/// user_management_abteilung_test.dart – Abteilung in der Nutzerverwaltung
/// (Issue #57 Phase 3, Nachzügler).
///
/// Der eigentliche Mandanten-Schutz sitzt in der Edge Function (sie prüft
/// serverseitig, dass die Ziel-Abteilung zur Gesamtwehr des Aufrufers
/// gehört). Hier wird geprüft, was der Screen anbietet und anzeigt — ein
/// Menüeintrag, der nichts zu wählen hat, ist eine Sackgasse.
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/providers/user_admin_providers.dart';
import 'package:fwapp/features/settings/presentation/screens/user_management_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

const _stadt = AbteilungInfo(
    id: 'A', name: '01 - Stadt', status: 'active', gesamtwehrName: 'BR');
const _grombach = AbteilungInfo(
    id: 'B', name: '05 - Grombach', status: 'active', gesamtwehrName: 'BR');

ManagedUser _user({String? abteilungId = 'A', String role = 'geraetewart'}) =>
    ManagedUser(
      id: 'u1',
      username: 'wart.grombach',
      email: 'wart.grombach@fw.local',
      role: role,
      mustChangePassword: false,
      banned: false,
      lastSignInAt: null,
      abteilungId: abteilungId,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget host({
    required List<AbteilungInfo> abteilungen,
    ManagedUser? user,
  }) =>
      buildTestApp(
        db: db,
        home: const UserManagementScreen(),
        overrides: [
          managedUsersProvider.overrideWith((ref) async => [user ?? _user()]),
          abteilungenProvider.overrideWith((ref) async => abteilungen),
          myAbteilungIdProvider.overrideWith((ref) async => 'A'),
          supabaseClientProvider.overrideWithValue(null),
        ],
      );

  testWidgets('die Abteilung steht in der Kontozeile', (tester) async {
    await tester.pumpWidget(host(abteilungen: const [_stadt, _grombach]));
    await tester.pumpAndSettle();

    expect(find.textContaining('01 - Stadt'), findsOneWidget);
  });

  testWidgets('ein Konto einer fremden Gesamtwehr wird als solches benannt',
      (tester) async {
    // RLS zeigt uns diese Abteilung nicht. „ohne Abteilung“ wäre gelogen
    // und würde zu einer falschen Korrektur verleiten.
    await tester.pumpWidget(host(
      abteilungen: const [_stadt, _grombach],
      user: _user(abteilungId: 'FREMD'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('andere Gesamtwehr'), findsOneWidget);
  });

  testWidgets('Konto ohne Abteilung wird benannt, nicht verschwiegen',
      (tester) async {
    await tester.pumpWidget(host(
      abteilungen: const [_stadt, _grombach],
      user: _user(abteilungId: null),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('ohne Abteilung'), findsOneWidget);
  });

  testWidgets('mit mehreren Abteilungen gibt es den Menüeintrag',
      (tester) async {
    await tester.pumpWidget(host(abteilungen: const [_stadt, _grombach]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Abteilung ändern'), findsOneWidget);
  });

  testWidgets('bei nur einer Abteilung bleibt der Eintrag weg (keine Wahl)',
      (tester) async {
    await tester.pumpWidget(host(abteilungen: const [_stadt]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Abteilung ändern'), findsNothing);
    // Die übrigen Einträge bleiben selbstverständlich erreichbar.
    expect(find.text('Rolle ändern'), findsOneWidget);
  });

  testWidgets('auf einem Legacy-Server ohne Abteilungen bleibt alles beim Alten',
      (tester) async {
    await tester.pumpWidget(host(abteilungen: const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('ohne Abteilung'), findsNothing,
        reason: 'ohne Mandanten-Schema ist die Angabe bedeutungslos');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Abteilung ändern'), findsNothing);
  });

  testWidgets('der Ändern-Dialog wählt die aktuelle Abteilung vor',
      (tester) async {
    await tester.pumpWidget(host(
      abteilungen: const [_stadt, _grombach],
      user: _user(abteilungId: 'B'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abteilung ändern'));
    await tester.pumpAndSettle();

    expect(find.textContaining('wart.grombach'), findsWidgets);
    // Der Dropdown zeigt den Ist-Zustand, nicht blind den ersten Eintrag.
    expect(find.text('05 - Grombach'), findsWidgets);
  });

  group('abteilungsName', () {
    test('bekannte Id wird zum Namen, unbekannte zur ehrlichen Auskunft', () {
      const bekannt = [_stadt, _grombach];
      expect(abteilungsName('A', bekannt), '01 - Stadt');
      expect(abteilungsName('B', bekannt), '05 - Grombach');
      expect(abteilungsName('X', bekannt), 'andere Gesamtwehr');
      expect(abteilungsName(null, bekannt), 'ohne Abteilung');
    });
  });
}
