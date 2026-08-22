/// fach_antwort.dart – Ein Fach als Antwortmöglichkeit: Farbpunkt, Fachname,
/// Verortung darunter (Issue #167, ausgelagert für #160).
///
/// **Warum hier und nicht in `core/widgets/`:** Das Widget hängt an
/// [seitenFarbe] und [verortungAnzeigename], beide im Feature `compartment`.
/// Ein Baustein in `core/`, der auf ein Feature zurückgreift, dreht die
/// Abhängigkeitsrichtung um — die Fach-Darstellung gehört zum Fach.
///
/// Gebraucht wird sie im Fach-Quiz und im Party-Modus. Die Alternative wäre
/// eine Kopie gewesen, und genau daran ist die Farbgebung vor #167 schon
/// einmal auseinandergelaufen.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';
import 'package:fwapp/features/compartment/presentation/seiten_farben.dart';

/// Eine Antwortmöglichkeit: der Fachname und wo das Fach liegt.
///
/// Verglichen wird über [label] — die Antwort ist der Fachname, nicht die
/// Verortung. Die Ortsangabe ist Beiwerk der Anzeige (Issue #167).
class FachAntwort {
  final String label;
  final String? seite;
  final String? laengsposition;

  const FachAntwort({
    required this.label,
    this.seite,
    this.laengsposition,
  });

  factory FachAntwort.ausFach(CompartmentData c) => FachAntwort(
        label: c.label,
        seite: c.seite,
        laengsposition: c.laengsposition,
      );

  /// „Fahrerseite · hinten", oder null für ein Fach ohne Seite — dann bleibt
  /// die Zeile weg, statt „Ohne Seite" als Antwort-Beiwerk zu behaupten.
  ///
  /// Auch weg, wenn sie nur den Fachnamen wiederholt: Ein Fach „Dach" mit der
  /// Unterzeile „Dach" sieht nach Fehler aus, nicht nach Hilfe.
  String? get verortung {
    if (seite == null) return null;
    final ort = verortungAnzeigename(seite, laengsposition);
    return ort.toLowerCase() == label.trim().toLowerCase() ? null : ort;
  }
}

/// Antwortknopf-Inhalt: Farbpunkt, Fachname, Ortsangabe darunter.
///
/// Dasselbe Bild wie die Fach-Karten im Fahrzeugmenü (Punkt links, Verortung
/// als Unterzeile) — wer im Quiz „G5 · Fahrerseite · hinten" liest, findet es
/// dort genauso wieder.
class FachAntwortInhalt extends StatelessWidget {
  final FachAntwort antwort;
  const FachAntwortInhalt({super.key, required this.antwort});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = seitenFarbe(antwort.seite);
    final ort = antwort.verortung;
    return Row(
      children: [
        if (farbe != null) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: farbe.akzent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(antwort.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (ort != null)
                Text(ort,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
