/// zugang_teilen_test.dart – Was in einem WhatsApp-Verlauf landen darf.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/settings/domain/zugang_teilen.dart';

void main() {
  group('Persönlicher Zugang', () {
    test('trägt Zugangsdaten und den Hinweis auf den Pflichtwechsel', () {
      final text = zugangsNachricht(nutzername: 'max.m', passwort: 'Ab3xy');

      expect(text, contains('Nutzername: max.m'));
      expect(text, contains('Passwort: Ab3xy'));
      // Ohne diesen Satz wirkt der erzwungene Wechsel beim ersten Anmelden
      // wie ein Fehler — und genau dort steigen Leute aus.
      expect(text, contains('eigenes Passwort'));
    });

    test('nennt die Adresse nur, wenn es eine gibt', () {
      final ohne =
          zugangsNachricht(nutzername: 'max.m', passwort: 'x', webUrl: '');
      final mit = zugangsNachricht(
          nutzername: 'max.m', passwort: 'x', webUrl: 'https://beispiel.test');

      expect(mit, contains('https://beispiel.test'));
      // Eine nachnutzende Wehr, die ohne --dart-define baut, darf keinen
      // Link auf eine fremde Instanz verschicken. Leer heißt: keine Zeile,
      // nicht „https://" als Rumpf.
      expect(ohne, isNot(contains('http')));
      expect(ohne, contains('Nutzername: max.m'));
    });
  });

  group('Demo-Zugang', () {
    test('benennt die Wehr als erfunden und den Zugang als lesend', () {
      final text = demoNachricht(webUrl: 'https://beispiel.test');

      expect(text, contains(kDemoNutzername));
      expect(text, contains(kDemoPasswort));
      // Wer die Nachricht bekommt, muss sofort wissen, dass die Fahrzeuge
      // erfunden sind — sonst hält er die Demo für den Bestand einer Wehr.
      expect(text, contains(kDemoWehrName));
      expect(text, contains('keine echten Daten'));
      expect(text, contains('nur zum Lesen'));
    });

    test('das geteilte Konto ist dasselbe wie im Seed-Skript', () {
      // Sprachgrenze: Die App verschickt die Zugangsdaten, das Python-Skript
      // legt sie an. Laufen die beiden Werte auseinander, verschickt die App
      // ein Passwort, mit dem sich niemand anmelden kann — und auffallen
      // würde es erst dem Empfänger.
      final seed = File('tool/demo_wehr.py').readAsStringSync();

      expect(
        seed,
        contains('MITGLIED_PASSWORT = "$kDemoPasswort"'),
        reason: 'tool/demo_wehr.py legt ein anderes Passwort an, als die App '
            'verschickt.',
      );
      expect(
        seed,
        contains('"email": "$kDemoNutzername@fw.local"'),
        reason: 'Das geteilte Konto heißt im Seed-Skript anders.',
      );
      // Und es muss das Konto sein, das nur liest: Ein öffentlich bekanntes
      // Passwort auf einem schreibenden Konto wäre ein Freibrief.
      final block = seed.substring(seed.indexOf('"$kDemoNutzername@fw.local"'));
      expect(
        block.substring(0, block.indexOf('},')),
        allOf(contains('"rolle": "member"'), contains('"oeffentlich": True')),
        reason: 'Das öffentliche Passwort gehört ausschließlich dem lesenden '
            'Konto.',
      );
    });
  });
}
