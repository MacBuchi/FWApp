/// compartment_manager_screen.dart – Add/remove/reorder compartments for a
/// vehicle plus a grid editor for the cutaway view (Schnittdarstellung).
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';
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
            error: (_, _) => const Text('Fächer'),
            data: (v) => Text('Fächer – ${v?.name ?? ''}'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Fach hinzufügen',
              onPressed: () => _showAddDialog(context, ref),
            ),
            // Nur anbieten, wenn es etwas vorzuschlagen gibt (Issue #126).
            if (_vorschlaege(compartmentsAsync.value ?? const []).isNotEmpty)
              IconButton(
                icon: const Icon(Icons.auto_fix_high),
                tooltip: 'Seiten aus den Namen vorschlagen',
                onPressed: () => _seitenVorschlagen(
                    context, ref, compartmentsAsync.value ?? const []),
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
            onReorderItem: (oldIndex, newIndex) =>
                _reorder(ref, compartments, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final c = compartments[index];
              return Card(
                key: ValueKey(c.id),
                child: ListTile(
                  leading: const Icon(Icons.drag_handle),
                  title: Text(c.label),
                  subtitle: Text(
                      '${seiteAnzeigename(c.seite)} · Position ${c.position + 1}'),
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
    final eingabe = await showDialog<_FachEingabe>(
      context: context,
      builder: (_) => const _FachDialog(titel: 'Fach hinzufügen',
          knopf: 'Hinzufügen'),
    );
    if (eingabe == null) return;
    final repo = ref.read(compartmentRepositoryProvider);
    final existing = await repo.getByVehicle(vehicleId);
    await repo.insert(Compartment(
      id: 0,
      vehicleId: vehicleId,
      label: eingabe.label,
      position: existing.length,
      gridColSpan: 1,
      seite: eingabe.seite,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Compartment c) async {
    final eingabe = await showDialog<_FachEingabe>(
      context: context,
      builder: (_) => _FachDialog(
        titel: 'Fach bearbeiten',
        knopf: 'Speichern',
        label: c.label,
        seite: c.seite,
      ),
    );
    if (eingabe == null) return;
    await ref.read(compartmentRepositoryProvider).update(
          c.copyWith(label: eingabe.label, seite: eingabe.seite),
        );
  }

  /// Fächer ohne Seite, für die der Name einen Vorschlag hergibt.
  ///
  /// Bereits zugeordnete Fächer bleiben ausdrücklich unberührt: Ein
  /// Vorschlag darf nichts überschreiben, was jemand von Hand gesetzt hat.
  static List<({Compartment fach, String seite})> _vorschlaege(
      List<Compartment> compartments) {
    final out = <({Compartment fach, String seite})>[];
    for (final c in compartments) {
      if (c.seite != null) continue;
      final seite = seiteAusName(c.label);
      if (seite != null) out.add((fach: c, seite: seite));
    }
    return out;
  }

  /// Zeigt den Vorschlag Fach für Fach und übernimmt ihn erst nach Bestätigung.
  ///
  /// ⚠️ Bewusst mit Rückfrage und Auflistung: „Ungerade Nummer =
  /// Fahrerseite" ist die verbreitete Konvention, aber keine Naturkonstante.
  /// Ein still gesetzter falscher Wert wäre schlimmer als gar keiner — im
  /// Einsatz greift jemand ins falsche Fach.
  Future<void> _seitenVorschlagen(BuildContext context, WidgetRef ref,
      List<Compartment> compartments) async {
    final vorschlaege = _vorschlaege(compartments);
    if (vorschlaege.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seiten vorschlagen?'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nach der verbreiteten Nummerierung: ungerade Geräteräume '
                'auf der Fahrerseite, gerade auf der Beifahrerseite. Prüfe '
                'es an eurem Fahrzeug — ändern kannst du jedes Fach danach '
                'einzeln.',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final v in vorschlaege)
                        Text('${v.fach.label} → '
                            '${seiteAnzeigename(v.seite)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('${vorschlaege.length} übernehmen')),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(compartmentRepositoryProvider);
    for (final v in vorschlaege) {
      await repo.update(v.fach.copyWith(seite: v.seite));
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
    // Kein `newIndex--` mehr: onReorderItem (ab Flutter 3.41) rechnet die
    // Verkuerzung durch das entnommene Element bereits selbst heraus.
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

/// Ergebnis des Fach-Dialogs.
typedef _FachEingabe = ({String label, String? seite});

/// Bezeichnung UND Seite in einem Dialog (Issue #126).
///
/// Beides zusammen, weil beides beim Anlegen feststeht: Wer „G3" tippt,
/// weiß in dem Moment auch, wo G3 sitzt. Ein zweiter Weg dafür wäre ein
/// zweiter Weg, den niemand geht.
class _FachDialog extends StatefulWidget {
  const _FachDialog({
    required this.titel,
    required this.knopf,
    this.label,
    this.seite,
  });

  final String titel;
  final String knopf;
  final String? label;
  final String? seite;

  @override
  State<_FachDialog> createState() => _FachDialogState();
}

class _FachDialogState extends State<_FachDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.label ?? '');
  late String? _seite = widget.seite;

  /// Beim Anlegen folgt die Seite dem Namen, solange niemand sie angefasst
  /// hat — „G3" tippen und die Fahrerseite steht da. Ab dem ersten
  /// Handgriff gewinnt der Mensch.
  bool _seiteVonHand = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _nameGeaendert(String text) {
    if (_seiteVonHand || widget.label != null) return;
    final vorschlag = seiteAusName(text);
    if (vorschlag != _seite) setState(() => _seite = vorschlag);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
                labelText: 'Bezeichnung (z.B. G1)'),
            autofocus: true,
            onChanged: _nameGeaendert,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _seite,
            decoration: const InputDecoration(
              labelText: 'Seite am Fahrzeug',
              helperText: 'Bestimmt, wo das Fach im Aufklappbild steht.',
              helperMaxLines: 2,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Ohne Seite')),
              for (final s in kFahrzeugSeiten)
                DropdownMenuItem(value: s, child: Text(seiteAnzeigename(s))),
            ],
            onChanged: (v) => setState(() {
              _seite = v;
              _seiteVonHand = true;
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final label = _ctrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(context, (label: label, seite: _seite));
          },
          child: Text(widget.knopf),
        ),
      ],
    );
  }
}
