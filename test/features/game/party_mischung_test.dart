/// party_mischung_test.dart – Wie eine Partie zusammengestellt wird
/// (Issue #160).
///
/// Die drei Töpfe sind unterschiedlich gut gefüllt: Eine frische Installation
/// hat weder Beladung noch Fotos, eine gepflegte Wehr hat hunderte Fächer und
/// kaum Bilder. [mischePartie] muss in beiden Fällen eine spielbare Partie
/// liefern — und die unerwarteten Fragen dürfen dabei nie unter den Tisch
/// fallen, sie waren der ausdrückliche Wunsch im Issue.
///
/// Seit Issue #172 kommt eine zweite Zusage dazu: **eine Runde, eine
/// Kategorie.** Sie steht ganz unten und ist der Grund, warum hier
/// rundenweise geprüft wird und nicht über die ganze Partie.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/game/party/domain/party_frage.dart';

PartyFrage frage(PartyFrageArt art, String text) => PartyFrage(
      art: art,
      text: text,
      antworten: const [PartyAntwort('a'), PartyAntwort('b')],
      richtig: 0,
    );

List<PartyFrage> topf(PartyFrageArt art, String praefix, int n) =>
    List.generate(n, (i) => frage(art, '$praefix$i'));

/// Zerlegt eine Partie in ihre Runden — genauso, wie `PartyStand.zugNummer`
/// am Handy rechnet.
List<List<PartyFrage>> runden(List<PartyFrage> partie, int proRunde) => [
      for (var i = 0; i < partie.length; i += proRunde)
        partie.sublist(i, min(i + proRunde, partie.length)),
    ];

