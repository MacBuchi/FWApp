/// compartment_assignment_widget_test.dart – Geräte von Hand ins Fach legen
/// (Issue #86).
///
/// Warum als Widget-Test: Der Defekt war keine kaputte Logik, sondern eine
/// FEHLENDE Bedienstelle — es gab keinen Weg von einem Gerät in ein Fach
/// außer Import und Vorlage. Genau das kann nur ein Test über die Oberfläche
/// festhalten.
library;
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
  late int compartmentId;

  setUp(() async {
    db = createTestDatabase();
    vehicleId = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
    compartmentId = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
    await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Leitkegel'));
    await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Spineboard'));
  });

  tearDown(() => db.close());

  Future<void> oeffneFach(WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
        db: db, home: VehicleDetailScreen(vehicleId: vehicleId)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('G1').last);
    await tester.pumpAndSettle();
  }

  testWidgets('ein Gerät lässt sich von Hand ins Fach legen', (tester) async {
    await oeffneFach(tester);
    expect(find.text('Kein Gerät zugewiesen.'), findsOneWidget);

    await tester.tap(find.text('Gerät zuweisen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leitkegel'));
    await tester.pumpAndSettle();

    final zuweisungen = await db.assignmentDao.getByCompartment(compartmentId);
    expect(zuweisungen, hasLength(1));
    expect(zuweisungen.single.quantity, 1);
    await endTestApp(tester);
  });

  testWidgets('die Suche filtert die Auswahl', (tester) async {
    await oeffneFach(tester);
    await tester.tap(find.text('Gerät zuweisen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'spine');
    await tester.pumpAndSettle();
    expect(find.text('Spineboard'), findsOneWidget);
    expect(find.text('Leitkegel'), findsNothing);
    await endTestApp(tester);
  });

  testWidgets('der Anlege-Weg reicht den Suchbegriff als Namen weiter',
      (tester) async {
    // Das ist Marcus' Aufnahme-Ablauf: Raum für Raum durchgehen und
    // unterwegs anlegen, was noch fehlt — ohne den Begriff zweimal zu tippen.
    await oeffneFach(tester);
    await tester.tap(find.text('Gerät zuweisen'));
    await tester.pumpAndSettle();
    expect(find.text('Neues Gerät anlegen'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Pylone');
    await tester.pumpAndSettle();
    // Groß-/Kleinschreibung bleibt, wie sie getippt wurde — der Text wird
    // zum Gerätenamen, nicht nur zum Suchfilter.
    expect(find.text('„Pylone“ neu anlegen'), findsOneWidget);
    await endTestApp(tester);
  });

  testWidgets('ein zugewiesenes Gerät lässt sich wieder entfernen',
      (tester) async {
    final equipmentId = (await db.equipmentDao.getAll()).first.id;
    await db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: compartmentId, equipmentId: equipmentId));

    await oeffneFach(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus dem Fach entfernen'));
    await tester.pumpAndSettle();

    expect(await db.assignmentDao.getByCompartment(compartmentId), isEmpty);
    await endTestApp(tester);
  });

  testWidgets('ohne Schreibrecht gibt es keinen Zuweisen-Einstieg',
      (tester) async {
    // Spiegel des Rollen-Gates: Ein Mitglied liest den Bestand, es
    // verändert ihn nicht.
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: VehicleDetailScreen(vehicleId: vehicleId),
      overrides: [canEditProvider.overrideWithValue(false)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('G1').last);
    await tester.pumpAndSettle();

    expect(find.text('Gerät zuweisen'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    await endTestApp(tester);
  });
}
