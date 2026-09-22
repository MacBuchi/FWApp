/// snapshot_verlust_test.dart – Was ein Zug löschen würde (Issue #214).
///
/// Der Fall dahinter: eine angelegte, aber nie veröffentlichte
/// Geräte-Einheit, ein Tipp auf „Jetzt aktualisieren" — und sie war weg,
/// ohne Frage und ohne Hinweis.
///
/// Geprüft wird beides, und das zweite ist das wichtigere: dass gezählt
/// wird, was wirklich verschwände, **und dass bei einem gewöhnlichen Zug
/// nichts gezählt wird**. Eine Warnung, die immer kommt, warnt vor nichts.
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

  test('ein lokal angelegtes Fahrzeug wird gezählt', () async {
    await fahrzeug('HLF 20');
    final verlust = await berechneVerlust(db, snapshot());

    expect(verlust.istNichts, isFalse);
    expect(verlust.jeTabelle['vehicles'], 1);
    expect(verlust.beschreibung, '1 Fahrzeug');
  });

  test('genau der Fall aus #214: die unveröffentlichte Einheit', () async {
    // Gerät und Fahrzeug stehen auf dem Server, die Einheit nicht — sie
    // wurde hier angelegt und nie veröffentlicht.
    final v = await fahrzeug('HLF 20');
    final g = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Tauchpumpe'));
    await einheit(g, 'TP 2');

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

    final verlust = await berechneVerlust(db, snapshot());

    expect(verlust.beschreibung,
        '1 Fahrzeug, 1 Fach, 1 Gerät und 1 Geräte-Einheit');
  });

  test('Einzahl und Mehrzahl stimmen', () async {
    final g = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Tauchpumpe'));
    await einheit(g, 'TP 1');
    expect((await berechneVerlust(db, snapshot(geraete: [g]))).beschreibung,
        '1 Geräte-Einheit');

    await einheit(g, 'TP 2');
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
