/// vehicle.dart – Vehicle domain entity (pure Dart, no Flutter/Drift dependencies).
library;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'vehicle.freezed.dart';

@freezed
abstract class Vehicle with _$Vehicle {
  const factory Vehicle({
    required int id,
    required String name,
    required String type,
    String? licensePlate,
    String? imagePath,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Vehicle;
}
