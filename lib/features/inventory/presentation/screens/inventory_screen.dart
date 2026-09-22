/// inventory_screen.dart – Inventurassistent: Fahrzeug fach für fach prüfen
/// (Soll/Ist), Mängel dokumentieren, Report mit Export. Admin-Tätigkeit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/presentation/providers/compartment_providers.dart';
import 'package:fwapp/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:fwapp/features/inventory/data/nfc_dienst.dart';
import 'package:fwapp/features/inventory/presentation/screens/code_scannen_screen.dart';
import 'package:fwapp/features/inventory/presentation/screens/nfc_lesen_screen.dart';
import 'package:fwapp/features/inventory/presentation/widgets/status_darstellung.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

/// Vehicle picker → starts/resumes a session, then shows the run screen.
class InventorySetupScreen extends ConsumerWidget {
  const InventorySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventur'),
        actions: const [AbteilungAction()],
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data:
            (vehicles) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Fahrzeug für die Inventur wählen:'),
                ),
                ...vehicles.map(
                  (v) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.fire_truck),
                      title: Text(v.name),
                      subtitle: Text(v.type),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final sessionId = await ref
                            .read(inventoryServiceProvider)
                            .startOrResume(v.id);
                        if (context.mounted) {
                          context.push('/inventory/run/$sessionId');
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class InventoryRunScreen extends ConsumerWidget {
  final int sessionId;
  const InventoryRunScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checksAsync = ref.watch(inventoryChecksProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Codes scannen',
            onPressed: () => _codeScannen(context, ref, sessionId),
          ),
          // Nur wo es NFC überhaupt gibt (#176). Ein Knopf, der im
          // Browser eine Erklärung statt einer Funktion öffnet, ist ein
          // Versprechen, das die Leiste nicht halten kann.
          if (NfcDienst.unterstuetzt)
            IconButton(
              icon: const Icon(Icons.nfc),
              tooltip: 'Tags lesen',
              onPressed: () => _tagsLesen(context, ref, sessionId),
            ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Code eingeben',
            onPressed: () => _codeEingeben(context, ref, sessionId),
          ),
          checksAsync.maybeWhen(
            data: (checks) {
              final summary = InventorySummary.from(checks);
              return TextButton(
                onPressed:
                    summary.checked == 0
                        ? null
                        : () => context.push('/inventory/report/$sessionId'),
                child: const Text('Abschluss'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: checksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (checks) => _InventoryBody(sessionId: sessionId, checks: checks),
      ),
    );
  }
}

/// Scannt Codes und hakt ab, ohne zwischendurch zu schließen.
///
/// Der Bildschirm bleibt offen und meldet jeden Fund über dem Bild: Ein Fach
/// hat fünfzehn Geräte, und für jedes die Kamera neu zu öffnen wäre der
/// langsamere Weg als das Antippen, das damit ersetzt werden soll.
Future<void> _codeScannen(
  BuildContext context,
  WidgetRef ref,
  int sessionId,
) async {
  final dienst = ref.read(inventoryServiceProvider);
  await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder:
          (_) => CodeScannenScreen(
            titel: 'Geräte abhaken',
            beiFund:
                (roh) async =>
                    abhakMeldung(await dienst.hakeCodeAb(sessionId, roh)),
          ),
    ),
  );
}

/// Liest NFC-Tags und hakt ab, ohne zwischendurch zu schließen (#176).
///
/// Derselbe Zuschnitt wie beim Scannen — nur dass das Handy das Tag berührt,
/// statt es anzupeilen. Das war der Punkt des Wunsches: im Geräteraum am
/// Gerät entlang, ohne Licht und ohne Zielen.
///
/// [hakeKandidatenAb] statt `hakeCodeAb`, weil ein Tag zwei Schlüssel tragen
/// kann — die Begründung steht dort.
Future<void> _tagsLesen(
  BuildContext context,
  WidgetRef ref,
  int sessionId,
) async {
  final dienst = ref.read(inventoryServiceProvider);
  await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder:
          (_) => NfcLesenScreen(
            titel: 'Geräte abhaken',
            anleitung:
                'Das Handy nacheinander an die Tags halten. Jeder Fund '
                'steht hier unten.',
            beiFund:
                (fund) async => abhakMeldung(
                  await dienst.hakeKandidatenAb(sessionId, fund.kandidaten),
                ),
          ),
    ),
  );
}

