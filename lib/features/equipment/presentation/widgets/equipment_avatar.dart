/// equipment_avatar.dart – Consistent visual identity for equipment items:
/// real photo when available, otherwise a category pictogram tile
/// (icon + colour per EquipmentFunction). Replaces the grey placeholder.
library;
import 'package:flutter/material.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';

/// Icon and colour per function category. Colours are mid-tone material
/// colours that read well on the tinted tile in light and dark mode.
(IconData, Color) equipmentCategoryStyle(EquipmentFunction? function) =>
    switch (function) {
      EquipmentFunction.rettung => (Icons.medical_services, Colors.red),
      EquipmentFunction.brand => (
          Icons.local_fire_department,
          Colors.deepOrange
        ),
      EquipmentFunction.wasser => (Icons.water_drop, Colors.blue),
      EquipmentFunction.pumpen => (Icons.compress, Colors.indigo),
      EquipmentFunction.beleuchtung => (Icons.light_mode, Colors.amber),
      EquipmentFunction.strom => (Icons.bolt, Colors.yellow),
      EquipmentFunction.lueftung => (Icons.air, Colors.lightBlue),
      EquipmentFunction.kommunikation => (Icons.headset_mic, Colors.purple),
      EquipmentFunction.messgeraete => (Icons.speed, Colors.teal),
      EquipmentFunction.absperren => (Icons.block, Colors.orange),
      EquipmentFunction.logistik => (Icons.inventory_2, Colors.brown),
      EquipmentFunction.fuehrung => (Icons.assignment, Colors.blueGrey),
      EquipmentFunction.psa => (Icons.masks, Colors.green),
      EquipmentFunction.armaturen => (Icons.plumbing, Colors.cyan),
      EquipmentFunction.abdichten => (Icons.do_not_disturb_on, Colors.lime),
      EquipmentFunction.dekon => (Icons.cleaning_services, Colors.lightGreen),
      EquipmentFunction.handwerkzeug => (Icons.handyman, Colors.grey),
      null => (Icons.category, Colors.grey),
    };

/// Photo when available, category pictogram tile otherwise.
class EquipmentAvatar extends StatelessWidget {
  final String? imagePath;

  /// UPPER_SNAKE function keys as stored in the DB / entity.
  final List<String> functions;
  final double size;

  /// Wide banner variant (detail/quiz headers) instead of a square tile.
  final double? width;

  const EquipmentAvatar({
    super.key,
    required this.imagePath,
    required this.functions,
    this.size = 48,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: resolveImage(
          path: imagePath,
          width: width ?? size,
          height: size,
        ),
      );
    }

    final function =
        functions.isEmpty ? null : EquipmentFunction.fromJson(functions.first);
    final (icon, color) = equipmentCategoryStyle(function);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = size * (width != null ? 0.4 : 0.55);

    return Container(
      width: width ?? size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: width != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: iconSize,
                    color: isDark ? color.shade300OrSelf : color.shade700OrSelf),
                if (function != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    function.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? color.shade300OrSelf : color.shade700OrSelf,
                    ),
                  ),
                ],
              ],
            )
          : Icon(icon,
              size: iconSize,
              color: isDark ? color.shade300OrSelf : color.shade700OrSelf),
    );
  }
}

extension on Color {
  /// MaterialColor shades when available, the colour itself otherwise.
  Color get shade700OrSelf => this is MaterialColor
      ? (this as MaterialColor).shade700
      : this;
  Color get shade300OrSelf => this is MaterialColor
      ? (this as MaterialColor).shade300
      : this;
}
