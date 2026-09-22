/// lerngruppen_screen_test.dart – Was die Lerngruppen-Bildschirme zeigen
/// (Issue #136).
///
/// Die Regeln (wer beitreten darf, was abgelaufen ist) setzt der Server
/// durch und beweist `lerngruppen_e2e_test.dart`. Hier geht es darum, dass
/// niemand vor einer leeren Seite steht und dass Gründen und Beitreten dort
/// ankommen, wo der Code zum Weitergeben steht.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/sync/gesamtwehr_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/lerngruppe/domain/lerngruppe.dart';
import 'package:fwapp/features/lerngruppe/presentation/providers/lerngruppe_providers.dart';
import 'package:fwapp/features/lerngruppe/presentation/screens/lerngruppe_detail_screen.dart';
import 'package:fwapp/features/lerngruppe/presentation/screens/lerngruppen_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, PostgrestException, SupabaseClient;

import '../../helpers/fake_session.dart';

// autoRefreshToken aus, sonst hinterlässt der Client einen Timer, der den
// Teardown-Invariant des Test-Frameworks reißt.
SupabaseClient _client() => SupabaseClient(
  'http://localhost:1',
  'test',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

/// Fängt die RPCs ab und führt eine eigene Liste, damit der Bildschirm nach
/// dem Gründen die neue Gruppe wirklich findet.
class _FakeService extends LerngruppeService {
  final Ref ref;
  final List<Lerngruppe> gruppen;
  final List<String> aufrufe;
  final Object? fehler;

  _FakeService(this.ref, this.gruppen, this.aufrufe, this.fehler)
    : super(_client(), ref);

  @override
  Future<Lerngruppe> gruende({
    required String gesamtwehrId,
    required String name,
    int wochen = kLerngruppenStandardWochen,
  }) async {
    aufrufe.add('gruende $gesamtwehrId $name $wochen');
    if (fehler != null) throw fehler!;
    final g = Lerngruppe(
      id: 'neu',
      gesamtwehrId: gesamtwehrId,
      name: name,
      code: '314159',
      laeuftBis: DateTime.now().add(Duration(days: wochen * 7)),
    );
    gruppen.add(g);
    ref.invalidate(meineLerngruppenProvider);
    return g;
  }

  @override
  Future<Lerngruppe> trittBei(String code) async {
    aufrufe.add('bei $code');
    if (fehler != null) throw fehler!;
    return gruppen.first;
  }

  @override
  Future<void> verlasse(String gruppeId) async {
    aufrufe.add('verlasse $gruppeId');
    gruppen.removeWhere((g) => g.id == gruppeId);
    ref.invalidate(meineLerngruppenProvider);
  }
}

const _verbunden = MeineOrganisation(
  abteilungId: 'A',
  abteilungName: 'Stadtmitte',
  status: 'active',
  gesamtwehrId: 'G',
  gesamtwehrName: 'Gesamtfeuerwehr Musterstadt',
);

Lerngruppe _laufend() => Lerngruppe(
  id: 'L1',
  gesamtwehrId: 'G',
  name: 'Truppmann Herbst',
  code: '042137',
  laeuftBis: DateTime.now().add(const Duration(days: 20)),
);

Lerngruppe _beendet() => Lerngruppe(
  id: 'L0',
  gesamtwehrId: 'G',
  name: 'Frühjahr',
  code: '999000',
  laeuftBis: DateTime.now().subtract(const Duration(days: 30)),
);

void main() {
  // Der Dienst entsteht erst beim ersten Tippen; die Tests prüfen deshalb
  // diese Liste und setzen den Fehler vorher.
  late List<String> aufrufe;
  Object? fehler;

  setUp(() {
    aufrufe = [];
    fehler = null;
  });

  Widget host({
    bool angemeldet = true,
    MeineOrganisation? org = _verbunden,
    List<Lerngruppe>? gruppen,
    List<LerngruppenMitglied> mitglieder = const [],
    String start = '/lerngruppen',
  }) {
    final liste = gruppen ?? <Lerngruppe>[];
    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: '/lerngruppen',
          builder: (_, _) => const LerngruppenScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder:
                  (_, s) =>
                      LerngruppeDetailScreen(gruppeId: s.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(angemeldet ? _client() : null),
        sessionStreamProvider.overrideWith(
          (ref) => Stream.value(angemeldet ? fakeSession() : null),
        ),
        meineOrganisationProvider.overrideWith((ref) async => org),
        // Liest bei jedem Invalidieren die aktuelle Liste des Fakes.
        meineLerngruppenProvider.overrideWith((ref) async => [...liste]),
        lerngruppenMitgliederProvider.overrideWith(
          (ref, _) async => mitglieder,
        ),
        lerngruppeServiceProvider.overrideWith(
          (ref) => _FakeService(ref, liste, aufrufe, fehler),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('ohne Anmeldung eine Erklärung statt leerer Seite', (
    tester,
  ) async {
    await tester.pumpWidget(host(angemeldet: false));
    await tester.pumpAndSettle();

    expect(
      find.text('Lerngruppen laufen über den Server der Wehr'),
      findsOneWidget,
    );
    expect(find.text('Gründen'), findsNothing);
  });

  testWidgets('ohne Gesamtwehr sagt der Bildschirm, wer das einrichtet', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        org: const MeineOrganisation(
          abteilungId: 'A',
          abteilungName: 'Stadtmitte',
          status: 'active',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Lerngruppen gibt es innerhalb einer Gesamtwehr'),
      findsOneWidget,
    );
    expect(find.text('Gründen'), findsNothing);
  });

  testWidgets('leer: erklärt die Idee und bietet beide Wege an', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.textContaining('sechsstelligen Code'), findsOneWidget);
    expect(find.text('Gründen'), findsOneWidget);
    expect(find.text('Mit Code beitreten'), findsOneWidget);
  });

  testWidgets('laufende vor beendeten, beide sichtbar', (tester) async {
    await tester.pumpWidget(host(gruppen: [_beendet(), _laufend()]));
    await tester.pumpAndSettle();

    final laufend = tester.getTopLeft(find.text('Truppmann Herbst'));
    final beendet = tester.getTopLeft(find.text('Frühjahr'));
    expect(laufend.dy, lessThan(beendet.dy));
    expect(find.textContaining('beendet am'), findsOneWidget);
    // Die Einführung steht nur da, solange man in keiner Gruppe ist.
    expect(find.textContaining('sechsstelligen Code'), findsNothing);
  });

  testWidgets('gründen führt direkt zum Code', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gründen'));
    await tester.pumpAndSettle();
    // Ohne Namen bleibt der Knopf aus.
    final knopf = find.widgetWithText(FilledButton, 'Gründen').last;
    expect(tester.widget<FilledButton>(knopf).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  Atemschutz  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Gründen').last);
    await tester.pumpAndSettle();

    expect(aufrufe, ['gruende G Atemschutz 8']);
    expect(find.text('314 159'), findsOneWidget);
    expect(find.text('Code weitergeben'), findsOneWidget);
  });

  testWidgets('beitreten prüft den Code, bevor er zum Server geht', (
    tester,
  ) async {
    await tester.pumpWidget(host(gruppen: [_laufend()]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mit Code beitreten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '04213');
    await tester.pump();
    final knopf = find.widgetWithText(FilledButton, 'Beitreten');
    expect(tester.widget<FilledButton>(knopf).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '042 137');
    await tester.pump();
    await tester.tap(knopf);
    await tester.pumpAndSettle();

    expect(aufrufe, ['bei 042137']);
    expect(find.text('042 137'), findsOneWidget);
  });

  testWidgets('eine Absage des Servers erscheint als Satz', (tester) async {
    fehler = const PostgrestException(
      message: 'Diese Lerngruppe ist abgelaufen',
      code: 'P0002',
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mit Code beitreten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '111111');
    await tester.pump();
    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();

    expect(find.textContaining('schon zu Ende'), findsOneWidget);
    // Kein Sprung in eine Gruppe, die es für einen nicht gibt.
    expect(find.text('Code weitergeben'), findsNothing);
  });

  group('Detail', () {
    const mitglieder = [
      LerngruppenMitglied(userId: kFakeUserId, name: 'Marcus'),
      LerngruppenMitglied(userId: 'u2', name: 'Brigitte'),
    ];

    testWidgets('zeigt Mitglieder und markiert sich selbst', (tester) async {
      await tester.pumpWidget(
        host(
          gruppen: [_laufend()],
          mitglieder: mitglieder,
          start: '/lerngruppen/L1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marcus (du)'), findsOneWidget);
      expect(find.text('Brigitte'), findsOneWidget);
      expect(find.text('042 137'), findsOneWidget);
    });

    testWidgets('eine beendete Gruppe zeigt keinen Code mehr', (tester) async {
      await tester.pumpWidget(
        host(
          gruppen: [_beendet()],
          mitglieder: mitglieder,
          start: '/lerngruppen/L0',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('999 000'), findsNothing);
      expect(find.text('Code weitergeben'), findsNothing);
      expect(find.text('Brigitte'), findsOneWidget);
    });

    testWidgets('verlassen fragt nach und führt zurück zur Liste', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(gruppen: [_laufend()], mitglieder: mitglieder),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Truppmann Herbst'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Gruppe verlassen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(aufrufe, isEmpty);

      await tester.tap(find.byTooltip('Gruppe verlassen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Verlassen'));
      await tester.pumpAndSettle();

      expect(aufrufe, ['verlasse L1']);
      expect(find.text('Mit Code beitreten'), findsOneWidget);
    });
  });
}