/// Fragt einen Code ab und hakt das Gerät ab, auf dem er klebt.
///
/// Das Feld bleibt nach jeder Eingabe offen und leert sich: Beim Abarbeiten
/// eines Fachs kommen die Codes hintereinander, und ein Dialog, den man
/// zwanzigmal neu öffnet, ist ein Dialog, den niemand benutzt. Bis zur
/// Kamera (#179, zweiter Schritt) ist dieses Feld der Leser — ein
/// Handscanner am Gerät tippt hier ohnehin hinein.
Future<void> _codeEingeben(
  BuildContext context,
  WidgetRef ref,
  int sessionId,
) async {
  final controller = TextEditingController();
  final dienst = ref.read(inventoryServiceProvider);

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      String? letzteMeldung;
      return StatefulBuilder(
        builder:
            (ctx, setState) => AlertDialog(
              title: const Text('Code eingeben'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        helperText: 'Nach jedem Code bleibt das Feld offen.',
                      ),
                      onSubmitted: (wert) async {
                        final ergebnis = await dienst.hakeCodeAb(
                          sessionId,
                          wert,
                        );
                        controller.clear();
                        setState(() => letzteMeldung = abhakMeldung(ergebnis));
                      },
                    ),
                    if (letzteMeldung != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        letzteMeldung!,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fertig'),
                ),
              ],
            ),
      );
    },
  );
}

