/// compartment.dart – Compartment domain entity.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'compartment.freezed.dart';

@freezed
abstract class Compartment with _$Compartment {
  const factory Compartment({
    required int id,
    required int vehicleId,
    required String label,
    required int position,
    int? gridRow,
    int? gridCol,
    required int gridColSpan,
    required DateTime updatedAt,
  }) = _Compartment;
}
