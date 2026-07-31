/// log_ring_test.dart – Der Log-Ring-Buffer, dessen Zeilen im Absturzbericht
/// landen (Issue #34).
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/logging/app_logger.dart';

void main() {
  late LogRingBuffer ring;

  setUp(() => ring = LogRingBuffer());

  test('hält die letzten Zeilen, älteste zuerst', () {
    ring
      ..add('eins')
      ..add('zwei')
      ..add('drei');
    expect(ring.lines, ['eins', 'zwei', 'drei']);
  });

  test('kappt bei der Ringgröße und verwirft die ältesten', () {
    for (var i = 1; i <= kLogRingSize + 10; i++) {
      ring.add('Zeile $i');
    }
    expect(ring.lines, hasLength(kLogRingSize));
    expect(ring.lines.first, 'Zeile 11');
    expect(ring.lines.last, 'Zeile ${kLogRingSize + 10}');
  });

  test('kürzt überlange Zeilen', () {
    // Sonst belegt ein hineingereichter Serverfehler den halben Ring und
    // verdrängt die Vorgeschichte, um die es geht.
    ring.add('x' * (kLogRingMaxLineChars + 200));
    expect(ring.lines.single.length, lessThanOrEqualTo(kLogRingMaxLineChars + 1));
    expect(ring.lines.single, endsWith('…'));
  });

  test('wirft den Rahmen des PrettyPrinters weg', () {
    // Auf dem Emulator nachgemessen: Ungefiltert belegt eine einzige Meldung
    // drei Ringplätze, und der Bericht trüge statt 50 Meldungen knapp 17.
    ring
      ..add('┌────────────────────────────')
      ..add('│ 💡 kurz vor dem Absturz')
      ..add('└────────────────────────────');
    expect(ring.lines, ['💡 kurz vor dem Absturz']);
  });

  test('verwirft leere Zeilen und reine Strichzeilen', () {
    ring
      ..add('')
      ..add('   ')
      ..add('├┄┄┄┄┄┄┄┄┄┄┄')
      ..add('echte Meldung');
    expect(ring.lines, ['echte Meldung']);
  });

  test('clear() leert den Ring', () {
    ring.add('etwas');
    ring.clear();
    expect(ring.lines, isEmpty);
  });

  test('lines ist unveränderlich', () {
    // Der Bericht bekommt die Liste durchgereicht; ein Aufrufer darf den
    // Ring darüber nicht verändern können.
    ring.add('etwas');
    expect(() => ring.lines.add('geht nicht'), throwsUnsupportedError);
  });
}
