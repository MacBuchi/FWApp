/// sync_e2e_test.dart – End-to-end sync test against the LOCAL Supabase stack
/// (`supabase start`). Skips itself when the stack is not running.
///
/// Requires the test users created for local dev:
///   admin@fw.local / test1234       (profiles.role = 'admin')
///   geraetewart@fw.local / test1234 (profiles.role = 'geraetewart')
///   member@fw.local / test1234      (profiles.role = 'member')
library;
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_database.dart';

const _url = 'http://127.0.0.1:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

/// Nur fürs Setzen von `dataset_meta.minimum_supported_version` im
/// Gate-Test — die App selbst hat dafür bewusst kein Recht.
///
/// Kein Geheimnis: Das ist der in jedem lokalen Supabase-Stack identische
/// Demo-Key aus der offiziellen Doku, genau wie `_anonKey` darüber und wie in
/// tool/setup_local_supabase.sh. Über die Env überschreibbar, falls jemand
/// einen abweichend konfigurierten Stack fährt.
final _serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

Future<bool> _stackAvailable() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(Uri.parse('$_url/auth/v1/health'));
    final response = await request.close();
    await response.drain<void>();
    client.close();
    return response.statusCode < 500;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  if (!await _stackAvailable()) {
    test('sync e2e', () {},
        skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).');
    return;
  }

  late AppDatabase adminDb;
  late AppDatabase memberDb;
  late SupabaseClient adminClient;
  late SupabaseClient memberClient;
  late SyncService adminSync;
  late SyncService memberSync;

  setUpAll(() async {
    adminDb = createTestDatabase();
    memberDb = createTestDatabase();
    adminClient = SupabaseClient(_url, _anonKey);
    memberClient = SupabaseClient(_url, _anonKey);
    await adminClient.auth
        .signInWithPassword(email: 'admin@fw.local', password: 'test1234');
    await memberClient.auth
        .signInWithPassword(email: 'member@fw.local', password: 'test1234');
    adminSync = SyncService(adminDb, adminClient);
    memberSync = SyncService(memberDb, memberClient);
  });

  tearDownAll(() async {
    await adminDb.close();
    await memberDb.close();
    await adminClient.dispose();
    await memberClient.dispose();
  });

  test('admin publishes, member pulls the identical dataset', () async {
    // Sync to the current central version, then reset to an empty baseline so
    // reruns against the same local stack stay deterministic.
    await adminSync.pullIfNewer(force: true);
    await adminDb.customStatement('PRAGMA foreign_keys = ON');
    await adminDb.delete(adminDb.vehicles).go();
    await adminDb.delete(adminDb.equipmentItems).go();
    await adminSync.publish();

    final vehicleId = await adminDb.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'LF 10 E2E', type: 'LF'));
    final compartmentId = await adminDb.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
    final equipmentId = await adminDb.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(name: 'Pressluftatmer E2E'));
    await adminDb.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: compartmentId,
            equipmentId: equipmentId,
            quantity: const Value(4)));
    final instanceId = await adminDb.inspectionDao.insertInstance(
        EquipmentInstancesCompanion.insert(
            equipmentId: equipmentId,
            vehicleId: Value(vehicleId),
            identifier: const Value('PA 1')));
    await adminDb.inspectionDao.insertSchedule(
        InspectionSchedulesCompanion.insert(
            instanceId: instanceId,
            kind: 'recurring',
            title: 'Jährliche Prüfung',
            intervalMonths: const Value(12),
            dueAt: DateTime(2027, 1, 15)));

    final published = await adminSync.publish();
    expect(published, greaterThan(0));

    final pulled = await memberSync.pullIfNewer();
    expect(pulled, published);

    final vehicles = await memberDb.vehicleDao.getAll();
    expect(vehicles.map((v) => v.name), contains('LF 10 E2E'));

    final equipment = await memberDb.equipmentDao.getAll();
    expect(equipment.map((e) => e.name), contains('Pressluftatmer E2E'));

    final assignments =
        await memberDb.assignmentDao.getByCompartment(compartmentId);
    expect(assignments.single.quantity, 4);

    final due = await memberDb.inspectionDao.watchDueSoon(
        withinDays: 10000).first;
    expect(due.single.schedule.title, 'Jährliche Prüfung');
    expect(due.single.schedule.dueAt, DateTime(2027, 1, 15));

    // Second pull without central change is a no-op.
    expect(await memberSync.pullIfNewer(), isNull);
  });

  test('member cannot write directly (RLS) nor publish (RPC role check)',
      () async {
    await expectLater(
      memberClient
          .from('vehicles')
          .insert({'id': 99999, 'name': 'Hack', 'type': 'X'}),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      memberSync.publish(),
      throwsA(isA<PostgrestException>().having(
          (e) => e.message, 'message', contains('editor role'))),
    );
  });

  test('stale publish is rejected with a version conflict', () async {
    // Simulate a second admin device that published in between: reset the
    // local base version below the central one.
    await (adminDb.update(adminDb.syncMeta)
          ..where((t) => t.id.equals(1)))
        .write(const SyncMetaCompanion(lastPulledVersion: Value(0)));
    await expectLater(
      adminSync.publish(),
      throwsA(isA<PostgrestException>().having(
          (e) => e.message, 'message', contains('version conflict'))),
    );
  });

  test('pull removes rows that were deleted centrally', () async {
    await adminSync.pullIfNewer(force: true); // re-sync base version
    final vehicles = await adminDb.vehicleDao.getAll();
    final target = vehicles.firstWhere((v) => v.name == 'LF 10 E2E');
    await adminDb.vehicleDao.deleteVehicle(target.id);
    await adminSync.publish();

    await memberSync.pullIfNewer();
    final memberVehicles = await memberDb.vehicleDao.getAll();
    expect(memberVehicles.map((v) => v.name), isNot(contains('LF 10 E2E')));
    // Cascade: its compartments/assignments are gone too.
    final compartments =
        await memberDb.compartmentDao.getByVehicle(target.id);
    expect(compartments, isEmpty);
  });

  test('geraetewart may publish (M7 editor role), member pulls it', () async {
    final gwDb = createTestDatabase();
    final gwClient = SupabaseClient(_url, _anonKey);
    addTearDown(() async {
      await gwDb.close();
      await gwClient.dispose();
    });
    await gwClient.auth.signInWithPassword(
        email: 'geraetewart@fw.local', password: 'test1234');
    final gwSync = SyncService(gwDb, gwClient);

    await gwSync.pullIfNewer(force: true);
    await gwDb.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'MTW GW-E2E', type: 'MTW'));
    final published = await gwSync.publish();
    expect(published, greaterThan(0));

    await memberSync.pullIfNewer();
    final memberVehicles = await memberDb.vehicleDao.getAll();
    expect(memberVehicles.map((v) => v.name), contains('MTW GW-E2E'));
  });

  // ── Mindestversions-Gate (Issue #35) ────────────────────────
  //
  // Der gefährliche Pfad ist publish(), nicht der Pull: Ein zu alter Client
  // baut den Snapshot aus seiner lokalen DB, und jsonb_populate_recordset
  // setzt ihm unbekannte Spalten kommentarlos auf NULL — danach wäre eine neu
  // hinzugekommene Sync-Spalte für die ganze Wehr leer.
  //
  // Diese Tests laufen gegen die echte SQL-Funktion, weil genau dort die
  // Entscheidung fällt. Ein nachgebauter Fake würde die Frage nicht beweisen.

  group('Mindestversions-Gate', () {
    /// Setzt das Minimum über den Service-Role-Key (die App darf das nicht).
    Future<void> setMinimum(String? version) async {
      final admin = SupabaseClient(_url, _serviceRoleKey);
      try {
        await admin
            .from('dataset_meta')
            .update({'minimum_supported_version': version}).eq('id', 1);
      } finally {
        await admin.dispose();
      }
    }

    // Nach jedem Test das Gate wieder entschärfen, sonst hängen die übrigen
    // E2E-Tests am selben Stack fest.
    tearDown(() => setMinimum(null));

    Future<SyncService> editorSync(String? appVersion) async {
      final db = createTestDatabase();
      final client = SupabaseClient(_url, _anonKey);
      addTearDown(() async {
        await db.close();
        await client.dispose();
      });
      await client.auth.signInWithPassword(
          email: 'geraetewart@fw.local', password: 'test1234');
      final sync = SyncService(db, client, appVersion: appVersion);
      await sync.pullIfNewer(force: true);
      return sync;
    }

    test('ohne gesetztes Minimum darf auch eine uralte Version publizieren',
        () async {
      // Aussperr-Schutz 1: Die Migration allein ändert nichts am Verhalten.
      await setMinimum(null);
      final sync = await editorSync('0.0.1');
      expect(await sync.publish(), greaterThan(0));
    });

    test('zu alte Version wird abgelehnt', () async {
      await setMinimum('99.0.0');
      final sync = await editorSync('1.0.0');
      await expectLater(sync.publish(), throwsA(isA<OutdatedClientException>()));
    });

    test('Version genau auf dem Minimum darf publizieren', () async {
      await setMinimum('2.0.0');
      final sync = await editorSync('2.0.0');
      expect(await sync.publish(), greaterThan(0));
    });

    test('neuere Version darf publizieren', () async {
      await setMinimum('2.0.0');
      final sync = await editorSync('2.0.1');
      expect(await sync.publish(), greaterThan(0));
    });

    test('1.10.0 gilt als neuer als 1.9.9 (numerisch, nicht alphabetisch)',
        () async {
      await setMinimum('1.9.9');
      final sync = await editorSync('1.10.0');
      expect(await sync.publish(), greaterThan(0));
    });

    test('Client ohne bekannte Version wird abgelehnt', () async {
      // Entspricht einem Alt-Client, der client_version noch nicht kennt.
      await setMinimum('1.0.0');
      final sync = await editorSync(null);
      await expectLater(sync.publish(), throwsA(isA<OutdatedClientException>()));
    });

    test('Abweisung sperrt NUR das Publizieren, nicht das Lesen', () async {
      // Aussperr-Schutz 2 und der Kern von local-first: Wer nicht publizieren
      // darf, muss trotzdem arbeiten und lesen können.
      await setMinimum('99.0.0');
      final sync = await editorSync('1.0.0');

      await expectLater(sync.publish(), throwsA(isA<OutdatedClientException>()));

      // Pull geht weiter — und wirft nicht.
      await expectLater(sync.pullIfNewer(force: true), completes);
    });

    test('lokale Daten überleben eine Abweisung', () async {
      await setMinimum('99.0.0');
      final db = createTestDatabase();
      final client = SupabaseClient(_url, _anonKey);
      addTearDown(() async {
        await db.close();
        await client.dispose();
      });
      await client.auth.signInWithPassword(
          email: 'geraetewart@fw.local', password: 'test1234');
      final sync = SyncService(db, client, appVersion: '1.0.0');
      await sync.pullIfNewer(force: true);

      await db.vehicleDao.insertVehicle(
          VehiclesCompanion.insert(name: 'LF 8 Aussperrtest', type: 'LF'));
      await expectLater(sync.publish(), throwsA(isA<OutdatedClientException>()));

      // Die Arbeit des Gerätewarts darf nicht verloren gehen.
      final local = await db.vehicleDao.getAll();
      expect(local.map((v) => v.name), contains('LF 8 Aussperrtest'));
    });
  });
}
