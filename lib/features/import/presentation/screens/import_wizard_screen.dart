/// import_wizard_screen.dart – 4-step Beladeliste import wizard:
/// Datei laden → Spalten zuordnen → Abgleich → Bestätigen.
library;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_item.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/import/data/equipment_matcher.dart';
import 'package:fwapp/features/import/data/import_parser.dart';
import 'package:fwapp/features/import/domain/import_models.dart';
import 'package:fwapp/features/import/presentation/providers/import_wizard_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class ImportWizardScreen extends ConsumerWidget {
  const ImportWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider);
    final notifier = ref.read(importWizardProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beladeliste importieren'),
        leading: BackButton(onPressed: () {
          if (state.step > 0 && state.result == null) {
            notifier.back();
          } else if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        }),
      ),
      body: Column(
        children: [
          _StepIndicator(current: state.step),
          if (state.error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(state.error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          Expanded(
            child: switch (state.step) {
              0 => const _FileStep(),
              1 => const _MappingStep(),
              2 => const _MatchStep(),
              _ => const _ConfirmStep(),
            },
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _labels = ['Datei', 'Spalten', 'Abgleich', 'Import'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor:
                  i <= current ? scheme.primary : scheme.surfaceContainerHighest,
              child: i < current
                  ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                  : Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          color: i <= current
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 4),
            Text(_labels[i],
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        i == current ? FontWeight.bold : FontWeight.normal)),
            if (i < _labels.length - 1)
              const Expanded(child: Divider(indent: 6, endIndent: 6)),
          ],
        ],
      ),
    );
  }
}

// ── Step 0: Datei laden ──────────────────────────────────────

class _FileStep extends ConsumerWidget {
  const _FileStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unterstützte Formate',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                const Text(
                    '• Excel (.xlsx, .xls)\n'
                    '• CSV (Trennzeichen ; , oder Tab – wird erkannt)\n\n'
                    'Die Spalten musst du nicht umbenennen: Im nächsten '
                    'Schritt ordnest du sie zu.',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: state.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_file),
          label: const Text('Datei auswählen'),
          onPressed: state.busy
              ? null
              : () async {
                  final picked = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
                    withData: true,
                  );
                  final file = picked?.files.firstOrNull;
                  if (file == null || file.bytes == null) return;
                  await ref
                      .read(importWizardProvider.notifier)
                      .loadFile(file.name, file.bytes!);
                },
        ),
      ],
    );
  }
}

// ── Step 1: Spalten zuordnen ─────────────────────────────────

