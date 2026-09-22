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
/// Wie die Datei technisch aussieht (Trenner, BOM, Datumsform), steht seit
/// dem Bestands-Export in `core/export/csv_datei.dart` — beide müssen
/// dieselbe Datei erzeugen.
library;

import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/export/csv_datei.dart';

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
  final datum = csvDatum(zeitpunkt);
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

  return alsCsvDatei(zeilen);
}

/// Dateiname für den Anhang: sprechend und ohne Zeichen, die ein Mailer oder
/// ein Dateisystem nicht mag.
String inventurDateiname({
  required String fahrzeug,
  required DateTime zeitpunkt,
}) {
  final rumpf = dateinameRumpf(fahrzeug, wennLeer: 'fahrzeug');
  return 'inventur-$rumpf-${dateinameDatum(zeitpunkt)}.csv';
}
