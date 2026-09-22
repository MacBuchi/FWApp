/// tag_code_test.dart – Codes für Geräte-Tags (Issues #177/#179).
///
/// Geprüft wird das, was beim Scannen still danebengeht: derselbe Aufkleber
/// in zwei Schreibweisen, ein Zeilenende vom Lesegerät, ein Code, der auf
/// alles passt — und die Kollision, die sonst niemand herstellt.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/inventory/data/tag_code.dart';

/// Liefert die vorgegebenen Indizes der Reihe nach — damit der Test
/// bestimmt, welcher Code als nächstes fällt.
class _GestellterZufall implements Random {
  final List<int> werte;
  int _i = 0;
  _GestellterZufall(this.werte);

  @override
  int nextInt(int max) => werte[_i++ % werte.length] % max;

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  group('normalisiereTagCode', () {
    test('macht aus zwei Schreibweisen denselben Code', () {
      expect(
        normalisiereTagCode('fw-7k2m9q'),
        normalisiereTagCode('FW-7K2M9Q'),
      );
    });

    test('wirft Leerraum weg, auch das Zeilenende vom Lesegerät', () {
      expect(normalisiereTagCode('  FW-7K2M9Q\n'), 'FW-7K2M9Q');
      expect(normalisiereTagCode('\tFW-7K2M9Q\r\n'), 'FW-7K2M9Q');
    });

    test('auch Leerraum MITTEN im Code fällt weg', () {
      // Handscanner streuen ihn an Trennstellen ein.
      expect(normalisiereTagCode('FW- 7K2 M9Q'), 'FW-7K2M9Q');
    });

    test('nur Leerraum ist kein Code', () {
      // Sonst entstünde ein Tag mit leerem Schlüssel, der auf alles passt.
      expect(normalisiereTagCode('   '), isNull);
      expect(normalisiereTagCode(''), isNull);
      expect(normalisiereTagCode('\n'), isNull);
    });

    test('lässt einen fremden Hersteller-Barcode unangetastet', () {
      expect(normalisiereTagCode('4006381333931'), '4006381333931');
    });
  });

  group('erzeugeTagCode', () {
    test('trägt den Vorsatz und hat die erwartete Länge', () {
      final code = erzeugeTagCode(const {});
      expect(code, startsWith(kTagPrefix));
      expect(code.length, kTagPrefix.length + 7);
    });

    test('benutzt keine verwechselbaren Zeichen', () {
      // 0/O und 1/I/L entscheiden darüber, ob ein abgetippter Code trifft.
      for (var i = 0; i < 200; i++) {
        final rumpf = erzeugeTagCode(const {}).substring(kTagPrefix.length);
        expect(rumpf, isNot(matches(RegExp('[ILOU]'))));
      }
    });

    test('ist bereits normalisiert', () {
      final code = erzeugeTagCode(const {});
      expect(normalisiereTagCode(code), code);
    });

    test('weicht einem schon vergebenen Code aus', () {
      // Erster Griff liefert lauter Index 0 → „FW-0000000"; der ist belegt,
      // der zweite Griff muss etwas anderes bringen.
      final zufall = _GestellterZufall([
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
      ]);
      final code = erzeugeTagCode({'FW-0000000'}, zufall: zufall);
      expect(code, isNot('FW-0000000'));
      expect(code, 'FW-1111111');
    });

    test('scheitert laut, statt ewig zu würfeln', () {
      // Ein Zufall, der immer dasselbe liefert, und dieser Code ist belegt:
      // Das ist kein Pech, sondern ein Defekt — also sichtbar abbrechen.
      expect(
        () => erzeugeTagCode({
          'FW-0000000',
        }, zufall: _GestellterZufall(const [0])),
        throwsStateError,
      );
    });
  });

  group('istEigenerCode', () {
    test('unterscheidet vergeben von fremd', () {
      expect(istEigenerCode('FW-7K2M9Q'), isTrue);
      expect(istEigenerCode('4006381333931'), isFalse);
    });
  });
}
