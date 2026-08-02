/// user_management_memberships_test.dart – Nutzerverwaltung mit
/// Mitgliedschaften (Nutzerkonzept Stufe 1, Issue #98): Anzeige der Rollen
/// je Abteilung, der Mitgliedschafts-Dialog und der Kommandanten-Eintrag.
///
/// Die Hierarchie-Regeln (wer darf was vergeben) erzwingt die Edge
/// Function serverseitig — hier geht es darum, was der Screen anbietet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/providers/user_admin_providers.dart';
import 'package:fwapp/features/settings/presentation/screens/user_management_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

const _stadt = AbteilungInfo(
  id: 'A',
  name: '01 - Stadt',
  status: 'active',
  gesamtwehrId: 'GW',
  gesamtwehrName: 'BR',
);
const _grombach = AbteilungInfo(
  id: 'B',
  name: '05 - Grombach',
  status: 'active',
  gesamtwehrId: 'GW',
  gesamtwehrName: 'BR',
);

ManagedUser _user({
  Map<String, String> memberships = const {'A': 'geraetewart'},
  List<String> kommandant = const [],
}) => ManagedUser(
  id: 'u1',
  username: 'wart.stadt',
  email: 'wart.stadt@fw.local',
  role: 'geraetewart',
  mustChangePassword: false,
  banned: false,
  lastSignInAt: null,
  abteilungId: 'A',
  memberships: memberships,
  kommandantGesamtwehren: kommandant,
  hatMitgliedschaften: true,
);

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget host({
    ManagedUser? user,
    Set<String> meineKommandos = const {},
    List<AbteilungInfo> abteilungen = const [_stadt, _grombach],
  }) => buildTestApp(
    db: db,
    home: const UserManagementScreen(),
    overrides: [
      managedUsersProvider.overrideWith((ref) async => [user ?? _user()]),
      abteilungenProvider.overrideWith((ref) async => abteilungen),
      myAbteilungIdProvider.overrideWith((ref) async => 'A'),
      meineKommandoGesamtwehrenProvider.overrideWith(
        (ref) async => meineKommandos,
      ),
      supabaseClientProvider.overrideWithValue(null),
    ],
  );

  testWidgets('Mitgliedschafts-Server: EIN Dialog statt zweier Einzelwege', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Rollen & Abteilungen'), findsOneWidget);
    expect(find.text('Rolle ändern'), findsNothing);
    expect(find.text('Abteilung ändern'), findsNothing);
  });

  testWidgets('Rollen stehen je Abteilung in der Kontozeile', (tester) async {
    await tester.pumpWidget(
      host(user: _user(memberships: {'A': 'geraetewart', 'B': 'member'})),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Gerätewart (01 - Stadt)'), findsOneWidget);
    expect(find.textContaining('Truppmann (05 - Grombach)'), findsOneWidget);
  });

  testWidgets('ein Feuerwehrkommandant wird als solcher gezeigt', (
    tester,
  ) async {
    await tester.pumpWidget(host(user: _user(kommandant: const ['GW'])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Feuerwehrkommandant'), findsOneWidget);
  });

  testWidgets('der Mitgliedschafts-Dialog zeigt jede Abteilung mit Rolle', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rollen & Abteilungen'));
    await tester.pumpAndSettle();

    expect(find.text('Rollen von „wart.stadt“'), findsOneWidget);
    expect(find.text('01 - Stadt'), findsOneWidget);
    expect(find.text('05 - Grombach'), findsOneWidget);
    // Abteilung ohne Mitgliedschaft steht auf „– keine –".
    expect(find.text('– keine –'), findsOneWidget);
  });

  group('Kommandanten-Eintrag', () {
    testWidgets('erscheint nur für Kommandanten der passenden Gesamtwehr', (
      tester,
    ) async {
      await tester.pumpWidget(host(meineKommandos: const {'GW'}));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Zum Feuerwehrkommandanten ernennen'), findsOneWidget);
    });

    testWidgets('wird zum Entlassen, wenn das Ziel schon Kommandant ist', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          user: _user(kommandant: const ['GW']),
          meineKommandos: const {'GW'},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Als Feuerwehrkommandant entlassen'), findsOneWidget);
    });

    testWidgets('fehlt ohne eigene Kommandanten-Stellung', (tester) async {
      await tester.pumpWidget(host(meineKommandos: const {}));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.textContaining('Feuerwehrkommandant'), findsNothing);
    });
  });
}
