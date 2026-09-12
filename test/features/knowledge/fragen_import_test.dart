/// fragen_import_test.dart – Fragen aus einer Tabelle einlesen.
///
/// **Der gefährlichste Fehler hier ist der um genau eins.** Menschen zählen
/// ab eins, die Datenbank ab null. Wer die Umrechnung übersieht, importiert
/// vierzig Fragen, bei denen systematisch die falsche Antwort als richtig
/// gilt — und das sieht völlig plausibel aus, bis jemand im Lehrgang danach
/// antwortet. Deshalb steht diese Prüfung hier an erster Stelle und mit
/// ausgeschriebenen Erwartungen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/import/domain/import_models.dart';
import 'package:fwapp/features/knowledge/data/fragen_import.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

ImportTable tabelle(List<List<String>> rows) =>
    ImportTable(name: 'test.csv', rows: rows);

const _kopf = [
  'frage',
  'gebiet',
  'antwort1',
  'antwort2',
  'antwort3',
  'richtig',
];

List<String> zeile(String richtig, {String frage = 'Wie breit ist ein C?'}) =>
    [frage, 'geraetekunde', 'A-Antwort', 'B-Antwort', 'C-Antwort', richtig];

void main() {
  group('welche Antwort ist richtig', () {
    test('„1" meint die ERSTE Antwort, nicht die zweite', () {
      final e = leseFragen(tabelle([_kopf, zeile('1')]));
      final f = e.uebernehmbare.single.frage!;
      expect(f.richtige, {0});
      expect(f.antworten[f.richtige.single], 'A-Antwort');
    });

    test('„a" meint dasselbe wie „1"', () {
      final e = leseFragen(tabelle([_kopf, zeile('a')]));
      expect(e.uebernehmbare.single.frage!.richtige, {0});
    });

    test('„b)" mit Klammer wird auch verstanden', () {
      // Der amtliche Fragenkatalog schreibt „b)" — wer daraus kopiert, hat
      // die Klammer dabei.
      final e = leseFragen(tabelle([_kopf, zeile('b)')]));
      expect(e.uebernehmbare.single.frage!.richtige, {1});
    });

    test('mehrere richtige: „a, c"', () {
      final e = leseFragen(tabelle([_kopf, zeile('a, c')]));
      final f = e.uebernehmbare.single.frage!;
      expect(f.richtige, {0, 2});
      expect(f.antworten[0], 'A-Antwort');
      expect(f.antworten[2], 'C-Antwort');
    });

    test('„1 und 3" geht auch', () {
      final e = leseFragen(tabelle([_kopf, zeile('1 und 3')]));
      expect(e.uebernehmbare.single.frage!.richtige, {0, 2});
    });

    test('eine Antwort, die es nicht gibt, ist ein Fehler', () {
      final e = leseFragen(tabelle([_kopf, zeile('7')]));
      expect(e.uebernehmbare, isEmpty);
      expect(e.fehlerhafte.single.fehler, contains('7'));
    });

    test('„0" ist ein Fehler — gezählt wird ab eins', () {
      // Wer 0-basiert denkt, schreibt „0" für die erste Antwort. Das still
      // als erste Antwort zu lesen waere die Falle: Dann bedeutet dieselbe
      // Datei je nach Schreibweise etwas anderes.
      final e = leseFragen(tabelle([_kopf, zeile('0')]));
      expect(e.uebernehmbare, isEmpty);
    });

    test('leer ist ein Fehler mit klarer Ansage', () {
      final e = leseFragen(tabelle([_kopf, zeile('')]));
      expect(e.fehlerhafte.single.fehler, contains('richtig'));
    });
  });

  group('Reihenfolge der Antwortspalten', () {
    test('antwort10 landet hinter antwort2, nicht dazwischen', () {
      // Alphabetisch käme „antwort10" direkt nach „antwort1" — und dann
      // zeigte „richtig: 2" auf die falsche Antwort.
      final kopf = [
        'frage',
        'gebiet',
        'antwort1',
        'antwort10',
        'antwort2',
        'richtig',
      ];
      final e = leseFragen(tabelle([
        kopf,
        ['Wie breit ist ein C?', 'geraetekunde', 'erste', 'zehnte', 'zweite',
            '2'],
      ]));
      final f = e.uebernehmbare.single.frage!;
      expect(f.antworten, ['erste', 'zweite', 'zehnte']);
      expect(f.antworten[f.richtige.single], 'zweite');
    });

    test('leere Antwortspalten fallen weg', () {
      final e = leseFragen(tabelle([
        _kopf,
        ['Wie breit ist ein C?', 'geraetekunde', 'A', 'B', '', '1'],
      ]));
      expect(e.uebernehmbare.single.frage!.antworten, ['A', 'B']);
    });
  });

  group('Sachgebiet', () {
    test('nimmt den Schlüssel', () {
      final e = leseFragen(tabelle([_kopf, zeile('1')]));
      expect(e.uebernehmbare.single.frage!.gebiet,
          Wissensgebiet.geraetekunde);
    });

    test('nimmt auch das Label', () {
      final e = leseFragen(tabelle([
        _kopf,
        ['Wie breit ist ein C?', 'Atemschutz', 'A', 'B', 'C', '1'],
      ]));
      expect(e.uebernehmbare.single.frage!.gebiet, Wissensgebiet.atemschutz);
    });

    test('ein erfundenes Sachgebiet ist ein Fehler', () {
      final e = leseFragen(tabelle([
        _kopf,
        ['Wie breit ist ein C?', 'Kochkunde', 'A', 'B', 'C', '1'],
      ]));
      expect(e.fehlerhafte.single.fehler, contains('Kochkunde'));
    });
  });

  group('Doppelte', () {
    test('gegen den vorhandenen Bestand', () {
      final e = leseFragen(
        tabelle([_kopf, zeile('1')]),
        vorhandeneFragen: {schluesselFuer('Wie breit ist ein C?')},
      );
      expect(e.uebernehmbare, isEmpty);
      expect(e.doppelte, hasLength(1));
    });

    test('auch INNERHALB der Datei', () {
      // Sonst legt eine Datei dieselbe Frage zweimal an, und das merkt man
      // erst beim Lernen.
      final e = leseFragen(tabelle([_kopf, zeile('1'), zeile('2')]));
      expect(e.uebernehmbare, hasLength(1));
      expect(e.doppelte, hasLength(1));
    });

    test('unterschiedliche Schreibweise zählt als dieselbe Frage', () {
      final e = leseFragen(tabelle([
        _kopf,
        zeile('1', frage: 'Wie breit ist ein C?'),
        zeile('1', frage: '  wie  BREIT ist ein C?  '),
      ]));
      expect(e.uebernehmbare, hasLength(1));
    });
  });

  group('Geltungsbereich', () {
    test('land ohne Länderkürzel ist ein Fehler', () {
      final e = leseFragen(tabelle([
        [..._kopf, 'geltung'],
        [...zeile('1'), 'land'],
      ]));
      expect(e.fehlerhafte.single.fehler, contains('land'));
    });

    test('land mit Kürzel geht', () {
      final e = leseFragen(tabelle([
        [..._kopf, 'geltung', 'land'],
        [...zeile('1'), 'land', 'bw'],
      ]));
      final f = e.uebernehmbare.single.frage!;
      expect(f.geltung, Geltungsbereich.land);
      expect(f.land, 'BW');
    });
  });

  group('Kopfzeile', () {
    test('ohne „frage" bricht es ab — mit Hinweis auf die Vorlage', () {
      expect(
        () => leseFragen(tabelle([
          ['gebiet', 'antwort1'],
          ['geraetekunde', 'A'],
        ])),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('Vorlage'))),
      );
    });

    test('ohne Antwortspalte bricht es ab', () {
      expect(
        () => leseFragen(tabelle([
          ['frage', 'gebiet'],
          ['Wie breit ist ein C?', 'geraetekunde'],
        ])),
        throwsA(isA<FormatException>()),
      );
    });

    test('unbekannte Spalten werden gemeldet, brechen aber nicht ab', () {
      // Der haeufigste Grund, warum eine Spalte „nicht ankommt", ist ein
      // Tippfehler in ihrem Namen — und den sieht man sonst nirgends.
      final e = leseFragen(tabelle([
        [..._kopf, 'Erklaerungg'],
        [...zeile('1'), 'vertippt'],
      ]));
      expect(e.unbekannteSpalten, ['Erklaerungg']);
      expect(e.uebernehmbare, hasLength(1));
    });

    test('Groß- und Kleinschreibung und Leerzeichen sind egal', () {
      final e = leseFragen(tabelle([
        ['  Frage ', 'GEBIET', 'Antwort1', 'Antwort2', 'Richtig'],
        ['Wie breit ist ein C?', 'geraetekunde', 'A', 'B', '1'],
      ]));
      expect(e.uebernehmbare, hasLength(1));
    });
  });

  group('Zeilen', () {
    test('die gemeldete Nummer ist die aus der Tabellenkalkulation', () {
      // Kopfzeile ist 1, erste Datenzeile ist 2. Alles andere zwingt zum
      // Nachzaehlen.
      final e = leseFragen(tabelle([_kopf, zeile('7')]));
      expect(e.fehlerhafte.single.zeile, 2);
    });

    test('eine Leerzeile ist kein Befund', () {
      final e = leseFragen(tabelle([_kopf, ['', '', '', '', '', ''],
          zeile('1')]));
      expect(e.uebernehmbare, hasLength(1));
      expect(e.fehlerhafte, isEmpty);
    });

    test('eine schlechte Zeile haelt die guten nicht auf', () {
      final e = leseFragen(tabelle([
        _kopf,
        zeile('1', frage: 'Erste Frage mit Fragezeichen?'),
        zeile('99', frage: 'Kaputte Frage mit Fragezeichen?'),
        zeile('2', frage: 'Dritte Frage mit Fragezeichen?'),
      ]));
      expect(e.uebernehmbare, hasLength(2));
      expect(e.fehlerhafte, hasLength(1));
    });
  });

  group('die Vorlage', () {
    test('laesst sich selbst wieder einlesen', () {
      // Eine Vorlage, die der eigene Importer nicht frisst, ist schlimmer
      // als keine: Sie sieht richtig aus und scheitert beim ersten Versuch.
      final rows = vorlageCsv()
          .trim()
          .split('\n')
          .map((z) => z.split(';'))
          .toList();
      final e = leseFragen(tabelle(rows));

      expect(e.fehlerhafte, isEmpty,
          reason: e.fehlerhafte.map((z) => z.fehler).join(' | '));
      expect(e.uebernehmbare, hasLength(2));
      expect(e.unbekannteSpalten, isEmpty);
    });

    test('ihr Mehrfachantwort-Beispiel hat wirklich zwei richtige', () {
      final rows = vorlageCsv()
          .trim()
          .split('\n')
          .map((z) => z.split(';'))
          .toList();
      final e = leseFragen(tabelle(rows));
      expect(e.uebernehmbare.last.frage!.richtige, hasLength(2));
    });
  });
}
