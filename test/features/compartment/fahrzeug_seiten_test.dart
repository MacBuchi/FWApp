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
      expect(kFahrzeugSeiten,
          ['dach', 'front', 'fahrerseite', 'heck', 'beifahrerseite']);
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
        'G1', 'G2', 'G9', 'Geräteraum 4', 'Dach', 'Front', 'GR',
        'Fahrerseite', 'Beifahrerseite',
      ]) {
        final s = seiteAusName(name);
        expect(istGueltigeSeite(s), isTrue, reason: '$name → $s');
      }
    });
  });
}
