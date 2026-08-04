/// einladungen_e2e_test.dart – Mail-Einladungen (Nutzerkonzept Stufe 3,
/// Issue #100) gegen den LOKALEN Supabase-Stack (`supabase start`).
/// Überspringt sich selbst, wenn er nicht läuft.
///
/// Warum das kein Widget-Test sein kann: Der ganze Wert des Ablaufs hängt an
/// einer Aussage, die erst aus dem Zusammenspiel von RPC, Trigger, GoTrue und
/// Mailvorlage entsteht — **eine offene Einladung verschafft KEIN Recht, erst
/// die bestätigte Adresse tut das**. Ein Fake würde genau die Stelle nachbauen,
/// die zu prüfen ist. Stimmt sie nicht, hat jeder Eingeladene Zugriff auf den
/// Bestand, sobald ihn jemand einlädt — auch wenn die Mail nie ankommt.
///
/// Zweite Aussage derselben Art: Die Mail zeigt einen Code und KEINEN Link.
/// Ein Einladungslink ist ein GET, das den Token verbraucht — Mail-Scanner
/// und Link-Vorschauen lösen ihn ein, bevor ein Mensch die Mail öffnet.
///
/// Braucht die lokalen Testkonten aus tool/setup_local_supabase.sh:
///   admin@fw.local / geraetewart@fw.local / member@fw.local, pw test1234
library;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'stack_sperre.dart';

const _url = 'http://127.0.0.1:54321';
const _mailpit = 'http://127.0.0.1:54324';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

/// Derselbe öffentlich dokumentierte Demo-Key wie in den übrigen E2E-Tests —
/// in jedem lokalen Stack identisch, kein Geheimnis.
final _serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

/// Adressen, die es nur in diesem Test gibt.
const _mailWart = 'einladung.wart@example.org';
const _mailZweiter = 'einladung.zweiter@example.org';

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

typedef HttpResult = ({int status, String text});

Future<HttpResult> _json(String method, String url,
    {Map<String, dynamic>? body}) async {
  final client = HttpClient();
  final request = await client.openUrl(method, Uri.parse(url));
  request.headers.set('apikey', _serviceRoleKey);
  request.headers.set('Authorization', 'Bearer $_serviceRoleKey');
  request.headers.contentType = ContentType.json;
  if (body != null) request.write(jsonEncode(body));
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  client.close();
  return (status: response.statusCode, text: text);
}

