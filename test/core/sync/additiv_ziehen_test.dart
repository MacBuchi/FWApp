/// additiv_ziehen_test.dart – Zu zweit am selben Fahrzeug erfassen
/// (Issue #67).
///
/// **Der Abend, um den es geht.** Zwei Leute nehmen sich ein Fahrzeug vor,
/// jeder einen Geräteraum. Beide tragen ein, was darin liegt. Einer
/// veröffentlicht zuerst — und der Zweite saß bis v1.57.0 fest: Er durfte
/// nicht veröffentlichen (Versionskonflikt) und musste ziehen, und das
/// Ziehen kostete ihn seine ganze Erfassung.
///
/// ⚠️ **Der teuerste Fall ist die ID-Kollision, und sie ist der Normalfall.**
/// Beide Geräte starten vom selben Stand. Legt jeder eine Zuordnung an,
/// vergibt die lokale Datenbank bei beiden dieselbe Nummer. Ohne Ausweichen
/// ersetzte der Zug die eine durch die andere — zwei verschiedene Geräte
/// würden stillschweigend zu einem.
///
/// Geprüft wird hier der Zug gegen eine **nachgebaute** Server-Nutzlast, wie
/// `_applySnapshot` sie bekommt. Der Weg zum Server selbst steht in
/// `sync_e2e_test.dart`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../helpers/test_database.dart';

const _z = '2026-09-22T10:00:00Z';

