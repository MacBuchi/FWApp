/// fach_quiz_verortung_test.dart – Die Antworten des Fach-Quiz sagen, WO das
/// Fach liegt (Issue #167).
///
/// Vorher standen dort vier nackte Namen („G5 / G2 / G3 / Dach"). Wer die
/// Nummern noch nicht im Kopf hat, konnte daraus nichts lernen — und die
/// Farbe, an der im Fahrzeugmenü gelernt wird, fehlte ganz. Alle vier
/// Antworten tragen die Ortsangabe, deshalb verrät sie nichts.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/compartment/presentation/seiten_farben.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/compartment_quiz_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    final vehicleId = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
    // Vier Fächer, damit eine Frage überhaupt zustande kommt (eine richtige
    // plus drei falsche Antworten).
    final faecher = <String, int>{};
    for (final (label, seite, laengs) in const [
      ('G1', 'fahrerseite', 'vorne'),
      ('G2', 'beifahrerseite', 'vorne'),
      ('G5', 'fahrerseite', 'hinten'),
      ('Dach', 'dach', null),
    ]) {
      faecher[label] = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(
          vehicleId: vehicleId,
          label: label,
          seite: Value(seite),
          laengsposition: Value(laengs),
        ),
      );
    }
    final geraet = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Strahlrohr'));
    await db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: faecher['G5']!, equipmentId: geraet));
  });

  tearDown(() => db.close());

  Future<void> starteQuiz(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        buildTestApp(db: db, home: const CompartmentQuizScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz starten'));
    await tester.pumpAndSettle();
  }

  testWidgets('jede Antwort nennt Seite und Längsposition', (tester) async {
    await starteQuiz(tester);

    // Dieselbe Schreibweise wie die Fach-Karten im Fahrzeugmenü.
    expect(find.text('Fahrerseite · hinten'), findsOneWidget);
    expect(find.text('Fahrerseite · vorne'), findsOneWidget);
    expect(find.text('Beifahrerseite · vorne'), findsOneWidget);
    // Das Fach „Dach" liegt auf der Seite „Dach" — die Unterzeile wäre eine
    // Wiederholung und bleibt deshalb weg.
    expect(find.text('Dach'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('jede Antwort trägt den Farbpunkt ihrer Seite', (tester) async {
    await starteQuiz(tester);

    Color punktFarbe(String label) {
      final punkt = find
          .descendant(
            of: find.ancestor(
                of: find.text(label), matching: find.byType(Row)).first,
            matching: find.byType(Container),
          )
          .first;
      return (tester.widget<Container>(punkt).decoration as BoxDecoration)
          .color!;
    }

    expect(punktFarbe('G1'), kSeitenFarben['fahrerseite']!.akzent);
    expect(punktFarbe('G2'), kSeitenFarben['beifahrerseite']!.akzent);

    await endTestApp(tester);
  });
}
