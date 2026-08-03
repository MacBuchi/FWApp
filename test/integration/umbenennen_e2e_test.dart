/// umbenennen_e2e_test.dart – Abteilung und Gesamtwehr umbenennen (#119)
/// gegen den LOKALEN Supabase-Stack (`supabase start`). Überspringt sich
/// selbst, wenn er nicht läuft.
///
/// Warum das kein Widget-Test sein kann: Der Wert dieser Funktion liegt
/// vollständig in der Rechtegrenze, und die zieht die Datenbank. Ein Fake
/// würde genau die Stelle nachbauen, die zu prüfen ist. Stimmt sie nicht,
/// benennt der Kommandant der kleinsten Abteilung die ganze Gesamtwehr um.
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

/// Derselbe öffentlich dokumentierte Demo-Key wie in den übrigen E2E-Tests —
/// in jedem lokalen Stack identisch, kein Geheimnis.
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
      'umbenennen e2e',
      () {},
      skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).',
    );
    return;
  }

  late SupabaseClient kommandant; // admin@fw.local, Feuerwehrkommandant
  late SupabaseClient abteilungsChef; // member@fw.local, Kommandant von A
  late SupabaseClient wart; // geraetewart@fw.local, darf nichts umbenennen

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

  /// Liest den Namen am Server vorbei an jeder Client-Sicht.
  Future<String> nameDerAbteilung(String id) => asService((s) async {
    final row =
        await s.from('abteilungen').select('name').eq('id', id).single();
    return row['name'] as String;
  });

  Future<String> nameDerWehr() => asService((s) async {
    final row =
        await s
            .from('gesamtwehren')
            .select('name')
            .eq('id', gesamtwehrId)
            .single();
    return row['name'] as String;
  });

  setUpAll(() async {
    await stackSperreHolen();
    kommandant = SupabaseClient(_url, _anonKey);
    abteilungsChef = SupabaseClient(_url, _anonKey);
    wart = SupabaseClient(_url, _anonKey);
    await kommandant.auth.signInWithPassword(
      email: 'admin@fw.local',
      password: 'test1234',
    );
    await abteilungsChef.auth.signInWithPassword(
      email: 'member@fw.local',
      password: 'test1234',
    );
    await wart.auth.signInWithPassword(
      email: 'geraetewart@fw.local',
      password: 'test1234',
    );

    await asService((s) async {
      final gw =
          await s
              .from('gesamtwehren')
              .insert({'name': 'GW Umbenennen', 'slug': 'gw-umbenennen'})
              .select('id')
              .single();
      gesamtwehrId = gw['id'] as String;

      // Eigene Abteilungen statt der Spiegel-Abteilung — sync_e2e_test hängt
      // die woanders hin, siehe stack_sperre.dart.
      for (final name in ['Umbenennen A', 'Umbenennen B']) {
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
          'user_id': abteilungsChef.auth.currentUser!.id,
          'abteilung_id': abteilungA,
          'role': 'admin',
        },
        {
          'user_id': wart.auth.currentUser!.id,
          'abteilung_id': abteilungA,
          'role': 'geraetewart',
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
    await abteilungsChef.dispose();
    await wart.dispose();
    await stackSperreFreigeben();
  });

  group('rename_abteilung', () {
    test(
      'der Abteilungskommandant benennt seine eigene Abteilung um',
      () async {
        await abteilungsChef.rpc(
          'rename_abteilung',
          params: {'ziel': abteilungA, 'neuer_name': 'A frisch benannt'},
        );
        expect(await nameDerAbteilung(abteilungA), 'A frisch benannt');
      },
    );

    test('die Kennung und der Kennzeichner bleiben dabei stehen', () async {
      // Der Grund, aus dem umbenennen überhaupt gefahrlos ist: Alles, was auf
      // die Abteilung zeigt, zeigt weiter auf dieselbe Zeile.
      final vorher = await asService(
        (s) async =>
            await s
                .from('abteilungen')
                .select('id, slug')
                .eq('id', abteilungA)
                .single(),
      );
      await abteilungsChef.rpc(
        'rename_abteilung',
        params: {'ziel': abteilungA, 'neuer_name': 'A noch anders'},
      );
      final nachher = await asService(
        (s) async =>
            await s
                .from('abteilungen')
                .select('id, slug')
                .eq('id', abteilungA)
                .single(),
      );
      expect(nachher['id'], vorher['id']);
      expect(nachher['slug'], vorher['slug']);
    });

    test('aber NICHT die Nachbarabteilung', () async {
      // Die Grenze, um die es in #119 geht.
      final vorher = await nameDerAbteilung(abteilungB);
      await expectLater(
        abteilungsChef.rpc(
          'rename_abteilung',
          params: {'ziel': abteilungB, 'neuer_name': 'geklaut'},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('abteilung umbenennen'),
          ),
        ),
      );
      expect(await nameDerAbteilung(abteilungB), vorher);
    });

    test('der Feuerwehrkommandant darf jede Abteilung seiner Wehr', () async {
      await kommandant.rpc(
        'rename_abteilung',
        params: {'ziel': abteilungB, 'neuer_name': 'B vom Kommandanten'},
      );
      expect(await nameDerAbteilung(abteilungB), 'B vom Kommandanten');
    });

    test('der Gerätewart darf gar nicht', () async {
      final vorher = await nameDerAbteilung(abteilungA);
      await expectLater(
        wart.rpc(
          'rename_abteilung',
          params: {'ziel': abteilungA, 'neuer_name': 'vom Wart'},
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(await nameDerAbteilung(abteilungA), vorher);
    });

    test('ein leerer Name wird abgewiesen', () async {
      final vorher = await nameDerAbteilung(abteilungA);
      await expectLater(
        kommandant.rpc(
          'rename_abteilung',
          params: {'ziel': abteilungA, 'neuer_name': '   '},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('name required'),
          ),
        ),
      );
      expect(await nameDerAbteilung(abteilungA), vorher);
    });

    test('Leerraum am Rand wird abgeschnitten', () async {
      await kommandant.rpc(
        'rename_abteilung',
        params: {'ziel': abteilungA, 'neuer_name': '  A gestutzt  '},
      );
      expect(await nameDerAbteilung(abteilungA), 'A gestutzt');
    });

    test(
      'eine Abteilung, die es nicht gibt, ist eine Absage — keine Auskunft',
      () async {
        // Bewusst dieselbe Meldung wie bei fehlendem Recht: Sonst verrät die
        // Absage, welche Kennungen existieren.
        await expectLater(
          kommandant.rpc(
            'rename_abteilung',
            params: {
              'ziel': '00000000-0000-0000-0000-000000000000',
              'neuer_name': 'Phantom',
            },
          ),
          throwsA(
            isA<PostgrestException>().having(
              (e) => e.message,
              'message',
              contains('abteilung umbenennen'),
            ),
          ),
        );
      },
    );
  });

  group('rename_gesamtwehr', () {
    test('der Feuerwehrkommandant benennt seine Wehr um', () async {
      await kommandant.rpc(
        'rename_gesamtwehr',
        params: {'ziel': gesamtwehrId, 'neuer_name': 'GW frisch benannt'},
      );
      expect(await nameDerWehr(), 'GW frisch benannt');
    });

    test('der Abteilungskommandant darf das NICHT', () async {
      // Sonst ändert der Kommandant der kleinsten Abteilung den Auftritt der
      // ganzen Wehr — der Grund für zwei getrennte Funktionen.
      final vorher = await nameDerWehr();
      await expectLater(
        abteilungsChef.rpc(
          'rename_gesamtwehr',
          params: {'ziel': gesamtwehrId, 'neuer_name': 'meine Wehr jetzt'},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('gesamtwehr umbenennen'),
          ),
        ),
      );
      expect(await nameDerWehr(), vorher);
    });

    test('der Gerätewart erst recht nicht', () async {
      final vorher = await nameDerWehr();
      await expectLater(
        wart.rpc(
          'rename_gesamtwehr',
          params: {'ziel': gesamtwehrId, 'neuer_name': 'vom Wart'},
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(await nameDerWehr(), vorher);
    });

    test('ein leerer Name wird abgewiesen', () async {
      final vorher = await nameDerWehr();
      await expectLater(
        kommandant.rpc(
          'rename_gesamtwehr',
          params: {'ziel': gesamtwehrId, 'neuer_name': ''},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('name required'),
          ),
        ),
      );
      expect(await nameDerWehr(), vorher);
    });
  });
}
