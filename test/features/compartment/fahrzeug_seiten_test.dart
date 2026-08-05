/// fahrzeug_seiten_test.dart – Die Fahrzeugseite eines Fachs (Issue #126).
///
/// Zwei Dinge stehen hier zur Prüfung: die Reihenfolge des Aufklappbilds
/// (sie muss einmal um das Fahrzeug herumgehen, sonst findet niemand ein
/// Fach wieder) und der Namensvorschlag — ausdrücklich ein Vorschlag, aber
/// einer, der nicht danebenliegen darf, wo er etwas sagt.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';

void main() {
  group('die Bereiche', () {
    test('gehen einmal um das Fahrzeug herum', () {
      // Dach oben, dann vorne herum über die Fahrerseite nach hinten und
      // auf der Beifahrerseite zurück. Wer diese Reihenfolge ändert, ändert
      // das Bild, das die Mannschaft im Kopf hat.
      expect(kFahrzeugSeiten, [
        'dach',
        'front',
        'fahrerseite',
        'heck',
        'beifahrerseite',
      ]);
    });

    test('jede Seite hat eine deutsche Beschriftung', () {
      for (final s in kFahrzeugSeiten) {
        expect(kFahrzeugSeitenLabels[s], isNotNull, reason: s);
        expect(seiteAnzeigename(s), isNot('Ohne Seite'), reason: s);
      }
      expect(seiteAnzeigename(null), 'Ohne Seite');
      expect(seiteAnzeigename('raumschiff'), 'Ohne Seite');
    });

    test('gültig ist genau, was auch der Server annimmt', () {
      // Zwilling zum CHECK in 20260804180000_fach_seiten.sql.
      for (final s in kFahrzeugSeiten) {
        expect(istGueltigeSeite(s), isTrue, reason: s);
      }
      expect(istGueltigeSeite(null), isTrue);
      expect(istGueltigeSeite('links'), isFalse);
      expect(istGueltigeSeite(''), isFalse);
    });
  });

  group('der Vorschlag aus dem Namen', () {
    test('ungerade Geräteräume links, gerade rechts', () {
      expect(seiteAusName('G1'), 'fahrerseite');
      expect(seiteAusName('G3'), 'fahrerseite');
      expect(seiteAusName('G7'), 'fahrerseite');
      expect(seiteAusName('G2'), 'beifahrerseite');
      expect(seiteAusName('G4'), 'beifahrerseite');
      expect(seiteAusName('G8'), 'beifahrerseite');
    });

    test('auch ausgeschrieben und mit Leerzeichen', () {
      expect(seiteAusName('Geräteraum 1'), 'fahrerseite');
      expect(seiteAusName('G 2'), 'beifahrerseite');
      expect(seiteAusName('  g5  '), 'fahrerseite');
    });

    test('Dach, Front und Heck werden am Wort erkannt', () {
      expect(seiteAusName('Dachkasten'), 'dach');
      expect(seiteAusName('Dach'), 'dach');
      expect(seiteAusName('Frontfach'), 'front');
      expect(seiteAusName('Heck'), 'heck');
      expect(seiteAusName('GR'), 'heck');
      expect(seiteAusName('GR hinten'), 'heck');
    });

    test('„Beifahrerseite" wird nicht zur Fahrerseite', () {
      // Die Falle: „beifahrerseite" ENTHÄLT „fahrerseite". Wer nur auf die
      // kürzere Form prüft, schickt die halbe Mannschaft auf die falsche
      // Seite des Fahrzeugs.
      expect(seiteAusName('Beifahrerseite vorn'), 'beifahrerseite');
      expect(seiteAusName('Fahrerseite vorn'), 'fahrerseite');
    });

    test('das Wort schlägt die Nummer', () {
      // „G2 im Dachkasten" ist ein Dachfach, keine Beifahrerseite.
      expect(seiteAusName('G2 Dachkasten'), 'dach');
      expect(seiteAusName('Heck G1'), 'heck');
    });

    test('ohne Anhaltspunkt gibt es KEINEN Vorschlag', () {
      // Lieber nichts als geraten: Eine falsch gesetzte Seite ist im
      // Einsatz ein Griff ins falsche Fach.
      expect(seiteAusName('Mannschaftsraum'), isNull);
      expect(seiteAusName('Ablage'), isNull);
      expect(seiteAusName(''), isNull);
      expect(seiteAusName('   '), isNull);
      expect(seiteAusName('42'), isNull);
    });

    test('Wörter mit „gr" im Inneren gelten nicht als Heck', () {
      // „Grombach" und „Gruppe" enthalten „gr" — als ganzes Wort gemeint war
      // aber der Geräteraum hinten.
      expect(seiteAusName('Gruppenfach'), isNull);
      expect(seiteAusName('Grombach'), isNull);
    });

    test('jeder Vorschlag ist ein Wert, den der Server annimmt', () {
      for (final name in const [
        'G1',
        'G2',
        'G9',
        'Geräteraum 4',
        'Dach',
        'Front',
        'GR',
        'Fahrerseite',
        'Beifahrerseite',
      ]) {
        final s = seiteAusName(name);
        expect(istGueltigeSeite(s), isTrue, reason: '$name → $s');
      }
    });
  });

  group('die Längsposition (Issue #141)', () {
    test('geht von vorne nach hinten', () {
      // Die Reihenfolge ist die Fahrtrichtung — dieselbe Achse, die die
      // Draufsicht von oben nach unten zeigt.
      expect(kLaengspositionen, ['vorne', 'mitte', 'hinten']);
    });

    test('gültig ist genau, was auch der Server annimmt', () {
      // Zwilling zum CHECK in 20260805090000_fach_laengsposition.sql.
      for (final p in kLaengspositionen) {
        expect(istGueltigeLaengsposition(p), isTrue, reason: p);
        expect(laengspositionAnzeigename(p), isNotNull, reason: p);
      }
      expect(istGueltigeLaengsposition(null), isTrue);
      expect(istGueltigeLaengsposition('achtern'), isFalse);
      expect(istGueltigeLaengsposition(''), isFalse);
    });

    test('die Verortung spricht überall dieselbe Sprache', () {
      expect(
        verortungAnzeigename('fahrerseite', 'vorne'),
        'Fahrerseite · vorne',
      );
      expect(
        verortungAnzeigename('fahrerseite', 'mitte'),
        'Fahrerseite · Mitte',
      );
      expect(verortungAnzeigename('heck', null), 'Heck');
      expect(verortungAnzeigename(null, null), 'Ohne Seite');
    });
  });

  group('der Positions-Vorschlag aus dem Namen', () {
    test('setzt die Nummern-Konvention fort: G1/G2 vorne, G3/G4 Mitte, '
        'G5/G6 hinten', () {
      expect(laengspositionAusName('G1'), 'vorne');
      expect(laengspositionAusName('G2'), 'vorne');
      expect(laengspositionAusName('G3'), 'mitte');
      expect(laengspositionAusName('G4'), 'mitte');
      expect(laengspositionAusName('G5'), 'hinten');
      expect(laengspositionAusName('G6'), 'hinten');
      expect(laengspositionAusName('Geräteraum 3'), 'mitte');
    });

    test('ab G7 sagt die Nummer nichts mehr', () {
      // Lieber kein Vorschlag als ein falscher: Bei mehr als drei Fächern
      // je Seite trägt die Drittel-Regel nicht mehr.
      expect(laengspositionAusName('G7'), isNull);
      expect(laengspositionAusName('G8'), isNull);
    });

    test('das Wort schlägt die Nummer', () {
      expect(laengspositionAusName('G1 hinten'), 'hinten');
      expect(laengspositionAusName('Fahrerseite vorn'), 'vorne');
      expect(laengspositionAusName('Beifahrerseite Mitte'), 'mitte');
    });

    test('abseits der Längsseiten gibt es KEINEN Vorschlag', () {
      // Ein Heckfach IST hinten, ein Dachkasten oben — dort wäre eine
      // Position keine Information, sondern Rauschen.
      expect(laengspositionAusName('GR'), isNull);
      expect(laengspositionAusName('GR hinten'), isNull);
      expect(laengspositionAusName('Dachkasten vorne'), isNull);
      expect(laengspositionAusName('G2 Dachkasten'), isNull);
      expect(laengspositionAusName('Frontfach'), isNull);
      expect(laengspositionAusName('Mannschaftsraum'), isNull);
      expect(laengspositionAusName(''), isNull);
    });

    test('jeder Vorschlag ist ein Wert, den der Server annimmt', () {
      for (final name in const [
        'G1',
        'G2',
        'G3',
        'G4',
        'G5',
        'G6',
        'G7',
        'G1 hinten',
        'Beifahrerseite Mitte',
        'GR',
        'Dach',
      ]) {
        final p = laengspositionAusName(name);
        expect(istGueltigeLaengsposition(p), isTrue, reason: '$name → $p');
      }
    });
  });
}
