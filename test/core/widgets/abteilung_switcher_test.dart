/// abteilung_switcher_test.dart – Die Abteilungs-Anzeige in der AppBar und
/// das gemeinsame Auswahl-Sheet (Issue #96).
///
/// Die Feld-Rückmeldung war dreiteilig: sehen WELCHE Abteilung, sehen OB es
/// die Heimat ist, und von dort aus wechseln können. Genau das prüfen die
/// Tests — plus die Rechte-Aussage, die seit Stufe ① nicht mehr aus „eigene
/// oder fremde Abteilung" folgt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

const _own = AbteilungInfo(
  id: 'A',
  name: 'Stadtmitte',
  status: 'active',
  gesamtwehrId: 'GW',
  gesamtwehrName: 'Musterstadt',
);
const _sister = AbteilungInfo(
  id: 'B',
  name: 'Nord',
  status: 'active',
  gesamtwehrId: 'GW',
  gesamtwehrName: 'Musterstadt',
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Widget host(
    List<AbteilungInfo> list, {
    String? selected,
    Map<String, String>? mitgliedschaften,
    Set<String>? kommandiert,
  }) => buildTestApp(
    db: db,
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Start'),
        actions: const [AbteilungAction()],
      ),
      body: const SizedBox.shrink(),
    ),
    overrides: [
      abteilungenProvider.overrideWith((ref) async => list),
      myAbteilungIdProvider.overrideWith((ref) async => 'A'),
      selectedAbteilungIdProvider.overrideWith((ref) => selected),
      meineMitgliedschaftenProvider.overrideWith((ref) async => mitgliedschaften),
      meineKommandoGesamtwehrenProvider.overrideWith((ref) async => kommandiert),
      supabaseClientProvider.overrideWithValue(null),
    ],
  );

  testWidgets('bei einer einzigen Abteilung bleibt die Leiste frei',
      (tester) async {
    await tester.pumpWidget(host(const [_own]));
    await tester.pumpAndSettle();
    expect(find.text('Stadtmitte'), findsNothing);
  });

  testWidgets('nennt die Heim-Abteilung beim Namen und zeigt das Heim-Symbol',
      (tester) async {
    await tester.pumpWidget(host(const [_own, _sister]));
    await tester.pumpAndSettle();

    expect(find.text('Stadtmitte'), findsOneWidget);
    expect(find.byIcon(Icons.home_work_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsNothing);
  });

  testWidgets('in der Schwester-Abteilung wechselt Symbol und Farbe',
      (tester) async {
    await tester.pumpWidget(host(const [_own, _sister], selected: 'B'));
    await tester.pumpAndSettle();

    expect(find.text('Nord'), findsOneWidget);
    // Das Symbol trägt die Aussage auch ohne Farbunterscheidung …
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.home_work_outlined), findsNothing);
    // … und der abgesetzte Hintergrund macht sie im Vorbeigehen sichtbar.
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AbteilungAction),
        matching: find.byType(Material),
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(AbteilungAction)),
    ).colorScheme;
    expect(material.color, scheme.tertiaryContainer);
  });

  testWidgets('Tippen öffnet die Wahl und wechselt die Abteilung',
      (tester) async {
    await tester.pumpWidget(host(const [_own, _sister]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AbteilungAction));
    await tester.pumpAndSettle();
    expect(find.text('Abteilung wählen'), findsOneWidget);

    await tester.tap(find.text('Nord · Musterstadt'));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(selectedAbteilungIdProvider), 'B');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSelectedAbteilungPref), 'B');
    expect(find.textContaining('Der Bestand wird geladen'), findsOneWidget);
  });

  testWidgets('die schon angezeigte Abteilung erneut zu wählen tut nichts',
      (tester) async {
    // Ein Wechsel zieht den kompletten Bestand neu — für einen Fehlgriff im
    // Sheet ist das zu teuer.
    await tester.pumpWidget(host(const [_own, _sister], selected: 'B'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AbteilungAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord · Musterstadt'));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(selectedAbteilungIdProvider), 'B');
    expect(find.byType(SnackBar), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSelectedAbteilungPref), isNull);
  });

  testWidgets('das Sheet liegt über der Navigationsleiste, nicht darunter',
      (tester) async {
    // Im Browser erlebt: Ohne Wurzel-Navigator landet das Sheet im
    // verschachtelten Navigator der ShellRoute — dann bleibt die
    // Navigationsleiste bedienbar, und ein Tipp knapp unter dem Sheet bricht
    // die Auswahl ab UND wechselt den Tab. Der Prüfstand baut die
    // Verschachtelung nach, sonst ginge der Fehler wieder durch.
    final shell = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: Scaffold(
        body: Navigator(
          key: shell,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(actions: const [AbteilungAction()]),
            ),
          ),
        ),
        bottomNavigationBar: const SizedBox(height: 68),
      ),
      overrides: [
        abteilungenProvider.overrideWith((ref) async => const [_own, _sister]),
        myAbteilungIdProvider.overrideWith((ref) async => 'A'),
        selectedAbteilungIdProvider.overrideWith((ref) => null),
        meineMitgliedschaftenProvider.overrideWith((ref) async => null),
        meineKommandoGesamtwehrenProvider.overrideWith((ref) async => null),
        supabaseClientProvider.overrideWithValue(null),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AbteilungAction));
    await tester.pumpAndSettle();

    expect(find.text('Abteilung wählen'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(shell),
        matching: find.text('Abteilung wählen'),
      ),
      findsNothing,
      reason: 'Das Sheet gehört auf den Wurzel-Navigator, nicht in die Shell',
    );
  });

  testWidgets('das Sheet nennt die Rechte je Abteilung, nicht die Herkunft',
      (tester) async {
    // Vor Stufe ① stand an jeder Schwester pauschal „nur lesen". Wer dort
    // Gerätewart ist, darf sehr wohl bearbeiten.
    await tester.pumpWidget(host(
      const [_own, _sister],
      mitgliedschaften: {'A': 'member', 'B': 'geraetewart'},
      kommandiert: const {},
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AbteilungAction));
    await tester.pumpAndSettle();

    expect(find.text('Deine Abteilung — nur lesen'), findsOneWidget);
    expect(find.text('Schwester-Abteilung — Gerätewart'), findsOneWidget);
  });

  testWidgets('der Feuerwehrkommandant sieht seine Stellung überall',
      (tester) async {
    await tester.pumpWidget(host(
      const [_own, _sister],
      mitgliedschaften: {'A': 'member'},
      kommandiert: const {'GW'},
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AbteilungAction));
    await tester.pumpAndSettle();

    expect(find.text('Deine Abteilung — Feuerwehrkommandant'), findsOneWidget);
    expect(
      find.text('Schwester-Abteilung — Feuerwehrkommandant'),
      findsOneWidget,
    );
  });
}
