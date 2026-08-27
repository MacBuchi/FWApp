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

  /// Tippt, nachdem sichergestellt ist, dass das Ziel im Bild liegt.
  ///
  /// Der Fahrzeugschirm ist eine lange Liste und wächst mit jedem Abschnitt
  /// (zuletzt die Unterlagen, Issue #182). Ein blankes `tap` traf dann
  /// plötzlich neben den Knopf — auf einem 800×600-Prüfbild, das kein echtes
  /// Gerät ist. Scrollen ist ohnehin, was ein Mensch hier täte.
  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.ensureVisible(ziel);
    await tester.pumpAndSettle();
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  Future<void> oeffneFach(WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
        db: db, home: VehicleDetailScreen(vehicleId: vehicleId)));
    await tester.pumpAndSettle();
    await tippe(tester, find.text('G1').last);
  }

  testWidgets('ein Gerät lässt sich von Hand ins Fach legen', (tester) async {
    await oeffneFach(tester);
    expect(find.text('Kein Gerät zugewiesen.'), findsOneWidget);

    await tippe(tester, find.text('Gerät zuweisen'));
    // Seit Issue #149 wählt der Tipp aus, statt sofort zu schreiben — der
    // Knopf schließt ab. Für ein einzelnes Gerät ist das ein Tipp mehr, für
    // ein ganzes Fahrzeug sind es hunderte weniger.
    await tester.tap(find.text('Leitkegel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 Gerät zuweisen'));
    await tester.pumpAndSettle();

    final zuweisungen = await db.assignmentDao.getByCompartment(compartmentId);
    expect(zuweisungen, hasLength(1));
    expect(zuweisungen.single.quantity, 1);
    await endTestApp(tester);
  });

  testWidgets('die Suche filtert die Auswahl', (tester) async {
    await oeffneFach(tester);
    await tippe(tester, find.text('Gerät zuweisen'));

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
    await tippe(tester, find.text('Gerät zuweisen'));
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
    await tippe(tester, find.byIcon(Icons.more_vert).first);
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
    await tippe(tester, find.text('G1').last);

    expect(find.text('Gerät zuweisen'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    await endTestApp(tester);
  });
}