/// Speicher für die PKCE-Prüfsumme — ein nackter SupabaseClient hat keinen
/// und bricht sonst mit einer Zusicherung ab (siehe passwort_reset_e2e_test).
class _SpeicherImArbeitsspeicher implements GotrueAsyncStorage {
  final _werte = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _werte[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _werte[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _werte.remove(key);
}

Future<void> main() async {
  if (!await _erreichbar('$_url/auth/v1/health') ||
      !await _erreichbar(_mailpit)) {
    test('einladungen e2e', () {},
        skip: 'Lokaler Supabase-Stack oder Mailpit läuft nicht '
            '(supabase start).');
    return;
  }

  late SupabaseClient kommandant; // admin@fw.local, Feuerwehrkommandant
  late SupabaseClient abteilungsChef; // member@fw.local, Abteilungskommandant
  late SupabaseClient wart; // geraetewart@fw.local, darf gar nicht einladen

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

  /// Konten, die dieser Test selbst erzeugt hat — kommen am Ende weg.
  final erzeugteKonten = <String>[];

  setUpAll(() async {
    await stackSperreHolen();
    kommandant = SupabaseClient(_url, _anonKey);
    abteilungsChef = SupabaseClient(_url, _anonKey);
    wart = SupabaseClient(_url, _anonKey);
    await kommandant.auth
        .signInWithPassword(email: 'admin@fw.local', password: 'test1234');
    await abteilungsChef.auth
        .signInWithPassword(email: 'member@fw.local', password: 'test1234');
    await wart.auth.signInWithPassword(
        email: 'geraetewart@fw.local', password: 'test1234');

    await asService((s) async {
      final gw = await s
          .from('gesamtwehren')
          .insert({'name': 'GW Einladung', 'slug': 'gw-einladung'})
          .select('id')
          .single();
      gesamtwehrId = gw['id'] as String;

      // ⚠️ Bewusst eigene Abteilungen statt der Spiegel-Abteilung:
      // `flutter test` lässt Dateien nebenläufig laufen, und sync_e2e_test
      // hängt die Spiegel-Abteilung an seine eigene Gesamtwehr um.
      for (final name in ['Einladung A', 'Einladung B']) {
        final abt = await s
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
        // member@fw.local ist hier Abteilungskommandant von A — die Rolle,
        // an der sich zeigt, dass er NICHT alles darf.
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
    await _json('DELETE', '$_mailpit/api/v1/messages');
  });

  tearDownAll(() async {
    for (final id in erzeugteKonten) {
      await _json('DELETE', '$_url/auth/v1/admin/users/$id');
    }
    await asService((s) async {
      await s
          .from('einladungen')
          .delete()
          .inFilter('abteilung_id', [abteilungA, abteilungB]);
      await s
          .from('memberships')
          .delete()
          .inFilter('abteilung_id', [abteilungA, abteilungB]);
      await s.from('gesamtwehr_kommandanten').delete().eq(
          'gesamtwehr_id', gesamtwehrId);
      await s
          .from('abteilungen')
          .delete()
          .inFilter('id', [abteilungA, abteilungB]);
      await s.from('gesamtwehren').delete().eq('id', gesamtwehrId);
    });
    await _json('DELETE', '$_mailpit/api/v1/messages');
    await kommandant.dispose();
    await abteilungsChef.dispose();
    await wart.dispose();
    await stackSperreFreigeben();
  });

  /// Die zuletzt an [adresse] zugestellte Mail (Betreff + Rumpf).
  Future<({String betreff, String rumpf})> letzteMailAn(String adresse) async {
    final liste = await _json('GET', '$_mailpit/api/v1/messages?limit=20');
    final nachrichten =
        (jsonDecode(liste.text) as Map)['messages'] as List<dynamic>;
    final treffer = nachrichten.cast<Map<String, dynamic>>().where((m) =>
        ((m['To'] as List).first as Map)['Address'] == adresse);
    expect(treffer, isNotEmpty, reason: 'keine Mail an $adresse in Mailpit');
    final einzeln =
        await _json('GET', '$_mailpit/api/v1/message/${treffer.first['ID']}');
    final m = jsonDecode(einzeln.text) as Map;
    return (
      betreff: treffer.first['Subject'] as String,
      rumpf: '${m['Text'] ?? ''}\n${m['HTML'] ?? ''}',
    );
  }

  group('wer einladen darf', () {
    test('der Feuerwehrkommandant lädt in jede Abteilung seiner Wehr ein',
        () async {
      final id = await kommandant.rpc('einladung_anlegen', params: {
        'adresse': 'probe.a@example.org',
        'name': 'Probe A',
        'abteilung': abteilungB,
        'rolle': 'geraetewart',
      });
      expect(id, isA<String>());
      await asService((s) => s.from('einladungen').delete().eq('id', id));
    });

    test('der Abteilungskommandant lädt in SEINE Abteilung ein', () async {
      final id = await abteilungsChef.rpc('einladung_anlegen', params: {
        'adresse': 'probe.b@example.org',
        'name': 'Probe B',
        'abteilung': abteilungA,
        'rolle': 'geraetewart',
      });
      expect(id, isA<String>());
      await asService((s) => s.from('einladungen').delete().eq('id', id));
    });

    test('der Abteilungskommandant vergibt KEIN admin — das bleibt dem '
        'Feuerwehrkommandanten', () async {
      await expectLater(
        abteilungsChef.rpc('einladung_anlegen', params: {
          'adresse': 'probe.c@example.org',
          'name': 'Probe C',
          'abteilung': abteilungA,
          'rolle': 'admin',
        }),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('permission denied'))),
      );
    });

    test('der Abteilungskommandant lädt NICHT in die Schwester-Abteilung ein',
        () async {
      await expectLater(
        abteilungsChef.rpc('einladung_anlegen', params: {
          'adresse': 'probe.d@example.org',
          'name': 'Probe D',
          'abteilung': abteilungB,
          'rolle': 'member',
        }),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('permission denied'))),
      );
    });

    test('der Gerätewart lädt gar niemanden ein', () async {
      await expectLater(
        wart.rpc('einladung_anlegen', params: {
          'adresse': 'probe.e@example.org',
          'name': 'Probe E',
          'abteilung': abteilungA,
          'rolle': 'member',
        }),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('permission denied'))),
      );
    });

    test('einen Feuerwehrkommandanten ernennt nur ein Feuerwehrkommandant',
        () async {
      await expectLater(
        abteilungsChef.rpc('einladung_anlegen', params: {
          'adresse': 'probe.f@example.org',
          'name': 'Probe F',
          'abteilung': abteilungA,
          'rolle': 'geraetewart',
          'kommandant': true,
        }),
        throwsA(isA<PostgrestException>().having((e) => e.message, 'message',
            contains('feuerwehrkommandant required'))),
      );
    });

    test('an @fw.local wird nicht eingeladen — dorthin kommt keine Post an',
        () async {
      await expectLater(
        kommandant.rpc('einladung_anlegen', params: {
          'adresse': 'zettel.konto@fw.local',
          'name': 'Zettel',
          'abteilung': abteilungA,
          'rolle': 'member',
        }),
        throwsA(isA<PostgrestException>()
            .having((e) => e.message, 'message', contains('fw.local'))),
      );
    });

    test('zwei offene Einladungen an dieselbe Adresse gehen nicht', () async {
      final id = await kommandant.rpc('einladung_anlegen', params: {
        'adresse': 'probe.g@example.org',
        'name': 'Probe G',
        'abteilung': abteilungA,
        'rolle': 'member',
      });
      await expectLater(
        kommandant.rpc('einladung_anlegen', params: {
          'adresse': 'probe.g@example.org',
          'name': 'Probe G',
          'abteilung': abteilungB,
          'rolle': 'admin',
        }),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('invitation already open'))),
      );
      await asService((s) => s.from('einladungen').delete().eq('id', id));
    });

    test('wer nicht verwalten darf, SIEHT die Einladungen auch nicht',
        () async {
      final id = await kommandant.rpc('einladung_anlegen', params: {
        'adresse': 'probe.h@example.org',
        'name': 'Probe H',
        'abteilung': abteilungA,
        'rolle': 'member',
      });
      // Der Gerätewart sitzt in DERSELBEN Abteilung — die Policy trennt also
      // nach Recht, nicht nach Mandant.
      final beimWart =
          await wart.from('einladungen').select('id').eq('id', id);
      expect(beimWart, isEmpty);
      final beimChef =
          await abteilungsChef.from('einladungen').select('id').eq('id', id);
      expect(beimChef, hasLength(1));
      await asService((s) => s.from('einladungen').delete().eq('id', id));
    });
  });

  group('der ganze Weg: einladen, Mail, annehmen', () {
    late String einladungId;

    test('einladen verschickt eine Mail mit Code und OHNE Link', () async {
      final antwort = await kommandant.functions.invoke('admin-users', body: {
        'action': 'invite',
        'email': _mailWart,
        'anzeigename': 'Max Muster',
        'abteilung_id': abteilungA,
        'role': 'geraetewart',
      });
      final daten = (antwort.data as Map).cast<String, dynamic>();
      expect(daten['ok'], isTrue);
      einladungId = daten['id'] as String;

      final mail = await letzteMailAn(_mailWart);
      expect(mail.betreff, contains('Einladung'),
          reason: 'die englische Standardvorlage würde „You\'ve been invited" '
              'schicken — dann hat GoTrue unsere Vorlage nicht geparst');
      // Der Wehrname im Betreff und als Überschrift: Eine Einladung, die mit
      // dem Namen der eigenen Wehr ankommt, sieht im Postfach nach Feuerwehr
      // aus und nicht nach Werbung. Der Betreff ist dabei SELBST eine
      // Go-Vorlage — steht so in keiner Dokumentation, ist am lokalen Stack
      // gemessen und hängt hier als Zusicherung.
      expect(mail.betreff, contains('GW Einladung'),
          reason: 'Betreff ohne Wehrname — wird GOTRUE_MAILER_SUBJECTS_INVITE '
              'nicht als Vorlage ausgewertet?');
      expect(mail.rumpf, contains('GW Einladung'),
          reason: 'Überschrift ohne Wehrname');
      // Und der alte Grammatikfehler ist damit weg: Ohne Gesamtwehr stand da
      // früher „Du wurdest für deiner Feuerwehr eingeladen". Die Fußzeile
      // („die Lern-App deiner Feuerwehr") ist richtig und bleibt — deshalb
      // prüft das hier auf den Satzanfang und nicht auf die Wortgruppe.
      expect(mail.rumpf, isNot(contains('für deiner Feuerwehr')));
      expect(mail.rumpf, isNot(contains('Willkommen bei der FWApp')));
      expect(RegExp(r'>\s*\d{6}\s*<').hasMatch(mail.rumpf), isTrue,
          reason: 'kein sechsstelliger Code in der Mail');
      expect(mail.rumpf, isNot(contains('auth/v1/verify')),
          reason: 'ein Einladungslink wird vom ersten Mail-Scanner eingelöst');
      // Aus den Metadaten: So weiß der Eingeladene, wofür er eingeladen wurde.
      expect(mail.rumpf, contains('Gerätewart'));
      expect(mail.rumpf, contains('Einladung A'));
    });

    test('die offene Einladung verschafft NOCH KEIN Recht', () async {
      final konto = await asService((s) => s
          .from('einladungen')
          .select('auth_user_id')
          .eq('id', einladungId)
          .single());
      final userId = konto['auth_user_id'] as String;
      erzeugteKonten.add(userId);

      // Das Konto existiert schon (GoTrue legt es beim Einladen an) …
      final profil = await asService((s) => s
          .from('profiles')
          .select('username, abteilung_id')
          .eq('id', userId)
          .single());
      expect(profil['username'], 'Max Muster');
      // … aber ohne Abteilung und ohne jede Mitgliedschaft.
      expect(profil['abteilung_id'], isNull);
      final mitgliedschaften = await asService(
          (s) => s.from('memberships').select('role').eq('user_id', userId));
      expect(mitgliedschaften, isEmpty,
          reason: 'eine unbestätigte Einladung darf kein Recht verschaffen');
    });

    test('das Einlösen des Codes setzt Rolle, Abteilung und Anzeigename',
        () async {
      final mail = await letzteMailAn(_mailWart);
      final code = RegExp(r'>\s*(\d{6})\s*<').firstMatch(mail.rumpf)!.group(1)!;

      final neuer = SupabaseClient(_url, _anonKey,
          authOptions: AuthClientOptions(
            autoRefreshToken: false,
            pkceAsyncStorage: _SpeicherImArbeitsspeicher(),
          ));
      try {
        final sitzung = await neuer.auth.verifyOTP(
          email: _mailWart,
          token: code,
          type: OtpType.invite,
        );
        expect(sitzung.session, isNotNull);
        await neuer.auth
            .updateUser(UserAttributes(password: 'einladung-1234'));

        final userId = neuer.auth.currentUser!.id;
        final mitgliedschaft = await asService((s) => s
            .from('memberships')
            .select('abteilung_id, role')
            .eq('user_id', userId)
            .single());
        expect(mitgliedschaft['abteilung_id'], abteilungA);
        expect(mitgliedschaft['role'], 'geraetewart');

        final profil = await asService((s) => s
            .from('profiles')
            .select('username, role, abteilung_id')
            .eq('id', userId)
            .single());
        expect(profil['username'], 'Max Muster');
        // Der Alt-Client-Spiegel muss mitgezogen haben.
        expect(profil['role'], 'geraetewart');
        expect(profil['abteilung_id'], abteilungA);

        final zeile = await asService((s) => s
            .from('einladungen')
            .select('angenommen_am')
            .eq('id', einladungId)
            .single());
        expect(zeile['angenommen_am'], isNotNull);
      } finally {
        await neuer.dispose();
      }
    });

    test('eine angenommene Einladung lässt sich nicht zurückziehen', () async {
      await expectLater(
        kommandant.rpc('einladung_zurueckziehen', params: {
          'ziel': einladungId,
        }),
        throwsA(isA<PostgrestException>().having(
            (e) => e.message, 'message', contains('already accepted'))),
      );
    });
  });

  group('zurückziehen', () {
    test('räumt das unbestätigte Konto weg und gibt die Adresse frei',
        () async {
      final erste = await kommandant.functions.invoke('admin-users', body: {
        'action': 'invite',
        'email': _mailZweiter,
        'anzeigename': 'Zweiter',
        'abteilung_id': abteilungA,
        'role': 'member',
      });
      final ersteId = ((erste.data as Map)['id']) as String;

      final vorher = await asService((s) => s
          .from('einladungen')
          .select('auth_user_id')
          .eq('id', ersteId)
          .single());
      final erstesKonto = vorher['auth_user_id'] as String;

      await kommandant.functions.invoke('admin-users',
          body: {'action': 'invite_revoke', 'einladung_id': ersteId});

      // Das Konto ist weg — sonst liefe die nächste Einladung an dieselbe
      // Adresse in „User already registered".
      final uebrig = await asService(
          (s) => s.from('profiles').select('id').eq('id', erstesKonto));
      expect(uebrig, isEmpty);

      // Und dieselbe Adresse lässt sich neu einladen.
      final zweite = await kommandant.functions.invoke('admin-users', body: {
        'action': 'invite',
        'email': _mailZweiter,
        'anzeigename': 'Zweiter, zweiter Versuch',
        'abteilung_id': abteilungA,
        'role': 'member',
      });
      expect(((zweite.data as Map)['ok']), isTrue);
      final zweiteId = ((zweite.data as Map)['id']) as String;
      final konto = await asService((s) => s
          .from('einladungen')
          .select('auth_user_id')
          .eq('id', zweiteId)
          .single());
      erzeugteKonten.add(konto['auth_user_id'] as String);
    });
  });

  /// Zustellung (Issue #121). Brevo gibt es hier nicht — geprüft wird
  /// deshalb genau das, was ohne Brevo überhaupt zu prüfen ist: dass die
  /// Aktion trägt, dass sie ehrlich „weiß ich nicht" sagt statt zu
  /// beruhigen, und woher sie ihre Adressen nimmt.
  group('Zustellung abfragen', () {
    test('ohne Mail-Brücke meldet der Server „nicht prüfbar"', () async {
      // Der Zustand jedes Servers, auf dem die Brücke (noch) nicht
      // eingetragen ist — und der des lokalen Stacks für immer. Er darf die
      // Nutzerverwaltung nicht scheitern lassen.
      final antwort = await kommandant.functions
          .invoke('admin-users', body: {'action': 'invite_status'});
      final daten = (antwort.data as Map).cast<String, dynamic>();
      expect(daten['verfuegbar'], isFalse);
      expect(daten['grund'], contains('BREVO_EVENTS_URL'));
      expect(daten['zustellungen'], isEmpty);
      expect(daten['gekuerzt'], 0);
    });

    test('ein Gerätewart darf gar nicht erst fragen', () async {
      // Zustellereignisse sagen etwas über Menschen aus. Das Tor ist
      // dasselbe wie für die ganze Nutzerverwaltung.
      await expectLater(
        wart.functions.invoke('admin-users', body: {'action': 'invite_status'}),
        throwsA(isA<FunctionException>()),
      );
    });

    test('die Adressen kommen aus der Tabelle, nicht aus dem Aufruf',
        () async {
      // Der eigentliche Schutz: Die Aktion nimmt KEINE Adressliste
      // entgegen. Nähme sie eine, könnte jeder Verwalter Brevo nach
      // beliebigen fremden Adressen fragen. Sie liest stattdessen genau
      // diese Abfrage mit dem JWT des Aufrufers — hier wortgleich zu
      // `offeneEinladungen()` in der Edge Function.
      final id = await kommandant.rpc('einladung_anlegen', params: {
        'adresse': 'zustell.quelle@example.org',
        'name': 'Zustell Quelle',
        'abteilung': abteilungA,
        'rolle': 'member',
      });
      Future<List<dynamic>> abfrage(SupabaseClient s) => s
          .from('einladungen')
          .select('id, email, created_at')
          .isFilter('angenommen_am', null)
          .isFilter('zurueckgezogen_am', null)
          .order('created_at');

      expect(
        (await abfrage(abteilungsChef)).map((r) => r['id']),
        contains(id),
      );
      // Derselbe Aufruf, dieselbe Abteilung, anderes Recht: nichts.
      expect((await abfrage(wart)).map((r) => r['id']), isNot(contains(id)));
      await asService((s) => s.from('einladungen').delete().eq('id', id));
    });
  });
}