void main() {
  late AppDatabase db;
  late SyncService sync;

  setUp(() {
    db = createTestDatabase();
    // Kein Netz noetig: Geprueft wird das Anwenden, nicht das Holen.
    sync = SyncService(db, SupabaseClient('http://127.0.0.1:1', 'anon'));
  });
  tearDown(() => db.close());

  /// Der gemeinsame Ausgangsstand: ein Fahrzeug, zwei Fächer, ein Gerät —
  /// alles veröffentlicht.
  Future<(int fahrzeug, int g1, int g2, int geraet)> ausgangsstand() async {
    final f = await db.vehicleDao.insertVehicle(
      VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF'),
    );
    final g1 = await db.compartmentDao.insertCompartment(
      CompartmentsCompanion.insert(vehicleId: f, label: 'G1'),
    );
    final g2 = await db.compartmentDao.insertCompartment(
      CompartmentsCompanion.insert(
        vehicleId: f,
        label: 'G2',
        position: const Value(1),
      ),
    );
    final g = await db.equipmentDao.insertEquipment(
      EquipmentItemsCompanion.insert(name: 'Strahlrohr'),
    );
    await _veroeffentlicht(db);
    return (f, g1, g2, g);
  }

  Map<String, List<Map<String, dynamic>>> snapshot({
    required List<int> fahrzeuge,
    required List<int> faecher,
    required List<int> geraete,
    List<Map<String, dynamic>> zuordnungen = const [],
  }) => {
    'vehicles': [
      for (final id in fahrzeuge)
        {
          'id': id,
          'name': 'HLF 20',
          'type': 'HLF',
          'created_at': _z,
          'updated_at': _z,
        },
    ],
    'equipment_items': [
      for (final id in geraete)
        {
          'id': id,
          'name': 'Strahlrohr',
          'equipment_functions_json': '[]',
          'deployment_scenarios_json': '[]',
          'description': '',
          'is_custom': false,
          'extra_attributes_json': '{}',
          'training_questions_json': '[]',
          'typical_use_json': '[]',
          'updated_at': _z,
        },
    ],
    'compartments': [
      for (final id in faecher)
        {
          'id': id,
          'vehicle_id': fahrzeuge.first,
          'label': 'G$id',
          'position': 0,
          'grid_col_span': 1,
          'updated_at': _z,
        },
    ],
    'equipment_assignments': zuordnungen,
    'equipment_instances': const [],
    'inspection_schedules': const [],
    'inspection_log': const [],
  };

  test('⚠️ die eigene Erfassung ueberlebt den Zug', () async {
    // Der Kern: B hat G2 erfasst, A hat veroeffentlicht. B zieht.
    final (f, g1, g2, g) = await ausgangsstand();
    final meine = await db.assignmentDao.insertAssignment(
      EquipmentAssignmentsCompanion.insert(
        compartmentId: g2,
        equipmentId: g,
        quantity: const Value(3),
      ),
    );

    // A's Stand: dieselbe Grundlage plus A's eigene Zuordnung in G1 — und
    // die traegt DIESELBE Nummer, weil A vom selben Stand ausging.
    await sync.wendeSnapshotAn(
      snapshot(
        fahrzeuge: [f],
        faecher: [g1, g2],
        geraete: [g],
        zuordnungen: [
          {
            'id': meine,
            'compartment_id': g1,
            'equipment_id': g,
            'quantity': 7,
            'updated_at': _z,
          },
        ],
      ),
    );

    final alle = await db.assignmentDao.getAll();
    expect(
      alle,
      hasLength(2),
      reason: 'A s Zuordnung UND die eigene muessen dastehen.',
    );
    expect(alle.where((z) => z.compartmentId == g1).single.quantity, 7);
    expect(alle.where((z) => z.compartmentId == g2).single.quantity, 3);
  });

  test('die ausgewichene Zeile bleibt unveroeffentlicht', () async {
    // Sonst raeumte der naechste Zug sie doch noch ab.
    final (f, g1, g2, g) = await ausgangsstand();
    final meine = await db.assignmentDao.insertAssignment(
      EquipmentAssignmentsCompanion.insert(compartmentId: g2, equipmentId: g),
    );
    await sync.wendeSnapshotAn(
      snapshot(
        fahrzeuge: [f],
        faecher: [g1, g2],
        geraete: [g],
        zuordnungen: [
          {
            'id': meine,
            'compartment_id': g1,
            'equipment_id': g,
            'quantity': 1,
            'updated_at': _z,
          },
        ],
      ),
    );

    final meineDanach = (await db.assignmentDao.getAll()).firstWhere(
      (z) => z.compartmentId == g2,
    );
    expect(meineDanach.dirty, isTrue);
    expect(meineDanach.id, isNot(meine), reason: 'Sie ist ausgewichen.');
    final fremde = (await db.assignmentDao.getAll()).firstWhere(
      (z) => z.compartmentId == g1,
    );
    expect(
      fremde.id,
      meine,
      reason:
          'Die gezogene behaelt ihre ID — oben '
          'IST sie dieser Schluessel.',
    );
    expect(fremde.dirty, isFalse);
  });

  test('was schon oben war und dort fehlt, faellt weg', () async {
    // Die andere Haelfte: Loeschungen muessen ankommen, sonst kaeme
    // Weggeworfenes immer wieder zurueck.
    final (f, g1, g2, g) = await ausgangsstand();
    await db.assignmentDao.insertAssignment(
      EquipmentAssignmentsCompanion.insert(compartmentId: g1, equipmentId: g),
    );
    await _veroeffentlicht(db);

    await sync.wendeSnapshotAn(
      snapshot(fahrzeuge: [f], faecher: [g1, g2], geraete: [g]),
    );

    expect(await db.assignmentDao.getAll(), isEmpty);
  });

  test('ohne Kollision wird nichts umnummeriert', () async {
    final (f, g1, g2, g) = await ausgangsstand();
    final meine = await db.assignmentDao.insertAssignment(
      EquipmentAssignmentsCompanion.insert(compartmentId: g2, equipmentId: g),
    );

    await sync.wendeSnapshotAn(
      snapshot(fahrzeuge: [f], faecher: [g1, g2], geraete: [g]),
    );

    expect((await db.assignmentDao.getAll()).single.id, meine);
  });

  test('ein ausgewichenes Elternteil nimmt seine Kinder mit', () async {
    // Geraete-Einheiten tragen Codes und Pruefungen. Wer die Einheit
    // umnummeriert und die vergisst, zerreisst genau das, was der
    // Geraetewart aufgeklebt hat.
    final (f, g1, g2, g) = await ausgangsstand();
    final einheit = await db.inspectionDao.insertInstance(
      EquipmentInstancesCompanion.insert(
        equipmentId: g,
        compartmentId: Value(g2),
        identifier: const Value('SR 2'),
      ),
    );
    await db.tagDao.insertTag(
      EquipmentTagsCompanion.insert(instanceId: einheit, code: 'FW-7K2M9Q'),
    );

    final daten = snapshot(fahrzeuge: [f], faecher: [g1, g2], geraete: [g]);
    daten['equipment_instances'] = [
      {
        'id': einheit,
        'equipment_id': g,
        'compartment_id': g1,
        'notes': '',
        'is_active': true,
        'updated_at': _z,
      },
    ];
    await sync.wendeSnapshotAn(daten);

    final tag = await db.tagDao.findByCode('FW-7K2M9Q');
    final meine = (await db.inspectionDao.getAllInstances()).firstWhere(
      (e) => e.identifier == 'SR 2',
    );
    expect(
      tag!.instanceId,
      meine.id,
      reason: 'Der Code muss der ausgewichenen Einheit folgen.',
    );
  });
}

Future<void> _veroeffentlicht(AppDatabase db) async {
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
