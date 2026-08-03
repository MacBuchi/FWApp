/// gesamtwehr_header_test.dart – Kopfbereich der Gesamtwehr auf der Startseite
/// (#57 P5): Wann er erscheint, was er zeigt, und wer ihn antippen kann.
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/branding_providers.dart';
import 'package:fwapp/features/home/presentation/widgets/gesamtwehr_header.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

const _gw = '11111111-1111-1111-1111-111111111111';
const _bild = 'supabase://gesamtwehr-branding/$_gw/1700.jpg';

/// Fester Stand statt Serverabfrage — der echte Notifier würde hier ins Netz
/// greifen und den Zwischenspeicher anfassen.
class _FesterKopf extends GesamtwehrBrandingNotifier {
  _FesterKopf(this.wert);
  final GesamtwehrBranding? wert;

  @override
  Future<GesamtwehrBranding?> build() async => wert;
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget app({
    GesamtwehrBranding? branding,
    String? wehrName = 'Gesamtfeuerwehr Musterstadt',
    bool darfPflegen = false,
  }) =>
      buildTestApp(
        db: db,
        home: Scaffold(body: ListView(children: const [GesamtwehrHeader()])),
        overrides: [
          gesamtwehrBrandingProvider.overrideWith(() => _FesterKopf(branding)),
          aktuelleGesamtwehrProvider.overrideWith(
            (ref) async => GesamtwehrBezug(id: _gw, name: wehrName),
          ),
          darfBrandingPflegenProvider.overrideWith((ref) async => darfPflegen),
        ],
      );

  testWidgets('ohne Gesamtwehr bleibt die Startseite kopflos', (tester) async {
    await tester.pumpWidget(app(branding: null));
    await tester.pumpAndSettle();
    expect(find.byType(GesamtwehrKopf), findsNothing);
    await endTestApp(tester);
  });

  testWidgets('ein ungepflegter Kopf beansprucht keinen Platz', (tester) async {
    await tester.pumpWidget(
        app(branding: const GesamtwehrBranding(gesamtwehrId: _gw)));
    await tester.pumpAndSettle();
    expect(find.byType(GesamtwehrKopf), findsNothing);
    await endTestApp(tester);
  });

  testWidgets('Überschrift und Begrüßung stehen im Kopf', (tester) async {
    await tester.pumpWidget(app(
      branding: const GesamtwehrBranding(
        gesamtwehrId: _gw,
        titel: 'Freiwillige Feuerwehr Musterstadt',
        willkommenstext: 'Übung am Dienstag, 19 Uhr im Gerätehaus.',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Freiwillige Feuerwehr Musterstadt'), findsOneWidget);
    expect(find.text('Übung am Dienstag, 19 Uhr im Gerätehaus.'), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('ohne eigene Überschrift steht der Name der Gesamtwehr da',
      (tester) async {
    await tester.pumpWidget(app(
      branding: const GesamtwehrBranding(
          gesamtwehrId: _gw, willkommenstext: 'Willkommen!'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Gesamtfeuerwehr Musterstadt'), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('nur ein Bild reicht — der Kopf erscheint auch ohne Text',
      (tester) async {
    await tester.pumpWidget(app(
      branding: const GesamtwehrBranding(gesamtwehrId: _gw, bildPfad: _bild),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(GesamtwehrKopf), findsOneWidget);
    // Der Wehr-Name legt sich über das Bild, auch wenn nichts getippt wurde.
    expect(find.text('Gesamtfeuerwehr Musterstadt'), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('wer pflegen darf, kann den Kopf antippen', (tester) async {
    await tester.pumpWidget(app(
      branding: const GesamtwehrBranding(gesamtwehrId: _gw, titel: 'Wehr'),
      darfPflegen: true,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('für alle anderen ist der Kopf reine Anzeige', (tester) async {
    await tester.pumpWidget(app(
      branding: const GesamtwehrBranding(gesamtwehrId: _gw, titel: 'Wehr'),
      darfPflegen: false,
    ));
    await tester.pumpAndSettle();
    // Kein Tippbereich: Ein Truppmann soll nicht in eine Maske geraten, die
    // ihn ohnehin nur abweist.
    expect(find.byType(InkWell), findsNothing);
    await endTestApp(tester);
  });
}
