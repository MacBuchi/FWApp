/// import_parser.dart – Parses Beladeliste files (xlsx/xls via `excel`,
/// CSV with delimiter auto-detection) into raw string tables.
library;
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:fwapp/features/import/domain/import_models.dart';

class ImportParser {
  /// Throws [FormatException] when the file cannot be parsed.
  static ParsedImportFile parse(String fileName, List<int> bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
      return ParsedImportFile(
          fileName: fileName, tables: [_parseCsv(fileName, bytes)]);
    }
    return ParsedImportFile(fileName: fileName, tables: _parseExcel(bytes));
  }

  static List<ImportTable> _parseExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final tables = <ImportTable>[];
    for (final entry in excel.tables.entries) {
      final rows = entry.value.rows
          .map((row) =>
              row.map((c) => c?.value?.toString().trim() ?? '').toList())
          .where((cells) => cells.any((c) => c.isNotEmpty))
          .toList();
      if (rows.isNotEmpty) {
        tables.add(ImportTable(name: entry.key, rows: rows));
      }
    }
    if (tables.isEmpty) {
      throw const FormatException('Die Excel-Datei enthält keine Daten.');
    }
    return tables;
  }

  static ImportTable _parseCsv(String fileName, List<int> bytes) {
    var text = _decodeText(bytes);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final delimiter = detectDelimiter(text);
    final parsed = CsvDecoder(fieldDelimiter: delimiter).convert(text);
    final rows = parsed
        .map((row) => row.map((c) => c.toString().trim()).toList())
        .where((cells) => cells.any((c) => c.isNotEmpty))
        .toList();
    if (rows.isEmpty) {
      throw const FormatException('Die CSV-Datei enthält keine Daten.');
    }
    return ImportTable(name: fileName, rows: rows);
  }

  /// UTF-8 (with BOM) first, Latin-1 as fallback for old Excel exports.
  static String _decodeText(List<int> bytes) {
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = data.sublist(3);
    }
    try {
      return utf8.decode(data);
    } on FormatException {
      return latin1.decode(data);
    }
  }

  /// German lists are usually semicolon-separated; pick the delimiter that
  /// occurs most consistently in the first lines.
  static String detectDelimiter(String text) {
    final lines = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(10)
        .toList();
    if (lines.isEmpty) return ';';
    var best = ';';
    var bestCount = -1;
    for (final candidate in [';', ',', '\t']) {
      final counts =
          lines.map((l) => candidate.allMatches(l).length).toList();
      final min = counts.reduce((a, b) => a < b ? a : b);
      if (min > bestCount) {
        bestCount = min;
        best = candidate;
      }
    }
    return best;
  }

  // ── Column auto-detection (used to pre-fill the mapping step) ──

  static const _vehicleHints = ['fahrzeug', 'vehicle', 'kfz'];
  static const _compartmentHints = [
    'fach', 'lagerort', 'compartment', 'bereich', 'ort'
  ];
  static const _equipmentHints = [
    'gegenstand', 'gerät', 'geraet', 'equipment', 'bezeichnung', 'name',
    'material'
  ];
  static const _quantityHints = [
    'stückzahl', 'stueckzahl', 'menge', 'anzahl', 'quantity', 'stk'
  ];

  /// Guesses a mapping from the header row. Returns null columns for what it
  /// cannot find; the UI lets the user correct everything.
  static ColumnMapping detectMapping(List<String> headerRow) {
    final header =
        headerRow.map((h) => h.toLowerCase().trim()).toList();
    int? find(List<String> hints) {
      for (final hint in hints) {
        final i = header.indexWhere((h) => h.contains(hint));
        if (i >= 0) return i;
      }
      return null;
    }

    final vehicle = find(_vehicleHints);
    final compartment = find(_compartmentHints);
    final equipment = find(_equipmentHints);
    final quantity = find(_quantityHints);

    return ColumnMapping(
      vehicleColumn: vehicle,
      compartmentColumn: compartment ?? -1,
      equipmentColumn: equipment ?? -1,
      quantityColumn: quantity,
      firstRowIsHeader: vehicle != null || compartment != null ||
          equipment != null || quantity != null,
    );
  }

  /// Applies [mapping] to [table], producing clean rows (empty rows and rows
  /// without an equipment name are dropped).
  static List<ImportRow> applyMapping(ImportTable table, ColumnMapping mapping) {
    final rows = <ImportRow>[];
    final start = mapping.firstRowIsHeader ? 1 : 0;
    String cell(List<String> cells, int? column) =>
        column == null || column < 0 || column >= cells.length
            ? ''
            : cells[column].trim();

    for (var i = start; i < table.rows.length; i++) {
      final cells = table.rows[i];
      final equipmentName = cell(cells, mapping.equipmentColumn);
      if (equipmentName.isEmpty) continue;
      final vehicleName = mapping.vehicleColumn != null
          ? cell(cells, mapping.vehicleColumn)
          : mapping.fixedVehicleName.trim();
      final compartmentLabel = cell(cells, mapping.compartmentColumn);
      if (vehicleName.isEmpty || compartmentLabel.isEmpty) continue;
      final quantityRaw = cell(cells, mapping.quantityColumn);
      final quantity = int.tryParse(
              quantityRaw.replaceAll(RegExp(r'[^0-9-]'), '')) ??
          1;
      rows.add(ImportRow(
        sourceRowIndex: i,
        vehicleName: vehicleName,
        compartmentLabel: compartmentLabel,
        equipmentName: equipmentName,
        quantity: quantity < 1 ? 1 : quantity,
      ));
    }
    return rows;
  }
}
