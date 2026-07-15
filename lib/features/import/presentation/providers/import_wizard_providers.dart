/// import_wizard_providers.dart – State and notifier for the 4-step
/// Beladeliste import wizard.
library;
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/import/data/equipment_matcher.dart';
import 'package:fwapp/features/import/data/import_parser.dart';
import 'package:fwapp/features/import/data/import_service.dart';
import 'package:fwapp/features/import/domain/import_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'import_wizard_providers.g.dart';

/// Parses assets/equipment_library/aliases.json. The file wraps the map in a
/// top-level "aliases" key; a bare map is accepted too.
Map<String, List<String>> parseBundledAliases(String json) {
  var decoded = jsonDecode(json) as Map<String, dynamic>;
  if (decoded['aliases'] is Map<String, dynamic>) {
    decoded = decoded['aliases'] as Map<String, dynamic>;
  }
  return decoded.map((k, v) => MapEntry(
      k, v is List ? v.map((e) => e.toString()).toList() : <String>[]));
}

/// Parses the standard catalog into an alias map (id → alias spellings).
Map<String, List<String>> parseCatalogAliases(String json) {
  final decoded = jsonDecode(json) as Map<String, dynamic>;
  final items = (decoded['items'] as List?) ?? [];
  return {
    for (final raw in items.cast<Map<String, dynamic>>())
      raw['id'] as String:
          ((raw['aliases'] as List?)?.map((e) => e.toString()).toList()) ?? [],
  };
}

class ImportWizardState {
  /// 0 = Datei, 1 = Spalten, 2 = Abgleich, 3 = Bestätigen/Ergebnis.
  final int step;
  final ParsedImportFile? file;
  final int tableIndex;
  final ColumnMapping? mapping;
  final List<ImportRow> rows;

  /// Match result per distinct normalized equipment name.
  final Map<String, EquipmentMatch> matches;

  /// User decision per distinct normalized equipment name.
  final Map<String, RowDecision> decisions;
  final bool busy;
  final ImportApplyResult? result;
  final String? error;

  const ImportWizardState({
    this.step = 0,
    this.file,
    this.tableIndex = 0,
    this.mapping,
    this.rows = const [],
    this.matches = const {},
    this.decisions = const {},
    this.busy = false,
    this.result,
    this.error,
  });

  ImportTable? get table =>
      file == null || file!.tables.isEmpty ? null : file!.tables[tableIndex];

  ImportWizardState copyWith({
    int? step,
    ParsedImportFile? file,
    int? tableIndex,
    ColumnMapping? mapping,
    List<ImportRow>? rows,
    Map<String, EquipmentMatch>? matches,
    Map<String, RowDecision>? decisions,
    bool? busy,
    ImportApplyResult? result,
    String? error,
    bool clearError = false,
    bool clearResult = false,
  }) =>
      ImportWizardState(
        step: step ?? this.step,
        file: file ?? this.file,
        tableIndex: tableIndex ?? this.tableIndex,
        mapping: mapping ?? this.mapping,
        rows: rows ?? this.rows,
        matches: matches ?? this.matches,
        decisions: decisions ?? this.decisions,
        busy: busy ?? this.busy,
        result: clearResult ? null : (result ?? this.result),
        error: clearError ? null : (error ?? this.error),
      );
}

@riverpod
class ImportWizardNotifier extends _$ImportWizardNotifier {
  @override
  ImportWizardState build() => const ImportWizardState();

  void reset() => state = const ImportWizardState();

  void back() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1, clearError: true);
    }
  }

  // ── Step 0: Datei laden ──

  Future<void> loadFile(String fileName, List<int> bytes) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final file = ImportParser.parse(fileName, bytes);
      final mapping = ImportParser.detectMapping(file.tables.first.rows.first);
      state = ImportWizardState(step: 1, file: file, mapping: mapping);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Datei nicht lesbar: $e');
    }
  }

  void selectTable(int index) {
    final file = state.file;
    if (file == null || index < 0 || index >= file.tables.length) return;
    state = state.copyWith(
      tableIndex: index,
      mapping: ImportParser.detectMapping(file.tables[index].rows.first),
    );
  }

  // ── Step 1: Spalten zuordnen ──

  void updateMapping(ColumnMapping mapping) =>
      state = state.copyWith(mapping: mapping, clearError: true);

  /// Applies the mapping and runs the matcher → step 2.
  Future<void> buildPreview() async {
    final table = state.table;
    final mapping = state.mapping;
    if (table == null || mapping == null || !mapping.isValid) {
      state = state.copyWith(
          error: 'Bitte Spalten für Fach und Gerät wählen und ein Fahrzeug '
              'festlegen.');
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final rows = ImportParser.applyMapping(table, mapping);
      if (rows.isEmpty) {
        state = state.copyWith(
            busy: false,
            error: 'Mit dieser Zuordnung ergeben sich keine Datenzeilen.');
        return;
      }
      final matcher = await _createMatcher();
      final matches = <String, EquipmentMatch>{};
      final decisions = <String, RowDecision>{};
      for (final row in rows) {
        final key = EquipmentMatcher.normalize(row.equipmentName);
        if (matches.containsKey(key)) continue;
        final match = matcher.match(row.equipmentName);
        matches[key] = match;
        decisions[key] = switch (match.kind) {
          MatchKind.exact || MatchKind.alias || MatchKind.fuzzy => RowDecision(
              action: RowAction.useEquipment,
              equipmentId: match.best!.equipmentId,
              // Learn fuzzy confirmations so the next import matches directly.
              rememberAlias: match.kind == MatchKind.fuzzy,
            ),
          MatchKind.none =>
            const RowDecision(action: RowAction.createCustom),
        };
      }
      state = state.copyWith(
          step: 2, rows: rows, matches: matches, decisions: decisions,
          busy: false);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Abgleich fehlgeschlagen: $e');
    }
  }

  Future<EquipmentMatcher> _createMatcher() async {
    final db = ref.read(appDatabaseProvider);
    final equipment = await db.equipmentDao.getAll();
    final userAliases = await db.select(db.userAliases).get();
    var bundled = <String, List<String>>{};
    try {
      final raw = await rootBundle
          .loadString('assets/equipment_library/aliases.json');
      bundled = parseBundledAliases(raw);
    } catch (_) {
      // No bundled aliases – matcher still works on names + user aliases.
    }
    try {
      final raw = await rootBundle
          .loadString('assets/equipment_library/catalog/standard_catalog.json');
      // Additiv mergen: aliases.json und Katalog-Aliasse ergänzen sich,
      // gleiche Library-IDs dürfen einander nicht verdrängen.
      parseCatalogAliases(raw).forEach((id, names) => bundled.update(
          id, (existing) => [...existing, ...names],
          ifAbsent: () => names));
    } catch (_) {
      // Catalog missing – nothing to merge.
    }
    return EquipmentMatcher(
      equipment: equipment,
      bundledAliases: bundled,
      userAliases: userAliases,
    );
  }

  // ── Step 2: Abgleich ──

  void setDecision(String key, RowDecision decision) => state = state
      .copyWith(decisions: {...state.decisions, key: decision});

  void toConfirm() => state = state.copyWith(step: 3, clearError: true);

  // ── Step 3: Anwenden ──

  Future<void> applyImport() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await ImportService(ref.read(appDatabaseProvider))
          .apply(rows: state.rows, decisions: state.decisions);
      state = state.copyWith(busy: false, result: result);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Import fehlgeschlagen: $e');
    }
  }
}
