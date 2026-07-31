/// update_check_test.dart – Versionsvergleich des Update-Checks.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/update/update_check.dart';

void main() {
  group('isNewerVersion', () {
    test('gleiche Version ist kein Update', () {
      expect(isNewerVersion('1.3.1', '1.3.1'), isFalse);
    });

    test('Patch/Minor/Major werden numerisch verglichen', () {
      expect(isNewerVersion('1.3.2', '1.3.1'), isTrue);
      expect(isNewerVersion('1.4.0', '1.3.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      // 1.10.0 > 1.9.2 — kein String-Vergleich!
      expect(isNewerVersion('1.10.0', '1.9.2'), isTrue);
    });

    test('ältere oder gleiche Versionen sind kein Update', () {
      expect(isNewerVersion('1.3.0', '1.3.1'), isFalse);
      expect(isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('fehlende Segmente zählen als 0', () {
      expect(isNewerVersion('1.4', '1.3.9'), isTrue);
      expect(isNewerVersion('1.3', '1.3.0'), isFalse);
      expect(isNewerVersion('2', '1.9.9'), isTrue);
    });

    test('unlesbare Versionen bieten kein Update an', () {
      // Verschärft mit Issue #35: Vorher wurde jedes nicht-numerische Segment
      // still zu 0, `1.x.5` also zu `1.0.5` — eine erfundene, *kleinere*
      // Version. Für den Update-Hinweis war das folgenlos, aber dieselbe
      // Vergleichsfunktion trägt jetzt das Mindestversions-Gate, und dort
      // wäre Raten die falsche Antwort. Unlesbar heisst nun: kein Update.
      expect(isNewerVersion('1.abc.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.1.0', '1.x.5'), isFalse);
      expect(isNewerVersion('', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', 'unsinn'), isFalse);
    });
  });

  group('parseVersion', () {
    test('liest MAJOR.MINOR.PATCH', () {
      expect(parseVersion('1.4.9'), [1, 4, 9]);
      expect(parseVersion('10.20.30'), [10, 20, 30]);
    });

    test('füllt fehlende Segmente mit 0 auf', () {
      expect(parseVersion('1.4'), [1, 4, 0]);
      expect(parseVersion('2'), [2, 0, 0]);
    });

    test('ignoriert Build-Metadaten und führendes v', () {
      // `1.4.9+17` steht so in pubspec.yaml, `v1.4.9` ist das Release-Tag.
      expect(parseVersion('1.4.9+17'), [1, 4, 9]);
      expect(parseVersion('v1.4.9'), [1, 4, 9]);
      expect(parseVersion('V1.4.9+17'), [1, 4, 9]);
    });

    test('schneidet Pre-Release-Suffixe ab, statt sie zu verrechnen', () {
      // Der eigentliche Fehler aus der Analyse zu #35: `1.5.1-rc1` wurde zu
      // [1, 5, 0] — also *kleiner* als 1.5.1 statt gleichrangig.
      expect(parseVersion('1.5.1-rc1'), [1, 5, 1]);
      expect(parseVersion('1.5.1-beta.2+9'), [1, 5, 1]);
    });

    test('liefert null für alles, was keine Version ist', () {
      expect(parseVersion('unsinn'), isNull);
      expect(parseVersion('1.x.5'), isNull);
      expect(parseVersion(''), isNull);
      expect(parseVersion('1.2.3.4'), isNull);
      expect(parseVersion('-1.0.0'), isNull);
    });
  });
}
