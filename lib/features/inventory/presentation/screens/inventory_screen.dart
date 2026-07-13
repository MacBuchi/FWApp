/// inventory_screen.dart – Inventurassistent: Fahrzeug fach für fach prüfen
/// (Soll/Ist), Mängel dokumentieren, Report mit Export. Admin-Tätigkeit.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/presentation/providers/compartment_providers.dart';
import 'package:fwapp/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

/// Vehicle picker → starts/resumes a session, then shows the run screen.
class InventorySetupScreen extends ConsumerWidget {
  const InventorySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventur')),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (vehicles) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Fahrzeug für die Inventur wählen:'),
            ),
            ...vehicles.map((v) => Card(
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
                )),
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
          checksAsync.maybeWhen(
            data: (checks) {
              final summary = InventorySummary.from(checks);
              return TextButton(
                onPressed: summary.checked == 0
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
            child: ref.watch(compartmentListStreamProvider(session)).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Fehler: $e')),
                  data: (compartments) {
                    final tileStates = <int, CutawayTileState>{};
                    for (final comp in compartments) {
                      final items = byCompartment[comp.id] ?? const [];
                      final done = items
                          .where((c) =>
                              c.status != InventoryChecks.statusOpen)
                          .length;
                      final hasIssue = items.any((c) =>
                          c.status == InventoryChecks.statusMissing ||
                          c.status == InventoryChecks.statusDamaged);
                      tileStates[comp.id] = CutawayTileState(
                        status: items.isEmpty
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
                          onTapCompartment: (comp) => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (_) => _CompartmentCheckSheet(
                              compartment: comp,
                              checks: byCompartment[comp.id] ?? const [],
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
final _sessionVehicleProvider =
    FutureProvider.family<int?, int>((ref, sessionId) async {
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
                    value: summary.total > 0
                        ? summary.checked / summary.total
                        : 0,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${summary.checked}/${summary.total}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            _Pill(color: Colors.green, label: '${summary.ok} i.O.'),
            if (summary.missing > 0)
              _Pill(color: Colors.red, label: '${summary.missing} fehlt'),
            if (summary.damaged > 0)
              _Pill(
                  color: Colors.orange, label: '${summary.damaged} beschädigt'),
          ]),
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

class _CompartmentCheckSheet extends ConsumerWidget {
  final Compartment compartment;
  final List<InventoryCheckData> checks;
  const _CompartmentCheckSheet(
      {required this.compartment, required this.checks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(compartment.label,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: checks.length,
                itemBuilder: (context, i) =>
                    _CheckTile(check: checks[i]),
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
    final (Color color, IconData icon) = switch (check.status) {
      InventoryChecks.statusOk => (Colors.green, Icons.check_circle),
      InventoryChecks.statusMissing => (Colors.red, Icons.cancel),
      InventoryChecks.statusDamaged =>
        (Colors.orange, Icons.warning),
      _ => (Colors.grey, Icons.radio_button_unchecked),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(check.equipmentName),
        subtitle: Text([
          if (check.targetQuantity > 1) 'Soll: ${check.targetQuantity}',
          if (check.note.isNotEmpty) check.note,
        ].join(' · ')),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              color: check.status == InventoryChecks.statusOk
                  ? Colors.green
                  : null,
              tooltip: 'Vollständig',
              onPressed: () =>
                  service.setStatus(check.id, InventoryChecks.statusOk),
            ),
            IconButton(
              icon: const Icon(Icons.report_gmailerrorred),
              color: check.status == InventoryChecks.statusMissing ||
                      check.status == InventoryChecks.statusDamaged
                  ? Colors.red
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
      BuildContext context, InventoryService service) async {
    final noteController = TextEditingController(text: check.note);
    var status = InventoryChecks.statusMissing;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Mangel: ${check.equipmentName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: InventoryChecks.statusMissing,
                      label: Text('Fehlt')),
                  ButtonSegment(
                      value: InventoryChecks.statusDamaged,
                      label: Text('Beschädigt')),
                ],
                selected: {status},
                onSelectionChanged: (s) => setState(() => status = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Notiz'),
              ),
            ],
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
      ),
    );
    if (result == true) {
      await service.setStatus(check.id, status,
          note: noteController.text.trim());
    }
  }
}
