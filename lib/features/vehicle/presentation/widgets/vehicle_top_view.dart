/// vehicle_top_view.dart – Draufsicht auf das Fahrzeug (Issue #141):
/// Fahrtrichtung oben, Front oben, Fahrerseite links, Dach in der Mitte,
/// Beifahrerseite rechts, Heck unten. Jede Seite trägt ihre feste Farbe
/// (seiten_farben.dart), die Längsposition bestimmt den Platz in der Spalte.
///
/// Ein Blick = ganzes Fahrzeug. Und zwar überall DERSELBE Blick: Die
/// Fahrzeug-Übersicht, das Fach-Sheet und der Lernmodus „Wo liegt's?" nutzen
/// dieses eine Widget — gelernt wird immer am gleichen Bild.
///
/// Fächer ohne (oder mit unbekannter) Seite verschwinden nicht: Sie stehen
/// als eigener Bereich unter dem Schema, wie im Aufklappbild.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';
import 'package:fwapp/features/compartment/presentation/seiten_farben.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

class VehicleTopView extends StatelessWidget {
  final List<Compartment> compartments;

  /// Anzeige-Zustand je Fach, gleicher Typ wie im Aufklappbild — die
  /// Aufrufer sollen zwischen beiden Ansichten wechseln können, ohne ihre
  /// Zustände umzubauen.
  final Map<int, CutawayTileState> tileStates;
  final void Function(Compartment compartment)? onTapCompartment;

  /// Kompakt = Mini-Schema („wo finde ich das?"): kleiner, ohne
  /// Fahrtrichtungs-Zeile und ohne Geräte-Zähler.
  final bool kompakt;

  const VehicleTopView({
    super.key,
    required this.compartments,
    this.tileStates = const {},
    this.onTapCompartment,
    this.kompakt = false,
  });

  /// Trägt mindestens ein Fach eine bekannte Seite? Erst dann ergibt die
  /// Draufsicht ein Bild — vorher wäre sie ein leerer Rahmen.
  static bool hatVerortung(List<Compartment> compartments) =>
      compartments.any((c) => kFahrzeugSeiten.contains(c.seite));

