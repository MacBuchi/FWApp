/// crash_report_test.dart – Fingerprint und Kürzung der Absturzberichte
/// (Issue #34).
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/crash/crash_report.dart';

const _stackA = '''
#0      Foo.bar (package:flutter/src/widgets/framework.dart:4567:12)
#1      Baz.qux (package:fwapp/features/vehicle/vehicle_screen.dart:88:5)
#2      Deep.call (package:fwapp/core/sync/sync_service.dart:120:9)
#3      main (package:flutter/src/foundation/binding.dart:12:3)
''';

/// Gleicher Fehler, aber ein paar Zeilen verschoben und mit anderer Meldung.
const _stackAShifted = '''
#0      Foo.bar (package:flutter/src/widgets/framework.dart:9999:1)
#1      Baz.qux (package:fwapp/features/vehicle/vehicle_screen.dart:91:5)
#2      Deep.call (package:fwapp/core/sync/sync_service.dart:123:9)
#3      main (package:flutter/src/foundation/binding.dart:12:3)
''';

const _stackB = '''
#0      Other.thing (package:fwapp/features/game/quiz_screen.dart:12:1)
''';

void main() {
  group('crashFingerprint', () {
    test('ist stabil für denselben Fehler', () {
      expect(crashFingerprint('Bad state: x', _stackA),
          crashFingerprint('Bad state: x', _stackA));
    });

    test('ignoriert Zeilen-/Spaltennummern', () {
      // Eine verschobene Codezeile ist derselbe Absturz — sonst bekäme jeder
      // Release neue Fingerprints und die Dedupe liefe leer.
      expect(crashFingerprint('Bad state: x', _stackA),
          crashFingerprint('Bad state: x', _stackAShifted));
    });

    test('ignoriert die Fehlermeldung hinter dem Typ', () {
      // „Bad state: Foo 42" und „Bad state: Foo 43" sind derselbe Fall.
      expect(crashFingerprint('Bad state: Foo 42', _stackA),
          crashFingerprint('Bad state: Foo 43', _stackA));
    });

    test('unterscheidet verschiedene Fehlerstellen', () {
      expect(crashFingerprint('Bad state: x', _stackA),
          isNot(crashFingerprint('Bad state: x', _stackB)));
    });

    test('unterscheidet verschiedene Fehlertypen an gleicher Stelle', () {
      expect(crashFingerprint('Bad state: x', _stackA),
          isNot(crashFingerprint('RangeError: x', _stackA)));
    });

    test('kommt ohne eigene Frames aus', () {
      // Reiner Framework-Absturz: Dann trägt der Fehlertyp allein.
      final onlyFramework = crashFingerprint(
          'Bad state: x', '#0 f (package:flutter/src/a.dart:1:1)');
      expect(onlyFramework, isNotEmpty);
      expect(onlyFramework, crashFingerprint('Bad state: x', ''));
    });

    test('liefert einen 8-stelligen Hex-Wert (FNV-1a, 32 Bit)', () {
      // Nicht String.hashCode: der ist zwischen Läufen nicht stabil, und ein
      // persistierter Hash, der sich ändert, dedupliziert nichts mehr.
      final fp = crashFingerprint('Bad state: x', _stackA);
      expect(fp, matches(RegExp(r'^[0-9a-f]{8}$')));
    });

    test('ist für bekannte Eingaben unveraendert', () {
      // Festnagelung: Ändert sich dieser Wert, passen gespeicherte
      // Fingerprints nicht mehr zu neu berechneten.
      expect(crashFingerprint('', ''), _fnvOfEmpty);
    });
  });

  group('truncateStack', () {
    test('lässt kurze Stacktraces unangetastet', () {
      expect(truncateStack('kurz'), 'kurz');
    });

    test('kürzt lange und macht das sichtbar', () {
      final cut = truncateStack('x' * 100, max: 10);
      expect(cut, startsWith('x' * 10));
      expect(cut, contains('gekürzt'));
    });
  });
}

/// FNV-1a über den String „|" (leerer Typ, keine Frames).
const _fnvOfEmpty = 'f90c4a3b';
