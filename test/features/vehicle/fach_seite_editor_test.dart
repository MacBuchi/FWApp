/// fach_seite_editor_test.dart – Seite und Längsposition eines Fachs pflegen
/// (Issue #126/#141).
///
/// Der heikle Teil ist nicht das Auswahlfeld, sondern der Vorschlag: „ungerade
/// Nummer = Fahrerseite" und „G1/G2 vorne, G3/G4 Mitte, G5/G6 hinten" sind
/// verbreitete Konventionen, keine Naturkonstanten. Deshalb muss der
/// Vorschlag sichtbar sein, bestätigt werden und darf nichts überschreiben,
/// was ein Mensch schon gesetzt hat. Genau das prüft diese Datei über die
/// Oberfläche.
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

  Future<int> fach(String label, {String? seite, String? laengsposition}) =>
      db.compartmentDao.insertCompartment(CompartmentsCompanion.insert(
        vehicleId: vehicleId,
        label: label,
        seite: Value(seite),
        laengsposition: Value(laengsposition),
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

  testWidgets('die Liste nennt die Verortung jedes Fachs', (tester) async {
    await fach('G1', seite: 'fahrerseite', laengsposition: 'vorne');
    await fach('GR', seite: 'heck');
    await fach('Ablage');
    await oeffne(tester);

    expect(find.textContaining('Fahrerseite · vorne · Reihenfolge 1'),
        findsOneWidget);
    expect(find.textContaining('Heck · Reihenfolge 1'), findsOneWidget);
    expect(find.textContaining('Ohne Seite · Reihenfolge 1'), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('beim Anlegen folgt die Verortung dem getippten Namen',
      (tester) async {
    await oeffne(tester);
    await tester.tap(find.byTooltip('Fach hinzufügen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'G3');
    await tester.pumpAndSettle();
    // Der Vorschlag steht in beiden Auswahlfeldern, bevor irgendjemand sie
    // anfasst: G3 → Fahrerseite, Mitte.
    expect(find.text('Fahrerseite'), findsOneWidget);
    expect(find.text('Mitte'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();

    final gespeichert = await db.compartmentDao.getByVehicle(vehicleId);
    expect(gespeichert.single.label, 'G3');
    expect(gespeichert.single.seite, 'fahrerseite');
    expect(gespeichert.single.laengsposition, 'mitte');
    await endTestApp(tester);
  });

  testWidgets('eine von Hand gewählte Seite überlebt weitere Tipper',
      (tester) async {
    await oeffne(tester);
    await tester.tap(find.byTooltip('Fach hinzufügen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'G3');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dach').last);
    await tester.pumpAndSettle();

    // Auf dem Dach gibt es kein vorne/Mitte/hinten — das Feld verschwindet.
    expect(find.text('Position an der Seite'), findsNothing);

    // Ab dem ersten Handgriff gewinnt der Mensch — auch wenn der Name sich
    // danach noch ändert.
    await tester.enterText(find.byType(TextField), 'G4');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();

    final gespeichert = await db.compartmentDao.getByVehicle(vehicleId);
    expect(gespeichert.single.seite, 'dach');
    expect(gespeichert.single.laengsposition, isNull,
        reason: 'abseits der Längsseiten wird keine Position gespeichert');
    await endTestApp(tester);
  });

  group('der Vorschlag für den Bestand', () {
    testWidgets('erscheint nur, wenn es etwas vorzuschlagen gibt',
        (tester) async {
      await fach('Ablage'); // kein Anhaltspunkt im Namen
      await oeffne(tester);
      expect(find.byTooltip('Verortung aus den Namen vorschlagen'),
          findsNothing);
      await endTestApp(tester);
    });

    testWidgets('listet auf, was er tun würde, und tut es erst nach dem Ja',
        (tester) async {
      await fach('G1');
      await fach('G2');
      await oeffne(tester);

      await tester.tap(find.byTooltip('Verortung aus den Namen vorschlagen'));
      await tester.pumpAndSettle();
      expect(find.text('G1 → Fahrerseite · vorne'), findsOneWidget);
      expect(find.text('G2 → Beifahrerseite · vorne'), findsOneWidget);

      // Abbrechen ändert nichts.
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      var stand = await db.compartmentDao.getByVehicle(vehicleId);
      expect(stand.every((c) => c.seite == null), isTrue);
      expect(stand.every((c) => c.laengsposition == null), isTrue);

      await tester.tap(find.byTooltip('Verortung aus den Namen vorschlagen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '2 übernehmen'));
      await tester.pumpAndSettle();

      stand = await db.compartmentDao.getByVehicle(vehicleId);
      expect(stand.firstWhere((c) => c.label == 'G1').seite, 'fahrerseite');
      expect(stand.firstWhere((c) => c.label == 'G1').laengsposition, 'vorne');
      expect(stand.firstWhere((c) => c.label == 'G2').seite, 'beifahrerseite');
      expect(stand.firstWhere((c) => c.label == 'G2').laengsposition, 'vorne');
      await endTestApp(tester);
    });

    testWidgets('rührt nicht an, was schon von Hand gesetzt wurde',
        (tester) async {
      // Der wichtigste Fall: Wer G2 bewusst aufs Dach gelegt hat, hat dafür
      // einen Grund, den die Namenskonvention nicht kennt.
      await fach('G1');
      await fach('G2', seite: 'dach');
      await oeffne(tester);

      await tester.tap(find.byTooltip('Verortung aus den Namen vorschlagen'));
      await tester.pumpAndSettle();
      expect(find.text('G1 → Fahrerseite · vorne'), findsOneWidget);
      expect(find.textContaining('G2 →'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, '1 übernehmen'));
      await tester.pumpAndSettle();

      final stand = await db.compartmentDao.getByVehicle(vehicleId);
      expect(stand.firstWhere((c) => c.label == 'G2').seite, 'dach');
      expect(stand.firstWhere((c) => c.label == 'G2').laengsposition, isNull);
      await endTestApp(tester);
    });

    testWidgets(
        'ein Bestand mit bestätigter Seite bekommt nur die Position dazu',
        (tester) async {
      // Der Bestandsfall nach Issue #126: Die Seiten sind längst bestätigt,
      // neu ist allein die Längsachse. Der Vorschlag füllt die Lücke und
      // fasst die Seite dabei nicht an.
      await fach('G3', seite: 'fahrerseite');
      await oeffne(tester);

      await tester.tap(find.byTooltip('Verortung aus den Namen vorschlagen'));
      await tester.pumpAndSettle();
      expect(find.text('G3 → Fahrerseite · Mitte'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '1 übernehmen'));
      await tester.pumpAndSettle();

      final stand = await db.compartmentDao.getByVehicle(vehicleId);
      expect(stand.single.seite, 'fahrerseite');
      expect(stand.single.laengsposition, 'mitte');
      await endTestApp(tester);
    });

    testWidgets(
        'wer der Nummern-Konvention widersprochen hat, bekommt keinen '
        'Positions-Vorschlag', (tester) async {
      // G3 liegt hier BEWUSST auf der Beifahrerseite — die Wehr zählt
      // anders. Dann ist auch „G3 = Mitte" nicht mehr gesichert, und es
      // gibt gar keinen Vorschlag statt eines halbgaren.
      await fach('G3', seite: 'beifahrerseite');
      await oeffne(tester);

      expect(find.byTooltip('Verortung aus den Namen vorschlagen'),
          findsNothing);
      await endTestApp(tester);
    });
  });
}
