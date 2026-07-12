/// inspection_schedule.dart – Recurring Prüfung or one-shot Ablaufdatum for an
/// equipment instance (pure Dart, no Flutter/Drift dependencies).
library;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'inspection_schedule.freezed.dart';

enum InspectionKind {
  recurring('recurring', 'Wiederkehrende Prüfung'),
  expiry('expiry', 'Ablaufdatum');

  final String dbValue;
  final String label;
  const InspectionKind(this.dbValue, this.label);

  static InspectionKind fromDb(String value) => InspectionKind.values
      .firstWhere((k) => k.dbValue == value, orElse: () => recurring);
}

@freezed
abstract class InspectionSchedule with _$InspectionSchedule {
  const InspectionSchedule._();

  const factory InspectionSchedule({
    required int id,
    required int instanceId,
    required InspectionKind kind,
    required String title,
    int? intervalMonths,
    DateTime? lastDoneAt,
    required DateTime dueAt,
    @Default('') String notes,
    required DateTime updatedAt,
  }) = _InspectionSchedule;

  bool isOverdue(DateTime now) => dueAt.isBefore(now);
}

@freezed
abstract class InspectionLogEntry with _$InspectionLogEntry {
  const factory InspectionLogEntry({
    required int id,
    required int scheduleId,
    required DateTime doneAt,
    @Default('') String doneBy,
    @Default('') String note,
  }) = _InspectionLogEntry;
}
