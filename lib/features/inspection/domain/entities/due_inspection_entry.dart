/// due_inspection_entry.dart – A due/soon-due schedule with display context
/// (pure Dart, no Flutter/Drift dependencies).
library;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fwapp/features/inspection/domain/entities/equipment_instance.dart';
import 'package:fwapp/features/inspection/domain/entities/inspection_schedule.dart';

part 'due_inspection_entry.freezed.dart';

/// Overdue / due-soon counts for one vehicle (for list badges).
typedef DueCounts = ({int overdueCount, int dueSoonCount});

@freezed
abstract class DueInspectionEntry with _$DueInspectionEntry {
  const DueInspectionEntry._();

  const factory DueInspectionEntry({
    required InspectionSchedule schedule,
    required EquipmentInstance instance,
    required String equipmentName,
    String? equipmentImagePath,
    String? vehicleName,
  }) = _DueInspectionEntry;

  bool isOverdue(DateTime now) => schedule.isOverdue(now);
}
