/// geteilter_bestand_hinweis.dart – Die eine Zeile, die sagt, wie weit eine
/// Änderung reicht (Nutzerkonzept Stufe ②, Issue #99).
///
/// Gerätetypen gehören der GESAMTWEHR, Exemplare und Zuordnungen der
/// Abteilung. Von außen sieht man einem Gerät das nicht an — dieselbe Liste,
/// dieselbe Detailseite. Deshalb sagt es diese Zeile ausdrücklich, und zwar
/// bevor jemand tippt: Wer den Namen ändert, ändert ihn für Grombach mit.
library;

import 'package:flutter/material.dart';

class GeteilterBestandHinweis extends StatelessWidget {
  final String text;

  /// Wartet die Änderung noch auf die Verteilung? Dann bekommt der Hinweis
  /// die Warnfarbe — offline gespeichert ist eben noch nicht geteilt.
  final bool offen;

  const GeteilterBestandHinweis({
    super.key,
    required this.text,
    this.offen = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hintergrund =
        offen ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final vordergrund =
        offen ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hintergrund,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(offen ? Icons.cloud_upload_outlined : Icons.groups,
              size: 20, color: vordergrund),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: vordergrund))),
        ],
      ),
    );
  }
}
