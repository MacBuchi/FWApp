/// party_inhalte_test.dart – Der mitgelieferte Fragen- und Aufgabentopf
/// (Issue #160).
///
/// Die Datei [kPartyAsset] ist zum Erweitern gedacht: Wer eine Frage ergänzt,
/// fasst JSON an und keinen Code. Genau deshalb muss die CI sie lesen — ein
/// Index, der nach dem Umsortieren der Antworten auf die falsche zeigt, fällt
/// sonst erst am Kameradschaftsabend auf, und dann diskutiert die Runde über
/// die App statt über die Antwort.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/game/party/data/party_inhalte.dart';
import 'package:fwapp/features/game/party/domain/party_frage.dart';

void main() {
  group('mitgelieferte Datei', () {
    late PartyInhalte inhalte;
    late Map<String, dynamic> roh;

    setUpAll(() {
      final text = File(kPartyAsset).readAsStringSync();
      roh = jsonDecode(text) as Map<String, dynamic>;
      inhalte = parsePartyInhalte(text);
    });

    test('nichts fällt beim Einlesen heraus', () {
      // Zählt gegen die Rohdatei: Käme eine Frage wegen eines kaputten Index
      // nicht durch, wäre der Unterschied hier zu sehen — der Parser
      // überspringt still, damit die App weiterläuft.
      expect(inhalte.fragen, hasLength((roh['fragen'] as List).length));
      expect(inhalte.aufgaben, hasLength((roh['aufgaben'] as List).length));
    });

    test('genug Vorrat für einen Abend', () {
      // Acht Fragen mal acht Spieler wären 64 — so weit muss es nicht
      // reichen, aber eine Runde ohne Wiederholung schon.
      expect(inhalte.fragen.length, greaterThanOrEqualTo(24));
      expect(inhalte.aufgaben.length, greaterThanOrEqualTo(10));
    });

    test('jede Frage ist beantwortbar', () {
      for (final f in inhalte.fragen) {
        expect(f.antworten.length, greaterThanOrEqualTo(3),
            reason: 'zu wenig Auswahl bei "${f.frage}"');
        expect(f.richtig, inInclusiveRange(0, f.antworten.length - 1),
            reason: '"${f.frage}"');
        expect(f.antworten.toSet(), hasLength(f.antworten.length),
            reason: 'doppelte Antwort bei "${f.frage}"');
        expect(kPartyKategorien, contains(f.kategorie),
            reason: 'unbekannte Kategorie bei "${f.frage}"');
      }
    });

    test('keine Frage steht zweimal drin', () {
      expect(inhalte.fragen.map((f) => f.frage).toSet(),
          hasLength(inhalte.fragen.length));
    });

    test('Klischee-Fragen sagen dazu, dass sie Spaß sind', () {
      // Ohne den Hinweis wirkt eine Klischee-Frage wie eine Wissensfrage, und
      // wer sie „falsch" beantwortet hat, streitet zu Recht.
      for (final f
          in inhalte.fragen.where((f) => f.kategorie == kKategorieKlischee)) {
        expect(f.erklaerung, isNotNull, reason: '"${f.frage}"');
        expect(f.erklaerung!.toLowerCase(), contains('klischee'),
            reason: '"${f.frage}"');
      }
    });

    test('das Mischen behält die richtige Antwort richtig', () {
      // Der Index wandert beim Mischen mit. Ginge das schief, wäre jede
      // Frage falsch bewertet — und niemand würde es sofort merken.
      for (var seed = 0; seed < 20; seed++) {
        final zufall = Random(seed);
        for (final f in inhalte.fragen) {
          final gemischt = f.zuPartyFrage(zufall);
          expect(gemischt.richtigeAntwort.text, f.antworten[f.richtig],
              reason: '"${f.frage}" mit Seed $seed');
          expect(gemischt.art, PartyFrageArt.unerwartet);
        }
      }
    });
  });

  group('parsePartyInhalte', () {
    test('kaputte Datei wirft nicht, sondern liefert leer', () {
      expect(parsePartyInhalte('kein JSON').fragen, isEmpty);
      expect(parsePartyInhalte('[]').aufgaben, isEmpty);
    });

    test('unbrauchbare Einträge fallen einzeln heraus', () {
      final inhalte = parsePartyInhalte(jsonEncode({
        'fragen': [
          {'frage': 'gut', 'antworten': ['a', 'b'], 'richtig': 1},
          {'frage': 'Index daneben', 'antworten': ['a', 'b'], 'richtig': 7},
          {'frage': 'nur eine Antwort', 'antworten': ['a'], 'richtig': 0},
          {'frage': '', 'antworten': ['a', 'b'], 'richtig': 0},
          'gar kein Objekt',
        ],
        'aufgaben': ['machbar', '   ', ''],
      }));
      expect(inhalte.fragen.map((f) => f.frage), ['gut']);
      expect(inhalte.aufgaben, ['machbar']);
    });

    test('ohne Kategorie gilt Wissen', () {
      final inhalte = parsePartyInhalte(jsonEncode({
        'fragen': [
          {'frage': 'x', 'antworten': ['a', 'b'], 'richtig': 0},
        ],
      }));
      expect(inhalte.fragen.single.kategorie, kKategorieWissen);
    });
  });
}
