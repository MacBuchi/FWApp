/// mailbridge_events_test.dart – Die Zustellauskunft der Mail-Brücke
/// (Issue #121).
///
/// Warum die Auskunft überhaupt auf dem Host sitzt und nicht im
/// edge-functions-Container: Die VM hat kein IPv4, `api.brevo.com` hat IPv6
/// — aber Docker-Bridge-Netze auf ihr haben keinen IPv6-Ausgang. Der
/// Container KANN Brevo nicht fragen. Die Brücke ist ohnehin draußen, also
/// fragt sie; angenehmer Nebeneffekt: Der Schlüssel bleibt auf dem Host.
///
/// Der Preis dafür ist ein HTTP-Ohr, das aus einem Container erreichbar ist.
/// Genau darum geht es hier: Es darf **kein allgemeiner Weiterleiter**
/// werden. Geprüft wird gegen die tatsächlich ausgelieferte Datei
/// `tool/vm/fwapp_mailbridge.py`, nicht gegen eine Abschrift — die Probe
/// lädt sie, hängt eine Attrappe vor den Netzzugriff und schaut nach, wohin
/// der Aufruf gegangen WÄRE.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> ergebnis;

  setUpAll(() {
    final tmp = Directory.systemTemp.createTempSync('mailbridge');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final key = File('${tmp.path}/brevo-api-key.txt')
      ..writeAsStringSync('xkeysib-probe');

    final lauf = Process.runSync('python3', [
      'test/vm/mailbridge_probe.py',
      'tool/vm/fwapp_mailbridge.py',
      key.path,
    ]);
    expect(lauf.exitCode, 0, reason: lauf.stderr.toString());
    final zeilen = (lauf.stdout as String)
        .split('\n')
        .where((z) => z.trim().startsWith('{'))
        .toList();
    expect(zeilen, isNotEmpty, reason: lauf.stdout.toString());
    ergebnis = jsonDecode(zeilen.last) as Map<String, dynamic>;
  });

  test('eine gültige Anfrage kommt durch und reicht Brevo unverändert weiter',
      () {
    expect(ergebnis['gut']['status'], 200);
    expect(ergebnis['gut']['rumpf'], contains('delivered'));
  });

  test('der Schlüssel geht an Brevo — und nur dorthin', () {
    // Die Ziel-URL ist im Skript fest verdrahtet. Wäre sie es nicht, ginge
    // der Brevo-Schlüssel an ein Ziel, das der Aufrufer bestimmt.
    final ziel = ergebnis['ziel'] as Map<String, dynamic>;
    expect(ziel['url'],
        startsWith('https://api.brevo.com/v3/smtp/statistics/events?'));
    expect(ziel['methode'], 'GET');
    expect(ziel['schluessel'], 'xkeysib-probe');
  });

  test('die Adresse landet kodiert im Parameter, nicht im Pfad', () {
    expect(ergebnis['ziel']['url'], contains('email=max%40web.de'));
  });

  group('was NICHT durchkommt', () {
    void keinAufruf(String fall, int status) {
      final r = ergebnis[fall] as Map<String, dynamic>;
      expect(r['status'], status, reason: fall);
      // Das Entscheidende: Es ging gar keine Anfrage nach draußen.
      expect(r['aufrufe'], 0, reason: fall);
    }

    test('ein anderer Pfad', () => keinAufruf('fremder_pfad', 404));
    test('eine fehlende Adresse', () => keinAufruf('ohne_adresse', 400));

    test('eine Adresse, die in Wahrheit eine URL ist', () {
      // Der Versuch, sich ein fremdes Ziel unterzuschieben. Die Prüfung auf
      // Adressform fängt ihn, bevor irgendetwas hinausgeht.
      keinAufruf('adresse_ist_url', 400);
    });

    test('ein Zeitfenster, das keine Zahl ist',
        () => keinAufruf('days_kein_wert', 400));
  });

  test('das Zeitfenster wird gedeckelt', () {
    // Sonst zöge ein einziger Aufruf die halbe Versandhistorie.
    expect(ergebnis['days_gedeckelt'], contains('days=30&'));
  });

  test('lehnt Brevo ab, wird das gemeldet und nicht durchgereicht', () {
    // 502 statt 401: Der Aufrufer soll nicht denken, SEIN Recht sei das
    // Problem. Und der Brevo-Text bleibt draußen.
    final r = ergebnis['brevo_lehnt_ab'] as Map<String, dynamic>;
    expect(r['status'], 502);
    expect(r['rumpf'], contains('brevo 401'));
    expect(r['rumpf'], isNot(contains('xkeysib')));
  });
}
