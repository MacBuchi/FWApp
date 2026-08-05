/// vehicle_detail_screen.dart – Vehicle detail with cutaway view and
/// compartments list.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';
import 'package:fwapp/features/assignment/domain/entities/equipment_assignment.dart';
import 'package:fwapp/features/assignment/presentation/providers/assignment_providers.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';
import 'package:fwapp/features/compartment/presentation/providers/compartment_providers.dart';
import 'package:fwapp/features/compartment/presentation/seiten_farben.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:fwapp/features/inspection/presentation/providers/inspection_providers.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/domain/loesch_umfang.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_top_view.dart';

class VehicleDetailScreen extends ConsumerWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));
    final compartmentsAsync =
        ref.watch(compartmentListStreamProvider(vehicleId));

    return vehicleAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
      data: (vehicle) {
        if (vehicle == null) {
          return const Scaffold(
              body: Center(child: Text('Fahrzeug nicht gefunden.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(vehicle.name),
            actions: [
              if (ref.watch(canEditProvider)) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Bearbeiten',
                  onPressed: () => context.push('/vehicles/$vehicleId/edit'),
                ),
                IconButton(
                  icon: const Icon(Icons.view_module),
                  tooltip: 'Beladefächer verwalten',
                  onPressed: () =>
                      context.push('/vehicles/$vehicleId/compartments'),
                ),
                // Entfernen liegt im Menü, nicht als eigenes Symbol: Es ist
                // die einzige Aktion hier, die nichts wiederherstellen kann
                // (Issue #127).
                PopupMenuButton<String>(
                  onSelected: (_) => _entfernen(context, ref, vehicle),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'entfernen',
                      child: Text('Fahrzeug entfernen'),
                    ),
                  ],
                ),
              ],
              const AbteilungAction(),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // Vehicle header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: resolveImage(
                          path: vehicle.imagePath ?? kPlaceholderAsset,
                          width: double.infinity,
                          height: 160,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow('Typ', vehicle.type),
                      if (vehicle.licensePlate != null)
                        _InfoRow('Kennzeichen', vehicle.licensePlate!),
                    ],
                  ),
                ),
              ),
              // Cutaway view (Schnittdarstellung)
              SliverToBoxAdapter(
                child: compartmentsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (compartments) => compartments.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: _VehicleCutaway(
                              vehicleId: vehicleId,
                              compartments: compartments),
                        ),
                ),
              ),
              // Compartments
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Beladefächer',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (ref.watch(canEditProvider))
                        TextButton.icon(
                          onPressed: () => context
                              .push('/vehicles/$vehicleId/compartments'),
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Verwalten'),
                        ),
                    ],
                  ),
                ),
              ),
              compartmentsAsync.when(
                loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverToBoxAdapter(
                    child: Center(child: Text('Fehler: $e'))),
                data: (compartments) {
                  if (compartments.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Keine Fächer angelegt.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _CompartmentTile(compartment: compartments[index]),
                      childCount: compartments.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  /// Fahrzeug entfernen (Issue #127).
  ///
  /// Die Zahlen werden VOR der Rückfrage geholt, nicht danach: Sie sind der
  /// Inhalt der Frage. Ein Dialog, der erst nach dem Ja nachzählt, fragt
  /// nach nichts.
  Future<void> _entfernen(
      BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final faecher =
        await ref.read(compartmentRepositoryProvider).getByVehicle(vehicle.id);
    final beladung =
        await ref.read(assignmentRepositoryProvider).getByVehicle(vehicle.id);
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      // PFLICHT in der ShellRoute: Ohne den Wurzel-Navigator liegt der Dialog
      // im verschachtelten Navigator und die Navigationsleiste darüber
      // (#79/#96).
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrzeug entfernen?'),
        content: Text(fahrzeugEntfernenText(
          name: vehicle.name,
          faecher: faecher.length,
          beladung: beladung.length,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await ref.read(vehicleRepositoryProvider).delete(vehicle.id);
    if (!context.mounted) return;
    // Zurück zur Liste, BEVOR die Meldung kommt: Der Detail-Screen steht
    // sonst auf einem Fahrzeug, das es nicht mehr gibt, und zeigt
    // „Fahrzeug nicht gefunden".
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/vehicles');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('„${vehicle.name}" wurde entfernt.')),
    );
  }
}

/// Fahrzeugschema mit Geräte-Zählern und Prüf-Badges je Fach; Tippen öffnet
/// den Fach-Inhalt als Bottom Sheet.
///
/// Zwei Ansichten, ein Bild (Issue #141): Sobald mindestens ein Fach eine
/// Seite trägt, ist die **Draufsicht** der Standard — ein Blick = ganzes
/// Fahrzeug. Das Aufklappbild bleibt als zweite Ansicht erreichbar. Ohne
/// jede Seitenangabe bleibt alles wie vorher.
class _VehicleCutaway extends ConsumerStatefulWidget {
  final int vehicleId;
  final List<Compartment> compartments;
  const _VehicleCutaway(
      {required this.vehicleId, required this.compartments});

  @override
  ConsumerState<_VehicleCutaway> createState() => _VehicleCutawayState();
}

class _VehicleCutawayState extends ConsumerState<_VehicleCutaway> {
  bool _draufsicht = true;

  @override
  Widget build(BuildContext context) {
    final assignments =
        ref.watch(assignmentsByVehicleProvider(widget.vehicleId)).value ??
            const [];
    final dues = ref.watch(dueInspectionsStreamProvider()).value ?? const [];

    final itemCounts = <int, int>{};
    for (final a in assignments) {
      itemCounts[a.compartmentId] = (itemCounts[a.compartmentId] ?? 0) + 1;
    }
    final now = DateTime.now();
    final dueCounts = <int, int>{};
    final overdueByCompartment = <int, bool>{};
    for (final due in dues) {
      final compartmentId = due.instance.compartmentId;
      if (compartmentId == null) continue;
      dueCounts[compartmentId] = (dueCounts[compartmentId] ?? 0) + 1;
      if (due.isOverdue(now)) overdueByCompartment[compartmentId] = true;
    }

    final tileStates = {
      for (final c in widget.compartments)
        c.id: CutawayTileState(
          itemCount: itemCounts[c.id] ?? 0,
          dueBadgeCount: dueCounts[c.id] ?? 0,
          dueBadgeIsOverdue: overdueByCompartment[c.id] ?? false,
        ),
    };
    void oeffneFach(Compartment c) => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (_) => _CompartmentSheet(compartment: c),
        );

    if (!VehicleTopView.hatVerortung(widget.compartments)) {
      return VehicleCutawayView(
        compartments: widget.compartments,
        tileStates: tileStates,
        onTapCompartment: oeffneFach,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Draufsicht')),
              ButtonSegment(value: false, label: Text('Aufgeklappt')),
            ],
            selected: {_draufsicht},
            onSelectionChanged: (s) => setState(() => _draufsicht = s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_draufsicht) ...[
          VehicleTopView(
            compartments: widget.compartments,
            tileStates: tileStates,
            onTapCompartment: oeffneFach,
          ),
          const SizedBox(height: 8),
          SeitenLegende(compartments: widget.compartments),
        ] else
          VehicleCutawayView(
            compartments: widget.compartments,
            tileStates: tileStates,
            onTapCompartment: oeffneFach,
          ),
      ],
    );
  }
}

/// Bottom sheet listing the equipment of one compartment.
///
/// Der Kopf ist die Antwort auf „wo finde ich das?" (Issue #141): Seite als
/// Farbe, Verortung als Text, daneben das Mini-Schema mit dem markierten
/// Fach — dasselbe Bild wie in der Übersicht, nur kleiner.
class _CompartmentSheet extends ConsumerWidget {
  final Compartment compartment;
  const _CompartmentSheet({required this.compartment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetVerortungsKopf(compartment: compartment),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: _ZuweisungsListe(compartment: compartment),
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Geräteliste eines Fachs samt Sammelauswahl (Issue #149).
///
/// ⚠️ **Geteilt von beiden Wegen ins Fach:** der aufklappbaren Karte in der
/// Fächerliste und dem Fach-Blatt der Draufsicht. Sie zweimal zu bauen hätte
/// bedeutet, dass das Einsortieren je nach Ansicht anders geht — und die
/// Karte ist ausgerechnet der Weg, den ein Fahrzeug ohne Verortung zeigt,
/// also genau der, auf dem heute niemand einsortiert.
class _ZuweisungsListe extends ConsumerStatefulWidget {
  final Compartment compartment;
  const _ZuweisungsListe({required this.compartment});

  @override
  ConsumerState<_ZuweisungsListe> createState() => _ZuweisungsListeState();
}

class _ZuweisungsListeState extends ConsumerState<_ZuweisungsListe> {
  /// Ausgewählte ZUWEISUNGS-IDs (nicht Geräte-IDs) — verschoben und entfernt
  /// wird die Zeile, nicht das Gerät.
  final Set<int> _auswahl = {};

  /// Es gibt keinen eigenen Schalter für den Auswahlmodus: Langes Tippen
  /// beginnt ihn, das Abwählen des letzten Eintrags beendet ihn. Ein
  /// zusätzlicher Modus-Knopf wäre ein Zustand mehr, den man erklären müsste.
  bool get _auswahlModus => _auswahl.isNotEmpty;

  void _umschalten(int assignmentId) => setState(() {
        if (!_auswahl.add(assignmentId)) _auswahl.remove(assignmentId);
      });

  Future<void> _verschieben() async {
    final alle = ref
            .read(compartmentListStreamProvider(widget.compartment.vehicleId))
            .value ??
        const <Compartment>[];
    final ziele =
        alle.where((c) => c.id != widget.compartment.id).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    if (ziele.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Das Fahrzeug hat kein zweites Fach.')));
      return;
    }
    final anzahl = _auswahl.length;
    final ziel = await showDialog<Compartment>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(anzahl == 1
            ? 'Gerät verschieben nach …'
            : '$anzahl Geräte verschieben nach …'),
        children: [
          for (final c in ziele)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Row(
                children: [
                  // Derselbe Farbpunkt wie in der Draufsicht — beim
                  // Einsortieren am Fahrzeug denkt man in Seiten, nicht in
                  // Fachnamen.
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: seitenFarbe(c.seite)?.akzent ??
                          Theme.of(ctx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.label)),
                ],
              ),
            ),
        ],
      ),
    );
    if (ziel == null) return;
    final bewegt = await ref
        .read(assignmentRepositoryProvider)
        .moveMany(_auswahl.toList(), ziel.id);
    ref.invalidate(
        assignmentsByVehicleProvider(widget.compartment.vehicleId));
    if (!mounted) return;
    setState(_auswahl.clear);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(bewegt == 1
            ? '1 Gerät liegt jetzt in ${ziel.label}.'
            : '$bewegt Geräte liegen jetzt in ${ziel.label}.')));
  }

  Future<void> _entfernen() async {
    final anzahl = _auswahl.length;
    await ref.read(assignmentRepositoryProvider).deleteMany(_auswahl.toList());
    ref.invalidate(
        assignmentsByVehicleProvider(widget.compartment.vehicleId));
    if (!mounted) return;
    setState(_auswahl.clear);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(anzahl == 1
            ? '1 Gerät aus dem Fach entfernt.'
            : '$anzahl Geräte aus dem Fach entfernt.')));
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync =
        ref.watch(assignmentListStreamProvider(widget.compartment.id));
    final canEdit = ref.watch(canEditProvider);
    return assignmentsAsync.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(16), child: Text('Fehler: $e')),
      data: (assignments) => Column(
        children: [
          if (_auswahlModus)
            _AuswahlLeiste(
              anzahl: _auswahl.length,
              onVerschieben: _verschieben,
              onEntfernen: _entfernen,
              onAbbrechen: () => setState(_auswahl.clear),
            ),
          if (assignments.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kein Gerät zugewiesen.',
                    style: TextStyle(color: Colors.grey))),
          for (final a in assignments)
            _AssignmentRow(
              assignment: a,
              vehicleId: widget.compartment.vehicleId,
              ausgewaehlt: _auswahl.contains(a.id),
              auswahlModus: _auswahlModus,
              // Ohne Schreibrecht gibt es nichts zu verschieben — dann
              // bleibt die Zeile die Verknüpfung von früher.
              onAuswahl: canEdit ? () => _umschalten(a.id) : null,
            ),
          // Der bisher einzige Weg, ein Gerät in ein Fach zu bekommen, waren
          // Import und Vorlage — von Hand ging es schlicht nicht (Issue #86).
          // Deshalb hier, wo man das Fach vor sich hat.
          if (canEdit && !_auswahlModus)
            _AssignTile(compartment: widget.compartment),
        ],
      ),
    );
  }
}

