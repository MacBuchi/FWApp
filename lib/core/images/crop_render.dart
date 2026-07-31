/// crop_render.dart – Die Transformation des Bildaufnahme-Editors (Issue #56)
/// und das Ausschneiden des sichtbaren Rahmeninhalts.
///
/// Anzeige und Ausgabe benutzen **dieselbe** Abbildung, nur mit
/// unterschiedlichem Maßstab. Deshalb steht sie genau einmal hier
/// ([applyImageTransform]) — liefe die Ausgabe über eine zweite, nachgebaute
/// Rechnung, wäre das Ergebnis früher oder später ein anderes als das, was
/// die Nutzerin im Rahmen gesehen hat.
///
/// Die Abbildung eines Bildpunkts p (Ursprung = Bildmitte):
///
///     p_screen = rahmenMitte + offset + R(rotation) · S(scale) · p
///
/// Für die Ausgabe wird der Rahmen auf die Zielfläche gelegt. Mit
/// k = zielBreite / rahmenBreite gilt:
///
///     p_out = zielMitte + k·offset + R(rotation) · S(k·scale) · p
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Längste Seite des ausgeschnittenen Bildes vor dem endgültigen Verkleinern.
///
/// Bewusst über dem Auslieferungsbudget: Der Zuschnitt ist die letzte Stelle
/// mit voller Auflösung, und [compressImageForUpload] rechnet danach ohnehin
/// auf 1024 px herunter. Zu knapp gerendert ließe sich das nicht nachholen.
const kCropRenderMaxDimension = 1600;

/// Setzt die Bild-Transformation auf [canvas] — geteilt von Anzeige und
/// Ausgabe. [center] ist die Rahmenmitte im jeweiligen Koordinatensystem,
/// [zoom] der bereits mit dem Maßstab verrechnete Skalierungsfaktor.
///
/// Danach wird das Bild mit seiner Mitte im Ursprung gezeichnet.
void applyImageTransform(
  ui.Canvas canvas,
  Offset center,
  Offset offset,
  double zoom,
  double rotation,
) {
  canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
  canvas.rotate(rotation);
  canvas.scale(zoom);
}

/// Wendet Drehung und Skalierung auf einen Bildpunkt an (ohne Verschiebung).
Offset _rotateScale(Offset p, double scale, double rotation) {
  final c = math.cos(rotation);
  final s = math.sin(rotation);
  return Offset(
    scale * (p.dx * c - p.dy * s),
    scale * (p.dx * s + p.dy * c),
  );
}

/// Welcher Bildpunkt liegt gerade unter [screenPoint]? Umkehrung der
/// Abbildung im Dateikopf.
Offset imagePointAt({
  required Offset screenPoint,
  required Offset center,
  required Offset offset,
  required double scale,
  required double rotation,
}) =>
    _rotateScale(screenPoint - center - offset, 1 / scale, -rotation);

/// Welche Verschiebung hält [imagePoint] unter [screenPoint], wenn mit
/// [scale] und [rotation] gearbeitet wird?
///
/// Damit bleibt beim Zoomen und Drehen der Punkt unter den Fingern stehen.
/// Ohne das zöge das Bild zur Rahmenmitte weg — die Geste fühlt sich dann an,
/// als würde man gegen die App arbeiten.
Offset offsetForAnchor({
  required Offset imagePoint,
  required Offset screenPoint,
  required Offset center,
  required double scale,
  required double rotation,
}) =>
    screenPoint - center - _rotateScale(imagePoint, scale, rotation);

/// Zielgröße für einen Rahmen: gleiches Seitenverhältnis, längste Seite auf
/// [kCropRenderMaxDimension] gedeckelt, aber nie hochskaliert.
ui.Size cropOutputSize(ui.Size frame, {int max = kCropRenderMaxDimension}) {
  if (frame.width <= 0 || frame.height <= 0) return ui.Size.zero;
  final longest = frame.width >= frame.height ? frame.width : frame.height;
  final factor = longest > max ? max / longest : 1.0;
  return ui.Size(
    (frame.width * factor).roundToDouble(),
    (frame.height * factor).roundToDouble(),
  );
}

/// Schneidet den Rahmeninhalt aus und gibt ihn als PNG-Bytes zurück.
///
/// Zeichnet dazu dieselbe Transformation noch einmal auf eine Leinwand in
/// Zielgröße — was im Rahmen stand, steht danach im Bild.
Future<Uint8List> renderCrop({
  required ui.Image image,
  required ui.Size frameSize,
  required Offset offset,
  required double scale,
  required double rotation,
}) async {
  final out = cropOutputSize(frameSize);
  if (out.isEmpty) {
    throw StateError('Zuschnittfenster hat keine Größe.');
  }
  // Maßstab zwischen Bildschirm-Rahmen und Zielfläche.
  final k = out.width / frameSize.width;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, out.width, out.height),
  );

  // Deckend füllen: Ein Rahmen, den das Bild nicht ganz ausfüllt, soll
  // schwarz sein statt durchsichtig — ein PNG mit Alpha-Löchern sieht später
  // je nach Hintergrund anders aus.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, out.width, out.height),
    ui.Paint()..color = const Color(0xFF000000),
  );

  canvas.save();
  applyImageTransform(
    canvas,
    Offset(out.width / 2, out.height / 2),
    offset * k,
    scale * k,
    rotation,
  );
  canvas.drawImage(
    image,
    Offset(-image.width / 2, -image.height / 2),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  canvas.restore();

  final picture = recorder.endRecording();
  try {
    final rendered = await picture.toImage(
      out.width.toInt(),
      out.height.toInt(),
    );
    try {
      final data =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Zuschnitt konnte nicht codiert werden.');
      }
      return data.buffer.asUint8List();
    } finally {
      rendered.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// Dekodiert Bytes zu einem [ui.Image] fürs Zeichnen.
Future<ui.Image> decodeUiImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}
