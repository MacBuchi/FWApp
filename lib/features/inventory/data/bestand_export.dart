/// bestand_export.dart – Der ganze Bestand als CSV: zum Archivieren und zum
/// Einlesen in fremde Systeme (Issue #176).
///
/// **Was das von `inventory_export.dart` unterscheidet.** Der Inventurbericht
/// beantwortet „was war am 22.09. in diesem Fahrzeug da?". Diese Datei
/// beantwortet „was hat die Wehr?" — der volle Bestand mit Fahrzeug, Fach,
/// Gerät, Einheit, Codes und Prüfterminen. Das eine ist ein Beleg, das
/// andere ein Verzeichnis.
///
/// **Warum herstellerneutral.** Der Wunsch nannte „die gängigen
/// Austauschformate der Hauptanbieter". Ohne den Namen eines konkreten
/// Systems wäre jedes Format geraten — und ein erfundenes Format importiert
/// hinterher niemand. Eine breite, sauber benannte Tabelle ist das, was jedes
/// dieser Systeme einlesen kann; ein konkretes Anbieterformat ist danach eine
/// **Zuordnung** von Spalten, kein Neubau.
///
/// **Die Zeilenregel, und warum sie so ist.** Eine Zeile ist ein Gegenstand,
/// so wie die App ihn kennt:
///
///  * Gibt es zu einem Gerät in diesem Fach **geführte Einheiten**, ist jede
///    Einheit eine Zeile mit Anzahl 1 — nur dort stehen Kennung, Codes und
///    Prüftermine, und nur einzeln sind sie etwas wert.
///  * Was an der Stückzahl darüber hinaus im Fach liegt, kommt als **eine**
///    Sammelzeile dazu (Anzahl = Rest, Einheit leer). Zehn Schlauchbinder
///    führt niemand einzeln.
///
/// Damit gilt: **Die Summe der Anzahl je Zuordnung ist die Stückzahl.** Das
/// ist die Eigenschaft, an der ein aufnehmendes System hängt, und sie ist
/// geprüft.
///
/// **Was NICHT im Fahrzeug liegt, fehlt trotzdem nicht.** Einheiten ohne
/// Fach — im Lager, in Reparatur, dem Fahrzeug noch nicht zugeordnet — stehen
/// am Ende unter [kOhneFahrzeug]. Ein Verzeichnis, das sie wegließe, wäre
/// beim Archivieren falsch.
///
/// **Kein Vorspann über der Kopfzeile**, aus demselben Grund wie beim
/// Inventurbericht: Er macht die Datei für jede Tabellenkalkulation und jeden
/// Importer kaputt, weil die Kopfzeile dann nicht mehr die erste Zeile ist.
library;

import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/export/csv_datei.dart';

/// Wohin Einheiten kommen, die an keinem Fahrzeug hängen.
const kOhneFahrzeug = 'Lager';

/// Kopfzeile des Bestands-Exports. Eigene Konstante, weil der Test sie prüft
/// — und weil ein aufnehmendes System daran seine Zuordnung festmacht.
const kBestandCsvKopf = [
  'Fahrzeug',
  'Kennzeichen',
  'Fach',
  'Gerät',
  'Kurzname',
  'Anzahl',
  'Einheit',
  'Codes',
  'Prüfungen',
  'Notiz',
];

