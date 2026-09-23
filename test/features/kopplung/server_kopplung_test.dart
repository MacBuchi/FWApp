/// server_kopplung_test.dart – Einrichtungs-Code und `.well-known`-Datei
/// lesen, holen, prüfen, speichern (Issue #238), ohne Netz: Der HTTP-Client
/// ist ein MockClient.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/kopplung/data/kopplung_quelle.dart';
import 'package:fwapp/features/kopplung/domain/server_kopplung.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _json =
    '{"fwapp":1,"name":"Feuerwehr Musterstadt",'
    '"url":"https://api.musterstadt.de/","anon_key":"eyJ.test"}';

void main() {
  group('Code lesen', () {
    test('liest die Datei und macht die Adresse sauber', () {
      final k = ServerKopplung.ausJson(_json);
      expect(k.name, 'Feuerwehr Musterstadt');
      expect(k.url, 'https://api.musterstadt.de');
      expect(k.anonKey, 'eyJ.test');
      expect(k.anzeige, 'Feuerwehr Musterstadt');
    });

    test('hin und zurück bleibt dasselbe', () {
      final k = ServerKopplung.ausJson(_json);
      final wieder = ServerKopplung.ausJson(k.alsJson());
      expect(wieder.url, k.url);
      expect(wieder.anonKey, k.anonKey);
      expect(wieder.name, k.name);
    });

    test('ohne Namen zeigt die App den Host', () {
      final k = ServerKopplung.ausJson(
        '{"fwapp":1,"url":"https://api.x.de","anon_key":"k"}',
      );
      expect(k.anzeige, 'api.x.de');
      expect(k.alsJson(), isNot(contains('name')));
    });

    test('fremde Codes werden mit einem Satz abgelehnt', () {
      for (final (text, erwartet) in [
        ('https://irgendwo.de', 'kein Einrichtungs-Code'),
        ('{"hallo":1}', 'kein Einrichtungs-Code'),
        ('A1B2C3', 'kein Einrichtungs-Code'),
        (
          '{"fwapp":2,"url":"https://a.de","anon_key":"k"}',
          'neuer als die App',
        ),
        ('{"fwapp":1,"url":"ftp://a.de","anon_key":"k"}', 'Server-Adresse'),
        ('{"fwapp":1,"url":"https://a.de","anon_key":" "}', 'Schlüssel'),
      ]) {
        expect(
          () => ServerKopplung.ausJson(text),
          throwsA(
            isA<KopplungFehler>().having(
              (e) => e.text,
              'text',
              contains(erwartet),
            ),
          ),
          reason: text,
        );
      }
    });
  });

  group('Adressen', () {
    test('was Menschen tippen, wird eine Server-Adresse', () {
      expect(normalisiereServerUrl('musterstadt.de'), 'https://musterstadt.de');
      expect(normalisiereServerUrl(' https://a.de/ '), 'https://a.de');
      expect(normalisiereServerUrl('https://a.de/api//'), 'https://a.de/api');
      expect(normalisiereServerUrl('https://a.de/?x=1#y'), 'https://a.de');
      // LAN ohne Zertifikat (Pi im Gerätehaus) bleibt möglich.
      expect(
        normalisiereServerUrl('http://192.168.1.20:8080'),
        'http://192.168.1.20:8080',
      );
      expect(normalisiereServerUrl(''), isNull);
      expect(normalisiereServerUrl('ftp://a.de'), isNull);
    });

    test('die Datei liegt immer an der Wurzel der Domain', () {
      expect(
        kopplungsAdresse('feuerwehr-musterstadt.de/irgendwas').toString(),
        'https://feuerwehr-musterstadt.de/.well-known/fwapp.json',
      );
      expect(
        kopplungsAdresse('http://pi.local:8080').toString(),
        'http://pi.local:8080/.well-known/fwapp.json',
      );
      expect(kopplungsAdresse('  '), isNull);
    });
  });

  group('Holen', () {
    test('200 liefert die Installation', () async {
      final k = await holeKopplung(
        Uri.parse('https://a.de/.well-known/fwapp.json'),
        client: MockClient((r) async {
          expect(r.url.path, '/.well-known/fwapp.json');
          return http.Response(_json, 200);
        }),
      );
      expect(k.name, 'Feuerwehr Musterstadt');
    });

    test('404, Zeitüberschreitung und kein Netz werden Sätze', () async {
      Future<String> fehlerBei(MockClient c) async {
        try {
          await holeKopplung(
            Uri.parse('https://a.de/x'),
            client: c,
            zeitlimit: const Duration(milliseconds: 50),
          );
          return 'kein Fehler';
        } on KopplungFehler catch (e) {
          return e.text;
        }
      }

      expect(
        await fehlerBei(MockClient((_) async => http.Response('', 404))),
        contains('keine FWApp-Installation'),
      );
      expect(
        await fehlerBei(MockClient((_) => Completer<http.Response>().future)),
        contains('antwortet nicht'),
      );
      expect(
        await fehlerBei(
          MockClient((_) async => throw http.ClientException('Failed host')),
        ),
        contains('nicht erreichbar'),
      );
    });
  });

  group('Prüfen', () {
    final k = ServerKopplung.ausJson(_json);

    test('schickt den Schlüssel an den Health-Endpunkt', () async {
      await pruefeServer(
        k,
        client: MockClient((r) async {
          expect(r.url.toString(), 'https://api.musterstadt.de/auth/v1/health');
          expect(r.headers['apikey'], 'eyJ.test');
          return http.Response('{}', 200);
        }),
      );
    });

    test('Ablehnung und Funkstille halten das Speichern auf', () async {
      await expectLater(
        pruefeServer(
          k,
          client: MockClient((_) async => http.Response('', 401)),
        ),
        throwsA(isA<KopplungFehler>()),
      );
      await expectLater(
        pruefeServer(
          k,
          client: MockClient((_) async => throw http.ClientException('weg')),
        ),
        throwsA(isA<KopplungFehler>()),
      );
    });
  });

  test('speichern schaltet den Sync ein und merkt Quelle und Namen', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await speichereKopplung(
      ServerKopplung.ausJson(_json),
      prefs,
      ServerQuelle.qr,
    );
    expect(prefs.getBool('sync_enabled'), isTrue);
    expect(prefs.getString('supabase_url'), 'https://api.musterstadt.de');
    expect(prefs.getString('supabase_key'), 'eyJ.test');
    expect(prefs.getString(kServerQuellePref), 'qr');
    expect(prefs.getString(kServerNamePref), 'Feuerwehr Musterstadt');
  });

  group('Web-App: welcher Server gilt beim Start', () {
    final eigene = ServerKopplung.ausJson(_json);

    test('die eigene Domain gewinnt über die eingebaute Vorgabe', () {
      final w =
          waehleWebServer(
            eigeneInstallation: eigene,
            gespeicherteUrl: '',
            gespeicherteQuelle: null,
            hatEingebauteVorgabe: true,
          )!;
      expect(w.url, 'https://api.musterstadt.de');
      // ⚠️ Unser Bündel hat eine Vorgabe: Der Sync wird NICHT eingeschaltet
      // — wer die Web-App im Lokalmodus nutzt, bekommt keinen Anmeldezwang.
      expect(w.einschalten, isFalse);
    });

    test('das neutrale Bündel des Installers schaltet den Sync ein', () {
      expect(
        waehleWebServer(
          eigeneInstallation: eigene,
          gespeicherteUrl: null,
          gespeicherteQuelle: null,
          hatEingebauteVorgabe: false,
        )!.einschalten,
        isTrue,
      );
    });

    test('eine bewusst eingetragene Adresse gewinnt immer', () {
      for (final quelle in [null, 'hand', 'qr', 'domain']) {
        expect(
          waehleWebServer(
            eigeneInstallation: eigene,
            gespeicherteUrl: 'https://anders.de',
            gespeicherteQuelle: quelle,
            hatEingebauteVorgabe: true,
          ),
          isNull,
          reason: 'Quelle $quelle',
        );
      }
    });

    test('eine früher von der Domain gelernte Adresse wird aufgefrischt', () {
      expect(
        waehleWebServer(
          eigeneInstallation: eigene,
          gespeicherteUrl: 'https://alt.de',
          gespeicherteQuelle: 'web',
          hatEingebauteVorgabe: true,
        )?.url,
        'https://api.musterstadt.de',
      );
    });

    test('ohne Datei (Entwicklung, offline) bleibt alles, wie es ist', () {
      expect(
        waehleWebServer(
          eigeneInstallation: null,
          gespeicherteUrl: '',
          gespeicherteQuelle: null,
          hatEingebauteVorgabe: true,
        ),
        isNull,
      );
    });
  });
}
