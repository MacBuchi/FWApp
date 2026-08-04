/// abzeichen_zeile.dart – Was am Kopf hängt, in Worten (Issue #135).
///
/// Die Marke am Avatar ist klein und stumm. Erst diese Zeile sagt, was sie
/// bedeutet und wie weit es bis zur nächsten Stufe ist — ohne sie wäre das
/// Abzeichen ein Ornament, über das man rätselt.
///
/// Eine Zeile für zwei Orte, weil beide dieselbe Aussage machen müssen: Auf
/// der Startseite steht die Zahl, aus der die Stufe entsteht, im Profil der
/// Kopf, an dem sie hängt. Liefen die beiden auseinander, wäre nicht mehr
/// erkennbar, dass es dieselbe Rechnung ist.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/features/profil/domain/leistungsabzeichen.dart';

class AbzeichenZeile extends StatelessWidget {
  const AbzeichenZeile({super.key, required this.level, this.kompakt = false});

  final int level;

  /// Für die Level-Karte auf der Startseite: Sie ist eine halbe
  /// Bildschirmbreite schmal, „Leistungsabzeichen in Bronze" passt dort
  /// nicht in eine Zeile. Der volle Satz steht im Profil.
  final bool kompakt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stufe = abzeichenFuerLevel(level);
    final name = stufe == null
        ? (kompakt ? 'Kein Abzeichen' : 'Noch kein Leistungsabzeichen')
        : (kompakt ? kAbzeichenNamen[stufe]! : abzeichenText(stufe));

    return Column(
      crossAxisAlignment:
          kompakt ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.military_tech,
              size: kompakt ? 16 : 20,
              // Ohne Stufe die gedämpfte Farbe: Ein bronzefarbenes Symbol
              // neben „Kein Abzeichen" liest sich wie ein Widerspruch.
              color: stufe == null
                  ? theme.colorScheme.outline
                  : kAbzeichenFarben[stufe],
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: kompakt
                    ? theme.textTheme.labelLarge
                    : theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Text(
          abzeichenFortschrittText(level),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
          textAlign: kompakt ? TextAlign.start : TextAlign.center,
        ),
      ],
    );
  }
}
