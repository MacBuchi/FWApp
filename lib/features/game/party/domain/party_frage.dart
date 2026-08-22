/// party_frage.dart – Eine Frage der Partie und das Mischen der Töpfe
/// (Issue #160).
///
/// Der Party-Modus stellt Fragen aus drei Quellen: den Fächern des Fahrzeugs,
/// den Gerätefotos und einem mitgelieferten Topf unerwarteter Fragen. Die
/// Auswahl steckt bewusst hier und nicht im Screen — sie hat Regeln
/// ([mischePartie]), und Regeln gehören dahin, wo man sie ohne Oberfläche
/// prüfen kann.
library;

import 'dart:math';

import 'package:fwapp/features/compartment/presentation/fach_antwort.dart';

/// Woher eine Frage stammt. Die Art entscheidet, wie sie dargestellt wird.
enum PartyFrageArt {
  /// „In welchem Fach liegt das?" — Antworten mit Farbpunkt und Verortung.
  fach,

  /// „Was ist das?" — Foto des Geräts, Antworten sind Gerätenamen.
  bild,

  /// Aus [assets/game/party.json]: Wissen und Klischees, ohne eigene Daten.
  unerwartet,
}

/// Eine Antwortmöglichkeit.
///
/// [fach] ist nur bei [PartyFrageArt.fach] gesetzt und trägt dann Seite und
/// Längsposition — dieselbe Darstellung wie im Fach-Quiz (Issue #167).
class PartyAntwort {
  final String text;
  final FachAntwort? fach;

  const PartyAntwort(this.text, {this.fach});

  factory PartyAntwort.ausFach(FachAntwort f) =>
      PartyAntwort(f.label, fach: f);
}

/// Eine gestellte Frage.
///
/// Die richtige Antwort steht als **Index**, nicht als Text: Zwei Fächer eines
/// Fahrzeugs dürfen gleich heißen, und ein Textvergleich würde dann beide als
/// richtig werten.
class PartyFrage {
  final PartyFrageArt art;

  /// Die Frage selbst („In welchem Fach liegt der Spreizer?").
  final String text;

  /// Überschrift über der Frage, z. B. der Gerätename. Optional.
  final String? kopfzeile;

  /// Foto des Geräts, falls vorhanden.
  final String? bildPfad;

  /// Funktions-Schlagworte für das Ersatz-Piktogramm, wenn kein Foto da ist.
  final List<String> funktionen;

  final List<PartyAntwort> antworten;
  final int richtig;

  /// Wird nach dem Antworten gezeigt, falls vorhanden.
  final String? erklaerung;

  const PartyFrage({
    required this.art,
    required this.text,
    required this.antworten,
    required this.richtig,
    this.kopfzeile,
    this.bildPfad,
    this.funktionen = const [],
    this.erklaerung,
  });

  PartyAntwort get richtigeAntwort => antworten[richtig];

  bool istRichtig(int index) => index == richtig;
}

/// Wie viele Fragen einer Partie höchstens aus dem unerwarteten Topf kommen.
///
/// „Da sollten auch ein paar unerwartete Fragen rein" (Issue #160) — ein
/// Drittel ist genug, damit sie auffallen, und wenig genug, dass der Abend
/// trotzdem über dem eigenen Fahrzeug stattfindet.
const kUnerwartetAnteil = 3;

/// Stellt aus den drei Töpfen eine Partie mit [anzahl] Fragen zusammen.
///
/// Zugesichert wird dreierlei:
/// - **Keine Frage doppelt.** Bei acht Fragen und einer Wiederholung wüssten
///   alle die Antwort schon.
/// - **Unerwartete Fragen sind dabei**, solange der Topf etwas hergibt — er
///   ist der einzige, der ohne eigenen Bestand funktioniert.
/// - **Leere Töpfe stören nicht.** Eine frische Installation hat weder
///   Beladung noch Fotos; die Partie läuft dann allein aus dem Asset.
List<PartyFrage> mischePartie({
  required List<PartyFrage> fach,
  required List<PartyFrage> bild,
  required List<PartyFrage> unerwartet,
  required int anzahl,
  required Random zufall,
}) {
  if (anzahl <= 0) return const [];

  List<PartyFrage> gemischt(List<PartyFrage> topf) =>
      [...topf]..shuffle(zufall);

  final ausUnerwartet = gemischt(unerwartet);
  final ausFach = gemischt(fach);
  final ausBild = gemischt(bild);

  final partie = <PartyFrage>[];

  // Erst der unerwartete Anteil, damit er nicht hinten herausfällt, wenn die
  // anderen Töpfe voll sind.
  final sollUnerwartet = (anzahl / kUnerwartetAnteil).ceil();
  partie.addAll(ausUnerwartet.take(sollUnerwartet));

  // Dann Fach und Bild im Wechsel: Wer nur Fächer bekäme, hätte einen halben
  // Modus vor sich.
  var i = 0;
  while (partie.length < anzahl && (i < ausFach.length || i < ausBild.length)) {
    if (i < ausFach.length && partie.length < anzahl) partie.add(ausFach[i]);
    if (i < ausBild.length && partie.length < anzahl) partie.add(ausBild[i]);
    i++;
  }

  // Bleibt Platz, füllt der unerwartete Topf auf — er ist der einzige, der
  // unabhängig vom Bestand etwas hergibt.
  if (partie.length < anzahl) {
    partie.addAll(
        ausUnerwartet.skip(sollUnerwartet).take(anzahl - partie.length));
  }

  partie.shuffle(zufall);
  return partie;
}
