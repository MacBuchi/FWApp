/// home_banners_test.dart – Update-/Feedback-/Absturz-Banner auf dem
/// Dashboard: Sichtbarkeitsbedingungen, Wegklicken, Dialoge und Validierung.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/crash/crash_report.dart';
import 'package:fwapp/core/crash/crash_store.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/update/update_check.dart';
import 'package:fwapp/features/home/presentation/widgets/home_banners.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

/// Minimal-Session, damit der Feedback-Banner "angemeldet" sieht.
Session fakeSession() => Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: const User(
        id: '00000000-0000-0000-0000-000000000001',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        email: 'tester@fw.local',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );

const _update = UpdateInfo(
  latestVersion: '9.9.9',
  downloadUrl: 'https://example.invalid/fwapp.apk',
  releaseNotes: 'Testnotizen',
);

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget app({
    UpdateInfo? update,
    bool signedIn = false,
    List<CrashReport> crashes = const [],
  }) =>
      buildTestApp(
        db: db,
        home: Scaffold(body: ListView(children: const [HomeBanners()])),
        overrides: [
          updateInfoProvider.overrideWith((ref) async => update),
          supabaseReadyProvider.overrideWithValue(signedIn),
          supabaseClientProvider.overrideWithValue(null),
          pendingCrashesProvider.overrideWith((ref) async => crashes),
          if (signedIn)
            sessionStreamProvider
                .overrideWith((ref) => Stream.value(fakeSession())),
        ],
      );

  CrashReport crashWith({String fingerprint = 'abc12345'}) => CrashReport(
        time: DateTime.utc(2026, 7, 31, 12),
        appVersion: '1.4.9 (Build 17)',
        source: 'Async',
        error: 'StateError: kaputt',
        stackTrace: '#0 irgendwo (package:fwapp/datei.dart:1:1)',
        fingerprint: fingerprint,
      );
  final crash = crashWith();

  testWidgets('Ohne Update und ohne Login: keine Banner', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Update auf'), findsNothing);
    expect(find.text('Wunsch oder Fehler melden'), findsNothing);
  });

  testWidgets('Update verfügbar: Banner sichtbar und wegklickbar',
      (tester) async {
    await tester.pumpWidget(app(update: _update));
    await tester.pumpAndSettle();

    expect(find.text('Update auf v9.9.9 verfügbar'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Update auf v9.9.9 verfügbar'), findsNothing);
  });

  testWidgets('Update-Banner öffnet den Dialog mit Release-Notes',
      (tester) async {
    await tester.pumpWidget(app(update: _update));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update auf v9.9.9 verfügbar'));
    await tester.pumpAndSettle();

    expect(find.text('Update auf v9.9.9'), findsOneWidget);
    expect(find.text('Jetzt aktualisieren'), findsOneWidget);
    expect(find.text('Testnotizen'), findsOneWidget);

    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();
    expect(find.text('Jetzt aktualisieren'), findsNothing);
  });

  testWidgets('Angemeldet: Feedback-Banner öffnet Dialog mit vier Arten',
      (tester) async {
    await tester.pumpWidget(app(signedIn: true));
    await tester.pumpAndSettle();

    expect(find.text('Wunsch oder Fehler melden'), findsOneWidget);

    await tester.tap(find.text('Wunsch oder Fehler melden'));
    await tester.pumpAndSettle();

    expect(find.text('Wünsch dir was!'), findsOneWidget);
    expect(find.text('💡 Wunsch'), findsOneWidget);
    expect(find.text('🐛 Fehler'), findsOneWidget);
    // Die beiden Inhalts-Vorschläge (Issue #145).
    expect(find.text('🚒 Fahrzeug-Vorlage'), findsOneWidget);
    expect(find.text('🧰 Standard-Gerät'), findsOneWidget);
    // Öffentlichkeits-Hinweis (Feedback wird GitHub-Issue).
    expect(find.textContaining('öffentlich'), findsOneWidget);
  });

  testWidgets('der Fahrzeug-Vorschlag erklärt die Erste-Zeile-Regel',
      (tester) async {
    // Der Bot baut die Issue-Überschrift aus der ersten Zeile — wer das
    // nicht weiß, schreibt die Überschrift mitten in den Fließtext.
    await tester.pumpWidget(app(signedIn: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wunsch oder Fehler melden'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('🚒 Fahrzeug-Vorlage'));
    await tester.pumpAndSettle();
    expect(find.textContaining('erste Zeile ist der Typ'), findsOneWidget);
    expect(find.text('Fahrzeugtyp und Geräteräume'), findsOneWidget);

    await tester.tap(find.text('🧰 Standard-Gerät'));
    await tester.pumpAndSettle();
    expect(find.textContaining('erste Zeile ist der Gerätename'),
        findsOneWidget);
  });

  testWidgets('Feedback-Dialog verlangt mindestens 3 Zeichen',
      (tester) async {
    await tester.pumpWidget(app(signedIn: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wunsch oder Fehler melden'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.tap(find.text('Senden'));
    await tester.pumpAndSettle();

    expect(find.textContaining('paar Worte mehr'), findsOneWidget);
    // Dialog bleibt offen.
    expect(find.text('Wünsch dir was!'), findsOneWidget);
  });

  // ── Absturz-Banner (Issue #34) ──────────────────────────────

  testWidgets('Ohne Absturz kein Absturz-Banner', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('Problem'), findsNothing);
  });

  testWidgets('Absturz zeigt das Banner — auch ohne Login', (tester) async {
    // Wichtig: nicht angemeldet. Nach einem Absturz ist eine Serververbindung
    // gerade nicht garantiert; das Banner darf davon nicht abhängen.
    await tester.pumpWidget(app(crashes: [crash]));
    await tester.pumpAndSettle();

    expect(find.text('Die App hatte zuletzt ein Problem'), findsOneWidget);
  });

  testWidgets('Mehrere verschiedene Abstürze werden gezählt', (tester) async {
    await tester.pumpWidget(app(crashes: [
      crashWith(fingerprint: 'aa'),
      crashWith(fingerprint: 'bb'),
      crashWith(fingerprint: 'cc'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Die App hatte zuletzt 3 Probleme'), findsOneWidget);
  });

  testWidgets('Dialog zeigt Version und Stacktrace', (tester) async {
    await tester.pumpWidget(app(crashes: [crash]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Die App hatte zuletzt ein Problem'));
    await tester.pumpAndSettle();

    expect(find.text('Problem melden'), findsOneWidget);
    expect(find.textContaining('1.4.9 (Build 17)'), findsOneWidget);
    expect(find.textContaining('StateError: kaputt'), findsOneWidget);
    // Die Datenschutz-Zusage muss zum tatsächlichen Inhalt passen: Seit dem
    // Kontextfeld stehen Android-Version und Sprache im Bericht.
    expect(find.textContaining('keine Namen, Zugangsdaten'), findsOneWidget);
  });

  testWidgets('Ohne Login ist "Melden" gesperrt, "Kopieren" nicht',
      (tester) async {
    await tester.pumpWidget(app(crashes: [crash]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Die App hatte zuletzt ein Problem'));
    await tester.pumpAndSettle();

    final melden = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Melden'));
    expect(melden.onPressed, isNull, reason: 'Melden braucht eine Session');

    final kopieren = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Kopieren'));
    expect(kopieren.onPressed, isNotNull,
        reason: 'Kopieren ist der Weg ohne Server und muss offen bleiben');
  });

  testWidgets('"Kopieren" legt den Bericht in die Zwischenablage',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(app(crashes: [crash]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Die App hatte zuletzt ein Problem'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kopieren'));
    await tester.pumpAndSettle();

    expect(copied, contains('StateError: kaputt'));
    expect(copied, contains('1.4.9 (Build 17)'));
  });

  testWidgets('Angemeldet ist "Melden" freigeschaltet', (tester) async {
    await tester.pumpWidget(app(signedIn: true, crashes: [crash]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Die App hatte zuletzt ein Problem'));
    await tester.pumpAndSettle();

    final melden = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Melden'));
    expect(melden.onPressed, isNotNull);
  });

  testWidgets('Absturz-Banner steht über Update- und Feedback-Banner',
      (tester) async {
    await tester.pumpWidget(
        app(update: _update, signedIn: true, crashes: [crash]));
    await tester.pumpAndSettle();

    final crashY =
        tester.getTopLeft(find.text('Die App hatte zuletzt ein Problem')).dy;
    final updateY =
        tester.getTopLeft(find.text('Update auf v9.9.9 verfügbar')).dy;
    final feedbackY =
        tester.getTopLeft(find.text('Wunsch oder Fehler melden')).dy;

    expect(crashY, lessThan(updateY));
    expect(updateY, lessThan(feedbackY));
  });
}
