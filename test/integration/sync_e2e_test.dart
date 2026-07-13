/// sync_e2e_test.dart – End-to-end sync test against the LOCAL Supabase stack
/// (`supabase start`). Skips itself when the stack is not running.
///
/// Requires the test users created for local dev:
///   admin@fw.local / test1234  (profiles.role = 'admin')
///   member@fw.local / test1234 (profiles.role = 'member')
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
          (e) => e.message, 'message', contains('admin role required'))),
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
}
