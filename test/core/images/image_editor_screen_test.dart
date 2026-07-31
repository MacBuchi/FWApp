/// image_editor_screen_test.dart – Der Zuschneide-/Dreh-Editor der
/// Bildaufnahme (Issue #56).
///
/// ⚠️ Hier **kein** `pumpAndSettle`: Der Crop-Widget zeigt beim Parsen einen
/// dauerlaufenden Fortschrittsring, und `pumpAndSettle` wartet auf einen
/// Ruhezustand, der damit nie eintritt (Timeout statt Fehlschlag). Deshalb
/// überall gezieltes `pump()` mit Dauer.
library;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/images/image_capture.dart';
import 'package:image/image.dart' as img;

/// Kleines, echt dekodierbares Bild — der Editor parst die Bytes wirklich,
/// ein Platzhalter-Array würde ihn nur in den Fehlerpfad schicken.
Uint8List _testImage({int width = 120, int height = 80}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(20, 120, 200));
  return img.encodeJpg(image);
}

/// Genug Frames, damit Routenwechsel und Bild-Parsing durch sind.
Future<void> _settleABit(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  /// Zieht den Editor in einem Navigator auf und merkt sich, was er
  /// zurückgibt — der Rückgabewert ist das eigentliche Vertragsversprechen.
  Future<void> pumpEditor(
    WidgetTester tester, {
    required void Function(Uint8List?) onResult,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute(
                    builder: (_) => ImageEditorScreen(source: _testImage()),
                  ),
                );
                onResult(result);
              },
              child: const Text('start'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('start'));
    await _settleABit(tester);
  }

  IconButton rotateButton(WidgetTester tester) => tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.rotate_right),
          matching: find.byType(IconButton),
        ),
      );

  testWidgets('zeigt Titel, Dreh-Knopf und beide Aktionen', (tester) async {
    await pumpEditor(tester, onResult: (_) {});

    expect(find.text('Bild zuschneiden'), findsOneWidget);
    expect(find.byIcon(Icons.rotate_right), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Übernehmen'), findsOneWidget);
  });

  testWidgets('Abbrechen liefert null zurück', (tester) async {
    Uint8List? result;
    var called = false;
    await pumpEditor(tester, onResult: (r) {
      result = r;
      called = true;
    });

    await tester.tap(find.text('Abbrechen'));
    await _settleABit(tester);

    expect(called, isTrue, reason: 'die Route muss sich geschlossen haben');
    expect(result, isNull);
  });

  testWidgets('die Aktionsflächen sind fingerfreundlich hoch', (tester) async {
    // Der Kern von „touchscreenfreundlich" aus dem Issue: Die Knöpfe müssen
    // auch mit Handschuh am Fahrzeug treffbar sein. 48 dp ist das
    // Material-Mindestmaß für Tippziele.
    await pumpEditor(tester, onResult: (_) {});

    for (final (type, label) in [
      (OutlinedButton, 'Abbrechen'),
      (FilledButton, 'Übernehmen'),
    ]) {
      final size = tester.getSize(find.widgetWithText(type, label));
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '"$label" ist nur ${size.height} hoch');
    }
  });

  testWidgets('Drehen sperrt den Knopf, solange es läuft', (tester) async {
    await pumpEditor(tester, onResult: (_) {});
    expect(rotateButton(tester).onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.rotate_right));
    await tester.pump(); // setState(_busy = true), Drehung läuft noch

    expect(rotateButton(tester).onPressed, isNull,
        reason: 'ein zweiter Tipp während des Drehens darf nicht durchgehen');

    // ⚠️ `runAsync`: Das Drehen läuft über `compute()` in einem echten
    // Isolate. `pump(Duration)` schiebt nur die simulierte Testzeit vor —
    // das Ergebnis des Isolates käme dabei nie an.
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 800)));
    await tester.pump();

    expect(rotateButton(tester).onPressed, isNotNull,
        reason: 'danach muss wieder gedreht werden können');
  });

  testWidgets('nach dem Drehen ist der Editor unverändert bedienbar',
      (tester) async {
    await pumpEditor(tester, onResult: (_) {});

    await tester.tap(find.byIcon(Icons.rotate_right));
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 800)));
    await _settleABit(tester);

    // Insbesondere ist er nicht in den Fehlerpfad gelaufen.
    expect(find.text('Bild zuschneiden'), findsOneWidget);
    expect(find.text('Übernehmen'), findsOneWidget);
    expect(find.textContaining('konnte nicht gedreht'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
