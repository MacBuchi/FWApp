/// settings_screen.dart – App settings: dark mode, Supabase sync, library info.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

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
          ),
          if (ref.watch(supabaseReadyProvider)) const _ConnectionSection(),

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

/// Login, role, pull and publish actions — shown only when Supabase was
/// initialised at app start.
class _ConnectionSection extends ConsumerWidget {
  const _ConnectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStreamProvider).value;
    final role = ref.watch(currentUserRoleProvider).value;
    final isAdmin = ref.watch(isAdminProvider);
    final syncMeta = ref.watch(syncMetaStreamProvider).value;

    if (session == null) {
      return ListTile(
        leading: const Icon(Icons.login),
        title: const Text('Mit Abteilung verbinden'),
        subtitle: const Text('Anmelden, um den zentralen Datenbestand zu laden'),
        onTap: () => _login(context, ref),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person),
          title: Text(session.user.email ?? 'Angemeldet'),
          subtitle: Text(isAdmin
              ? 'Rolle: Admin – darf bearbeiten und veröffentlichen'
              : role == null
                  ? 'Rolle wird geladen...'
                  : 'Rolle: Mitglied – nur Lesezugriff'),
          trailing: TextButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider)?.auth.signOut();
            },
            child: const Text('Abmelden'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Jetzt aktualisieren'),
          subtitle: Text(syncMeta == null || syncMeta.lastPulledAt == null
              ? 'Noch nie synchronisiert'
              : 'Stand: Version ${syncMeta.lastPulledVersion} vom '
                  '${_fmt(syncMeta.lastPulledAt!)}'),
          onTap: () => _pull(context, ref),
        ),
        if (isAdmin)
          ListTile(
            leading: Icon(Icons.cloud_upload,
                color: (syncMeta?.localDirty ?? false) ? Colors.orange : null),
            title: const Text('Veröffentlichen'),
            subtitle: Text((syncMeta?.localDirty ?? false)
                ? 'Unveröffentlichte Änderungen vorhanden'
                : 'Lokalen Datenbestand als neue Version veröffentlichen'),
            onTap: () => _publish(context, ref),
          ),
      ],
    );
  }

  Future<void> _login(BuildContext context, WidgetRef ref) async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anmelden'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'E-Mail'),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'Passwort'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anmelden')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(supabaseClientProvider)?.auth.signInWithPassword(
            email: emailCtrl.text.trim(),
            password: passwordCtrl.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Angemeldet. Lade Datenbestand...')));
      }
      final version = await ref.read(syncServiceProvider)?.pullIfNewer();
      if (context.mounted && version != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Datenbestand Version $version geladen.')));
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Anmeldung fehlgeschlagen: ${e.message}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _pull(BuildContext context, WidgetRef ref) async {
    try {
      final version =
          await ref.read(syncServiceProvider)?.pullIfNewer(force: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(version == null
                ? 'Bereits aktuell.'
                : 'Datenbestand Version $version geladen.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aktualisierung fehlgeschlagen: $e')));
      }
    }
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Veröffentlichen?'),
        content: const Text(
            'Der lokale Datenbestand ersetzt die zentrale Version für alle '
            'Mitglieder der Abteilung.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Veröffentlichen')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final version = await ref.read(syncServiceProvider)?.publish();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Version $version veröffentlicht.')));
      }
    } catch (e) {
      if (context.mounted) {
        final message = e.toString().contains('version conflict')
            ? 'Konflikt: Jemand hat zwischenzeitlich veröffentlicht. '
                'Bitte erst „Jetzt aktualisieren“, dann erneut veröffentlichen.'
            : 'Veröffentlichen fehlgeschlagen: $e';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.'
      '${dt.month.toString().padLeft(2, '0')}.'
      '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
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
