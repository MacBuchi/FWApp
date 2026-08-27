/// geraete_suche_screen_test.dart – Die Gerätesuche, wie sie bedient wird
/// (Issue #180).
///
/// Hier hängt, was die reinen Regeln nicht prüfen können: dass der Index aus
/// der Datenbank überhaupt richtig zusammengebaut wird (Gerät → Fach →
/// Fahrzeug über zwei Fremdschlüssel), und dass das Fahrzeug an jedem
/// Fundort steht — ohne das ist ein Treffer im Fuhrpark wertlos, genau der
/// Fehler aus Issue #172.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/search/presentation/screens/geraete_suche_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  /// Zwei Fahrzeuge: Der Spreizer liegt nur im HLF, die Schläuche in beiden,
  /// die Wärmebildkamera in keinem.
  Future<void> seedFuhrpark() async {
    final hlf = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
    final lf = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'LF 20', type: 'LF 20'));

    Future<int> fach(int vehicleId, String label, String seite) =>
        db.compartmentDao.insertCompartment(CompartmentsCompanion.insert(
            vehicleId: vehicleId, label: label, seite: Value(seite)));
    final g3Hlf = await fach(hlf, 'G3', 'fahrerseite');
    final g1Hlf = await fach(hlf, 'G1', 'beifahrerseite');
    final g4Lf = await fach(lf, 'G4', 'heck');

    Future<int> geraet(String name, {String? kurz}) =>
        db.equipmentDao.insertEquipment(EquipmentItemsCompanion.insert(
            name: name, shortName: Value(kurz)));
    final spreizer = await geraet('Spreizer');
    final schlauch = await geraet('C-Schläuche', kurz: 'C42');
    await geraet('Wärmebildkamera');

    Future<void> lege(int fachId, int geraetId, int menge) =>
        db.assignmentDao.insertAssignment(
            EquipmentAssignmentsCompanion.insert(
                compartmentId: fachId,
                equipmentId: geraetId,
                quantity: Value(menge)));
    await lege(g3Hlf, spreizer, 1);
    await lege(g1Hlf, schlauch, 6);
    await lege(g4Lf, schlauch, 4);
  }

  Future<void> pumpe(WidgetTester tester, {int? vehicleId}) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: GeraeteSucheScreen(vehicleId: vehicleId),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tippe(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  testWidgets('ohne Eingabe steht da, wozu der Schirm gut ist',
      (tester) async {
    await seedFuhrpark();
    await pumpe(tester);

    expect(find.textContaining('in welchem Fach'), findsOneWidget);
    expect(find.text('Spreizer'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('ein Treffer nennt Fahrzeug UND Fach', (tester) async {
    // Die Lehre aus Issue #172: Ein Fach ohne Fahrzeug ist bei mehreren
    // Fahrzeugen keine Auskunft.
    await seedFuhrpark();
    await pumpe(tester);
    await tippe(tester, 'spreizer');

    expect(find.text('Spreizer'), findsOneWidget);
    expect(find.text('HLF 20'), findsOneWidget);
    expect(find.text('G3'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('ein Gerät in zwei Fahrzeugen zeigt beide Fundorte mit Menge',
      (tester) async {
    await seedFuhrpark();
    await pumpe(tester);
    await tippe(tester, 'schlauche');

    expect(find.text('C-Schläuche'), findsOneWidget);
    expect(find.text('HLF 20'), findsOneWidget);
    expect(find.text('LF 20'), findsOneWidget);
    expect(find.text('6×'), findsOneWidget);
    expect(find.text('4×'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('auf ein Fahrzeug vorgewählt: was fehlt, steht trotzdem da',
      (tester) async {
    // Der Fall, für den die Fahrzeug-Suche überhaupt gebaut wurde: Man steht
    // am LF und sucht den Spreizer. „Keine Treffer" wäre sachlich falsch.
    await seedFuhrpark();
    final lf = (await db.vehicleDao.getAll())
        .firstWhere((v) => v.name == 'LF 20');
    await pumpe(tester, vehicleId: lf.id);
    await tippe(tester, 'spreizer');

    expect(find.text('Nicht in diesem Fahrzeug — aber im Fuhrpark'),
        findsOneWidget);
    expect(find.text('HLF 20'), findsOneWidget);
    expect(find.text('G3'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('im eigenen Fahrzeug wird der Fahrzeugname nicht wiederholt',
      (tester) async {
    await seedFuhrpark();
    final hlf = (await db.vehicleDao.getAll())
        .firstWhere((v) => v.name == 'HLF 20');
    await pumpe(tester, vehicleId: hlf.id);
    await tippe(tester, 'spreizer');

    expect(find.text('G3'), findsOneWidget);
    // Der Name steht in der Fahrzeugwahl, nicht zusätzlich an jedem Treffer.
    expect(find.widgetWithText(InkWell, 'HLF 20'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('was im Katalog steht, aber nirgends liegt, wird gesagt',
      (tester) async {
    await seedFuhrpark();
    await pumpe(tester);
    await tippe(tester, 'wärmebild');

    expect(find.text('Im Katalog, aber nirgends verlastet'), findsOneWidget);
    expect(find.text('In keinem Fahrzeug eingetragen.'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('gar nichts Passendes sagt genau das', (tester) async {
    await seedFuhrpark();
    await pumpe(tester);
    await tippe(tester, 'hubschrauber');

    expect(find.textContaining('Kein Gerät gefunden'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('der Kurzname findet auch', (tester) async {
    await seedFuhrpark();
    await pumpe(tester);
    await tippe(tester, 'c42');

    expect(find.text('C-Schläuche'), findsOneWidget);
    expect(find.text('C42'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('ein leerer Fuhrpark lässt den Schirm stehen', (tester) async {
    // Frisch eingerichtetes Gerät: kein Fahrzeug, kein Gerät. Der Schirm
    // darf dann nichts finden, aber auch nicht umfallen.
    await pumpe(tester);
    await tippe(tester, 'spreizer');

    expect(find.textContaining('Kein Gerät gefunden'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await endTestApp(tester);
  });

  testWidgets('lange Fahrzeugnamen sprengen das Handy nicht', (tester) async {
    // Dieselbe Engstelle wie in Issue #172, nur an zwei neuen Stellen: die
    // Fahrzeugwahl und der Fahrzeugname an jedem Fundort. Flutter lässt den
    // Test bei „RenderFlex overflowed" fallen.
    await db.vehicleDao.insertVehicle(VehiclesCompanion.insert(
        name: 'HLF 20/16 Florian Musterstadt 1/44', type: 'HLF 20'));
    final fach = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(
            vehicleId: 1, label: 'G1', seite: const Value('fahrerseite')));
    final geraet = await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(name: 'Hydraulischer Rettungsspreizer'));
    await db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: fach, equipmentId: geraet));

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestApp(db: db, home: const GeraeteSucheScreen()));
    await tester.pumpAndSettle();
    await tippe(tester, 'spreizer');

    expect(find.text('Hydraulischer Rettungsspreizer'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await endTestApp(tester);
  });
}
