/// user_management_teilen_test.dart – Der Demo-Zugang muss dort sein, wo
/// jemand ihn sucht (Issue #165).
///
/// Der Text der Nachricht steht in `zugang_teilen_test.dart`; hier geht es
/// nur um die Verdrahtung. Genau die ist in diesem Screen schon einmal
/// danebengegangen: Beim Einsortieren mehrerer Geräte (#149) hing die Aktion
/// an EINER von ZWEI Stellen, die dieselbe Liste zeigten, und der Testpfad
/// lief in die falsche. Ein Knopf, den niemand findet, ist kein Knopf.
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

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('der Demo-Zugang steht neben dem Einladen', (tester) async {
    // Grosse Pruefflaeche: Bei 800x600 rutscht der Einladungs-Abschnitt aus
    // dem Bild, und `find` liefert dann zwar einen Treffer, ein `tap` liefe
    // aber ins Leere — mit einer Warnung im Log statt eines roten Tests.
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(
      db: db,
      home: const UserManagementScreen(),
      overrides: [
        managedUsersProvider.overrideWith((ref) async => const <ManagedUser>[]),
        abteilungenProvider.overrideWith((ref) async => const [_stadt]),
        myAbteilungIdProvider.overrideWith((ref) async => 'A'),
        meineKommandoGesamtwehrenProvider
            .overrideWith((ref) async => const <String>{}),
        supabaseClientProvider.overrideWithValue(null),
      ],
    ));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Demo-Zugang teilen'),
      findsOneWidget,
      reason: 'Der Demo-Zugang gehoert neben „Einladen": Dort sucht der '
          'Kommandant, wenn er jemanden dazuholen will — und der Blick in '
          'die Demo ist der kleinere Schritt davor.',
    );
    expect(find.text('Einladen'), findsOneWidget);
  });
}
