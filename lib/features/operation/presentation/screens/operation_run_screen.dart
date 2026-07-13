/// operation_run_screen.dart – Virtuelles Ausladen: pro Fahrzeug die
/// Schnittdarstellung; Fach antippen öffnet die Geräte als Fotokacheln, die
/// bei Entnahme abgehakt werden. Einsatzrelevante Geräte sind hervorgehoben.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/assignment/presentation/providers/assignment_providers.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/presentation/providers/compartment_providers.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:fwapp/features/operation/presentation/providers/operation_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

class OperationRunScreen extends ConsumerWidget {
  const OperationRunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final op = ref.watch(operationProvider);
    if (!op.active || op.vehicleIds.isEmpty) {
      // Kein aktiver Einsatz (z.B. nach Reload) → zurück zum Setup.
      return Scaffold(
        appBar: AppBar(title: const Text('Einsatz')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.pushReplacement('/operation'),
            child: const Text('Einsatz starten'),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: op.vehicleIds.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Einsatz – Ausladen'),
          actions: [
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Entnommen-Liste',
              onPressed: () => context.push('/operation/summary'),
            ),
          ],
          bottom: op.vehicleIds.length > 1
              ? TabBar(
                  isScrollable: true,
                  tabs: [
                    for (final id in op.vehicleIds) _VehicleTab(vehicleId: id),
                  ],
                )
              : null,
        ),
        body: TabBarView(
          children: [
            for (final id in op.vehicleIds) _VehicleUnloadView(vehicleId: id),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.done_all),
          label: const Text('Übersicht'),
          onPressed: () => context.push('/operation/summary'),
        ),
      ),
    );
  }
}

class _VehicleTab extends ConsumerWidget {
  final int vehicleId;
  const _VehicleTab({required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleDetailProvider(vehicleId)).value;
    return Tab(text: vehicle?.name ?? '…');
  }
}

class _VehicleUnloadView extends ConsumerWidget {
  final int vehicleId;
  const _VehicleUnloadView({required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final op = ref.watch(operationProvider);
    final compartmentsAsync =
        ref.watch(compartmentListStreamProvider(vehicleId));
    final assignments =
        ref.watch(assignmentsByVehicleProvider(vehicleId)).value ?? const [];

    // Assignments je Fach + Entnahme-Fortschritt.
    final byCompartment = <int, List<int>>{}; // compartmentId → assignmentIds
    for (final a in assignments) {
      byCompartment.putIfAbsent(a.compartmentId, () => []).add(a.id);
    }
    final takenTotal =
        assignments.where((a) => op.isTaken(a.id)).length;

    return compartmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (compartments) {
        final tileStates = <int, CutawayTileState>{};
        for (final c in compartments) {
          final ids = byCompartment[c.id] ?? const [];
          final taken = ids.where(op.isTaken).length;
          tileStates[c.id] = CutawayTileState(
            status: ids.isEmpty
                ? CutawayTileStatus.normal
                : taken == ids.length
                    ? CutawayTileStatus.correct
                    : taken > 0
                        ? CutawayTileStatus.selected
                        : CutawayTileStatus.normal,
            statusText: ids.isEmpty ? null : '$taken/${ids.length}',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProgressBanner(taken: takenTotal, total: assignments.length),
            const SizedBox(height: 12),
            VehicleCutawayView(
              compartments: compartments,
              tileStates: tileStates,
              onTapCompartment: (c) => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _CompartmentUnloadSheet(compartment: c),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tippe ein Fach an, um die Geräte auszuladen.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  final int taken;
  final int total;
  const _ProgressBanner({required this.taken, required this.total});

  @override
  Widget build(BuildContext context) {
    final done = total > 0 && taken == total;
    return Card(
      color: done
          ? Colors.green.withValues(alpha: 0.15)
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.inventory_2,
                color: done ? Colors.green.shade700 : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(done ? 'Fahrzeug leer geräumt' : 'Ausladen',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? taken / total : 0,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('$taken/$total',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _CompartmentUnloadSheet extends ConsumerWidget {
  final Compartment compartment;
  const _CompartmentUnloadSheet({required this.compartment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync =
        ref.watch(assignmentListStreamProvider(compartment.id));
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(compartment.label,
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            Expanded(
              child: assignmentsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Fehler: $e')),
                data: (assignments) => assignments.isEmpty
                    ? const Center(
                        child: Text('Kein Gerät zugewiesen.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: assignments.length,
                        itemBuilder: (context, i) => _UnloadTile(
                          assignmentId: assignments[i].id,
                          equipmentId: assignments[i].equipmentId,
                          quantity: assignments[i].quantity,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnloadTile extends ConsumerWidget {
  final int assignmentId;
  final int equipmentId;
  final int quantity;
  const _UnloadTile({
    required this.assignmentId,
    required this.equipmentId,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taken = ref.watch(
        operationProvider.select((s) => s.isTaken(assignmentId)));
    final scenario = ref.watch(operationProvider.select((s) => s.scenario));
    final item = ref.watch(equipmentDetailProvider(equipmentId)).value;

    final relevant = scenario != null &&
        (item?.deploymentScenarios.contains(scenario.jsonKey) ?? false);

    return Card(
      color: taken
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : relevant
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
      child: ListTile(
        leading: Opacity(
          opacity: taken ? 0.4 : 1,
          child: EquipmentAvatar(
            imagePath: item?.imagePath,
            functions: item?.equipmentFunctions ?? const [],
            size: 48,
          ),
        ),
        title: Text(
          item?.name ?? '…',
          style: TextStyle(
            decoration: taken ? TextDecoration.lineThrough : null,
            color: taken ? Colors.grey : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            if (quantity > 1) Text('× $quantity  '),
            if (relevant && !taken)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Einsatzrelevant',
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onPrimary)),
              ),
          ],
        ),
        trailing: Icon(
          taken ? Icons.check_circle : Icons.radio_button_unchecked,
          color: taken ? Colors.green : Colors.grey,
          size: 28,
        ),
        onTap: () =>
            ref.read(operationProvider.notifier).toggleTaken(assignmentId),
      ),
    );
  }
}
