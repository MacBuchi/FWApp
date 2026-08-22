/// vehicle_cutaway_view.dart – 2D cutaway view (aufgeklappte Schnittdarstellung):
/// compartments as tappable tiles arranged by gridRow/gridCol/gridColSpan.
/// Reused by VehicleDetailScreen, the grid editor, and the training modes.
///
/// Seit Issue #126 klappt die Ansicht das Fahrzeug auch wirklich auf: Hat
/// mindestens ein Fach eine Seite, entstehen beschriftete Bereiche in der
/// Reihenfolge Dach → Front → Fahrerseite → Heck → Beifahrerseite, also
/// einmal um das Fahrzeug herum. Hat KEIN Fach eine Seite, bleibt alles wie
/// vorher — ein Fahrzeug, das noch niemand zugeordnet hat, soll sich nicht
/// plötzlich anders anfühlen.
library;
import 'package:flutter/material.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';
import 'package:fwapp/features/compartment/presentation/seiten_farben.dart';

enum CutawayTileStatus { normal, selected, correct, wrong }

/// Kachelfarben eines Fachs — die EINE Entscheidung für beide Ansichten.
///
/// Die Seite ist die Farbe (seiten_farben.dart), im Aufklappbild genauso wie
/// in der Draufsicht. Bis Issue #167 hatte nur die Draufsicht sie: derselbe
/// Geräteraum war im Fahrzeugmenü blau und im Drag&Drop grau, obwohl die
/// Mannschaft genau an dieser Farbe lernt. Zwei Kopien desselben `switch`
/// waren der Grund, deshalb steht er jetzt einmal hier.
///
/// Grün/Richtig und Rot/Falsch stechen die Seitenfarbe: Im Lernmodus zählt
/// die Rückmeldung mehr als der Ort. Ohne Seite bleibt alles Theme-neutral —
/// ein unverortetes Fahrzeug soll sich nicht plötzlich anders anfühlen.
({Color fill, Color border, Color fg}) fachKachelFarben({
  required String? seite,
  required CutawayTileStatus status,
  required ColorScheme scheme,
  required Brightness brightness,
}) {
  final farbe = seitenFarbe(seite);
  return switch (status) {
    CutawayTileStatus.normal => farbe == null
        ? (
            fill: scheme.surfaceContainerHighest,
            border: scheme.outlineVariant,
            fg: scheme.onSurface,
          )
        : (
            fill: farbe.flaeche(brightness),
            border: farbe.rand(brightness),
            fg: farbe.text(brightness),
          ),
    CutawayTileStatus.selected => farbe == null
        ? (
            fill: scheme.primaryContainer,
            border: scheme.primary,
            fg: scheme.onPrimaryContainer,
          )
        : (fill: farbe.akzent, border: farbe.akzent, fg: Colors.white),
    CutawayTileStatus.correct => (
        fill: Colors.green.shade100,
        border: Colors.green.shade700,
        fg: Colors.green.shade900,
      ),
    CutawayTileStatus.wrong => (
        fill: Colors.red.shade100,
        border: Colors.red.shade700,
        fg: Colors.red.shade900,
      ),
  };
}

/// Häkchen oder Kreuz in der Ecke einer Kachel — die Rückmeldung, die ohne
/// Farbe auskommt. Bei `normal`/`selected` bleibt die Ecke leer.
///
/// Nötig geworden mit den Seitenfarben im Aufklappbild (Issue #167): Das Grün
/// des Hecks und das Grün für „richtig" liegen dicht beieinander, ebenso das
/// Rostrot der Beifahrerseite und das Rot für „falsch". Wer nur auf die
/// Fläche sieht, weiß dann nicht, ob er getroffen hat — und wer Rot und Grün
/// schlecht auseinanderhält, wusste es noch nie.
class FachStatusZeichen extends StatelessWidget {
  final CutawayTileStatus status;
  final Color farbe;
  final double size;

  const FachStatusZeichen({
    super.key,
    required this.status,
    required this.farbe,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) => switch (status) {
        CutawayTileStatus.correct =>
          Icon(Icons.check_circle, size: size, color: farbe),
        CutawayTileStatus.wrong => Icon(Icons.cancel, size: size, color: farbe),
        _ => const SizedBox.shrink(),
      };
}

class CutawayTileState {
  final CutawayTileStatus status;

  /// Shown as "N Geräte" under the label (ignored when [statusText] is set).
  final int? itemCount;

  /// Overrides the count line, e.g. "3/5 entnommen" during an Einsatz.
  final String? statusText;

  /// Red/orange inspection badge in the tile corner.
  final int dueBadgeCount;
  final bool dueBadgeIsOverdue;

  const CutawayTileState({
    this.status = CutawayTileStatus.normal,
    this.itemCount,
    this.statusText,
    this.dueBadgeCount = 0,
    this.dueBadgeIsOverdue = false,
  });
}

class VehicleCutawayView extends StatelessWidget {
  final List<Compartment> compartments;

  /// Per-compartment display state, keyed by compartment id.
  final Map<int, CutawayTileState> tileStates;
  final void Function(Compartment compartment)? onTapCompartment;

