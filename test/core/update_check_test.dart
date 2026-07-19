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

    test('Nicht-Zahlen werden als 0 gewertet statt zu crashen', () {
      expect(isNewerVersion('1.abc.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.1.0', '1.x.5'), isTrue);
    });
  });
}
