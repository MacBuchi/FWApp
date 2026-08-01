/// login_screen_test.dart – Der Anmelde-Screen (Issue #57 Phase 4, Etappe 2).
///
/// Geprüft wird, was der Nutzer sieht und anfassen kann; ob der Screen
/// überhaupt erscheint, beweist login_gate_widget_test.dart.
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/widgets/password_field.dart';
import 'package:fwapp/features/auth/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'sync_enabled': true});
    db = createTestDatabase();
  });

  tearDown(() async => db.close());

  /// Ein Client, der ins Leere zeigt: Er beantwortet keine Anfrage, aber die
  /// Eingabeprüfungen davor laufen — sonst gewönne immer die Meldung
  /// „kein Server konfiguriert". autoRefreshToken aus, sonst hinterlässt der
  /// Client einen laufenden Timer und der Test scheitert am Aufräumen.
  SupabaseClient toterClient() => SupabaseClient('http://localhost:1', 'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false));

  Future<void> pumpLogin(WidgetTester tester, {SupabaseClient? client}) async {
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: const LoginScreen(),
      overrides: [
        supabaseReadyProvider.overrideWithValue(true),
        supabaseClientProvider.overrideWithValue(client),
        serverHealthProvider.overrideWith((ref) async => true),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('das Auge macht das Passwort sichtbar', (tester) async {
    await pumpLogin(tester);

    TextField passwortFeld() => tester.widget<TextField>(
        find.descendant(of: find.byType(PasswordField), matching: find.byType(TextField)));

    expect(passwortFeld().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(passwortFeld().obscureText, isFalse,
        reason: 'sichtbares Passwort ist der wirksamere Tippfehler-Schutz');
    await endTestApp(tester);
  });

  testWidgets('leere Eingabe meldet inline, nicht per SnackBar',
      (tester) async {
    await pumpLogin(tester, client: toterClient());

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.pump();

    expect(find.text('Bitte Nutzername und Passwort eingeben.'), findsOneWidget);
    // Eine SnackBar wäre hier falsch: Im Erfolgsfall räumt der Redirect den
    // Screen sofort ab, die Meldung liefe ins Leere.
    expect(find.byType(SnackBar), findsNothing);
    await endTestApp(tester);
  });

  testWidgets('ohne konfigurierten Server verweist der Fehler auf den Ausgang',
      (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Nutzername'), 'max');
    await tester.enterText(
        find.descendant(
            of: find.byType(PasswordField), matching: find.byType(TextField)),
        'geheim123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.pump();

    expect(find.textContaining('Servereinstellungen'), findsWidgets);
    await endTestApp(tester);
  });

  testWidgets('erklärt, woher die Zugangsdaten kommen', (tester) async {
    await pumpLogin(tester);
    // Der Satz stand vorher im Login-Dialog der Einstellungen und ist der
    // einzige Hinweis darauf, dass man sich hier NICHT registriert.
    expect(find.textContaining('Zugangszettel im Gerätehaus'), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('beide Felder liegen in einer AutofillGroup', (tester) async {
    await pumpLogin(tester);
    expect(find.byType(AutofillGroup), findsOneWidget);

    final nutzer = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Nutzername'));
    expect(nutzer.autofillHints, contains(AutofillHints.username));
    final passwort = tester.widget<TextField>(find.descendant(
        of: find.byType(PasswordField), matching: find.byType(TextField)));
    expect(passwort.autofillHints, contains(AutofillHints.password));
    await endTestApp(tester);
  });
}
