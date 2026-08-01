/// gesamtwehr_screen_test.dart – Abteilung & Gesamtwehr (Issue #57 Phase 3).
///
/// Geprüft wird, was der Screen ZEIGT — die Regeln dahinter setzt der Server
/// durch und beweist der E2E-Test. Hier geht es darum, dass niemand einen
/// Vorgang angeboten bekommt, der für ihn ohnehin abprallen würde.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/gesamtwehr_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/screens/gesamtwehr_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, PostgrestException, SupabaseClient;

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

/// Fängt die schreibenden Aufrufe ab, statt einen echten Server zu brauchen.
class _FakeGesamtwehrService extends GesamtwehrService {
  final List<String> gegruendet = [];
  _FakeGesamtwehrService(Ref ref)
      // autoRefreshToken aus, sonst hinterlässt der Client einen Timer,
      // der den Teardown-Invariant des Test-Frameworks reißt.
      : super(
          SupabaseClient('http://localhost:1', 'test',
              authOptions: const AuthClientOptions(autoRefreshToken: false)),
          ref,
        );

  @override
  Future<String> gruendeGesamtwehr(String name) async {
    gegruendet.add(name);
    return 'gw-neu';
  }
}

const _allein = MeineOrganisation(
  abteilungId: 'A',
  abteilungName: 'Stadtmitte',
  status: 'active',
);

const _verbunden = MeineOrganisation(
  abteilungId: 'A',
  abteilungName: 'Stadtmitte',
  status: 'active',
  gesamtwehrId: 'G',
  gesamtwehrName: 'Gesamtfeuerwehr Musterstadt',
);

const _wartend = MeineOrganisation(
  abteilungId: 'A',
  abteilungName: 'Süd',
  status: 'pending',
);

