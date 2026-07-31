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

  group('bakeOrientationBytes', () {
    test('liefert wieder dekodierbare JPEG-Bytes gleicher Groesse', () {
      final out = bakeOrientationBytes(_markedImage(400, 200));
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 400);
      expect(decoded.height, 200);
      // Die markierte Ecke bleibt oben links — ohne EXIF wird nicht gedreht.
      expect(_isRedish(decoded.getPixel(5, 5)), isTrue);
    });

    test('verkleinert nicht', () {
      // Wichtig: Das Bild geht anschliessend in den Editor. Verkleinert wird
      // erst ganz am Schluss, sonst fehlt dort Aufloesung zum Zuschneiden.
      final decoded =
          img.decodeJpg(bakeOrientationBytes(_noiseImage(2400, 1600)))!;
      expect(decoded.width, 2400);
      expect(decoded.height, 1600);
    });

    test('meldet unlesbare Daten statt still ein leeres Bild zu liefern', () {
      expect(() => bakeOrientationBytes(Uint8List.fromList([9, 9, 9])),
          throwsFormatException);
    });
  });
}
