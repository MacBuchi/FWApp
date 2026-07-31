/// image_processing_test.dart – Bildverarbeitung der Bildaufnahme (Issue #56):
/// Verkleinern aufs Auslieferungsbudget und Drehen.
///
/// Die Kompressionsfälle standen bis v1.5.0 in image_sync_service_test.dart;
/// sie sind mit der Funktion hierher gewandert, damit Test und Code
/// beieinander liegen.
library;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/images/image_processing.dart';
import 'package:image/image.dart' as img;

/// Noise compresses worst-case — if this fits the budget, real photos do too.
Uint8List _noiseImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  var seed = 42;
  for (final pixel in image) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    pixel.setRgb(seed & 0xff, (seed >> 8) & 0xff, (seed >> 16) & 0xff);
  }
  return img.encodePng(image);
}

/// Einfarbiges Bild mit einer andersfarbigen Ecke oben links — daran lässt
/// sich die Drehrichtung eindeutig ablesen.
Uint8List _markedImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));
  img.fillRect(image,
      x1: 0,
      y1: 0,
      x2: (width ~/ 4) - 1,
      y2: (height ~/ 4) - 1,
      color: img.ColorRgb8(255, 0, 0));
  return img.encodePng(image);
}

bool _isRedish(img.Pixel p) => p.r > 200 && p.g < 80 && p.b < 80;

void main() {
  group('compressImageForUpload', () {
    test('shrinks a large noisy image below the size and dimension budget',
        () {
      final result = compressImageForUpload(_noiseImage(2400, 1600));

      expect(result.length, lessThanOrEqualTo(kMaxImageBytes));
      final decoded = img.decodeJpg(result)!;
      expect(decoded.width, lessThanOrEqualTo(kMaxImageDimension));
      expect(decoded.height, lessThanOrEqualTo(kMaxImageDimension));
      // Aspect ratio preserved (2400:1600 = 3:2).
      expect((decoded.width / decoded.height - 1.5).abs(), lessThan(0.01));
    });

    test('keeps small images at their dimensions', () {
      final result = compressImageForUpload(_noiseImage(200, 150));

      final decoded = img.decodeJpg(result)!;
      expect(decoded.width, 200);
      expect(decoded.height, 150);
      expect(result.length, lessThanOrEqualTo(kMaxImageBytes));
    });

    test('portrait orientation uses the height as the longest side', () {
      final result = compressImageForUpload(_noiseImage(1200, 2400));

      final decoded = img.decodeJpg(result)!;
      expect(decoded.height, kMaxImageDimension);
      expect(decoded.width, kMaxImageDimension ~/ 2);
    });

    test('rejects data that is not an image', () {
      expect(() => compressImageForUpload(Uint8List.fromList([1, 2, 3])),
          throwsFormatException);
    });
  });

  group('rotateImageBytes', () {
    test('dreht um 90° im Uhrzeigersinn und tauscht dabei die Seiten', () {
      final rotated = rotateImageBytes(_markedImage(400, 200), 1);
      final decoded = img.decodeJpg(rotated)!;

      expect(decoded.width, 200, reason: 'aus 400 breit wird 200 breit');
      expect(decoded.height, 400);

      // Die rote Ecke war oben links und muss nach einer Rechtsdrehung
      // oben rechts liegen.
      expect(_isRedish(decoded.getPixel(decoded.width - 5, 5)), isTrue);
      expect(_isRedish(decoded.getPixel(5, 5)), isFalse);
    });

    test('vier Drehungen führen zurück zum Ausgangsformat', () {
      var bytes = _markedImage(400, 200);
      for (var i = 0; i < 4; i++) {
        bytes = rotateImageBytes(bytes, 1);
      }
      final decoded = img.decodeJpg(bytes)!;
      expect(decoded.width, 400);
      expect(decoded.height, 200);
      expect(_isRedish(decoded.getPixel(5, 5)), isTrue);
    });

    test('0 Vierteldrehungen lassen die Ausrichtung unverändert', () {
      final decoded =
          img.decodeJpg(rotateImageBytes(_markedImage(400, 200), 0))!;
      expect(decoded.width, 400);
      expect(decoded.height, 200);
      expect(_isRedish(decoded.getPixel(5, 5)), isTrue);
    });

    test('normalisiert Werte außerhalb von 0..3', () {
      // 5 Vierteldrehungen == 1, und -1 == 3.
      final five = img.decodeJpg(rotateImageBytes(_markedImage(400, 200), 5))!;
      expect(five.width, 200);
      expect(five.height, 400);

      final minusOne =
          img.decodeJpg(rotateImageBytes(_markedImage(400, 200), -1))!;
      expect(minusOne.width, 200);
      // -1 % 4 ist in Dart 3, also eine Linksdrehung: rote Ecke unten links.
      expect(_isRedish(minusOne.getPixel(5, minusOne.height - 5)), isTrue);
    });

    test('verkleinert beim Drehen nicht', () {
      // Wichtig: Zwischen zwei Editor-Schritten darf keine Auflösung
      // verloren gehen — verkleinert wird erst einmal ganz am Schluss.
      final decoded =
          img.decodeJpg(rotateImageBytes(_noiseImage(2400, 1600), 1))!;
      expect(decoded.width, 1600);
      expect(decoded.height, 2400);
    });

    test('meldet unlesbare Daten statt still ein leeres Bild zu liefern', () {
      expect(() => rotateImageBytes(Uint8List.fromList([9, 9, 9]), 1),
          throwsFormatException);
    });
  });
}
