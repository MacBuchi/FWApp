/// equipment_assignment.dart – EquipmentAssignment domain entity.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'equipment_assignment.freezed.dart';

@freezed
abstract class EquipmentAssignment with _$EquipmentAssignment {
  const factory EquipmentAssignment({
    required int id,
    required int compartmentId,
    required int equipmentId,
    required int quantity,
    required DateTime updatedAt,
  }) = _EquipmentAssignment;
}