  /// Optional wrapper around each tile (e.g. a DragTarget in Drag&Drop mode).
  final Widget Function(Compartment compartment, Widget tile)?
      tileWrapperBuilder;
  final double tileHeight;

  const VehicleCutawayView({
    super.key,
    required this.compartments,
    this.tileStates = const {},
    this.onTapCompartment,
    this.tileWrapperBuilder,
    this.tileHeight = 76,
  });

  /// Rows of tiles: explicit grid placement if any compartment has grid
  /// coordinates, otherwise auto-flow by position into rows of 3.
  static List<List<Compartment>> layoutRows(List<Compartment> compartments) {
    final placed = compartments
        .where((c) => c.gridRow != null && c.gridCol != null)
        .toList();
    final unplaced = compartments
        .where((c) => c.gridRow == null || c.gridCol == null)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final rows = <List<Compartment>>[];
    if (placed.isNotEmpty) {
      final byRow = <int, List<Compartment>>{};
      for (final c in placed) {
        byRow.putIfAbsent(c.gridRow!, () => []).add(c);
      }
      final rowKeys = byRow.keys.toList()..sort();
      for (final key in rowKeys) {
        rows.add(byRow[key]!..sort((a, b) => a.gridCol!.compareTo(b.gridCol!)));
      }
    }
    // Unplaced compartments flow into trailing rows of 3.
    for (var i = 0; i < unplaced.length; i += 3) {
      rows.add(unplaced.sublist(
          i, i + 3 > unplaced.length ? unplaced.length : i + 3));
    }
    return rows;
  }

  /// Die Bereiche des Aufklappbilds, in der Reihenfolge einmal ums Fahrzeug.
  ///
  /// Leere Bereiche entstehen nicht: Ein Fahrzeug ohne Frontfach zeigt keine
  /// Überschrift „Front". Nicht zugeordnete Fächer kommen als letzter
  /// Bereich (`seite == null`) — sichtbar, aber nicht dazwischengemischt.
  ///
  /// Ohne jede Seitenangabe liefert die Funktion GENAU EINEN Bereich ohne
  /// Überschrift; daran hängt die Rückwärtskompatibilität.
  static List<({String? seite, List<List<Compartment>> reihen})> layoutBereiche(
      List<Compartment> compartments) {
    final mitSeite =
        compartments.where((c) => c.seite != null).toList(growable: false);
    if (mitSeite.isEmpty) {
      return [(seite: null, reihen: layoutRows(compartments))];
    }
    final bereiche = <({String? seite, List<List<Compartment>> reihen})>[];
    for (final seite in kFahrzeugSeiten) {
      final darin = compartments.where((c) => c.seite == seite).toList();
      if (darin.isEmpty) continue;
      bereiche.add((seite: seite, reihen: layoutRows(darin)));
    }
    // Unbekannte Werte (Server neuer als die App) landen bewusst hier statt
    // zu verschwinden — ein Fach, das man nicht mehr sieht, ist schlimmer
    // als eines unter der falschen Überschrift.
    final ohne = compartments
        .where((c) => c.seite == null || !kFahrzeugSeiten.contains(c.seite))
        .toList();
    if (ohne.isNotEmpty) {
      bereiche.add((seite: null, reihen: layoutRows(ohne)));
    }
    return bereiche;
  }

  @override
  Widget build(BuildContext context) {
    final bereiche = layoutBereiche(compartments);
    final mitUeberschrift = bereiche.length > 1 || bereiche.first.seite != null;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bereich in bereiche) ...[
          if (mitUeberschrift)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text(
                seiteAnzeigename(bereich.seite).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          for (final row in bereich.reihen)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (final c in row) ...[
                    Expanded(
                      flex: c.gridColSpan.clamp(1, 12),
                      child: _buildTile(context, c),
                    ),
                    if (c != row.last) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildTile(BuildContext context, Compartment c) {
    final state = tileStates[c.id] ?? const CutawayTileState();
    final tile = _CutawayTile(
      compartment: c,
      state: state,
      height: tileHeight,
      onTap:
          onTapCompartment == null ? null : () => onTapCompartment!(c),
    );
    return tileWrapperBuilder?.call(c, tile) ?? tile;
  }
}

class _CutawayTile extends StatelessWidget {
  final Compartment compartment;
  final CutawayTileState state;
  final double height;
  final VoidCallback? onTap;

  const _CutawayTile({
    required this.compartment,
    required this.state,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:fill, :border, :fg) = fachKachelFarben(
      seite: compartment.seite,
      status: state.status,
      scheme: theme.colorScheme,
      brightness: theme.brightness,
    );

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        compartment.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: fg),
                      ),
                      if (state.statusText != null)
                        Text(state.statusText!,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fg.withValues(alpha: 0.85)))
                      else if (state.itemCount != null)
                        Text('${state.itemCount} Geräte',
                            style: TextStyle(
                                fontSize: 11, color: fg.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: FachStatusZeichen(status: state.status, farbe: fg),
              ),
              if (state.dueBadgeCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: state.dueBadgeIsOverdue
                          ? Colors.red.shade700
                          : Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${state.dueBadgeCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
