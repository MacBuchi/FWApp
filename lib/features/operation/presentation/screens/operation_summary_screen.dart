/// operation_summary_screen.dart – Entnommen-Übersicht: was ist ausgeladen und
/// muss beim Aufräumen zurück. Export in die Zwischenablage; Einsatz beenden.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/assignment/presentation/providers/assignment_providers.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/operation/presentation/providers/operation_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class OperationSummaryScreen extends ConsumerWidget {
  const OperationSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final op = ref.watch(operationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entnommen-Liste'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'In Zwischenablage kopieren',
            onPressed: () => _copyToClipboard(context, ref),
          ),
        ],
      ),
      body: !op.active
          ? const Center(child: Text('Kein aktiver Einsatz.'))
          : op.takenAssignmentIds.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Noch nichts entnommen. Tippe im Ausladen-Bildschirm '
                        'die entnommenen Geräte an.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final vehicleId in op.vehicleIds)
                      _VehicleTakenSection(vehicleId: vehicleId),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Einsatz beenden'),
            onPressed: () => _endOperation(context, ref),
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, WidgetRef ref) async {
    final text = await _buildReport(ref);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entnommen-Liste in die Zwischenablage kopiert.')));
    }
  }

  Future<String> _endOperation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Einsatz beenden?'),
        content: const Text(
            'Die Entnommen-Liste geht verloren. Vorher ggf. kopieren.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Beenden')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(operationProvider.notifier).end();
      context.go('/');
    }
    return '';
  }

  Future<String> _buildReport(WidgetRef ref) async {
    final op = ref.read(operationProvider);
    final vehicleRepo = ref.read(vehicleRepositoryProvider);
    final assignmentRepo = ref.read(assignmentRepositoryProvider);
    final equipmentRepo = ref.read(equipmentRepositoryProvider);

    final buffer = StringBuffer('Einsatz – Entnommene Geräte\n');
    if (op.scenario != null) buffer.writeln('Einsatzart: ${op.scenario!.label}');
    if (op.startedAt != null) {
      final d = op.startedAt!;
      buffer.writeln('Beginn: ${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}. '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}');
    }
    buffer.writeln();

    for (final vehicleId in op.vehicleIds) {
      final vehicle = await vehicleRepo.getById(vehicleId);
      final assignments = await assignmentRepo.getByVehicle(vehicleId);
      final taken =
          assignments.where((a) => op.isTaken(a.id)).toList();
      if (taken.isEmpty) continue;
      buffer.writeln('${vehicle?.name ?? 'Fahrzeug $vehicleId'}:');
      for (final a in taken) {
        final item = await equipmentRepo.getById(a.equipmentId);
        buffer.writeln('  - ${item?.name ?? 'Gerät ${a.equipmentId}'}'
            '${a.quantity > 1 ? ' (×${a.quantity})' : ''}');
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}

class _VehicleTakenSection extends ConsumerWidget {
  final int vehicleId;
  const _VehicleTakenSection({required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final op = ref.watch(operationProvider);
    final vehicle = ref.watch(vehicleDetailProvider(vehicleId)).value;
    final assignments =
        ref.watch(assignmentsByVehicleProvider(vehicleId)).value ?? const [];
    final taken = assignments.where((a) => op.isTaken(a.id)).toList();
    if (taken.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
          child: Text('${vehicle?.name ?? '…'} (${taken.length})',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(
          child: Column(
            children: [
              for (final a in taken)
                _TakenRow(
                  equipmentId: a.equipmentId,
                  quantity: a.quantity,
                  assignmentId: a.id,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TakenRow extends ConsumerWidget {
  final int equipmentId;
  final int quantity;
  final int assignmentId;
  const _TakenRow({
    required this.equipmentId,
    required this.quantity,
    required this.assignmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(equipmentDetailProvider(equipmentId)).value;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
      title: Text(item?.name ?? '…'),
      trailing: quantity > 1 ? Text('× $quantity') : null,
      onTap: () =>
          ref.read(operationProvider.notifier).toggleTaken(assignmentId),
    );
  }
}
