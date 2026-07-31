/// image_capture.dart – Gemeinsame Bildaufnahme für Fahrzeug- und Gerätebilder
/// (Issue #56): Quelle wählen (Kamera oder Galerie), zuschneiden, drehen.
///
/// Vorher gab es drei Aufrufstellen mit je eigenem Verhalten — Fahrzeugformular
/// nur Galerie mit vorgeschalteter Größenabfrage, Gerätedetail bevorzugt
/// Kamera, Geräteformular nur Galerie — und nirgends Zuschneiden oder Drehen.
/// AGENTS.md § 3 („Zweitverwendung = Extraktion") verlangt genau hier eine
/// gemeinsame Stelle.
///
/// Der Editor kommt ohne Zuschneide-Paket aus: Die Zwei-Finger-Geste liefert
/// Flutter selbst (`ScaleUpdateDetails` trägt scale, rotation und
/// focalPointDelta), gezeichnet und ausgeschnitten wird über `dart:ui`. Das
/// läuft auf allen Zielplattformen inklusive Web, braucht keine native
/// Einrichtung — und das Ergebnis ist exakt der sichtbare Ausschnitt.
library;

import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:fwapp/core/images/crop_render.dart';
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

  // rootNavigator: Ohne das öffnet der Editor im Shell-Navigator, die untere
  // Navigationsleiste bleibt stehen und frisst genau die Höhe, die der
  // Zuschnittrahmen braucht. Zum Bildbearbeiten gehört der ganze Schirm.
  final edited =
      await Navigator.of(context, rootNavigator: true).push<Uint8List>(
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

/// Vollbild-Editor: Der Rahmen steht fest, **das Bild** wird darin bewegt —
/// ein Finger verschiebt, zwei Finger skalieren und drehen gleichzeitig. Was
/// im Rahmen steht, ist der Zuschnitt.
///
/// Bewusst so herum statt „Rahmen aufziehen": Am Fahrzeug hält man das Gerät
/// in einer Hand, und das Bild direkt anzufassen ist die Geste, die man von
/// jeder Foto-App kennt. Ein Rahmen mit vier Greifpunkten verlangt dagegen
/// zielgenaues Treffen kleiner Punkte.
///
/// Öffentlich, damit der Widget-Test ihn direkt aufziehen kann — über
/// [captureImage] käme man nur mit einem Plattformkanal für die Bildauswahl
/// hierher. Gibt die zugeschnittenen Bytes per `Navigator.pop` zurück,
/// oder `null` bei Abbruch.
class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({
    super.key,
    required this.source,
    this.aspectRatio = 4 / 3,
  });

  final Uint8List source;

  /// Seitenverhältnis des Zuschnittfensters (Breite/Höhe).
  final double aspectRatio;

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  ui.Image? _image;
  Object? _loadError;
  var _busy = false;

  // Lage des Bildes relativ zur Rahmenmitte, in logischen Pixeln.
  Offset _offset = Offset.zero;
  double _scale = 1;
  double _rotation = 0;

  // Ausgangswerte beim Beginn einer Geste. `details.scale`/`.rotation` sind
  // seit Gestenbeginn kumulativ, deshalb wird gegen diese Basis gerechnet.
  double _startScale = 1;
  double _startRotation = 0;

  /// Der Bildpunkt, der beim Gestenbeginn unter den Fingern lag. Er bleibt
  /// während der ganzen Geste dort — siehe [offsetForAnchor].
  Offset _anchorInImage = Offset.zero;

  /// Skalierung, bei der das Bild den Rahmen gerade ausfüllt. Untergrenze
  /// beim Zoomen: Ein Rahmen mit Löchern wäre nie das gewünschte Ergebnis.
  double _coverScale = 1;
  Size _frameSize = Size.zero;

  /// Rahmenmitte im Koordinatensystem des Gesten-Widgets.
  Offset _center = Offset.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // EXIF-Drehung vorab anwenden: ui.decodeImageFromList wertet sie nicht
      // zuverlässig aus, und ein liegendes Foto im Editor wäre verwirrend.
      final upright = await compute(bakeOrientationBytes, widget.source);
      final image = await decodeUiImage(upright);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (e, s) {
      appLog.w('Bild konnte nicht geladen werden', error: e, stackTrace: s);
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startRotation = _rotation;
    // Merken, welcher Bildpunkt unter den Fingern liegt — er bleibt dort.
    _anchorInImage = imagePointAt(
      screenPoint: details.localFocalPoint,
      center: _center,
      offset: _offset,
      scale: _scale,
      rotation: _rotation,
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Nicht kleiner als „füllt den Rahmen" — sonst entstehen Ränder.
      _scale = (_startScale * details.scale).clamp(_coverScale, _coverScale * 8);
      _rotation = _startRotation + details.rotation;
      // Verschieben ergibt sich daraus, den gemerkten Punkt unter dem
      // (mitwandernden) Fingerschwerpunkt zu halten. Deckt Ein-Finger-Ziehen
      // gleich mit ab: Dort ändern sich scale und rotation einfach nicht.
      _offset = offsetForAnchor(
        imagePoint: _anchorInImage,
        screenPoint: details.localFocalPoint,
        center: _center,
        scale: _scale,
        rotation: _rotation,
      );
    });
  }

  /// Grob-Drehung in 90°-Schritten. Die freie Drehung per Zwei-Finger-Geste
  /// bleibt davon unberührt; der Knopf ist für ein komplett quer liegendes
  /// Foto gedacht, das man sonst mühsam von Hand geraderücken müsste.
  void _rotateQuarter() => setState(() => _rotation += math.pi / 2);

  void _reset() => setState(() {
        _offset = Offset.zero;
        _rotation = 0;
        _scale = _coverScale;
      });

  Future<void> _apply() async {
    final image = _image;
    if (image == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await renderCrop(
        image: image,
        frameSize: _frameSize,
        offset: _offset,
        scale: _scale,
        rotation: _rotation,
      );
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (e, s) {
      appLog.w('Zuschneiden fehlgeschlagen', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(context, 'Zuschneiden fehlgeschlagen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Bild zuschneiden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Um 90° drehen',
            onPressed: image == null || _busy ? null : _rotateQuarter,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Zurücksetzen',
            onPressed: image == null || _busy ? null : _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadError != null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Bildformat wird nicht unterstützt.',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : image == null
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final frame = _fitFrame(constraints.biggest);
                          // Erststart und Fenstergrößenwechsel: Bild so
                          // legen, dass es den Rahmen füllt.
                          final cover = math.max(
                            frame.width / image.width,
                            frame.height / image.height,
                          );
                          if (_frameSize != frame) {
                            _frameSize = frame;
                            _coverScale = cover;
                            if (_scale < cover) _scale = cover;
                          }
                          _center = Offset(
                            constraints.maxWidth / 2,
                            constraints.maxHeight / 2,
                          );
                          return GestureDetector(
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: _onScaleUpdate,
                            child: CustomPaint(
                              size: constraints.biggest,
                              painter: _EditorPainter(
                                image: image,
                                frame: frame,
                                offset: _offset,
                                scale: _scale,
                                rotation: _rotation,
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Eigene schwarze Fläche: Der Hinweis stand sonst halb über dem Bild
          // und war je nach Motiv nicht zu lesen.
          ColoredBox(
            color: Colors.black,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    const Text(
                      'Mit zwei Fingern drehen und zoomen, '
                      'mit einem verschieben.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).pop(),
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
                            onPressed: image == null || _busy ? null : _apply,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Übernehmen'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Größter Rahmen mit dem gewünschten Seitenverhältnis, der mit etwas Luft
  /// in die verfügbare Fläche passt.
  Size _fitFrame(Size available) {
    final maxW = available.width - 32;
    final maxH = available.height - 32;
    if (maxW <= 0 || maxH <= 0) return Size.zero;
    final byWidth = Size(maxW, maxW / widget.aspectRatio);
    return byWidth.height <= maxH
        ? byWidth
        : Size(maxH * widget.aspectRatio, maxH);
  }
}

/// Zeichnet das transformierte Bild und dunkelt alles außerhalb des Rahmens ab.
class _EditorPainter extends CustomPainter {
  const _EditorPainter({
    required this.image,
    required this.frame,
    required this.offset,
    required this.scale,
    required this.rotation,
  });

  final ui.Image image;
  final Size frame;
  final Offset offset;
  final double scale;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final frameRect = Rect.fromCenter(
        center: center, width: frame.width, height: frame.height);

    canvas.save();
    applyImageTransform(canvas, center, offset, scale, rotation);
    canvas.drawImage(
        image, Offset(-image.width / 2, -image.height / 2), Paint());
    canvas.restore();

    // Alles außerhalb des Rahmens abdunkeln — der Rahmen IST der Zuschnitt,
    // das muss ohne Erklärung sichtbar sein.
    final mask = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(frameRect),
    );
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawRect(
      frameRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_EditorPainter old) =>
      old.image != image ||
      old.frame != frame ||
      old.offset != offset ||
      old.scale != scale ||
      old.rotation != rotation;
}