class _MappingStep extends ConsumerWidget {
  const _MappingStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider);
    final notifier = ref.read(importWizardProvider.notifier);
    final table = state.table;
    final mapping = state.mapping;
    if (table == null || mapping == null) return const SizedBox.shrink();

    final headerRow = table.rows.first;
    final columnCount = table.rows
        .map((r) => r.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    String columnLabel(int i) {
      final header = i < headerRow.length ? headerRow[i].trim() : '';
      return header.isEmpty || !mapping.firstRowIsHeader
          ? 'Spalte ${i + 1}'
          : header;
    }

    final columnItems = [
      for (var i = 0; i < columnCount; i++)
        DropdownMenuItem<int?>(value: i, child: Text(columnLabel(i))),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.file!.tables.length > 1)
          DropdownButtonFormField<int>(
            initialValue: state.tableIndex,
            decoration: const InputDecoration(labelText: 'Tabellenblatt'),
            items: [
              for (var i = 0; i < state.file!.tables.length; i++)
                DropdownMenuItem(
                    value: i, child: Text(state.file!.tables[i].name)),
            ],
            onChanged: (i) => i == null ? null : notifier.selectTable(i),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Erste Zeile ist Überschrift'),
          value: mapping.firstRowIsHeader,
          onChanged: (v) =>
              notifier.updateMapping(mapping.copyWith(firstRowIsHeader: v)),
        ),
        DropdownButtonFormField<int?>(
          initialValue: mapping.vehicleColumn,
          decoration: const InputDecoration(labelText: 'Fahrzeug'),
          items: [
            const DropdownMenuItem<int?>(
                value: null, child: Text('Fester Wert (kein Spaltenbezug)')),
            ...columnItems,
          ],
          onChanged: (v) =>
              notifier.updateMapping(mapping.copyWith(vehicleColumn: () => v)),
        ),
        if (mapping.vehicleColumn == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _FixedVehicleField(
              initial: mapping.fixedVehicleName,
              onChanged: (v) =>
                  notifier.updateMapping(mapping.copyWith(fixedVehicleName: v)),
            ),
          ),
        DropdownButtonFormField<int?>(
          initialValue:
              mapping.compartmentColumn >= 0 ? mapping.compartmentColumn : null,
          decoration: const InputDecoration(labelText: 'Fach / Lagerort *'),
          items: columnItems,
          onChanged: (v) => notifier
              .updateMapping(mapping.copyWith(compartmentColumn: v ?? -1)),
        ),
        DropdownButtonFormField<int?>(
          initialValue:
              mapping.equipmentColumn >= 0 ? mapping.equipmentColumn : null,
          decoration: const InputDecoration(labelText: 'Gerät / Gegenstand *'),
          items: columnItems,
          onChanged: (v) => notifier
              .updateMapping(mapping.copyWith(equipmentColumn: v ?? -1)),
        ),
        DropdownButtonFormField<int?>(
          initialValue: mapping.quantityColumn,
          decoration:
              const InputDecoration(labelText: 'Menge (optional, sonst 1)'),
          items: [
            const DropdownMenuItem<int?>(
                value: null, child: Text('Keine Spalte')),
            ...columnItems,
          ],
          onChanged: (v) =>
              notifier.updateMapping(mapping.copyWith(quantityColumn: () => v)),
        ),
        const SizedBox(height: 16),
        Text('Vorschau', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        _MappingPreview(table: table, mapping: mapping),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: state.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_forward),
          label: const Text('Weiter zum Abgleich'),
          onPressed:
              state.busy || !mapping.isValid ? null : notifier.buildPreview,
        ),
      ],
    );
  }
}

/// Text field that keeps its own controller so typing doesn't fight the
/// provider rebuild.
class _FixedVehicleField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _FixedVehicleField({required this.initial, required this.onChanged});

  @override
  State<_FixedVehicleField> createState() => _FixedVehicleFieldState();
}

class _FixedVehicleFieldState extends State<_FixedVehicleField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        decoration: const InputDecoration(
            labelText: 'Fahrzeugname *', hintText: 'z.B. LF 10'),
        onChanged: widget.onChanged,
      );
}

class _MappingPreview extends StatelessWidget {
  final ImportTable table;
  final ColumnMapping mapping;
  const _MappingPreview({required this.table, required this.mapping});

  @override
  Widget build(BuildContext context) {
    final rows = ImportParser.applyMapping(table, mapping).take(5).toList();
    if (rows.isEmpty) {
      return const Text('Keine Datenzeilen mit dieser Zuordnung.',
          style: TextStyle(color: Colors.grey));
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 32,
          dataRowMinHeight: 28,
          dataRowMaxHeight: 36,
          columns: const [
            DataColumn(label: Text('Fahrzeug')),
            DataColumn(label: Text('Fach')),
            DataColumn(label: Text('Gerät')),
            DataColumn(label: Text('Menge')),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(r.vehicleName)),
                DataCell(Text(r.compartmentLabel)),
                DataCell(SizedBox(
                    width: 220,
                    child: Text(r.equipmentName,
                        overflow: TextOverflow.ellipsis))),
                DataCell(Text('${r.quantity}')),
              ]),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Abgleich ─────────────────────────────────────────

class _MatchStep extends ConsumerWidget {
  const _MatchStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider);
    final notifier = ref.read(importWizardProvider.notifier);

    // Distinct equipment names in first-seen order, with row counts.
    final distinct = <String, ({String rawName, int rowCount})>{};
    for (final row in state.rows) {
      final key = EquipmentMatcher.normalize(row.equipmentName);
      final existing = distinct[key];
      distinct[key] = (
        rawName: existing?.rawName ?? row.equipmentName,
        rowCount: (existing?.rowCount ?? 0) + 1,
      );
    }

