/// home_banners_test.dart – Update-/Feedback-Banner auf dem Dashboard:
/// Sichtbarkeitsbedingungen, Wegklicken, Dialoge und Validierung.
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Widget app({UpdateInfo? update, bool signedIn = false}) => buildTestApp(
        db: db,
        home: Scaffold(body: ListView(children: const [HomeBanners()])),
        overrides: [
          updateInfoProvider.overrideWith((ref) async => update),
          supabaseReadyProvider.overrideWithValue(signedIn),
          supabaseClientProvider.overrideWithValue(null),
          if (signedIn)
            sessionStreamProvider
                .overrideWith((ref) => Stream.value(fakeSession())),
        ],
      );

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

  testWidgets('Angemeldet: Feedback-Banner öffnet Dialog mit Feature/Bug',
      (tester) async {
    await tester.pumpWidget(app(signedIn: true));
    await tester.pumpAndSettle();

    expect(find.text('Wunsch oder Fehler melden'), findsOneWidget);

    await tester.tap(find.text('Wunsch oder Fehler melden'));
    await tester.pumpAndSettle();

    expect(find.text('Wünsch dir was!'), findsOneWidget);
    expect(find.text('💡 Feature'), findsOneWidget);
    expect(find.text('🐛 Bug'), findsOneWidget);
    // Öffentlichkeits-Hinweis (Feedback wird GitHub-Issue).
    expect(find.textContaining('öffentlich'), findsOneWidget);
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
}
