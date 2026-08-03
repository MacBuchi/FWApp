/// temp_rechte_e2e_test.dart – Temporäre Gerätewart-Rechte (Nutzerkonzept
/// Stufe ③, Issue #100) gegen den LOKALEN Supabase-Stack (`supabase start`).
/// Überspringt sich selbst, wenn er nicht läuft.
///
/// Warum das kein Widget-Test sein kann: Die Aussage, um die es geht, ist
/// **„ein befristetes Recht schaltet Bearbeiten frei, aber niemals
/// Verwalten"** — und die entsteht erst aus dem Zusammenspiel von Tabelle,
/// Rechte-Helfern und RLS. Ein Fake würde genau die Stelle nachbauen, die zu
/// prüfen ist. Stimmt sie nicht, macht sich ein Übungsteilnehmer für zwölf
/// Stunden selbst zum Kommandanten.
///
/// Braucht die lokalen Testkonten aus tool/setup_local_supabase.sh:
///   admin@fw.local / geraetewart@fw.local / member@fw.local, pw test1234
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

String _in(Duration d) => DateTime.now().toUtc().add(d).toIso8601String();

Future<void> main() async {
  if (!await _erreichbar('$_url/auth/v1/health')) {
    test(
      'temporaere rechte e2e',
      () {},
      skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).',
    );
    return;
  }

  late SupabaseClient kommandant; // admin@fw.local, Feuerwehrkommandant
  late SupabaseClient wart; // geraetewart@fw.local, Gerätewart in A
  late SupabaseClient truppfuehrer; // member@fw.local, nur Mitglied in A

  Future<T> asService<T>(Future<T> Function(SupabaseClient) body) async {
    final service = SupabaseClient(_url, _serviceRoleKey);
    try {
      return await body(service);
    } finally {
      await service.dispose();
    }
  }

  late String gesamtwehrId;
  late String abteilungA;
  late String abteilungB;

  Future<void> alleRechteWeg() => asService((s) async {
    await s.from('temporaere_rechte').delete().inFilter('abteilung_id', [
      abteilungA,
      abteilungB,
    ]);
  });

  setUpAll(() async {
    await stackSperreHolen();
    kommandant = SupabaseClient(_url, _anonKey);
    wart = SupabaseClient(_url, _anonKey);
    truppfuehrer = SupabaseClient(_url, _anonKey);
    await kommandant.auth.signInWithPassword(
      email: 'admin@fw.local',
      password: 'test1234',
    );
    await wart.auth.signInWithPassword(
      email: 'geraetewart@fw.local',
      password: 'test1234',
    );
    await truppfuehrer.auth.signInWithPassword(
      email: 'member@fw.local',
      password: 'test1234',
    );

    await asService((s) async {
      final gw =
          await s
              .from('gesamtwehren')
              .insert({'name': 'GW Uebung', 'slug': 'gw-uebung'})
              .select('id')
              .single();
      gesamtwehrId = gw['id'] as String;
      for (final name in ['Uebung A', 'Uebung B']) {
        final abt =
            await s
                .from('abteilungen')
                .insert({
                  'name': name,
                  'slug': name.toLowerCase().replaceAll(' ', '-'),
                  'status': 'active',
                  'gesamtwehr_id': gesamtwehrId,
                })
                .select('id')
                .single();
        if (name.endsWith('A')) {
          abteilungA = abt['id'] as String;
        } else {
          abteilungB = abt['id'] as String;
        }
      }
      await s.from('memberships').upsert([
        {
          'user_id': wart.auth.currentUser!.id,
          'abteilung_id': abteilungA,
          'role': 'geraetewart',
        },
        // Der Truppführer: Mitglied in A, ohne Schreibrolle. Genau der Fall,
        // für den es die Übungsrechte gibt.
        {
          'user_id': truppfuehrer.auth.currentUser!.id,
          'abteilung_id': abteilungA,
          'role': 'member',
        },
      ]);
      await s.from('gesamtwehr_kommandanten').upsert({
        'user_id': kommandant.auth.currentUser!.id,
        'gesamtwehr_id': gesamtwehrId,
      });
    });
  });

  tearDownAll(() async {
    await asService((s) async {
      await s.from('temporaere_rechte').delete().inFilter('abteilung_id', [
        abteilungA,
        abteilungB,
      ]);
      await s.from('memberships').delete().inFilter('abteilung_id', [
        abteilungA,
        abteilungB,
      ]);
      await s
          .from('gesamtwehr_kommandanten')
          .delete()
          .eq('gesamtwehr_id', gesamtwehrId);
      await s.from('abteilungen').delete().inFilter('id', [
        abteilungA,
        abteilungB,
      ]);
      await s.from('gesamtwehren').delete().eq('id', gesamtwehrId);
    });
    await kommandant.dispose();
    await wart.dispose();
    await truppfuehrer.dispose();
    await stackSperreFreigeben();
  });

  setUp(alleRechteWeg);

  group('erteilen', () {
    test('der Gerätewart erteilt seinem Truppführer Übungsrechte', () async {
      // Ausdrücklich der GERÄTEWART, nicht nur der Kommandant: Er steht bei
      // der Übung daneben. Müsste man dafür den Kommandanten holen, würde die
      // Funktion im Feld nicht benutzt.
      final id = await wart.rpc(
        'temp_recht_erteilen',
        params: {
          'ziel_user': truppfuehrer.auth.currentUser!.id,
          'ziel_abteilung': abteilungA,
          'bis': _in(const Duration(hours: 3)),
        },
      );
      expect(id, isA<String>());
    });

    test('und der Truppführer darf danach veröffentlichen', () async {
      // DIE Aussage des ganzen Features — geprüft an derselben Funktion, die
      // der Publish-Weg benutzt.
      expect(
        await truppfuehrer.rpc(
          'can_publish_abteilung',
          params: {'target': abteilungA},
        ),
        isFalse,
        reason: 'ohne Recht darf er nicht — sonst beweist der Rest nichts',
      );
      await wart.rpc(
        'temp_recht_erteilen',
        params: {
          'ziel_user': truppfuehrer.auth.currentUser!.id,
          'ziel_abteilung': abteilungA,
          'bis': _in(const Duration(hours: 3)),
        },
      );
      expect(
        await truppfuehrer.rpc(
          'can_publish_abteilung',
          params: {'target': abteilungA},
        ),
        isTrue,
      );
    });

    test('aber NICHT Mitglieder verwalten', () async {
      // Die Grenze, die das Feature erst vertretbar macht.
      await wart.rpc(
        'temp_recht_erteilen',
        params: {
          'ziel_user': truppfuehrer.auth.currentUser!.id,
          'ziel_abteilung': abteilungA,
          'bis': _in(const Duration(hours: 3)),
        },
      );
      expect(
        await truppfuehrer.rpc(
          'darf_mitglieder_verwalten',
          params: {'ziel_abteilung': abteilungA, 'ziel_rolle': null},
        ),
        isFalse,
      );
    });

    test('und auch nicht selbst Übungsrechte weitergeben', () async {
      await wart.rpc(
        'temp_recht_erteilen',
        params: {
          'ziel_user': truppfuehrer.auth.currentUser!.id,
          'ziel_abteilung': abteilungA,
          'bis': _in(const Duration(hours: 3)),
        },
      );
      // Sonst verlängert sich eine Kette von Übungsrechten selbst über den
      // Ablauf hinaus.
      expect(
        await truppfuehrer.rpc(
          'darf_temporaeres_recht_erteilen',
          params: {'ziel_abteilung': abteilungA},
        ),
        isFalse,
      );
    });

    test('ein abgelaufenes Recht wirkt nicht mehr', () async {
      await asService((s) async {
        await s.from('temporaere_rechte').insert({
          'user_id': truppfuehrer.auth.currentUser!.id,
          'abteilung_id': abteilungA,
          'laeuft_ab':
              DateTime.now()
                  .toUtc()
                  .subtract(const Duration(minutes: 1))
                  .toIso8601String(),
        });
      });
      expect(
        await truppfuehrer.rpc(
          'can_publish_abteilung',
          params: {'target': abteilungA},
        ),
        isFalse,
      );
    });

    test('ein zurückgezogenes Recht wirkt sofort nicht mehr', () async {
      final id =
          await wart.rpc(
                'temp_recht_erteilen',
                params: {
                  'ziel_user': truppfuehrer.auth.currentUser!.id,
                  'ziel_abteilung': abteilungA,
                  'bis': _in(const Duration(hours: 3)),
                },
              )
              as String;
      await wart.rpc('temp_recht_zurueckziehen', params: {'ziel': id});
      expect(
        await truppfuehrer.rpc(
          'can_publish_abteilung',
          params: {'target': abteilungA},
        ),
        isFalse,
      );
      // Das Protokoll bleibt: Die Zeile ist noch da, nur entwertet.
      final zeilen = await asService(
        (s) async => await s
            .from('temporaere_rechte')
            .select('id, zurueckgezogen_am')
            .eq('id', id),
      );
      expect(zeilen, hasLength(1));
      expect(zeilen.first['zurueckgezogen_am'], isNotNull);
    });

    test('erneutes Erteilen verlängert, statt zu scheitern', () async {
      final erst =
          await wart.rpc(
                'temp_recht_erteilen',
                params: {
                  'ziel_user': truppfuehrer.auth.currentUser!.id,
                  'ziel_abteilung': abteilungA,
                  'bis': _in(const Duration(hours: 1)),
                },
              )
              as String;
      final zweit =
          await wart.rpc(
                'temp_recht_erteilen',
                params: {
                  'ziel_user': truppfuehrer.auth.currentUser!.id,
                  'ziel_abteilung': abteilungA,
                  'bis': _in(const Duration(hours: 5)),
                },
              )
              as String;
      expect(zweit, erst, reason: 'dieselbe Zeile, nur später ablaufend');
      final zeilen = await asService(
        (s) async => await s
            .from('temporaere_rechte')
            .select('id')
            .eq('abteilung_id', abteilungA),
      );
      expect(zeilen, hasLength(1));
    });
  });

  group('Grenzen', () {
    test('der Truppführer kann sich nichts selbst erteilen', () async {
      await expectLater(
        truppfuehrer.rpc(
          'temp_recht_erteilen',
          params: {
            'ziel_user': truppfuehrer.auth.currentUser!.id,
            'ziel_abteilung': abteilungA,
            'bis': _in(const Duration(hours: 3)),
          },
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('temporaeres recht erteilen'),
          ),
        ),
      );
    });

    test('nicht an jemanden, der gar nicht zur Abteilung gehört', () async {
      // Ein Recht ist eine Erweiterung, kein Zugang: Es darf niemandem den
      // Bestand einer fremden Abteilung öffnen.
      await expectLater(
        kommandant.rpc(
          'temp_recht_erteilen',
          params: {
            'ziel_user': truppfuehrer.auth.currentUser!.id,
            'ziel_abteilung': abteilungB,
            'bis': _in(const Duration(hours: 3)),
          },
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('not a member'),
          ),
        ),
      );
    });

    test('nicht an jemanden, der ohnehin schon schreiben darf', () async {
      // Sonst stünde beim Gerätewart „Rechte laufen um 18 Uhr ab" — und das
      // wäre schlicht gelogen.
      await expectLater(
        kommandant.rpc(
          'temp_recht_erteilen',
          params: {
            'ziel_user': wart.auth.currentUser!.id,
            'ziel_abteilung': abteilungA,
            'bis': _in(const Duration(hours: 3)),
          },
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('already permanent'),
          ),
        ),
      );
    });

    test('nicht länger als 24 Stunden', () async {
      await expectLater(
        wart.rpc(
          'temp_recht_erteilen',
          params: {
            'ziel_user': truppfuehrer.auth.currentUser!.id,
            'ziel_abteilung': abteilungA,
            'bis': _in(const Duration(hours: 25)),
          },
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('expiry too far away'),
          ),
        ),
      );
    });

    test('und nicht rückwirkend', () async {
      await expectLater(
        wart.rpc(
          'temp_recht_erteilen',
          params: {
            'ziel_user': truppfuehrer.auth.currentUser!.id,
            'ziel_abteilung': abteilungA,
            'bis': _in(const Duration(hours: -1)),
          },
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('expiry must be in the future'),
          ),
        ),
      );
    });
  });

  group('Sichtbarkeit', () {
    test('der Empfänger sieht sein eigenes Recht', () async {
      // Ohne das gäbe es den Hinweis auf der Startseite nicht — und er wüsste
      // nicht, bis wann er arbeiten kann.
      await wart.rpc(
        'temp_recht_erteilen',
        params: {
          'ziel_user': truppfuehrer.auth.currentUser!.id,
          'ziel_abteilung': abteilungA,
          'bis': _in(const Duration(hours: 3)),
        },
      );
      final meine = await truppfuehrer
          .from('temporaere_rechte')
          .select('id, laeuft_ab');
      expect(meine, hasLength(1));
    });

    test('ein Unbeteiligter sieht das Protokoll NICHT', () async {
      await wart.rpc(
        'temp_recht_erteilen',
        params: {
          'ziel_user': truppfuehrer.auth.currentUser!.id,
          'ziel_abteilung': abteilungA,
          'bis': _in(const Duration(hours: 3)),
        },
      );
      // Der Truppführer darf in A nicht erteilen, also geht ihn das Protokoll
      // der anderen nichts an — er sieht nur die eigene Zeile.
      final alles = await truppfuehrer
          .from('temporaere_rechte')
          .select('id, user_id')
          .eq('abteilung_id', abteilungA);
      expect(
        alles.every((r) => r['user_id'] == truppfuehrer.auth.currentUser!.id),
        isTrue,
      );
    });

    test(
      'wer erteilen darf, sieht das ganze Protokoll der Abteilung',
      () async {
        await wart.rpc(
          'temp_recht_erteilen',
          params: {
            'ziel_user': truppfuehrer.auth.currentUser!.id,
            'ziel_abteilung': abteilungA,
            'bis': _in(const Duration(hours: 3)),
          },
        );
        final ausSichtDesWarts = await wart
            .from('temporaere_rechte')
            .select('id, user_id, erteilt_von')
            .eq('abteilung_id', abteilungA);
        expect(ausSichtDesWarts, hasLength(1));
        expect(
          ausSichtDesWarts.first['erteilt_von'],
          wart.auth.currentUser!.id,
          reason: 'wer wem wann — das Protokoll IST die Tabelle',
        );
      },
    );
  });
}