void main() {
  final zufall = Random(160);

  test('liefert genau so viele Fragen wie bestellt', () {
    final partie = mischePartie(
      fach: topf(PartyFrageArt.fach, 'F', 30),
      bild: topf(PartyFrageArt.bild, 'B', 30),
      unerwartet: topf(PartyFrageArt.unerwartet, 'U', 30),
      anzahl: 12,
      proRunde: 3,
      zufall: zufall,
    );
    expect(partie, hasLength(12));
  });

  test('keine Frage doppelt', () {
    final partie = mischePartie(
      fach: topf(PartyFrageArt.fach, 'F', 10),
      bild: topf(PartyFrageArt.bild, 'B', 10),
      unerwartet: topf(PartyFrageArt.unerwartet, 'U', 10),
      anzahl: 20,
      proRunde: 4,
      zufall: zufall,
    );
    expect(partie.map((f) => f.text).toSet(), hasLength(partie.length));
  });

  test('unerwartete Fragen sind dabei — darum ging es im Issue', () {
    final partie = mischePartie(
      fach: topf(PartyFrageArt.fach, 'F', 100),
      bild: topf(PartyFrageArt.bild, 'B', 100),
      unerwartet: topf(PartyFrageArt.unerwartet, 'U', 100),
      anzahl: 9,
      proRunde: 3,
      zufall: zufall,
    );
    final unerwartet =
        partie.where((f) => f.art == PartyFrageArt.unerwartet).length;
    // Ein Drittel ist die Zusage von kUnerwartetAnteil.
    expect(unerwartet, 3);
  });

  test('Fach und Bild kommen beide vor, nicht nur der größere Topf', () {
    // Vier Runden — genug für drei Kategorien. Bei nur zwei Umläufen fällt
    // zwangsläufig eine aus; dann geht die Rundenregel vor (Issue #172).
    final partie = mischePartie(
      fach: topf(PartyFrageArt.fach, 'F', 200),
      bild: topf(PartyFrageArt.bild, 'B', 4),
      unerwartet: topf(PartyFrageArt.unerwartet, 'U', 30),
      anzahl: 12,
      proRunde: 3,
      zufall: zufall,
    );
    expect(partie.where((f) => f.art == PartyFrageArt.fach), isNotEmpty);
    expect(partie.where((f) => f.art == PartyFrageArt.bild), isNotEmpty);
  });

  test('frische Installation: spielbar allein aus dem mitgelieferten Topf',
      () {
    // Kein Fahrzeug, keine Fotos — genau der Zustand nach der ersten
    // Installation. Ohne das wäre der Modus dort tot.
    final partie = mischePartie(
      fach: const [],
      bild: const [],
      unerwartet: topf(PartyFrageArt.unerwartet, 'U', 30),
      anzahl: 10,
      proRunde: 2,
      zufall: zufall,
    );
    expect(partie, hasLength(10));
    expect(partie.every((f) => f.art == PartyFrageArt.unerwartet), isTrue);
  });

  test('zu wenig Vorrat: so viele Fragen wie da sind, statt Wiederholung',
      () {
    final partie = mischePartie(
      fach: topf(PartyFrageArt.fach, 'F', 2),
      bild: const [],
      unerwartet: topf(PartyFrageArt.unerwartet, 'U', 3),
      anzahl: 24,
      proRunde: 2,
      zufall: zufall,
    );
    expect(partie, hasLength(5));
    expect(partie.map((f) => f.text).toSet(), hasLength(5));
  });

  test('gar kein Vorrat oder nichts bestellt: leere Partie', () {
    expect(
        mischePartie(
            fach: const [],
            bild: const [],
            unerwartet: const [],
            anzahl: 6,
            proRunde: 2,
            zufall: zufall),
        isEmpty);
    expect(
        mischePartie(
            fach: topf(PartyFrageArt.fach, 'F', 5),
            bild: const [],
            unerwartet: const [],
            anzahl: 0,
            proRunde: 2,
            zufall: zufall),
        isEmpty);
  });

  group('eine Runde, eine Kategorie (Issue #172)', () {
    test('jede Runde besteht aus einer einzigen Art Frage', () {
      // Der Fall aus dem Issue: volle Töpfe, fünf Spieler, vier Fragen je
      // Spieler. Vorher wechselte die Art bei praktisch jeder Frage.
      final partie = mischePartie(
        fach: topf(PartyFrageArt.fach, 'F', 100),
        bild: topf(PartyFrageArt.bild, 'B', 100),
        unerwartet: topf(PartyFrageArt.unerwartet, 'U', 100),
        anzahl: 20,
        proRunde: 5,
        zufall: zufall,
      );
      expect(partie, hasLength(20));
      for (final runde in runden(partie, 5)) {
        expect(runde.map((f) => f.art).toSet(), hasLength(1),
            reason: 'gemischte Runde: ${runde.map((f) => f.text)}');
      }
    });

    test('auch bei knappem Vorrat bleibt jede volle Runde rein', () {
      // Kein einziges Foto und nur wenige Fach-Fragen — der Normalfall einer
      // Wehr, die gerade erst anfängt zu pflegen. Eine Runde darf sich
      // trotzdem nicht aus zwei Töpfen bedienen, nur um voll zu werden.
      final partie = mischePartie(
        fach: topf(PartyFrageArt.fach, 'F', 6),
        bild: const [],
        unerwartet: topf(PartyFrageArt.unerwartet, 'U', 30),
        anzahl: 12,
        proRunde: 3,
        zufall: zufall,
      );
      expect(partie, hasLength(12));
      for (final runde in runden(partie, 3)) {
        expect(runde.map((f) => f.art).toSet(), hasLength(1));
      }
      // Fach-Fragen kommen vor, aber nur in ganzen Runden — nie als
      // Lückenfüller.
      final fachFragen = partie.where((f) => f.art == PartyFrageArt.fach);
      expect(fachFragen, isNotEmpty);
      expect(fachFragen.length % 3, 0);
    });

    test('die unerwartete Runde steht nicht immer vorn', () {
      // Ohne das Mischen der Runden wäre Runde 1 jedes Mal die unerwartete —
      // ab dem dritten Abend wüsste das jeder am Tisch.
      final stellen = <int>{};
      for (var lauf = 0; lauf < 20; lauf++) {
        final partie = mischePartie(
          fach: topf(PartyFrageArt.fach, 'F', 100),
          bild: topf(PartyFrageArt.bild, 'B', 100),
          unerwartet: topf(PartyFrageArt.unerwartet, 'U', 100),
          anzahl: 12,
          proRunde: 3,
          zufall: Random(lauf),
        );
        stellen.add(runden(partie, 3)
            .indexWhere((r) => r.first.art == PartyFrageArt.unerwartet));
      }
      expect(stellen, hasLength(greaterThan(1)));
    });

    test('ohne Spielerzahl ist die Partie eine einzige Runde', () {
      // Verteidigt den Rückfall: `proRunde: 0` darf weder durch null teilen
      // noch endlos laufen.
      final partie = mischePartie(
        fach: topf(PartyFrageArt.fach, 'F', 10),
        bild: const [],
        unerwartet: topf(PartyFrageArt.unerwartet, 'U', 10),
        anzahl: 8,
        proRunde: 0,
        zufall: zufall,
      );
      expect(partie, hasLength(8));
      expect(partie.map((f) => f.art).toSet(), hasLength(1));
    });
  });
}
