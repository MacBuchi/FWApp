/// settings_screen.dart – App settings: dark mode, Supabase sync, library info.
library;
import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fwapp/core/sync/auth_utils.dart';
import 'package:fwapp/core/sync/image_precache.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, UserAttributes;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final syncAsync = ref.watch(syncSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          // ─── Darstellung ─────────────────────────────────────
          _SectionHeader('Darstellung'),
          themeModeAsync.when(
            loading: () => const ListTile(title: Text('Lade...')),
            error: (e, _) => ListTile(title: Text('Fehler: $e')),
            data: (mode) => Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.brightness_6),
                  title: Text('Design'),
                  subtitle:
                      Text('Standard: folgt der Systemeinstellung'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.settings_suggest),
                          label: Text('System')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Hell')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Dunkel')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeProvider.notifier)
                        .set(selection.first),
                  ),
                ),
              ],
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
          if (ref.watch(supabaseReadyProvider)) ...[
            const _ServerHealthTile(),
            const _ConnectionSection(),
          ],

          // ─── Bibliothek ───────────────────────────────────────
          _SectionHeader('Gerätebibliothek'),
          const _LibraryInfoTile(),

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

/// Version and item count of the bundled equipment library, read from
/// assets/equipment_library/metadata.json.
class _LibraryInfoTile extends StatelessWidget {
  const _LibraryInfoTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context)
          .loadString('assets/equipment_library/metadata.json'),
      builder: (context, snapshot) {
        String subtitle = '…';
        if (snapshot.hasError) {
          subtitle = 'Keine Bibliothek gebündelt';
        } else if (snapshot.hasData) {
          try {
            final meta = jsonDecode(snapshot.data!) as Map<String, dynamic>;
            final vehicles = (meta['vehicles'] as List?)?.join(', ') ?? '?';
            subtitle = 'v${meta['version'] ?? '?'} – '
                '${meta['equipment_count'] ?? '?'} Geräte ($vehicles), '
                'Stand ${meta['last_updated'] ?? '?'}';
          } catch (_) {
            subtitle = 'metadata.json nicht lesbar';
          }
        }
        return ListTile(
          leading: const Icon(Icons.library_books),
          title: const Text('Gebündelte Bibliothek'),
          subtitle: Text(subtitle),
        );
      },
    );
  }
}

/// Live-Verbindungsstatus zum Sync-Server — sichtbar schon VOR dem Login,
/// damit Netzwerkprobleme nicht wie falsche Zugangsdaten aussehen.
class _ServerHealthTile extends ConsumerWidget {
  const _ServerHealthTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(serverHealthProvider);
    return health.when(
      loading: () => const ListTile(
        leading: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5)),
        title: Text('Prüfe Server…'),
      ),
      error: (_, __) => _statusTile(ref, reachable: false),
      data: (reachable) => _statusTile(ref, reachable: reachable),
    );
  }

  Widget _statusTile(WidgetRef ref, {required bool reachable}) => ListTile(
        leading: Icon(reachable ? Icons.check_circle : Icons.cancel,
            color: reachable ? Colors.green : Colors.red),
        title: Text(
            reachable ? 'Server erreichbar' : 'Server nicht erreichbar'),
        subtitle: Text(reachable
            ? 'Verbindung steht – zum erneuten Prüfen tippen'
            : 'Internetverbindung prüfen – zum erneuten Prüfen tippen'),
        onTap: () => ref.invalidate(serverHealthProvider),
      );
}

