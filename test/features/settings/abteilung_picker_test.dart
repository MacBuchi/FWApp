/// abteilung_picker_test.dart – Abteilungs-Kachel und Auswahl-Sheet
/// (Issue #57 Phase 2).
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/widgets/abteilung_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

const _own = AbteilungInfo(
    id: 'A', name: 'Stadtmitte', status: 'active', gesamtwehrName: 'Musterstadt');
const _sister = AbteilungInfo(
    id: 'B', name: 'Nord', status: 'active', gesamtwehrName: 'Musterstadt');

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Widget host(List<AbteilungInfo> list) => buildTestApp(
        db: db,
        home: const Scaffold(body: AbteilungTile()),
        overrides: [
          abteilungenProvider.overrideWith((ref) async => list),
          myAbteilungIdProvider.overrideWith((ref) async => 'A'),
          supabaseClientProvider.overrideWithValue(null),
        ],
      );

  testWidgets('ohne Abteilungen bleibt die Kachel unsichtbar',
      (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('zeigt die eigene Abteilung mit Gesamtwehr-Kontext',
      (tester) async {
    await tester.pumpWidget(host(const [_own, _sister]));
    await tester.pumpAndSettle();
    expect(find.text('Stadtmitte · Musterstadt'), findsOneWidget);
    expect(find.textContaining('Deine Abteilung'), findsOneWidget);
  });

  testWidgets('Wechsel zur Schwester: nur lesen, Wahl wird gemerkt',
      (tester) async {
    await tester.pumpWidget(host(const [_own, _sister]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('Abteilung wählen'), findsOneWidget);

    await tester.tap(find.text('Nord · Musterstadt'));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(selectedAbteilungIdProvider), 'B');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSelectedAbteilungPref), 'B');
    // Kachel zeigt den Lese-Status, die Snackbar bestätigt den Wechsel.
    expect(find.text('Schwester-Abteilung — nur lesen'), findsOneWidget);
    expect(find.textContaining('Der Bestand wird geladen'), findsOneWidget);
  });

  testWidgets('zurück zur eigenen: Auswahl wird zu null (Datei-Invariante)',
      (tester) async {
    await tester.pumpWidget(host(const [_own, _sister]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord · Musterstadt'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stadtmitte · Musterstadt').last);
    await tester.pumpAndSettle();

    // Eigene Abteilung heißt null — NICHT 'A': Nur so bleibt die
    // angestammte Datenbank-Datei in Benutzung.
    expect(containerOf(tester).read(selectedAbteilungIdProvider), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSelectedAbteilungPref), isNull);
  });
}
