/// image_capture.dart – Gemeinsame Bildaufnahme für Fahrzeug- und Gerätebilder
/// (Issue #56): Quelle wählen (Kamera oder Galerie), zuschneiden, drehen.
///
/// Vorher gab es drei Aufrufstellen mit je eigenem Verhalten — Fahrzeugformular
/// nur Galerie mit vorgeschalteter Größenabfrage, Gerätedetail bevorzugt
/// Kamera, Geräteformular nur Galerie — und nirgends Zuschneiden oder Drehen.
/// AGENTS.md § 3 („Zweitverwendung = Extraktion") verlangt genau hier eine
/// gemeinsame Stelle.
///
/// Der Editor arbeitet rein in Dart (`crop_your_image` + `image`), damit er
/// auch in der Web-App läuft und keine native Einrichtung auf drei Plattformen
/// braucht.
library;

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:fwapp/core/images/image_processing.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ergebnis der Bildaufnahme.
class CapturedImage {
  /// Fertig zugeschnittene, gedrehte und verkleinerte JPEG-Bytes.
  final Uint8List bytes;

  /// Pfad der abgelegten Datei — `null` in der Web-App, wo es kein
  /// beschreibbares Dateisystem gibt. Aufrufer, die zwingend einen Pfad
  /// brauchen, müssen diesen Fall behandeln.
  final String? path;

  const CapturedImage({required this.bytes, this.path});
}

/// Öffnet Quellenwahl und Editor und liefert das fertige Bild.
///
/// Gibt `null` zurück, wenn abgebrochen wurde. [saveToFile] schreibt das
/// Ergebnis zusätzlich in den App-Ordner (auf Web wirkungslos).
///
/// Ist [source] gesetzt, entfällt die Quellenwahl. Das brauchen Aufrufer, die
/// die Quelle schon in einem eigenen Menü erfragt haben — sonst kämen zwei
/// Auswahl-Sheets hintereinander (Geräteformular: dort steht zusätzlich das
/// Symbolbild aus der Bildbibliothek zur Wahl).
Future<CapturedImage?> captureImage(
  BuildContext context, {
  ImageSource? source,
  bool saveToFile = true,
}) async {
  source ??= await _askForSource(context);
  if (source == null || !context.mounted) return null;

  final picker = ImagePicker();
  final XFile? file;
  try {
    // Großzügige Obergrenze: Der Zuschnitt braucht noch Auflösung zum
    // Arbeiten. Klein gerechnet wird erst ganz am Schluss.
    file = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
  } catch (e, s) {
    appLog.w('Bildauswahl fehlgeschlagen', error: e, stackTrace: s);
    if (context.mounted) {
      _showError(context, 'Bild konnte nicht geöffnet werden.');
    }
    return null;
  }
  if (file == null || !context.mounted) return null;

  final raw = await file.readAsBytes();
  if (!context.mounted) return null;

  final edited = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ImageEditorScreen(source: raw),
    ),
  );
  if (edited == null) return null;

  // Einmal am Schluss auf Auslieferungsgröße rechnen — nicht nach jedem
  // Editor-Schritt, sonst baut sich die Qualität stufenweise ab.
  final Uint8List small;
  try {
    small = await compute(compressImageForUpload, edited);
  } on FormatException catch (e) {
    appLog.w('Bild konnte nicht verkleinert werden', error: e);
    if (context.mounted) _showError(context, 'Bildformat wird nicht unterstützt.');
    return null;
  }

  if (!saveToFile || kIsWeb) return CapturedImage(bytes: small);
  try {
    return CapturedImage(bytes: small, path: await _writeToAppDir(small));
  } catch (e, s) {
    // Ohne Datei ist das Bild für pfadbasierte Aufrufer unbrauchbar — aber
    // die Bytes stehen, und der Aufrufer kann sie hochladen.
    appLog.w('Bild konnte nicht gespeichert werden', error: e, stackTrace: s);
    return CapturedImage(bytes: small);
  }
}

void _showError(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

/// Schreibt das Bild unter einem eindeutigen Namen in den App-Ordner.
/// Zeitstempel im Namen: Ein ersetztes Bild darf nie denselben Pfad bekommen,
/// sonst zeigen Bild-Caches weiter das alte.
Future<String> _writeToAppDir(Uint8List bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = await File(
    p.join(dir.path, 'img_${DateTime.now().millisecondsSinceEpoch}.jpg'),
  ).create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// `true`, wenn diese Plattform die Kamera anbieten kann. Aufrufer mit
/// eigenem Auswahlmenü blenden ihren Kamera-Eintrag danach aus — auf dem
/// Desktop und im Browser ohne Kamera wäre er eine Sackgasse.
bool get cameraAvailable =>
    ImagePicker().supportsImageSource(ImageSource.camera);

/// Kamera oder Galerie? Die Kamera erscheint nur, wo es sie gibt.
Future<ImageSource?> _askForSource(BuildContext context) {
  final hasCamera = cameraAvailable;
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCamera)
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Aus Galerie wählen'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Abbrechen'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

/// Vollbild-Editor: Ausschnitt ziehen, drehen, übernehmen.
///
/// Öffentlich, damit der Widget-Test ihn direkt aufziehen kann — über
/// [captureImage] käme man nur mit einem Plattformkanal für die Bildauswahl
/// hierher. Gibt die zugeschnittenen Bytes per `Navigator.pop` zurück,
/// oder `null` bei Abbruch.
class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({super.key, required this.source});

  final Uint8List source;

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final _controller = CropController();
  late Uint8List _current = widget.source;
  var _busy = false;

  Future<void> _rotate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Im Isolate: Drehen dekodiert und codiert das ganze Bild neu und
      // würde den UI-Thread sonst sichtbar hängen lassen.
      final rotated =
          await compute(_rotateOnce, (bytes: _current, turns: 1));
      if (!mounted) return;
      setState(() {
        _current = rotated;
        _busy = false;
      });
      // Neues Bild in den Cropper — der Ausschnitt wird dabei zurückgesetzt,
      // was nach einer Drehung auch die richtige Erwartung ist.
      _controller.image = rotated;
    } catch (e, s) {
      appLog.w('Drehen fehlgeschlagen', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(context, 'Bild konnte nicht gedreht werden.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Bild zuschneiden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Drehen',
            onPressed: _busy ? null : _rotate,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: _current,
              controller: _controller,
              // Zoomen und Verschieben per Finger — der Punkt, an dem die
              // bisherige Auswahl „dürftig" war.
              interactive: true,
              baseColor: Colors.black,
              maskColor: Colors.black.withValues(alpha: 0.6),
              cornerDotBuilder: (size, _) =>
                  const DotControl(color: Colors.white),
              progressIndicator: const CircularProgressIndicator(),
              onCropped: (result) {
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    Navigator.of(context).pop(croppedImage);
                  case CropFailure(:final cause):
                    appLog.w('Zuschneiden fehlgeschlagen', error: cause);
                    setState(() => _busy = false);
                    _showError(context, 'Zuschneiden fehlgeschlagen.');
                }
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        // Fingerfreundlich statt Maus-Maß.
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() => _busy = true);
                              _controller.crop();
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Übernehmen'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-level für `compute` — Closures lassen sich nicht in ein Isolate geben.
Uint8List _rotateOnce(({Uint8List bytes, int turns}) arg) =>
    rotateImageBytes(arg.bytes, arg.turns);
