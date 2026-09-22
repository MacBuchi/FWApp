/// tag_sync_e2e_test.dart – Der Abgleich der Geräte-Codes selbst, gegen den
/// LOKALEN Supabase-Stack (`supabase start`). Überspringt sich selbst, wenn
/// er nicht läuft.
///
/// **Warum gegen den echten Stack und nicht gegen einen Fake.** Ein Fake
/// prüfte meine Annahme über den Server, nicht den Server — und hier hängen
/// drei Zusicherungen daran, die nur er beantworten kann:
///
///   1. Der Primärschlüssel ist `(abteilung_id, code)`. Erst der echte
///      Server zeigt, dass zwei Geräte mit derselben lokalen Drift-ID
///      einander NICHT überschreiben.
///   2. `authenticated` hat bewusst **kein** DELETE. Das Entfernen ist ein
///      Soft-Delete; wäre das Recht doch da, fiele es nirgends auf, bis ein
///      Code bei anderen Geräten unwiederbringlich verschwindet.
///   3. Ein Grabstein kommt auch wirklich als `deleted_at` an.
///
/// Arbeitsteilung wie bei `wissen_sync_e2e_test.dart`: Die RLS-Regeln der
/// Abteilung beweisen die übrigen E2E-Dateien, hier steht die Client-Logik.
///
/// Braucht die lokalen Testkonten aus tool/setup_local_supabase.sh.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inventory/data/tag_sync.dart';
import 'package:fwapp/features/inventory/presentation/providers/tag_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_database.dart';
import 'stack_sperre.dart';

const _url = 'http://127.0.0.1:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

final _serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

