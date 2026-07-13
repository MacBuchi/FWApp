/// vehicle_list_screen.dart – Shows all vehicles with navigation to detail and create.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/inspection/domain/entities/due_inspection_entry.dart';
import 'package:fwapp/features/inspection/presentation/providers/inspection_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class VehicleListScreen extends ConsumerWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);
    final dueCounts =
        ref.watch(vehicleDueCountsStreamProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrzeuge'),
        actions: [
          if (ref.watch(isAdminProvider))
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Fahrzeug hinzufügen',
              onPressed: () => context.push('/vehicles/new'),
            ),
        ],
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fire_truck, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Noch keine Fahrzeuge angelegt.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          // dueCounts read above so badges update reactively with the list
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: vehicles.length,
            itemBuilder: (context, i) {
              final v = vehicles[i];
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: resolveImage(
                      path: v.imagePath ?? kPlaceholderAsset,
                      width: 56,
                      height: 56,
                    ),
                  ),
                  title: Text(v.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(v.type),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dueCounts[v.id] != null)
                        _DueBadge(counts: dueCounts[v.id]!),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push('/vehicles/${v.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Small pill showing overdue (red) / due-soon (orange) inspection counts.
class _DueBadge extends StatelessWidget {
  final DueCounts counts;
  const _DueBadge({required this.counts});

  @override
  Widget build(BuildContext context) {
    final isOverdue = counts.overdueCount > 0;
    final color = isOverdue ? Colors.red.shade700 : Colors.orange.shade800;
    final count = isOverdue ? counts.overdueCount : counts.dueSoonCount;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fact_check, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text('$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
