/// changelog_screen_test.dart – „Was ist neu?"-Screen (Issue #51).
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/changelog/changelog.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/settings/presentation/screens/changelog_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  const releases = [
    ChangelogRelease(
      version: '1.4.8',
      date: '2026-07-31',
      sections: [
        ChangelogSection(title: 'Behoben', entries: ['Ein behobener Fehler']),
      ],
    ),
    ChangelogRelease(
      version: '1.0.0',
      date: '2026-07-15',
      sections: [
        ChangelogSection(title: 'Neu', entries: ['Die erste Ausgabe']),
      ],
    ),
  ];

  testWidgets('zeigt die Versionen und klappt die neueste auf', (tester) async {
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: const ChangelogScreen(),
      overrides: [changelogProvider.overrideWith((ref) async => releases)],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Was ist neu?'), findsOneWidget);
    expect(find.text('Version 1.4.8'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);
    // Datum in deutscher Schreibweise.
    expect(find.text('31.07.2026'), findsOneWidget);
    // Der oberste Eintrag ist aufgeklappt, der ältere nicht.
    expect(find.text('Ein behobener Fehler'), findsOneWidget);
    expect(find.text('Die erste Ausgabe'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('klappt eine ältere Version auf Tipp auf', (tester) async {
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: const ChangelogScreen(),
      overrides: [changelogProvider.overrideWith((ref) async => releases)],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Version 1.0.0'));
    await tester.pumpAndSettle();

    expect(find.text('Die erste Ausgabe'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('bleibt bei leerer Änderungsliste bedienbar', (tester) async {
    // Ein kaputtes oder fehlendes Asset darf einen Hinweis zeigen, aber den
    // Screen nicht sprengen — changelogProvider fängt Fehler bewusst ab.
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: const ChangelogScreen(),
      overrides: [
        changelogProvider.overrideWith((ref) async => <ChangelogRelease>[]),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('nicht verfügbar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await endTestApp(tester);
  });
}
