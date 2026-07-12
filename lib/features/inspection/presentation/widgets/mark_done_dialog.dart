/// mark_done_dialog.dart – Shared dialog to log a completed Prüfung /
/// replaced expiry item and advance its due date.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/inspection/domain/entities/inspection_schedule.dart';
import 'package:fwapp/features/inspection/presentation/providers/inspection_providers.dart';

/// Shows the dialog and, if confirmed, marks [schedule] done via the repository.
Future<void> markScheduleDone(
    BuildContext context, WidgetRef ref, InspectionSchedule schedule) async {
  final result = await showDialog<MarkDoneResult>(
    context: context,
    builder: (_) => MarkDoneDialog(schedule: schedule),
  );
  if (result == null || !context.mounted) return;
  try {
    await ref.read(inspectionRepositoryProvider).markDone(
          schedule,
          doneAt: DateTime.now(),
          doneBy: result.doneBy,
          note: result.note,
          nextDueAt: result.nextDueAt,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(schedule.kind == InspectionKind.expiry
              ? 'Als ersetzt vermerkt.'
              : 'Prüfung als erledigt vermerkt.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }
}

class MarkDoneResult {
  final String doneBy;
  final String note;
  final DateTime? nextDueAt;
  MarkDoneResult({required this.doneBy, required this.note, this.nextDueAt});
}

/// Expiry schedules additionally require the replacement's new expiry date.
class MarkDoneDialog extends StatefulWidget {
  final InspectionSchedule schedule;
  const MarkDoneDialog({super.key, required this.schedule});

  @override
  State<MarkDoneDialog> createState() => _MarkDoneDialogState();
}

class _MarkDoneDialogState extends State<MarkDoneDialog> {
  final _doneByController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _nextDueAt;

  bool get _isExpiry => widget.schedule.kind == InspectionKind.expiry;

  @override
  void dispose() {
    _doneByController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isExpiry ? 'Material ersetzt' : 'Prüfung erledigt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _doneByController,
            decoration:
                const InputDecoration(labelText: 'Erledigt von (optional)'),
          ),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Notiz (optional)'),
          ),
          if (_isExpiry) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_nextDueAt == null
                  ? 'Neues Ablaufdatum wählen'
                  : 'Neues Ablaufdatum: '
                      '${_nextDueAt!.day.toString().padLeft(2, '0')}.'
                      '${_nextDueAt!.month.toString().padLeft(2, '0')}.'
                      '${_nextDueAt!.year}'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
                );
                if (picked != null) setState(() => _nextDueAt = picked);
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: (_isExpiry && _nextDueAt == null)
              ? null
              : () => Navigator.of(context).pop(MarkDoneResult(
                    doneBy: _doneByController.text.trim(),
                    note: _noteController.text.trim(),
                    nextDueAt: _nextDueAt,
                  )),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
