/// einladung_zustellung_test.dart – Die Einladungsliste sagt, was Sache ist
/// (Issue #121).
///
/// Vor #121 stand an jeder Zeile dasselbe: eine Sanduhr und „wartet auf
/// Bestätigung". Eine verworfene Einladung sah damit exakt aus wie eine
/// zugestellte. Geprüft wird deshalb nicht, dass „irgendwo etwas steht",
/// sondern dass sich die drei Fälle auf dem Bildschirm **unterscheiden** —
/// und dass der Ausweg (Zugangszettel) auch dann erreichbar ist, wenn der
/// Server über die Zustellung gar nichts weiß.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/domain/zustellung.dart';
import 'package:fwapp/features/settings/presentation/providers/einladung_providers.dart';
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

final _einladung = Einladung(
  id: 'e1',
  email: 'max.mustermann@web.de',
  anzeigename: 'Max Mustermann',
  abteilungId: 'A',
  role: 'geraetewart',
  alsKommandant: false,
  createdAt: DateTime.utc(2026, 8, 4, 18),
);

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget host(Zustellstand stand) => buildTestApp(
        db: db,
        home: const UserManagementScreen(),
        overrides: [
          managedUsersProvider.overrideWith((ref) async => const <ManagedUser>[]),
          abteilungenProvider.overrideWith((ref) async => const [_stadt]),
          myAbteilungIdProvider.overrideWith((ref) async => 'A'),
          meineKommandoGesamtwehrenProvider
              .overrideWith((ref) async => const <String>{}),
          supabaseClientProvider.overrideWithValue(null),
          offeneEinladungenProvider.overrideWith((ref) async => [_einladung]),
          einladungZustellungProvider.overrideWith((ref) async => stand),
        ],
      );

  Zustellstand stand(Zustellung z) => Zustellstand(
        verfuegbar: true,
        gekuerzt: 0,
        proEinladung: {'e1': z},
      );

  testWidgets('eine verworfene Einladung nennt Grund und Zeitpunkt',
      (tester) async {
    await tester.pumpWidget(host(stand(Zustellung(
      Zustellzustand.gescheitert,
      grund: 'vorübergehend abgelehnt (Internal Error: DKIM Bad request)',
      zeit: DateTime.utc(2026, 8, 4, 19, 41),
    ))));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('unzustellbar: vorübergehend abgelehnt'),
      findsOneWidget,
    );
    expect(find.textContaining('DKIM Bad request'), findsOneWidget);
    // Und das Symbol wechselt: Die Sanduhr sagt „warte noch", und genau das
    // wäre hier der falsche Rat.
    expect(find.byIcon(Icons.hourglass_empty), findsNothing);
    expect(find.byIcon(Icons.report_gmailerrorred), findsOneWidget);
  });

  testWidgets('eine zugestellte Einladung sieht anders aus als eine offene',
      (tester) async {
    await tester.pumpWidget(host(stand(
        Zustellung(Zustellzustand.zugestellt, zeit: DateTime.utc(2026, 8, 4)))));
    await tester.pumpAndSettle();

    expect(find.textContaining('zugestellt'), findsOneWidget);
    expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
    expect(find.byIcon(Icons.report_gmailerrorred), findsNothing);
  });

  testWidgets('ohne Auskunft steht „nicht prüfbar" statt einer Beruhigung',
      (tester) async {
    // Der Zustand auf jedem Server ohne Brevo-Schlüssel. Er darf NICHT wie
    // „alles in Ordnung" aussehen — das war der Fehler, den #121 meldet.
    await tester.pumpWidget(host(Zustellstand.leer));
    await tester.pumpAndSettle();

    expect(find.text('Zustellung nicht prüfbar'), findsOneWidget);
    expect(find.byIcon(Icons.report_gmailerrorred), findsNothing);
  });

  testWidgets('der Ausweg steht auch ohne Zustell-Auskunft im Menü',
      (tester) async {
    await tester.pumpWidget(host(Zustellstand.leer));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Zugangszettel stattdessen'), findsOneWidget);
    expect(find.text('Erneut senden'), findsOneWidget);
  });

  testWidgets('der Zettel-Dialog kommt mit dem, was die Einladung weiß',
      (tester) async {
    await tester.pumpWidget(host(stand(const Zustellung(
      Zustellzustand.gescheitert,
      grund: 'Adresse existiert nicht',
    ))));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zugangszettel stattdessen'));
    await tester.pumpAndSettle();

    expect(find.text('Zugangszettel statt Mail'), findsOneWidget);
    // Nutzername vorbelegt aus der Adresse …
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'max.mustermann'))
          .controller
          ?.text,
      'max.mustermann',
    );
    // … und der Hinweis sagt, was mit der Einladung passiert.
    expect(find.textContaining('Einladung wird'), findsOneWidget);
    expect(find.textContaining('NICHT selbst'), findsOneWidget);
  });

  testWidgets('gekürzte Prüfung wird gesagt, nicht verschwiegen',
      (tester) async {
    await tester.pumpWidget(host(const Zustellstand(
      verfuegbar: true,
      gekuerzt: 3,
      proEinladung: {},
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('nur für die ersten'), findsOneWidget);
  });
}
