/// wissensdatenbank_screen_test.dart – Was die Wissensdatenbank zeigt
/// (Issue #174, ABC-Einsatz).
///
/// Zwei Zusagen hängen allein an der Oberfläche: **Das Bild wird
/// tatsächlich gezeichnet** — bei einem Gefahrzettel ist es die Frage, und
/// eine Frage ohne ihren Gefahrzettel ist unbeantwortbar — und **der
/// Kapitelfilter räumt sich beim Gebietswechsel selbst auf**. Ein
/// „Dekontamination"-Filter, der nach dem Wechsel zu „Funk" stehen bleibt,
/// zeigt eine leere Liste, und der Grund steht am anderen Ende des Schirms.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/knowledge/presentation/screens/wissensdatenbank_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> anlegen({
    required String frage,
    String gebiet = 'gefahrgut',
    String? kapitel,
    String? bild,
  }) =>
      db.wissenDao.insertFrage(WissensfragenCompanion.insert(
        gebiet: gebiet,
        frage: frage,
        antwortenJson: const Value('["Stimmt","Daneben"]'),
        richtigeJson: const Value('[0]'),
        kapitel: Value(kapitel),
        bildPfad: Value(bild),
        herkunft: const Value('mitgeliefert'),
        stand: const Value('freigegeben'),
      ));

  Future<void> pumpe(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        buildTestApp(db: db, home: const WissensdatenbankScreen()));
    await tester.pumpAndSettle();
  }

  /// Wählt ein Sachgebiet über seinen Filter-Knopf.
  ///
  /// ⚠️ Mit Scrollen, und das ist kein Zufall: Die elf Sachgebiets-Chips
  /// liegen in einer waagerechten ListView. „Gefahrgut" und „Funk" liegen
  /// hinten — je nach Schirmbreite sind sie entweder gar nicht gebaut
  /// (`scrollUntilVisible` hilft) oder gebaut, aber außerhalb des Fensters,
  /// wo ein `tap` ins Leere geht (`ensureVisible` hilft). Beides ist nötig,
  /// eines allein reicht nicht.
  Future<void> gebietWaehlen(WidgetTester tester, String label) async {
    final knopf = find.textContaining('$label (');
    await tester.scrollUntilVisible(
      knopf,
      300,
      scrollable: find
          .byWidgetPredicate((w) =>
              w is Scrollable && w.axisDirection == AxisDirection.right)
          .first,
    );
    await tester.ensureVisible(knopf);
    await tester.pumpAndSettle();
    await tester.tap(knopf);
    await tester.pumpAndSettle();
  }

  testWidgets('die Bildfrage zeigt ihren Gefahrzettel', (tester) async {
    await anlegen(
      frage: 'Welche Gefahr zeigt dieser Gefahrzettel an?',
      kapitel: 'Gefahrzettel und Kennzeichnung',
      bild: 'assets/knowledge/bilder/gefahrzettel_klasse_3.png',
    );
    await pumpe(tester);

    // Zugeklappt kein Bild — die Liste soll eine Liste bleiben.
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.text('Welche Gefahr zeigt dieser Gefahrzettel an?'));
    await tester.pumpAndSettle();

    final bild = tester.widget<Image>(find.byType(Image).first);
    expect(bild.image, isA<AssetImage>());
    expect((bild.image as AssetImage).assetName,
        'assets/knowledge/bilder/gefahrzettel_klasse_3.png');

    await endTestApp(tester);
  });

  testWidgets('das Kapitel steht in der Unterzeile', (tester) async {
    await anlegen(
      frage: 'Was ist die Dekon-Stufe I?',
      kapitel: 'Dekontamination',
    );
    await pumpe(tester);

    expect(find.textContaining('Dekontamination'), findsWidgets);

    await endTestApp(tester);
  });

  testWidgets('ein einzelnes Kapitel bekommt keinen Filter', (tester) async {
    // Ein Knopf, der nichts eingrenzt, ist kein Filter, sondern
    // Beschriftung.
    await anlegen(frage: 'Frage A', kapitel: 'Dekontamination');
    await pumpe(tester);
    await gebietWaehlen(tester, 'Gefahrgut');

    expect(find.text('Alle Kapitel'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('ab zwei Kapiteln steht der Filter da', (tester) async {
    await anlegen(frage: 'Frage A', kapitel: 'Dekontamination');
    await anlegen(frage: 'Frage B', kapitel: 'Gefahrengruppen');
    await pumpe(tester);
    await gebietWaehlen(tester, 'Gefahrgut');

    expect(find.text('Alle Kapitel'), findsOneWidget);
    expect(find.text('Dekontamination (1)'), findsOneWidget);
    expect(find.text('Gefahrengruppen (1)'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('ein Gebietswechsel räumt den Kapitelfilter weg',
      (tester) async {
    await anlegen(frage: 'Erste ABC-Frage', kapitel: 'Dekontamination');
    await anlegen(frage: 'Zweite ABC-Frage', kapitel: 'Gefahrengruppen');
    await anlegen(frage: 'Eine Frage zum Sprechfunk', gebiet: 'funk');
    await pumpe(tester);

    await gebietWaehlen(tester, 'Gefahrgut');
    await tester.tap(find.text('Dekontamination (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Zweite ABC-Frage'), findsNothing);

    // Jetzt in ein Gebiet ohne Kapitel wechseln: Die Funkfrage muss da
    // sein. Bliebe der Filter stehen, wäre die Liste leer.
    await gebietWaehlen(tester, 'Funk');
    expect(find.text('Eine Frage zum Sprechfunk'), findsOneWidget);

    await endTestApp(tester);
  });
}
