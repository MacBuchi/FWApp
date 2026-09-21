/// inventory_export_test.dart – Der Inventurbericht als CSV (Issue #178).
///
/// Geprüft wird, was an der Datei später niemand mehr nachsehen kann: dass
/// eine Notiz mit Semikolon die Spalten nicht verschiebt, dass „nicht
/// nachgezählt" und „null Stück" zwei verschiedene Zellen sind, und dass das
/// BOM vorne steht — ohne das zeigt Excel aus „beschädigt" Buchstabensalat.
library;

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inventory/data/inventory_export.dart';

InventoryCheckData _check({
  required String fach,
  required String geraet,
  int soll = 1,
  int? ist,
  String status = InventoryChecks.statusOk,
  String note = '',
}) =>
    InventoryCheckData(
      id: 1,
      sessionId: 1,
      equipmentName: geraet,
      compartmentLabel: fach,
      targetQuantity: soll,
      actualQuantity: ist,
      status: status,
      note: note,
      // Für den Export ohne Belang — er liest Soll, Ist und Zustand.
      countedInstancesJson: '[]',
    );

/// Liest die erzeugte Datei so, wie eine Tabellenkalkulation sie läse.
List<List<dynamic>> _zurueckgelesen(String csv) => const CsvDecoder(
      fieldDelimiter: ';',
      dynamicTyping: false,
    ).convert(csv.replaceFirst('﻿', ''));

void main() {
  final zeitpunkt = DateTime(2026, 9, 21, 14, 30);

  group('inventurCsv', () {
    test('beginnt mit dem BOM, sonst verstümmelt Excel die Umlaute', () {
      final csv = inventurCsv(
        fahrzeug: 'HLF 20',
        zeitpunkt: zeitpunkt,
        checks: [_check(fach: 'G1', geraet: 'Strahlrohr')],
      );
      expect(csv.codeUnitAt(0), 0xFEFF);
    });

    test('schreibt die Kopfzeile als erste Zeile', () {
      final csv = inventurCsv(
        fahrzeug: 'HLF 20',
        zeitpunkt: zeitpunkt,
        checks: [_check(fach: 'G1', geraet: 'Strahlrohr')],
      );
      expect(_zurueckgelesen(csv).first, kInventurCsvKopf);
    });

    test('trägt Fahrzeug und Datum in jede Zeile', () {
      final csv = inventurCsv(
        fahrzeug: 'HLF 20',
        zeitpunkt: zeitpunkt,
        checks: [
          _check(fach: 'G1', geraet: 'Strahlrohr'),
          _check(fach: 'G2', geraet: 'Verteiler'),
        ],
      );
      final zeilen = _zurueckgelesen(csv).skip(1);
      expect(zeilen, hasLength(2));
      for (final z in zeilen) {
        expect(z[0], 'HLF 20');
        expect(z[1], '21.09.2026');
      }
    });

    test('eine Notiz mit Semikolon verschiebt die Spalten nicht', () {
      final csv = inventurCsv(
        fahrzeug: 'HLF 20',
        zeitpunkt: zeitpunkt,
        checks: [
          _check(
            fach: 'G1',
            geraet: 'Rettungsschere',
            status: InventoryChecks.statusDamaged,
            note: 'Dichtung porös; Hydraulik prüfen',
          ),
        ],
      );
      final zeile = _zurueckgelesen(csv)[1];
      expect(zeile, hasLength(kInventurCsvKopf.length));
      expect(zeile.last, 'Dichtung porös; Hydraulik prüfen');
    });

    test('eine Notiz mit Zeilenumbruch bleibt eine Zeile', () {
      final csv = inventurCsv(
        fahrzeug: 'HLF 20',
        zeitpunkt: zeitpunkt,
        checks: [
          _check(
            fach: 'G1',
            geraet: 'Pumpe',
            status: InventoryChecks.statusRepair,
            note: 'abgegeben\nRückgabe offen',
          ),
        ],
      );
      final zeilen = _zurueckgelesen(csv);
      expect(zeilen, hasLength(2));
      expect(zeilen[1].last, 'abgegeben\nRückgabe offen');
    });

    test('nicht nachgezähltes Ist bleibt leer und wird nicht zu 0', () {
      final csv = inventurCsv(
        fahrzeug: 'HLF 20',
        zeitpunkt: zeitpunkt,
        checks: [
          _check(fach: 'G1', geraet: 'Ungeprüft', soll: 2),
          _check(fach: 'G1', geraet: 'Wirklich keins', soll: 2, ist: 0),
        ],
      );
      final zeilen = _zurueckgelesen(csv);
      expect(zeilen[1][5], '');
      expect(zeilen[2][5], '0');
    });

    test('schreibt den Status in Worten, nicht den rohen Schlüssel', () {
      final csv = inventurCsv(
        fahrzeug: 'HLF 20',
        zeitpunkt: zeitpunkt,
        checks: [
          _check(fach: 'G1', geraet: 'A', status: InventoryChecks.statusOk),
          _check(
              fach: 'G1', geraet: 'B', status: InventoryChecks.statusMissing),
          _check(
              fach: 'G1', geraet: 'C', status: InventoryChecks.statusDamaged),
          _check(fach: 'G1', geraet: 'D', status: InventoryChecks.statusRepair),
          _check(fach: 'G1', geraet: 'E', status: InventoryChecks.statusOpen),
        ],
      );
      final status = _zurueckgelesen(csv).skip(1).map((z) => z[6]).toList();
      expect(status, [
        'i.O.',
        'fehlt',
        'beschädigt',
        'in Reparatur',
        'nicht geprüft',
      ]);
    });

    test('ohne Prüfzeilen bleibt die Kopfzeile stehen', () {
      final csv =
          inventurCsv(fahrzeug: 'HLF 20', zeitpunkt: zeitpunkt, checks: []);
      expect(_zurueckgelesen(csv), [kInventurCsvKopf]);
    });
  });

  group('inventurDateiname', () {
    test('macht aus dem Fahrzeugnamen einen brauchbaren Dateinamen', () {
      expect(
        inventurDateiname(fahrzeug: 'HLF 20/1', zeitpunkt: zeitpunkt),
        'inventur-hlf-20-1-2026-09-21.csv',
      );
    });

    test('sortiert nach Datum: Jahr zuerst', () {
      final name =
          inventurDateiname(fahrzeug: 'LF 20', zeitpunkt: DateTime(2026, 1, 5));
      expect(name, endsWith('2026-01-05.csv'));
    });

    test('ein Name ohne verwertbare Zeichen fällt nicht auf leer zurück', () {
      expect(
        inventurDateiname(fahrzeug: '—/—', zeitpunkt: zeitpunkt),
        'inventur-fahrzeug-2026-09-21.csv',
      );
    });
  });
}
