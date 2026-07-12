/// inspection_repository_test.dart – markDone due-date logic and due queries.
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inspection/data/repositories/inspection_repository_impl.dart';
import 'package:fwapp/features/inspection/domain/entities/inspection_schedule.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InspectionRepositoryImpl repo;
  late int equipmentId;
  late int instanceId;

  setUp(() async {
    db = createTestDatabase();
    repo = InspectionRepositoryImpl(db.inspectionDao);
    equipmentId = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Pressluftatmer'));
    instanceId = await db.inspectionDao.insertInstance(
        EquipmentInstancesCompanion.insert(
            equipmentId: equipmentId, identifier: const Value('PA 1')));
  });

  tearDown(() => db.close());

  Future<InspectionSchedule> currentSchedule() async =>
      (await repo.watchSchedulesByInstance(instanceId).first).single;

  test('markDone on recurring schedule advances dueAt by intervalMonths',
      () async {
    await repo.insertSchedule(InspectionSchedule(
      id: 0,
      instanceId: instanceId,
      kind: InspectionKind.recurring,
      title: 'Jährliche Prüfung',
      intervalMonths: 12,
      dueAt: DateTime(2026, 7, 1),
      updatedAt: DateTime.now(),
    ));

    final doneAt = DateTime(2026, 7, 12);
    await repo.markDone(await currentSchedule(),
        doneAt: doneAt, doneBy: 'Marcus', note: 'alles i.O.');

    final updated = await currentSchedule();
    expect(updated.lastDoneAt, doneAt);
    expect(updated.dueAt, DateTime(2027, 7, 12));

    final log = await repo.getLog(updated.id);
    expect(log, hasLength(1));
    expect(log.single.doneBy, 'Marcus');
    expect(log.single.note, 'alles i.O.');
  });

  test('markDone on expiry schedule requires and applies nextDueAt', () async {
    await repo.insertSchedule(InspectionSchedule(
      id: 0,
      instanceId: instanceId,
      kind: InspectionKind.expiry,
      title: 'MHD Verbandmaterial',
      dueAt: DateTime(2026, 8, 1),
      updatedAt: DateTime.now(),
    ));
    final schedule = await currentSchedule();

    await expectLater(
      repo.markDone(schedule, doneAt: DateTime.now()),
      throwsArgumentError,
    );

    final newExpiry = DateTime(2031, 8, 1);
    await repo.markDone(schedule,
        doneAt: DateTime.now(), nextDueAt: newExpiry);
    expect((await currentSchedule()).dueAt, newExpiry);
  });

  test('due queries only count active instances within the window', () async {
    final vehicleId = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'AB-G', type: 'AB-G'));
    final instance =
        (await repo.watchInstancesByEquipment(equipmentId).first).single;
    await repo.updateInstance(instance.copyWith(vehicleId: vehicleId));

    final now = DateTime.now();
    // Overdue, due soon, and far-future schedule on the same instance.
    for (final (title, due) in [
      ('Überfällig', now.subtract(const Duration(days: 5))),
      ('Bald fällig', now.add(const Duration(days: 10))),
      ('Weit weg', now.add(const Duration(days: 200))),
    ]) {
      await repo.insertSchedule(InspectionSchedule(
        id: 0,
        instanceId: instanceId,
        kind: InspectionKind.expiry,
        title: title,
        dueAt: due,
        updatedAt: now,
      ));
    }

    final due = await repo.watchDueSoon(withinDays: 30).first;
    expect(due.map((e) => e.schedule.title), ['Überfällig', 'Bald fällig']);
    expect(due.first.vehicleName, 'AB-G');

    final counts = await repo.watchDueCountsByVehicle().first;
    expect(counts[vehicleId], (overdueCount: 1, dueSoonCount: 1));

    // Deactivated instances disappear from due lists.
    final active =
        (await repo.watchInstancesByEquipment(equipmentId).first).single;
    await repo.updateInstance(active.copyWith(isActive: false));
    expect(await repo.watchDueSoon(withinDays: 30).first, isEmpty);
  });
}
