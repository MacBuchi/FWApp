/// inspection_flow_widget_test.dart – Drives the Gerätewart UI: create an
/// instance + schedule in the equipment detail, see it on the dashboard and
/// as a vehicle badge, mark it done, watch the due date advance.
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_detail_screen.dart';
import 'package:fwapp/features/inspection/presentation/screens/inspection_dashboard_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_list_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;
  late int equipmentId;
  late int vehicleId;

  setUp(() async {
    db = createTestDatabase();
    vehicleId = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'AB-G', type: 'AB-G'));
    equipmentId = await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(name: 'Pressluftatmer'));
  });

  tearDown(() => db.close());

  testWidgets('Instanz + Prüfung anlegen über das Gerätedetail',
      (tester) async {
    await tester.pumpWidget(buildTestApp(
        db: db, home: EquipmentDetailScreen(equipmentId: equipmentId)));
    await tester.pumpAndSettle();

    // Leerer Zustand mit Hinweistext.
    expect(find.text('Instanzen & Prüfungen'), findsOneWidget);
    expect(find.textContaining('Keine Instanzen angelegt'), findsOneWidget);

    // Instanz anlegen.
    await tester.tap(find.byTooltip('Instanz hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Kennung (z.B. Seriennr., "Flasche 3")'),
        'PA 1');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('PA 1'), findsOneWidget);

    // Prüfung anlegen (wiederkehrend, Standardintervall 12 Monate).
    await tester.tap(find.text('PA 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prüfung hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Titel (z.B. "Jährliche Sichtprüfung")'),
        'Jährliche Prüfung');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    expect(find.text('Jährliche Prüfung'), findsOneWidget);
    expect(find.textContaining('alle 12 Monate'), findsOneWidget);

    // Datenbank-Nachweis: dueAt ≈ heute + 12 Monate.
    final schedules = await db.select(db.inspectionSchedules).get();
    final now = DateTime.now();
    expect(schedules.single.dueAt.year * 12 + schedules.single.dueAt.month,
        now.year * 12 + now.month + 12);

    await endTestApp(tester);
  });

  testWidgets(
      'überfällige Prüfung: Dashboard-Gruppe, Fahrzeug-Badge, Erledigt-Flow',
      (tester) async {
    // Überfällige Prüfung direkt in der DB anlegen.
    final instanceId = await db.inspectionDao.insertInstance(
        EquipmentInstancesCompanion.insert(
            equipmentId: equipmentId,
            vehicleId: Value(vehicleId),
            identifier: const Value('PA 1')));
    await db.inspectionDao.insertSchedule(InspectionSchedulesCompanion.insert(
      instanceId: instanceId,
      kind: 'recurring',
      title: 'Jährliche Prüfung',
      intervalMonths: const Value(12),
      dueAt: DateTime.now().subtract(const Duration(days: 10)),
    ));

    // Fahrzeugliste zeigt das rote Badge mit Zähler 1.
    await tester
        .pumpWidget(buildTestApp(db: db, home: const VehicleListScreen()));
    await tester.pumpAndSettle();
    // Name und Typ sind beide 'AB-G' → zwei Text-Widgets.
    expect(find.text('AB-G'), findsNWidgets(2));
    expect(find.byIcon(Icons.fact_check), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // Dashboard gruppiert als überfällig.
    await tester.pumpWidget(
        buildTestApp(db: db, home: const InspectionDashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Überfällig (1)'), findsOneWidget);
    expect(find.text('Pressluftatmer'), findsOneWidget);

    // Erledigt: Dialog bestätigen → Fälligkeit springt ein Jahr weiter,
    // Dashboard ist leer, Historie hat einen Eintrag.
    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Erledigt von (optional)'), 'Marcus');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    // SnackBar-Timer (4s) ablaufen lassen, sonst meldet das Test-Framework
    // einen hängenden Timer beim Abbau des Widget-Baums.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.textContaining('Keine fälligen Prüfungen'), findsOneWidget);

    final schedule = (await db.select(db.inspectionSchedules).get()).single;
    expect(schedule.lastDoneAt, isNotNull);
    expect(schedule.dueAt.isAfter(DateTime.now()), isTrue);
    final log = await db.inspectionDao.getLogBySchedule(schedule.id);
    expect(log.single.doneBy, 'Marcus');

    await endTestApp(tester);
  });
}
