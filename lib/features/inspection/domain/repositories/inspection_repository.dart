/// inspection_repository.dart – Abstract interface for instance/inspection data access.
library;
import 'package:fwapp/features/inspection/domain/entities/due_inspection_entry.dart';
import 'package:fwapp/features/inspection/domain/entities/equipment_instance.dart';
import 'package:fwapp/features/inspection/domain/entities/inspection_schedule.dart';

abstract class InspectionRepository {
  // Instances
  Stream<List<EquipmentInstance>> watchInstancesByEquipment(int equipmentId);
  Future<int> insertInstance(EquipmentInstance instance);
  Future<void> updateInstance(EquipmentInstance instance);
  Future<void> deleteInstance(int id);

  // Schedules
  Stream<List<InspectionSchedule>> watchSchedulesByInstance(int instanceId);
  Future<int> insertSchedule(InspectionSchedule schedule);
  Future<void> updateSchedule(InspectionSchedule schedule);
  Future<void> deleteSchedule(int id);

  // History
  Future<List<InspectionLogEntry>> getLog(int scheduleId);

  /// Logs a completed Prüfung and advances dueAt.
  /// Recurring: next dueAt = doneAt + intervalMonths (or [nextDueAt] if given).
  /// Expiry: [nextDueAt] is required (the replacement's new expiry date).
  Future<void> markDone(
    InspectionSchedule schedule, {
    required DateTime doneAt,
    String doneBy,
    String note,
    DateTime? nextDueAt,
  });

  // Due queries
  Stream<List<DueInspectionEntry>> watchDueSoon({int withinDays});
  Stream<Map<int, DueCounts>> watchDueCountsByVehicle({int withinDays});
}
