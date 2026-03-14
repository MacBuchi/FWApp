/// vehicle_list_screen.dart – Shows all vehicles with navigation to detail and create.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class VehicleListScreen extends ConsumerWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrzeuge'),
        actions: [
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
                  trailing: const Icon(Icons.chevron_right),
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
