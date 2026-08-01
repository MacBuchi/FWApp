/// widget_harness.dart – Shared scaffolding for widget tests: wraps a screen
/// in ProviderScope (with an in-memory database) and MaterialApp.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/router/app_router.dart';

Widget buildTestApp({
  required AppDatabase db,
  required Widget home,
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ...overrides,
      ],
      child: MaterialApp(home: home),
    );

/// Wie [buildTestApp], aber mit dem ECHTEN Router — für Tests, die den
/// Redirect selbst beweisen sollen und nicht nur einen einzelnen Screen.
/// Ohne das liefe der Anmeldezwang in keinem Widget-Test mit.
Widget buildRoutedTestApp({
  required AppDatabase db,
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ...overrides,
      ],
      child: Consumer(
        builder: (_, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(routerProvider)),
      ),
    );

/// The ProviderContainer of a pumped test app (to drive notifiers directly
/// where native integrations like file pickers block UI-level interaction).
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first));

/// Call at the END of tests whose screens watch drift streams: disposes the
/// tree and lets drift's stream-retention timers expire — otherwise the test
/// framework fails with "A Timer is still pending" (tearDown runs only after
/// that invariant check).
Future<void> endTestApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}
