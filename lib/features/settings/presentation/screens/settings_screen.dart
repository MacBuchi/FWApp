/// settings_screen.dart – App settings: dark mode, Supabase sync, library info.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkModeAsync = ref.watch(themeModeProvider);
    final syncAsync = ref.watch(syncSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          // ─── Darstellung ─────────────────────────────────────
          _SectionHeader('Darstellung'),
          darkModeAsync.when(
            loading: () => const ListTile(title: Text('Lade...')),
            error: (e, _) => ListTile(title: Text('Fehler: $e')),
            data: (isDark) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Dunkles Design'),
              value: isDark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),

          // ─── Supabase Sync ────────────────────────────────────
          _SectionHeader('Cloud-Synchronisation'),
          syncAsync.when(
            loading: () => const ListTile(title: Text('Lade...')),
            error: (e, _) => ListTile(title: Text('Fehler: $e')),
            data: (settings) => Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_sync),
                  title: const Text('Supabase-Sync aktivieren'),
                  subtitle: const Text(
                      'Daten werden mit der Cloud synchronisiert'),
                  value: settings.enabled,
                  onChanged: (v) => ref
                      .read(syncSettingsProvider.notifier)
                      .save(SyncSettings(
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
                      ref,
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
                    subtitle: Text(settings.supabaseKey.isEmpty
                        ? 'Nicht konfiguriert'
                        : '••••••••'),
                    onTap: () => _editText(
                      context,
                      ref,
                      title: 'Supabase Anon Key',
                      initial: settings.supabaseKey,
                      obscure: true,
                      onSave: (v) => ref
                          .read(syncSettingsProvider.notifier)
                          .save(settings.copyWith(supabaseKey: v)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Bibliothek ───────────────────────────────────────
          _SectionHeader('Gerätebibliothek'),
          const ListTile(
            leading: Icon(Icons.library_books),
            title: Text('Installierte Version'),
            subtitle: Text('v1.0.0 – 257 Geräte (AB-G)'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Nach Updates suchen'),
            subtitle: const Text('Prüft auf neue Bibliotheksversionen'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Keine Updates verfügbar (Netzwerk nicht konfiguriert).')),
            ),
          ),

          // ─── App-Info ─────────────────────────────────────────
          _SectionHeader('App-Information'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final info = snap.data;
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                subtitle: Text(info != null
                    ? '${info.version} (Build ${info.buildNumber})'
                    : '...'),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editText(
    BuildContext context,
    WidgetRef ref, {
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      );
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
