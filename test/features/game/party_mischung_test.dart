/// party_mischung_test.dart – Wie eine Partie zusammengestellt wird
/// (Issue #160).
///
/// Die drei Töpfe sind unterschiedlich gut gefüllt: Eine frische Installation
/// hat weder Beladung noch Fotos, eine gepflegte Wehr hat hunderte Fächer und
/// kaum Bilder. [mischePartie] muss in beiden Fällen eine spielbare Partie
/// liefern — und die unerwarteten Fragen dürfen dabei nie unter den Tisch
/// fallen, sie waren der ausdrückliche Wunsch im Issue.
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

void main() {
  final zufall = Random(160);

  test('liefert genau so viele Fragen wie bestellt', () {
    final partie = mischePartie(
      fach: topf(PartyFrageArt.fach, 'F', 30),
      bild: topf(PartyFrageArt.bild, 'B', 30),
      unerwartet: topf(PartyFrageArt.unerwartet, 'U', 30),
      anzahl: 12,
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
      zufall: zufall,
    );
    final unerwartet =
        partie.where((f) => f.art == PartyFrageArt.unerwartet).length;
    // Ein Drittel ist die Zusage von kUnerwartetAnteil.
    expect(unerwartet, 3);
  });

  test('Fach und Bild kommen beide vor, nicht nur der größere Topf', () {
    final partie = mischePartie(
      fach: topf(PartyFrageArt.fach, 'F', 200),
      bild: topf(PartyFrageArt.bild, 'B', 4),
      unerwartet: topf(PartyFrageArt.unerwartet, 'U', 30),
      anzahl: 12,
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
            zufall: zufall),
        isEmpty);
    expect(
        mischePartie(
            fach: topf(PartyFrageArt.fach, 'F', 5),
            bild: const [],
            unerwartet: const [],
            anzahl: 0,
            zufall: zufall),
        isEmpty);
  });
}