/// Login, role, pull and publish actions — shown only when Supabase was
/// initialised at app start.
class _ConnectionSection extends ConsumerWidget {
  const _ConnectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStreamProvider).value;
    final role = ref.watch(currentUserRoleProvider).value;
    final canEdit = ref.watch(canEditProvider);
    final syncMeta = ref.watch(syncMetaStreamProvider).value;
    final mustChange = ref.watch(mustChangePasswordProvider).value ?? false;

    if (session == null) {
      return ListTile(
        leading: const Icon(Icons.login),
        title: const Text('Mit Abteilung verbinden'),
        subtitle: const Text('Anmelden, um den zentralen Datenbestand zu laden'),
        onTap: () => _login(context, ref),
      );
    }

    final roleLabel = switch (role) {
      'admin' => 'Rolle: Admin – volle Verwaltung, darf bearbeiten und '
          'veröffentlichen',
      'geraetewart' =>
        'Rolle: Gerätewart – darf bearbeiten und veröffentlichen',
      'member' => 'Rolle: Mitglied – nur Lesezugriff',
      null => 'Rolle wird geladen...',
      _ => 'Rolle: $role',
    };

    return Column(
      children: [
        ListTile(
          leading: Icon(canEdit ? Icons.admin_panel_settings : Icons.person),
          title: Text(session.user.email ?? 'Angemeldet'),
          subtitle: Text(roleLabel),
          trailing: TextButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider)?.auth.signOut();
            },
            child: const Text('Abmelden'),
          ),
        ),
        if (mustChange)
          ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.red),
            title: const Text('Passwort ändern erforderlich',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text(
                'Das Initialpasswort vom Zugangszettel muss ersetzt werden'),
            onTap: () => showForcedPasswordChange(context, ref),
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
        if (canEdit)
          ListTile(
            leading: Icon(Icons.cloud_upload,
                color: (syncMeta?.localDirty ?? false) ? Colors.orange : null),
            title: const Text('Veröffentlichen'),
            subtitle: Text((syncMeta?.localDirty ?? false)
                ? 'Unveröffentlichte Änderungen vorhanden'
                : 'Lokalen Datenbestand als neue Version veröffentlichen'),
            onTap: () => _publish(context, ref),
          ),
        const _ImageCacheTile(),
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
        // Scrollbar, damit auf kleinen Screens mit offener Tastatur nichts
        // von den Buttons überlappt wird (Feldtest Pixel XL).
        content: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Nutzername',
                helperText: 'Vom Zugangszettel (oder vollständige E-Mail)',
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofocus: true,
            ),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'Passwort'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'Keine Registrierung nötig — die Zugangsdaten vergibt der '
              'Gerätewart (Zugangszettel im Gerätehaus).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        )),
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
            email: loginInputToEmail(emailCtrl.text),
            password: passwordCtrl.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Angemeldet. Lade Datenbestand...')));
      }
      // Initialpasswort? Dann MUSS es jetzt geändert werden (M7 Etappe 3).
      final mustChange =
          await ref.refresh(mustChangePasswordProvider.future);
      if (mustChange && context.mounted) {
        await showForcedPasswordChange(context, ref);
      }
      final version = await ref.read(syncServiceProvider)?.pullIfNewer();
      if (version != null) {
        unawaited(ref.read(imagePrecacheProvider.notifier).run());
      }
      if (context.mounted && version != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Datenbestand Version $version geladen.')));
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        final hint = e.message.toLowerCase().contains('credentials')
            ? 'E-Mail oder Passwort falsch — Daten vom Zugangszettel '
                'übernehmen.'
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Anmeldung fehlgeschlagen: $hint')));
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
      unawaited(ref.read(imagePrecacheProvider.notifier).run());
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

/// Erzwungener Passwortwechsel nach dem ersten Login mit Initialpasswort
/// (M7 Etappe 3). Nicht wegklickbar — die einzigen Auswege sind ein neues
/// Passwort oder Abmelden. Löscht danach das must_change_password-Flag
/// per RPC und invalidiert den Provider.
Future<void> showForcedPasswordChange(
    BuildContext context, WidgetRef ref) async {
  final pw1 = TextEditingController();
  final pw2 = TextEditingController();
  String? error;
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Neues Passwort festlegen'),
          // Scrollbar: verhindert Button-Überlappung auf kleinen Screens
          // mit offener Tastatur (Feldtest Pixel XL).
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Du bist mit einem Initialpasswort angemeldet. Bitte lege '
                'jetzt dein eigenes Passwort fest (mindestens 8 Zeichen).',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pw1,
                decoration:
                    const InputDecoration(labelText: 'Neues Passwort'),
                obscureText: true,
                autofocus: true,
              ),
              TextField(
                controller: pw2,
                decoration:
                    const InputDecoration(labelText: 'Passwort wiederholen'),
                obscureText: true,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          )),
          actions: [
            TextButton(
              onPressed: () async {
                await ref.read(supabaseClientProvider)?.auth.signOut();
                if (ctx.mounted) Navigator.pop(ctx, false);
              },
              child: const Text('Abmelden'),
            ),
            FilledButton(
              onPressed: () async {
                if (pw1.text.length < 8) {
                  setState(() =>
                      error = 'Mindestens 8 Zeichen erforderlich.');
                  return;
                }
                if (pw1.text != pw2.text) {
                  setState(
                      () => error = 'Die Passwörter stimmen nicht überein.');
                  return;
                }
                try {
                  final client = ref.read(supabaseClientProvider);
                  await client?.auth
                      .updateUser(UserAttributes(password: pw1.text));
                  await client?.rpc('clear_must_change_password');
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } on AuthException catch (e) {
                  setState(() => error = e.message);
                } catch (e) {
                  setState(() => error = 'Fehler: $e');
                }
              },
              child: const Text('Passwort setzen'),
            ),
          ],
        ),
      ),
    ),
  );
  ref.invalidate(mustChangePasswordProvider);
  if (changed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Passwort geändert – Zugangszettel wegwerfen.')));
  }
}

/// Offline availability of the central photos: shows precache progress and
/// lets the user re-run the download (e.g. after a failed first attempt).
class _ImageCacheTile extends ConsumerWidget {
  const _ImageCacheTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(imagePrecacheProvider);

    final String subtitle;
    if (cache.running) {
      subtitle = 'Lade ${cache.done + cache.failed}/${cache.total}…';
    } else if (!cache.hasRun) {
      subtitle = 'Fotos für die Offline-Nutzung herunterladen';
    } else if (cache.failed > 0) {
      subtitle = '${cache.done}/${cache.total} geladen, '
          '${cache.failed} fehlgeschlagen – antippen zum Wiederholen';
    } else {
      subtitle = 'Alle ${cache.done} Fotos offline verfügbar';
    }

    return ListTile(
      leading: cache.running
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.photo_library,
              color: cache.hasRun && cache.failed > 0 ? Colors.orange : null),
      title: const Text('Gerätefotos offline'),
      subtitle: Text(subtitle),
      onTap: cache.running
          ? null
          : () => ref.read(imagePrecacheProvider.notifier).run(),
    );
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
