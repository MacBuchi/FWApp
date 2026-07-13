/// inventory_report_screen.dart – Abschluss der Inventur: Zusammenfassung,
/// Mängelliste, Export in die Zwischenablage, Session abschließen.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inventory/presentation/providers/inventory_providers.dart';

class InventoryReportScreen extends ConsumerWidget {
  final int sessionId;
  const InventoryReportScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checksAsync = ref.watch(inventoryChecksProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventur – Abschluss'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Bericht kopieren',
            onPressed: () => _copy(context, ref),
          ),
        ],
      ),
      body: checksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (checks) {
          final summary = InventorySummary.from(checks);
          final open = checks
              .where((c) => c.status == InventoryChecks.statusOpen)
              .toList();
          final issues = checks
              .where((c) =>
                  c.status == InventoryChecks.statusMissing ||
                  c.status == InventoryChecks.statusDamaged)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zusammenfassung',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('${summary.checked} von ${summary.total} geprüft'),
                      Text('${summary.ok} vollständig',
                          style: TextStyle(color: Colors.green.shade700)),
                      if (summary.missing > 0)
                        Text('${summary.missing} fehlen',
                            style: TextStyle(color: Colors.red.shade700)),
                      if (summary.damaged > 0)
                        Text('${summary.damaged} beschädigt',
                            style: TextStyle(color: Colors.orange.shade800)),
                    ],
                  ),
                ),
              ),
              if (open.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${open.length} Geräte noch ungeprüft.',
                      style: TextStyle(color: Colors.orange.shade800)),
                ),
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Mängel', style: Theme.of(context).textTheme.titleMedium),
                ...issues.map((c) => Card(
                      child: ListTile(
                        leading: Icon(
                            c.status == InventoryChecks.statusMissing
                                ? Icons.cancel
                                : Icons.warning,
                            color: c.status == InventoryChecks.statusMissing
                                ? Colors.red
                                : Colors.orange),
                        title: Text(c.equipmentName),
                        subtitle: Text([
                          c.compartmentLabel,
                          c.status == InventoryChecks.statusMissing
                              ? 'fehlt'
                              : 'beschädigt',
                          if (c.note.isNotEmpty) c.note,
                        ].join(' · ')),
                      ),
                    )),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Inventur abschließen'),
                onPressed: () => _finish(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final checks =
        ref.read(inventoryChecksProvider(sessionId)).value ?? const [];
    await Clipboard.setData(ClipboardData(text: _buildReport(checks)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inventurbericht in die Zwischenablage kopiert.')));
    }
  }

  String _buildReport(List<InventoryCheckData> checks) {
    final summary = InventorySummary.from(checks);
    final buffer = StringBuffer('Inventurbericht\n');
    buffer.writeln('${summary.checked}/${summary.total} geprüft · '
        '${summary.ok} i.O. · ${summary.missing} fehlt · '
        '${summary.damaged} beschädigt\n');
    final issues = checks.where((c) =>
        c.status == InventoryChecks.statusMissing ||
        c.status == InventoryChecks.statusDamaged);
    if (issues.isNotEmpty) {
      buffer.writeln('Mängel:');
      for (final c in issues) {
        buffer.writeln('  - ${c.compartmentLabel} · ${c.equipmentName} · '
            '${c.status == InventoryChecks.statusMissing ? 'fehlt' : 'beschädigt'}'
            '${c.note.isNotEmpty ? ' (${c.note})' : ''}');
      }
    }
    return buffer.toString().trimRight();
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    await ref.read(inventoryServiceProvider).finish(sessionId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventur abgeschlossen.')));
      context.go('/');
    }
  }
}
