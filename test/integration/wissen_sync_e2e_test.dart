/// wissen_sync_e2e_test.dart – Der Abgleich der Wissensdatenbank selbst,
/// gegen den LOKALEN Supabase-Stack (`supabase start`). Überspringt sich
/// selbst, wenn er nicht läuft.
///
/// **Warum es diese Datei gibt.** `wissen_sync.dart` stand bei 0 % Coverage,
/// und zwar als einzige Datei dieser Größe im Projekt: Die übrigen E2E-Tests
/// sprechen die RPCs direkt an, nicht durch den Sync. Gewachsen ist sie
/// seither zweimal — um die abgeschalteten Lernbereiche, um die Hinweise und
/// um den Gerätebezug. Eine Datei, die Datenverlust verursachen kann, sollte
/// nicht diejenige sein, die niemand prüft.
///
/// **Warum gegen den echten Stack und nicht gegen einen Fake.** Ein Fake
/// würde genau das nachbauen, was hier fraglich ist — was der Server mit
/// einem Insert tut, welchen `stand` er zurückgibt, ob `deleted_at` wirklich
/// ankommt. Er prüfte dann meine Annahme über den Server, nicht den Server.
/// Die Arbeitsteilung ist bewusst: Die RLS-Regeln beweist
/// `lernbereiche_e2e_test.dart`, die **Client-Logik** beweist diese Datei —
/// und die interessanteste Zusicherung davon ist, dass ein Zug eine lokal
/// geänderte Frage NICHT überschreibt.
///
/// Braucht die lokalen Testkonten aus tool/setup_local_supabase.sh.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/knowledge/data/wissen_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_database.dart';
import 'stack_sperre.dart';

const _url = 'http://127.0.0.1:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

