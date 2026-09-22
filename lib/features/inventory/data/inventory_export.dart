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

import 'dart:convert';

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
  'Nicht gefunden',
  'Notiz',
];

/// Eine geführte Einheit, wie sie im Bericht benannt wird.
class InventurEinheit {
  final int id;

  /// Kennung der Einheit („Flasche 3"), falls eine vergeben ist.
  final String? kennung;

  /// Ihre Codes — beim Suchen ist der Aufkleber die genaueste Angabe.
  final List<String> codes;

  const InventurEinheit({required this.id, this.kennung, this.codes = const []});

  /// „Flasche 3 (FW-7K2M9Q)" — was davon da ist.
  String get beschriftung {
    final name = kennung?.trim();
    final code = codes.isEmpty ? null : codes.first;
    if (name != null && name.isNotEmpty) {
      return code == null ? name : '$name ($code)';
    }
    return code ?? 'Einheit $id';
  }
}

/// Welche geführten Einheiten bei dieser Prüfzeile NICHT gefunden wurden.
///
/// **Warum das nicht immer beantwortbar ist — und dann leer bleibt.** Die
/// Menge der gezählten Einheiten entsteht nur beim Abhaken per Code
/// (`hakeCodeAb`). Wer die Stückzahl von Hand setzt, hinterlässt dort
/// nichts; die Zeile weiß dann, WIE VIELE da waren, aber nicht WELCHE.
///
/// ⚠️ Daran hängt die Ehrlichkeit des Berichts: Wäre die Menge leer und
/// würde trotzdem ausgewertet, stünden alle Einheiten als „nicht gefunden"
/// da — und jemand liefe los, um Dinge zu suchen, die im Fach liegen.
/// Deshalb wird nur benannt, was wirklich bekannt ist: Die Zahl der
/// gezählten Einheiten muss zur erfassten Stückzahl passen.
List<InventurEinheit> nichtGefundene(
  InventoryCheckData check,
  List<InventurEinheit> einheiten,
) {
  if (einheiten.isEmpty) return const [];
  final ist = check.actualQuantity;
  if (ist == null) return const [];

  final gezaehlt = _gezaehlteIds(check.countedInstancesJson);
  // Passt die Menge nicht zur Zahl, kam die Zahl von Hand — dann ist
  // „welche" schlicht nicht bekannt.
  if (gezaehlt.length != ist) return const [];

  return [for (final e in einheiten) if (!gezaehlt.contains(e.id)) e];
}

Set<int> _gezaehlteIds(String json) {
  try {
    return {
      for (final e in jsonDecode(json) as List) (e as num).toInt(),
    };
  } catch (_) {
    // Eine kaputte Zeile darf den Bericht nicht kosten.
    return {};
  }
}

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
/// [einheiten] sind die geführten Einheiten je Prüfzeile (Schlüssel ist
/// `InventoryCheckData.id`). Fehlen sie, bleibt die Spalte „Nicht gefunden"
/// leer — der Bericht ist dann derselbe wie vorher.
String inventurCsv({
  required String fahrzeug,
  required DateTime zeitpunkt,
  required List<InventoryCheckData> checks,
  Map<int, List<InventurEinheit>> einheiten = const {},
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
        // Die Antwort auf „wonach suche ich?" — ohne sie sagt der Bericht
        // „2 von 4", und der Gerätewart zählt das Fach noch einmal durch.
        nichtGefundene(c, einheiten[c.id] ?? const [])
            .map((e) => e.beschriftung)
            .join(', '),
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
