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
    final assignmentsAsync =
        ref.watch(assignmentListStreamProvider(compartment.id));
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetVerortungsKopf(compartment: compartment),
          const SizedBox(height: 8),
          Flexible(
            child: assignmentsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator()),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Fehler: $e')),
              data: (assignments) => ListView(
                shrinkWrap: true,
                children: [
                  if (assignments.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Kein Gerät zugewiesen.',
                            style: TextStyle(color: Colors.grey))),
                  for (final a in assignments)
                    _AssignmentRow(
                        assignment: a, vehicleId: compartment.vehicleId),
                  if (ref.watch(canEditProvider))
                    _AssignTile(compartment: compartment),
                ],
              ),
            ),
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
        children: [
          assignmentsAsync.when(
            loading: () =>
                const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Fehler: $e'),
            ),
            data: (assignments) => Column(
              children: [
                if (assignments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Kein Gerät zugewiesen.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                for (final a in assignments)
                  _AssignmentRow(
                      assignment: a, vehicleId: compartment.vehicleId),
                // Der bisher einzige Weg, ein Gerät in ein Fach zu bekommen,
                // waren Import und Vorlage — von Hand ging es schlicht nicht
                // (Issue #86). Deshalb hier, wo man das Fach vor sich hat.
                if (ref.watch(canEditProvider))
                  _AssignTile(compartment: compartment),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends ConsumerWidget {
  final EquipmentAssignment assignment;
  final int vehicleId;
  const _AssignmentRow({required this.assignment, required this.vehicleId});

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
        leading: EquipmentAvatar(
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
            if (canEdit)
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
        onTap: item != null
            ? () => context.push('/equipment/${item.id}')
            : null,
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

  Future<void> _assign(int equipmentId, String name) async {
    await ref.read(assignmentRepositoryProvider).insert(EquipmentAssignment(
          id: 0, // vergibt die Datenbank
          compartmentId: widget.compartment.id,
          equipmentId: equipmentId,
          quantity: 1,
          updatedAt: DateTime.now(),
        ));
    ref.invalidate(assignmentsByVehicleProvider(widget.compartment.vehicleId));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('„$name“ liegt jetzt in ${widget.compartment.label}.')));
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
                        return ListTile(
                          enabled: !schonDa,
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
                          onTap: () => _assign(e.id, e.name),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
