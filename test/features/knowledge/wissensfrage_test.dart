/// wissensfrage_test.dart – Was eine Frage sein muss, um in die Datenbank zu
/// dürfen (Issue #174).
///
/// Die Prüfung steht in der Domäne, weil sie zwei Türen bewacht: das
/// Formular und — sobald er kommt — den CSV-Import. Zwei Fassungen derselben
/// Regel laufen auseinander, und dann kommt durch die eine Tür herein, was
/// die andere abweist. Genau das wollte das Issue verhindern: „Filterung,
/// damit kein blöder Unsinn in die Datenbank kommt."
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

void main() {
  group('pruefeFrage', () {
    String? pruefe({
      String frage = 'Wie lang ist ein C-Druckschlauch?',
      List<String> antworten = const ['15 m', '20 m', '30 m'],
      int richtig = 0,
    }) =>
        pruefeFrage(frage: frage, antworten: antworten, richtig: richtig);

    test('eine ordentliche Frage geht durch', () {
      expect(pruefe(), isNull);
    });

    test('ohne Fragezeichen ist es keine Frage', () {
      // Der häufigste Fehlgriff beim schnellen Eintippen — und im Quiz steht
      // dann eine Behauptung, auf die man antworten soll.
      expect(pruefe(frage: 'Länge eines C-Schlauchs'), isNotNull);
    });

    test('zu kurz wird abgewiesen', () {
      expect(pruefe(frage: 'Was?'), isNotNull);
    });

    test('eine einzige Antwort ist kein Quiz', () {
      expect(pruefe(antworten: ['15 m'], richtig: 0), isNotNull);
    });

    test('zwei gleiche Antworten machen die Frage unbeantwortbar', () {
      // Zwei identische Texte, einer davon als richtig gewertet: Wer den
      // anderen tippt, hat sachlich recht und bekommt trotzdem einen Fehler.
      expect(pruefe(antworten: ['15 m', '15 m', '20 m']), isNotNull);
      // Auch mit anderer Schreibweise.
      expect(pruefe(antworten: ['15 m', '15 M', '20 m']), isNotNull);
    });

    test('eine leere Antwort wird abgewiesen', () {
      expect(pruefe(antworten: ['15 m', '', '20 m']), isNotNull);
    });

    test('ohne markierte richtige Antwort geht nichts', () {
      // Genau das passiert im Formular, wenn jemand die als richtig
      // angetippte Antwort danach leert.
      expect(pruefe(richtig: -1), isNotNull);
      expect(pruefe(richtig: 99), isNotNull);
    });

    test('mehr als sechs Antworten passen auf kein Handy', () {
      expect(
          pruefe(
              antworten: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
              richtig: 0),
          isNotNull);
    });

    test('Leerraum ringsum stört nicht', () {
      expect(pruefe(antworten: const ['  15 m  ', '20 m']), isNull);
    });
  });

  group('Wissensgebiet', () {
    test('der Schlüssel ist stabil, nicht das Label', () {
      // In der Datenbank steht der Schlüssel. Wer das Label umbenennt, darf
      // damit keine Frage aus ihrem Gebiet werfen.
      expect(Wissensgebiet.ausSchluessel('geraetekunde'),
          Wissensgebiet.geraetekunde);
      expect(Wissensgebiet.ausSchluessel('Gerätekunde'), isNull);
      expect(Wissensgebiet.ausSchluessel(null), isNull);
    });

    test('Klischees zählen nicht zum Lernstoff', () {
      // Sonst hielte jemand beim Üben ein Klischee für Prüfungsstoff.
      expect(Wissensgebiet.lernstoff, isNot(contains(Wissensgebiet.klischee)));
      expect(Wissensgebiet.lernstoff, contains(Wissensgebiet.loeschlehre));
    });

    test('jedes Gebiet hat einen eigenen Schlüssel', () {
      final schluessel =
          Wissensgebiet.values.map((g) => g.schluessel).toList();
      expect(schluessel.toSet(), hasLength(schluessel.length));
    });
  });

  group('Wissensfrage', () {
    Wissensfrage bauen({
      Fragenherkunft herkunft = Fragenherkunft.eigen,
      Fragenstand stand = Fragenstand.freigegeben,
    }) =>
        Wissensfrage(
          id: 1,
          gebiet: Wissensgebiet.geraetekunde,
          frage: 'Wie lang ist ein C-Druckschlauch?',
          antworten: const ['15 m', '20 m'],
          richtig: 0,
          herkunft: herkunft,
          stand: stand,
        );

    test('gestellt wird nur, was freigegeben ist', () {
      expect(bauen().spielbar, isTrue);
      expect(bauen(stand: Fragenstand.eingereicht).spielbar, isFalse);
      expect(bauen(stand: Fragenstand.abgelehnt).spielbar, isFalse);
    });

    test('Mitgeliefertes ist nicht löschbar', () {
      // Es käme beim nächsten Start ohnehin aus dem Asset wieder — ein
      // Löschknopf wäre eine Lüge.
      expect(bauen(herkunft: Fragenherkunft.mitgeliefert).loeschbar, isFalse);
      expect(bauen(herkunft: Fragenherkunft.eigen).loeschbar, isTrue);
    });

    test('unbekannte Werte fallen auf den sicheren Fall zurück', () {
      // Ein Server, der einen neuen Stand kennt, den diese App-Version noch
      // nicht hat, darf keine Frage ins Spiel schmuggeln.
      expect(Fragenstand.ausSchluessel('was_neues'), Fragenstand.eingereicht);
      expect(Fragenherkunft.ausSchluessel('was_neues'), Fragenherkunft.eigen);
    });
  });
}