Future<bool> _erreichbar(String url) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    await response.drain<void>();
    client.close();
    return response.statusCode < 500;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  if (!await _erreichbar('$_url/auth/v1/health')) {
    test(
      'tag sync e2e',
      () {},
      skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).',
    );
    return;
  }

  late SupabaseClient wart;
  late AppDatabase db;
  late TagSync sync;
  late TagDienst dienst;
  late String wehr;
  late String abteilung;
  late int einheitA;
  late int einheitB;

  Future<T> asService<T>(Future<T> Function(SupabaseClient) body) async {
    final service = SupabaseClient(_url, _serviceRoleKey);
    try {
      return await body(service);
    } finally {
      await service.dispose();
    }
  }

  /// Legt einen Code direkt auf dem Server an — so, wie er vom Handy des
  /// zweiten Gerätewarts käme.
  Future<void> vonEinemAnderenGeraet({
    required String code,
    required int instanceId,
    String kind = 'qr',
    bool selfIssued = true,
    DateTime? entferntAm,
  }) =>
      asService((s) => s.from('equipment_tags').upsert({
            'abteilung_id': abteilung,
            'code': code,
            'instance_id': instanceId,
            'kind': kind,
            'self_issued': selfIssued,
            'deleted_at': entferntAm?.toUtc().toIso8601String(),
          }));

  Future<List<Map<String, dynamic>>> aufDemServer() async =>
      asService((s) async => List<Map<String, dynamic>>.from(
          await s.from('equipment_tags').select().eq('abteilung_id', abteilung)));

  setUpAll(() async {
    await stackSperreHolen();
    wart = SupabaseClient(_url, _anonKey);
    await wart.auth.signInWithPassword(
      email: 'geraetewart@fw.local',
      password: 'test1234',
    );
    await asService((s) async {
      final gw = await s
          .from('gesamtwehren')
          .insert({'name': 'Tag Wehr', 'slug': 'tag-wehr'})
          .select('id')
          .single();
      wehr = gw['id'] as String;
      final abt = await s
          .from('abteilungen')
          .insert({
            'name': 'Tag Abteilung',
            'slug': 'tag-abt',
            'status': 'active',
            'gesamtwehr_id': wehr,
          })
          .select('id')
          .single();
      abteilung = abt['id'] as String;
      await s.from('memberships').upsert({
        'user_id': wart.auth.currentUser!.id,
        'abteilung_id': abteilung,
        'role': 'geraetewart',
      });
    });
  });

  tearDownAll(() async {
    await asService((s) async {
      await s.from('equipment_tags').delete().eq('abteilung_id', abteilung);
      await s.from('memberships').delete().eq('abteilung_id', abteilung);
      await s.from('abteilungen').delete().eq('id', abteilung);
      await s.from('gesamtwehren').delete().eq('id', wehr);
    });
    await wart.dispose();
    await stackSperreFreigeben();
  });

  setUp(() async {
    db = createTestDatabase();
    sync = TagSync(db: db, client: wart);
    dienst = TagDienst(db);
    final geraet = await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(name: 'Pressluftatmer'));
    einheitA = await db.inspectionDao.insertInstance(
        EquipmentInstancesCompanion.insert(
            equipmentId: geraet, identifier: const Value('Flasche 3')));
    einheitB = await db.inspectionDao.insertInstance(
        EquipmentInstancesCompanion.insert(
            equipmentId: geraet, identifier: const Value('Flasche 4')));
    await asService(
        (s) => s.from('equipment_tags').delete().eq('abteilung_id', abteilung));
  });

  tearDown(() => db.close());

  group('schieben', () {
    test('ein vergebener Code geht hinaus und wird sauber', () async {
      final code = await dienst.vergebeCode(einheitA);
      expect(await sync.schiebe(abteilung), 1);

      final zeilen = await aufDemServer();
      expect(zeilen, hasLength(1));
      expect(zeilen.single['code'], code);
      expect(zeilen.single['instance_id'], einheitA);
      expect(zeilen.single['self_issued'], isTrue);
      expect(zeilen.single['deleted_at'], isNull);

      expect((await db.tagDao.findByCode(code))!.dirty, isFalse,
          reason: 'Was oben steht, darf nicht erneut geschoben werden.');
      expect(await sync.schiebe(abteilung), 0);
    });

    test('ein übernommener Hersteller-Barcode geht als solcher hinaus',
        () async {
      await dienst.verknuepfe(einheitA, '4006381333931');
      await sync.schiebe(abteilung);

      final zeile = (await aufDemServer()).single;
      expect(zeile['kind'], 'barcode');
      expect(zeile['self_issued'], isFalse);
    });

    test('ein entfernter Code geht als Grabstein hinaus und fällt hier weg',
        () async {
      final code = await dienst.vergebeCode(einheitA);
      await sync.schiebe(abteilung);

      await dienst.entferne((await db.tagDao.findByCode(code))!);
      expect(await sync.schiebe(abteilung), 1);

      expect((await aufDemServer()).single['deleted_at'], isNotNull,
          reason: 'Ohne Grabstein könnte kein anderes Gerät die Löschung '
              'sehen — ein Zug sieht nur, was da ist.');
      expect(await db.tagDao.findByCodeAuchEntfernt(code), isNull,
          reason: 'Der Grabstein hat seinen Zweck erfüllt und gibt den Code '
              'hier wieder frei.');
    });

    test('zwei Geräte mit derselben lokalen ID überschreiben einander nicht',
        () async {
      // ⚠️ Der Grund, warum der Primärschlüssel der CODE ist. Zwei
      // Gerätewarte, zwei Geräteräume, dieselbe laufende Nummer aus der
      // jeweils eigenen Datenbank — mit `(abteilung_id, id)` zeigte einer
      // der beiden Aufkleber danach auf das falsche Gerät.
      await vonEinemAnderenGeraet(code: 'FW-AAAAAAA', instanceId: einheitA);
      await dienst.verknuepfe(einheitA, 'FW-BBBBBBB');
      await sync.schiebe(abteilung);

      final codes =
          (await aufDemServer()).map((z) => z['code'] as String).toSet();
      expect(codes, {'FW-AAAAAAA', 'FW-BBBBBBB'});
    });
  });

  group('ziehen', () {
    test('ein Code vom anderen Gerät kommt hier an', () async {
      await vonEinemAnderenGeraet(code: 'FW-CCCCCCC', instanceId: einheitB);
      expect(await sync.ziehe(abteilung), 1);

      final treffer = await dienst.schlageNach('fw-ccccccc');
      expect(treffer, isNotNull,
          reason: 'Genau dafür ist der Abgleich da: Der Aufkleber des '
              'Gerätewarts muss beim nächsten die Inventur abhaken.');
      expect(treffer!.einheit.id, einheitB);
      expect((await db.tagDao.findByCode('FW-CCCCCCC'))!.dirty, isFalse);
    });

    test('ein Grabstein vom Server nimmt den Code auch hier weg', () async {
      await vonEinemAnderenGeraet(code: 'FW-DDDDDDD', instanceId: einheitA);
      await sync.ziehe(abteilung);
      expect(await db.tagDao.findByCode('FW-DDDDDDD'), isNotNull);

      await vonEinemAnderenGeraet(
          code: 'FW-DDDDDDD',
          instanceId: einheitA,
          entferntAm: DateTime.now());
      await sync.ziehe(abteilung);

      expect(await db.tagDao.findByCodeAuchEntfernt('FW-DDDDDDD'), isNull);
    });

    test('was hier noch aufs Hochladen wartet, wird NICHT überschrieben',
        () async {
      // Der teuerste Fehler dieser Bauform: Der Gerätewart klebt einen
      // Aufkleber, aktualisiert zwischendurch — und verliert ihn.
      await dienst.verknuepfe(einheitA, 'FW-EEEEEEE');
      await vonEinemAnderenGeraet(code: 'FW-EEEEEEE', instanceId: einheitB);

      await sync.ziehe(abteilung);

      expect((await db.tagDao.findByCode('FW-EEEEEEE'))!.instanceId, einheitA,
          reason: 'Erst schieben, dann ziehen — und was noch dirty ist, '
              'gehört dem Gerät.');
    });

    test('ein entfernter Code kommt durch den Zug nicht zurück', () async {
      await vonEinemAnderenGeraet(code: 'FW-FFFFFFF', instanceId: einheitA);
      await sync.ziehe(abteilung);
      await dienst.entferne((await db.tagDao.findByCode('FW-FFFFFFF'))!);

      await sync.ziehe(abteilung);

      expect(await db.tagDao.findByCode('FW-FFFFFFF'), isNull,
          reason: 'Der Aufkleber ist ab. Ihn zurückzuholen wäre genau der '
              'Fehler, den der Grabstein verhindert.');
    });

    test('ein Code auf eine unbekannte Einheit bricht den Zug nicht ab',
        () async {
      // Kommt vor: Der andere hat den Code vergeben, aber den Bestand noch
      // nicht veröffentlicht. Die Spalte trägt einen Fremdschlüssel — ohne
      // die Prüfung risse der ganze Abgleich hier ab.
      await vonEinemAnderenGeraet(code: 'FW-GGGGGGG', instanceId: 999999);
      await vonEinemAnderenGeraet(code: 'FW-HHHHHHH', instanceId: einheitA);

      expect(await sync.ziehe(abteilung), 1);
      expect(await db.tagDao.findByCode('FW-HHHHHHH'), isNotNull);
      expect(await db.tagDao.findByCode('FW-GGGGGGG'), isNull);
    });
  });

  group('Rechte', () {
    test('der Gerätewart darf einen Code NICHT hart löschen', () async {
      // Das ist keine Kür: Mit DELETE-Recht verschwände eine Zeile spurlos,
      // und jedes andere Gerät schöbe seinen Code beim nächsten Abgleich
      // wieder hoch — die Löschung wäre nie endgültig. Deshalb vergibt
      // 20260922080000 bewusst nur SELECT, INSERT und UPDATE.
      await vonEinemAnderenGeraet(code: 'FW-JJJJJJJ', instanceId: einheitA);

      // Ob der Server mit 42501 abbricht oder still nichts tut, hängt daran,
      // woran es zuerst scheitert — Grant oder Policy. Beides ist recht; die
      // Zusicherung ist, dass die Zeile stehen bleibt.
      try {
        await wart
            .from('equipment_tags')
            .delete()
            .eq('abteilung_id', abteilung)
            .eq('code', 'FW-JJJJJJJ');
      } on PostgrestException catch (_) {}

      expect((await aufDemServer()).map((z) => z['code']),
          contains('FW-JJJJJJJ'),
          reason: 'Ohne Grant und ohne Policy bleibt die Zeile stehen.');
    });
  });
}
