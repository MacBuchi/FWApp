/// leistungsabzeichen_test.dart – Die Regel hinter dem Abzeichen (#135).
///
/// Geprüft wird nicht, dass „ein Abzeichen erscheint", sondern die drei
/// Zusagen, die man später brechen könnte, ohne es zu merken: die Schwellen
/// selbst, dass eine erreichte Stufe **nie wieder verschwindet**, und dass
/// die Reihenfolge der Aufzählung mit den Schwellen zusammenpasst — davon
/// hängt [abzeichenFuerLevel] ab.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/profil/domain/leistungsabzeichen.dart';

void main() {
  group('die Schwellen', () {
    test('unter Bronze hängt gar nichts am Kopf', () {
      expect(abzeichenFuerLevel(1), isNull);
      expect(abzeichenFuerLevel(2), isNull);
    });

    test('jede Stufe beginnt genau an ihrem Level', () {
      // Die Grenze selbst, nicht irgendwo dahinter: Ein „>" statt „>="
      // verschöbe jede Stufe um ein volles Level, ohne sonst aufzufallen.
      expect(abzeichenFuerLevel(3), Leistungsabzeichen.bronze);
      expect(abzeichenFuerLevel(7), Leistungsabzeichen.bronze);
      expect(abzeichenFuerLevel(8), Leistungsabzeichen.silber);
      expect(abzeichenFuerLevel(14), Leistungsabzeichen.silber);
      expect(abzeichenFuerLevel(15), Leistungsabzeichen.gold);
    });

    test('über Gold hinaus bleibt es Gold', () {
      expect(abzeichenFuerLevel(99), Leistungsabzeichen.gold);
    });

    test('die Aufzählung steht in derselben Reihenfolge wie die Schwellen',
        () {
      // [abzeichenFuerLevel] läuft die Aufzählung durch und behält die
      // letzte passende Stufe. Stünde Gold vor Bronze, käme bei Level 20
      // Bronze heraus — und niemand käme auf die Idee, danach zu suchen.
      final schwellen =
          Leistungsabzeichen.values.map((s) => kAbzeichenAbLevel[s]!).toList();
      for (var i = 1; i < schwellen.length; i++) {
        expect(schwellen[i], greaterThan(schwellen[i - 1]));
      }
    });

    test('jede Stufe hat Name und Farbe', () {
      for (final stufe in Leistungsabzeichen.values) {
        expect(kAbzeichenNamen[stufe], isNotNull, reason: '$stufe');
        expect(kAbzeichenFarben[stufe], isNotNull, reason: '$stufe');
        expect(kAbzeichenAbLevel[stufe], isNotNull, reason: '$stufe');
      }
    });
  });

  test('einmal verliehen bleibt verliehen', () {
    // Die Zusage aus dem Issue: Ein Abzeichen, das nach zwei ruhigen Wochen
    // wieder weg ist, bestraft genau den, der zurückkommt. Steigt das Level,
    // darf die Stufe nie kleiner werden.
    Leistungsabzeichen? vorher;
    for (var level = 1; level <= 40; level++) {
      final jetzt = abzeichenFuerLevel(level);
      if (vorher != null) {
        expect(jetzt, isNotNull, reason: 'Level $level verlor die Stufe');
        expect(jetzt!.index, greaterThanOrEqualTo(vorher.index),
            reason: 'Level $level fiel zurück');
      }
      vorher = jetzt;
    }
  });

  group('die nächste Stufe', () {
    test('zeigt von unten nach oben auf die jeweils nächste', () {
      expect(naechsteStufe(1)?.stufe, Leistungsabzeichen.bronze);
      expect(naechsteStufe(3)?.stufe, Leistungsabzeichen.silber);
      expect(naechsteStufe(8)?.stufe, Leistungsabzeichen.gold);
    });

    test('ist ab Gold leer statt „noch 0 Level"', () {
      expect(naechsteStufe(15), isNull);
      expect(naechsteStufe(100), isNull);
    });

    test('nennt das Level, ab dem sie hängt', () {
      expect(naechsteStufe(1)?.abLevel,
          kAbzeichenAbLevel[Leistungsabzeichen.bronze]);
    });
  });

  group('der Fortschrittssatz', () {
    test('zählt die fehlenden Level', () {
      expect(abzeichenFortschrittText(1), 'Noch 2 Level bis Bronze.');
      expect(abzeichenFortschrittText(4), 'Noch 4 Level bis Silber.');
    });

    test('sagt bei einem fehlenden Level nicht „1 Level"', () {
      expect(abzeichenFortschrittText(2), 'Noch ein Level bis Bronze.');
      expect(abzeichenFortschrittText(7), 'Noch ein Level bis Silber.');
    });

    test('kennt das Ende', () {
      expect(abzeichenFortschrittText(15), 'Höchste Stufe erreicht.');
    });
  });
}
