/// lernbereiche_e2e_test.dart – Abgeschaltete Lernbereiche (Marcus,
/// 2026-08-28) und Hinweise an Fragen (Issue #194) gegen den LOKALEN
/// Supabase-Stack (`supabase start`). Überspringt sich selbst, wenn er nicht
/// läuft.
///
/// **Warum das kein Widget-Test sein kann.** Beide Zusicherungen entstehen
/// erst aus dem Zusammenspiel von RLS, Grants und den geprüften Funktionen:
/// „**nur der Gerätewart schaltet ab, aber jeder in der Wehr sieht es**" und
/// „**ein Hinweis auf eine Frage der eigenen Wehr bleibt in der Wehr**". Ein
/// Fake würde genau die Stelle nachbauen, die zu prüfen ist.
///
/// Die Lehre aus #198 steht hier Pate: Drei Schreibpfade waren von keinem
/// Test gedeckt, und ein zu weiter `revoke` wäre erst auf der VM aufgefallen.
/// Diese beiden Tabellen bekommen ihre Prüfung deshalb sofort mit.
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
      'lernbereiche e2e',
      () {},
      skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).',
    );
    return;
  }

  late SupabaseClient wart; // geraetewart@fw.local, Gerätewart in Wehr 1
  late SupabaseClient mitglied; // member@fw.local, nur Mitglied in Wehr 1
  late SupabaseClient fremder; // admin@fw.local, Mitglied in Wehr 2

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

  /// Eine eigene Frage der Wehr — der Aufhänger für die Hinweise.
  late String frage1;
  late String frage2; // gehört Wehr 2

  Future<void> aufraeumen() => asService((s) async {
    await s.from('frage_hinweise').delete().inFilter('gesamtwehr_id', [
      wehr1,
      wehr2,
    ]);
    await s
        .from('abgeschaltete_lernbereiche')
        .delete()
        .inFilter('gesamtwehr_id', [wehr1, wehr2]);
  });

  setUpAll(() async {
    await stackSperreHolen();
    wart = SupabaseClient(_url, _anonKey);
    mitglied = SupabaseClient(_url, _anonKey);
    fremder = SupabaseClient(_url, _anonKey);
    await wart.auth.signInWithPassword(
      email: 'geraetewart@fw.local',
      password: 'test1234',
    );
    await mitglied.auth.signInWithPassword(
      email: 'member@fw.local',
      password: 'test1234',
    );
    await fremder.auth.signInWithPassword(
      email: 'admin@fw.local',
      password: 'test1234',
    );

    await asService((s) async {
      for (final name in ['Lernwehr Eins', 'Lernwehr Zwei']) {
        final slug = name.toLowerCase().replaceAll(' ', '-');
        final gw = await s
            .from('gesamtwehren')
            .insert({'name': name, 'slug': slug})
            .select('id')
            .single();
        final abt = await s
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
          'user_id': wart.auth.currentUser!.id,
          'abteilung_id': abteilung1,
          'role': 'geraetewart',
        },
        {
          'user_id': mitglied.auth.currentUser!.id,
          'abteilung_id': abteilung1,
          'role': 'member',
        },
        // Der Fremde gehört zu Wehr 2 — er ist Mitglied, nur eben der
        // falschen Wehr. Genau der Fall, den die Lese-Policy trennen muss.
        {
          'user_id': fremder.auth.currentUser!.id,
          'abteilung_id': abteilung2,
          'role': 'geraetewart',
        },
      ]);

      for (final eintrag in [
        (wehr1, 'Wie lang ist ein B-Schlauch?'),
        (wehr2, 'Wie breit ist ein C-Schlauch?'),
      ]) {
        final f = await s
            .from('quiz_questions')
            .insert({
              'gesamtwehr_id': eintrag.$1,
              'gebiet': 'geraetekunde',
              'frage': eintrag.$2,
              'antworten_json': '["20 m","5 m"]',
              'richtige_json': '[0]',
              'herkunft': 'eigen',
              'stand': 'freigegeben',
            })
            .select('id')
            .single();
        if (eintrag.$1 == wehr1) {
          frage1 = f['id'] as String;
        } else {
          frage2 = f['id'] as String;
        }
      }
    });
  });

  tearDownAll(() async {
    await aufraeumen();
    await asService((s) async {
      await s.from('quiz_questions').delete().inFilter('gesamtwehr_id', [
        wehr1,
        wehr2,
      ]);
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
    await wart.dispose();
    await mitglied.dispose();
    await fremder.dispose();
    await stackSperreFreigeben();
  });

  setUp(aufraeumen);

  group('Lernbereiche abschalten', () {
    test('der Gerätewart schaltet ein Gebiet ab und wieder ein', () async {
      await wart.rpc('setze_lernbereich', params: {
        'gw': wehr1,
        'p_gebiet': 'atemschutz',
        'p_kapitel': null,
        'aus': true,
      });

      final aus = await wart
          .from('abgeschaltete_lernbereiche')
          .select()
          .eq('gesamtwehr_id', wehr1);
      expect(aus, hasLength(1));
      expect(aus.single['gebiet'], 'atemschutz');
      expect(aus.single['kapitel'], isNull, reason: 'NULL = ganzes Gebiet');

      await wart.rpc('setze_lernbereich', params: {
        'gw': wehr1,
        'p_gebiet': 'atemschutz',
        'p_kapitel': null,
        'aus': false,
      });
      expect(
        await wart
            .from('abgeschaltete_lernbereiche')
            .select()
            .eq('gesamtwehr_id', wehr1),
        isEmpty,
      );
    });

    test('zweimal abschalten legt keine zweite Zeile an', () async {
      // Der Grund für den Ausdrucks-Index: Zwei NULL sind in Postgres
      // verschieden, ein schlichtes UNIQUE ließe „ganzes Gebiet aus"
      // beliebig oft zu — und dann bliebe beim Einschalten eine Zeile
      // stehen und das Gebiet stumm abgeschaltet.
      for (var i = 0; i < 2; i++) {
        await wart.rpc('setze_lernbereich', params: {
          'gw': wehr1,
          'p_gebiet': 'funk',
          'p_kapitel': null,
          'aus': true,
        });
      }
      expect(
        await wart
            .from('abgeschaltete_lernbereiche')
            .select()
            .eq('gesamtwehr_id', wehr1),
        hasLength(1),
      );
    });

    test('Gebiet und Kapitel sind zwei verschiedene Zeilen', () async {
      await wart.rpc('setze_lernbereich', params: {
        'gw': wehr1,
        'p_gebiet': 'gefahrgut',
        'p_kapitel': 'Dekontamination',
        'aus': true,
      });
      await wart.rpc('setze_lernbereich', params: {
        'gw': wehr1,
        'p_gebiet': 'gefahrgut',
        'p_kapitel': null,
        'aus': true,
      });
      expect(
        await wart
            .from('abgeschaltete_lernbereiche')
            .select()
            .eq('gesamtwehr_id', wehr1),
        hasLength(2),
      );
    });

    test('ein Leerstring meint dasselbe wie NULL: das ganze Gebiet', () async {
      // Sonst legte ein Client mit '' eine zweite Zeile neben die mit NULL,
      // und das Einschalten träfe nur eine davon.
      await wart.rpc('setze_lernbereich', params: {
        'gw': wehr1,
        'p_gebiet': 'funk',
        'p_kapitel': '',
        'aus': true,
      });
      final aus = await wart
          .from('abgeschaltete_lernbereiche')
          .select()
          .eq('gesamtwehr_id', wehr1);
      expect(aus, hasLength(1));
      expect(aus.single['kapitel'], isNull);
    });

    test('ein Mitglied ohne Schreibrolle darf NICHT abschalten', () async {
      // Die Entscheidung gilt für die ganze Wehr — sie gehört dem
      // Gerätewart, nicht jedem mit Konto.
      await expectLater(
        mitglied.rpc('setze_lernbereich', params: {
          'gw': wehr1,
          'p_gebiet': 'atemschutz',
          'p_kapitel': null,
          'aus': true,
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        await asService((s) => s
            .from('abgeschaltete_lernbereiche')
            .select()
            .eq('gesamtwehr_id', wehr1)),
        isEmpty,
      );
    });

    test('ein Gerätewart einer FREMDEN Wehr darf nicht in unsere schalten',
        () async {
      await expectLater(
        fremder.rpc('setze_lernbereich', params: {
          'gw': wehr1,
          'p_gebiet': 'atemschutz',
          'p_kapitel': null,
          'aus': true,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('jeder in der Wehr SIEHT die Abschaltung — sie wirkt auf jedem Gerät',
        () async {
      await wart.rpc('setze_lernbereich', params: {
        'gw': wehr1,
        'p_gebiet': 'atemschutz',
        'p_kapitel': null,
        'aus': true,
      });
      expect(
        await mitglied
            .from('abgeschaltete_lernbereiche')
            .select()
            .eq('gesamtwehr_id', wehr1),
        hasLength(1),
      );
    });

    test('eine fremde Wehr sieht davon nichts', () async {
      await wart.rpc('setze_lernbereich', params: {
        'gw': wehr1,
        'p_gebiet': 'atemschutz',
        'p_kapitel': null,
        'aus': true,
      });
      expect(await fremder.from('abgeschaltete_lernbereiche').select(),
          isEmpty);
    });

    test('an der Funktion vorbei geht nichts', () async {
      // Der Entzug aus der Migration, gemessen statt geglaubt (#198).
      await erwarteKeinenDurchgriff(() async {
        await wart.from('abgeschaltete_lernbereiche').insert({
          'gesamtwehr_id': wehr1,
          'gebiet': 'atemschutz',
        });
      });
      expect(
        await asService((s) => s
            .from('abgeschaltete_lernbereiche')
            .select()
            .eq('gesamtwehr_id', wehr1)),
        isEmpty,
      );
    });
  });

  group('Hinweise an Fragen', () {
    test('jedes Mitglied darf einen Hinweis geben', () async {
      // Dieselbe Linie wie beim Einreichen einer Frage: beitragen darf
      // jeder, entscheiden nur der Gerätewart.
      await mitglied.rpc('melde_frage_hinweis', params: {
        'gw': wehr1,
        'p_frage': frage1,
        'text_hinweis': 'Seit der Neufassung sind es 20 m, nicht 15 m.',
        'melder_name': 'Truppführer',
      });

      final hinweise =
          await wart.from('frage_hinweise').select().eq('gesamtwehr_id', wehr1);
      expect(hinweise, hasLength(1));
      expect(hinweise.single['von_name'], 'Truppführer');
      expect(hinweise.single['erledigt_am'], isNull);
    });

    test('eine Frage einer FREMDEN Wehr lässt sich nicht unterschieben',
        () async {
      // Ohne diese Prüfung könnte man an eine fremde Frage schreiben, indem
      // man die eigene Wehr-ID mitschickt.
      await expectLater(
        mitglied.rpc('melde_frage_hinweis', params: {
          'gw': wehr1,
          'p_frage': frage2,
          'text_hinweis': 'Gehört gar nicht hierher.',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('zu kurzer Text wird abgelehnt', () async {
      await expectLater(
        mitglied.rpc('melde_frage_hinweis', params: {
          'gw': wehr1,
          'p_frage': frage1,
          'text_hinweis': 'x',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('nur der Gerätewart hakt ab', () async {
      await mitglied.rpc('melde_frage_hinweis', params: {
        'gw': wehr1,
        'p_frage': frage1,
        'text_hinweis': 'Antwort b) ist auch richtig.',
      });
      final id = (await wart
              .from('frage_hinweise')
              .select('id')
              .eq('gesamtwehr_id', wehr1)
              .single())['id']
          as String;

      await expectLater(
        mitglied.rpc('erledige_frage_hinweis',
            params: {'hinweis_id': id, 'erledigt': true}),
        throwsA(isA<PostgrestException>()),
      );

      await wart.rpc('erledige_frage_hinweis',
          params: {'hinweis_id': id, 'erledigt': true});
      expect(
        (await wart.from('frage_hinweise').select().eq('id', id).single())[
            'erledigt_am'],
        isNotNull,
      );
    });

    test('abhaken lässt sich zurücknehmen', () async {
      // Wer versehentlich abhakt, soll das können, ohne dass der Hinweis
      // verloren geht.
      await mitglied.rpc('melde_frage_hinweis', params: {
        'gw': wehr1,
        'p_frage': frage1,
        'text_hinweis': 'Doch noch offen.',
      });
      final id = (await wart
              .from('frage_hinweise')
              .select('id')
              .eq('gesamtwehr_id', wehr1)
              .single())['id']
          as String;

      await wart.rpc('erledige_frage_hinweis',
          params: {'hinweis_id': id, 'erledigt': true});
      await wart.rpc('erledige_frage_hinweis',
          params: {'hinweis_id': id, 'erledigt': false});

      final zeile =
          await wart.from('frage_hinweise').select().eq('id', id).single();
      expect(zeile['erledigt_am'], isNull);
      expect(zeile['hinweis'], 'Doch noch offen.');
    });

    test('eine fremde Wehr liest die Hinweise nicht', () async {
      // Das ist der Kern von #194: Der Hinweis bleibt in der Wehr.
      await mitglied.rpc('melde_frage_hinweis', params: {
        'gw': wehr1,
        'p_frage': frage1,
        'text_hinweis': 'Bleibt unter uns.',
      });
      expect(await fremder.from('frage_hinweise').select(), isEmpty);
    });

    test('an der Funktion vorbei geht nichts', () async {
      await erwarteKeinenDurchgriff(() async {
        await mitglied.from('frage_hinweise').insert({
          'gesamtwehr_id': wehr1,
          'frage_id': frage1,
          'hinweis': 'Direkt geschrieben.',
        });
      });
      expect(
        await asService(
            (s) => s.from('frage_hinweise').select().eq('gesamtwehr_id', wehr1)),
        isEmpty,
      );
    });
  });
}
