/// compartment_manager_screen.dart – Add/remove/reorder compartments for a
/// vehicle plus a grid editor for the cutaway view (Schnittdarstellung).
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/presentation/providers/compartment_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

class CompartmentManagerScreen extends ConsumerWidget {
  final int vehicleId;
  const CompartmentManagerScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));
    final compartmentsAsync =
        ref.watch(compartmentListStreamProvider(vehicleId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(tabs: [
            Tab(text: 'Liste', icon: Icon(Icons.list)),
            Tab(text: 'Raster', icon: Icon(Icons.grid_view)),
          ]),
        ),
        body: TabBarView(
          children: [
            _buildListTab(context, ref, compartmentsAsync),
            _GridEditorTab(vehicleId: vehicleId),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab(BuildContext context, WidgetRef ref,
      AsyncValue<List<Compartment>> compartmentsAsync) {
    return compartmentsAsync.when(
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

/// Editor for the cutaway grid: live preview, tap a tile to set its
/// row/column/span. Persists directly via the compartment repository.
class _GridEditorTab extends ConsumerWidget {
  final int vehicleId;
  const _GridEditorTab({required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compartmentsAsync =
        ref.watch(compartmentListStreamProvider(vehicleId));
    return compartmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (compartments) {
        if (compartments.isEmpty) {
          return const Center(
              child: Text('Lege zuerst Fächer an.',
                  style: TextStyle(color: Colors.grey)));
        }
        final unplaced = compartments
            .where((c) => c.gridRow == null || c.gridCol == null)
            .length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tippe auf ein Fach, um Zeile, Spalte und Breite in der '
              'Schnittdarstellung festzulegen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (unplaced > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$unplaced Fach/Fächer noch nicht platziert '
                  '(werden unten automatisch angeordnet).',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.orange.shade800),
                ),
              ),
            const SizedBox(height: 12),
            VehicleCutawayView(
              compartments: compartments,
              onTapCompartment: (c) => _editTile(context, ref, c),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editTile(
      BuildContext context, WidgetRef ref, Compartment c) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _TileEditorSheet(compartment: c),
    );
  }
}

class _TileEditorSheet extends ConsumerStatefulWidget {
  final Compartment compartment;
  const _TileEditorSheet({required this.compartment});

  @override
  ConsumerState<_TileEditorSheet> createState() => _TileEditorSheetState();
}

class _TileEditorSheetState extends ConsumerState<_TileEditorSheet> {
  late int _row;
  late int _col;
  late int _span;

  @override
  void initState() {
    super.initState();
    _row = widget.compartment.gridRow ?? 0;
    _col = widget.compartment.gridCol ?? 0;
    _span = widget.compartment.gridColSpan;
  }

  Future<void> _save({bool removeFromGrid = false}) async {
    final repo = ref.read(compartmentRepositoryProvider);
    await repo.update(widget.compartment.copyWith(
      gridRow: removeFromGrid ? null : _row,
      gridCol: removeFromGrid ? null : _col,
      gridColSpan: removeFromGrid ? 1 : _span,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.compartment.label,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _Stepper(
                label: 'Zeile',
                value: _row,
                min: 0,
                onChanged: (v) => setState(() => _row = v)),
            _Stepper(
                label: 'Spalte',
                value: _col,
                min: 0,
                onChanged: (v) => setState(() => _col = v)),
            _Stepper(
                label: 'Breite (Spalten)',
                value: _span,
                min: 1,
                onChanged: (v) => setState(() => _span = v)),
            const SizedBox(height: 12),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _save(removeFromGrid: true),
                  child: const Text('Aus Raster entfernen'),
                ),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
            width: 32,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
