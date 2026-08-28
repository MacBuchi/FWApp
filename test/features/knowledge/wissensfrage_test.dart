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
      Set<int> richtige = const {0},
    }) =>
        pruefeFrage(frage: frage, antworten: antworten, richtige: richtige);

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
      expect(pruefe(antworten: ['15 m'], richtige: {0}), isNotNull);
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
      expect(pruefe(richtige: const {}), isNotNull);
      expect(pruefe(richtige: {99}), isNotNull);
    });

    test('sieben Antworten sind erlaubt — der Prüfungsstoff geht bis zehn',
        () {
      // Die erste Fassung stoppte bei sechs. Das war geraten: Im amtlichen
      // Fragenkatalog laufen die Antwortkennungen bis „j)".
      expect(
          pruefe(
              antworten: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
              richtige: {0}),
          isNull);
    });

    test('mehr als zehn Antworten werden abgewiesen', () {
      expect(
          pruefe(
              antworten: const [
                'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k'
              ],
              richtige: {0}),
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
          richtige: const {0},
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

  group('Mehrfachantworten (Issue #174)', () {
    // Der Grund in einer Zahl: Im Fragenkatalog des Innenministeriums BW
    // haben nur 79 von 210 Fragen genau eine richtige Antwort.
    Wissensfrage mitRichtigen(Set<int> richtige) => Wissensfrage(
          id: 1,
          gebiet: Wissensgebiet.loeschlehre,
          frage: 'Welche Aussagen zur Brandklasse A sind richtig?',
          antworten: const ['Feste Stoffe', 'Gase', 'Glutbildend', 'Metalle'],
          richtige: richtige,
        );

    test('richtig ist nur, wer alle trifft und keine danebenlegt', () {
      final f = mitRichtigen({0, 2});
      expect(f.istRichtig({0, 2}), isTrue);
      // Reihenfolge egal — es ist eine Menge.
      expect(f.istRichtig({2, 0}), isTrue);
      // Eine fehlt.
      expect(f.istRichtig({0}), isFalse);
      // Eine zu viel.
      expect(f.istRichtig({0, 1, 2}), isFalse);
      // Gar nichts angekreuzt.
      expect(f.istRichtig(const {}), isFalse);
    });

    test('teilweise richtig gibt es nicht', () {
      // Im Prüfungsbogen gibt es keine Teilpunkte, und sie hier zu erfinden
      // wäre eine andere Bewertung als die, auf die hin geübt wird.
      expect(mitRichtigen({0, 1, 2}).istRichtig({0, 1}), isFalse);
    });

    test('nur Einfachauswahl geht in den Party-Modus', () {
      // Am Tisch reihum ist Mehrfach-Ankreuzen kein Spielzug.
      expect(mitRichtigen({1}).istEinfachauswahl, isTrue);
      expect(mitRichtigen({0, 2}).istEinfachauswahl, isFalse);
    });

    test('alle Antworten richtig ist keine Frage', () {
      expect(
          pruefeFrage(
              frage: 'Welche gehören dazu?',
              antworten: const ['a', 'b'],
              richtige: {0, 1}),
          isNotNull);
    });

    test('mehrere richtige gehen durch', () {
      expect(
          pruefeFrage(
              frage: 'Welche Aussagen sind richtig?',
              antworten: const ['a', 'b', 'c', 'd'],
              richtige: {0, 2, 3}),
          isNull);
    });
  });

  group('Geltungsbereich und Quelle', () {
    test('Landesrecht wird benannt, Bundesweites bleibt neutral', () {
      const bund = Wissensfrage(
        id: 1,
        gebiet: Wissensgebiet.loeschlehre,
        frage: 'Was ist Brandklasse A?',
        antworten: ['Feste Stoffe', 'Gase'],
        richtige: {0},
      );
      const land = Wissensfrage(
        id: 2,
        gebiet: Wissensgebiet.rechtUndOrganisation,
        frage: 'Wer wählt den Feuerwehrkommandanten?',
        antworten: ['Die Einsatzabteilungen', 'Der Bürgermeister'],
        richtige: {0},
        geltung: Geltungsbereich.land,
        land: 'BW',
      );
      expect(bund.geltungAnzeige, 'Bundesweit');
      expect(land.geltungAnzeige, 'Baden-Württemberg');
    });

    test('die Fundstelle steht in einer Zeile', () {
      const q = Fragenquelle(werk: 'FwG BW', fundstelle: '§ 8 Abs. 2');
      expect(q.anzeige, 'FwG BW · § 8 Abs. 2');
      // Ohne Fundstelle bleibt es beim Werk — kein einsamer Trenner.
      expect(const Fragenquelle(werk: 'FwDV 10').anzeige, 'FwDV 10');
    });

    test('ein unbekanntes Land fällt nicht auf die Nase', () {
      const f = Wissensfrage(
        id: 3,
        gebiet: Wissensgebiet.funk,
        frage: 'Was bedeutet „kommen"?',
        antworten: ['Sprechaufforderung', 'Ende'],
        richtige: {0},
        geltung: Geltungsbereich.land,
        land: 'XX',
      );
      expect(f.geltungAnzeige, 'Landesrecht');
    });
  });
}
