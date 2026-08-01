/// sync_config_section.dart – Serveradresse, Schlüssel und Sync-Schalter.
///
/// Aus dem Einstellungs-Screen herausgelöst, weil dieselben Kacheln seit dem
/// Anmeldezwang an einer zweiten Stelle gebraucht werden: im Notausgang
/// `/server-settings`, den man ohne Anmeldung erreicht. Genau dort korrigiert
/// jemand die Adresse, dessen Server nicht mehr antwortet — ohne diesen Weg
/// säße er in einer App fest, in die er sich nicht anmelden kann.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';

/// Schalter, Serveradresse und Schlüssel. Verhalten unverändert übernommen —
/// Änderungen greifen erst nach einem Neustart, weil main() die Werte vor
/// `runApp` liest.
class SyncConfigSection extends ConsumerWidget {
  const SyncConfigSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncSettingsProvider);
    return syncAsync.when(
      loading: () => const ListTile(title: Text('Lade...')),
      error: (e, _) => ListTile(title: Text('Fehler: $e')),
      data: (settings) => Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync),
            title: const Text('Supabase-Sync aktivieren'),
            subtitle:
                const Text('Daten werden mit der Cloud synchronisiert'),
            value: settings.enabled,
            onChanged: (v) =>
                ref.read(syncSettingsProvider.notifier).save(SyncSettings(
                      enabled: v,
                      supabaseUrl: settings.supabaseUrl,
                      supabaseKey: settings.supabaseKey,
                    )),
          ),
          if (settings.enabled) ...[
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Supabase URL'),
              subtitle: Text(settings.supabaseUrl.isEmpty
                  ? 'Nicht konfiguriert'
                  : settings.supabaseUrl),
              onTap: () => _editText(
                context,
                title: 'Supabase URL',
                initial: settings.supabaseUrl,
                onSave: (v) => ref
                    .read(syncSettingsProvider.notifier)
                    .save(settings.copyWith(supabaseUrl: v)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Supabase Anon Key'),
              subtitle: Text(
                  settings.supabaseKey.isEmpty ? 'Nicht konfiguriert' : '••••••••'),
              onTap: () => _editText(
                context,
                title: 'Supabase Anon Key',
                initial: settings.supabaseKey,
                obscure: true,
                onSave: (v) => ref
                    .read(syncSettingsProvider.notifier)
                    .save(settings.copyWith(supabaseKey: v)),
              ),
            ),
            if (!ref.watch(supabaseReadyProvider))
              const ListTile(
                leading: Icon(Icons.restart_alt, color: Colors.orange),
                title: Text('Neustart erforderlich'),
                subtitle: Text(
                    'Die Verbindung wird beim nächsten App-Start aufgebaut.'),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
    bool obscure = false,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(labelText: title),
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
    if (ok == true) onSave(ctrl.text.trim());
  }
}

extension on SyncSettings {
  SyncSettings copyWith({
    bool? enabled,
    String? supabaseUrl,
    String? supabaseKey,
  }) =>
      SyncSettings(
        enabled: enabled ?? this.enabled,
        supabaseUrl: supabaseUrl ?? this.supabaseUrl,
        supabaseKey: supabaseKey ?? this.supabaseKey,
      );
}

/// Live-Verbindungsstatus zum Sync-Server — sichtbar schon VOR dem Login,
/// damit Netzwerkprobleme nicht wie falsche Zugangsdaten aussehen.
class ServerHealthTile extends ConsumerWidget {
  const ServerHealthTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(serverHealthProvider);
    return health.when(
      loading: () => const ListTile(
        leading: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Server wird geprüft...'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Server nicht erreichbar'),
        subtitle: Text('$e'),
        onTap: () => ref.invalidate(serverHealthProvider),
      ),
      data: (reachable) => ListTile(
        leading: Icon(reachable ? Icons.check_circle : Icons.cancel,
            color: reachable ? Colors.green : Colors.red),
        title: Text(reachable ? 'Server erreichbar' : 'Server nicht erreichbar'),
        subtitle: Text(reachable
            ? 'Verbindung steht – zum erneuten Prüfen tippen'
            : 'Internetverbindung prüfen – zum erneuten Prüfen tippen'),
        onTap: () => ref.invalidate(serverHealthProvider),
      ),
    );
  }
}
