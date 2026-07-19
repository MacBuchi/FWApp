/// settings_screen_widget_test.dart – Settings states: sync section and the
/// restart hint when credentials are configured but not yet active.
library;
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

  testWidgets('Server erreichbar: grüner Status vor dem Login',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sync_enabled': true});
    await tester.pumpWidget(readyApp(db, healthy: true));
    await tester.pumpAndSettle();

    expect(find.text('Server erreichbar'), findsOneWidget);
    expect(find.text('Mit Abteilung verbinden'), findsOneWidget);
  });

  testWidgets('Server nicht erreichbar: roter Status mit Netzwerk-Hinweis',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sync_enabled': true});
    await tester.pumpWidget(readyApp(db, healthy: false));
    await tester.pumpAndSettle();

    expect(find.text('Server nicht erreichbar'), findsOneWidget);
    expect(find.textContaining('Internetverbindung'), findsOneWidget);
  });

  testWidgets('Login-Dialog erklärt die fehlende Registrierung',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sync_enabled': true});
    await tester.pumpWidget(readyApp(db, healthy: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mit Abteilung verbinden'));
    await tester.pumpAndSettle();

    expect(find.text('Anmelden'), findsWidgets);
    expect(find.textContaining('Keine Registrierung nötig'), findsOneWidget);
  });

  testWidgets('Login-Dialog fragt nach dem Nutzernamen (M7 Etappe 3)',
      (tester) async {
    SharedPreferences.setMockInitialValues({'sync_enabled': true});
    await tester.pumpWidget(readyApp(db, healthy: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mit Abteilung verbinden'));
    await tester.pumpAndSettle();

    expect(find.text('Nutzername'), findsOneWidget);
    expect(find.text('E-Mail'), findsNothing);
  });
}