final _serviceRoleKey =
    Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
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
      'wissen sync e2e',
      () {},
      skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).',
    );
    return;
  }

  late SupabaseClient wart;
  late AppDatabase db;
  late WissenSync sync;
  late String wehr;
  late String abteilung;

  Future<T> asService<T>(Future<T> Function(SupabaseClient) body) async {
    final service = SupabaseClient(_url, _serviceRoleKey);
    try {
      return await body(service);
    } finally {
      await service.dispose();
    }
  }

  /// Legt eine Frage direkt auf dem Server an — so, wie sie von einem
  /// anderen Gerät käme.
  Future<String> aufDemServer({
    String frage = 'Serverfrage mit Fragezeichen?',
    String? kapitel,
    String? bildPfad,
    String? geraet,
    String stand = 'freigegeben',
  }) async =>
      asService((s) async {
        final zeile = await s
            .from('quiz_questions')
            .insert({
              'gesamtwehr_id': wehr,
              'gebiet': 'geraetekunde',
              'frage': frage,
              'antworten_json': '["Richtig","Falsch"]',
              'richtige_json': '[0]',
              'herkunft': 'eigen',
              'stand': stand,
              'kapitel': kapitel,
              'bild_pfad': bildPfad,
              'geraet': geraet,
            })
            .select('id')
            .single();
        return zeile['id'] as String;
      });

  Future<int> lokal({
    String frage = 'Lokale Frage mit Fragezeichen?',
    String herkunft = 'eigen',
    String stand = 'eingereicht',
    bool dirty = true,
    String? remoteId,
  }) =>
      db.wissenDao.insertFrage(WissensfragenCompanion.insert(
        gebiet: 'geraetekunde',
        frage: frage,
        antwortenJson: const Value('["Richtig","Falsch"]'),
        richtigeJson: const Value('[0]'),
        herkunft: Value(herkunft),
        stand: Value(stand),
        remoteId: Value(remoteId),
        dirty: Value(dirty),
      ));

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
          .insert({'name': 'Sync Wehr', 'slug': 'sync-wehr'})
          .select('id')
          .single();
      wehr = gw['id'] as String;
      final abt = await s
          .from('abteilungen')
          .insert({
            'name': 'Sync Abteilung',
            'slug': 'sync-abt',
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
      await s.from('frage_hinweise').delete().eq('gesamtwehr_id', wehr);
      await s
          .from('abgeschaltete_lernbereiche')
          .delete()
          .eq('gesamtwehr_id', wehr);
      await s.from('quiz_questions').delete().eq('gesamtwehr_id', wehr);
      await s.from('memberships').delete().eq('abteilung_id', abteilung);
      await s.from('abteilungen').delete().eq('id', abteilung);
      await s.from('gesamtwehren').delete().eq('id', wehr);
    });
    await wart.dispose();
    await stackSperreFreigeben();
  });

  setUp(() async {
    db = createTestDatabase();
    sync = WissenSync(db: db, client: wart);
    await asService((s) async {
      await s.from('frage_hinweise').delete().eq('gesamtwehr_id', wehr);
      await s
          .from('abgeschaltete_lernbereiche')
          .delete()
          .eq('gesamtwehr_id', wehr);
      await s.from('quiz_questions').delete().eq('gesamtwehr_id', wehr);
    });
  });

  tearDown(() => db.close());

  group('schieben', () {
    test('eine lokal angelegte Frage geht hinaus und wird sauber', () async {
      final id = await lokal();
      expect(await sync.schiebe(wehr), 1);

      final danach = (await db.wissenDao.getById(id))!;
      expect(danach.remoteId, isNotNull);
      expect(danach.dirty, isFalse,
          reason: 'Was geschoben ist, darf nicht erneut geschoben werden.');
    });

    test('eine MITGELIEFERTE Frage geht NICHT hinaus, wird aber sauber',
        () async {
      // Mitgeliefertes steht auf jedem Gerät im Asset. Es hochzuladen hieße,
      // denselben Grundstock für jede Wehr ein zweites Mal zu speichern.
      final id = await lokal(herkunft: 'mitgeliefert');
      await sync.schiebe(wehr);

      final danach = (await db.wissenDao.getById(id))!;
      expect(danach.remoteId, isNull);
      expect(danach.dirty, isFalse,
          reason: 'Sonst versucht es jeder Abgleich erneut.');
      expect(
        await asService(
            (s) => s.from('quiz_questions').select().eq('gesamtwehr_id', wehr)),
        isEmpty,
      );
    });

    test('neu geht IMMER als eingereicht hinaus — und wird dann gesetzt',
        () async {
      // Die Insert-Policy lässt nichts anderes zu: Niemand gibt seine eigene
      // Frage frei. Wer freigeben darf, tut es im zweiten Zug.
      final id = await lokal(stand: 'freigegeben');
      await sync.schiebe(wehr);

      final danach = (await db.wissenDao.getById(id))!;
      final serverZeile = await asService((s) => s
          .from('quiz_questions')
          .select('stand')
          .eq('id', danach.remoteId!)
          .single());
      expect(serverZeile['stand'], 'freigegeben',
          reason: 'Der zweite Zug muss den Stand nachziehen.');
    });

    test('eine saubere Frage wird gar nicht erst angefasst', () async {
      await lokal(dirty: false);
      expect(await sync.schiebe(wehr), 0);
    });
  });

  group('ziehen', () {
    test('holt eine Serverfrage mit allen Feldern', () async {
      await aufDemServer(
        kapitel: 'Dekontamination',
        bildPfad: 'assets/knowledge/bilder/test.png',
        geraet: 'std_b_druckschlauch_20m',
      );
      expect(await sync.ziehe(wehr), 1);

      final f = (await db.wissenDao.getAll()).single;
      expect(f.frage, 'Serverfrage mit Fragezeichen?');
      expect(f.kapitel, 'Dekontamination');
      expect(f.bildPfad, 'assets/knowledge/bilder/test.png');
      // Der Gerätebezug kam zuletzt dazu — eine Spalte, die der Zug nicht
      // mitnimmt, verliert ihren Inhalt beim ersten Bearbeiten.
      expect(f.geraet, 'std_b_druckschlauch_20m');
      expect(f.dirty, isFalse);
    });

    test('⚠️ überschreibt eine lokal geänderte Frage NICHT', () async {
      // Die wichtigste Zusicherung dieser Datei. Ohne sie verliert der
      // Einreichende seinen Text, sobald er zwischendurch synchronisiert —
      // und zwar ohne Fehlermeldung.
      final remoteId = await aufDemServer(frage: 'Fassung vom Server?');
      final id = await lokal(
          frage: 'Meine geänderte Fassung?', dirty: true, remoteId: remoteId);

      await sync.ziehe(wehr);

      expect((await db.wissenDao.getById(id))!.frage,
          'Meine geänderte Fassung?');
    });

    test('eine SAUBERE lokale Frage wird sehr wohl aktualisiert', () async {
      // Die Gegenprobe: Der Schutz oben darf nicht dazu führen, dass gar
      // nichts mehr ankommt.
      final remoteId = await aufDemServer(frage: 'Fassung vom Server?');
      final id = await lokal(
          frage: 'Alte Fassung?', dirty: false, remoteId: remoteId);

      await sync.ziehe(wehr);

      expect((await db.wissenDao.getById(id))!.frage, 'Fassung vom Server?');
    });

    test('entfernt, was der Server als gelöscht meldet', () async {
      final remoteId = await aufDemServer();
      final id = await lokal(dirty: false, remoteId: remoteId);
      await asService((s) => s.from('quiz_questions').update(
          {'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq(
          'id', remoteId));

      await sync.ziehe(wehr);

      expect(await db.wissenDao.getById(id), isNull);
    });
  });

  test('archivieren löscht auf dem Server nicht hart', () async {
    // Ein inkrementeller Pull sähe eine harte Löschung nie — die Frage käme
    // auf jedem Gerät, das gerade offline war, nie wieder weg.
    final remoteId = await aufDemServer();
    final id = await lokal(dirty: false, remoteId: remoteId);
    final f = (await db.wissenDao.getById(id))!;

    await sync.archiviere(f, wehr);

    final zeile = await asService((s) => s
        .from('quiz_questions')
        .select('deleted_at')
        .eq('id', remoteId)
        .single());
    expect(zeile['deleted_at'], isNotNull);
    expect(await db.wissenDao.getById(id), isNull);
  });

  group('Lernbereiche', () {
    test('abschalten, spiegeln, wieder einschalten', () async {
      await sync.setzeLernbereich(wehr, gebiet: 'atemschutz', aus: true);
      expect((await db.wissenDao.getAbgeschaltet()).single.gebiet,
          'atemschutz');

      await sync.setzeLernbereich(wehr, gebiet: 'atemschutz', aus: false);
      expect(await db.wissenDao.getAbgeschaltet(), isEmpty);
    });

    test('der Zug ERSETZT den Spiegel', () async {
      // Kein `deleted_at` nötig: Eine Zeile, die nicht mehr kommt, ist wieder
      // eingeschaltet. Das gilt nur, solange der Zug wirklich ersetzt.
      await sync.setzeLernbereich(wehr, gebiet: 'funk', aus: true);
      await asService((s) =>
          s.from('abgeschaltete_lernbereiche').delete().eq('gesamtwehr_id', wehr));

      await sync.zieheLernbereiche(wehr);

      expect(await db.wissenDao.getAbgeschaltet(), isEmpty);
    });
  });

  group('Hinweise', () {
    test('melden landet im Spiegel, abhaken auch', () async {
      final remoteId = await aufDemServer();
      await sync.meldeHinweis(wehr,
          frageRemoteId: remoteId,
          text: 'Antwort b) stimmt seit 2024 auch.',
          melderName: 'Truppführer');

      final offen = await db.wissenDao.watchOffeneHinweise().first;
      expect(offen, hasLength(1));
      expect(offen.single.vonName, 'Truppführer');
      expect(offen.single.frageRemoteId, remoteId);

      await sync.erledigeHinweis(wehr, hinweisRemoteId: offen.single.remoteId!);
      expect(await db.wissenDao.watchOffeneHinweise().first, isEmpty);
    });
  });

  test('ohne Client tut keiner der Züge etwas', () async {
    // Lokalbetrieb ist ein gültiger Zustand, kein Fehler.
    final ohne = WissenSync(db: db);
    expect(await ohne.ziehe(wehr), 0);
    expect(await ohne.schiebe(wehr), 0);
    expect(await ohne.zieheLernbereiche(wehr), 0);
    expect(await ohne.zieheHinweise(wehr), 0);
  });
}
