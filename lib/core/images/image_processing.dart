/// image_processing.dart – Reine Bildoperationen für die Bildaufnahme
/// (Issue #56). Ohne Flutter-Widgets und ohne I/O, damit sie im Test direkt
/// prüfbar sind und in `compute()` in einem Hintergrund-Isolate laufen können.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Budget für ausgelieferte Bilder: längste Seite und Zielgröße.
///
/// Beide Werte gelten seit M2 für Upload-Bilder und jetzt zusätzlich für
/// lokal gespeicherte Fahrzeug-/Gerätebilder. Ein Handyfoto hat schnell
/// 4000 px und mehrere MB — auf einem Beladeplan bringt das nichts, kostet
/// aber Speicher, Sync-Zeit und Bandbreite im Feld.
const kMaxImageDimension = 1024;
const kMaxImageBytes = 300 * 1024;

/// Dekodiert [input] und wendet die EXIF-Ausrichtung an.
///
/// Wirft [FormatException], wenn das Format nicht lesbar ist — der Aufrufer
/// zeigt das als Meldung; still ein leeres Bild zu liefern wäre schlimmer.
img.Image decodeUpright(Uint8List input) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    decoded = null; // Decoder warf bei kaputten Daten — gleiche Folge wie null
  }
  if (decoded == null) {
    throw const FormatException('Bildformat wird nicht unterstützt.');
  }
  // EXIF-Drehung anwenden, bevor die Metadaten beim Neucodieren wegfallen.
  // Ohne das liegen Fotos mancher Kameras im Editor auf der Seite.
  return img.bakeOrientation(decoded);
}

/// Dreht [input] um [quarterTurns] × 90° im Uhrzeigersinn und gibt wieder
/// JPEG-Bytes zurück.
///
/// Wird zwischen zwei Zuschnitt-Schritten aufgerufen, deshalb bewusst ohne
/// Verkleinerung: Das endgültige Verkleinern passiert einmal am Schluss in
/// [compressImageForUpload], sonst würde jede Drehung die Qualität weiter
/// abbauen.
Uint8List rotateImageBytes(Uint8List input, int quarterTurns) {
  final turns = quarterTurns % 4;
  final image = decodeUpright(input);
  if (turns == 0) return img.encodeJpg(image, quality: 95);
  return img.encodeJpg(img.copyRotate(image, angle: turns * 90), quality: 95);
}

/// Dekodiert, verkleinert auf [kMaxImageDimension] und codiert als JPEG neu —
/// mit absteigender Qualität (und notfalls Größe), bis das Ergebnis unter
/// [kMaxImageBytes] liegt. Top-level, damit es in einem Isolate laufen kann.
Uint8List compressImageForUpload(Uint8List input) {
  var image = decodeUpright(input);

  var bytes = Uint8List(0);
  var dimension = kMaxImageDimension;
  while (true) {
    var scaled = image;
    if (max(image.width, image.height) > dimension) {
      scaled = img.copyResize(
        image,
        width: image.width >= image.height ? dimension : null,
        height: image.height > image.width ? dimension : null,
        interpolation: img.Interpolation.average,
      );
    }
    for (var quality = 85; quality >= 45; quality -= 10) {
      bytes = img.encodeJpg(scaled, quality: quality);
      if (bytes.length <= kMaxImageBytes) return bytes;
    }
    // Qualität ausgereizt: kleiner rechnen und erneut versuchen.
    if (dimension <= 512) return bytes; // pathologische Eingabe: best effort
    dimension = (dimension * 3) ~/ 4;
  }
}
