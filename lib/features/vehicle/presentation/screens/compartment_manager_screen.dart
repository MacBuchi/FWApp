/// compartment_manager_screen.dart – Add/remove/reorder compartments for a vehicle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/presentation/providers/compartment_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class CompartmentManagerScreen extends ConsumerWidget {
  final int vehicleId;
  const CompartmentManagerScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));
    final compartmentsAsync =
        ref.watch(compartmentListStreamProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: vehicleAsync.when(
          loading: () => const Text('Fächer'),
          error: (_, __) => const Text('Fächer'),
          data: (v) => Text('Fächer – ${v?.name ?? ''}'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Fach hinzufügen',
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: compartmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (compartments) {
          if (compartments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inbox, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Noch keine Fächer.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Fach hinzufügen'),
                  ),
                ],
              ),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: compartments.length,
            onReorder: (oldIndex, newIndex) =>
                _reorder(ref, compartments, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final c = compartments[index];
              return Card(
                key: ValueKey(c.id),
                child: ListTile(
                  leading: const Icon(Icons.drag_handle),
                  title: Text(c.label),
                  subtitle: Text('Position ${c.position + 1}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () =>
                            _showEditDialog(context, ref, c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () =>
                            _confirmDelete(context, ref, c),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fach hinzufügen'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Bezeichnung (z.B. G1)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hinzufügen')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final repo = ref.read(compartmentRepositoryProvider);
      final existing = await repo.getByVehicle(vehicleId);
      await repo.insert(Compartment(
        id: 0,
        vehicleId: vehicleId,
        label: ctrl.text.trim(),
        position: existing.length,
        gridColSpan: 1,
        updatedAt: DateTime.now(),
      ));
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Compartment c) async {
    final ctrl = TextEditingController(text: c.label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fach bearbeiten'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Bezeichnung'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(compartmentRepositoryProvider).update(
            c.copyWith(label: ctrl.text.trim()),
          );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Compartment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fach löschen?'),
        content: Text(
            '„${c.label}" und alle zugewiesenen Geräte werden gelöscht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(compartmentRepositoryProvider).delete(c.id);
    }
  }

  Future<void> _reorder(WidgetRef ref, List<Compartment> compartments,
      int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final repo = ref.read(compartmentRepositoryProvider);
    final list = [...compartments];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (var i = 0; i < list.length; i++) {
      await repo.update(list[i].copyWith(position: i));
    }
  }
}
