/// party_frage.dart – Eine Frage der Partie und das Mischen der Töpfe
/// (Issue #160).
///
/// Der Party-Modus stellt Fragen aus drei Quellen: den Fächern des Fahrzeugs,
/// den Gerätefotos und einem mitgelieferten Topf unerwarteter Fragen. Die
/// Auswahl steckt bewusst hier und nicht im Screen — sie hat Regeln
/// ([mischePartie]), und Regeln gehören dahin, wo man sie ohne Oberfläche
/// prüfen kann.
///
/// ⚠️ **Eine Runde bleibt bei einer Kategorie** und **eine Fach-Frage nennt
/// ihr Fahrzeug** (Issue #172). Beides kam aus dem Spiel am Tisch zurück: Ein
/// Fuhrpark mit fünf Fahrzeugen macht „In welchem Fach liegt das?" ohne
/// Fahrzeugangabe unbeantwortbar, und ein Kategorienwechsel bei jeder Frage
/// lässt jeden Zug wie ein anderes Spiel wirken.
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

/// Wie die Kategorie am Tisch angesagt wird.
///
/// Steht auf dem Übergabe-Schirm, damit die Zusage „eine Runde, eine
/// Kategorie" (Issue #172) sichtbar ist und nicht nur im Code gilt.
extension PartyFrageArtName on PartyFrageArt {
  String get bezeichnung => switch (this) {
        PartyFrageArt.fach => 'Wo liegt was?',
        PartyFrageArt.bild => 'Was ist das?',
        PartyFrageArt.unerwartet => 'Unerwartetes',
      };
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

  /// Das Fahrzeug, um dessen Fächer es geht (Issue #172).
  ///
  /// Ohne diese Angabe war eine Fach-Frage bei mehreren Fahrzeugen nicht zu
  /// beantworten: Vier Fachnamen stehen zur Wahl, aber von welchem Wagen sie
  /// stammen, stand erst in der Auflösung — also nach der Antwort. Bei
  /// [PartyFrageArt.bild] bleibt das Feld leer, ein Gerät kann auf mehreren
  /// Fahrzeugen liegen.
  final String? fahrzeug;

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
    this.fahrzeug,
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
/// trotzdem über dem eigenen Fahrzeug stattfindet. Seit Issue #172 zählt der
/// Anteil in **Runden** statt in Einzelfragen: Jede dritte Runde ist die
/// unerwartete.
const kUnerwartetAnteil = 3;

/// Stellt aus den drei Töpfen eine Partie mit [anzahl] Fragen zusammen.
///
/// [proRunde] ist die Zahl der Spieler — eine Runde ist genau ein Umlauf des
/// Handys. Die Partie wird deshalb **rundenweise** gebaut und nicht Frage für
/// Frage.
///
/// Zugesichert wird viererlei:
/// - **Eine Runde, eine Kategorie** (Issue #172). Alle Spieler eines Umlaufs
///   bekommen dieselbe Art Frage. Das war der Wunsch aus dem Spiel am Tisch
///   und ist nebenbei fairer: Vorher konnte einer ein Klischee raten, während
///   der Nächste ein Fach aus dem Kopf wissen musste.
/// - **Keine Frage doppelt.** Bei acht Fragen und einer Wiederholung wüssten
///   alle die Antwort schon.
/// - **Unerwartete Fragen sind dabei**, solange der Topf etwas hergibt — er
///   ist der einzige, der ohne eigenen Bestand funktioniert.
/// - **Leere Töpfe stören nicht.** Eine frische Installation hat weder
///   Beladung noch Fotos; die Partie läuft dann allein aus dem Asset.
///
/// Der Preis der Rundenregel: Reicht keine Kategorie mehr für einen ganzen
/// Umlauf, hängen die übrigen Fragen **gemischt hinten an** — eine gemischte
/// letzte Runde ist besser als eine Partie, die früher aufhört als bestellt.
/// Aus demselben Grund kann bei sehr wenigen Runden eine Kategorie ganz
/// ausfallen: Bei zwei Umläufen gibt es keine drei Kategorien.
List<PartyFrage> mischePartie({
  required List<PartyFrage> fach,
  required List<PartyFrage> bild,
  required List<PartyFrage> unerwartet,
  required int anzahl,
  required int proRunde,
  required Random zufall,
}) {
  if (anzahl <= 0) return const [];
  // Eine Partie ohne Spielerzahl ist eine einzige lange Runde.
  final rundenlaenge = proRunde <= 0 ? anzahl : proRunde;

  final vorrat = <PartyFrageArt, List<PartyFrage>>{
    PartyFrageArt.unerwartet: [...unerwartet]..shuffle(zufall),
    PartyFrageArt.fach: [...fach]..shuffle(zufall),
    PartyFrageArt.bild: [...bild]..shuffle(zufall),
  };

  /// Nimmt [wieViele] Fragen aus dem Topf und entfernt sie daraus.
  List<PartyFrage> entnimm(PartyFrageArt art, int wieViele) {
    final topf = vorrat[art]!;
    final genommen = topf.take(wieViele).toList();
    topf.removeRange(0, genommen.length);
    return genommen;
  }

  final runden = <List<PartyFrage>>[];
  // Fach und Bild wechseln sich in den übrigen Runden ab: Wer nur Fächer
  // bekäme, hätte einen halben Modus vor sich.
  var wechsel = PartyFrageArt.fach;

  for (var r = 0; r * rundenlaenge < anzahl; r++) {
    final rest = anzahl - r * rundenlaenge;
    final soll = rest < rundenlaenge ? rest : rundenlaenge;
    final wunsch =
        r % kUnerwartetAnteil == 0 ? PartyFrageArt.unerwartet : wechsel;

    // Die Wunschkategorie nur, wenn sie die Runde ganz füllt — sonst die mit
    // dem größten Rest. Eine halb gefüllte Runde wäre wieder eine gemischte.
    var art = vorrat[wunsch]!.length >= soll ? wunsch : null;
    if (art == null) {
      for (final kandidat in vorrat.keys) {
        if (vorrat[kandidat]!.length < soll) continue;
        if (art == null || vorrat[kandidat]!.length > vorrat[art]!.length) {
          art = kandidat;
        }
      }
    }
    // Keine Kategorie füllt einen ganzen Umlauf mehr — hier hört die
    // Rundeneinteilung auf, der Rest hängt unten an.
    if (art == null) break;

    if (art != PartyFrageArt.unerwartet) {
      wechsel =
          art == PartyFrageArt.fach ? PartyFrageArt.bild : PartyFrageArt.fach;
    }
    runden.add(entnimm(art, soll));
  }

  // Die Runden mischen, nicht die Fragen: Sonst wäre die erste Runde immer
  // die unerwartete, und ab dem dritten Abend wüsste das jeder.
  runden.shuffle(zufall);
  final partie = [for (final runde in runden) ...runde];

  if (partie.length < anzahl) {
    final uebrig = [for (final topf in vorrat.values) ...topf]
      ..shuffle(zufall);
    partie.addAll(uebrig.take(anzahl - partie.length));
  }

  return partie;
}