  /// Die drei Plätze (vorne/Mitte/hinten) einer Längsseite.
  ///
  /// Fächer mit Längsposition liegen fest. Fächer ohne rücken von vorne nach
  /// hinten in die freien Plätze — die Sortier-Reihenfolge der Liste wird
  /// dann als Fahrtrichtung gelesen. Reicht der Platz nicht, hängen sie im
  /// hintersten Platz mit an: verschwinden darf nichts.
  static List<List<Compartment>> laengsSlots(List<Compartment> faecher) {
    final slots = List.generate(3, (_) => <Compartment>[]);
    final ohne = <Compartment>[];
    final sortiert = [...faecher]
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final c in sortiert) {
      final i = kLaengspositionen.indexOf(c.laengsposition ?? '');
      if (i >= 0) {
        slots[i].add(c);
      } else {
        ohne.add(c);
      }
    }
    var frei = 0;
    for (final c in ohne) {
      while (frei < slots.length && slots[frei].isNotEmpty) {
        frei++;
      }
      if (frei < slots.length) {
        slots[frei++].add(c);
      } else {
        slots.last.add(c);
      }
    }
    return slots;
  }

  List<Compartment> _seite(String seite) =>
      compartments.where((c) => c.seite == seite).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final front = _seite('front');
    final heck = _seite('heck');
    final dach = _seite('dach');
    final fahrer = laengsSlots(_seite('fahrerseite'));
    final beifahrer = laengsSlots(_seite('beifahrerseite'));
    final ohneSeite =
        compartments.where((c) => !kFahrzeugSeiten.contains(c.seite)).toList()
          ..sort((a, b) => a.position.compareTo(b.position));

    final slotHoehe = kompakt ? 34.0 : 72.0;
    final querHoehe = kompakt ? 26.0 : 56.0;
    final abstand = kompakt ? 3.0 : 5.0;
    final mittelHoehe = 3 * slotHoehe + 2 * abstand;

    Widget kachel(Compartment c) => _TopTile(
      compartment: c,
      state: tileStates[c.id] ?? const CutawayTileState(),
      kompakt: kompakt,
      onTap: onTapCompartment == null ? null : () => onTapCompartment!(c),
    );

    // Mehrere Fächer am selben Platz teilen sich seine Höhe — selten, aber
    // verschwinden darf keines.
    Widget slot(List<Compartment> faecher) => SizedBox(
      height: slotHoehe,
      child:
          faecher.isEmpty
              ? const SizedBox.shrink()
              : Column(
                children: [
                  for (final c in faecher) ...[
                    Expanded(child: kachel(c)),
                    if (c != faecher.last) SizedBox(height: abstand),
                  ],
                ],
              ),
    );

    Widget laengsSpalte(List<List<Compartment>> slots) => Column(
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          slot(slots[i]),
          if (i < slots.length - 1) SizedBox(height: abstand),
        ],
      ],
    );

    Widget querReihe(List<Compartment> faecher) => SizedBox(
      height: querHoehe,
      child: Row(
        children: [
          for (final c in faecher) ...[
            Expanded(child: kachel(c)),
            if (c != faecher.last) SizedBox(width: abstand),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!kompakt)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'FAHRTRICHTUNG ▲',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                letterSpacing: 1.5,
              ),
            ),
          ),
        Container(
          padding: EdgeInsets.all(kompakt ? 4 : 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(kompakt ? 10 : 18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (front.isNotEmpty) ...[
                querReihe(front),
                SizedBox(height: abstand),
              ],
              SizedBox(
                height: mittelHoehe,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: laengsSpalte(fahrer)),
                    SizedBox(width: abstand),
                    Expanded(
                      flex: 2,
                      child:
                          dach.isEmpty
                              ? const SizedBox.shrink()
                              : Column(
                                children: [
                                  for (final c in dach) ...[
                                    Expanded(child: kachel(c)),
                                    if (c != dach.last)
                                      SizedBox(height: abstand),
                                  ],
                                ],
                              ),
                    ),
                    SizedBox(width: abstand),
                    Expanded(flex: 3, child: laengsSpalte(beifahrer)),
                  ],
                ),
              ),
              if (heck.isNotEmpty) ...[
                SizedBox(height: abstand),
                querReihe(heck),
              ],
            ],
          ),
        ),
        if (ohneSeite.isNotEmpty && !kompakt) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              'OHNE SEITE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (var i = 0; i < ohneSeite.length; i += 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                height: querHoehe,
                child: Row(
                  children: [
                    for (final c in ohneSeite.sublist(
                      i,
                      i + 3 > ohneSeite.length ? ohneSeite.length : i + 3,
                    )) ...[
                      Expanded(child: kachel(c)),
                      const SizedBox(width: 6),
                    ],
                    // Lücken auffüllen, damit die letzte Reihe nicht breiter
                    // wirkt als die anderen.
                    for (
                      var j = 0;
                      j < (3 - (ohneSeite.length - i)).clamp(0, 2);
                      j++
                    )
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Legende unter der Draufsicht: Farbpunkt + Seitenname für jede Seite, die
/// am Fahrzeug vorkommt — samt der Merkregel als eigentlichem Inhalt.
class SeitenLegende extends StatelessWidget {
  final List<Compartment> compartments;
  const SeitenLegende({super.key, required this.compartments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seiten = [
      for (final s in kFahrzeugSeiten)
        if (compartments.any((c) => c.seite == s)) s,
    ];
    if (seiten.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final s in seiten)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: seitenFarbe(s)!.akzent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(seiteAnzeigename(s), style: theme.textTheme.labelMedium),
            ],
          ),
      ],
    );
  }
}

class _TopTile extends StatelessWidget {
  final Compartment compartment;
  final CutawayTileState state;
  final bool kompakt;
  final VoidCallback? onTap;

  const _TopTile({
    required this.compartment,
    required this.state,
    required this.kompakt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Farben wie im Aufklappbild — dieselbe Funktion, damit dasselbe Fach in
    // beiden Ansichten dieselbe Farbe trägt (Issue #167).
    final (:fill, :border, :fg) = fachKachelFarben(
      seite: compartment.seite,
      status: state.status,
      scheme: theme.colorScheme,
      brightness: theme.brightness,
    );

    final radius = BorderRadius.circular(kompakt ? 6 : 10);
    return Material(
      color: fill,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: kompakt ? 1 : 1.5),
            borderRadius: radius,
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        compartment.label,
                        textAlign: TextAlign.center,
                        maxLines: kompakt ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: kompakt ? 9.5 : 13,
                          color: fg,
                        ),
                      ),
                      if (!kompakt && state.statusText != null)
                        Text(
                          state.statusText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: fg.withValues(alpha: 0.85),
                          ),
                        )
                      else if (!kompakt && state.itemCount != null)
                        Text(
                          '${state.itemCount} Geräte',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: fg.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: kompakt ? 2 : 4,
                left: kompakt ? 2 : 4,
                child: FachStatusZeichen(
                  status: state.status,
                  farbe: fg,
                  size: kompakt ? 11 : 16,
                ),
              ),
              if (!kompakt && state.dueBadgeCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color:
                          state.dueBadgeIsOverdue
                              ? Colors.red.shade700
                              : Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${state.dueBadgeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
