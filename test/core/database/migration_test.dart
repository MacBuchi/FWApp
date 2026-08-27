/// migration_test.dart – Verifies the v1→v2 schema migration keeps data intact.
library;
import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates from v1 to v9 without schema errors', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 9);
    await db.close();
  });

  test('v1 data survives the migration to v9', () async {
    final schema = await verifier.schemaAt(1);

    schema.rawDatabase
      ..execute(
          "INSERT INTO vehicles (id, name, type, created_at, updated_at) "
          "VALUES (1, 'AB-G', 'AB-G', 0, 0)")
      ..execute(
          "INSERT INTO compartments (id, vehicle_id, label, position, grid_col_span, updated_at) "
          "VALUES (1, 1, 'G1', 0, 1, 0)")
      ..execute(
          "INSERT INTO equipment_items (id, name, equipment_functions_json, "
          "deployment_scenarios_json, description, is_custom, extra_attributes_json, updated_at) "
          "VALUES (1, 'Testgerät', '[\"PSA\"]', '[]', 'Beschreibung', 0, '{}', 0)")
      ..execute(
          "INSERT INTO equipment_assignments (id, compartment_id, equipment_id, quantity, updated_at) "
          "VALUES (1, 1, 1, 2, 0)");

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final vehicle = await db.vehicleDao.getById(1);
    expect(vehicle?.name, 'AB-G');

    final equipment = await db.equipmentDao.getById(1);
    expect(equipment?.name, 'Testgerät');
    // New columns get their defaults.
    expect(equipment?.trainingQuestionsJson, '[]');
    expect(equipment?.typicalUseJson, '[]');
    expect(equipment?.shortName, isNull);

    final assignments = await db.assignmentDao.getByCompartment(1);
    expect(assignments, hasLength(1));
    expect(assignments.single.quantity, 2);

    await db.close();
  });

  test('migrates from v2 to v3 and learning progress upserts correctly',
      () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 9);

    final equipmentId = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Spineboard'));
    await db.learningDao.recordAnswer(equipmentId, correct: true);
    await db.learningDao.recordAnswer(equipmentId, correct: true);
    await db.learningDao.recordAnswer(equipmentId, correct: false);

    final progress = await db.learningDao.watchAll().first;
    expect(progress.single.correctCount, 2);
    expect(progress.single.wrongCount, 1);

    await db.close();
  });

  test('new v2 tables are usable after migration', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 9);

    final vehicleId = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'LF 10', type: 'LF'));
    final equipmentId = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Pressluftatmer'));

    final instanceId = await db.inspectionDao.insertInstance(
      EquipmentInstancesCompanion.insert(
        equipmentId: equipmentId,
        vehicleId: Value(vehicleId),
        identifier: const Value('PA 1'),
      ),
    );
    await db.inspectionDao.insertSchedule(
      InspectionSchedulesCompanion.insert(
        instanceId: instanceId,
        kind: InspectionSchedules.kindRecurring,
        title: 'Jährliche Prüfung',
        intervalMonths: const Value(12),
        dueAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );

    final due = await db.inspectionDao.watchDueSoon().first;
    expect(due, hasLength(1));
    expect(due.single.equipment.name, 'Pressluftatmer');
    expect(due.single.isOverdue(DateTime.now()), isTrue);

    final counts = await db.inspectionDao.watchDueCountsByVehicle().first;
    expect(counts[vehicleId]?.overdueCount, 1);
    expect(counts[vehicleId]?.dueSoonCount, 0);

    await db.close();
  });

  test('v4→v5: bestehende Geräte überstehen den Typ-Anschluss unverbunden',
      () async {
    // Nutzerkonzept Stufe ② (Issue #99). Der Anschluss an den geteilten
    // Typ-Bestand darf einen Bestandsdatensatz NICHT verändern: Er läuft
    // unverbunden weiter und findet seinen Typ beim ersten Typ-Sync. Ein
    // Gerät im Feld ohne Gesamtwehr bleibt für immer so.
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase.execute(
        "INSERT INTO equipment_items (id, name, equipment_functions_json, "
        "deployment_scenarios_json, description, is_custom, "
        "extra_attributes_json, training_questions_json, typical_use_json, "
        "updated_at) VALUES (1, 'Feuerwehraxt', '[]', '[]', 'Bestand', 0, "
        "'{}', '[]', '[]', 0)");

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final geraet = await db.equipmentDao.getById(1);
    expect(geraet?.name, 'Feuerwehraxt');
    expect(geraet?.description, 'Bestand');
    expect(geraet?.remoteTypeId, isNull);
    expect(geraet?.typeDirty, isFalse);

    final meta = await (db.select(db.syncMeta)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    // Kein Fenster gezogen: Der erste Typ-Sync holt alles.
    expect(meta?.lastTypeCursor, isNull);

    await db.close();
  });

  test('v5→v6: bestehende Fächer behalten alles und bekommen KEINE Seite',
      () async {
    // Issue #126. Die Seite eines vorhandenen Fachs kennt die Migration
    // nicht — sie kennt nur seinen Namen. Aus „G1" auf „Fahrerseite" zu
    // schließen ist eine Konvention, keine Tatsache; still gesetzt wäre sie
    // im Einsatz ein Griff ins falsche Fach. Die App schlägt sie stattdessen
    // sichtbar vor.
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase
      ..execute("INSERT INTO vehicles (id, name, type, created_at, updated_at) "
          "VALUES (1, 'HLF 20', 'HLF 20', 0, 0)")
      ..execute("INSERT INTO compartments (id, vehicle_id, label, position, "
          "grid_row, grid_col, grid_col_span, updated_at) "
          "VALUES (1, 1, 'G1', 0, 2, 1, 3, 0)");

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final fach = await db.compartmentDao.getById(1);
    expect(fach?.label, 'G1');
    expect(fach?.seite, isNull, reason: 'kein stiller Backfill');
    // Die Rasterangaben sind der eigentliche Bestand dieser Tabelle — geht
    // dabei etwas verloren, steht der halbe Beladeplan durcheinander.
    expect(fach?.gridRow, 2);
    expect(fach?.gridCol, 1);
    expect(fach?.gridColSpan, 3);

    await db.close();
  });

  test('v6→v7: bestehende Fächer behalten die Seite und bekommen KEINE '
      'Längsposition', () async {
    // Issue #141 — dieselbe Zurückhaltung wie bei der Seite: „G1 liegt
    // vorne" ist die verbreitete Konvention, keine Tatsache. Die Migration
    // setzt nichts; die App schlägt vor, ein Mensch bestätigt.
    final schema = await verifier.schemaAt(6);
    schema.rawDatabase
      ..execute("INSERT INTO vehicles (id, name, type, created_at, updated_at) "
          "VALUES (1, 'HLF 20', 'HLF 20', 0, 0)")
      ..execute("INSERT INTO compartments (id, vehicle_id, label, position, "
          "grid_col_span, seite, updated_at) "
          "VALUES (1, 1, 'G1', 0, 1, 'fahrerseite', 0)");

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final fach = await db.compartmentDao.getById(1);
    expect(fach?.label, 'G1');
    // Die bestätigte Seite ist der Bestand, an dem hier nichts wackeln darf.
    expect(fach?.seite, 'fahrerseite');
    expect(fach?.laengsposition, isNull, reason: 'kein stiller Backfill');

    await db.close();
  });

  test('v7→v8: Fächer behalten alles, bekommen KEIN Foto, und die '
      'Anhang-Tabelle ist leer da', () async {
    // Issues #181 und #182. Dieselbe Zurückhaltung wie bei Seite und
    // Längsposition: Die Migration erfindet kein Foto. Und die neue Tabelle
    // entsteht LEER — sie liegt außerhalb des Snapshots und füllt sich über
    // ihren eigenen Sync, nicht aus Altbestand.
    final schema = await verifier.schemaAt(7);
    schema.rawDatabase
      ..execute("INSERT INTO vehicles (id, name, type, created_at, updated_at) "
          "VALUES (1, 'HLF 20', 'HLF 20', 0, 0)")
      ..execute("INSERT INTO compartments (id, vehicle_id, label, position, "
          "grid_col_span, seite, laengsposition, updated_at) "
          "VALUES (1, 1, 'G1', 0, 1, 'fahrerseite', 'vorne', 0)");

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    final fach = await db.compartmentDao.getById(1);
    expect(fach?.label, 'G1');
    expect(fach?.seite, 'fahrerseite');
    expect(fach?.laengsposition, 'vorne');
    expect(fach?.imagePath, isNull, reason: 'kein erfundenes Foto');

    expect(await db.attachmentDao.getAll(), isEmpty);
    // Und sie ist benutzbar, nicht nur vorhanden.
    await db.attachmentDao.insertAttachment(VehicleAttachmentsCompanion.insert(
        vehicleId: 1, title: 'Betriebsanleitung'));
    expect(await db.attachmentDao.getByVehicle(1), hasLength(1));

    await db.close();
  });

  test('v8→v9: die Wissensdatenbank entsteht leer und benutzbar', () async {
    // Issue #174. Der Grundstock kommt NICHT aus der Migration, sondern beim
    // ersten Start aus dem Asset — sonst läge die Einordnung der Fragen in
    // einer Migration fest und ließe sich nie korrigieren.
    final schema = await verifier.schemaAt(8);
    schema.rawDatabase.execute(
        "INSERT INTO vehicles (id, name, type, created_at, updated_at) "
        "VALUES (1, 'HLF 20', 'HLF 20', 0, 0)");

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 9);

    expect(await db.wissenDao.getAll(), isEmpty);
    await db.wissenDao.insertFrage(WissensfragenCompanion.insert(
      gebiet: 'geraetekunde',
      frage: 'Wie lang ist ein C-Schlauch?',
      antwortenJson: const Value('["15 m","20 m"]'),
      richtig: const Value(0),
      stand: const Value('freigegeben'),
    ));
    expect(await db.wissenDao.getSpielbare(), hasLength(1));
    // Das Fahrzeug von vorher steht unangetastet da.
    expect((await db.vehicleDao.getById(1))?.name, 'HLF 20');

    await db.close();
  });
}
