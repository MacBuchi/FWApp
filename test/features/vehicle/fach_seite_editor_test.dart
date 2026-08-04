/// fach_seite_editor_test.dart – Die Seite eines Fachs pflegen (Issue #126).
///
/// Der heikle Teil ist nicht das Auswahlfeld, sondern der Vorschlag: „ungerade
/// Nummer = Fahrerseite" ist eine verbreitete Konvention, keine
/// Naturkonstante. Deshalb muss er sichtbar sein, bestätigt werden und darf
/// nichts überschreiben, was ein Mensch schon gesetzt hat. Genau das prüft
/// diese Datei über die Oberfläche.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/vehicle/presentation/screens/compartment_manager_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;
  late int vehicleId;

  setUp(() async {
    db = createTestDatabase();
    vehicleId = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
  });

  tearDown(() => db.close());

  Future<int> fach(String label, {String? seite}) =>
      db.compartmentDao.insertCompartment(CompartmentsCompanion.insert(
        vehicleId: vehicleId,
        label: label,
        seite: Value(seite),
      ));

  Future<void> oeffne(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: CompartmentManagerScreen(vehicleId: vehicleId),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('die Liste nennt die Seite jedes Fachs', (tester) async {
    await fach('G1', seite: 'fahrerseite');
    await fach('Ablage');
    await oeffne(tester);

    expect(find.textContaining('Fahrerseite · Position 1'), findsOneWidget);
    expect(find.textContaining('Ohne Seite · Position 1'), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('beim Anlegen folgt die Seite dem getippten Namen',
      (tester) async {
    await oeffne(tester);
    await tester.tap(find.byTooltip('Fach hinzufügen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'G3');
    await tester.pumpAndSettle();
    // Der Vorschlag steht im Auswahlfeld, bevor irgendjemand es anfasst.
    expect(find.text('Fahrerseite'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();

    final gespeichert = await db.compartmentDao.getByVehicle(vehicleId);
    expect(gespeichert.single.label, 'G3');
    expect(gespeichert.single.seite, 'fahrerseite');
    await endTestApp(tester);
  });

  testWidgets('eine von Hand gewählte Seite überlebt weitere Tipper',
      (tester) async {
    await oeffne(tester);
    await tester.tap(find.byTooltip('Fach hinzufügen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'G3');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dach').last);
    await tester.pumpAndSettle();

    // Ab dem ersten Handgriff gewinnt der Mensch — auch wenn der Name sich
    // danach noch ändert.
    await tester.enterText(find.byType(TextField), 'G4');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();

    final gespeichert = await db.compartmentDao.getByVehicle(vehicleId);
    expect(gespeichert.single.seite, 'dach');
    await endTestApp(tester);
  });

  group('der Vorschlag für den Bestand', () {
    testWidgets('erscheint nur, wenn es etwas vorzuschlagen gibt',
        (tester) async {
      await fach('Ablage'); // kein Anhaltspunkt im Namen
      await oeffne(tester);
      expect(find.byTooltip('Seiten aus den Namen vorschlagen'), findsNothing);
      await endTestApp(tester);
    });

    testWidgets('listet auf, was er tun würde, und tut es erst nach dem Ja',
        (tester) async {
      await fach('G1');
      await fach('G2');
      await oeffne(tester);

      await tester.tap(find.byTooltip('Seiten aus den Namen vorschlagen'));
      await tester.pumpAndSettle();
      expect(find.text('G1 → Fahrerseite'), findsOneWidget);
      expect(find.text('G2 → Beifahrerseite'), findsOneWidget);

      // Abbrechen ändert nichts.
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      var stand = await db.compartmentDao.getByVehicle(vehicleId);
      expect(stand.every((c) => c.seite == null), isTrue);

      await tester.tap(find.byTooltip('Seiten aus den Namen vorschlagen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '2 übernehmen'));
      await tester.pumpAndSettle();

      stand = await db.compartmentDao.getByVehicle(vehicleId);
      expect(stand.firstWhere((c) => c.label == 'G1').seite, 'fahrerseite');
      expect(stand.firstWhere((c) => c.label == 'G2').seite, 'beifahrerseite');
      await endTestApp(tester);
    });

    testWidgets('rührt nicht an, was schon von Hand gesetzt wurde',
        (tester) async {
      // Der wichtigste Fall: Wer G2 bewusst aufs Dach gelegt hat, hat dafür
      // einen Grund, den die Namenskonvention nicht kennt.
      await fach('G1');
      await fach('G2', seite: 'dach');
      await oeffne(tester);

      await tester.tap(find.byTooltip('Seiten aus den Namen vorschlagen'));
      await tester.pumpAndSettle();
      expect(find.text('G1 → Fahrerseite'), findsOneWidget);
      expect(find.textContaining('G2 →'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, '1 übernehmen'));
      await tester.pumpAndSettle();

      final stand = await db.compartmentDao.getByVehicle(vehicleId);
      expect(stand.firstWhere((c) => c.label == 'G2').seite, 'dach');
      await endTestApp(tester);
    });
  });
}
