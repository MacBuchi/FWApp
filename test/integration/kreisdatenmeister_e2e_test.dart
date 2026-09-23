/// kreisdatenmeister_e2e_test.dart – Der Betreiber der Installation und seine
/// Konsole (Nutzerkonzept Stufe ④, Issue #101) gegen den LOKALEN
/// Supabase-Stack. Überspringt sich selbst, wenn er nicht läuft.
///
/// **Warum am echten Stack.** Jede Zusicherung hier ist eine Rechtefrage,
/// und die beantwortet die Datenbank: `ist_betreiber()` in vier
/// SECURITY-DEFINER-Funktionen, derselbe Helfer in `darf_mitglieder_verwalten`
/// und `einladung_anlegen`, und `gesamtwehr_aktiv` in den Schreib-Helfern,
/// an denen die Policies von Bestand, Anhängen, Codes, Gerätetypen und
/// Wissensdatenbank hängen. Ein Fake bildete genau das nach, was hier
/// bewiesen werden soll.
///
/// Die wichtigste Zusicherung ist „stillgelegt sperrt SCHREIBEN, nicht
/// LESEN": Eine Wehr, die nichts mehr sieht, verlöre beim nächsten Zug ihre
/// Daten auf den Handys (`_applySnapshot` löscht, was der Server nicht
/// kennt).
///
/// Braucht die lokalen Testkonten aus tool/setup_local_supabase.sh:
///   admin@fw.local / geraetewart@fw.local / member@fw.local, pw test1234
library;

import 'dart:convert';
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

/// Präfix aller Wehren, die dieser Test anlegt — daran räumt er auf.
const _praefix = 'KDM-Test';

/// Adresse, an die nur dieser Test einlädt. Ohne Konto, damit die
/// Einladung nicht an „account already exists" scheitert.
const _neuerKommandant = 'kdm.test.kommandant@example.org';

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

Matcher _abgewiesen(String code) =>
    throwsA(isA<PostgrestException>().having((e) => e.code, 'code', code));