    var green = 0, yellow = 0, red = 0, skippedCount = 0;
    for (final key in distinct.keys) {
      final match = state.matches[key];
      final decision = state.decisions[key];
      if (decision?.action == RowAction.skip) {
        skippedCount++;
      } else if (decision?.action == RowAction.createCustom) {
        red++;
      } else if (match?.kind == MatchKind.exact ||
          match?.kind == MatchKind.alias) {
        green++;
      } else {
        yellow++;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              _CountChip(color: Colors.green, label: '$green erkannt'),
              _CountChip(color: Colors.orange, label: '$yellow zugeordnet'),
              _CountChip(color: Colors.red, label: '$red neu'),
              if (skippedCount > 0)
                _CountChip(color: Colors.grey, label: '$skippedCount übersprungen'),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tippe einen Eintrag an, um die Zuordnung zu ändern.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final entry in distinct.entries)
                _MatchTile(
                  matchKey: entry.key,
                  rawName: entry.value.rawName,
                  rowCount: entry.value.rowCount,
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Weiter zur Zusammenfassung'),
              onPressed: notifier.toConfirm,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final Color color;
  final String label;
  const _CountChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Chip(
        visualDensity: VisualDensity.compact,
        avatar: CircleAvatar(backgroundColor: color, radius: 6),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      );
}

class _MatchTile extends ConsumerWidget {
  final String matchKey;
  final String rawName;
  final int rowCount;
  const _MatchTile({
    required this.matchKey,
    required this.rawName,
    required this.rowCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider);
    final match = state.matches[matchKey];
    final decision = state.decisions[matchKey] ??
        const RowDecision(action: RowAction.createCustom);

    final (Color color, String status) = switch (decision.action) {
      RowAction.skip => (Colors.grey, 'Wird übersprungen'),
      RowAction.createCustom => (
          Colors.red,
          'Wird als neues Gerät angelegt'
        ),
      RowAction.useEquipment when match?.kind == MatchKind.exact ||
              match?.kind == MatchKind.alias =>
        (Colors.green, '→ ${_targetName(state, decision)}'),
      RowAction.useEquipment => (
          Colors.orange,
          '→ ${_targetName(state, decision)}'
        ),
    };

    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(backgroundColor: color, radius: 8),
        title: Text(rawName, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            rowCount > 1 ? '$status · $rowCount Zeilen' : status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.edit, size: 18),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _ResolutionSheet(matchKey: matchKey, rawName: rawName),
        ),
      ),
    );
  }

  String _targetName(ImportWizardState state, RowDecision decision) {
    final match = state.matches[matchKey];
    for (final s in match?.suggestions ?? const <MatchCandidate>[]) {
      if (s.equipmentId == decision.equipmentId) return s.equipmentName;
    }
    return 'Gerät #${decision.equipmentId}';
  }
}

/// Bottom sheet: pick a suggestion, search the full database, create as
/// custom, or skip.
class _ResolutionSheet extends ConsumerStatefulWidget {
  final String matchKey;
  final String rawName;
  const _ResolutionSheet({required this.matchKey, required this.rawName});

  @override
  ConsumerState<_ResolutionSheet> createState() => _ResolutionSheetState();
}