class _InventoryBody extends ConsumerWidget {
  final int sessionId;
  final List<InventoryCheckData> checks;
  const _InventoryBody({required this.sessionId, required this.checks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(_sessionVehicleProvider(sessionId)).value;
    final summary = InventorySummary.from(checks);

    // Checks nach Fach (compartmentId) gruppieren.
    final byCompartment = <int?, List<InventoryCheckData>>{};
    for (final c in checks) {
      byCompartment.putIfAbsent(c.compartmentId, () => []).add(c);
    }

    return Column(
      children: [
        _ProgressHeader(summary: summary),
        if (session != null)
          Expanded(
            child: ref
                .watch(compartmentListStreamProvider(session))
                .when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Fehler: $e')),
                  data: (compartments) {
                    final tileStates = <int, CutawayTileState>{};
                    for (final comp in compartments) {
                      final items = byCompartment[comp.id] ?? const [];
                      final done =
                          items
                              .where(
                                (c) => c.status != InventoryChecks.statusOpen,
                              )
                              .length;
                      final hasIssue = items.any(
                        (c) => InventorySummary.abweichendeStatus.contains(
                          c.status,
                        ),
                      );
                      tileStates[comp.id] = CutawayTileState(
                        status:
                            items.isEmpty
                                ? CutawayTileStatus.normal
                                : hasIssue
                                ? CutawayTileStatus.wrong
                                : done == items.length
                                ? CutawayTileStatus.correct
                                : done > 0
                                ? CutawayTileStatus.selected
                                : CutawayTileStatus.normal,
                        statusText:
                            items.isEmpty ? null : '$done/${items.length}',
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        VehicleCutawayView(
                          compartments: compartments,
                          tileStates: tileStates,
                          onTapCompartment:
                              (comp) => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder:
                                    (_) => _CompartmentCheckSheet(
                                      compartment: comp,
                                      sessionId: sessionId,
                                    ),
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tippe ein Fach an und hake die Geräte ab.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
          ),
      ],
    );
  }
}

/// Resolves a session's vehicleId.
final _sessionVehicleProvider = FutureProvider.family<int?, int>((
  ref,
  sessionId,
) async {
  final session = await ref.watch(inventoryDaoProvider).getSession(sessionId);
  return session?.vehicleId;
});

class _ProgressHeader extends StatelessWidget {
  final InventorySummary summary;
  const _ProgressHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        summary.total > 0 ? summary.checked / summary.total : 0,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${summary.checked}/${summary.total}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _Pill(color: Colors.green, label: '${summary.ok} i.O.'),
              if (summary.missing > 0)
                _Pill(color: Colors.red, label: '${summary.missing} fehlt'),
              if (summary.damaged > 0)
                _Pill(
                  color: Colors.orange,
                  label: '${summary.damaged} beschädigt',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Color color;
  final String label;
  const _Pill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: CircleAvatar(backgroundColor: color, radius: 6),
    label: Text(label, style: const TextStyle(fontSize: 12)),
  );
}

/// Die Geräte eines Fachs zum Abhaken.
///
/// ⚠️ **Beobachtet den Provider selbst**, statt die Liste beim Öffnen
/// übergeben zu bekommen. Das Blatt ist eine eigene Route: Eine mitgegebene
/// Liste ist ab dem ersten Häkchen veraltet, und dann hakt der Gerätewart ein
/// Fach durch, ohne dass sich vor seinen Augen etwas ändert — Fortschritt und
/// Fachkachel dahinter zählen mit, die Zeile darunter bleibt grau.
class _CompartmentCheckSheet extends ConsumerWidget {
  final Compartment compartment;
  final int sessionId;
  const _CompartmentCheckSheet({
    required this.compartment,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks =
        ref
            .watch(inventoryChecksProvider(sessionId))
            .value
            ?.where((c) => c.compartmentId == compartment.id)
            .toList() ??
        const <InventoryCheckData>[];
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder:
            (context, controller) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      compartment.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: checks.length,
                    itemBuilder: (context, i) => _CheckTile(check: checks[i]),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _CheckTile extends ConsumerWidget {
  final InventoryCheckData check;
  const _CheckTile({required this.check});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(inventoryServiceProvider);
    final (color, icon) = statusDarstellung(check.status);

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(check.equipmentName),
        subtitle: Text(
          [
            if (check.targetQuantity > 1) 'Soll: ${check.targetQuantity}',
            if (check.note.isNotEmpty) check.note,
          ].join(' · '),
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              color:
                  check.status == InventoryChecks.statusOk
                      ? Colors.green
                      : null,
              tooltip: 'Vollständig',
              onPressed:
                  () => service.setStatus(check.id, InventoryChecks.statusOk),
            ),
            IconButton(
              icon: const Icon(Icons.report_gmailerrorred),
              color:
                  InventorySummary.abweichendeStatus.contains(check.status)
                      ? color
                      : null,
              tooltip: 'Mangel',
              onPressed: () => _reportIssue(context, service),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportIssue(
    BuildContext context,
    InventoryService service,
  ) async {
    final noteController = TextEditingController(text: check.note);
    // Beim zweiten Öffnen steht der bereits vermerkte Zustand da — sonst
    // setzt ein Blick in die Notiz das Gerät stillschweigend auf „fehlt".
    var status =
        InventorySummary.abweichendeStatus.contains(check.status)
            ? check.status
            : InventoryChecks.statusMissing;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setState) => AlertDialog(
                  title: Text('Mangel: ${check.equipmentName}'),
                  // Drei Zustände und ein Textfeld: ohne Scrollbereich überlappen
                  // auf kleinen Bildschirmen Knöpfe und Feld (AGENTS.md).
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: InventoryChecks.statusMissing,
                              label: Text('Fehlt'),
                            ),
                            ButtonSegment(
                              value: InventoryChecks.statusDamaged,
                              label: Text('Beschädigt'),
                            ),
                            ButtonSegment(
                              value: InventoryChecks.statusRepair,
                              label: Text('In Reparatur'),
                            ),
                          ],
                          selected: {status},
                          onSelectionChanged:
                              (s) => setState(() => status = s.first),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(labelText: 'Notiz'),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Abbrechen'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Speichern'),
                    ),
                  ],
                ),
          ),
    );
    if (result == true) {
      await service.setStatus(
        check.id,
        status,
        note: noteController.text.trim(),
      );
    }
  }
}
