/// settings_screen_widget_test.dart – Settings states: sync section and the
/// restart hint when credentials are configured but not yet active.
library;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('Sync deaktiviert: keine Verbindungsfelder sichtbar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester
        .pumpWidget(buildTestApp(db: db, home: const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Supabase-Sync aktivieren'), findsOneWidget);
    expect(find.text('Supabase URL'), findsNothing);
    expect(find.text('Neustart erforderlich'), findsNothing);
  });

  testWidgets('Design: Standard System, Auswahl Hell/Dunkel vorhanden',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester
        .pumpWidget(buildTestApp(db: db, home: const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Design'), findsOneWidget);
    final segmented = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.system});

    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SegmentedButton<ThemeMode>>(
                find.byType(SegmentedButton<ThemeMode>))
            .selected,
        {ThemeMode.dark});
  });

  testWidgets('Design-Migration: alter Dunkel-Schalter bleibt Dunkel',
      (tester) async {
    SharedPreferences.setMockInitialValues({'dark_mode': true});
    await tester
        .pumpWidget(buildTestApp(db: db, home: const SettingsScreen()));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>));
    expect(segmented.selected, {ThemeMode.dark});
  });

  testWidgets(
      'Sync konfiguriert, aber nicht initialisiert: Neustart-Hinweis',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'sync_enabled': true,
      'supabase_url': 'http://127.0.0.1:54321',
      'supabase_key': 'anon-key',
    });
    await tester
        .pumpWidget(buildTestApp(db: db, home: const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Supabase URL'), findsOneWidget);
    expect(find.text('http://127.0.0.1:54321'), findsOneWidget);
    // supabaseReadyProvider ist false (kein Initialize in diesem Lauf).
    expect(find.text('Neustart erforderlich'), findsOneWidget);
    // Verbindungs-Sektion (Login) erscheint erst nach dem Neustart.
    expect(find.text('Mit Abteilung verbinden'), findsNothing);
  });

  // Bewusst kein Test für den metadata.json-FutureBuilder: Asset-I/O in
  // FutureBuildern lässt sich in der Fake-Async-Testumgebung nicht
  // zuverlässig antreiben, und die Kachel ist rein kosmetisch.

  Widget readyApp(AppDatabase db, {required bool healthy}) => buildTestApp(
        db: db,
        home: const SettingsScreen(),
        overrides: [
          supabaseReadyProvider.overrideWithValue(true),
          supabaseClientProvider.overrideWithValue(null),
          serverHealthProvider.overrideWith((ref) async => healthy),
        ],
      );

  /// Scrollt zum Serverstatus. Nötig, seit die Darstellungs-Sektion um die
  /// Farbthema-Auswahl gewachsen ist (#58): Was im 600-px-Testfenster unter
  /// der Kante liegt, baut die ListView gar nicht erst.
  Future<void> scrollToConnect(WidgetTester tester) => tester.scrollUntilVisible(
        find.text('Server erreichbar'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('Server erreichbar: grüner Status vor dem Login',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sync_enabled': true});
    await tester.pumpWidget(readyApp(db, healthy: true));
    await tester.pumpAndSettle();

    await scrollToConnect(tester);

    expect(find.text('Server erreichbar'), findsOneWidget);
  });

  testWidgets('Server nicht erreichbar: roter Status mit Netzwerk-Hinweis',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sync_enabled': true});
    await tester.pumpWidget(readyApp(db, healthy: false));
    await tester.pumpAndSettle();

    expect(find.text('Server nicht erreichbar'), findsOneWidget);
    expect(find.textContaining('Internetverbindung'), findsOneWidget);
  });

  // ── Vorab-Kanal (Issue #169) ────────────────────────────────────────────

  testWidgets('Vorabversionen: Schalter ist da und ab Werk aus',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester
        .pumpWidget(buildTestApp(db: db, home: const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.text('Vorabversionen erhalten'), 200,
        scrollable: find.byType(Scrollable).first);

    final schalter = tester.widget<SwitchListTile>(find.ancestor(
        of: find.text('Vorabversionen erhalten'),
        matching: find.byType(SwitchListTile)));
    expect(schalter.value, isFalse);
    // Der Untertitel ist die halbe Funktion: Wer ihn kürzt, verspricht der
    // Wehr etwas, das der Schalter nicht hält.
    expect(find.textContaining('Gilt nur für dieses Gerät'), findsOneWidget);
  });

  testWidgets('Vorabversionen: Umlegen merkt sich die Wahl', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester
        .pumpWidget(buildTestApp(db: db, home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Vorabversionen erhalten'), 200,
        scrollable: find.byType(Scrollable).first);

    await tester.tap(find.text('Vorabversionen erhalten'));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<SwitchListTile>(find.ancestor(
                of: find.text('Vorabversionen erhalten'),
                matching: find.byType(SwitchListTile)))
            .value,
        isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('prerelease_updates'), isTrue);
  });

  testWidgets('Vorabversionen: kein Schalter, wo es keine Updates gibt',
      (tester) async {
    // Ein Schalter ohne Wirkung wäre ein Versprechen, das niemand einlöst.
    //
    // ⚠️ Das Zurücksetzen gehört in den Testrumpf, NICHT in addTearDown:
    // testWidgets prüft die Foundation-Debug-Variablen am Ende des Rumpfes,
    // also bevor tearDown läuft — der Test scheitert sonst mit „The value of
    // a foundation debug variable was changed by the test".
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    try {
      await tester
          .pumpWidget(buildTestApp(db: db, home: const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vorabversionen erhalten'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
