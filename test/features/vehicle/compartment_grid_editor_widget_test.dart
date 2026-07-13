/// compartment_grid_editor_widget_test.dart – Grid editor tab: placing a
/// compartment persists gridRow/gridCol and updates the cutaway layout.
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
    vehicleId = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'AB-G', type: 'AB-G'));
    for (final (i, label) in ['Dach', 'G1', 'G2'].indexed) {
      await db.compartmentDao.insertCompartment(CompartmentsCompanion.insert(
          vehicleId: vehicleId, label: label, position: Value(i)));
    }
  });

  tearDown(() => db.close());

  testWidgets('Kachel im Raster platzieren persistiert Zeile/Spalte/Breite',
      (tester) async {
    await tester.pumpWidget(buildTestApp(
        db: db, home: CompartmentManagerScreen(vehicleId: vehicleId)));
    await tester.pumpAndSettle();

    // Zum Raster-Tab wechseln: alle Fächer sind unplatziert.
    await tester.tap(find.text('Raster'));
    await tester.pumpAndSettle();
    expect(find.textContaining('noch nicht platziert'), findsOneWidget);

    // "Dach" antippen → Editor-Sheet → Breite auf 3 erhöhen → speichern.
    await tester.tap(find.text('Dach'));
    await tester.pumpAndSettle();
    expect(find.text('Breite (Spalten)'), findsOneWidget);
    final plusButtons = find.byIcon(Icons.add_circle_outline);
    await tester.tap(plusButtons.last); // Breite 1 → 2
    await tester.pump();
    await tester.tap(plusButtons.last); // Breite 2 → 3
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Persistiert: Dach liegt auf (0,0) mit Breite 3.
    final compartments = await db.compartmentDao.getByVehicle(vehicleId);
    final dach = compartments.firstWhere((c) => c.label == 'Dach');
    expect(dach.gridRow, 0);
    expect(dach.gridCol, 0);
    expect(dach.gridColSpan, 3);

    // Hinweis zählt nur noch die zwei unplatzierten Fächer.
    expect(find.textContaining('2 Fach/Fächer noch nicht platziert'),
        findsOneWidget);

    // "Aus Raster entfernen" setzt die Platzierung zurück.
    await tester.tap(find.text('Dach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus Raster entfernen'));
    await tester.pumpAndSettle();
    final reset = (await db.compartmentDao.getByVehicle(vehicleId))
        .firstWhere((c) => c.label == 'Dach');
    expect(reset.gridRow, isNull);
    expect(reset.gridColSpan, 1);

    await endTestApp(tester);
  });
}