/// Kopfleiste im Auswahlmodus: wie viele ausgewählt sind und was damit geht.
class _AuswahlLeiste extends StatelessWidget {
  final int anzahl;
  final VoidCallback onVerschieben;
  final VoidCallback onEntfernen;
  final VoidCallback onAbbrechen;

  const _AuswahlLeiste({
    required this.anzahl,
    required this.onVerschieben,
    required this.onEntfernen,
    required this.onAbbrechen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('$anzahl ausgewählt',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSecondaryContainer)),
          ),
          TextButton.icon(
            onPressed: onVerschieben,
            icon: const Icon(Icons.drive_file_move_outlined, size: 20),
            label: const Text('Verschieben'),
          ),
          IconButton(
            onPressed: onEntfernen,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Aus dem Fach entfernen',
          ),
          IconButton(
            onPressed: onAbbrechen,
            icon: const Icon(Icons.close),
            tooltip: 'Auswahl aufheben',
          ),
        ],
      ),
    );
  }
}

/// Kopfzeile des Fach-Sheets: eingefärbt in die Seitenfarbe, mit Verortung
/// in Worten, der Längs-Leiste und dem Mini-Schema. Ohne Seite bleibt es
/// die schlichte Überschrift von früher.
class _SheetVerortungsKopf extends ConsumerWidget {
  final Compartment compartment;
  const _SheetVerortungsKopf({required this.compartment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farbe = seitenFarbe(compartment.seite);
    if (farbe == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(compartment.label,
            style: Theme.of(context).textTheme.titleLarge),
      );
    }

    final alle = ref
            .watch(compartmentListStreamProvider(compartment.vehicleId))
            .value ??
        const <Compartment>[];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: farbe.akzent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(compartment.label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  verortungAnzeigename(
                      compartment.seite, compartment.laengsposition),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                if (compartment.laengsposition != null) ...[
                  const SizedBox(height: 10),
                  _VerortungsLeiste(
                      laengsposition: compartment.laengsposition!,
                      farbe: farbe),
                ],
              ],
            ),
          ),
          if (alle.isNotEmpty && VehicleTopView.hatVerortung(alle)) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 104,
              child: VehicleTopView(
                compartments: alle,
                kompakt: true,
                tileStates: {
                  compartment.id: const CutawayTileState(
                      status: CutawayTileStatus.selected),
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Die Längsachse als Leiste: Front · vorne · Mitte · hinten · Heck, der
/// Platz des Fachs hervorgehoben — dieselbe Achse, die auch die Draufsicht
/// von oben nach unten zeigt.
class _VerortungsLeiste extends StatelessWidget {
  final String laengsposition;
  final SeitenFarbe farbe;
  const _VerortungsLeiste(
      {required this.laengsposition, required this.farbe});

  @override
  Widget build(BuildContext context) {
    final zellen = ['Front', ...kLaengspositionen, 'Heck'];
    return Row(
      children: [
        for (final z in zellen) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: z == laengsposition
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                kLaengspositionLabels[z] ?? z,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      z == laengsposition ? FontWeight.w900 : FontWeight.w500,
                  color: z == laengsposition
                      ? farbe.akzent
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          if (z != zellen.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value),
          ],
        ),
      );
}

class _CompartmentTile extends ConsumerWidget {
  final Compartment compartment;
  const _CompartmentTile({required this.compartment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync =
        ref.watch(assignmentListStreamProvider(compartment.id));
    final farbe = seitenFarbe(compartment.seite);

    // Die Verortung steht vor der Stückzahl: Sie ist es, was man beim
    // Überfliegen der Liste sucht (Issue #141).
    String untertitel(int anzahl) => compartment.seite == null
        ? '$anzahl Gerät(e)'
        : '${verortungAnzeigename(compartment.seite, compartment.laengsposition)}'
            ' · $anzahl Gerät(e)';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: farbe == null
            ? null
            : Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: farbe.akzent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
        title: Text(compartment.label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: assignmentsAsync.when(
          loading: () => const Text('Lade...'),
          error: (_, _) => const Text('Fehler'),
          data: (a) => Text(untertitel(a.length)),
        ),
        children: [_ZuweisungsListe(compartment: compartment)],
      ),
    );
  }
}

class _AssignmentRow extends ConsumerWidget {
  final EquipmentAssignment assignment;
  final int vehicleId;

  /// Auswahl für Sammelaktionen (Issue #149). [onAuswahl] ist null, wenn
  /// niemand schreiben darf — dann bleibt die Zeile die reine Verknüpfung.
  final bool ausgewaehlt;
  final bool auswahlModus;
  final VoidCallback? onAuswahl;

  const _AssignmentRow({
    required this.assignment,
    required this.vehicleId,
    this.ausgewaehlt = false,
    this.auswahlModus = false,
    this.onAuswahl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync =
        ref.watch(equipmentDetailProvider(assignment.equipmentId));
    final canEdit = ref.watch(canEditProvider);
    return itemAsync.when(
      loading: () => const ListTile(title: Text('...')),
      error: (_, _) => const ListTile(title: Text('Fehler')),
      data: (item) => ListTile(
        dense: true,
        selected: ausgewaehlt,
        leading: auswahlModus
            ? Checkbox(
                value: ausgewaehlt,
                onChanged: onAuswahl == null ? null : (_) => onAuswahl!(),
              )
            : EquipmentAvatar(
                imagePath: item?.imagePath,
                functions: item?.equipmentFunctions ?? const [],
                size: 40,
              ),
        title: Text(item?.name ?? '?'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('× ${assignment.quantity}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            // Im Auswahlmodus verschwindet das Einzel-Menü: Was gerade für
            // mehrere gilt, soll nicht danebenstehen und für eines gelten.
            if (canEdit && !auswahlModus)
              PopupMenuButton<String>(
                onSelected: (action) => switch (action) {
                  'menge' => _changeQuantity(context, ref),
                  _ => _remove(context, ref, item?.name),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'menge', child: Text('Menge ändern')),
                  PopupMenuItem(
                      value: 'entfernen',
                      child: Text('Aus dem Fach entfernen')),
                ],
              ),
          ],
        ),
        // Langes Tippen beginnt die Auswahl — die im Android-Alltag gelernte
        // Geste. Ist sie einmal offen, wählt auch der kurze Tipp aus, statt
        // zum Gerät zu springen: Sonst verliert man die Auswahl an einem
        // Fehlgriff.
        onLongPress: onAuswahl,
        onTap: auswahlModus
            ? onAuswahl
            : (item != null
                ? () => context.push('/equipment/${item.id}')
                : null),
      ),
    );
  }

  Future<void> _changeQuantity(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: '${assignment.quantity}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Menge ändern'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Anzahl im Fach'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Speichern')),
        ],
      ),
    );
    final menge = int.tryParse(ctrl.text.trim());
    if (ok != true || menge == null || menge < 1) return;
    await ref
        .read(assignmentRepositoryProvider)
        .update(assignment.copyWith(quantity: menge));
    ref.invalidate(assignmentsByVehicleProvider(vehicleId));
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, String? name) async {
    // Bewusst ohne Rückfrage: Die Zuweisung ist mit zwei Tipps wieder da,
    // das Gerät selbst bleibt in der Bibliothek erhalten.
    await ref.read(assignmentRepositoryProvider).delete(assignment.id);
    ref.invalidate(assignmentsByVehicleProvider(vehicleId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('„${name ?? 'Gerät'}“ aus dem Fach entfernt.')));
    }
  }
}

