/// screenshots_test.dart – erzeugt die README-Screenshots auf einem echten
/// Gerät.
///
/// Kein Test im eigentlichen Sinn: Die Datei fährt die App durch die Screens,
/// die nach außen etwas zeigen sollen, und löst an jeder Station eine
/// Aufnahme aus. Deshalb läuft sie NICHT bei `flutter test integration_test`
/// mit — sie braucht den Driver, der die Bilder auf dem Host ablegt:
///
///   flutter drive --driver=test_driver/screenshot_driver.dart \
///     --target=integration_test/screenshots_test.dart -d `geräte-id`
///
/// Vorher das Gerät ins Hochformat zwingen, sonst entstehen quer liegende
/// Bilder (der Pixel XL im Testrig steht auf Auto-Rotation):
///
///   adb shell settings put system accelerometer_rotation 0
///   adb shell settings put system user_rotation 0
///
/// Gezeigt wird ausschließlich der gebündelte Demo-Bestand (fiktives
/// HLF 20 + Normgeräte-Katalog) auf einer frisch installierten, nicht
/// angemeldeten App. Vor dem Lauf sicherstellen, dass keine echten Wehrdaten
/// auf dem Gerät liegen — die Bilder landen in einem öffentlichen Repo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/main.dart' as app;
import 'package:integration_test/integration_test.dart';

late IntegrationTestWidgetsFlutterBinding binding;

Future<void> settle(WidgetTester tester) async =>
    tester.pumpAndSettle(const Duration(milliseconds: 250));

/// Trifft [finder] gerade etwas?
///
/// `evaluate()` ist auf `.first`/`.last`-Findern nicht harmlos: Solange nichts
/// passt, werfen sie `Bad state: No element` statt eine leere Liste zu
/// liefern. Genau das passiert beim Warten auf noch nicht geladene Inhalte.
bool matches(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

/// Pumpt, bis [finder] fündig wird — asynchrone Provider (Seeder, Drift)
/// brauchen auf einem echten Gerät mehrere Frames, und `pumpAndSettle` kehrt
/// währenddessen zurück, weil kein Frame ansteht.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  for (var waited = Duration.zero;
      waited < timeout;
      waited += const Duration(milliseconds: 100)) {
    if (matches(finder)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  final sichtbar = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList();
  fail('Nach ${timeout.inSeconds}s nicht gefunden: '
      '${finder.describeMatch(Plurality.one)}\nSichtbar: $sichtbar');
}

Future<void> shoot(WidgetTester tester, String name) async {
  await settle(tester);
  await binding.takeScreenshot(name);
}

/// Tippt ein Ziel an, nachdem es in den sichtbaren Bereich gescrollt wurde.
Future<void> tapItem(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('README-Screenshots aufnehmen', (tester) async {
    // Auf Android muss die Flutter-Oberfläche erst in ein aufnehmbares Bild
    // umgewandelt werden, sonst liefert takeScreenshot nichts.
    await binding.convertFlutterSurfaceToImage();

    await app.main();
    await settle(tester);
    await waitFor(tester, find.text('Start'));

    // Start-Dashboard und Fahrzeugliste werden bewusst NICHT aufgenommen:
    // Auf einer frischen Installation sind beide fast leer (0 XP, ein einziges
    // Demo-Fahrzeug) und taugen nicht als Aushängeschild.

    // 1 – Fahrzeugdetail: die Beladefächer des Demo-HLF.
    await tapItem(tester, find.text('Fahrzeuge').last);
    await tapItem(tester, find.text('HLF 20 (Demo)').first);
    await waitFor(tester, find.text('Beladefächer'));
    await shoot(tester, '01-beladefaecher');

    // 2 – Lernen: die Spielmodi.
    await tapItem(tester, find.text('Lernen').last);
    await waitFor(tester, find.text('Fach-Quiz'));
    await shoot(tester, '02-lernen');

    // 3 – Gerätekatalog mit den Piktogrammen aus der Bildbibliothek.
    await tapItem(tester, find.text('Mehr').last);
    await tapItem(tester, find.widgetWithText(ListTile, 'Gerätekatalog').first);
    await settle(tester);
    await shoot(tester, '03-geraetekatalog');
  });
}
