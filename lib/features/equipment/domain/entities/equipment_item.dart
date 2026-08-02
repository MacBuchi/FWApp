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

    /// Verweis in den geteilten Typ-Bestand der Gesamtwehr (Stufe ②,
    /// Issue #99). `null` heißt: Dieses Gerät steht nur hier — im
    /// Lokalmodus, ohne Gesamtwehr, oder noch vor dem ersten Abgleich.
    String? remoteTypeId,

    /// Lokal geändert und noch nicht an die Gesamtwehr verteilt.
    @Default(false) bool typeDirty,
  }) = _EquipmentItem;
}