/// Einstieg „Gerät zuweisen" am Ende der Fach-Liste (nur mit Schreibrecht).
class _AssignTile extends ConsumerWidget {
  final Compartment compartment;
  const _AssignTile({required this.compartment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.add_circle_outline),
      title: const Text('Gerät zuweisen'),
      onTap: () async {
        // Der Picker liefert einen String zurück, wenn „neu anlegen" gewählt
        // wurde (= vorbelegter Name, ggf. leer); bei Zuweisung oder Abbruch
        // kommt null — zugewiesen hat der Picker dann schon selbst.
        final neuName = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _EquipmentPickerSheet(compartment: compartment),
        );
        if (neuName == null || !context.mounted) return;

        // Anlegen im vollen Geräte-Formular (Foto, Funktionen, …) — die
        // neue ID kommt als Pop-Ergebnis zurück und landet direkt im Fach.
        // So bildet man ein Fahrzeug Raum für Raum ab, ohne den Umweg über
        // den Geräte-Tab (Issue #86, Marcus' Aufnahme-Workflow).
        final neuId = await context.push<int>(neuName.isEmpty
            ? '/equipment/new'
            : '/equipment/new?name=${Uri.encodeComponent(neuName)}');
        if (neuId == null || !context.mounted) return;

        await ref.read(assignmentRepositoryProvider).insert(EquipmentAssignment(
              id: 0, // vergibt die Datenbank
              compartmentId: compartment.id,
              equipmentId: neuId,
              quantity: 1,
              updatedAt: DateTime.now(),
            ));
        ref.invalidate(assignmentsByVehicleProvider(compartment.vehicleId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Gerät angelegt und in ${compartment.label} gelegt.')));
        }
      },
    );
  }
}