const _anfrage = VerbindungsAnfrage(
  id: 'R1',
  abteilungId: 'B',
  abteilungName: 'Abteilung Nord',
  nachricht: 'Wir würden gern dazu.',
);

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget host({
    required MeineOrganisation? org,
    bool isAdmin = true,
    List<VerbindungsAnfrage> anfragen = const [],
    EigenerAntrag? antrag,
  }) =>
      buildTestApp(
        db: db,
        home: const GesamtwehrScreen(),
        overrides: [
          meineOrganisationProvider.overrideWith((ref) async => org),
          offeneAnfragenProvider.overrideWith((ref) async => anfragen),
          eigenerAntragProvider.overrideWith((ref) async => antrag),
          gesamtwehrenProvider.overrideWith((ref) async => const [
                GesamtwehrInfo(id: 'G', name: 'Gesamtfeuerwehr Musterstadt'),
              ]),
          isAdminProvider.overrideWithValue(isAdmin),
          supabaseClientProvider.overrideWithValue(null),
        ],
      );

  testWidgets('ohne Klammer bietet der Admin gründen UND beitreten an',
      (tester) async {
    await tester.pumpWidget(host(org: _allein));
    await tester.pumpAndSettle();

    expect(find.text('Stadtmitte'), findsOneWidget);
    expect(find.text('Keiner Gesamtwehr angeschlossen'), findsOneWidget);
    expect(find.text('Gesamtwehr gründen'), findsOneWidget);
    expect(find.text('Anschluss beantragen'), findsOneWidget);
    // Ohne Klammer gibt es nichts anzulegen und nichts zu entscheiden.
    expect(find.text('Weitere Abteilung anlegen'), findsNothing);
    expect(find.text('Offene Anfragen'), findsNothing);
  });

  testWidgets('Gerätewart darf beantragen, aber nicht gründen',
      (tester) async {
    await tester.pumpWidget(host(org: _allein, isAdmin: false));
    await tester.pumpAndSettle();

    expect(find.text('Gesamtwehr gründen'), findsNothing);
    expect(find.text('Anschluss beantragen'), findsOneWidget);
  });

  testWidgets('läuft ein Antrag, wird kein zweiter angeboten', (tester) async {
    await tester.pumpWidget(host(
      org: _wartend,
      antrag: const EigenerAntrag(
          id: 'R1', gesamtwehrId: 'G', status: 'pending'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Antrag läuft'), findsOneWidget);
    expect(find.text('Anschluss beantragen'), findsNothing);
    expect(find.text('Gesamtwehr gründen'), findsNothing);
    // Die noch fehlende Freigabe steht dran, statt sie zu verschweigen.
    expect(find.textContaining('noch nicht freigegeben'), findsOneWidget);
    expect(find.text('wartet'), findsOneWidget);
  });

  testWidgets('abgelehnter Antrag zeigt die Begründung und lässt es erneut zu',
      (tester) async {
    await tester.pumpWidget(host(
      org: _allein,
      antrag: const EigenerAntrag(
        id: 'R1',
        gesamtwehrId: 'G',
        status: 'rejected',
        antwort: 'Bitte erst im Kommandantenkreis besprechen.',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('abgelehnt'), findsOneWidget);
    expect(find.text('Bitte erst im Kommandantenkreis besprechen.'),
        findsOneWidget);
    expect(find.text('Anschluss beantragen'), findsOneWidget);
  });

  testWidgets('mit Klammer sieht der Admin Anlegen und offene Anfragen',
      (tester) async {
    await tester.pumpWidget(host(org: _verbunden, anfragen: const [_anfrage]));
    await tester.pumpAndSettle();

    expect(find.text('Gesamtfeuerwehr Musterstadt'), findsOneWidget);
    expect(find.text('Weitere Abteilung anlegen'), findsOneWidget);
    expect(find.text('Offene Anfragen'), findsOneWidget);
    expect(find.text('Abteilung Nord'), findsOneWidget);
    expect(find.text('Wir würden gern dazu.'), findsOneWidget);
    // Beitreten ist erledigt und verschwindet.
    expect(find.text('Anschluss beantragen'), findsNothing);
  });

  testWidgets('Freigabe fragt nach und benennt die Folge fürs Lesen',
      (tester) async {
    await tester.pumpWidget(host(org: _verbunden, anfragen: const [_anfrage]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Freigeben'));
    await tester.pumpAndSettle();

    expect(find.text('Anschluss freigeben?'), findsOneWidget);
    // Der Dialog muss die Folge benennen: gegenseitiges Lesen, kein Schreiben.
    expect(
        find.textContaining('den Bestand der jeweils anderen lesen'),
        findsOneWidget);
    expect(find.textContaining('bearbeiten weiterhin nur die eigene'),
        findsOneWidget);
  });

  testWidgets('Gerätewart bekommt in der Gesamtwehr nichts zu entscheiden',
      (tester) async {
    await tester.pumpWidget(host(
        org: _verbunden, isAdmin: false, anfragen: const [_anfrage]));
    await tester.pumpAndSettle();

    expect(find.text('Weitere Abteilung anlegen'), findsNothing);
    expect(find.text('Offene Anfragen'), findsNothing);
  });

  testWidgets('Legacy-Server ohne Abteilungen sagt das offen', (tester) async {
    await tester.pumpWidget(host(org: null));
    await tester.pumpAndSettle();

    expect(find.textContaining('kennt noch keine Abteilungen'), findsOneWidget);
  });

  testWidgets(
      'Gründen-Dialog funktioniert auch im verschachtelten Navigator '
      '(Regression: v1.6.0 im Feld)', (tester) async {
    // Der Screen liegt in der App unter der Shell-Route in einem EIGENEN
    // Navigator, der Dialog aber im Root-Navigator. Ein Pop über den
    // Screen-Kontext trifft dann den falschen Navigator und "Anlegen" tut
    // sichtbar nichts. Ein flacher MaterialApp(home:)-Harness kann das
    // nicht zeigen — deshalb hier explizit verschachtelt.
    late _FakeGesamtwehrService dienst;
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const GesamtwehrScreen()),
      ),
      overrides: [
        meineOrganisationProvider.overrideWith((ref) async => _allein),
        offeneAnfragenProvider.overrideWith((ref) async => const []),
        eigenerAntragProvider.overrideWith((ref) async => null),
        gesamtwehrenProvider.overrideWith((ref) async => const []),
        isAdminProvider.overrideWithValue(true),
        supabaseClientProvider.overrideWithValue(null),
        gesamtwehrServiceProvider
            .overrideWith((ref) => dienst = _FakeGesamtwehrService(ref)),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gesamtwehr gründen'));
    await tester.pumpAndSettle();
    expect(find.text('Name der Gesamtwehr'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'Gesamtfeuerwehr Musterstadt');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    // Der Dialog ist zu, der Vorgang lief, die Snackbar bestätigt.
    expect(find.text('Name der Gesamtwehr'), findsNothing,
        reason: 'der Dialog muss sich über den RICHTIGEN Navigator schließen');
    expect(dienst.gegruendet, ['Gesamtfeuerwehr Musterstadt']);
    expect(find.textContaining('gegründet'), findsOneWidget);

    // Snackbar-Timer ablaufen lassen, sonst reißt der Teardown-Invariant.
    await tester.pump(const Duration(seconds: 5));
  });

  group('Fehlertexte', () {
    // Die Server-Meldungen sind englisch und technisch; im Gerätehaus steht
    // jemand davor, der wissen will, was jetzt zu tun ist.
    test('bekannte Marker werden zu einem verständlichen Satz', () {
      String uebersetzt(String meldung) => gesamtwehrFehlerText(
          PostgrestException(message: meldung, code: 'P0001'));

      expect(uebersetzt('permission denied: admin role required'),
          contains('Berechtigung'));
      expect(uebersetzt('abteilung already belongs to a gesamtwehr'),
          contains('gehört bereits'));
      expect(uebersetzt('gesamtwehr required: create or join one first'),
          contains('zuerst eine Gesamtwehr'));
      expect(uebersetzt('a request is already pending for this abteilung'),
          contains('läuft bereits'));
      expect(uebersetzt('request already decided (approved)'),
          contains('schon entschieden'));
    });

    test('Unbekanntes bleibt im Original stehen', () {
      // Lieber eine fremde Meldung als eine falsche Beruhigung.
      const roh = 'deadlock detected';
      expect(
          gesamtwehrFehlerText(
              PostgrestException(message: roh, code: '40P01')),
          roh);
    });
  });
}
