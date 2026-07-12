/// inspection_dashboard_screen.dart – Gerätewart dashboard: overdue and
/// soon-due Prüfungen/Ablaufdaten across the whole fleet.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/inspection/domain/entities/due_inspection_entry.dart';
import 'package:fwapp/features/inspection/domain/entities/inspection_schedule.dart';
import 'package:fwapp/features/inspection/presentation/providers/inspection_providers.dart';
import 'package:fwapp/features/inspection/presentation/widgets/mark_done_dialog.dart';

class InspectionDashboardScreen extends ConsumerWidget {
  const InspectionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueAsync = ref.watch(dueInspectionsStreamProvider());

    return Scaffold(
      appBar: AppBar(title: const Text('Prüftermine')),
      body: dueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text('Keine fälligen Prüfungen in den nächsten 30 Tagen.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          final now = DateTime.now();
          final overdue = entries.where((e) => e.isOverdue(now)).toList();
          final dueSoon = entries.where((e) => !e.isOverdue(now)).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (overdue.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Überfällig (${overdue.length})',
                    color: Colors.red.shade700),
                ...overdue.map((e) =>
                    _DueTile(entry: e, isOverdue: true)),
                const SizedBox(height: 16),
              ],
              if (dueSoon.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Bald fällig (${dueSoon.length})',
                    color: Colors.orange.shade800),
                ...dueSoon.map((e) =>
                    _DueTile(entry: e, isOverdue: false)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      );
}

class _DueTile extends ConsumerWidget {
  final DueInspectionEntry entry;
  final bool isOverdue;
  const _DueTile({required this.entry, required this.isOverdue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = entry.schedule;
    final subtitleParts = <String>[
      schedule.title,
      if (entry.instance.identifier?.isNotEmpty ?? false)
        entry.instance.identifier!,
      if (entry.vehicleName != null) entry.vehicleName!,
    ];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isOverdue ? Colors.red.shade700 : Colors.orange.shade800,
          child: Icon(
            schedule.kind == InspectionKind.expiry
                ? Icons.hourglass_bottom
                : Icons.fact_check,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(entry.equipmentName),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_formatDate(schedule.dueAt),
                style: TextStyle(
                    color: isOverdue
                        ? Colors.red.shade700
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.bold)),
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => markScheduleDone(context, ref, schedule),
              child: Text(schedule.kind == InspectionKind.expiry
                  ? 'Ersetzt'
                  : 'Erledigt'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.'
      '${dt.month.toString().padLeft(2, '0')}.'
      '${dt.year}';
}
