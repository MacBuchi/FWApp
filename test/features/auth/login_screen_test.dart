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
    // einzige Hinweis darauf, dass man sich hier NICHT registriert. Seit
    // Stufe 3 nennt er beide Wege — Einladung und Zugangszettel.
    expect(
        find.textContaining('Zugangszettel aus dem Gerätehaus'), findsOneWidget);
    expect(find.textContaining('Einladung'), findsWidgets);
    await endTestApp(tester);
  });

  testWidgets('führt vom Anmelden zur Einladung und wieder zurück',
      (tester) async {
    await pumpLogin(tester);
    // Ohne diesen Weg ist eine verschickte Einladung wertlos: Der Code aus
    // der Mail liesse sich nirgends eingeben.
    await tester.ensureVisible(find.text('Ich habe eine Einladung'));
    await tester.tap(find.text('Ich habe eine Einladung'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Code aus der Einladung'),
        findsOneWidget);
    expect(find.widgetWithText(TextField, 'E-Mail-Adresse'), findsOneWidget);
    // Passwort UND Wiederholung: Das Konto bekommt sein Passwort in einem Zug
    // mit dem Einlösen, sonst bliebe eine Sitzung ohne Passwort stehen.
    expect(find.byType(PasswordField), findsNWidgets(2));

    await tester.ensureVisible(find.text('Zurück zur Anmeldung'));
    await tester.tap(find.text('Zurück zur Anmeldung'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Nutzername'), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('nach dem Wechsel hat das erste Feld der neuen Ansicht den Fokus',
      (tester) async {
    // ⚠️ DIESER TEST BEWEIST DEN FIX NICHT — er hält nur fest, dass das
    // erste Feld am Ende Fokus hat. Gegenprobe gemacht: Ohne den
    // ausdrücklichen Fokuswechsel in `_wechsle` bleibt er GRÜN, weil im
    // Widget-Test `autofocus: true` greift. Genau das tut es im Browser
    // nicht, und dort hängt daran das DOM-Formular für den Passwortmanager
    // (#120). Der Beweis dafür ist die Messung im Browser (im PR belegt:
    // ohne Fokuswechsel 0 Formulare nach dem Moduswechsel, mit ihm eines
    // mit beiden `new-password`-Feldern) — nicht dieser Test.
    await pumpLogin(tester);
    await tester.ensureVisible(find.text('Ich habe eine Einladung'));
    await tester.tap(find.text('Ich habe eine Einladung'));
    await tester.pumpAndSettle();

    final mail = tester.widget<TextField>(
        find.widgetWithText(TextField, 'E-Mail-Adresse'));
    expect(mail.focusNode?.hasFocus, isTrue,
        reason: 'Das Adressfeld der Einladungs-Ansicht muss den Fokus haben');
    await endTestApp(tester);
  });

  testWidgets('jede Ansicht bekommt ihre eigene AutofillGroup', (tester) async {
    // Der Schlüssel wirft die Gruppe beim Wechsel weg. Ohne ihn behält
    // Flutter den einmal aufgebauten Autofill-Kontext der Anmeldung bei
    // (#120) — dann trägt das DOM-Formular `username`/`current-password`,
    // während man ein neues Passwort setzen will.
    await pumpLogin(tester);
    final vorher = tester.widget<AutofillGroup>(find.byType(AutofillGroup)).key;
    expect(vorher, isNotNull, reason: 'ohne Schlüssel wird nie neu aufgebaut');

    await tester.ensureVisible(find.text('Ich habe eine Einladung'));
    await tester.tap(find.text('Ich habe eine Einladung'));
    await tester.pumpAndSettle();

    final nachher = tester.widget<AutofillGroup>(find.byType(AutofillGroup)).key;
    expect(nachher, isNot(vorher),
        reason: 'ein anderer Modus muss eine andere Gruppe ergeben');
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

  group('Passwort vergessen (Etappe 2)', () {
    Future<void> zumAdressmodus(WidgetTester tester) async {
      await pumpLogin(tester, client: toterClient());
      await tester.ensureVisible(find.text('Passwort vergessen?'));
      await tester.tap(find.text('Passwort vergessen?'));
      await tester.pumpAndSettle();
    }

    testWidgets('der Weg dorthin fragt nur nach der Adresse', (tester) async {
      await zumAdressmodus(tester);

      expect(find.widgetWithText(TextField, 'E-Mail-Adresse'), findsOneWidget);
      // Gegenprobe im Test selbst: Die Anmeldefelder sind weg, nicht nur
      // überdeckt — sonst könnte man versehentlich ins Leere tippen.
      expect(find.widgetWithText(TextField, 'Nutzername'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Code anfordern'),
          findsOneWidget);
      await endTestApp(tester);
    });

    testWidgets('sagt ehrlich, für wen das funktioniert', (tester) async {
      await zumAdressmodus(tester);
      // Ein Zettel-Konto hat keine erreichbare Adresse; das muss dastehen,
      // sonst wartet jemand auf eine Mail, die nie kommt.
      expect(find.textContaining('Admins und Gerätewarte'), findsOneWidget);
      await endTestApp(tester);
    });

    testWidgets('unvollständige Adresse wird abgefangen', (tester) async {
      await zumAdressmodus(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'E-Mail-Adresse'), 'nurname');
      await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Code anfordern'));
      await tester.tap(find.widgetWithText(FilledButton, 'Code anfordern'));
      await tester.pump();

      expect(find.textContaining('vollständige E-Mail-Adresse'), findsOneWidget);
      // Und der Modus bleibt stehen — kein Sprung in die Code-Eingabe.
      expect(find.widgetWithText(TextField, 'Code aus der E-Mail'),
          findsNothing);
      await endTestApp(tester);
    });

    testWidgets('zurück zur Anmeldung führt wirklich zurück', (tester) async {
      await zumAdressmodus(tester);
      await tester.ensureVisible(find.text('Zurück zur Anmeldung'));
      await tester.tap(find.text('Zurück zur Anmeldung'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Nutzername'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'E-Mail-Adresse'), findsNothing);
      await endTestApp(tester);
    });
  });
}
