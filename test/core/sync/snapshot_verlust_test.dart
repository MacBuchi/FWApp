/// snapshot_verlust_test.dart – Was ein Zug löschen würde (Issue #214).
///
/// Der Fall dahinter: eine angelegte, aber nie veröffentlichte
/// Geräte-Einheit, ein Tipp auf „Jetzt aktualisieren" — und sie war weg,
/// ohne Frage und ohne Hinweis.
///
/// Geprüft wird beides, und das zweite ist das wichtigere: dass gezählt
/// wird, was wirklich verschwände, **und dass bei einem gewöhnlichen Zug
/// nichts gezählt wird**. Eine Warnung, die immer kommt, warnt vor nichts.
///
/// ⚠️ **Seit #67 heißt „Verlust" etwas anderes.** Was hier entstand und nie
/// veröffentlicht wurde, überlebt den Zug — gezählt wird nur noch, was schon
/// einmal oben war und dort inzwischen fehlt. Also: was jemand anders
/// gelöscht hat. Deshalb steht in fast jedem Fall unten ein
/// `alsVeroeffentlicht()`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/snapshot_verlust.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  /// Eine Nutzlast, wie der Server sie liefert — nur die IDs zählen hier.
  Map<String, List<Map<String, dynamic>>> snapshot({
    List<int> fahrzeuge = const [],
    List<int> faecher = const [],
    List<int> geraete = const [],
    List<int> einheiten = const [],
  }) =>
      {
        'vehicles': [for (final id in fahrzeuge) {'id': id}],
        'compartments': [for (final id in faecher) {'id': id}],
        'equipment_items': [for (final id in geraete) {'id': id}],
        'equipment_assignments': const [],
        'equipment_instances': [for (final id in einheiten) {'id': id}],
        'inspection_schedules': const [],
        'inspection_log': const [],
      };

  Future<int> fahrzeug(String name) => db.vehicleDao
      .insertVehicle(VehiclesCompanion.insert(name: name, type: 'HLF'));

  /// Setzt alles auf „war schon oben" — das tut sonst ein erfolgreiches
  /// Veröffentlichen. Ohne das zählt seit #67 gar nichts mehr als Verlust.
  Future<void> alsVeroeffentlicht() async {
    for (final name in [
      'vehicles',
      'equipment_items',
      'compartments',
      'equipment_assignments',
      'equipment_instances',
      'inspection_schedules',
      'inspection_log',
    ]) {
      await db.customStatement('UPDATE $name SET dirty = 0');
    }
  }

  Future<int> einheit(int geraetId, String kennung) =>
      db.inspectionDao.insertInstance(EquipmentInstancesCompanion.insert(
          equipmentId: geraetId, identifier: Value(kennung)));

  test('was der Server kennt, geht nicht verloren', () async {
    // ⚠️ Der wichtigste Fall: der gewöhnliche Zug. Käme hier eine Warnung,
    // wäre sie nach dem dritten Mal ein Reflex zum Wegklicken.
    final id = await fahrzeug('HLF 20');
    final verlust = await berechneVerlust(db, snapshot(fahrzeuge: [id]));

    expect(verlust.istNichts, isTrue);
    expect(verlust.gesamt, 0);
  });

  test('⚠️ was hier entstand und nie oben war, zählt NICHT als Verlust',
      () async {
    // Der Kern von #67: Der Zug behält es. Würde es hier gezählt, fragte die
    // App bei jedem gemeinsamen Erfassen nach einem Verlust, den es nicht
    // gibt — und der Zweite klickte die Warnung weg, die ihn einmal wirklich
    // schützen soll.
    await fahrzeug('MTW Probe');
    final verlust = await berechneVerlust(db, snapshot());

    expect(verlust.istNichts, isTrue);
  });

  test('ein Fahrzeug, das jemand anders gelöscht hat, wird gezählt', () async {
    await fahrzeug('HLF 20');
    await alsVeroeffentlicht();
    final verlust = await berechneVerlust(db, snapshot());

    expect(verlust.istNichts, isFalse);
    expect(verlust.jeTabelle['vehicles'], 1);
    expect(verlust.beschreibung, '1 Fahrzeug');
  });

  test('eine Einheit, die es oben nicht mehr gibt', () async {
    // Gerät und Fahrzeug stehen auf dem Server, die Einheit nicht mehr —
    // jemand anders hat sie entfernt. (Bis #67 war das auch der Fall einer
    // hier angelegten, nie veröffentlichten Einheit; die überlebt den Zug
    // inzwischen — siehe oben.)
    final v = await fahrzeug('HLF 20');
    final g = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Tauchpumpe'));
    await einheit(g, 'TP 2');
    await alsVeroeffentlicht();

    final verlust = await berechneVerlust(
        db, snapshot(fahrzeuge: [v], geraete: [g]));

    expect(verlust.jeTabelle['equipment_instances'], 1);
    expect(verlust.beschreibung, '1 Geräte-Einheit');
  });

  test('mehrere Sorten werden zu einem lesbaren Satz', () async {
    await fahrzeug('HLF 20');
    await fahrzeug('LF 20');
    final g = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Tauchpumpe'));
    await einheit(g, 'TP 1');
    await einheit(g, 'TP 2');
    await alsVeroeffentlicht();

    final verlust = await berechneVerlust(db, snapshot(geraete: [g]));

    expect(verlust.gesamt, 4);
    expect(verlust.beschreibung, '2 Fahrzeuge und 2 Geräte-Einheiten');
  });

  test('drei Sorten bekommen Kommas und ein „und"', () async {
    final v = await fahrzeug('HLF 20');
    await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: v, label: 'G1'));
    final g = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Tauchpumpe'));
    await einheit(g, 'TP 1');
    await alsVeroeffentlicht();

    final verlust = await berechneVerlust(db, snapshot());

    expect(verlust.beschreibung,
        '1 Fahrzeug, 1 Fach, 1 Gerät und 1 Geräte-Einheit');
  });

  test('Einzahl und Mehrzahl stimmen', () async {
    final g = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Tauchpumpe'));
    await einheit(g, 'TP 1');
    await alsVeroeffentlicht();
    expect((await berechneVerlust(db, snapshot(geraete: [g]))).beschreibung,
        '1 Geräte-Einheit');

    await einheit(g, 'TP 2');
    await alsVeroeffentlicht();
    expect((await berechneVerlust(db, snapshot(geraete: [g]))).beschreibung,
        '2 Geräte-Einheiten');
  });

  test('eine leere lokale Datenbank verliert nichts', () async {
    // Der erste Start einer Schwester-Abteilung: Die Datei ist leer, der
    // Server bringt alles mit. Da gibt es nichts zu fragen.
    expect(
      (await berechneVerlust(db, snapshot(fahrzeuge: [1, 2], geraete: [7])))
          .istNichts,
      isTrue,
    );
  });
}
