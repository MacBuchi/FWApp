/// party_screen_test.dart – Der Party-Modus, wie er am Tisch bedient wird
/// (Issue #160).
///
/// Zwei Zusagen hängen allein an der Oberfläche und wären ohne diesen Test
/// nicht abgesichert: Der Übergabe-Schirm darf die Frage **nicht** schon
/// zeigen, und das Trinkspiel ist **ab Werk aus**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/game/party/data/party_inhalte.dart';
import 'package:fwapp/features/game/party/presentation/screens/party_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

/// Antworttexte bewusst ohne „Richtig"/„Daneben": Das sind die Wörter der
/// Auflösung, und ein Test, der beides verwechselt, prüft nichts.
final testInhalte = PartyInhalte(
  fragen: List.generate(
      12,
      (i) => UnerwarteteFrage(
            frage: 'Testfrage $i',
            antworten: const ['Stimmt', 'Daneben A', 'Daneben B'],
            richtig: 0,
            kategorie: kKategorieWissen,
          )),
  aufgaben: const ['Zehn Liegestütze'],
);

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpe(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: const PartyScreen(),
      overrides: [
        partyInhalteProvider.overrideWith((ref) async => testInhalte),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Future<void> spielerEintragen(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
  }

  Future<void> starten(WidgetTester tester,
      {bool trinkspiel = false}) async {
    await spielerEintragen(tester, 'Anna');
    await spielerEintragen(tester, 'Ben');
    if (trinkspiel) {
      await tester.tap(find.text('Trinkspiel'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Losgeht\'s'));
    await tester.pumpAndSettle();
  }

  testWidgets('ein einzelner Spieler kann nicht starten', (tester) async {
    await pumpe(tester);
    await spielerEintragen(tester, 'Anna');

    expect(find.text('Mindestens zwei Spieler.'), findsOneWidget);
    final knopf = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Losgeht\'s'), matching: find.byType(FilledButton)));
    expect(knopf.onPressed, isNull);

    await endTestApp(tester);
  });

  testWidgets('derselbe Name kommt nicht zweimal in die Runde',
      (tester) async {
    await pumpe(tester);
    await spielerEintragen(tester, 'Anna');
    await spielerEintragen(tester, 'anna');

    expect(find.widgetWithText(Chip, 'Anna'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'anna'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('das Trinkspiel ist ab Werk aus', (tester) async {
    await pumpe(tester);

    final schalter = tester.widget<SwitchListTile>(find.ancestor(
        of: find.text('Trinkspiel'), matching: find.byType(SwitchListTile)));
    expect(schalter.value, isFalse);
    // Der Hinweis erscheint erst, wenn jemand den Schalter umlegt.
    expect(find.textContaining('Bereitschaft'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('eingeschaltet sagt das Trinkspiel etwas zur Bereitschaft',
      (tester) async {
    await pumpe(tester);
    await tester.tap(find.text('Trinkspiel'));
    await tester.pumpAndSettle();

    expect(find.text('Wer heute Bereitschaft hat, nimmt die Aufgabe.'),
        findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('die Übergabe nennt den Spieler und verrät die Frage nicht',
      (tester) async {
    await pumpe(tester);
    await starten(tester);

    expect(find.text('Handy weitergeben an'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    // Der springende Punkt: Solange übergeben wird, ist keine Antwort zu
    // sehen. Sonst liest der Vorgänger mit.
    expect(find.text('Stimmt'), findsNothing);

    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();
    expect(find.text('Stimmt'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('falsche Antwort ohne Trinkspiel bleibt folgenlos',
      (tester) async {
    await pumpe(tester);
    await starten(tester);
    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daneben A'));
    await tester.pumpAndSettle();

    expect(find.text('Daneben'), findsOneWidget);
    expect(find.textContaining('Ein Schluck'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('mit Trinkspiel steht die Aufgabe als Alternative daneben',
      (tester) async {
    await pumpe(tester);
    await starten(tester, trinkspiel: true);
    await tester.tap(find.text('Bereit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daneben B'));
    await tester.pumpAndSettle();

    // „Ein Schluck — ODER" ist die ganze Entscheidung dieses Modus.
    expect(find.text('Ein Schluck — oder:'), findsOneWidget);
    expect(find.text('Zehn Liegestütze'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('Gleichstand heißt Unentschieden, nicht „Sieger: Anna"',
      (tester) async {
    await pumpe(tester);
    await starten(tester);

    // Alle antworten richtig — dann steht es 3:3.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Bereit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stimmt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(i < 5 ? 'Weitergeben' : 'Ergebnis'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Unentschieden: Anna und Ben'), findsOneWidget);
    expect(find.textContaining('Sieger'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('am Ende steht die Rangliste', (tester) async {
    await pumpe(tester);
    await starten(tester);

    // Anna trifft immer, Ben nie — das Ergebnis ist damit vorhersagbar.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Bereit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(i.isEven ? 'Stimmt' : 'Daneben A'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text(i < 5 ? 'Weitergeben' : 'Ergebnis'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Sieger: Anna'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Anna'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    await endTestApp(tester);
  });
}
