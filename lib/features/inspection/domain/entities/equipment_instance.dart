/// equipment_instance.dart – Physical, trackable instance of an equipment type
/// (pure Dart, no Flutter/Drift dependencies).
library;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'equipment_instance.freezed.dart';

@freezed
abstract class EquipmentInstance with _$EquipmentInstance {
  const factory EquipmentInstance({
    required int id,
    required int equipmentId,
    int? vehicleId,
    int? compartmentId,
    String? identifier,
    @Default('') String notes,
    @Default(true) bool isActive,
    required DateTime updatedAt,
  }) = _EquipmentInstance;
}
