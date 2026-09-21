/// inventory_export.dart – Inventurbericht als CSV-Datei (Issue #178).
///
/// **Warum eine Datei und nicht der bisherige Text.** Der Abschluss konnte
/// den Bericht bisher nur in die Zwischenablage legen. Wer eine Inventur
/// belegen muss, braucht etwas, das sich anhängen, ablegen und in einer
/// Tabellenkalkulation öffnen lässt — nicht etwas, das beim nächsten
/// Kopieren verschwindet.
///
/// **Warum Fahrzeug und Datum in JEDER Zeile stehen** statt in einem Vorspann
/// über der Kopfzeile: Ein Vorspann macht die Datei für jede
/// Tabellenkalkulation und jeden Importer kaputt — die Kopfzeile ist dann
/// nicht mehr die erste Zeile. Redundanz in zwei Spalten kostet nichts und
/// hält die Datei maschinenlesbar, was für das Archivieren und den Import in
/// fremde Systeme (#176) die Voraussetzung ist.
///
/// **Warum ein BOM davor steht** (`addBom`). Ohne BOM zeigt Excel unter
/// Windows aus „Beschädigt" ein „BeschÃ¤digt". Der eigene Importer stört
/// sich nicht daran, er entfernt das BOM beim Einlesen
/// (`ImportParser._decodeText`).
library;

import 'package:csv/csv.dart';
import 'package:fwapp/core/database/app_database.dart';

/// Semikolon: deutsche Tabellenkalkulationen trennen so, und der eigene
/// Importer erkennt es ohnehin selbst.
const _trenner = ';';

/// Kopfzeile des Exports. Eigene Konstante, weil der Test sie prüft.
const kInventurCsvKopf = [
  'Fahrzeug',
  'Datum',
  'Fach',
  'Gerät',
  'Soll',
  'Ist',
  'Status',
  'Notiz',
];

/// Der Status, wie er in der Datei steht — für Menschen, nicht für Maschinen.
///
/// Bewusst nicht der rohe Schlüssel (`damaged`): Die Datei landet beim
/// Kommandanten in Excel, nicht in einem Parser.
String statusText(String status) => switch (status) {
      InventoryChecks.statusOk => 'i.O.',
      InventoryChecks.statusMissing => 'fehlt',
      InventoryChecks.statusDamaged => 'beschädigt',
      InventoryChecks.statusRepair => 'in Reparatur',
      _ => 'nicht geprüft',
    };

/// Baut den Inventurbericht als CSV.
///
/// [zeitpunkt] ist der Abschluss der Inventur, nicht der Moment des Exports —
/// ein zweimal geteilter Bericht muss zweimal dasselbe Datum tragen.
String inventurCsv({
  required String fahrzeug,
  required DateTime zeitpunkt,
  required List<InventoryCheckData> checks,
}) {
  final datum = _datum(zeitpunkt);
  final zeilen = <List<String>>[
    kInventurCsvKopf,
    for (final c in checks)
      [
        fahrzeug,
        datum,
        c.compartmentLabel,
        c.equipmentName,
        '${c.targetQuantity}',
        // Ein nicht erfasstes Ist bleibt leer statt „0": Null Stück und
        // „nicht nachgezählt" sind zwei verschiedene Aussagen.
        c.actualQuantity?.toString() ?? '',
        statusText(c.status),
        c.note,
      ],
  ];

  // Das Paket kümmert sich um Anführungszeichen, eingebettete Semikolons und
  // Zeilenumbrüche in Notizen — von Hand ist genau das die Fehlerquelle.
  const konverter = CsvEncoder(fieldDelimiter: _trenner, addBom: true);
  return konverter.convert(zeilen);
}

/// Dateiname für den Anhang: sprechend und ohne Zeichen, die ein Mailer oder
/// ein Dateisystem nicht mag.
String inventurDateiname({
  required String fahrzeug,
  required DateTime zeitpunkt,
}) {
  final rumpf = fahrzeug
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'inventur-${rumpf.isEmpty ? 'fahrzeug' : rumpf}-'
      '${_datum(zeitpunkt, trenner: '-', jahrZuerst: true)}.csv';
}

String _datum(DateTime d, {String trenner = '.', bool jahrZuerst = false}) {
  final tag = d.day.toString().padLeft(2, '0');
  final monat = d.month.toString().padLeft(2, '0');
  return jahrZuerst
      ? '${d.year}$trenner$monat$trenner$tag'
      : '$tag$trenner$monat$trenner${d.year}';
}
