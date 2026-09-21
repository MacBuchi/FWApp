/// inventory_service_test.dart – Inventurassistent-Logik: Soll-Snapshot beim
/// Start, Status setzen, Summary-Aggregation, Resume statt Doppelanlage.
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inventory/presentation/providers/inventory_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InventoryService service;
  late int vehicleId;
  late int compartmentId;

  setUp(() async {
    db = createTestDatabase();
    service = InventoryService(db);
    vehicleId = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF'));
    compartmentId = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
    for (final (name, qty) in [('Spineboard', 1), ('Feuerlöscher', 2)]) {
      final eq = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: name));
      await db.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
              compartmentId: compartmentId,
              equipmentId: eq,
              quantity: Value(qty)));
    }
  });

  tearDown(() => db.close());

  test('startOrResume snapshottet die Soll-Beladung', () async {
    final sessionId = await service.startOrResume(vehicleId);
    final checks = await db.inventoryDao.getChecks(sessionId);
    expect(checks, hasLength(2));
    expect(checks.map((c) => c.equipmentName),
        containsAll(['Spineboard', 'Feuerlöscher']));
    expect(checks.every((c) => c.status == InventoryChecks.statusOpen), isTrue);
    final loescher =
        checks.firstWhere((c) => c.equipmentName == 'Feuerlöscher');
    expect(loescher.targetQuantity, 2);
    expect(loescher.compartmentLabel, 'G1');
  });

  test('startOrResume nimmt offene Session wieder auf statt neu anzulegen',
      () async {
    final first = await service.startOrResume(vehicleId);
    final second = await service.startOrResume(vehicleId);
    expect(second, first);
    // Keine doppelten Checks.
    expect(await db.inventoryDao.getChecks(first), hasLength(2));
  });

  test('Status setzen und Summary-Aggregation', () async {
    final sessionId = await service.startOrResume(vehicleId);
    final checks = await db.inventoryDao.getChecks(sessionId);
    await service.setStatus(checks[0].id, InventoryChecks.statusOk);
    await service.setStatus(checks[1].id, InventoryChecks.statusMissing,
        note: 'nicht auffindbar');

    final updated = await db.inventoryDao.getChecks(sessionId);
    final summary = InventorySummary.from(updated);
    expect(summary.total, 2);
    expect(summary.checked, 2);
    expect(summary.ok, 1);
    expect(summary.missing, 1);
    expect(summary.complete, isTrue);
    expect(summary.hasIssues, isTrue);
    expect(
        updated.firstWhere((c) => c.status == InventoryChecks.statusMissing).note,
        'nicht auffindbar');
  });

  test('„in Reparatur" zählt als geprüft und als Abweichung', () async {
    // Der Zustand kam mit #178 dazu. Er darf nicht in `checked` fehlen —
    // sonst gilt eine vollständig durchgegangene Inventur als unfertig und
    // der Gerätewart sucht ein Gerät, das er selbst weggegeben hat.
    final sessionId = await service.startOrResume(vehicleId);
    final checks = await db.inventoryDao.getChecks(sessionId);
    await service.setStatus(checks[0].id, InventoryChecks.statusOk);
    await service.setStatus(checks[1].id, InventoryChecks.statusRepair,
        note: 'bei der Prüfstelle');

    final summary =
        InventorySummary.from(await db.inventoryDao.getChecks(sessionId));
    expect(summary.repair, 1);
    expect(summary.checked, 2);
    expect(summary.complete, isTrue);
    expect(summary.hasIssues, isTrue);
    // Und es ist KEIN fehlendes Gerät — die beiden dürfen nicht verschmelzen.
    expect(summary.missing, 0);
    expect(summary.damaged, 0);
  });

  test('ein Gerät in Reparatur erscheint im Bericht', () async {
    // Gegen den Fehler, der beim Hinzufügen eines Zustands am leichtesten
    // passiert: Die Aggregation kennt ihn, die Mängelliste filtert ihn weg.
    final sessionId = await service.startOrResume(vehicleId);
    final checks = await db.inventoryDao.getChecks(sessionId);
    await service.setStatus(checks[0].id, InventoryChecks.statusRepair);

    final updated = await db.inventoryDao.getChecks(sessionId);
    final abweichungen = updated
        .where((c) => InventorySummary.abweichendeStatus.contains(c.status));
    expect(abweichungen, hasLength(1));
    expect(abweichungen.first.status, InventoryChecks.statusRepair);
  });

  test('finish schließt die Session (kein Resume mehr)', () async {
    final sessionId = await service.startOrResume(vehicleId);
    await service.finish(sessionId, doneBy: 'Marcus');
    final session = await db.inventoryDao.getSession(sessionId);
    expect(session!.finishedAt, isNotNull);
    expect(session.doneBy, 'Marcus');
    // Neuer Start legt eine frische Session an.
    final next = await service.startOrResume(vehicleId);
    expect(next, isNot(sessionId));
  });
}
