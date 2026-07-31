/// crop_render_test.dart – Transformation des Bildaufnahme-Editors (Issue #56).
///
/// Die Geste „zwei Finger drehen und zoomen, Rahmen ist der Zuschnitt" steht
/// und fällt mit dieser Mathematik: Anzeige und ausgeschnittenes Ergebnis
/// müssen dieselbe Abbildung benutzen, und der Punkt unter den Fingern muss
/// dort bleiben.
library;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/images/crop_render.dart';

/// Bildet einen Bildpunkt so ab, wie es der Painter zeichnet — die Umkehrung
/// dessen, was [imagePointAt] leistet.
Offset _project(Offset p, Offset center, Offset offset, double scale,
    double rotation) {
  final c = math.cos(rotation);
  final s = math.sin(rotation);
  return center +
      offset +
      Offset(
        scale * (p.dx * c - p.dy * s),
        scale * (p.dx * s + p.dy * c),
      );
}

void _expectNear(Offset actual, Offset expected, {double tolerance = 0.001}) {
  expect((actual.dx - expected.dx).abs(), lessThan(tolerance),
      reason: 'dx: $actual statt $expected');
  expect((actual.dy - expected.dy).abs(), lessThan(tolerance),
      reason: 'dy: $actual statt $expected');
}

void main() {
  const center = Offset(200, 150);

  group('imagePointAt', () {
    test('ist die Umkehrung der Projektion', () {
      const offset = Offset(30, -20);
      const scale = 1.7;
      final rotation = 0.4;
      const imagePoint = Offset(55, -12);

      final screen = _project(imagePoint, center, offset, scale, rotation);
      final back = imagePointAt(
        screenPoint: screen,
        center: center,
        offset: offset,
        scale: scale,
        rotation: rotation,
      );

      _expectNear(back, imagePoint);
    });

    test('die Rahmenmitte zeigt ohne Verschiebung auf die Bildmitte', () {
      final back = imagePointAt(
        screenPoint: center,
        center: center,
        offset: Offset.zero,
        scale: 2,
        rotation: 0,
      );
      _expectNear(back, Offset.zero);
    });
  });

  group('offsetForAnchor', () {
    test('hält den Bildpunkt beim Zoomen unter dem Finger', () {
      // Der eigentliche Anspruch der Geste: Ich fasse einen Punkt an und
      // zoome — der Punkt darf nicht wegwandern.
      const finger = Offset(260, 190);
      const imagePoint = Offset(40, 25);
      const newScale = 3.2;
      const rotation = 0.0;

      final offset = offsetForAnchor(
        imagePoint: imagePoint,
        screenPoint: finger,
        center: center,
        scale: newScale,
        rotation: rotation,
      );

      _expectNear(
          _project(imagePoint, center, offset, newScale, rotation), finger);
    });

    test('hält ihn auch beim gleichzeitigen Drehen', () {
      const finger = Offset(120, 210);
      const imagePoint = Offset(-30, 60);
      const newScale = 1.4;
      final rotation = -1.1;

      final offset = offsetForAnchor(
        imagePoint: imagePoint,
        screenPoint: finger,
        center: center,
        scale: newScale,
        rotation: rotation,
      );

      _expectNear(
          _project(imagePoint, center, offset, newScale, rotation), finger);
    });

    test('reines Verschieben verschiebt genau um die Fingerstrecke', () {
      // Ein-Finger-Ziehen: scale und rotation bleiben, der Fingerpunkt wandert.
      const imagePoint = Offset(10, 10);
      const scale = 2.0;
      const rotation = 0.0;
      const from = Offset(200, 150);
      const to = Offset(230, 170);

      final before = offsetForAnchor(
        imagePoint: imagePoint,
        screenPoint: from,
        center: center,
        scale: scale,
        rotation: rotation,
      );
      final after = offsetForAnchor(
        imagePoint: imagePoint,
        screenPoint: to,
        center: center,
        scale: scale,
        rotation: rotation,
      );

      _expectNear(after - before, to - from);
    });
  });

  group('cropOutputSize', () {
    test('behält das Seitenverhältnis des Rahmens', () {
      final out = cropOutputSize(const ui.Size(400, 300));
      expect(out.width / out.height, closeTo(4 / 3, 0.01));
    });

    test('deckelt die längste Seite', () {
      final out = cropOutputSize(const ui.Size(4000, 1000));
      expect(out.width, kCropRenderMaxDimension);
      expect(out.height, kCropRenderMaxDimension / 4);
    });

    test('deckelt auch bei hochkantem Rahmen die längste Seite', () {
      final out = cropOutputSize(const ui.Size(1000, 4000));
      expect(out.height, kCropRenderMaxDimension);
      expect(out.width, kCropRenderMaxDimension / 4);
    });

    test('skaliert kleine Rahmen nicht hoch', () {
      // Hochrechnen erfindet keine Bildinformation, kostet aber Speicher.
      final out = cropOutputSize(const ui.Size(300, 200));
      expect(out, const ui.Size(300, 200));
    });

    test('leerer Rahmen ergibt leere Zielgröße', () {
      expect(cropOutputSize(ui.Size.zero), ui.Size.zero);
    });
  });

  group('renderCrop', () {
    /// Einfarbiges Bild, an dem sich die ausgeschnittene Farbe ablesen lässt.
    Future<ui.Image> solid(int w, int h, Color color) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Paint()..color = color);
      final picture = recorder.endRecording();
      final image = await picture.toImage(w, h);
      picture.dispose();
      return image;
    }

    testWidgets('liefert ein Bild in der Zielgröße des Rahmens',
        (tester) async {
      // runAsync: toImage() ist echte GPU-/Engine-Arbeit und läuft nicht in
      // der simulierten Testzeit ab.
      await tester.runAsync(() async {
        final image = await solid(200, 200, const Color(0xFF3388CC));
        final bytes = await renderCrop(
          image: image,
          frameSize: const ui.Size(400, 300),
          offset: Offset.zero,
          scale: 4,
          rotation: 0,
        );
        image.dispose();

        final decoded = await decodeUiImage(bytes);
        expect(decoded.width, 400);
        expect(decoded.height, 300);
        decoded.dispose();
      });
    });

    testWidgets('schneidet den sichtbaren Ausschnitt aus, nicht das Original',
        (tester) async {
      await tester.runAsync(() async {
        final image = await solid(100, 100, const Color(0xFFFF0000));
        final bytes = await renderCrop(
          image: image,
          frameSize: const ui.Size(300, 300),
          offset: Offset.zero,
          // Deutlich hineingezoomt: Der Rahmen ist komplett von Bild bedeckt.
          scale: 6,
          rotation: 0.3,
        );
        image.dispose();

        final decoded = await decodeUiImage(bytes);
        final data = await decoded.toByteData();
        // Mitte muss die Bildfarbe tragen, nicht den schwarzen Grund.
        final middle = ((decoded.height ~/ 2) * decoded.width +
                decoded.width ~/ 2) *
            4;
        expect(data!.getUint8(middle), greaterThan(200), reason: 'Rot-Kanal');
        expect(data.getUint8(middle + 1), lessThan(60), reason: 'Grün-Kanal');
        decoded.dispose();
      });
    });

    testWidgets('weist einen Rahmen ohne Größe zurück', (tester) async {
      await tester.runAsync(() async {
        final image = await solid(10, 10, const Color(0xFF000000));
        await expectLater(
          renderCrop(
            image: image,
            frameSize: ui.Size.zero,
            offset: Offset.zero,
            scale: 1,
            rotation: 0,
          ),
          throwsStateError,
        );
        image.dispose();
      });
    });
  });
}
