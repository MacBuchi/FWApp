/// import_parser_test.dart – CSV/Excel parsing, delimiter and column detection.
library;
import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/import/data/import_parser.dart';
import 'package:fwapp/features/import/domain/import_models.dart';

void main() {
  group('detectDelimiter', () {
    test('prefers semicolon in German lists', () {
      expect(
          ImportParser.detectDelimiter(
              'Gegenstand;Stückzahl;Lagerort\nBindeleine, 20m;2;G1'),
          ';');
    });

    test('detects comma and tab', () {
      expect(ImportParser.detectDelimiter('a,b,c\nd,e,f'), ',');
      expect(ImportParser.detectDelimiter('a\tb\tc\nd\te\tf'), '\t');
    });
  });

  group('CSV parsing', () {
    test('handles UTF-8 BOM, umlauts and quoted delimiters', () {
      final csv = '\u{FEFF}Gegenstand;Stückzahl;Lagerort\n'
          '"Bindeleine; 20m";2;G1\n'
          'Kübelspritze;1;G2\n';
      final file = ImportParser.parse('test.csv', utf8.encode(csv));
      final rows = file.tables.single.rows;
      expect(rows, hasLength(3));
      expect(rows[1][0], 'Bindeleine; 20m');
      expect(rows[2][0], 'Kübelspritze');
    });

    test('falls back to Latin-1 for old exports', () {
      final csv = 'Gerät;Menge\nKübelspritze;1\n';
      final file = ImportParser.parse('alt.csv', latin1.encode(csv));
      expect(file.tables.single.rows[1][0], 'Kübelspritze');
    });
  });

  group('Excel parsing', () {
    test('reads a generated xlsx sheet', () {
      final excel = Excel.createExcel();
      final sheet = excel.sheets.keys.first;
      excel.updateCell(sheet, CellIndex.indexByString('A1'),
          TextCellValue('Fahrzeug'));
      excel.updateCell(
          sheet, CellIndex.indexByString('B1'), TextCellValue('Fach'));
      excel.updateCell(
          sheet, CellIndex.indexByString('C1'), TextCellValue('Gerät'));
      excel.updateCell(
          sheet, CellIndex.indexByString('A2'), TextCellValue('LF 10'));
      excel.updateCell(
          sheet, CellIndex.indexByString('B2'), TextCellValue('G1'));
      excel.updateCell(sheet, CellIndex.indexByString('C2'),
          TextCellValue('Spineboard'));
      final bytes = excel.encode()!;

      final file = ImportParser.parse('plan.xlsx', bytes);
      final rows = file.tables.single.rows;
      expect(rows.first, containsAll(['Fahrzeug', 'Fach', 'Gerät']));
      expect(rows[1], containsAll(['LF 10', 'G1', 'Spineboard']));
    });
  });

  group('detectMapping', () {
    test('finds AB-G style columns (no vehicle column)', () {
      final mapping = ImportParser.detectMapping(
          ['Gegenstand', 'Stückzahl', 'Kategorie', 'Lagerort']);
      expect(mapping.equipmentColumn, 0);
      expect(mapping.quantityColumn, 1);
      expect(mapping.compartmentColumn, 3);
      expect(mapping.vehicleColumn, isNull);
      expect(mapping.firstRowIsHeader, isTrue);
    });

    test('finds English/German mixed columns', () {
      final mapping = ImportParser.detectMapping(
          ['vehicle', 'compartment', 'equipment', 'quantity']);
      expect(mapping.vehicleColumn, 0);
      expect(mapping.compartmentColumn, 1);
      expect(mapping.equipmentColumn, 2);
      expect(mapping.quantityColumn, 3);
    });
  });

  group('applyMapping', () {
    const table = ImportTable(name: 't', rows: [
      ['Gegenstand', 'Stückzahl', 'Lagerort'],
      ['Bindeleine 20m', '2', 'G1'],
      ['', '9', 'G1'], // no equipment → dropped
      ['Kübelspritze', 'ca. 3 Stk.', 'G2'], // messy quantity
      ['Werkzeugkasten', '', 'G2'], // missing quantity → 1
    ]);

    test('maps rows with fixed vehicle and cleans quantities', () {
      const mapping = ColumnMapping(
        fixedVehicleName: 'AB-G',
        compartmentColumn: 2,
        equipmentColumn: 0,
        quantityColumn: 1,
      );
      final rows = ImportParser.applyMapping(table, mapping);
      expect(rows, hasLength(3));
      expect(rows[0].vehicleName, 'AB-G');
      expect(rows[0].quantity, 2);
      expect(rows[1].equipmentName, 'Kübelspritze');
      expect(rows[1].quantity, 3);
      expect(rows[2].quantity, 1);
    });

    test('invalid mapping is flagged', () {
      const mapping =
          ColumnMapping(compartmentColumn: -1, equipmentColumn: 0);
      expect(mapping.isValid, isFalse);
      const valid = ColumnMapping(
          fixedVehicleName: 'AB-G', compartmentColumn: 2, equipmentColumn: 0);
      expect(valid.isValid, isTrue);
    });
  });
}
