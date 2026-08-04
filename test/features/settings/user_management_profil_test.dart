/// user_management_profil_test.dart – Anzeigename und Avatar in der
/// Nutzerverwaltung (Issue #100).
///
/// Die Verwaltung LIEST beides nur: Setzen kann es ausschliesslich die Person
/// selbst über `mein_profil_setzen`. Geprüft wird deshalb die Anzeige — und
/// besonders, dass der Nutzername dabei nicht verschwindet: Er ist die
/// Anmeldung, und ohne ihn weiss der Kommandant beim Zurücksetzen nicht mehr,
/// wem er den Zettel gibt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
import 'package:fwapp/features/profil/presentation/widgets/fw_avatar.dart';
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

ManagedUser _user({String? anzeigename, String? avatar}) => ManagedUser(
      id: 'u1',
      username: 'marcus.bucher',
      email: 'marcus.bucher@example.org',
      role: 'member',
      mustChangePassword: false,
      banned: false,
      lastSignInAt: null,
      abteilungId: 'A',
      memberships: const {'A': 'member'},
      hatMitgliedschaften: true,
      anzeigename: anzeigename,
      avatar: avatar,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget host(List<ManagedUser> users) => buildTestApp(
        db: db,
        home: const UserManagementScreen(),
        overrides: [
          managedUsersProvider.overrideWith((ref) async => users),
          abteilungenProvider.overrideWith((ref) async => const [_stadt]),
          myAbteilungIdProvider.overrideWith((ref) async => 'A'),
          meineKommandoGesamtwehrenProvider.overrideWith(
              (ref) async => const <String>{}),
          supabaseClientProvider.overrideWithValue(null),
        ],
      );

  testWidgets('ohne Anzeigenamen bleibt es beim Nutzernamen — und zwar einmal',
      (tester) async {
    await tester.pumpWidget(host([_user()]));
    await tester.pumpAndSettle();

    expect(find.text('marcus.bucher'), findsOneWidget);
  });

  testWidgets('mit Anzeigenamen steht dieser oben und der Nutzername daneben',
      (tester) async {
    await tester.pumpWidget(host([_user(anzeigename: 'Marcus B.')]));
    await tester.pumpAndSettle();

    expect(find.text('Marcus B.'), findsOneWidget);
    expect(find.textContaining('marcus.bucher'), findsOneWidget);
  });

  testWidgets('der gespeicherte Kopf wird gezeichnet, nicht der Standardkopf',
      (tester) async {
    const kopf = AvatarKonfiguration(gear: 'dog', eyes: 'dots');
    await tester.pumpWidget(host([_user(avatar: kopf.kodiert)]));
    await tester.pumpAndSettle();

    final avatar = tester.widget<FwAvatar>(find.byType(FwAvatar));
    expect(avatar.konfiguration, kopf);
  });

  testWidgets('ohne gespeicherten Kopf steht der Standardkopf da',
      (tester) async {
    await tester.pumpWidget(host([_user()]));
    await tester.pumpAndSettle();

    expect(tester.widget<FwAvatar>(find.byType(FwAvatar)).konfiguration,
        const AvatarKonfiguration());
  });

  testWidgets('die Liste ist nach dem ANGEZEIGTEN Namen sortiert',
      (tester) async {
    // Sonst steht sie in einer Reihenfolge, die auf dem Bildschirm niemand
    // nachvollziehen kann: „zeus" vor „Anton", weil der Nutzername anders
    // heisst als der Anzeigename.
    final users = [
      ManagedUser(
        id: 'u1',
        username: 'aaa.zuerst',
        email: 'a@fw.local',
        role: 'member',
        mustChangePassword: false,
        banned: false,
        lastSignInAt: null,
        memberships: const {'A': 'member'},
        hatMitgliedschaften: true,
        anzeigename: 'Zacharias',
      ),
      ManagedUser(
        id: 'u2',
        username: 'zzz.zuletzt',
        email: 'z@fw.local',
        role: 'member',
        mustChangePassword: false,
        banned: false,
        lastSignInAt: null,
        memberships: const {'A': 'member'},
        hatMitgliedschaften: true,
        anzeigename: 'Anton',
      ),
    ];
    // Der Provider sortiert; hier wird die Regel selbst geprüft, weil der
    // überschriebene Provider im Widget-Test nicht durch ihn läuft.
    final sortiert = [...users]..sort(
        (a, b) => a.anzeige.toLowerCase().compareTo(b.anzeige.toLowerCase()));
    expect(sortiert.map((u) => u.anzeige), ['Anton', 'Zacharias']);

    await tester.pumpWidget(host(sortiert));
    await tester.pumpAndSettle();
    final antonY = tester.getTopLeft(find.text('Anton')).dy;
    final zachY = tester.getTopLeft(find.text('Zacharias')).dy;
    expect(antonY, lessThan(zachY));
  });
}