/// Baut den vollständigen Bestand als CSV.
///
/// Nimmt fertige Listen statt einer Datenbank: So lässt sich die Zeilenregel
/// prüfen, ohne einen Bestand aufzubauen — und genau dort liegt der Fehler,
/// der niemandem auffällt.
String bestandCsv({
  required List<VehicleData> fahrzeuge,
  required List<CompartmentData> faecher,
  required List<AssignmentData> zuordnungen,
  required List<EquipmentItemData> geraete,
  required List<EquipmentInstanceData> einheiten,
  required List<EquipmentTagData> codes,
  required List<InspectionScheduleData> pruefungen,
}) {
  final geraetNachId = {for (final g in geraete) g.id: g};
  final codesNachEinheit = <int, List<String>>{};
  for (final c in codes) {
    (codesNachEinheit[c.instanceId] ??= []).add(c.code);
  }
  final pruefungNachEinheit = <int, List<InspectionScheduleData>>{};
  for (final p in pruefungen) {
    (pruefungNachEinheit[p.instanceId] ??= []).add(p);
  }

  List<String> zeile({
    required String fahrzeug,
    required String kennzeichen,
    required String fach,
    required EquipmentItemData? geraet,
    required int anzahl,
    EquipmentInstanceData? einheit,
  }) =>
      [
        fahrzeug,
        kennzeichen,
        fach,
        geraet?.name ?? '',
        geraet?.shortName ?? '',
        '$anzahl',
        einheit?.identifier ?? '',
        // Leerzeichen als Trenner ist hier eindeutig: `normalisiereTagCode`
        // wirft JEDEN Leerraum aus einem Code, auch den mittendrin.
        (codesNachEinheit[einheit?.id] ?? const []).join(' '),
        (pruefungNachEinheit[einheit?.id] ?? const [])
            .map((p) => '${p.title}: ${csvDatum(p.dueAt)}')
            .join(' | '),
        einheit?.notes ?? '',
      ];

  final zeilen = <List<String>>[kBestandCsvKopf];
  final verbuchteEinheiten = <int>{};

  for (final f in fahrzeuge) {
    final meineFaecher = faecher.where((c) => c.vehicleId == f.id).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final fach in meineFaecher) {
      final meine = zuordnungen.where((z) => z.compartmentId == fach.id);
      for (final z in meine) {
        final geraet = geraetNachId[z.equipmentId];
        // Nur Einheiten, die WIRKLICH in diesem Fach stehen: Dasselbe Gerät
        // kann in zwei Fächern liegen, und die Einheit ist die genauere
        // Angabe — dieselbe Regel wie beim Abhaken.
        final meineEinheiten = einheiten
            .where((e) =>
                e.equipmentId == z.equipmentId && e.compartmentId == fach.id)
            .toList()
          ..sort((a, b) => (a.identifier ?? '').compareTo(b.identifier ?? ''));

        for (final e in meineEinheiten) {
          verbuchteEinheiten.add(e.id);
          zeilen.add(zeile(
            fahrzeug: f.name,
            kennzeichen: f.licensePlate ?? '',
            fach: fach.label,
            geraet: geraet,
            anzahl: 1,
            einheit: e,
          ));
        }

        final rest = z.quantity - meineEinheiten.length;
        if (rest > 0) {
          zeilen.add(zeile(
            fahrzeug: f.name,
            kennzeichen: f.licensePlate ?? '',
            fach: fach.label,
            geraet: geraet,
            anzahl: rest,
          ));
        }
      }
    }
  }

  // Was an keinem Fach hängt — Lager, Reparatur, noch nicht zugeordnet.
  final uebrige = einheiten
      .where((e) => !verbuchteEinheiten.contains(e.id))
      .toList()
    ..sort((a, b) => (a.identifier ?? '').compareTo(b.identifier ?? ''));
  for (final e in uebrige) {
    zeilen.add(zeile(
      fahrzeug: kOhneFahrzeug,
      kennzeichen: '',
      fach: '',
      geraet: geraetNachId[e.equipmentId],
      anzahl: 1,
      einheit: e,
    ));
  }

  return alsCsvDatei(zeilen);
}

/// Dateiname für den Anhang.
String bestandDateiname({String? wehr, required DateTime zeitpunkt}) {
  final rumpf = dateinameRumpf(wehr ?? '', wennLeer: 'wehr');
  return 'bestand-$rumpf-${dateinameDatum(zeitpunkt)}.csv';
}
