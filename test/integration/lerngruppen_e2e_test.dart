/// lerngruppen_e2e_test.dart – Lerngruppen auf Zeit (Issue #136) gegen den
/// LOKALEN Supabase-Stack (`supabase start`). Überspringt sich selbst, wenn
/// er nicht läuft.
///
/// **Warum das kein Widget-Test sein kann.** Jede Zusicherung dieses Features
/// entsteht erst aus RLS, Grants und den SECURITY-DEFINER-Funktionen
/// zusammen — und zwei davon zeigen sich ausschließlich am laufenden Stack:
///
///   * Die Lese-Policy auf `lerngruppen_mitglieder` fragt dieselbe Tabelle ab
///     und liefe ohne den Helfer `ist_lerngruppen_mitglied` in „infinite
///     recursion detected in policy" — **erst beim ersten echten SELECT**,
///     nie beim Anlegen.
///   * `lerngruppen_mitglieder_namen` umgeht RLS (security definer) und ist
///     damit die einzige Stelle, an der ein fremdes Profil überhaupt
///     herauskommt. Ob sie wirklich nur Mitgliedern antwortet, kann kein Fake
///     beweisen — er baute genau die Prüfung nach, um die es geht.
///   * Die Wertung (20260923120000) ist der erste Weg, auf dem Lerndaten das
///     Gerät verlassen. Dass die Tabelle NUR eine Zahl je Woche trägt, dass
///     Außenstehende sie nicht sehen und dass sie beim Verlassen mitgeht,
///     hängt an Spaltenliste, Policy und Fremdschlüssel zugleich.
///
/// Braucht die lokalen Testkonten aus tool/setup_local_supabase.sh:
///   admin@fw.local / geraetewart@fw.local / member@fw.local, pw test1234
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'direktzugriff.dart';
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
      'lerngruppen e2e',
      () {},
      skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).',
    );
    return;
  }

  late SupabaseClient gruenderin; // geraetewart@fw.local, Wehr 1
  late SupabaseClient zweite; // member@fw.local, Wehr 1
  late SupabaseClient fremder; // admin@fw.local, Wehr 2

  Future<T> asService<T>(Future<T> Function(SupabaseClient) body) async {
    final service = SupabaseClient(_url, _serviceRoleKey);
    try {
      return await body(service);
    } finally {
      await service.dispose();
    }
  }

  late String wehr1;
  late String wehr2;
  late String abteilung1;
  late String abteilung2;

  Future<void> aufraeumen() => asService((s) async {
    await s.from('lerngruppen').delete().inFilter('gesamtwehr_id', [
      wehr1,
      wehr2,
    ]);
  });

  /// Legt eine Gruppe an und gibt sie samt Code zurück.
  Future<Map<String, dynamic>> gruppeAnlegen({
    String name = 'Winterprüfung',
    int wochen = 8,
  }) async {
    final roh = await gruenderin.rpc(
      'erstelle_lerngruppe',
      params: {'p_gesamtwehr': wehr1, 'p_name': name, 'p_wochen': wochen},
    );
    return (roh as Map).cast<String, dynamic>();
  }

  setUpAll(() async {
    await stackSperreHolen();
    gruenderin = SupabaseClient(_url, _anonKey);
    zweite = SupabaseClient(_url, _anonKey);
    fremder = SupabaseClient(_url, _anonKey);
    await gruenderin.auth.signInWithPassword(
      email: 'geraetewart@fw.local',
      password: 'test1234',
    );
    await zweite.auth.signInWithPassword(
      email: 'member@fw.local',
      password: 'test1234',
    );
    await fremder.auth.signInWithPassword(
      email: 'admin@fw.local',
      password: 'test1234',
    );

    await asService((s) async {
      for (final name in ['Lerngruppenwehr Eins', 'Lerngruppenwehr Zwei']) {
        final slug = name.toLowerCase().replaceAll(' ', '-');
        final gw =
            await s
                .from('gesamtwehren')
                .insert({'name': name, 'slug': slug})
                .select('id')
                .single();
        final abt =
            await s
                .from('abteilungen')
                .insert({
                  'name': '$name Abteilung',
                  'slug': '$slug-abt',
                  'status': 'active',
                  'gesamtwehr_id': gw['id'],
                })
                .select('id')
                .single();
        if (name.endsWith('Eins')) {
          wehr1 = gw['id'] as String;
          abteilung1 = abt['id'] as String;
        } else {
          wehr2 = gw['id'] as String;
          abteilung2 = abt['id'] as String;
        }
      }
      await s.from('memberships').upsert([
        {
          'user_id': gruenderin.auth.currentUser!.id,
          'abteilung_id': abteilung1,
          'role': 'geraetewart',
        },
        {
          'user_id': zweite.auth.currentUser!.id,
          'abteilung_id': abteilung1,
          'role': 'member',
        },
        // Der Fremde ist Mitglied — nur eben der anderen Gesamtwehr. Genau
        // die Grenze, die der Beitritt ziehen muss.
        {
          'user_id': fremder.auth.currentUser!.id,
          'abteilung_id': abteilung2,
          'role': 'admin',
        },
      ]);

      // Die Gründerin hat einen Anzeigenamen gesetzt, die zweite nicht —
      // beide Seiten des Rückfalls stehen damit in derselben Liste.
      await s
          .from('profiles')
          .update({'anzeigename': 'Lea vom Löschzug', 'avatar': 'helm=rot'})
          .eq('id', gruenderin.auth.currentUser!.id);
      await s
          .from('profiles')
          .update({'anzeigename': null, 'username': 'member'})
          .eq('id', zweite.auth.currentUser!.id);
    });
  });

  tearDownAll(() async {
    await aufraeumen();
    await asService((s) async {
      await s.from('memberships').delete().inFilter('abteilung_id', [
        abteilung1,
        abteilung2,
      ]);
      await s.from('abteilungen').delete().inFilter('id', [
        abteilung1,
        abteilung2,
      ]);
      await s.from('gesamtwehren').delete().inFilter('id', [wehr1, wehr2]);
    });
    await gruenderin.dispose();
    await zweite.dispose();
    await fremder.dispose();
    await stackSperreFreigeben();
  });

  setUp(aufraeumen);

  group('Gruppe und Beitritt', () {
    test('gründen macht die Gründerin zum ersten Mitglied', () async {
      final gruppe = await gruppeAnlegen();

      expect(gruppe['code'], matches(RegExp(r'^[0-9]{6}$')));
      expect(gruppe['gesamtwehr_id'], wehr1);
      // Acht KALENDERWOCHEN, die angebrochene Gründungswoche mitgezählt
      // (20260923120000): Ende ist immer ein Sonntag, 49 Tage entfernt bei
      // Gründung am Sonntag, 55 am Montag. Ein Tag Spiel nach beiden
      // Seiten, weil der Server die Uhr der Wehr nimmt und dieser Lauf
      // womöglich UTC.
      final ende = DateTime.parse(gruppe['laeuft_bis'] as String);
      expect(ende.weekday, DateTime.sunday);
      final tage = ende.difference(DateTime.now().toUtc()).inDays;
      expect(tage, inInclusiveRange(48, 56));

      final eigene = await gruenderin.from('lerngruppen').select('id, name');
      expect(eigene, hasLength(1));
      expect(eigene.single['name'], 'Winterprüfung');

      final mitglieder = await gruenderin
          .from('lerngruppen_mitglieder')
          .select('user_id');
      expect(mitglieder, hasLength(1));
      expect(mitglieder.single['user_id'], gruenderin.auth.currentUser!.id);
    });

    test('wer nicht drin ist, sieht die Gruppe nicht', () async {
      await gruppeAnlegen();

      expect(await zweite.from('lerngruppen').select('id'), isEmpty);
      expect(
        await zweite.from('lerngruppen_mitglieder').select('user_id'),
        isEmpty,
      );
      expect(await fremder.from('lerngruppen').select('id'), isEmpty);
    });

    test('über den Code tritt man bei und sieht danach beide', () async {
      final gruppe = await gruppeAnlegen();

      await zweite.rpc(
        'tritt_lerngruppe_bei',
        params: {'p_code': gruppe['code']},
      );

      expect(await zweite.from('lerngruppen').select('id'), hasLength(1));
      for (final wer in [gruenderin, zweite]) {
        final mitglieder = await wer
            .from('lerngruppen_mitglieder')
            .select('user_id');
        expect(mitglieder, hasLength(2));
      }
    });

    test('ein falscher Code, eine abgelaufene und eine fremde Gruppe '
        'werden unterschiedlich abgelehnt', () async {
      final gruppe = await gruppeAnlegen();

      await expectLater(
        zweite.rpc('tritt_lerngruppe_bei', params: {'p_code': '000000'}),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('gibt es nicht'),
          ),
        ),
      );

      // Abgelaufen: dasselbe Datum, das die App als „beendet" anzeigt.
      await asService(
        (s) => s
            .from('lerngruppen')
            .update({'laeuft_bis': '2020-01-01'})
            .eq('id', gruppe['id'] as String),
      );
      await expectLater(
        zweite.rpc('tritt_lerngruppe_bei', params: {'p_code': gruppe['code']}),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('abgelaufen'),
          ),
        ),
      );

      // Und die Gruppe der anderen Wehr bleibt der anderen Wehr.
      await asService(
        (s) => s
            .from('lerngruppen')
            .update({'laeuft_bis': '2099-01-01'})
            .eq('id', gruppe['id'] as String),
      );
      await expectLater(
        fremder.rpc('tritt_lerngruppe_bei', params: {'p_code': gruppe['code']}),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
    });

    test('in einer fremden Gesamtwehr gründet niemand', () async {
      await expectLater(
        gruenderin.rpc(
          'erstelle_lerngruppe',
          params: {'p_gesamtwehr': wehr2, 'p_name': 'Fremd', 'p_wochen': 8},
        ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
    });

    test('verlassen wirkt nur auf die eigene Zeile', () async {
      final gruppe = await gruppeAnlegen();
      await zweite.rpc(
        'tritt_lerngruppe_bei',
        params: {'p_code': gruppe['code']},
      );

      await zweite.rpc(
        'verlasse_lerngruppe',
        params: {'p_gruppe': gruppe['id']},
      );

      expect(await zweite.from('lerngruppen').select('id'), isEmpty);
      expect(
        await gruenderin.from('lerngruppen_mitglieder').select('user_id'),
        hasLength(1),
      );
    });

    test('direkt schreiben geht an beiden Tabellen nicht', () async {
      final gruppe = await gruppeAnlegen();

      await erwarteKeinenDurchgriff(
        () => zweite.from('lerngruppen').insert({
          'gesamtwehr_id': wehr1,
          'name': 'Selbst gebaut',
          'code': '123456',
          'laeuft_bis': '2099-01-01',
        }),
      );
      await erwarteKeinenDurchgriff(
        () => zweite.from('lerngruppen_mitglieder').insert({
          'gruppe_id': gruppe['id'],
          'user_id': zweite.auth.currentUser!.id,
        }),
      );

      expect(await zweite.from('lerngruppen').select('id'), isEmpty);
      expect(
        await gruenderin.from('lerngruppen_mitglieder').select('user_id'),
        hasLength(1),
      );
    });
  });

  group('Mitgliedernamen', () {
    test('die Gruppe sieht Anzeigename, Rückfall und Avatar', () async {
      final gruppe = await gruppeAnlegen();
      await zweite.rpc(
        'tritt_lerngruppe_bei',
        params: {'p_code': gruppe['code']},
      );

      final roh = await zweite.rpc(
        'lerngruppen_mitglieder_namen',
        params: {'p_gruppe': gruppe['id']},
      );
      final zeilen = [
        for (final r in roh as List) (r as Map).cast<String, dynamic>(),
      ];

      expect(zeilen, hasLength(2));
      // Beitrittsreihenfolge: die Gründerin zuerst.
      expect(zeilen.first['user_id'], gruenderin.auth.currentUser!.id);
      expect(zeilen.first['anzeigename'], 'Lea vom Löschzug');
      expect(zeilen.first['avatar'], 'helm=rot');
      // Ohne Anzeigenamen steht der Nutzername da — und nicht nichts.
      expect(zeilen.last['user_id'], zweite.auth.currentUser!.id);
      expect(zeilen.last['anzeigename'], 'member');

      // Und sonst nichts: Rolle und Kontozustand bleiben im Profil.
      expect(zeilen.first.keys.toSet(), {
        'user_id',
        'anzeigename',
        'avatar',
        'beigetreten_am',
      });
    });

    test('ein Nichtmitglied bekommt eine leere Liste', () async {
      final gruppe = await gruppeAnlegen();

      // Der Fremde kennt die Kennung (im Test geschenkt, im Feld aus einem
      // weitergereichten Screenshot) — die Funktion antwortet trotzdem nicht.
      expect(
        await fremder.rpc(
          'lerngruppen_mitglieder_namen',
          params: {'p_gruppe': gruppe['id']},
        ),
        isEmpty,
      );
      // Auch die zweite Person der eigenen Wehr, solange sie nicht beitritt.
      expect(
        await zweite.rpc(
          'lerngruppen_mitglieder_namen',
          params: {'p_gruppe': gruppe['id']},
        ),
        isEmpty,
      );
    });
  });

  group('Wochenaufgabe und Wertung', () {
    const vierModi = {
      'compartment',
      'image_recognition',
      'cutaway',
      'dragdrop',
    };

    Future<({String woche, String modus})?> aufgabe(
      SupabaseClient wer,
      String gruppe, [
      String? tag,
    ]) async {
      final roh =
          await wer.rpc(
                'lerngruppe_wochenaufgabe',
                params: {'p_gruppe': gruppe, if (tag != null) 'p_tag': tag},
              )
              as List;
      if (roh.isEmpty) return null;
      final z = (roh.single as Map).cast<String, dynamic>();
      return (woche: z['woche'] as String, modus: z['modus'] as String);
    }

    Future<List<Map<String, dynamic>>> wertungen(SupabaseClient wer) async => [
      for (final r in await wer.from('lerngruppen_wertungen').select('*'))
        r.cast<String, dynamic>(),
    ];

    /// Gruppe mit beiden Mitgliedern aus Wehr 1.
    Future<String> gruppeZuZweit() async {
      final gruppe = await gruppeAnlegen();
      await zweite.rpc(
        'tritt_lerngruppe_bei',
        params: {'p_code': gruppe['code']},
      );
      return gruppe['id'] as String;
    }

    test('die Aufgabe ist ein Montag und einer der vier Modi', () async {
      final gruppe = await gruppeZuZweit();

      final a = await aufgabe(gruenderin, gruppe);
      expect(a, isNotNull);
      expect(DateTime.parse(a!.woche).weekday, DateTime.monday);
      expect(vierModi, contains(a.modus));
      // Beide Mitglieder sehen dieselbe Aufgabe — sonst wäre es keine
      // gemeinsame.
      expect(await aufgabe(zweite, gruppe), a);
    });

    test(
      'in vier Wochen ist jeder Modus einmal dran — ohne Karteikarten',
      () async {
        final gruppe = await gruppeZuZweit();
        final montag = DateTime.parse(
          (await aufgabe(gruenderin, gruppe))!.woche,
        );

        final modi = <String>{};
        for (var i = 0; i < 4; i++) {
          final tag = montag.add(Duration(days: 7 * i + 3));
          final a = await aufgabe(
            gruenderin,
            gruppe,
            tag.toIso8601String().substring(0, 10),
          );
          modi.add(a!.modus);
        }
        expect(modi, vierModi);

        // Auch vor der Gründungswoche kein NULL (Vorzeichen von `%`).
        final vorher = await aufgabe(gruenderin, gruppe, '2000-01-05');
        expect(vierModi, contains(vorher!.modus));
      },
    );

    test('wer nicht drin ist, erfährt die Aufgabe nicht', () async {
      final gruppe = await gruppeAnlegen();
      expect(await aufgabe(zweite, gruppe['id'] as String), isNull);
      expect(await aufgabe(fremder, gruppe['id'] as String), isNull);
    });

    test('melden legt EINE Zeile an und überschreibt sie danach', () async {
      final gruppe = await gruppeZuZweit();
      final a = (await aufgabe(zweite, gruppe))!;

      await zweite.rpc(
        'melde_lerngruppen_wert',
        params: {'p_gruppe': gruppe, 'p_modus': a.modus, 'p_wert': 60},
      );
      await zweite.rpc(
        'melde_lerngruppen_wert',
        params: {'p_gruppe': gruppe, 'p_modus': a.modus, 'p_wert': 85},
      );

      // Die Gründerin sieht den Wert der zweiten — dafür ist er da.
      final zeilen = await wertungen(gruenderin);
      expect(zeilen, hasLength(1));
      expect(zeilen.single['user_id'], zweite.auth.currentUser!.id);
      expect(zeilen.single['wert'], 85);
      expect(zeilen.single['woche'], a.woche);
      expect(zeilen.single['modus'], a.modus);

      // ⚠️ Und NICHTS sonst: keine Fragen, kein Gerät, keine Rundenzahl.
      // Wer der Tabelle eine Spalte gibt, muss hier begründen, warum.
      expect(zeilen.single.keys.toSet(), {
        'gruppe_id',
        'user_id',
        'woche',
        'modus',
        'wert',
        'gemeldet_am',
      });
    });

    test('ein falscher Modus, ein Wert über 100 und ein Nichtmitglied '
        'werden abgelehnt', () async {
      final gruppe = await gruppeAnlegen();
      final id = gruppe['id'] as String;
      final a = (await aufgabe(gruenderin, id))!;
      final falsch = vierModi.firstWhere((m) => m != a.modus);

      await expectLater(
        gruenderin.rpc(
          'melde_lerngruppen_wert',
          params: {'p_gruppe': id, 'p_modus': falsch, 'p_wert': 50},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('gewechselt'),
          ),
        ),
      );
      // Karteikarten sind nie die Aufgabe — also auch nie meldbar.
      await expectLater(
        gruenderin.rpc(
          'melde_lerngruppen_wert',
          params: {'p_gruppe': id, 'p_modus': 'flashcards', 'p_wert': 50},
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        gruenderin.rpc(
          'melde_lerngruppen_wert',
          params: {'p_gruppe': id, 'p_modus': a.modus, 'p_wert': 101},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('zwischen 0 und 100'),
          ),
        ),
      );
      await expectLater(
        fremder.rpc(
          'melde_lerngruppen_wert',
          params: {'p_gruppe': id, 'p_modus': a.modus, 'p_wert': 50},
        ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
      expect(await wertungen(gruenderin), isEmpty);
    });

    test('in eine abgelaufene Gruppe meldet niemand mehr', () async {
      final gruppe = await gruppeAnlegen();
      final id = gruppe['id'] as String;
      final a = (await aufgabe(gruenderin, id))!;
      await asService(
        (s) => s
            .from('lerngruppen')
            .update({'laeuft_bis': '2020-01-05'})
            .eq('id', id),
      );

      await expectLater(
        gruenderin.rpc(
          'melde_lerngruppen_wert',
          params: {'p_gruppe': id, 'p_modus': a.modus, 'p_wert': 50},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('abgelaufen'),
          ),
        ),
      );
    });

    test(
      'Außenstehende sehen keine Werte, direkt schreiben geht nicht',
      () async {
        final gruppe = await gruppeAnlegen();
        final id = gruppe['id'] as String;
        final a = (await aufgabe(gruenderin, id))!;
        await gruenderin.rpc(
          'melde_lerngruppen_wert',
          params: {'p_gruppe': id, 'p_modus': a.modus, 'p_wert': 70},
        );

        // Die zweite ist in derselben Wehr, aber nicht in der Gruppe.
        expect(await wertungen(zweite), isEmpty);
        expect(await wertungen(fremder), isEmpty);

        await erwarteKeinenDurchgriff(
          () => gruenderin.from('lerngruppen_wertungen').insert({
            'gruppe_id': id,
            'user_id': gruenderin.auth.currentUser!.id,
            'woche': '2020-01-06',
            'modus': a.modus,
            'wert': 100,
          }),
        );
        await erwarteKeinenDurchgriff(
          () => gruenderin
              .from('lerngruppen_wertungen')
              .update({'wert': 100})
              .eq('gruppe_id', id),
        );
        expect((await wertungen(gruenderin)).single['wert'], 70);
      },
    );

    test('wer die Gruppe verlässt, nimmt seine Werte mit', () async {
      final gruppe = await gruppeZuZweit();
      final a = (await aufgabe(zweite, gruppe))!;
      for (final wer in [gruenderin, zweite]) {
        await wer.rpc(
          'melde_lerngruppen_wert',
          params: {'p_gruppe': gruppe, 'p_modus': a.modus, 'p_wert': 40},
        );
      }
      expect(await wertungen(gruenderin), hasLength(2));

      await zweite.rpc('verlasse_lerngruppe', params: {'p_gruppe': gruppe});

      final uebrig = await wertungen(gruenderin);
      expect(uebrig, hasLength(1));
      expect(uebrig.single['user_id'], gruenderin.auth.currentUser!.id);
    });
  });

  group('Ohne Anmeldung', () {
    test('anon kommt weder an die Tabellen noch an die Funktionen', () async {
      final gruppe = await gruppeAnlegen();
      final anon = SupabaseClient(_url, _anonKey);
      addTearDown(anon.dispose);

      for (final tabelle in [
        'lerngruppen',
        'lerngruppen_mitglieder',
        'lerngruppen_wertungen',
      ]) {
        await expectLater(
          anon.from(tabelle).select('*'),
          throwsA(isA<PostgrestException>()),
        );
      }
      await expectLater(
        anon.rpc('tritt_lerngruppe_bei', params: {'p_code': gruppe['code']}),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anon.rpc(
          'lerngruppen_mitglieder_namen',
          params: {'p_gruppe': gruppe['id']},
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anon.rpc(
          'lerngruppe_wochenaufgabe',
          params: {'p_gruppe': gruppe['id']},
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anon.rpc(
          'melde_lerngruppen_wert',
          params: {'p_gruppe': gruppe['id'], 'p_modus': 'cutaway', 'p_wert': 1},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
