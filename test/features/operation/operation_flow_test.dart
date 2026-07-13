/// operation_flow_test.dart – Einsatzassistent: Session-Logik und die
/// Ausladen-Interaktion (Gerät entnehmen → Fortschritt, Entnommen-Liste).
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
import 'package:fwapp/features/operation/presentation/providers/operation_providers.dart';
import 'package:fwapp/features/operation/presentation/screens/operation_run_screen.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late int vehicleId;
  late int compartmentId;
  late int assignmentId;

  setUp(() async {
    db = createTestDatabase();
    vehicleId = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF'));
    compartmentId = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
    final equipmentId = await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(name: 'Spineboard'));
    assignmentId = await db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: compartmentId,
            equipmentId: equipmentId,
            quantity: const Value(1)));
  });

  tearDown(() => db.close());

  test('OperationNotifier: start, toggle, end', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(operationProvider.notifier);

    notifier.start(
        vehicleIds: [vehicleId], scenario: DeploymentScenario.vuPkw);
    var state = container.read(operationProvider);
    expect(state.active, isTrue);
    expect(state.scenario, DeploymentScenario.vuPkw);
    expect(state.isTaken(assignmentId), isFalse);

    notifier.toggleTaken(assignmentId);
    expect(container.read(operationProvider).isTaken(assignmentId), isTrue);
    notifier.toggleTaken(assignmentId);
    expect(container.read(operationProvider).isTaken(assignmentId), isFalse);

    notifier.end();
    expect(container.read(operationProvider).active, isFalse);
  });

  testWidgets('Ausladen-Screen ohne aktiven Einsatz zeigt Startaufforderung',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: OperationRunScreen()),
    ));
    await tester.pump();
    expect(find.text('Einsatz starten'), findsOneWidget);
  });

  testWidgets('Ausladen-Screen mit aktivem Einsatz baut die Ansicht auf',
      (tester) async {
    final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    container.read(operationProvider.notifier).start(vehicleIds: [vehicleId]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: OperationRunScreen()),
    ));
    // Gezielt pumpen (kein pumpAndSettle wegen DB-Async + Sheet-Animation).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ausladen'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
