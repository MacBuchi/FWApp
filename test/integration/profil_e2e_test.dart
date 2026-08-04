/// profil_e2e_test.dart – Anzeigename und Avatar selbst setzen (Nutzerkonzept
/// Stufe ③, Issue #100) gegen den LOKALEN Supabase-Stack (`supabase start`).
/// Überspringt sich selbst, wenn er nicht läuft.
///
/// Warum das kein Unit-Test sein kann: Die Aussage, um die es geht, ist
/// **„jeder setzt nur sich selbst"** — und die entsteht nicht im Client,
/// sondern daraus, dass `mein_profil_setzen` überhaupt kein Ziel-Konto
/// entgegennimmt und auf `auth.uid()` schreibt. Ein Fake würde genau das
/// nachbauen, was zu prüfen ist.
///
/// Die zweite Hälfte sind die Grenzen: Länge und Zeichenvorrat. Sie stehen in
/// SQL, die Erzeugung steht in Dart — dass beide zusammenpassen, prüft
/// zusätzlich avatar_konfiguration_test.dart.
///
/// Braucht die lokalen Testkonten aus tool/setup_local_supabase.sh:
///   admin@fw.local / geraetewart@fw.local / member@fw.local, pw test1234
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
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

Future<void> main() async {
  if (!await _erreichbar('$_url/auth/v1/health')) {
    test(
      'profil e2e',
      () {},
      skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).',
    );
    return;
  }

  late SupabaseClient wart; // geraetewart@fw.local
  late SupabaseClient truppfuehrer; // member@fw.local
  late String wartId;
  late String truppfuehrerId;

  Future<T> asService<T>(Future<T> Function(SupabaseClient) body) async {
    final service = SupabaseClient(_url, _serviceRoleKey);
    try {
      return await body(service);
    } finally {
      await service.dispose();
    }
  }

  Future<Map<String, dynamic>> profilVon(String id) => asService(
        (s) async => await s
            .from('profiles')
            .select('username, anzeigename, avatar')
            .eq('id', id)
            .single(),
      );

  setUpAll(() async {
    await stackSperreHolen();
    wart = SupabaseClient(_url, _anonKey);
    truppfuehrer = SupabaseClient(_url, _anonKey);
    final a = await wart.auth.signInWithPassword(
      email: 'geraetewart@fw.local',
      password: 'test1234',
    );
    wartId = a.user!.id;
    final b = await truppfuehrer.auth.signInWithPassword(
      email: 'member@fw.local',
      password: 'test1234',
    );
    truppfuehrerId = b.user!.id;
  });

  tearDownAll(() async {
    await asService((s) async {
      await s
          .from('profiles')
          .update({'anzeigename': null, 'avatar': null})
          .inFilter('id', [wartId, truppfuehrerId]);
    });
    await wart.dispose();
    await truppfuehrer.dispose();
    stackSperreFreigeben();
  });

  setUp(() => asService((s) async {
        await s
            .from('profiles')
            .update({'anzeigename': null, 'avatar': null})
            .inFilter('id', [wartId, truppfuehrerId]);
      }));

  group('setzen', () {
    test('ein Truppführer setzt seinen eigenen Namen und Kopf', () async {
      const kopf = AvatarKonfiguration(gear: 'scba', eyes: 'shades');
      await truppfuehrer.rpc('mein_profil_setzen', params: {
        'neuer_anzeigename': 'Marcus B.',
        'neuer_avatar': kopf.kodiert,
      });

      final zeile = await profilVon(truppfuehrerId);
      expect(zeile['anzeigename'], 'Marcus B.');
      expect(AvatarKonfiguration.dekodiert(zeile['avatar'] as String?), kopf);
    });

    test('der Nutzername bleibt unangetastet — er ist die Anmeldung',
        () async {
      final vorher = (await profilVon(truppfuehrerId))['username'];
      await truppfuehrer.rpc('mein_profil_setzen', params: {
        'neuer_anzeigename': 'Ganz jemand anderes',
        'neuer_avatar': const AvatarKonfiguration().kodiert,
      });
      expect((await profilVon(truppfuehrerId))['username'], vorher);
    });

    test('leer setzen löscht beides wieder', () async {
      await truppfuehrer.rpc('mein_profil_setzen', params: {
        'neuer_anzeigename': 'Marcus B.',
        'neuer_avatar': const AvatarKonfiguration(gear: 'cap').kodiert,
      });
      await truppfuehrer.rpc('mein_profil_setzen', params: {
        'neuer_anzeigename': '',
        'neuer_avatar': '',
      });

      final zeile = await profilVon(truppfuehrerId);
      expect(zeile['anzeigename'], isNull);
      expect(zeile['avatar'], isNull);
    });

    test('Leerzeichen ringsum zählen nicht als Name', () async {
      await truppfuehrer.rpc('mein_profil_setzen', params: {
        'neuer_anzeigename': '   ',
        'neuer_avatar': '  ${const AvatarKonfiguration().kodiert}  ',
      });
      final zeile = await profilVon(truppfuehrerId);
      expect(zeile['anzeigename'], isNull);
      expect(zeile['avatar'], const AvatarKonfiguration().kodiert);
    });
  });

  group('jeder setzt nur sich selbst', () {
    test('das Setzen des einen lässt den anderen unberührt', () async {
      // Die RPC KANN kein fremdes Konto ansprechen — es gibt keinen
      // Parameter dafür. Das ist die eigentliche Absicherung; dieser Test
      // hält fest, dass sie auch wirkt.
      await wart.rpc('mein_profil_setzen', params: {
        'neuer_anzeigename': 'Der Wart',
        'neuer_avatar': const AvatarKonfiguration(gear: 'cap').kodiert,
      });

      expect((await profilVon(wartId))['anzeigename'], 'Der Wart');
      expect((await profilVon(truppfuehrerId))['anzeigename'], isNull);
    });

    test('ein fremdes Profil lässt sich auch nicht direkt beschreiben',
        () async {
      // profiles hat keine Update-Policy — geschrieben wird nur über RPCs.
      // Ohne diese Zeile wäre der Rest hier Theater.
      await expectLater(
        truppfuehrer
            .from('profiles')
            .update({'anzeigename': 'Übernommen'}).eq('id', wartId),
        throwsA(anything),
      );
      expect((await profilVon(wartId))['anzeigename'], isNot('Übernommen'));
    });

    test('das eigene Profil liest man, ein fremdes nicht', () async {
      await wart.rpc('mein_profil_setzen', params: {
        'neuer_anzeigename': 'Der Wart',
        'neuer_avatar': const AvatarKonfiguration().kodiert,
      });

      final eigenes = await truppfuehrer
          .from('profiles')
          .select('id, anzeigename')
          .eq('id', truppfuehrerId)
          .maybeSingle();
      expect(eigenes, isNotNull);

      final fremdes = await truppfuehrer
          .from('profiles')
          .select('id, anzeigename')
          .eq('id', wartId)
          .maybeSingle();
      expect(fremdes, isNull, reason: 'RLS: nur das eigene Profil');
    });
  });

  group('die Grenzen', () {
    test('ein zu langer Name wird abgewiesen', () async {
      await expectLater(
        truppfuehrer.rpc('mein_profil_setzen', params: {
          'neuer_anzeigename': 'M' * 41,
          'neuer_avatar': '',
        }),
        throwsA(predicate((e) => e.toString().contains('name too long'))),
      );
      expect((await profilVon(truppfuehrerId))['anzeigename'], isNull);
    });

    test('genau 40 Zeichen gehen noch', () async {
      await truppfuehrer.rpc('mein_profil_setzen', params: {
        'neuer_anzeigename': 'M' * 40,
        'neuer_avatar': '',
      });
      expect((await profilVon(truppfuehrerId))['anzeigename'], 'M' * 40);
    });

    test('ein Zeilenumbruch im Namen wird abgewiesen', () async {
      await expectLater(
        truppfuehrer.rpc('mein_profil_setzen', params: {
          'neuer_anzeigename': 'Marcus\nB.',
          'neuer_avatar': '',
        }),
        throwsA(predicate(
            (e) => e.toString().contains('name has control characters'))),
      );
    });

    test('ein zu langer Avatar wird abgewiesen', () async {
      await expectLater(
        truppfuehrer.rpc('mein_profil_setzen', params: {
          'neuer_anzeigename': '',
          'neuer_avatar': 'a' * 201,
        }),
        throwsA(predicate((e) => e.toString().contains('avatar too long'))),
      );
    });

    test('fremde Zeichen im Avatar werden abgewiesen', () async {
      await expectLater(
        truppfuehrer.rpc('mein_profil_setzen', params: {
          'neuer_anzeigename': '',
          'neuer_avatar': '{"gear":"scba"}',
        }),
        throwsA(predicate(
            (e) => e.toString().contains('avatar has invalid characters'))),
      );
    });

    test('jede Vorlage der App kommt beim Server durch', () async {
      // Der Abgleich, der beide Seiten zusammenhält: Was der Baukasten
      // erzeugen kann, muss die RPC annehmen. Sonst steht jemand vor einem
      // Kopf, den er nicht speichern kann.
      for (final v in kAvatarVorlagen) {
        await truppfuehrer.rpc('mein_profil_setzen', params: {
          'neuer_anzeigename': v.rolle,
          'neuer_avatar': v.kopf.kodiert,
        });
      }
      final zeile = await profilVon(truppfuehrerId);
      expect(
        AvatarKonfiguration.dekodiert(zeile['avatar'] as String?),
        kAvatarVorlagen.last.kopf,
      );
    });
  });
}
