/// equipment_item.dart – EquipmentItem domain entity.
library;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'equipment_item.freezed.dart';

@freezed
abstract class EquipmentItem with _$EquipmentItem {
  const factory EquipmentItem({
    required int id,
    required String name,
    String? shortName,
    required List<String> equipmentFunctions,
    required List<String> deploymentScenarios,
    required String description,
    String? imagePath,
    String? trainingUrl,
    String? libraryEquipmentId,
    required bool isCustom,
    required Map<String, dynamic> extraAttributes,
    @Default([]) List<String> trainingQuestions,
    @Default([]) List<String> typicalUse,
    required DateTime updatedAt,
  }) = _EquipmentItem;
}
