/// inspection_repository_impl.dart – Drift-backed implementation of InspectionRepository.
library;
import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inspection/domain/entities/due_inspection_entry.dart';
import 'package:fwapp/features/inspection/domain/entities/equipment_instance.dart';
import 'package:fwapp/features/inspection/domain/entities/inspection_schedule.dart';
import 'package:fwapp/features/inspection/domain/repositories/inspection_repository.dart';

class InspectionRepositoryImpl implements InspectionRepository {
  final InspectionDao _dao;
  InspectionRepositoryImpl(this._dao);

  // ── Instances ──

  @override
  Stream<List<EquipmentInstance>> watchInstancesByEquipment(int equipmentId) =>
      _dao
          .watchInstancesByEquipment(equipmentId)
          .map((rows) => rows.map(_toInstance).toList());

  @override
  Future<int> insertInstance(EquipmentInstance instance) =>
      _dao.insertInstance(EquipmentInstancesCompanion.insert(
        equipmentId: instance.equipmentId,
        vehicleId: Value(instance.vehicleId),
        compartmentId: Value(instance.compartmentId),
        identifier: Value(instance.identifier),
        notes: Value(instance.notes),
        isActive: Value(instance.isActive),
      ));

  @override
  Future<void> updateInstance(EquipmentInstance instance) =>
      _dao.updateInstance(EquipmentInstancesCompanion(
        id: Value(instance.id),
        equipmentId: Value(instance.equipmentId),
        vehicleId: Value(instance.vehicleId),
        compartmentId: Value(instance.compartmentId),
        identifier: Value(instance.identifier),
        notes: Value(instance.notes),
        isActive: Value(instance.isActive),
        updatedAt: Value(DateTime.now()),
      ));

  @override
  Future<void> deleteInstance(int id) => _dao.deleteInstance(id);

  // ── Schedules ──

  @override
  Stream<List<InspectionSchedule>> watchSchedulesByInstance(int instanceId) =>
      _dao
          .watchSchedulesByInstance(instanceId)
          .map((rows) => rows.map(_toSchedule).toList());

  @override
  Future<int> insertSchedule(InspectionSchedule schedule) =>
      _dao.insertSchedule(InspectionSchedulesCompanion.insert(
        instanceId: schedule.instanceId,
        kind: schedule.kind.dbValue,
        title: schedule.title,
        intervalMonths: Value(schedule.intervalMonths),
        lastDoneAt: Value(schedule.lastDoneAt),
        dueAt: schedule.dueAt,
        notes: Value(schedule.notes),
      ));

  @override
  Future<void> updateSchedule(InspectionSchedule schedule) =>
      _dao.updateSchedule(_toScheduleCompanion(schedule));

  @override
  Future<void> deleteSchedule(int id) => _dao.deleteSchedule(id);

  // ── History ──

  @override
  Future<List<InspectionLogEntry>> getLog(int scheduleId) async {
    final rows = await _dao.getLogBySchedule(scheduleId);
    return rows
        .map((r) => InspectionLogEntry(
              id: r.id,
              scheduleId: r.scheduleId,
              doneAt: r.doneAt,
              doneBy: r.doneBy,
              note: r.note,
            ))
        .toList();
  }

  @override
  Future<void> markDone(
    InspectionSchedule schedule, {
    required DateTime doneAt,
    String doneBy = '',
    String note = '',
    DateTime? nextDueAt,
  }) async {
    final DateTime newDueAt;
    if (nextDueAt != null) {
      newDueAt = nextDueAt;
    } else if (schedule.kind == InspectionKind.recurring &&
        schedule.intervalMonths != null) {
      newDueAt = DateTime(
          doneAt.year, doneAt.month + schedule.intervalMonths!, doneAt.day);
    } else {
      throw ArgumentError(
          'nextDueAt is required for expiry schedules (new replacement date)');
    }
    await _dao.insertLogEntry(InspectionLogCompanion.insert(
      scheduleId: schedule.id,
      doneAt: doneAt,
      doneBy: Value(doneBy),
      note: Value(note),
    ));
    await _dao.updateSchedule(_toScheduleCompanion(
      schedule.copyWith(lastDoneAt: doneAt, dueAt: newDueAt),
    ));
  }

  // ── Due queries ──

  @override
  Stream<List<DueInspectionEntry>> watchDueSoon({int withinDays = 30}) =>
      _dao.watchDueSoon(withinDays: withinDays).map((rows) => rows
          .map((row) => DueInspectionEntry(
                schedule: _toSchedule(row.schedule),
                instance: _toInstance(row.instance),
                equipmentName: row.equipment.name,
                equipmentImagePath: row.equipment.imagePath,
                vehicleName: row.vehicle?.name,
              ))
          .toList());

  @override
  Stream<Map<int, DueCounts>> watchDueCountsByVehicle({int withinDays = 30}) =>
      _dao.watchDueCountsByVehicle(withinDays: withinDays);

  // ── Mapping ──

  EquipmentInstance _toInstance(EquipmentInstanceData row) =>
      EquipmentInstance(
        id: row.id,
        equipmentId: row.equipmentId,
        vehicleId: row.vehicleId,
        compartmentId: row.compartmentId,
        identifier: row.identifier,
        notes: row.notes,
        isActive: row.isActive,
        updatedAt: row.updatedAt,
      );

  InspectionSchedule _toSchedule(InspectionScheduleData row) =>
      InspectionSchedule(
        id: row.id,
        instanceId: row.instanceId,
        kind: InspectionKind.fromDb(row.kind),
        title: row.title,
        intervalMonths: row.intervalMonths,
        lastDoneAt: row.lastDoneAt,
        dueAt: row.dueAt,
        notes: row.notes,
        updatedAt: row.updatedAt,
      );

  InspectionSchedulesCompanion _toScheduleCompanion(InspectionSchedule s) =>
      InspectionSchedulesCompanion(
        id: Value(s.id),
        instanceId: Value(s.instanceId),
        kind: Value(s.kind.dbValue),
        title: Value(s.title),
        intervalMonths: Value(s.intervalMonths),
        lastDoneAt: Value(s.lastDoneAt),
        dueAt: Value(s.dueAt),
        notes: Value(s.notes),
        updatedAt: Value(DateTime.now()),
      );
}
