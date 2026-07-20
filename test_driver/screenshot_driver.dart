/// screenshot_driver.dart – Host-Seite der Screenshot-Strecke.
///
/// Nimmt die Bilder entgegen, die `integration_test/screenshots_test.dart`
/// auf dem Gerät aufnimmt, und legt sie unter docs/screenshots/ ab.
///
/// Aufruf:
///   flutter drive --driver=test_driver/screenshot_driver.dart \
///     --target=integration_test/screenshots_test.dart -d `geräte-id`
library;

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? _]) async {
      final file = File('docs/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      stdout.writeln('Screenshot: ${file.path} (${bytes.length} Bytes)');
      return true;
    },
  );
}
