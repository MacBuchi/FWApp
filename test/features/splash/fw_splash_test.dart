/// fw_splash_test.dart – Die Startanimation (Issue #129).
///
/// ⚠️ **Was dieser Test NICHT beweist:** wie es aussieht. Im Testlauf ist
/// keine Textschrift geladen, der Schriftzug erscheint als leere Kästchen.
/// Das Aussehen ist als Bild je Szene geprüft, hier geht es um die
/// Mechanik: Läuft die Zeit wirklich durch drei Szenen, und ändert sich
/// dabei das Bild?
///
/// Gerastert statt Werte abgefragt, aus demselben Grund wie beim Avatar: Ein
/// Painter kann jede Zahl entgegennehmen und nichts damit tun.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/splash/presentation/widgets/fw_splash.dart';

const _w = 216, _h = 384;

Future<String> _bild({required double t, bool voll = true}) async {
  final recorder = ui.PictureRecorder();
  SplashPainter(fortschritt: t, voll: voll)
      .paint(Canvas(recorder), const Size(216, 384));
  final bild = await recorder.endRecording().toImage(_w, _h);
  final daten = await bild.toByteData(format: ui.ImageByteFormat.rawRgba);
  bild.dispose();
  return daten!.buffer
      .asUint8List()
      .fold<int>(17, (h, b) => (h * 31 + b) & 0x7FFFFFFF)
      .toString();
}

/// Mitte der jeweiligen Szene, ausgedrückt im Gesamtfortschritt.
double _mitte(int vorherMs, int dauerMs) =>
    (vorherMs + dauerMs / 2) / kSplashVollMs;

void main() {
  test('die Szenendauern bleiben, was sie waren', () {
    // 1,2 s + 1,3 s + 1,8 s = 4,3 s. Der Inhalt der Szenen ist mit #175 neu,
    // ihre Länge nicht — ändert sie jemand versehentlich, fällt es hier auf
    // und nicht erst im Feld.
    expect(kFachMs, 1200);
    expect(kPruefenMs, 1300);
    expect(kZeichenMs, 1800);
    expect(kSplashVollMs, 4300);
    // Die Kurzform muss deutlich kürzer sein als eine einzelne Szene,
    // sonst ist sie keine.
    expect(kSplashKurzMs, lessThan(kZeichenMs));
  });

  test('derselbe Zeitpunkt ergibt zweimal dasselbe Bild', () async {
    expect(await _bild(t: 0.3), await _bild(t: 0.3));
  });

  test('die Bühne ist nicht leer', () async {
    final leer = await () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder);
      final bild = await recorder.endRecording().toImage(_w, _h);
      final daten = await bild.toByteData(format: ui.ImageByteFormat.rawRgba);
      bild.dispose();
      return daten!.buffer
          .asUint8List()
          .fold<int>(17, (h, b) => (h * 31 + b) & 0x7FFFFFFF)
          .toString();
    }();
    expect(await _bild(t: 0.5), isNot(leer));
  });

  test('die drei Szenen sehen verschieden aus', () async {
    final flamme = await _bild(t: _mitte(0, kFachMs));
    final loeschen = await _bild(t: _mitte(kFachMs, kPruefenMs));
    final logo = await _bild(t: _mitte(kFachMs + kPruefenMs, kZeichenMs));
    expect({flamme, loeschen, logo}, hasLength(3));
  });

  test('innerhalb jeder Szene bewegt sich etwas', () async {
    // Sonst wäre eine Szene ein Standbild mit Wartezeit.
    for (final (name, a, b) in <(String, double, double)>[
      ('Fach', 0.02, 0.2),
      ('Prüfen', 0.32, 0.5),
      ('Zeichen', 0.62, 0.85),
    ]) {
      expect(await _bild(t: a), isNot(await _bild(t: b)), reason: name);
    }
  });

  test('die Kurzform beginnt mit dem Zeichen, nicht mit dem Fach', () async {
    // Der Unterschied, an dem die ganze Entscheidung „voll oder kurz" hängt.
    final kurzAnfang = await _bild(t: 0.05, voll: false);
    final vollAnfang = await _bild(t: 0.05, voll: true);
    expect(kurzAnfang, isNot(vollAnfang));

    // Und sie zeigt dasselbe wie die Zeichen-Szene der vollen Fassung an
    // der entsprechenden Stelle.
    final kurzMitte = await _bild(t: 0.5, voll: false);
    final vollLogoMitte =
        await _bild(t: (kFachMs + kPruefenMs + kZeichenMs / 2) / kSplashVollMs);
    expect(kurzMitte, vollLogoMitte);
  });

  test('am Ende steht die fertige Zeichen-Szene', () async {
    expect(await _bild(t: 1.0), await _bild(t: 1.0, voll: false));
  });
}