/// Durchsuchbare Geräteliste; bereits zugewiesene Geräte sind ausgegraut.
/// Neue Geräte entstehen weiterhin unter „Mehr → Geräte" — hier wird nur
/// zugeordnet, was es schon gibt (Bibliothek, Katalog oder eigene).
///
/// **Mehrfachauswahl (Issue #149):** Ein Tipp wählt aus, statt sofort
/// zuzuweisen und das Blatt zu schließen. Ein Fahrzeug hat rund 60 Geräte —
/// mit „auswählen und schließen" war das Einsortieren rund 250 Handgriffe, und
/// genau daran ist es im Feld gescheitert. ⚠️ Die Auswahl überlebt das Ändern
/// der Suche: Man sucht „Schlauch", hakt drei an, sucht „Strahlrohr", hakt
/// zwei an. Ginge sie beim Tippen verloren, wäre die Mehrfachauswahl keine.
class _EquipmentPickerSheet extends ConsumerStatefulWidget {
  final Compartment compartment;
  const _EquipmentPickerSheet({required this.compartment});

  @override
  ConsumerState<_EquipmentPickerSheet> createState() =>
      _EquipmentPickerSheetState();
}

class _EquipmentPickerSheetState extends ConsumerState<_EquipmentPickerSheet> {
  /// Wie getippt — so wandert der Text als Name ins Anlege-Formular.
  String _eingabe = '';

