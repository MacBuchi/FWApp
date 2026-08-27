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

    /// Position entlang der Fahrzeuglängsachse (Issue #141); `null` = keine.
    /// Werte: vorne | mitte | hinten (fahrzeug_seiten.dart). Nur auf
    /// Fahrer-/Beifahrerseite sinnvoll — Heck, Dach und Front tragen ihren
    /// Ort schon in der Seite.
    String? laengsposition,

    /// Foto des Geräteraums (Issue #181); `null` = keins. Lokaler Pfad,
    /// solange das Bild nur auf diesem Gerät liegt, danach ein
    /// `supabase://`-Marker — dieselbe Form wie beim Gerätefoto.
    String? imagePath,
    required DateTime updatedAt,
  }) = _Compartment;
}
