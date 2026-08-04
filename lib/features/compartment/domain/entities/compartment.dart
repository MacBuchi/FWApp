/// compartment.dart – Compartment domain entity.
library;
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

    /// Fahrzeugseite für das Aufklappbild (Issue #126); `null` = noch nicht
    /// zugeordnet. Werte: fahrerseite | beifahrerseite | heck | dach | front
    /// (fahrzeug_seiten.dart).
    String? seite,
    required DateTime updatedAt,
  }) = _Compartment;
}