  /// Kleingeschrieben, nur zum Filtern.
  String get _suche => _eingabe.toLowerCase();

  /// Angehakte Geräte-IDs. Lebt am Zustand des Blattes, nicht an der
  /// Trefferliste — deshalb übersteht sie jede Sucheingabe.
  final Set<int> _auswahl = {};

  /// Namen der angehakten Geräte, nur für die Rückmeldung nach dem Zuweisen.
  final Map<int, String> _namen = {};

  void _umschalten(int id, String name) => setState(() {
        if (!_auswahl.add(id)) {
          _auswahl.remove(id);
        } else {
          _namen[id] = name;
        }
      });

  Future<void> _assignSelected() async {
    final geschrieben = await ref
        .read(assignmentRepositoryProvider)
        .assignMany(widget.compartment.id, _auswahl.toList());
    ref.invalidate(assignmentsByVehicleProvider(widget.compartment.vehicleId));
    if (!mounted) return;
    // Bei genau einem Gerät ist sein Name die hilfreichere Rückmeldung als
    // „1 Gerät" — man hat gerade nach ihm gesucht.
    final was = geschrieben == 1
        ? '„${_namen[_auswahl.first] ?? 'Gerät'}“'
        : '$geschrieben Geräte';
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '$was ${geschrieben == 1 ? 'liegt' : 'liegen'} jetzt in ${widget.compartment.label}.')));
  }

  @override
  Widget build(BuildContext context) {
    final alleAsync = ref.watch(equipmentListStreamProvider);
    final zugewiesen = (ref
                .watch(assignmentListStreamProvider(widget.compartment.id))
                .value ??
            const [])
        .map((a) => a.equipmentId)
        .toSet();

    return Padding(
      // Tastatur schiebt die Liste hoch, statt das Suchfeld zu verdecken.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    labelText:
                        'Gerät für ${widget.compartment.label} suchen',
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _eingabe = v.trim()),
                ),
              ),
              // Fester Einstieg statt Treffer-abhängig: Auch wenn die Suche
              // etwas findet, kann genau dieses Exemplar ein anderes sein.
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(_eingabe.isEmpty
                    ? 'Neues Gerät anlegen'
                    : '„$_eingabe“ neu anlegen'),
                subtitle:
                    const Text('Mit Foto und Details — landet in diesem Fach'),
                onTap: () => Navigator.of(context).pop(_eingabe),
              ),
              const Divider(height: 1),
              Expanded(
                child: alleAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Fehler: $e')),
                  data: (alle) {
                    final treffer = alle
                        .where((e) =>
                            _suche.isEmpty ||
                            e.name.toLowerCase().contains(_suche) ||
                            (e.shortName ?? '')
                                .toLowerCase()
                                .contains(_suche))
                        .toList();
                    if (treffer.isEmpty) {
                      return const Center(
                          child: Text('Kein Gerät gefunden.',
                              style: TextStyle(color: Colors.grey)));
                    }
                    return ListView.builder(
                      itemCount: treffer.length,
                      itemBuilder: (context, i) {
                        final e = treffer[i];
                        final schonDa = zugewiesen.contains(e.id);
                        final gewaehlt = _auswahl.contains(e.id);
                        return ListTile(
                          enabled: !schonDa,
                          selected: gewaehlt,
                          leading: EquipmentAvatar(
                            imagePath: e.imagePath,
                            functions: e.equipmentFunctions,
                            size: 40,
                          ),
                          title: Text(e.name),
                          subtitle: schonDa
                              ? const Text(
                                  'Bereits im Fach — Menge über das Menü')
                              : null,
                          trailing: schonDa
                              ? null
                              : Checkbox(
                                  value: gewaehlt,
                                  onChanged: (_) => _umschalten(e.id, e.name),
                                ),
                          onTap: schonDa
                              ? null
                              : () => _umschalten(e.id, e.name),
                        );
                      },
                    );
                  },
                ),
              ),
              // Die Leiste erscheint erst mit der ersten Auswahl — solange
              // nichts angehakt ist, wäre sie ein toter Knopf, der Platz von
              // der Trefferliste nimmt.
              if (_auswahl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _assignSelected,
                    icon: const Icon(Icons.playlist_add_check),
                    label: Text(_auswahl.length == 1
                        ? '1 Gerät zuweisen'
                        : '${_auswahl.length} Geräte zuweisen'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
