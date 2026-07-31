/// image_editor_screen_test.dart – Der Zuschneide-Editor der Bildaufnahme
/// (Issue #56). Der Rahmen steht fest, das Bild wird darin bewegt.
///
/// ⚠️ Hier **kein** `pumpAndSettle`: Solange das Bild lädt, läuft ein
/// `CircularProgressIndicator`, und `pumpAndSettle` wartet auf einen
/// Ruhezustand, der damit nie eintritt (Timeout statt Fehlschlag).
///
/// ⚠️ Und **`runAsync` beim Aufziehen**: Das Bild wird über `compute()`
/// aufbereitet und von der Engine dekodiert — beides läuft nicht in der
/// simulierten Testzeit ab. Ohne das prüfen die Tests nur den Ladezustand.
///
/// Die Transformationsmathematik selbst steht in crop_render_test.dart.
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

Future<void> _settleABit(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lässt echte Arbeit laufen und pumpt danach.
///
/// Mehrere Runden, weil das Laden zwei aufeinanderfolgende echte Schritte hat
/// (Bytes im Isolate aufbereiten, dann über die Engine dekodieren). Nach dem
/// ersten `runAsync` läuft wieder die simulierte Uhr, in der der zweite
/// Schritt nicht fertig würde.
Future<void> _letRealWorkRun(WidgetTester tester, {int rounds = 3}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await _settleABit(tester);
  }
}

void main() {
  /// Zieht den Editor in einem Navigator auf und merkt sich, was er
  /// zurückgibt — der Rückgabewert ist das eigentliche Vertragsversprechen.
  Future<void> pumpEditor(
    WidgetTester tester, {
    required void Function(Uint8List?) onResult,
    Uint8List? source,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ImageEditorScreen(source: source ?? _testImage()),
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
    // Erst pumpen, damit die Route gebaut ist und initState() das Laden
    // anstoesst — sonst liefe das runAsync-Fenster ins Leere und der Editor
    // haenge im Ladezustand fest.
    await _settleABit(tester);
    await _letRealWorkRun(tester);
  }

  T buttonWith<T extends Widget>(WidgetTester tester, IconData icon) =>
      tester.widget<T>(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(T)),
      );

  testWidgets('zeigt Titel, beide Werkzeuge, beide Aktionen und den Hinweis',
      (tester) async {
    await pumpEditor(tester, onResult: (_) {});

    expect(find.text('Bild zuschneiden'), findsOneWidget);
    expect(find.byIcon(Icons.rotate_right), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Übernehmen'), findsOneWidget);
    // Die Geste ist nicht selbsterklärend genug, um sie unerwähnt zu lassen.
    expect(find.textContaining('zwei Fingern'), findsOneWidget);
  });

  testWidgets('ist nach dem Laden bedienbar (kein Dauer-Ladezustand)',
      (tester) async {
    await pumpEditor(tester, onResult: (_) {});

    // Solange das Bild fehlt, ist Übernehmen gesperrt — das darf nach dem
    // Laden nicht mehr so sein.
    final apply = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Übernehmen'));
    expect(apply.onPressed, isNotNull);
    expect(find.byType(CustomPaint), findsWidgets);
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

  testWidgets('90°-Drehen wirkt sofort und sperrt nichts', (tester) async {
    // Anders als früher wird beim Drehen nichts neu codiert — es ändert nur
    // die Transformation. Ein Wartezustand wäre hier also ein Fehler.
    await pumpEditor(tester, onResult: (_) {});

    await tester.tap(find.byIcon(Icons.rotate_right));
    await tester.pump();

    expect(buttonWith<IconButton>(tester, Icons.rotate_right).onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
    expect(find.text('Übernehmen'), findsOneWidget);
  });

  testWidgets('Zurücksetzen bleibt bedienbar', (tester) async {
    await pumpEditor(tester, onResult: (_) {});

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Bild zuschneiden'), findsOneWidget);
  });

  testWidgets('Ziehen und Zwei-Finger-Geste laufen ohne Fehler durch',
      (tester) async {
    await pumpEditor(tester, onResult: (_) {});

    final area = find.byType(CustomPaint).first;

    // Ein Finger: verschieben.
    await tester.drag(area, const Offset(40, -25));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Zwei Finger: zoomen und drehen zugleich.
    final center = tester.getCenter(area);
    final g1 = await tester.startGesture(center - const Offset(40, 0));
    final g2 = await tester.startGesture(center + const Offset(40, 0));
    await g1.moveBy(const Offset(-30, -20));
    await g2.moveBy(const Offset(30, 20));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Übernehmen'), findsOneWidget);
  });

  testWidgets('Übernehmen liefert Bytes zurück', (tester) async {
    Uint8List? result;
    await pumpEditor(tester, onResult: (r) => result = r);

    await tester.tap(find.text('Übernehmen'));
    await _letRealWorkRun(tester);

    expect(result, isNotNull);
    expect(result!.length, greaterThan(100),
        reason: 'ein leeres Ergebnis wäre kein Bild');
  });

  testWidgets('unlesbare Daten zeigen einen Hinweis statt eines Absturzes',
      (tester) async {
    await pumpEditor(
      tester,
      onResult: (_) {},
      source: Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(find.textContaining('nicht unterstützt'), findsOneWidget);
    // Übernehmen bleibt gesperrt — es gibt nichts zu übernehmen.
    final apply = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Übernehmen'));
    expect(apply.onPressed, isNull);
  });
}
