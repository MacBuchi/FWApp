/// snapshot_verlust.dart – Was ein Zug löschen würde, BEVOR er es tut
/// (Issue #214).
///
/// **Der Fall.** Beim Prüfen des Tag-Syncs hatte ich eine Geräte-Einheit
/// angelegt, aber nicht veröffentlicht. Ein Tipp auf „Jetzt aktualisieren" —
/// und sie war weg. Kein Hinweis, keine Frage, nichts im Protokoll.
///
/// **Warum das kein Fehler im Sync ist.** `publish_snapshot` ist
/// Einzelschreiber: Der Server hält den gültigen Stand, und ein Zug ersetzt
/// die Tabellen der Abteilung. Was lokal entstanden und nie veröffentlicht
/// wurde, kennt der Server nicht — es fällt weg, und das ist im Modell
/// richtig. Falsch war nur, dass niemand gefragt wurde.
///
/// ⚠️ **Warum NICHT `SyncMeta.localDirty` als Gradmesser.** Das lag nahe und
/// ist falsch: Das Kennzeichen wird gesetzt, sobald IRGENDWER in eine
/// synchronisierte Tabelle schreibt — auch die App selbst. Der
/// Katalog-Seeder beim ersten Start tut es, und der Gerätetypen-Sync
/// (Stufe ②) schreibt bei JEDEM Start in `equipment_items`. Am laufenden
/// Stack nachgesehen: Die Kachel „Unveröffentlichte Änderungen vorhanden"
/// steht nach jedem Start da, ohne dass jemand etwas geändert hat.
///
/// Eine Warnung, die immer kommt, warnt vor nichts — sie wird nach dem
/// dritten Mal weggeklickt, ohne gelesen zu werden. Deshalb zählt hier
/// nicht, ob etwas geschrieben wurde, sondern **was wirklich verschwände**:
/// die lokalen Zeilen, deren ID der Server nicht kennt. Das ist genau die
/// Menge, die `_applySnapshot` löscht.
library;

import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';

/// Was ein Zug an lokalen Zeilen löschen würde, je Tabelle benannt.
class SnapshotVerlust {
  /// Wie viele Fahrzeuge, Fächer, Einheiten … verschwänden.
  final Map<String, int> jeTabelle;

  const SnapshotVerlust(this.jeTabelle);

  static const nichts = SnapshotVerlust({});

  bool get istNichts => jeTabelle.values.every((n) => n == 0);

  int get gesamt => jeTabelle.values.fold(0, (a, b) => a + b);

  /// Aufzählung für den Menschen: „2 Fahrzeuge und 5 Geräte-Einheiten".
  ///
  /// Namen und nicht Tabellenbezeichner: Wer vor der Frage steht, soll
  /// wissen, was er verliert, nicht in welcher Tabelle es lag.
  String get beschreibung {
    final teile = [
      for (final e in jeTabelle.entries)
        if (e.value > 0) '${e.value} ${_name(e.key, e.value)}',
    ];
    if (teile.isEmpty) return '';
    if (teile.length == 1) return teile.single;
    return '${teile.sublist(0, teile.length - 1).join(', ')} und ${teile.last}';
  }

  static String _name(String tabelle, int anzahl) => switch (tabelle) {
        'vehicles' => anzahl == 1 ? 'Fahrzeug' : 'Fahrzeuge',
        'compartments' => anzahl == 1 ? 'Fach' : 'Fächer',
        'equipment_items' => anzahl == 1 ? 'Gerät' : 'Geräte',
        'equipment_assignments' =>
          anzahl == 1 ? 'Zuordnung' : 'Zuordnungen',
        'equipment_instances' =>
          anzahl == 1 ? 'Geräte-Einheit' : 'Geräte-Einheiten',
        'inspection_schedules' => anzahl == 1 ? 'Prüftermin' : 'Prüftermine',
        'inspection_log' =>
          anzahl == 1 ? 'Prüfeintrag' : 'Prüfeinträge',
        _ => anzahl == 1 ? 'Eintrag' : 'Einträge',
      };
}

/// Zählt, wie viele lokale Zeilen der Snapshot [data] nicht kennt.
///
/// Dieselbe Bedingung wie in `_applySnapshot`: gelöscht wird, was nicht in
/// der Nutzlast steht. Stünde hier eine andere, wäre die Warnung eine
/// Behauptung über etwas anderes als das, was dann passiert.
Future<SnapshotVerlust> berechneVerlust(
  AppDatabase db,
  Map<String, List<Map<String, dynamic>>> data,
) async {
  Future<int> zaehle(String tabelle, TableInfo<Table, dynamic> t) async {
    final ids = (data[tabelle] ?? const [])
        .map((r) => (r['id'] as num).toInt())
        .toList();
    final spalte = t.columnsByName['id']! as GeneratedColumn<int>;
    final anzahl = countAll();
    final abfrage = db.selectOnly(t)
      ..addColumns([anzahl])
      ..where(spalte.isNotIn(ids));
    return await abfrage.map((r) => r.read(anzahl)!).getSingle();
  }

  return SnapshotVerlust({
    'vehicles': await zaehle('vehicles', db.vehicles),
    'compartments': await zaehle('compartments', db.compartments),
    'equipment_items': await zaehle('equipment_items', db.equipmentItems),
    'equipment_assignments':
        await zaehle('equipment_assignments', db.equipmentAssignments),
    'equipment_instances':
        await zaehle('equipment_instances', db.equipmentInstances),
    'inspection_schedules':
        await zaehle('inspection_schedules', db.inspectionSchedules),
    'inspection_log': await zaehle('inspection_log', db.inspectionLog),
  });
}
