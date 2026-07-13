/// vehicle_detail_screen.dart – Vehicle detail with cutaway view and
/// compartments list.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/assignment/presentation/providers/assignment_providers.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/presentation/providers/compartment_providers.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/inspection/presentation/providers/inspection_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

class VehicleDetailScreen extends ConsumerWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));
    final compartmentsAsync =
        ref.watch(compartmentListStreamProvider(vehicleId));

    return vehicleAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
      data: (vehicle) {
        if (vehicle == null) {
          return const Scaffold(
              body: Center(child: Text('Fahrzeug nicht gefunden.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(vehicle.name),
            actions: [
              if (ref.watch(isAdminProvider)) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Bearbeiten',
                  onPressed: () => context.push('/vehicles/$vehicleId/edit'),
                ),
                IconButton(
                  icon: const Icon(Icons.view_module),
                  tooltip: 'Beladefächer verwalten',
                  onPressed: () =>
                      context.push('/vehicles/$vehicleId/compartments'),
                ),
              ],
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // Vehicle header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: resolveImage(
                          path: vehicle.imagePath ?? kPlaceholderAsset,
                          width: double.infinity,
                          height: 160,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow('Typ', vehicle.type),
                      if (vehicle.licensePlate != null)
                        _InfoRow('Kennzeichen', vehicle.licensePlate!),
                    ],
                  ),
                ),
              ),
              // Cutaway view (Schnittdarstellung)
              SliverToBoxAdapter(
                child: compartmentsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (compartments) => compartments.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: _VehicleCutaway(
                              vehicleId: vehicleId,
                              compartments: compartments),
                        ),
                ),
              ),
              // Compartments
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Beladefächer',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (ref.watch(isAdminProvider))
                        TextButton.icon(
                          onPressed: () => context
                              .push('/vehicles/$vehicleId/compartments'),
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Verwalten'),
                        ),
                    ],
                  ),
                ),
              ),
              compartmentsAsync.when(
                loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverToBoxAdapter(
                    child: Center(child: Text('Fehler: $e'))),
                data: (compartments) {
                  if (compartments.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Keine Fächer angelegt.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final c = compartments[index];
                        return _CompartmentTile(
                            compartmentId: c.id, label: c.label);
                      },
                      childCount: compartments.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }
}

/// Cutaway with per-compartment item counts and inspection due badges;
/// tapping a tile opens its contents as a bottom sheet.
class _VehicleCutaway extends ConsumerWidget {
  final int vehicleId;
  final List<Compartment> compartments;
  const _VehicleCutaway(
      {required this.vehicleId, required this.compartments});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments =
        ref.watch(assignmentsByVehicleProvider(vehicleId)).value ?? const [];
    final dues = ref.watch(dueInspectionsStreamProvider()).value ?? const [];

    final itemCounts = <int, int>{};
    for (final a in assignments) {
      itemCounts[a.compartmentId] = (itemCounts[a.compartmentId] ?? 0) + 1;
    }
    final now = DateTime.now();
    final dueCounts = <int, int>{};
    final overdueByCompartment = <int, bool>{};
    for (final due in dues) {
      final compartmentId = due.instance.compartmentId;
      if (compartmentId == null) continue;
      dueCounts[compartmentId] = (dueCounts[compartmentId] ?? 0) + 1;
      if (due.isOverdue(now)) overdueByCompartment[compartmentId] = true;
    }

    return VehicleCutawayView(
      compartments: compartments,
      tileStates: {
        for (final c in compartments)
          c.id: CutawayTileState(
            itemCount: itemCounts[c.id] ?? 0,
            dueBadgeCount: dueCounts[c.id] ?? 0,
            dueBadgeIsOverdue: overdueByCompartment[c.id] ?? false,
          ),
      },
      onTapCompartment: (c) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => _CompartmentSheet(compartment: c),
      ),
    );
  }
}

/// Bottom sheet listing the equipment of one compartment.
class _CompartmentSheet extends ConsumerWidget {
  final Compartment compartment;
  const _CompartmentSheet({required this.compartment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync =
        ref.watch(assignmentListStreamProvider(compartment.id));
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(compartment.label,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: assignmentsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator()),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Fehler: $e')),
              data: (assignments) => assignments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Kein Gerät zugewiesen.',
                          style: TextStyle(color: Colors.grey)))
                  : ListView(
                      shrinkWrap: true,
                      children: assignments
                          .map((a) => _AssignmentRow(
                              equipmentId: a.equipmentId,
                              quantity: a.quantity))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value),
          ],
        ),
      );
}

class _CompartmentTile extends ConsumerWidget {
  final int compartmentId;
  final String label;
  const _CompartmentTile(
      {required this.compartmentId, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync =
        ref.watch(assignmentListStreamProvider(compartmentId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: assignmentsAsync.when(
          loading: () => const Text('Lade...'),
          error: (_, __) => const Text('Fehler'),
          data: (a) => Text('${a.length} Gerät(e)'),
        ),
        children: [
          assignmentsAsync.when(
            loading: () =>
                const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Fehler: $e'),
            ),
            data: (assignments) {
              if (assignments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Kein Gerät zugewiesen.',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return Column(
                children: assignments
                    .map((a) => _AssignmentRow(
                        equipmentId: a.equipmentId,
                        quantity: a.quantity))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends ConsumerWidget {
  final int equipmentId;
  final int quantity;
  const _AssignmentRow(
      {required this.equipmentId, required this.quantity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(equipmentDetailProvider(equipmentId));
    return itemAsync.when(
      loading: () => const ListTile(title: Text('...')),
      error: (_, __) => const ListTile(title: Text('Fehler')),
      data: (item) => ListTile(
        dense: true,
        leading: resolveImage(
          path: item?.imagePath ?? kPlaceholderAsset,
          width: 40,
          height: 40,
        ),
        title: Text(item?.name ?? '?'),
        trailing: Text('× $quantity',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: item != null
            ? () => context.push('/equipment/${item.id}')
            : null,
      ),
    );
  }
}
