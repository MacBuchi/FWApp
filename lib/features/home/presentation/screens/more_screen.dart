/// more_screen.dart – "Mehr" tab: lookup, settings, and (admins only) the
/// Verwaltung section. Normal members never see editing entry points.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final syncMeta = ref.watch(syncMetaStreamProvider).value;
    final dirty = syncMeta?.localDirty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section('Nachschlagen'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Gerätekatalog'),
              subtitle: const Text('Alle Geräte durchsuchen und filtern'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/equipment'),
            ),
          ),
          _Section('App'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Einstellungen'),
              subtitle: const Text('Design, Synchronisation, Konto'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings'),
            ),
          ),
          if (isAdmin) ...[
            _Section('Verwaltung (Gerätewart)'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.fact_check),
                    title: const Text('Prüftermine'),
                    subtitle:
                        const Text('Fällige Prüfungen und Ablaufdaten'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/inspections'),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Beladeliste importieren'),
                    subtitle: const Text('Excel/CSV mit Zuordnungs-Assistent'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/import'),
                  ),
                  if (dirty) ...[
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.cloud_upload,
                          color: Colors.orange.shade800),
                      title: const Text('Unveröffentlichte Änderungen'),
                      subtitle: const Text(
                          'In den Einstellungen veröffentlichen'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
        child: Text(title,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.4)),
      );
}
