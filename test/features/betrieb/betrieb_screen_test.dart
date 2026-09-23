/// betrieb_screen_test.dart – Was die KreisDatenMeister-Konsole zeigt und
/// anstößt, und die zwei Stellen, an denen alle anderen etwas davon sehen
/// (Issue #101).
///
/// Die Rechte beweist `kreisdatenmeister_e2e_test.dart` am echten Stack.
/// Hier geht es darum, dass die Konsole die Warnungen zeigt, die Vorgänge
/// mit den richtigen Werten anstößt und nichts ohne Rückfrage stilllegt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/betrieb/domain/betrieb.dart';
import 'package:fwapp/features/betrieb/presentation/providers/betrieb_providers.dart';
import 'package:fwapp/features/betrieb/presentation/screens/betrieb_screen.dart';
import 'package:fwapp/features/betrieb/presentation/widgets/betrieb_eintrag.dart';
import 'package:fwapp/features/betrieb/presentation/widgets/stillgelegt_hinweis.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

/// Zeichnet die Aufrufe auf, statt einen Server zu brauchen.
class _FakeDienst extends BetriebService {
  final List<String> aufrufe;
  final KommandantWeg weg;
  _FakeDienst(Ref ref, this.aufrufe, this.weg)
    : super(
        SupabaseClient(
          'http://localhost:1',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        ref,
      );

  @override
  Future<String> legeWehrAn({
    required String wehr,
    required String abteilung,
    required String kommandantMail,
    String? kommandantName,
  }) async {
    aufrufe.add('anlegen $wehr/$abteilung/$kommandantMail/$kommandantName');
    return 'neu';
  }

  @override
  Future<KommandantWeg> fuegeKommandantHinzu({
    required String gesamtwehrId,
    required String abteilungId,
    required String mail,
    String? name,
  }) async {
    aufrufe.add('kommandant $gesamtwehrId/$abteilungId/$mail');
    return weg;
  }

  @override
  Future<void> setzeStillgelegt(String gesamtwehrId, bool still) async {
    aufrufe.add('still $gesamtwehrId $still');
  }
}

const _ohneKommandant = KdmWehr(
  id: 'g1',
  name: 'Feuerwehr Neustadt',
  abteilungen: [(id: 'a1', name: 'Mitte')],
);

final _mitZwei = KdmWehr(
  id: 'g2',
  name: 'Feuerwehr Altstadt',
  abteilungen: const [(id: 'a2', name: 'Nord'), (id: 'a3', name: 'Süd')],
  mitglieder: 23,
  kommandanten: const [
    KdmKommandant(userId: 'u1', name: 'Erika', email: 'erika@example.org'),
    KdmKommandant(userId: 'u2', name: 'Hans'),
  ],
  zuletztVeroeffentlicht: DateTime(2026, 9, 20),
);

void main() {
  late AppDatabase db;
  late List<String> aufrufe;

  setUp(() {
    db = createTestDatabase();
    aufrufe = [];
  });
  tearDown(() => db.close());

  Widget host({
    bool betreiber = true,
    List<KdmWehr>? wehren,
    KommandantWeg weg = KommandantWeg.ernannt,
  }) => buildTestApp(
    db: db,
    home: const BetriebScreen(),
    overrides: [
      supabaseClientProvider.overrideWithValue(null),
      istBetreiberProvider.overrideWith((ref) async => betreiber),
      kdmGesamtwehrenProvider.overrideWith(
        (ref) async => wehren ?? [_ohneKommandant, _mitZwei],
      ),
      betriebServiceProvider.overrideWith(
        (ref) => _FakeDienst(ref, aufrufe, weg),
      ),
    ],
  );

  testWidgets('wer nicht Betreiber ist, sieht nur einen Hinweis', (
    tester,
  ) async {
    await tester.pumpWidget(host(betreiber: false));
    await tester.pumpAndSettle();

    expect(find.textContaining('vorbehalten'), findsOneWidget);
    expect(find.text('Wehr anlegen'), findsNothing);
    expect(find.text('Feuerwehr Neustadt'), findsNothing);
  });

  testWidgets('die Übersicht zeigt Stand und Warnungen je Wehr', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('2 Gesamtwehren auf dieser Installation'), findsOneWidget);
    expect(
      find.textContaining('ohne Gesamtwehr stehen hier nicht'),
      findsOneWidget,
    );
    expect(find.textContaining('Niemand kann hier einladen'), findsOneWidget);
    expect(
      find.textContaining('Erika (erika@example.org), Hans'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '2 Abteilungen · 23 Mitglieder · zuletzt '
        'veröffentlicht am 20.09.2026',
      ),
      findsOneWidget,
    );
  });

  testWidgets('anlegen gibt Wehr, Abteilung und Kommandant weiter', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wehr anlegen'));
    await tester.pumpAndSettle();
    final knopf = find.widgetWithText(FilledButton, 'Anlegen und einladen');
    // Ohne gültige Mail bleibt der Knopf aus.
    await tester.enterText(find.byType(TextField).at(0), 'Feuerwehr Probe');
    await tester.enterText(find.byType(TextField).at(1), 'Abteilung Ost');
    await tester.enterText(find.byType(TextField).at(2), 'keine-mail');
    await tester.pump();
    expect(tester.widget<FilledButton>(knopf).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(2), 'chef@example.org');
    await tester.enterText(find.byType(TextField).at(3), 'Erika');
    await tester.pump();
    await tester.tap(knopf);
    await tester.pumpAndSettle();

    expect(aufrufe, [
      'anlegen Feuerwehr Probe/Abteilung Ost/chef@example.org/Erika',
    ]);
    expect(
      find.textContaining('Einladung an chef@example.org'),
      findsOneWidget,
    );
  });

  testWidgets('Kommandant hinzufügen sagt, ob ernannt oder eingeladen', (
    tester,
  ) async {
    await tester.pumpWidget(host(weg: KommandantWeg.eingeladen));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aktionen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kommandant hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'neu@example.org');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();

    expect(aufrufe, ['kommandant g1/a1/neu@example.org']);
    expect(find.textContaining('noch kein Konto'), findsOneWidget);
  });

  testWidgets('stilllegen fragt nach und erklärt, dass nichts gelöscht wird', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aktionen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stilllegen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('es wird nichts gelöscht'), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(aufrufe, isEmpty);

    await tester.tap(find.byTooltip('Aktionen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stilllegen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Stilllegen'));
    await tester.pumpAndSettle();
    expect(aufrufe, ['still g2 true']);
  });

  group('für alle anderen', () {
    Widget einzeln(Widget kind, List<Override> overrides) => buildTestApp(
      db: db,
      home: Scaffold(body: ListView(children: [kind])),
      overrides: [supabaseClientProvider.overrideWithValue(null), ...overrides],
    );

    testWidgets('der Hinweis „stillgelegt" nennt den Kontakt', (tester) async {
      await tester.pumpWidget(
        einzeln(const StillgelegtHinweis(), [
          eigeneWehrStillgelegtProvider.overrideWith((ref) async => true),
          installationKontaktProvider.overrideWith(
            (ref) async => 'Mail an kdm@example.org',
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deine Feuerwehr ist stillgelegt'), findsOneWidget);
      expect(find.textContaining('Kontakt: Mail an kdm@'), findsOneWidget);
      expect(find.textContaining('Lernen gehen weiter'), findsOneWidget);
    });

    testWidgets('ohne Stilllegung kein Hinweis', (tester) async {
      await tester.pumpWidget(
        einzeln(const StillgelegtHinweis(), [
          eigeneWehrStillgelegtProvider.overrideWith((ref) async => false),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('stillgelegt'), findsNothing);
    });

    testWidgets('den Einstellungs-Eintrag sieht nur der Betreiber', (
      tester,
    ) async {
      for (final betreiber in [false, true]) {
        // Eine bestehende ProviderScope übernimmt geänderte Overrides nicht —
        // der Baum muss einmal weg, sonst prüft der zweite Durchlauf den
        // ersten noch einmal.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          einzeln(const BetriebEintrag(), [
            istBetreiberProvider.overrideWith((ref) async => betreiber),
          ]),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('KreisDatenMeister'),
          betreiber ? findsOneWidget : findsNothing,
        );
      }
    });
  });
}
