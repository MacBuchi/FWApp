/// login_gate_widget_test.dart – Der Beweis, dass der Anmeldezwang wirkt
/// (Issue #57 Phase 4, Etappe 2).
///
/// Die Regeln selbst prüft app_router_guard_test.dart als reine Funktion.
/// Hier läuft der ECHTE Router: Er beantwortet die Frage, die eine reine
/// Funktion nicht beantworten kann — kommt der gesperrte Screen wirklich nie
/// auf den Bildschirm?
library;
import 'package:flutter/material.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/router/app_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/auth/presentation/screens/login_screen.dart';
import 'package:fwapp/features/home/presentation/screens/home_screen.dart';
import 'package:fwapp/features/settings/presentation/screens/server_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'sync_enabled': true});
    db = createTestDatabase();
  });

  tearDown(() async => db.close());

  /// Verbundene Installation ohne Sitzung. supabaseClientProvider bleibt
  /// null (kein echter Supabase-Client im Test), der Anmeldezustand kommt
  /// über den Callback — genau dafür ist er ein Callback.
  List<Override> ausgeloggt() => [
        supabaseReadyProvider.overrideWithValue(true),
        supabaseClientProvider.overrideWithValue(null),
        signedInReaderProvider.overrideWithValue(() => false),
        serverHealthProvider.overrideWith((ref) async => true),
      ];

  testWidgets('ohne Sitzung landet man auf der Anmeldung', (tester) async {
    await tester.pumpWidget(buildRoutedTestApp(db: db, overrides: ausgeloggt()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    // Die eigentliche Zusicherung: Die App dahinter wurde nie gebaut.
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    await endTestApp(tester);
  });

  testWidgets('auch ein Deep-Link kommt nicht an der Anmeldung vorbei',
      (tester) async {
    await tester.pumpWidget(buildRoutedTestApp(db: db, overrides: ausgeloggt()));
    await tester.pumpAndSettle();

    containerOf(tester).read(routerProvider).go('/import');
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('der Notausgang bleibt ohne Anmeldung erreichbar',
      (tester) async {
    await tester.pumpWidget(buildRoutedTestApp(db: db, overrides: ausgeloggt()));
    await tester.pumpAndSettle();

    // ensureVisible zuerst: Ein Tap außerhalb des sichtbaren Bereichs warnt
    // nur, statt zu scheitern — der Test liefe sonst stumm ins Leere.
    await tester.ensureVisible(find.text('Servereinstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Servereinstellungen'));
    await tester.pumpAndSettle();

    // Ohne diesen Weg säße jemand mit falscher Serveradresse fest.
    expect(find.byType(ServerSettingsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await endTestApp(tester);
  });

  testWidgets('containerOf findet den Scope trotz MaterialApp.router',
      (tester) async {
    // Absicherung des Test-Werkzeugs selbst: containerOf sucht nach
    // MaterialApp — das muss auch für die Router-Variante gelten.
    await tester.pumpWidget(buildRoutedTestApp(db: db, overrides: ausgeloggt()));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(supabaseReadyProvider), isTrue);
    await endTestApp(tester);
  });
}