Future<void> main() async {
  if (!await _erreichbar('$_url/auth/v1/health')) {
    test(
      'kreisdatenmeister e2e',
      () {},
      skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).',
    );
    return;
  }

  late SupabaseClient kdm; // admin@fw.local — bekommt die Betreiber-Zeile
  late SupabaseClient wart; // geraetewart@fw.local
  late SupabaseClient mitglied; // member@fw.local — kein Betreiber

  Future<T> asService<T>(Future<T> Function(SupabaseClient) body) async {
    final service = SupabaseClient(_url, _serviceRoleKey);
    try {
      return await body(service);
    } finally {
      await service.dispose();
    }
  }

  /// Löscht über die Auth-Admin-API, was eine Einladung an [adresse] an
  /// unbestätigtem Konto hinterlassen hat.
  Future<void> kontoWeg(String adresse) => asService((s) async {
    final liste = await s.auth.admin.listUsers(perPage: 200);
    for (final u in liste) {
      if (u.email == adresse) await s.auth.admin.deleteUser(u.id);
    }
  });

  Future<void> aufraeumen() => asService((s) async {
    final wehren = await s
        .from('gesamtwehren')
        .select('id')
        .like('name', '$_praefix%');
    final ids = [for (final w in wehren) w['id'] as String];
    if (ids.isNotEmpty) {
      final abt = await s
          .from('abteilungen')
          .select('id')
          .inFilter('gesamtwehr_id', ids);
      final abtIds = [for (final a in abt) a['id'] as String];
      if (abtIds.isNotEmpty) {
        await s.from('einladungen').delete().inFilter('abteilung_id', abtIds);
        await s.from('memberships').delete().inFilter('abteilung_id', abtIds);
        await s.from('abteilungen').delete().inFilter('id', abtIds);
      }
      await s
          .from('gesamtwehr_kommandanten')
          .delete()
          .inFilter('gesamtwehr_id', ids);
      await s.from('gesamtwehren').delete().inFilter('id', ids);
    }
    await kontoWeg(_neuerKommandant);
    // ⚠️ Der Alt-Client-Spiegel in `profiles` (role, abteilung_id) wird bei
    // jeder Ernennung nachgeführt — beim Löschen der Kommandanten-Zeile oben
    // aber nicht. Ohne diese Zeilen stand `geraetewart@` nach diesem Test
    // mit Profilrolle „admin" da, und `sync_e2e_test` fand danach einen
    // Gerätewart, der eine Gesamtwehr gründen konnte. Die Konten teilen
    // sich alle E2E-Dateien; was hier verstellt wird, wird hier gerichtet.
    for (final wer in [kdm, wart, mitglied]) {
      final id = wer.auth.currentUser?.id;
      if (id != null) {
        await s.rpc('sync_profile_mirror', params: {'target': id});
      }
    }
  });

  setUpAll(() async {
    await stackSperreHolen();
    kdm = SupabaseClient(_url, _anonKey);
    wart = SupabaseClient(_url, _anonKey);
    mitglied = SupabaseClient(_url, _anonKey);
    await kdm.auth.signInWithPassword(
      email: 'admin@fw.local',
      password: 'test1234',
    );
    await wart.auth.signInWithPassword(
      email: 'geraetewart@fw.local',
      password: 'test1234',
    );
    await mitglied.auth.signInWithPassword(
      email: 'member@fw.local',
      password: 'test1234',
    );
    await aufraeumen();
    await asService(
      (s) => s.from('betreiber').upsert({
        'user_id': kdm.auth.currentUser!.id,
        'kontakt': 'Neue Wehr? Mail an kdm@example.org',
      }),
    );
  });

  tearDownAll(() async {
    await aufraeumen();
    await asService(
      (s) =>
          s.from('betreiber').delete().eq('user_id', kdm.auth.currentUser!.id),
    );
    await kdm.dispose();
    await wart.dispose();
    await mitglied.dispose();
    await stackSperreFreigeben();
  });

  setUp(aufraeumen);

  /// Legt über die Konsole eine Wehr an und gibt ihre IDs zurück.
  Future<({String wehr, String abteilung})> wehrAnlegen([
    String name = '$_praefix Musterstadt',
  ]) async {
    final roh =
        await kdm.rpc(
              'kdm_lege_gesamtwehr_an',
              params: {'p_name': name, 'p_abteilung': 'Abteilung Mitte'},
            )
            as List;
    final z = (roh.single as Map).cast<String, dynamic>();
    return (
      wehr: z['gesamtwehr_id'] as String,
      abteilung: z['abteilung_id'] as String,
    );
  }

  Future<Map<String, dynamic>> zeileInUebersicht(String wehr) async {
    final roh = await kdm.rpc('kdm_gesamtwehren') as List;
    return roh.cast<Map<String, dynamic>>().singleWhere((z) => z['id'] == wehr);
  }

  group('Wer KreisDatenMeister ist', () {
    test('ohne Betreiber-Zeile bleibt die Konsole zu', () async {
      final w = await wehrAnlegen();
      for (final (name, params) in [
        ('kdm_gesamtwehren', <String, dynamic>{}),
        ('kdm_lege_gesamtwehr_an', {'p_name': 'X', 'p_abteilung': 'Y'}),
        (
          'kdm_ernenne_kommandant',
          {'p_gesamtwehr': w.wehr, 'p_email': 'member@fw.local'},
        ),
        ('kdm_stilllegen', {'p_gesamtwehr': w.wehr, 'p_still': true}),
      ]) {
        await expectLater(
          mitglied.rpc(name, params: params),
          _abgewiesen('42501'),
          reason: name,
        );
      }
    });

    test(
      'jeder sieht nur die eigene Betreiber-Zeile, schreiben kann keiner',
      () async {
        expect(await kdm.from('betreiber').select('user_id'), hasLength(1));
        expect(await mitglied.from('betreiber').select('user_id'), isEmpty);

        await erwarteKeinenDurchgriff(
          () => mitglied.from('betreiber').insert({
            'user_id': mitglied.auth.currentUser!.id,
          }),
        );
        expect(await mitglied.rpc('ist_betreiber'), isFalse);
        expect(await kdm.rpc('ist_betreiber'), isTrue);
      },
    );

    test('die Kontaktzeile steht auch vor dem Anmelden bereit', () async {
      final anon = SupabaseClient(_url, _anonKey);
      addTearDown(anon.dispose);
      expect(
        await anon.rpc('installation_kontakt'),
        'Neue Wehr? Mail an kdm@example.org',
      );
      // Und nur sie: an die Konsole kommt anon nicht.
      await expectLater(
        anon.rpc('kdm_gesamtwehren'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('Anlegen und einladen', () {
    test('eine neue Wehr kommt mit aktiver Abteilung — der KDM wird nicht '
        'Mitglied', () async {
      final w = await wehrAnlegen();

      final abt = await asService(
        (s) =>
            s
                .from('abteilungen')
                .select('status, gesamtwehr_id')
                .eq('id', w.abteilung)
                .single(),
      );
      expect(abt['status'], 'active');
      expect(abt['gesamtwehr_id'], w.wehr);

      // Er richtet sie für andere ein — Kommando oder Mitgliedschaft wären
      // Rechte, die ihm niemand gegeben hat.
      expect(
        await asService(
          (s) => s
              .from('gesamtwehr_kommandanten')
              .select('user_id')
              .eq('gesamtwehr_id', w.wehr),
        ),
        isEmpty,
      );
      expect(
        await asService(
          (s) => s
              .from('memberships')
              .select('user_id')
              .eq('abteilung_id', w.abteilung),
        ),
        isEmpty,
      );

      final zeile = await zeileInUebersicht(w.wehr);
      expect(zeile['mitglieder'], 0);
      expect(zeile['kommandanten'], isEmpty);
      expect(zeile['stillgelegt_am'], isNull);
      expect((zeile['abteilungen'] as List).single['name'], 'Abteilung Mitte');
    });

    test('der KDM lädt den ersten Feuerwehrkommandanten ein — sonst niemand '
        'ohne Kommando', () async {
      final w = await wehrAnlegen();
      final params = {
        'adresse': _neuerKommandant,
        'name': 'Erika Muster',
        'abteilung': w.abteilung,
        'rolle': 'admin',
        'kommandant': true,
      };

      await expectLater(
        mitglied.rpc('einladung_anlegen', params: params),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('permission denied'),
          ),
        ),
      );

      final id = await kdm.rpc('einladung_anlegen', params: params);
      expect(id, isA<String>());
      expect((await zeileInUebersicht(w.wehr))['offene_einladungen'], 1);
    });

    test('der ganze Mailweg: die Edge Function lässt den KDM herein', () async {
      final w = await wehrAnlegen();

      final antwort = await kdm.functions.invoke(
        'admin-users',
        body: {
          'action': 'invite',
          'email': _neuerKommandant,
          'anzeigename': 'Erika Muster',
          'abteilung_id': w.abteilung,
          'role': 'admin',
          'als_kommandant': true,
        },
      );
      expect((antwort.data as Map)['ok'], isTrue);

      final einladung = await asService(
        (s) =>
            s
                .from('einladungen')
                .select('als_kommandant, auth_user_id')
                .eq('abteilung_id', w.abteilung)
                .single(),
      );
      expect(einladung['als_kommandant'], isTrue);
      // GoTrue hat das (noch unbestätigte) Konto angelegt — die Mail ist raus.
      expect(einladung['auth_user_id'], isNotNull);
    });
  });

  group('Notfall: Kommandant', () {
    test('ein vorhandenes Konto wird direkt Feuerwehrkommandant', () async {
      final w = await wehrAnlegen();

      final wer = await kdm.rpc(
        'kdm_ernenne_kommandant',
        params: {'p_gesamtwehr': w.wehr, 'p_email': 'GERAETEWART@fw.local '},
      );
      expect(wer, wart.auth.currentUser!.id);

      final zeile = await zeileInUebersicht(w.wehr);
      final kommandanten =
          (zeile['kommandanten'] as List).cast<Map<String, dynamic>>();
      expect(kommandanten.single['user_id'], wart.auth.currentUser!.id);
      expect(kommandanten.single['email'], 'geraetewart@fw.local');
    });

    test('ohne Konto verweist die Konsole auf die Einladung', () async {
      final w = await wehrAnlegen();
      await expectLater(
        kdm.rpc(
          'kdm_ernenne_kommandant',
          params: {'p_gesamtwehr': w.wehr, 'p_email': 'niemand@example.org'},
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('bitte einladen'),
          ),
        ),
      );
    });
  });

  group('Stilllegen', () {
    /// Veröffentlicht einen leeren Stand in [abteilung] — der echte
    /// Schreibweg, an dem alle Bestands-Policies hängen.
    Future<void> veroeffentliche(String abteilung) async {
      final version = await asService(
        (s) =>
            s
                .from('abteilungen')
                .select('version')
                .eq('id', abteilung)
                .single(),
      );
      await wart.rpc(
        'publish_snapshot',
        params: {
          'abteilung': abteilung,
          'expected_version': version['version'],
          'payload': jsonDecode('{}'),
          'client_version': '99.0.0',
        },
      );
    }

    test(
      'sperrt Veröffentlichen, Gerätetypen und Einladen — Lesen bleibt',
      () async {
        final w = await wehrAnlegen();
        await asService(
          (s) => s.from('memberships').upsert({
            'user_id': wart.auth.currentUser!.id,
            'abteilung_id': w.abteilung,
            'role': 'geraetewart',
          }),
        );

        // Vorher: Der Gerätewart darf.
        await veroeffentliche(w.abteilung);
        expect(
          await wart.rpc(
            'can_write_gesamtwehr_types',
            params: {'ziel': w.wehr},
          ),
          isTrue,
        );

        await kdm.rpc(
          'kdm_stilllegen',
          params: {'p_gesamtwehr': w.wehr, 'p_still': true},
        );
        expect((await zeileInUebersicht(w.wehr))['stillgelegt_am'], isNotNull);

        await expectLater(
          veroeffentliche(w.abteilung),
          throwsA(isA<PostgrestException>()),
        );
        expect(
          await wart.rpc(
            'can_write_gesamtwehr_types',
            params: {'ziel': w.wehr},
          ),
          isFalse,
        );
        // Auch der KDM lädt in eine stillgelegte Wehr nicht mehr ein: erst
        // reaktivieren, dann handeln.
        await expectLater(
          kdm.rpc(
            'einladung_anlegen',
            params: {
              'adresse': _neuerKommandant,
              'name': null,
              'abteilung': w.abteilung,
              'rolle': 'admin',
              'kommandant': true,
            },
          ),
          throwsA(isA<PostgrestException>()),
        );

        // ⚠️ Lesen bleibt — sonst hielte der nächste Zug alles für gelöscht.
        expect(
          await wart.from('abteilungen').select('id').eq('id', w.abteilung),
          hasLength(1),
        );
        expect(
          await wart.from('gesamtwehren').select('id').eq('id', w.wehr),
          hasLength(1),
        );

        // Und rückgängig machen gibt alles zurück.
        await kdm.rpc(
          'kdm_stilllegen',
          params: {'p_gesamtwehr': w.wehr, 'p_still': false},
        );
        await veroeffentliche(w.abteilung);
      },
    );

    test('eine andere Wehr bleibt davon unberührt', () async {
      final eins = await wehrAnlegen('$_praefix Eins');
      final zwei = await wehrAnlegen('$_praefix Zwei');
      await asService(
        (s) => s.from('memberships').upsert({
          'user_id': wart.auth.currentUser!.id,
          'abteilung_id': zwei.abteilung,
          'role': 'geraetewart',
        }),
      );

      await kdm.rpc(
        'kdm_stilllegen',
        params: {'p_gesamtwehr': eins.wehr, 'p_still': true},
      );
      await veroeffentliche(zwei.abteilung);
    });
  });
}
