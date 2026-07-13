/// equipment_instances_section.dart – "Instanzen & Prüfungen" section embedded
/// in EquipmentDetailScreen: manage physical instances of an equipment type
/// and their inspection schedules.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/inspection/domain/entities/equipment_instance.dart';
import 'package:fwapp/features/inspection/domain/entities/inspection_schedule.dart';
import 'package:fwapp/features/inspection/presentation/providers/inspection_providers.dart';
import 'package:fwapp/features/inspection/presentation/widgets/mark_done_dialog.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.'
    '${dt.month.toString().padLeft(2, '0')}.'
    '${dt.year}';

class EquipmentInstancesSection extends ConsumerWidget {
  final int equipmentId;
  const EquipmentInstancesSection({super.key, required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instancesAsync =
        ref.watch(instancesByEquipmentStreamProvider(equipmentId));
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);
    final vehicles = vehiclesAsync.value ?? const <Vehicle>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Instanzen & Prüfungen',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (ref.watch(isAdminProvider))
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Instanz hinzufügen',
                onPressed: () => _addInstance(context, ref, vehicles),
              ),
          ],
        ),
        instancesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Fehler: $e'),
          data: (instances) {
            if (instances.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Keine Instanzen angelegt. Lege eine Instanz an, um '
                  'Prüftermine oder Ablaufdaten zu verfolgen.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return Column(
              children: instances
                  .map((i) => _InstanceCard(
                        instance: i,
                        vehicles: vehicles,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addInstance(
      BuildContext context, WidgetRef ref, List<Vehicle> vehicles) async {
    final result = await showDialog<EquipmentInstance>(
      context: context,
      builder: (_) =>
          _InstanceDialog(equipmentId: equipmentId, vehicles: vehicles),
    );
    if (result == null) return;
    await ref.read(inspectionRepositoryProvider).insertInstance(result);
  }
}

class _InstanceCard extends ConsumerWidget {
  final EquipmentInstance instance;
  final List<Vehicle> vehicles;
  const _InstanceCard({required this.instance, required this.vehicles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync =
        ref.watch(schedulesByInstanceStreamProvider(instance.id));
    final vehicleName = vehicles
        .where((v) => v.id == instance.vehicleId)
        .map((v) => v.name)
        .firstOrNull;
    final title = instance.identifier?.isNotEmpty ?? false
        ? instance.identifier!
        : 'Instanz ${instance.id}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Icon(Icons.qr_code_2,
            color: instance.isActive ? null : Colors.grey),
        title: Text(title,
            style: instance.isActive
                ? null
                : const TextStyle(
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough)),
        subtitle: Text([
          if (vehicleName != null) vehicleName,
          if (!instance.isActive) 'inaktiv',
          if (instance.notes.isNotEmpty) instance.notes,
        ].join(' · ')),
        children: [
          schedulesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (e, _) => Text('Fehler: $e'),
            data: (schedules) => Column(
              children: [
                if (schedules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Keine Prüfungen hinterlegt.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ...schedules.map((s) => _ScheduleTile(schedule: s)),
              ],
            ),
          ),
          if (ref.watch(isAdminProvider))
            OverflowBar(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Prüfung hinzufügen'),
                  onPressed: () => _addSchedule(context, ref),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Instanz löschen'),
                  onPressed: () => _deleteInstance(context, ref),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _addSchedule(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<InspectionSchedule>(
      context: context,
      builder: (_) => _ScheduleDialog(instanceId: instance.id),
    );
    if (result == null) return;
    await ref.read(inspectionRepositoryProvider).insertSchedule(result);
  }

  Future<void> _deleteInstance(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instanz löschen?'),
        content: const Text(
            'Alle Prüfungen und die Prüfhistorie dieser Instanz werden '
            'ebenfalls gelöscht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(inspectionRepositoryProvider).deleteInstance(instance.id);
  }
}

class _ScheduleTile extends ConsumerWidget {
  final InspectionSchedule schedule;
  const _ScheduleTile({required this.schedule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final dueSoonCutoff = now.add(const Duration(days: 30));
    final Color? dueColor = schedule.isOverdue(now)
        ? Colors.red.shade700
        : schedule.dueAt.isBefore(dueSoonCutoff)
            ? Colors.orange.shade800
            : null;
    return ListTile(
      dense: true,
      leading: Icon(
        schedule.kind == InspectionKind.expiry
            ? Icons.hourglass_bottom
            : Icons.fact_check,
        size: 20,
      ),
      title: Text(schedule.title),
      subtitle: Text([
        schedule.kind.label,
        if (schedule.intervalMonths != null)
          'alle ${schedule.intervalMonths} Monate',
        if (schedule.lastDoneAt != null)
          'zuletzt ${_formatDate(schedule.lastDoneAt!)}',
      ].join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_formatDate(schedule.dueAt),
              style: TextStyle(color: dueColor, fontWeight: FontWeight.bold)),
          if (ref.watch(isAdminProvider))
            PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'done':
                  await markScheduleDone(context, ref, schedule);
                case 'delete':
                  await ref
                      .read(inspectionRepositoryProvider)
                      .deleteSchedule(schedule.id);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'done',
                child: Text(schedule.kind == InspectionKind.expiry
                    ? 'Ersetzt'
                    : 'Erledigt'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstanceDialog extends StatefulWidget {
  final int equipmentId;
  final List<Vehicle> vehicles;
  const _InstanceDialog({required this.equipmentId, required this.vehicles});

  @override
  State<_InstanceDialog> createState() => _InstanceDialogState();
}

class _InstanceDialogState extends State<_InstanceDialog> {
  final _identifierController = TextEditingController();
  final _notesController = TextEditingController();
  int? _vehicleId;

  @override
  void dispose() {
    _identifierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Instanz anlegen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _identifierController,
            decoration: const InputDecoration(
                labelText: 'Kennung (z.B. Seriennr., "Flasche 3")'),
          ),
          DropdownButtonFormField<int?>(
            initialValue: _vehicleId,
            decoration: const InputDecoration(labelText: 'Fahrzeug'),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Kein Fahrzeug / Lager')),
              ...widget.vehicles.map((v) =>
                  DropdownMenuItem<int?>(value: v.id, child: Text(v.name))),
            ],
            onChanged: (v) => setState(() => _vehicleId = v),
          ),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notizen (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(EquipmentInstance(
            id: 0,
            equipmentId: widget.equipmentId,
            vehicleId: _vehicleId,
            identifier: _identifierController.text.trim().isEmpty
                ? null
                : _identifierController.text.trim(),
            notes: _notesController.text.trim(),
            updatedAt: DateTime.now(),
          )),
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}

class _ScheduleDialog extends StatefulWidget {
  final int instanceId;
  const _ScheduleDialog({required this.instanceId});

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final _titleController = TextEditingController();
  InspectionKind _kind = InspectionKind.recurring;
  int _intervalMonths = 12;
  DateTime? _dueAt;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime get _effectiveDueAt {
    if (_dueAt != null) return _dueAt!;
    final now = DateTime.now();
    return _kind == InspectionKind.recurring
        ? DateTime(now.year, now.month + _intervalMonths, now.day)
        : now;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prüfung anlegen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Titel (z.B. "Jährliche Sichtprüfung")'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<InspectionKind>(
              segments: const [
                ButtonSegment(
                    value: InspectionKind.recurring,
                    label: Text('Wiederkehrend')),
                ButtonSegment(
                    value: InspectionKind.expiry, label: Text('Ablaufdatum')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            if (_kind == InspectionKind.recurring) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _intervalMonths,
                decoration:
                    const InputDecoration(labelText: 'Intervall'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Monatlich')),
                  DropdownMenuItem(value: 3, child: Text('Vierteljährlich')),
                  DropdownMenuItem(value: 6, child: Text('Halbjährlich')),
                  DropdownMenuItem(value: 12, child: Text('Jährlich')),
                  DropdownMenuItem(value: 24, child: Text('Alle 2 Jahre')),
                  DropdownMenuItem(value: 36, child: Text('Alle 3 Jahre')),
                  DropdownMenuItem(value: 60, child: Text('Alle 5 Jahre')),
                  DropdownMenuItem(value: 120, child: Text('Alle 10 Jahre')),
                ],
                onChanged: (v) =>
                    setState(() => _intervalMonths = v ?? 12),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_kind == InspectionKind.expiry
                  ? (_dueAt == null
                      ? 'Ablaufdatum wählen'
                      : 'Ablaufdatum: ${_formatDate(_dueAt!)}')
                  : 'Erste Fälligkeit: ${_formatDate(_effectiveDueAt)}'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _effectiveDueAt,
                  firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
                );
                if (picked != null) setState(() => _dueAt = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) return;
            if (_kind == InspectionKind.expiry && _dueAt == null) return;
            Navigator.of(context).pop(InspectionSchedule(
              id: 0,
              instanceId: widget.instanceId,
              kind: _kind,
              title: _titleController.text.trim(),
              intervalMonths:
                  _kind == InspectionKind.recurring ? _intervalMonths : null,
              dueAt: _effectiveDueAt,
              updatedAt: DateTime.now(),
            ));
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
