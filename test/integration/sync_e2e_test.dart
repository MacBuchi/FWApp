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
import 'package:fwapp/core/sync/equipment_type_sync.dart';
import 'package:fwapp/core/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_database.dart';

import 'stack_sperre.dart';

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
    await stackSperreHolen();
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
    await stackSperreFreigeben();
  });

  /// Service-Role-Zugriff für Prüfungen und Aufbauten, die die App per RLS
  /// nicht darf — bewusst getrennt vom Weg, den der Test beweisen soll.
  Future<T> asService<T>(Future<T> Function(SupabaseClient) body) async {
    final service = SupabaseClient(_url, _serviceRoleKey);
    try {
      return await body(service);
    } finally {
      await service.dispose();
    }
  }

  Future<String> mirrorAbteilungId() => asService((s) async =>
      (await s
          .from('abteilungen')
          .select('id')
          .eq('legacy_mirror', true)
          .single())['id'] as String);

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
        CompartmentsCompanion.insert(
            vehicleId: vehicleId,
            label: 'G1',
            seite: const Value('fahrerseite')));
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

    // Die Fahrzeugseite (Issue #126) muss den Weg über den Schnappschuss
    // mitgehen — sonst sieht der Beladeplan auf jedem zweiten Gerät anders
    // aus als auf dem, an dem er gepflegt wurde. Die Publish-Funktion füllt
    // per `jsonb_populate_recordset` und zählt keine Spalten auf; genau
    // deshalb gehört das hier geprüft und nicht angenommen.
    final faecher = await memberDb.compartmentDao.getByVehicle(vehicleId);
    expect(faecher.single.label, 'G1');
    expect(faecher.single.seite, 'fahrerseite');

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

  group('Abteilungen (Issue #57 Phase 1)', () {
    test('publish stempelt jede Zeile mit der Abteilung des Veröffentlichers',
        () async {
      // Der Client schickt seine Drift-Zeilen OHNE abteilung_id — die Spalte
      // existiert lokal gar nicht. Wenn sie serverseitig fehlt, ist die
      // Mandanten-Trennung ein leeres Versprechen.
      await adminSync.pullIfNewer(force: true);
      await adminDb.vehicleDao.insertVehicle(
          VehiclesCompanion.insert(name: 'TLF Stempeltest', type: 'TLF'));
      await adminSync.publish();

      final abteilung = await mirrorAbteilungId();
      final rows = await asService((s) => s
          .from('vehicles')
          .select('name, abteilung_id')
          .eq('name', 'TLF Stempeltest'));
      expect(rows, isNotEmpty);
      expect(rows.first['abteilung_id'], abteilung);
    });

    test('Legacy-Spiegel: dataset_meta.version folgt der Spiegel-Abteilung',
        () async {
      // Alt-Clients lesen weiter dataset_meta.select().single(). Bis die
      // Mindestversion angehoben ist, muss der Zähler dort mitlaufen —
      // sonst übersehen sie neue Stände.
      await adminSync.pullIfNewer(force: true);
      final published = await adminSync.publish();

      final meta = await asService((s) async =>
          await s.from('dataset_meta').select('version').single());
      expect((meta['version'] as num).toInt(), published);
    });

    test('pending-Abteilung darf nicht veröffentlichen (Freigabe-Hebel)',
        () async {
      // Entscheidung C: Selbstregistrierte Abteilungen starten als pending.
      // Local-first heißt: lokal darf alles — nur das Veröffentlichen wartet
      // auf die Freigabe. Genau diese Sperre wird hier scharf geprüft.
      final abteilung = await mirrorAbteilungId();
      Future<void> setStatus(String status) => asService((s) async =>
          await s.from('abteilungen').update({'status': status}).eq(
              'id', abteilung));

      await adminSync.pullIfNewer(force: true);
      await setStatus('pending');
      try {
        await expectLater(
          adminSync.publish(),
          throwsA(isA<PostgrestException>().having(
              (e) => e.message, 'message', contains('not approved'))),
        );
      } finally {
        await setStatus('active');
      }

      // Nach der Freigabe klappt derselbe Publish sofort.
      expect(await adminSync.publish(), greaterThan(0));
    });

    test('Schwester-Sicht: lesen ja, veröffentlichen nein (Phase 2)',
        () async {
      // Aufbau über den Service-Role-Weg: eine Gesamtwehr, die die
      // Bestands-Abteilung und eine neue Schwester B verbindet.
      final mirror = await mirrorAbteilungId();
      final ids = await asService((s) async {
        final gw = await s
            .from('gesamtwehren')
            .insert({'name': 'GW Test', 'slug': 'gw-test'})
            .select('id')
            .single();
        final b = await s
            .from('abteilungen')
            .insert({
              'name': 'Abteilung B',
              'slug': 'abteilung-b',
              'status': 'active',
              'gesamtwehr_id': gw['id'],
            })
            .select('id')
            .single();
        await s
            .from('abteilungen')
            .update({'gesamtwehr_id': gw['id']}).eq('id', mirror);
        return (gw: gw['id'] as String, b: b['id'] as String);
      });

      try {
        // RLS zeigt dem Admin jetzt beide Abteilungen (Entscheidung A).
        final visible = await adminClient
            .from('abteilungen')
            .select('id')
            .order('name');
        expect(visible.map((r) => r['id']),
            containsAll([mirror, ids.b]));

        // Pull der Schwester-Sicht: eigener SyncService mit Override und
        // eigener (leerer) lokaler DB — wie die App nach dem Umschalten.
        final sisterDb = createTestDatabase();
        addTearDown(sisterDb.close);
        final sisterSync =
            SyncService(sisterDb, adminClient, abteilungOverride: ids.b);
        await sisterSync.pullIfNewer(force: true);
        // B ist leer — und vor allem: NICHT der Bestand der eigenen
        // Abteilung. Ein Leck würde hier Fahrzeuge zeigen.
        expect(await sisterDb.vehicleDao.getAll(), isEmpty);

        // Veröffentlichen in die Schwester lehnt der Server ab, auch für
        // den Admin ohne Gesamtwehr-Admin-Rolle... admin IST admin der
        // Gesamtwehr (gleiche gesamtwehr_id) — der darf laut Issue sogar
        // schreiben. Deshalb prüft der Sperr-Test mit dem GERÄTEWART.
        final gwDb = createTestDatabase();
        addTearDown(gwDb.close);
        final gwClient = SupabaseClient(_url, _anonKey);
        addTearDown(gwClient.dispose);
        await gwClient.auth.signInWithPassword(
            email: 'geraetewart@fw.local', password: 'test1234');
        final gwSister =
            SyncService(gwDb, gwClient, abteilungOverride: ids.b);
        await gwSister.pullIfNewer(force: true);
        await expectLater(
          gwSister.publish(),
          throwsA(isA<PostgrestException>().having(
              (e) => e.message, 'message', contains('permission denied'))),
        );
      } finally {
        await asService((s) async {
          await s
              .from('abteilungen')
              .update({'gesamtwehr_id': null}).eq('id', mirror);
          await s.from('abteilungen').delete().eq('id', ids.b);
          await s.from('gesamtwehren').delete().eq('id', ids.gw);
        });
      }
    });
  });

  group('Gesamtwehr & Verbindungen (Issue #57 Phase 3)', () {
    late String mirror;
    late SupabaseClient gwClient;

    setUp(() async {
      mirror = await mirrorAbteilungId();
      gwClient = SupabaseClient(_url, _anonKey);
      await gwClient.auth.signInWithPassword(
          email: 'geraetewart@fw.local', password: 'test1234');
    });

    // Jeder Test hinterlässt eine leere Bühne: die Phase-1-Gruppe und die
    // Wiederholung desselben Tests laufen gegen dieselbe lokale Instanz.
    tearDown(() async {
      await gwClient.dispose();
      await asService((s) async {
        await s.from('gesamtwehr_anfragen').delete().neq('status', 'nie');
        await s.from('abteilungen').delete().eq('legacy_mirror', false);
        await s
            .from('abteilungen')
            .update({'gesamtwehr_id': null}).eq('id', mirror);
        await s.from('gesamtwehren').delete().neq('name', 'nie');
        // Profile, deren Abteilung gerade gelöscht wurde (on delete set
        // null), gehören zurück in die Bestands-Abteilung.
        await s
            .from('profiles')
            .update({'abteilung_id': mirror}).filter('abteilung_id', 'is', null);
        // Mitgliedschaften wiederherstellen (Nutzerkonzept Stufe 1): Das
        // Löschen der Test-Abteilungen kaskadiert in memberships; die
        // Spiegel-Spalten am Profil sagen, was jedes Konto hatte.
        final profs = await s.from('profiles').select('id, role, abteilung_id');
        await s.from('memberships').upsert([
          for (final p in profs)
            if (p['abteilung_id'] != null)
              {
                'user_id': p['id'],
                'abteilung_id': p['abteilung_id'],
                'role': p['role'],
              },
        ], onConflict: 'user_id,abteilung_id');
      });
    });

    Future<String> gruendeGesamtwehr([String name = 'Gesamtwehr Musterstadt']) =>
        adminClient.rpc('create_gesamtwehr', params: {'name': name})
            .then((v) => v as String);

    test('Admin gründet die Gesamtwehr und nimmt seine Abteilung mit',
        () async {
      final id = await gruendeGesamtwehr();

      final gw = await asService((s) async => await s
          .from('gesamtwehren')
          .select('name, slug, created_by')
          .eq('id', id)
          .single());
      // Der Slug entsteht serverseitig — der Client soll ihn nicht erfinden.
      expect(gw['slug'], 'gesamtwehr-musterstadt');
      expect(gw['created_by'], isNotNull);

      final meine = await asService((s) async => await s
          .from('abteilungen')
          .select('gesamtwehr_id')
          .eq('id', mirror)
          .single());
      expect(meine['gesamtwehr_id'], id);

      // Ein zweites Mal gründen hieße, die eigene Abteilung aus der ersten
      // Klammer zu reißen — das muss abprallen.
      await expectLater(
        gruendeGesamtwehr('Noch eine'),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('already belongs'))),
      );
    });

    test('Gerätewart darf keine Gesamtwehr gründen', () async {
      await expectLater(
        gwClient.rpc('create_gesamtwehr', params: {'name': 'Heimlich'}),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('permission denied'))),
      );
    });

    test('Abteilung anlegen braucht die Klammer und ist danach sofort aktiv',
        () async {
      // Ohne Gesamtwehr gäbe es niemanden, der die neue Abteilung sähe —
      // deshalb verweigert der Server, statt eine Waise anzulegen.
      await expectLater(
        adminClient.rpc('create_abteilung', params: {'name': 'Abteilung Nord'}),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('gesamtwehr required'))),
      );

      final gwId = await gruendeGesamtwehr();
      final neue = await adminClient
          .rpc('create_abteilung', params: {'name': 'Abteilung Nord'}) as String;

      final row = await asService((s) async => await s
          .from('abteilungen')
          .select('name, slug, status, gesamtwehr_id, version')
          .eq('id', neue)
          .single());
      expect(row['status'], 'active', reason: 'der anlegende Admin bürgt');
      expect(row['gesamtwehr_id'], gwId);
      expect(row['slug'], 'abteilung-nord');
      expect((row['version'] as num).toInt(), 0);

      // Und sie ist sofort Schwester: RLS zeigt sie dem Admin.
      final sichtbar = await adminClient.from('abteilungen').select('id');
      expect(sichtbar.map((r) => r['id']), containsAll([mirror, neue]));
    });

    test('Namen ohne slugfähige Zeichen kollidieren nicht', () async {
      await gruendeGesamtwehr();
      final a =
          await adminClient.rpc('create_abteilung', params: {'name': '???'});
      final b =
          await adminClient.rpc('create_abteilung', params: {'name': '!!!'});
      final slugs = await asService((s) async => await s
          .from('abteilungen')
          .select('slug')
          .inFilter('id', [a as String, b as String]));
      expect(slugs.map((r) => r['slug']).toSet().length, 2,
          reason: 'zwei Abteilungen, zwei Slugs — der Unique-Index hält');
    });

    group('Anschluss-Anfrage', () {
      late String gwId;
      late String fremde;

      setUp(() async {
        gwId = await gruendeGesamtwehr();
        // Abteilung C steht noch allein da und wartet auf Freigabe; der
        // Gerätewart gehört zu ihr, nicht mehr zur Bestands-Abteilung.
        fremde = await asService((s) async {
          final c = await s
              .from('abteilungen')
              .insert({
                'name': 'Abteilung Süd',
                'slug': 'abteilung-sued',
                'status': 'pending',
              })
              .select('id')
              .single();
          await s
              .from('profiles')
              .update({'abteilung_id': c['id']}).eq(
                  'id', gwClient.auth.currentUser!.id);
          // Seit Stufe 1 zählt die Mitgliedschaft, nicht die Profil-Spalte —
          // der Umzug braucht beide (so macht es auch admin-users).
          await s.from('memberships').upsert({
            'user_id': gwClient.auth.currentUser!.id,
            'abteilung_id': c['id'],
            'role': 'geraetewart',
          }, onConflict: 'user_id,abteilung_id');
          return c['id'] as String;
        });
      });

      test('Anfrage, Freigabe, und die Freigabe hebt zugleich pending auf',
          () async {
        await gwClient.rpc('request_gesamtwehr_verbindung',
            params: {'ziel': gwId, 'nachricht': 'Wir würden gern dazu.'});

        // Vor der Freigabe darf der Admin die fremde Abteilung NICHT lesen —
        // genau deshalb braucht die Freigabe-Liste eine eigene RPC.
        final direkt =
            await adminClient.from('abteilungen').select('id').eq('id', fremde);
        expect(direkt, isEmpty);

        final offen = await adminClient.rpc('offene_verbindungsanfragen')
            as List<dynamic>;
        expect(offen, hasLength(1));
        expect(offen.first['abteilung_name'], 'Abteilung Süd');
        expect(offen.first['nachricht'], 'Wir würden gern dazu.');

        await adminClient.rpc('decide_gesamtwehr_verbindung', params: {
          'anfrage': offen.first['id'],
          'freigeben': true,
        });

        final danach = await asService((s) async => await s
            .from('abteilungen')
            .select('gesamtwehr_id, status')
            .eq('id', fremde)
            .single());
        expect(danach['gesamtwehr_id'], gwId);
        expect(danach['status'], 'active',
            reason: 'die Aufnahme IST die Freigabe');

        // Und die Liste ist leer, die Anfrage nicht zweimal entscheidbar.
        expect(await adminClient.rpc('offene_verbindungsanfragen'), isEmpty);
        await expectLater(
          adminClient.rpc('decide_gesamtwehr_verbindung',
              params: {'anfrage': offen.first['id'], 'freigeben': true}),
          throwsA(isA<PostgrestException>().having(
              (e) => e.message, 'message', contains('already decided'))),
        );
      });

      test('Ablehnen verbindet nicht und lässt die Abteilung pending',
          () async {
        await gwClient
            .rpc('request_gesamtwehr_verbindung', params: {'ziel': gwId});
        final offen = await adminClient.rpc('offene_verbindungsanfragen')
            as List<dynamic>;

        await adminClient.rpc('decide_gesamtwehr_verbindung', params: {
          'anfrage': offen.first['id'],
          'freigeben': false,
          'nachricht': 'Bitte erst im Kommandantenkreis besprechen.',
        });

        final danach = await asService((s) async => await s
            .from('abteilungen')
            .select('gesamtwehr_id, status')
            .eq('id', fremde)
            .single());
        expect(danach['gesamtwehr_id'], isNull);
        expect(danach['status'], 'pending');
      });

      test('Der Antragsteller kann sich nicht selbst freigeben', () async {
        // Der Kern der ganzen Freigabe: Wer fragt, entscheidet nicht.
        await gwClient
            .rpc('request_gesamtwehr_verbindung', params: {'ziel': gwId});
        final anfrage = await asService((s) async => await s
            .from('gesamtwehr_anfragen')
            .select('id')
            .eq('abteilung_id', fremde)
            .single());

        await expectLater(
          gwClient.rpc('decide_gesamtwehr_verbindung',
              params: {'anfrage': anfrage['id'], 'freigeben': true}),
          throwsA(isA<PostgrestException>().having(
              (e) => e.message, 'message', contains('permission denied'))),
        );
      });

      test('Zwei offene Anfragen derselben Abteilung gibt es nicht', () async {
        await gwClient
            .rpc('request_gesamtwehr_verbindung', params: {'ziel': gwId});
        await expectLater(
          gwClient.rpc('request_gesamtwehr_verbindung', params: {'ziel': gwId}),
          throwsA(isA<PostgrestException>().having(
              (e) => e.message, 'message', contains('already pending'))),
        );
      });

      test('Die anfragende Abteilung sieht ihren eigenen Antrag', () async {
        await gwClient.rpc('request_gesamtwehr_verbindung',
            params: {'ziel': gwId, 'nachricht': 'Bitte um Anschluss.'});
        final eigene = await gwClient
            .from('gesamtwehr_anfragen')
            .select('status, nachricht');
        expect(eigene, hasLength(1));
        expect(eigene.first['status'], 'pending');
      });
    });
  });

  group('Mitgliedschaften & Kommandanten (Nutzerkonzept Stufe 1, #98)', () {
    late String mirror;
    late SupabaseClient gwClient;

    setUp(() async {
      mirror = await mirrorAbteilungId();
      gwClient = SupabaseClient(_url, _anonKey);
      await gwClient.auth.signInWithPassword(
          email: 'geraetewart@fw.local', password: 'test1234');
    });

    // Bühne räumen wie in der Phase-3-Gruppe — inklusive der
    // Mitgliedschaften, die die Lösch-Kaskade mitnimmt.
    tearDown(() async {
      await gwClient.dispose();
      await asService((s) async {
        await s.from('gesamtwehr_anfragen').delete().neq('status', 'nie');
        await s.from('abteilungen').delete().eq('legacy_mirror', false);
        await s
            .from('abteilungen')
            .update({'gesamtwehr_id': null}).eq('id', mirror);
        await s.from('gesamtwehren').delete().neq('name', 'nie');
        await s
            .from('profiles')
            .update({'abteilung_id': mirror}).filter('abteilung_id', 'is', null);
        final profs = await s.from('profiles').select('id, role, abteilung_id');
        await s.from('memberships').upsert([
          for (final p in profs)
            if (p['abteilung_id'] != null)
              {
                'user_id': p['id'],
                'abteilung_id': p['abteilung_id'],
                'role': p['role'],
              },
        ], onConflict: 'user_id,abteilung_id');
      });
    });

    test('Backfill & RLS: jeder liest genau die eigenen Mitgliedschaften',
        () async {
      final eigene =
          await adminClient.from('memberships').select('abteilung_id, role');
      expect(eigene.map((r) => r['abteilung_id']), contains(mirror));
      expect(eigene.map((r) => r['role']), contains('admin'));

      // Fremde Zeilen bleiben unsichtbar — der Provider-Select in der App
      // kommt deshalb ohne Filter aus.
      final fremd = await adminClient
          .from('memberships')
          .select('user_id')
          .neq('user_id', adminClient.auth.currentUser!.id);
      expect(fremd, isEmpty);
    });

    test('der Gründer einer Gesamtwehr wird Feuerwehrkommandant', () async {
      final gwId = await adminClient
          .rpc('create_gesamtwehr', params: {'name': 'Stufe1 GW'}) as String;

      final rows = await asService((s) async => await s
          .from('gesamtwehr_kommandanten')
          .select('user_id')
          .eq('gesamtwehr_id', gwId));
      expect(rows.map((r) => r['user_id']),
          contains(adminClient.auth.currentUser!.id));

      // Die eigene Stellung ist per RLS lesbar — genau der Weg, den der
      // Client-Provider geht.
      final eigene = await adminClient
          .from('gesamtwehr_kommandanten')
          .select('gesamtwehr_id');
      expect(eigene.map((r) => r['gesamtwehr_id']), contains(gwId));
    });

    test('die Schreibrolle klebt an der Abteilung — der Kommandant darf '
        'überall', () async {
      await adminClient
          .rpc('create_gesamtwehr', params: {'name': 'Stufe1 Schreib'});
      final neue = await adminClient
          .rpc('create_abteilung', params: {'name': 'Stufe1 Nord'}) as String;

      // Gerätewart mit Mitgliedschaft NUR in der Bestands-Abteilung:
      // Veröffentlichen in die Schwester prallt ab …
      final gwDb = createTestDatabase();
      addTearDown(gwDb.close);
      final gwSister = SyncService(gwDb, gwClient, abteilungOverride: neue);
      await gwSister.pullIfNewer(force: true);
      await expectLater(
        gwSister.publish(),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('permission denied'))),
      );

      // … bis ihm dort eine Schreib-Mitgliedschaft gehört. Genau das ist
      // Marcus' Fall „dieselbe Person ist Gerätewart in zwei Abteilungen".
      await asService((s) async => await s.from('memberships').upsert({
            'user_id': gwClient.auth.currentUser!.id,
            'abteilung_id': neue,
            'role': 'geraetewart',
          }, onConflict: 'user_id,abteilung_id'));
      expect(await gwSister.publish(), greaterThan(0));

      // Der Feuerwehrkommandant braucht keine Mitgliedschaft — die
      // Gesamtwehr-Stellung genügt.
      final adminSisterDb = createTestDatabase();
      addTearDown(adminSisterDb.close);
      final adminSister =
          SyncService(adminSisterDb, adminClient, abteilungOverride: neue);
      await adminSister.pullIfNewer(force: true);
      expect(await adminSister.publish(), greaterThan(0));
    });

    test('create_abteilung verlangt den Feuerwehrkommandanten', () async {
      await adminClient
          .rpc('create_gesamtwehr', params: {'name': 'Stufe1 Guard'});
      // Der Gerätewart gehört zur Gesamtwehr, ist aber kein Kommandant.
      await expectLater(
        gwClient.rpc('create_abteilung', params: {'name': 'Heimlich Nord'}),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('permission denied'))),
      );
    });
  });

  /// Mandantenscharfe Identität im zentralen Bestand.
  ///
  /// Der Server trug die **lokalen** Drift-IDs als alleinigen
  /// Primärschlüssel, und jede lokale Datenbank zählt bei 1 los. In jedem
  /// Test davor ist die zweite Abteilung LEER — genau deshalb ist nie
  /// aufgefallen, dass sie gar nicht veröffentlichen kann und dabei den
  /// Nachbarn beschädigt. Beide Tests hier legen deshalb **feste, absichtlich
  /// gleiche IDs** an; ohne sie liefe der Beweis ins Leere, weil SQLite nach
  /// einem `delete` weiterzählt statt bei 1 neu zu beginnen.
  group('Mandantenscharfe IDs', () {
    late String mirror;
    late String schwester;

    setUp(() async {
      mirror = await mirrorAbteilungId();
      await adminClient.rpc('create_gesamtwehr', params: {'name': 'GW IDs'});
      // Der Admin ist als Gründer Feuerwehrkommandant und darf damit in
      // beiden Abteilungen veröffentlichen — Marcus' Lage.
      schwester = await adminClient
          .rpc('create_abteilung', params: {'name': 'Nord IDs'}) as String;
    });

    tearDown(() async {
      await asService((s) async {
        await s.from('abteilungen').delete().eq('legacy_mirror', false);
        await s
            .from('abteilungen')
            .update({'gesamtwehr_id': null}).eq('id', mirror);
        await s.from('gesamtwehren').delete().neq('name', 'nie');
        await s
            .from('profiles')
            .update({'abteilung_id': mirror}).filter('abteilung_id', 'is', null);
        final profs = await s.from('profiles').select('id, role, abteilung_id');
        await s.from('memberships').upsert([
          for (final p in profs)
            if (p['abteilung_id'] != null)
              {
                'user_id': p['id'],
                'abteilung_id': p['abteilung_id'],
                'role': p['role'],
              },
        ], onConflict: 'user_id,abteilung_id');
      });
    });

    /// Ein vollständiger Strang über alle sieben gespiegelten Tabellen — mit
    /// FESTEN IDs, damit beide Abteilungen garantiert dieselben Zahlen
    /// benutzen. Das ist der Kern des Beweises.
    Future<void> bestandMitFestenIds(AppDatabase db, String marke) async {
      await db.into(db.vehicles).insert(VehiclesCompanion.insert(
          id: const Value(1), name: 'Fahrzeug $marke', type: 'LF'));
      await db.into(db.compartments).insert(CompartmentsCompanion.insert(
          id: const Value(1), vehicleId: 1, label: 'G1 $marke'));
      await db.into(db.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1), name: 'Gerät $marke'));
      await db.into(db.equipmentAssignments).insert(
          EquipmentAssignmentsCompanion.insert(
              id: const Value(1),
              compartmentId: 1,
              equipmentId: 1,
              quantity: const Value(3)));
      await db.into(db.equipmentInstances).insert(
          EquipmentInstancesCompanion.insert(
              id: const Value(1),
              equipmentId: 1,
              vehicleId: const Value(1),
              identifier: Value('Nr 1 $marke')));
      await db.into(db.inspectionSchedules).insert(
          InspectionSchedulesCompanion.insert(
              id: const Value(1),
              instanceId: 1,
              kind: 'recurring',
              title: 'Prüfung $marke',
              dueAt: DateTime(2027, 6, 1)));
      await db.into(db.inspectionLog).insert(InspectionLogCompanion.insert(
          id: const Value(1), scheduleId: 1, doneAt: DateTime(2026, 6, 1)));
    }

    /// Frische lokale Datenbank plus Sync auf [abteilung], auf deren
    /// aktuellen Stand gezogen (sonst scheitert publish am Versionsvergleich).
    Future<(AppDatabase, SyncService)> sicht(String abteilung) async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final sync = SyncService(db, adminClient, abteilungOverride: abteilung);
      await sync.pullIfNewer(force: true);
      return (db, sync);
    }

    test('zwei Abteilungen veröffentlichen dieselben IDs nebeneinander',
        () async {
      final (dbA, syncA) = await sicht(mirror);
      // Leere Bühne: Der Bestand der Bestands-Abteilung stammt aus den
      // Tests davor und würde die festen IDs blockieren.
      await dbA.delete(dbA.vehicles).go();
      await dbA.delete(dbA.equipmentItems).go();
      await syncA.publish();
      await bestandMitFestenIds(dbA, 'A');
      await syncA.publish();

      // Und jetzt dieselben Zahlen aus der Schwester-Abteilung. Vor der
      // Migration endet genau hier ein Duplicate-Key-Fehler.
      final (dbB, syncB) = await sicht(schwester);
      await bestandMitFestenIds(dbB, 'B');
      expect(await syncB.publish(), greaterThan(0));

      // Jede Seite bekommt beim Pull ihren eigenen Bestand zurück, nicht den
      // der anderen — die IDs sind identisch, die Abteilung entscheidet.
      final (leseA, _) = await sicht(mirror);
      final (leseB, _) = await sicht(schwester);
      expect((await leseA.vehicleDao.getAll()).single.name, 'Fahrzeug A');
      expect((await leseB.vehicleDao.getAll()).single.name, 'Fahrzeug B');
      expect((await leseA.equipmentDao.getAll()).single.name, 'Gerät A');
      expect((await leseB.equipmentDao.getAll()).single.name, 'Gerät B');
    });

    test('Veröffentlichen einer Abteilung lässt den Nachbarn unberührt',
        () async {
      // Der schwerere der beiden Fehler: Die Fremdschlüssel zeigten OHNE
      // Abteilung auf equipment_items und standen auf `on delete cascade`.
      // Das Aufräumen vor dem Einfügen riss deshalb die Zuordnungen JEDER
      // Abteilung mit, die dieselbe Zahl benutzt.
      final (dbA, syncA) = await sicht(mirror);
      await dbA.delete(dbA.vehicles).go();
      await dbA.delete(dbA.equipmentItems).go();
      await syncA.publish();
      await bestandMitFestenIds(dbA, 'A');
      await syncA.publish();

      final (dbB, syncB) = await sicht(schwester);
      await bestandMitFestenIds(dbB, 'B');
      await syncB.publish();
      // ZWEITER Publish: Jetzt löscht der Server B's Zeilen wirklich, und
      // genau dieses Löschen kaskadierte früher in A hinein.
      await dbB.update(dbB.vehicles).write(
          const VehiclesCompanion(name: Value('Fahrzeug B zwei')));
      await syncB.publish();

      final (leseA, _) = await sicht(mirror);
      expect((await leseA.vehicleDao.getAll()).single.name, 'Fahrzeug A');
      expect((await leseA.equipmentDao.getAll()).single.name, 'Gerät A');
      expect(
        (await leseA.assignmentDao.getByCompartment(1)).single.quantity,
        3,
        reason: 'Die Zuordnung von A darf B\'s Publish nicht zum Opfer fallen',
      );
      final faellig =
          await leseA.inspectionDao.watchDueSoon(withinDays: 10000).first;
      expect(faellig.single.schedule.title, 'Prüfung A');
    });
  });

  /// Gerätetypen auf Gesamtwehr-Ebene (Nutzerkonzept Stufe ②, Issue #99).
  ///
  /// Der Snapshot bleibt je Abteilung, die TYPEN gehören der ganzen Wehr und
  /// haben einen eigenen, zeilenweisen Weg. Die Tests beweisen beide Hälften:
  /// dass zwei Abteilungen denselben Typ teilen, und dass der Weg dorthin
  /// keinen fremden Stand überschreibt.
  group('Gerätetypen auf Gesamtwehr-Ebene (Stufe ②)', () {
    late String mirror;
    late String schwester;
    late String gesamtwehr;

    setUp(() async {
      mirror = await mirrorAbteilungId();
      gesamtwehr = await adminClient
          .rpc('create_gesamtwehr', params: {'name': 'GW Typen'}) as String;
      schwester = await adminClient
          .rpc('create_abteilung', params: {'name': 'Nord Typen'}) as String;
    });

    tearDown(() async {
      await asService((s) async {
        await s.from('abteilungen').delete().eq('legacy_mirror', false);
        await s
            .from('abteilungen')
            .update({'gesamtwehr_id': null}).eq('id', mirror);
        await s.from('gesamtwehren').delete().neq('name', 'nie');
        await s
            .from('profiles')
            .update({'abteilung_id': mirror}).filter('abteilung_id', 'is', null);
        final profs = await s.from('profiles').select('id, role, abteilung_id');
        await s.from('memberships').upsert([
          for (final p in profs)
            if (p['abteilung_id'] != null)
              {
                'user_id': p['id'],
                'abteilung_id': p['abteilung_id'],
                'role': p['role'],
              },
        ], onConflict: 'user_id,abteilung_id');
      });
    });

    /// Veröffentlicht [name] als einziges Gerät der Abteilung — auf genau dem
    /// Weg, den die App HEUTE geht: Der Client kennt `type_id` nicht, die
    /// Payload trägt sie also nicht. Damit ist jeder dieser Aufrufe zugleich
    /// ein Alt-Client-Test.
    Future<AppDatabase> veroeffentlicheGeraet(
      String abteilung,
      String name, {
      String? katalogId,
    }) async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final sync = SyncService(db, adminClient, abteilungOverride: abteilung);
      await sync.pullIfNewer(force: true);
      await db.delete(db.vehicles).go();
      await db.delete(db.equipmentItems).go();
      await db.into(db.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1),
          name: name,
          libraryEquipmentId: Value(katalogId)));
      await sync.publish();
      return db;
    }

    Future<List<Map<String, dynamic>>> typen() async => asService((s) async =>
        List<Map<String, dynamic>>.from(await s
            .from('equipment_types')
            .select('id, name, library_equipment_id, deleted_at')
            .eq('gesamtwehr_id', gesamtwehr)));

    test('zwei Abteilungen laufen auf denselben Typ zusammen', () async {
      // Unterschiedliche Schreibweise, gleicher Typ — normalisiert wird nach
      // derselben Regel wie im Import-Matcher.
      await veroeffentlicheGeraet(mirror, 'C-Rohr', katalogId: 'std_c_rohr');
      await veroeffentlicheGeraet(schwester, 'C-ROHR!');

      expect(await typen(), hasLength(1));

      final projektionen = await asService((s) async =>
          List<Map<String, dynamic>>.from(await s
              .from('equipment_items')
              .select('abteilung_id, id, type_id')
              .inFilter('abteilung_id', [mirror, schwester])));
      expect(projektionen, hasLength(2));
      // Beide behalten ihre eigene lokale ID 1 und zeigen doch auf einen Typ.
      expect(projektionen.map((p) => p['id']).toSet(), {1});
      expect(projektionen.map((p) => p['type_id']).toSet(), hasLength(1));
      expect(projektionen.first['type_id'], isNotNull);
    });

    test('jeder Gerätewart der Gesamtwehr darf den Typ pflegen', () async {
      await veroeffentlicheGeraet(mirror, 'Kübelspritze');
      final typ = (await typen()).single;

      // Der Gerätewart hat seine Mitgliedschaft NUR in der Bestands-Abteilung
      // — für den geteilten Typ-Bestand genügt das, er gehört der Wehr.
      final gwClient = SupabaseClient(_url, _anonKey);
      addTearDown(gwClient.dispose);
      await gwClient.auth.signInWithPassword(
          email: 'geraetewart@fw.local', password: 'test1234');

      await gwClient.rpc('push_equipment_types', params: {
        'gw': gesamtwehr,
        'aenderungen': [
          {...typ, 'name': 'Kübelspritze 10 l', 'updated_at': null},
        ],
      });
      expect((await typen()).single['name'], 'Kübelspritze 10 l');
    });

    test('ohne Schreibrolle in der Gesamtwehr prallt der Schreibweg ab',
        () async {
      await veroeffentlicheGeraet(mirror, 'Feuerpatsche');
      await expectLater(
        memberClient.rpc('push_equipment_types', params: {
          'gw': gesamtwehr,
          'aenderungen': [
            {'name': 'Heimlich umbenannt'},
          ],
        }),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('permission denied'))),
      );
    });

    test('ein Alt-Client überschreibt den gepflegten Typ NICHT', () async {
      // Genau die Falle der Alt-Client-Choreografie: Solange die Mindest-
      // version nicht steht, veröffentlichen Apps ohne Typ-Kenntnis weiter.
      // Sie dürfen anlegen und verknüpfen — aber nicht zurückrollen.
      await veroeffentlicheGeraet(mirror, 'Schaumrohr');
      final typ = (await typen()).single;

      await adminClient.rpc('push_equipment_types', params: {
        'gw': gesamtwehr,
        'aenderungen': [
          {...typ, 'name': 'Schaumrohr M4', 'description': 'Mittelschaum'},
        ],
      });

      // Dieselbe Abteilung veröffentlicht erneut mit dem ALTEN Namen.
      await veroeffentlicheGeraet(mirror, 'Schaumrohr');

      final danach = (await typen()).single;
      expect(danach['name'], 'Schaumrohr M4',
          reason: 'Der Snapshot eines Alt-Clients darf die Pflege der '
              'Gesamtwehr nicht zurückrollen');
      expect(await typen(), hasLength(1),
          reason: 'und schon gar keinen zweiten Typ anlegen');
    });

    test('ein Alt-Client löscht gepflegte Felder nicht weg', () async {
      // Der gefährlichere Fall als das Umbenennen, weil er unbemerkt bleibt:
      // Ein Gerätewart hängt Foto und Beschreibung an den geteilten Typ, und
      // eine ANDERE Abteilung veröffentlicht danach mit einer App, die von
      // Typen nichts weiß — ihre Payload trägt an denselben Feldern nichts.
      // Der Name passt hier weiterhin, das Verknüpfungs-Gedächtnis greift
      // also gar nicht: Diese Zeile schützt allein `nur_anlegen`.
      await veroeffentlicheGeraet(mirror, 'Feuerwehrleine');
      final typ = (await typen()).single;

      await adminClient.rpc('push_equipment_types', params: {
        'gw': gesamtwehr,
        'aenderungen': [
          {
            ...typ,
            'description': 'Kernmantel, 30 m',
            'image_path': 'supabase://equipment-images/leine.jpg',
            'short_name': 'FW-Leine',
          },
        ],
      });

      await veroeffentlicheGeraet(schwester, 'Feuerwehrleine');

      final danach = await asService((s) async => await s
          .from('equipment_types')
          .select('description, image_path, short_name')
          .eq('gesamtwehr_id', gesamtwehr)
          .single());
      expect(danach['description'], 'Kernmantel, 30 m');
      expect(danach['image_path'], 'supabase://equipment-images/leine.jpg');
      expect(danach['short_name'], 'FW-Leine');
      expect(await typen(), hasLength(1));
    });

    test('ein älterer Stand rollt eine neuere Pflege nicht zurück', () async {
      await veroeffentlicheGeraet(mirror, 'Trennschleifer');
      final typ = (await typen()).single;

      await adminClient.rpc('push_equipment_types', params: {
        'gw': gesamtwehr,
        'aenderungen': [
          {...typ, 'name': 'Trennschleifer neu'},
        ],
      });

      // Ein Gerät, das lange offline war, schickt seinen alten Stand.
      await adminClient.rpc('push_equipment_types', params: {
        'gw': gesamtwehr,
        'aenderungen': [
          {
            ...typ,
            'name': 'Trennschleifer alt',
            'updated_at': DateTime.utc(2020).toIso8601String(),
          },
        ],
      });
      expect((await typen()).single['name'], 'Trennschleifer neu');
    });

    test('die Verwendung zählt über alle Abteilungen der Gesamtwehr',
        () async {
      // Grundlage für „löschen oder archivieren?": Die App darf einen Typ nur
      // dann wirklich löschen, wenn ihn NIEMAND mehr zugeordnet hat — und die
      // eigene RLS-Sicht zeigt ihr die fremden Abteilungen nicht vollständig.
      await veroeffentlicheGeraet(mirror, 'Rettungsspreizer');
      await veroeffentlicheGeraet(schwester, 'Rettungsspreizer');
      final typ = (await typen()).single;

      final verwendung = List<Map<String, dynamic>>.from(await adminClient
          .rpc('equipment_type_verwendung', params: {'ziel': typ['id']}));
      expect(verwendung, hasLength(2));
      expect(verwendung.map((v) => v['abteilung_id']).toSet(),
          {mirror, schwester});
    });
  });

  /// Der Client-Weg zum geteilten Typ-Bestand (Stufe ②, Issue #99).
  ///
  /// Der Snapshot-Sync bleibt, wie er ist; daneben zieht und schiebt
  /// [EquipmentTypeSync] die Typen zeilenweise. Die Tests decken die drei
  /// Stellen ab, an denen das schiefgehen kann: die Erstverbindung mit dem
  /// schon vorhandenen lokalen Katalog, das Fenster, und der Rückweg.
  group('Typ-Sync im Client (Stufe ②)', () {
    late String mirror;
    late String schwester;
    late String gesamtwehr;

    setUp(() async {
      mirror = await mirrorAbteilungId();
      gesamtwehr = await adminClient
          .rpc('create_gesamtwehr', params: {'name': 'GW Client'}) as String;
      schwester = await adminClient
          .rpc('create_abteilung', params: {'name': 'Nord Client'}) as String;
    });

    tearDown(() async {
      await asService((s) async {
        await s.from('abteilungen').delete().eq('legacy_mirror', false);
        await s
            .from('abteilungen')
            .update({'gesamtwehr_id': null}).eq('id', mirror);
        await s.from('gesamtwehren').delete().neq('name', 'nie');
        await s
            .from('profiles')
            .update({'abteilung_id': mirror}).filter('abteilung_id', 'is', null);
        final profs = await s.from('profiles').select('id, role, abteilung_id');
        await s.from('memberships').upsert([
          for (final p in profs)
            if (p['abteilung_id'] != null)
              {
                'user_id': p['id'],
                'abteilung_id': p['abteilung_id'],
                'role': p['role'],
              },
        ], onConflict: 'user_id,abteilung_id');
      });
    });

    (AppDatabase, SyncService, EquipmentTypeSync) sicht(String abteilung) {
      final db = createTestDatabase();
      addTearDown(db.close);
      return (
        db,
        SyncService(db, adminClient, abteilungOverride: abteilung),
        EquipmentTypeSync(db, adminClient, abteilungOverride: abteilung),
      );
    }

    test('der erste Zug hängt sich an den vorhandenen Katalog an', () async {
      // DER Fallstrick: Lokal liegen die Katalog-Geräte aus dem Seeder schon.
      // Ohne Zuordnung legte der erste Zug jedes davon ein zweites Mal an.
      final (dbA, syncA, _) = sicht(mirror);
      await syncA.pullIfNewer(force: true);
      await dbA.delete(dbA.vehicles).go();
      await dbA.delete(dbA.equipmentItems).go();
      await dbA.into(dbA.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1),
          name: 'C-Rohr',
          libraryEquipmentId: const Value('std_c_rohr')));
      await syncA.publish();

      // Zweite Abteilung, frische lokale Datei — aber mit demselben Katalog,
      // wie ihn der Seeder auf jedem Gerät anlegt.
      final (dbB, _, typenB) = sicht(schwester);
      await dbB.into(dbB.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1),
          name: 'C-Rohr',
          libraryEquipmentId: const Value('std_c_rohr')));

      expect(await typenB.pull(force: true), 1);
      final geraete = await dbB.equipmentDao.getAll();
      expect(geraete, hasLength(1),
          reason: 'der gezogene Typ gehört an das vorhandene Gerät, '
              'nicht daneben');
      expect(geraete.single.remoteTypeId, isNotNull);
      expect(geraete.single.id, 1, reason: 'die lokale ID bleibt, woran '
          'Zuordnungen und Exemplare hängen');
    });

    test('ein unbekannter Typ kommt als neues Gerät an', () async {
      final (dbA, syncA, _) = sicht(mirror);
      await syncA.pullIfNewer(force: true);
      await dbA.delete(dbA.vehicles).go();
      await dbA.delete(dbA.equipmentItems).go();
      await dbA.into(dbA.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1), name: 'Kübelspritze'));
      await syncA.publish();

      final (dbB, _, typenB) = sicht(schwester);
      expect(await typenB.pull(force: true), 1);
      expect((await dbB.equipmentDao.getAll()).single.name, 'Kübelspritze');
    });

    test('das Fenster zieht nur Neues, nicht alles', () async {
      final (dbA, syncA, _) = sicht(mirror);
      await syncA.pullIfNewer(force: true);
      await dbA.delete(dbA.vehicles).go();
      await dbA.delete(dbA.equipmentItems).go();
      await dbA.into(dbA.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1), name: 'Halligan-Tool'));
      await syncA.publish();

      final (dbB, _, typenB) = sicht(schwester);
      expect(await typenB.pull(force: true), 1);
      // Nichts hat sich geändert: Der zweite Zug bleibt leer.
      expect(await typenB.pull(), 0);

      // Jetzt kommt einer dazu — und NUR der wird geholt.
      await dbA.into(dbA.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(2), name: 'Brechstange'));
      await syncA.publish();
      expect(await typenB.pull(), 1);
      expect((await dbB.equipmentDao.getAll()).map((e) => e.name),
          containsAll(['Halligan-Tool', 'Brechstange']));
    });

    test('ein lokal geänderter Typ geht hoch und kommt bestätigt zurück',
        () async {
      final (dbA, syncA, typenA) = sicht(mirror);
      await syncA.pullIfNewer(force: true);
      await dbA.delete(dbA.vehicles).go();
      await dbA.delete(dbA.equipmentItems).go();
      await dbA.into(dbA.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1), name: 'Wärmebildkamera'));
      await syncA.publish();
      await typenA.pull(force: true);

      // So ändert die App einen Typ: Inhalt schreiben, `updatedAt` hochziehen
      // und als offen kennzeichnen. Das Hochziehen ist Pflicht — der Server
      // entscheidet daran, ob die Änderung neuer ist als sein Stand.
      await dbA.equipmentDao.patchEquipment(
          1,
          EquipmentItemsCompanion(
            description: const Value('Bullard QXT'),
            updatedAt: Value(DateTime.now()),
            typeDirty: const Value(true),
          ));
      expect(await typenA.push(), 1);

      final lokal = await dbA.equipmentDao.getById(1);
      expect(lokal?.typeDirty, isFalse, reason: 'nach dem Schieben abgeräumt');
      expect(lokal?.remoteTypeId, isNotNull);

      // Und die Schwester-Abteilung sieht die Änderung.
      final (dbB, _, typenB) = sicht(schwester);
      await typenB.pull(force: true);
      expect((await dbB.equipmentDao.getAll()).single.description,
          'Bullard QXT');
    });

    test('wer auf einem überholten Stand schreibt, wird abgewiesen', () async {
      // Optimistische Nebenläufigkeit je Zeile: Der Client schickt die
      // Version zurück, die er zuletzt gesehen hat. Ist der Server seither
      // weitergezogen, gilt dessen Stand. Ein Uhrenvergleich täte das NICHT
      // zuverlässig — Drift rundet auf Sekunden, und zwei Geräte gehen nie
      // gleich.
      final (dbA, syncA, typenA) = sicht(mirror);
      await syncA.pullIfNewer(force: true);
      await dbA.delete(dbA.vehicles).go();
      await dbA.delete(dbA.equipmentItems).go();
      await dbA.into(dbA.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1), name: 'Sprungretter'));
      await syncA.publish();
      await typenA.pull(force: true);
      final typId = (await dbA.equipmentDao.getById(1))!.remoteTypeId!;

      // Jemand anders pflegt den Typ — A weiß davon nichts.
      await adminClient.rpc('push_equipment_types', params: {
        'gw': gesamtwehr,
        'aenderungen': [
          {'id': typId, 'name': 'Sprungretter', 'description': 'von Kollege'},
        ],
      });

      // A ändert auf seinem überholten Stand und schiebt.
      await dbA.equipmentDao.patchEquipment(
          1,
          const EquipmentItemsCompanion(
            description: Value('von A'),
            typeDirty: Value(true),
          ));
      await typenA.push();

      final zentral = await asService((s) async => await s
          .from('equipment_types')
          .select('description')
          .eq('id', typId)
          .single());
      expect(zentral['description'], 'von Kollege',
          reason: 'der überholte Stand darf die neuere Pflege nicht kippen');
    });

    test('ein archivierter Typ verschwindet nur, wenn er frei ist', () async {
      final (dbA, syncA, typenA) = sicht(mirror);
      await syncA.pullIfNewer(force: true);
      await dbA.delete(dbA.vehicles).go();
      await dbA.delete(dbA.equipmentItems).go();
      await dbA.into(dbA.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1), name: 'Ölbindemittel'));
      await syncA.publish();
      await typenA.pull(force: true);
      final typId = (await dbA.equipmentDao.getById(1))!.remoteTypeId!;

      // Ein zweites Gerät derselben Wehr, das den Typ BENUTZT.
      final (dbB, syncB, typenB) = sicht(schwester);
      await typenB.pull(force: true);
      final vehicleId = await dbB.vehicleDao
          .insertVehicle(VehiclesCompanion.insert(name: 'LF', type: 'LF'));
      final fach = await dbB.compartmentDao.insertCompartment(
          CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
      final geraetB = (await dbB.equipmentDao.getAll()).single.id;
      await dbB.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
              compartmentId: fach, equipmentId: geraetB));
      await syncB.publish();

      // Aus dem Bestand nehmen.
      await adminClient.rpc('push_equipment_types', params: {
        'gw': gesamtwehr,
        'aenderungen': [
          {'id': typId, 'deleted_at': DateTime.now().toUtc().toIso8601String()},
        ],
      });

      // Wo er frei ist, verschwindet er …
      expect(await typenA.pull(), 1);
      expect(await dbA.equipmentDao.getAll(), isEmpty);

      // … wo er in einem Fach liegt, bleibt er. Sonst risse das Archivieren
      // einer anderen Abteilung ein Loch in ihre Beladung.
      expect(await typenB.pull(), 1);
      expect(await dbB.equipmentDao.getAll(), hasLength(1));
    });

    /// Aus dem Bestand nehmen — die Oberfläche zu Stufe ② (Issue #99).
    ///
    /// Zentral ist „löschen" und „archivieren" derselbe Vorgang
    /// (`deleted_at` setzen). Was die App unterscheidet, ist die ANSAGE —
    /// und die hängt daran, ob eine ANDERE Abteilung den Typ noch benutzt.
    group('aus dem Bestand nehmen', () {
      /// Ein Gerät in [mirror], das im geteilten Bestand angekommen ist.
      Future<(AppDatabase, SyncService, EquipmentTypeSync, String)> vorbereiten(
          String name) async {
        final (dbA, syncA, typenA) = sicht(mirror);
        await syncA.pullIfNewer(force: true);
        await dbA.delete(dbA.vehicles).go();
        await dbA.delete(dbA.equipmentItems).go();
        await dbA.into(dbA.equipmentItems).insert(
            EquipmentItemsCompanion.insert(
                id: const Value(1),
                name: name,
                shortName: const Value('KS'),
                imagePath: const Value('assets/equipment_library/'
                    'images/std_kuebelspritze.png')));
        await syncA.publish();
        await typenA.pull(force: true);
        return (
          dbA,
          syncA,
          typenA,
          (await dbA.equipmentDao.getById(1))!.remoteTypeId!
        );
      }

      test('was frei ist, wird gelöscht — und nimmt nichts mit', () async {
        final (_, _, typenA, typId) = await vorbereiten('Kübelspritze');
        expect((await typenA.verwendungAnderswo(1)).nurArchivieren, isFalse,
            reason: 'niemand sonst benutzt den Typ');

        await typenA.ausBestandNehmen(1);

        final zentral = await asService((s) async => await s
            .from('equipment_types')
            .select('deleted_at, short_name, image_path')
            .eq('id', typId)
            .single());
        expect(zentral['deleted_at'], isNotNull);
        // ⚠️ Der Schreibweg setzt short_name und image_path OHNE coalesce:
        // Wer beim Archivieren nur `deleted_at` schickt, löscht der ganzen
        // Wehr den Namen und das Foto mit.
        expect(zentral['short_name'], 'KS');
        expect(zentral['image_path'], contains('std_kuebelspritze'));
      });

      test('was eine andere Abteilung benutzt, wird nur archiviert',
          () async {
        final (dbA, syncA, typenA, _) = await vorbereiten('Ölbindemittel');

        // Die Schwester legt den Typ in ein Fach.
        final (dbB, syncB, typenB) = sicht(schwester);
        await typenB.pull(force: true);
        final vehicleId = await dbB.vehicleDao
            .insertVehicle(VehiclesCompanion.insert(name: 'LF', type: 'LF'));
        final fach = await dbB.compartmentDao.insertCompartment(
            CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
        await dbB.assignmentDao.insertAssignment(
            EquipmentAssignmentsCompanion.insert(
                compartmentId: fach,
                equipmentId: (await dbB.equipmentDao.getAll()).single.id));
        await syncB.publish();

        final anderswo = await typenA.verwendungAnderswo(1);
        expect(anderswo.nurArchivieren, isTrue);
        expect(anderswo.abteilungen, 1);
        expect(anderswo.summe, 1);

        // Und die eigene Verwendung zählt NICHT mit: Sie verschwindet mit
        // dem Entfernen ohnehin, sonst wäre nie etwas löschbar.
        final vehicleA = await dbA.vehicleDao
            .insertVehicle(VehiclesCompanion.insert(name: 'HLF', type: 'HLF'));
        final fachA = await dbA.compartmentDao.insertCompartment(
            CompartmentsCompanion.insert(vehicleId: vehicleA, label: 'G2'));
        await dbA.assignmentDao.insertAssignment(
            EquipmentAssignmentsCompanion.insert(
                compartmentId: fachA, equipmentId: 1));
        await syncA.publish();
        expect((await typenA.verwendungAnderswo(1)).abteilungen, 1,
            reason: 'die eigene Abteilung zählt nicht als „anderswo"');
      });

      test('wer auf einem überholten Stand entfernt, wird abgewiesen',
          () async {
        final (_, _, typenA, typId) = await vorbereiten('Sprungretter');

        // Jemand anders pflegt den Typ, A weiß davon nichts.
        await adminClient.rpc('push_equipment_types', params: {
          'gw': gesamtwehr,
          'aenderungen': [
            {'id': typId, 'name': 'Sprungretter', 'description': 'gepflegt'},
          ],
        });

        // Ohne die Prüfung verschwände das Gerät lokal, bliebe zentral aber
        // stehen — und käme beim nächsten vollen Zug wortlos zurück.
        await expectLater(
            typenA.ausBestandNehmen(1), throwsA(isA<TypKonfliktException>()));
        final zentral = await asService((s) async => await s
            .from('equipment_types')
            .select('deleted_at')
            .eq('id', typId)
            .single());
        expect(zentral['deleted_at'], isNull);
      });

      test('ein Foto, das nur hier liegt, geht nicht in den Bestand',
          () async {
        // Kamera und Galerie liefern einen Pfad auf DIESES Gerät. Zentral
        // wäre er tot — und `image_path` wird ohne coalesce geschrieben, das
        // gute Bild der Wehr wäre weg. Solche Zeilen bleiben vorgemerkt.
        final (dbA, _, typenA, typId) = await vorbereiten('Rettungssäge');
        await dbA.equipmentDao.patchEquipment(
            1,
            const EquipmentItemsCompanion(
              imagePath: Value('/data/user/0/com.feuerwehr.fwapp/saege.jpg'),
              typeDirty: Value(true),
            ));

        expect(await typenA.push(), 0);
        expect((await dbA.equipmentDao.getById(1))?.typeDirty, isTrue,
            reason: 'die Zeile bleibt vorgemerkt, bis der Upload durch ist');
        final zentral = await asService((s) async => await s
            .from('equipment_types')
            .select('image_path')
            .eq('id', typId)
            .single());
        expect(zentral['image_path'], contains('std_kuebelspritze'));
      });
    });

    test('ohne Gesamtwehr ist der Typ-Sync ein No-op', () async {
      // Lokalmodus, Alt-Server, Abteilung ohne Gesamtwehr: Die App muss
      // unverändert auf dem Snapshot-Weg weiterlaufen.
      await asService((s) async =>
          await s.from('abteilungen').update({'gesamtwehr_id': null}).eq(
              'id', mirror));
      final (dbA, _, typenA) = sicht(mirror);
      await dbA.into(dbA.equipmentItems).insert(EquipmentItemsCompanion.insert(
          id: const Value(1), name: 'Einreißhaken', typeDirty: const Value(true)));

      expect(await typenA.pull(force: true), 0);
      expect(await typenA.push(), 0);
      // Unangetastet — insbesondere bleibt das Kennzeichen stehen.
      expect((await dbA.equipmentDao.getById(1))?.typeDirty, isTrue);
    });
  });
}
