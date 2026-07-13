/// vehicle_cutaway_view.dart – 2D cutaway view (aufgeklappte Schnittdarstellung):
/// compartments as tappable tiles arranged by gridRow/gridCol/gridColSpan.
/// Reused by VehicleDetailScreen, the grid editor, and the training modes.
library;
import 'package:flutter/material.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';

enum CutawayTileStatus { normal, selected, correct, wrong }

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

  @override
  Widget build(BuildContext context) {
    final rows = layoutRows(compartments);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final row in rows)
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
    final scheme = Theme.of(context).colorScheme;
    final (Color fill, Color border, Color fg) = switch (state.status) {
      CutawayTileStatus.normal => (
          scheme.surfaceContainerHighest,
          scheme.outlineVariant,
          scheme.onSurface,
        ),
      CutawayTileStatus.selected => (
          scheme.primaryContainer,
          scheme.primary,
          scheme.onPrimaryContainer,
        ),
      CutawayTileStatus.correct => (
          Colors.green.shade100,
          Colors.green.shade700,
          Colors.green.shade900,
        ),
      CutawayTileStatus.wrong => (
          Colors.red.shade100,
          Colors.red.shade700,
          Colors.red.shade900,
        ),
    };

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