class _ResolutionSheetState extends ConsumerState<_ResolutionSheet> {
  String _search = '';
  bool _rememberAlias = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importWizardProvider);
    final notifier = ref.read(importWizardProvider.notifier);
    final match = state.matches[widget.matchKey];
    final equipmentAsync = ref.watch(equipmentListProvider);
    final allEquipment = equipmentAsync.value ?? const <EquipmentItem>[];

    final searchNorm = EquipmentMatcher.normalize(_search);
    final searchResults = _search.trim().isEmpty
        ? const <EquipmentItem>[]
        : allEquipment
            .where((e) =>
                EquipmentMatcher.normalize(e.name).contains(searchNorm))
            .take(10)
            .toList();

    void choose(int equipmentId) {
      notifier.setDecision(
          widget.matchKey,
          RowDecision(
            action: RowAction.useEquipment,
            equipmentId: equipmentId,
            rememberAlias: _rememberAlias,
          ));
      Navigator.of(context).pop();
    }

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.rawName,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Als Alias merken (künftig automatisch)'),
              value: _rememberAlias,
              onChanged: (v) => setState(() => _rememberAlias = v ?? true),
            ),
            if (match != null && match.suggestions.isNotEmpty) ...[
              Text('Vorschläge', style: Theme.of(context).textTheme.titleSmall),
              ...match.suggestions.map((s) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.lightbulb_outline, size: 20),
                    title: Text(s.equipmentName),
                    subtitle: Text('Ähnlichkeit ${(s.score * 100).round()} %'),
                    onTap: () => choose(s.equipmentId),
                  )),
              const Divider(),
            ],
            TextField(
              decoration: const InputDecoration(
                  labelText: 'Gerätedatenbank durchsuchen',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _search = v),
            ),
            ...searchResults.map((e) => ListTile(
                  dense: true,
                  title: Text(e.name),
                  onTap: () => choose(e.id),
                )),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Als neues Gerät anlegen'),
              onTap: () {
                notifier.setDecision(widget.matchKey,
                    const RowDecision(action: RowAction.createCustom));
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.block),
              title: const Text('Überspringen'),
              onTap: () {
                notifier.setDecision(widget.matchKey,
                    const RowDecision(action: RowAction.skip));
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Bestätigen / Ergebnis ────────────────────────────

class _ConfirmStep extends ConsumerWidget {
  const _ConfirmStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider);
    final notifier = ref.read(importWizardProvider.notifier);
    final result = state.result;

    if (result != null) return _ResultView(result: result);

    var useCount = 0, customCount = 0, skipCount = 0;
    final seen = <String>{};
    for (final row in state.rows) {
      final key = EquipmentMatcher.normalize(row.equipmentName);
      if (!seen.add(key)) continue;
      switch ((state.decisions[key] ??
              const RowDecision(action: RowAction.createCustom))
          .action) {
        case RowAction.useEquipment:
          useCount++;
        case RowAction.createCustom:
          customCount++;
        case RowAction.skip:
          skipCount++;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zusammenfassung',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('${state.rows.length} Zeilen aus '
                    '„${state.file?.fileName ?? ''}“'),
                Text('$useCount Geräte zugeordnet'),
                Text('$customCount Geräte werden neu angelegt'),
                if (skipCount > 0) Text('$skipCount werden übersprungen'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: state.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_done),
          label: const Text('Import ausführen'),
          onPressed: state.busy
              ? null
              : () async {
                  await notifier.applyImport();
                  // Refresh lists fed from the changed tables.
                  ref.invalidate(vehicleListStreamProvider);
                  ref.invalidate(vehicleListProvider);
                  ref.invalidate(equipmentListProvider);
                  ref.invalidate(equipmentListStreamProvider);
                },
        ),
      ],
    );
  }
}

class _ResultView extends ConsumerWidget {
  final ImportApplyResult result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(canEditProvider);
    final syncService = ref.watch(syncServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Import abgeschlossen',
                      style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 8),
                Text('${result.assignmentsWritten} Zuordnungen geschrieben'),
                if (result.vehiclesCreated > 0)
                  Text('${result.vehiclesCreated} Fahrzeuge neu angelegt'),
                if (result.compartmentsCreated > 0)
                  Text('${result.compartmentsCreated} Fächer neu angelegt'),
                if (result.customItemsCreated > 0)
                  Text('${result.customItemsCreated} Geräte neu angelegt'),
                if (result.aliasesLearned > 0)
                  Text('${result.aliasesLearned} Aliasse gelernt'),
                if (result.skipped > 0)
                  Text('${result.skipped} Zeilen übersprungen'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (isAdmin && syncService != null)
          FilledButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Jetzt veröffentlichen'),
            onPressed: () async {
              try {
                final version = await syncService.publish();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Version $version veröffentlicht.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Veröffentlichen fehlgeschlagen: $e')));
                }
              }
            },
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('Weitere Datei importieren'),
          onPressed: () =>
              ref.read(importWizardProvider.notifier).reset(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.home),
          label: const Text('Zurück zur Startseite'),
          onPressed: () {
            ref.read(importWizardProvider.notifier).reset();
            context.go('/');
          },
        ),
      ],
    );
  }
}
