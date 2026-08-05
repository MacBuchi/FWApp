/// sammelzuweisung_test.dart – Mehrere Geräte auf einmal einsortieren
/// (Issue #149).
///
/// Warum das ein eigener Test ist: Der Mangel war keine falsche Rechnung,
/// sondern ein Ablauf, den niemand zu Ende geht. Fünf Fahrzeuge auf der
/// Anlage, kein einziges Gerät in einem echten Fach — die 63 Zuweisungen des
/// LF 20 lagen alle in einem Sammelfach „noch zuzuordnen", weil das Leeren
/// 63 Einzelgriffe gekostet hätte. Belegt wird deshalb beides: dass die
/// Datenschicht den Stapel korrekt schreibt UND dass es die Bedienstelle
/// dafür wirklich gibt.
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_detail_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;
  late int vehicleId;
  late int sammelfach;
  late int g1;
  late Map<String, int> geraete;

  setUp(() async {
    db = createTestDatabase();
    vehicleId = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
    sammelfach = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(
            vehicleId: vehicleId, label: 'Normbeladung – noch zuzuordnen'));
    g1 = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
    geraete = {};
    for (final name in ['Strahlrohr', 'Verteiler', 'Standrohr', 'Kupplung']) {
      geraete[name] = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: name));
    }
  });

  tearDown(() => db.close());

  Future<int> mengeIn(int fach, String geraet) async {
    final zeilen = await db.assignmentDao.getByCompartment(fach);
    return zeilen
        .where((a) => a.equipmentId == geraete[geraet])
        .fold<int>(0, (s, a) => s + a.quantity);
  }

  group('Datenschicht', () {
    test('assignMany schreibt den ganzen Stapel', () async {
      final geschrieben =
          await db.assignmentDao.assignMany(g1, geraete.values.toList());

      expect(geschrieben, 4);
      expect(await db.assignmentDao.getByCompartment(g1), hasLength(4));
    });

    test('assignMany überspringt, was schon im Fach liegt', () async {
      await db.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
              compartmentId: g1, equipmentId: geraete['Strahlrohr']!));

      final geschrieben = await db.assignmentDao
          .assignMany(g1, [geraete['Strahlrohr']!, geraete['Verteiler']!]);

      // Nur der Verteiler ist neu — das Strahlrohr bekommt keine zweite
      // Zeile, sonst stünde es doppelt in der Liste.
      expect(geschrieben, 1);
      expect(await db.assignmentDao.getByCompartment(g1), hasLength(2));
    });

    test('assignMany hält Doppelte in der eigenen Eingabe zurück', () async {
      final id = geraete['Strahlrohr']!;
      final geschrieben = await db.assignmentDao.assignMany(g1, [id, id, id]);

      expect(geschrieben, 1);
      expect(await db.assignmentDao.getByCompartment(g1), hasLength(1));
    });

    test('moveMany räumt das Sammelfach ins Zielfach', () async {
      await db.assignmentDao.assignMany(sammelfach, geraete.values.toList());
      final zeilen = await db.assignmentDao.getByCompartment(sammelfach);
      final zweiIds = zeilen.take(2).map((a) => a.id).toList();

      final bewegt = await db.assignmentDao.moveMany(zweiIds, g1);

      expect(bewegt, 2);
      expect(await db.assignmentDao.getByCompartment(g1), hasLength(2));
      expect(await db.assignmentDao.getByCompartment(sammelfach),
          hasLength(2));
    });

    test('moveMany führt zusammen, statt eine zweite Zeile anzulegen',
        () async {
      // Der Fall, den es ohne Unique-Schlüssel wirklich gibt: dasselbe Gerät
      // liegt im Ziel schon. Zwei Zeilen für ein Gerät im selben Fach hält
      // danach niemand mehr auseinander.
      final strahlrohr = geraete['Strahlrohr']!;
      await db.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
              compartmentId: g1,
              equipmentId: strahlrohr,
              quantity: const Value(2)));
      final quelle = await db.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
              compartmentId: sammelfach,
              equipmentId: strahlrohr,
              quantity: const Value(3)));

      final bewegt = await db.assignmentDao.moveMany([quelle], g1);

      expect(bewegt, 1);
      expect(await db.assignmentDao.getByCompartment(g1), hasLength(1));
      expect(await mengeIn(g1, 'Strahlrohr'), 5);
      expect(await db.assignmentDao.getByCompartment(sammelfach), isEmpty);
    });

    test('moveMany lässt das Ziel in Ruhe, wenn es schon das Ziel ist',
        () async {
      await db.assignmentDao.assignMany(g1, [geraete['Strahlrohr']!]);
      final id = (await db.assignmentDao.getByCompartment(g1)).single.id;

      expect(await db.assignmentDao.moveMany([id], g1), 0);
      expect(await db.assignmentDao.getByCompartment(g1), hasLength(1));
    });

    test('deleteAssignments entfernt den ganzen Stapel', () async {
      await db.assignmentDao.assignMany(g1, geraete.values.toList());
      final ids = (await db.assignmentDao.getByCompartment(g1))
          .map((a) => a.id)
          .toList();

      await db.assignmentDao.deleteAssignments(ids.take(3).toList());

      expect(await db.assignmentDao.getByCompartment(g1), hasLength(1));
    });
  });

  group('Oberfläche', () {
    Future<void> oeffneFach(WidgetTester tester, String label) async {
      // Große Prüffläche statt Scrollerei: In den 800×600 der Voreinstellung
      // rutscht schon das zweite Gerät der Liste unter die Kante, und
      // `tester.tap` trifft dann ins Leere statt zu scheitern (nur eine
      // Warnung). Gemessen an genau diesem Testlauf.
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildTestApp(
          db: db, home: VehicleDetailScreen(vehicleId: vehicleId)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('mehrere Geräte wandern mit einem Knopfdruck ins Fach',
        (tester) async {
      await oeffneFach(tester, 'G1');
      await tester.tap(find.text('Gerät zuweisen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Strahlrohr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verteiler'));
      await tester.pumpAndSettle();
      expect(find.text('2 Geräte zuweisen'), findsOneWidget);

      await tester.tap(find.text('2 Geräte zuweisen'));
      await tester.pumpAndSettle();

      expect(await db.assignmentDao.getByCompartment(g1), hasLength(2));
      await endTestApp(tester);
    });

    testWidgets('die Auswahl überlebt eine neue Sucheingabe', (tester) async {
      // Der Kern der Erleichterung: Man sucht „Strahl", hakt an, sucht
      // „Vertei", hakt an. Ginge die erste Auswahl beim Tippen verloren,
      // wäre die Mehrfachauswahl nur Zierde.
      await oeffneFach(tester, 'G1');
      await tester.tap(find.text('Gerät zuweisen'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Strahl');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Strahlrohr'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Vertei');
      await tester.pumpAndSettle();
      expect(find.text('Strahlrohr'), findsNothing);
      // Der Zähler steht weiter auf 1, obwohl das Gerät nicht mehr zu sehen
      // ist — die Auswahl hängt am Blatt, nicht an der Trefferliste.
      expect(find.text('1 Gerät zuweisen'), findsOneWidget);

      await tester.tap(find.text('Verteiler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 Geräte zuweisen'));
      await tester.pumpAndSettle();

      expect(await db.assignmentDao.getByCompartment(g1), hasLength(2));
      await endTestApp(tester);
    });

    testWidgets('langes Tippen öffnet die Auswahl im Fach', (tester) async {
      await db.assignmentDao.assignMany(sammelfach, geraete.values.toList());
      await oeffneFach(tester, 'Normbeladung – noch zuzuordnen');

      await tester.longPress(find.text('Strahlrohr'));
      await tester.pumpAndSettle();

      expect(find.text('1 ausgewählt'), findsOneWidget);
      await tester.tap(find.text('Verteiler'));
      await tester.pumpAndSettle();
      expect(find.text('2 ausgewählt'), findsOneWidget);
      await endTestApp(tester);
    });

    testWidgets('ausgewählte Geräte lassen sich in ein anderes Fach schieben',
        (tester) async {
      await db.assignmentDao.assignMany(sammelfach, geraete.values.toList());
      await oeffneFach(tester, 'Normbeladung – noch zuzuordnen');

      await tester.longPress(find.text('Strahlrohr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verteiler'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verschieben'));
      await tester.pumpAndSettle();
      // Der Dialog listet die anderen Fächer des Fahrzeugs — das Fach, in
      // dem man steht, gehört nicht dazu. ⚠️ Der Finder muss auf den Dialog
      // eingegrenzt werden: Der Fachname steht auch dahinter noch auf der
      // Karte, ein globales `findsNothing` wäre immer rot.
      final imDialog = find.descendant(
          of: find.byType(SimpleDialog), matching: find.byType(Text));
      expect(
          find.descendant(
              of: find.byType(SimpleDialog),
              matching: find.text('Normbeladung – noch zuzuordnen')),
          findsNothing);
      await tester.tap(imDialog.at(1));
      await tester.pumpAndSettle();

      expect(await db.assignmentDao.getByCompartment(g1), hasLength(2));
      expect(
          await db.assignmentDao.getByCompartment(sammelfach), hasLength(2));
      await endTestApp(tester);
    });

    testWidgets('ausgewählte Geräte lassen sich gemeinsam entfernen',
        (tester) async {
      await db.assignmentDao.assignMany(sammelfach, geraete.values.toList());
      await oeffneFach(tester, 'Normbeladung – noch zuzuordnen');

      await tester.longPress(find.text('Strahlrohr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verteiler'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aus dem Fach entfernen'));
      await tester.pumpAndSettle();

      expect(
          await db.assignmentDao.getByCompartment(sammelfach), hasLength(2));
      await endTestApp(tester);
    });

    testWidgets('ohne Schreibrecht öffnet langes Tippen keine Auswahl',
        (tester) async {
      // Spiegel des Rollen-Gates: Ein Mitglied liest den Bestand. Die
      // Sammelaktionen sind kein Sonderfall davon.
      await db.assignmentDao.assignMany(sammelfach, geraete.values.toList());
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildTestApp(
        db: db,
        home: VehicleDetailScreen(vehicleId: vehicleId),
        overrides: [canEditProvider.overrideWithValue(false)],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Normbeladung – noch zuzuordnen').last);
      await tester.pumpAndSettle();

      // Geprüft wird die Zeile selbst, nicht die Geste: Ohne Schreibrecht
      // hängt am langen Tippen gar kein Handler, und der kurze Tipp führt
      // weiterhin zum Gerät. Ein simuliertes Langdrücken liefe hier in
      // genau diese Navigation und würde etwas anderes messen.
      final zeile = tester.widget<ListTile>(find.ancestor(
          of: find.text('Strahlrohr'), matching: find.byType(ListTile)));
      expect(zeile.onLongPress, isNull);
      expect(find.byType(Checkbox), findsNothing);
      await endTestApp(tester);
    });
  });
}
