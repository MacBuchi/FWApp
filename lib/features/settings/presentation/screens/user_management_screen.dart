/// user_management_screen.dart – Admin-Nutzerverwaltung (M7 Etappe 3):
/// Konten anlegen (Nutzername + Initialpasswort), Passwort zurücksetzen,
/// Rolle ändern, sperren/entsperren, löschen. Nur für Admins erreichbar
/// (Tile im Mehr-Tab ist isAdmin-gated; die Edge Function prüft serverseitig
/// nochmal).
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/auth_utils.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/providers/user_admin_providers.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(managedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutzerverwaltung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: () => ref.invalidate(managedUsersProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createUser(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Nutzer anlegen'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nutzerliste konnte nicht geladen werden:\n$e',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(managedUsersProvider),
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
        data: (users) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: users.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, i) => _UserTile(user: users[i]),
        ),
      ),
    );
  }

  Future<void> _createUser(BuildContext context, WidgetRef ref) async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl =
        TextEditingController(text: generateInitialPassword());
    var role = 'member';
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nutzer anlegen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nutzername',
                  helperText: 'z. B. max.m – steht auf dem Zugangszettel',
                ),
                autocorrect: false,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rolle'),
                items: const [
                  DropdownMenuItem(
                      value: 'member', child: Text('Mitglied (liest)')),
                  DropdownMenuItem(
                      value: 'geraetewart',
                      child: Text('Gerätewart (bearbeitet)')),
                  DropdownMenuItem(
                      value: 'admin', child: Text('Admin (verwaltet)')),
                ],
                onChanged: (v) => setState(() => role = v ?? 'member'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Initialpasswort',
                  helperText: 'Muss beim ersten Login geändert werden',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.casino),
                    tooltip: 'Neu würfeln',
                    onPressed: () => setState(
                        () => passwordCtrl.text = generateInitialPassword()),
                  ),
                ),
                autocorrect: false,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final name = usernameCtrl.text.trim().toLowerCase();
                if (!isValidUsername(name)) {
                  setState(() => error =
                      'Ungültiger Nutzername (3–32 Zeichen: a-z, 0-9, . _ -)');
                  return;
                }
                if (passwordCtrl.text.length < 8) {
                  setState(
                      () => error = 'Passwort braucht mindestens 8 Zeichen');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Anlegen'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final username = usernameCtrl.text.trim().toLowerCase();
    await _run(context, ref, () async {
      await invokeAdminUsers(ref.read(supabaseClientProvider), {
        'action': 'create',
        'username': username,
        'role': role,
        'password': passwordCtrl.text,
      });
      if (context.mounted) {
        await _showCredentials(context, username, passwordCtrl.text);
      }
    });
  }
}

/// Zeigt die Zugangsdaten GENAU EINMAL an (fürs Übertragen auf den
/// Zugangszettel) — das Passwort ist danach nirgends mehr ablesbar.
Future<void> _showCredentials(
    BuildContext context, String username, String password) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Zugangsdaten notieren'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fürs Ausfüllen des Zugangszettels — diese Anzeige kommt '
            'nur einmal:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SelectableText('Nutzername: $username\nPasswort: $password',
              style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Kopieren'),
          onPressed: () => Clipboard.setData(ClipboardData(
              text: 'Nutzername: $username\nPasswort: $password')),
        ),
        FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Notiert')),
      ],
    ),
  );
}

class _UserTile extends ConsumerWidget {
  final ManagedUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleLabel = switch (user.role) {
      'admin' => 'Admin',
      'geraetewart' => 'Gerätewart',
      _ => 'Mitglied',
    };
    final details = <String>[
      roleLabel,
      if (user.banned) 'GESPERRT',
      if (user.mustChangePassword) 'Initialpasswort aktiv',
      if (user.lastSignInAt != null)
        'zuletzt ${_fmtDate(user.lastSignInAt!)}'
      else
        'noch nie angemeldet',
    ];

    return ListTile(
      leading: Icon(
        user.banned
            ? Icons.block
            : switch (user.role) {
                'admin' => Icons.admin_panel_settings,
                'geraetewart' => Icons.build_circle,
                _ => Icons.person,
              },
        color: user.banned ? Colors.red : null,
      ),
      title: Text(user.username,
          style: user.banned
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null),
      subtitle: Text(details.join(' · ')),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _onAction(context, ref, action),
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: 'reset', child: Text('Passwort zurücksetzen')),
          const PopupMenuItem(value: 'role', child: Text('Rolle ändern')),
          PopupMenuItem(
              value: user.banned ? 'enable' : 'disable',
              child: Text(user.banned ? 'Entsperren' : 'Sperren')),
          const PopupMenuItem(value: 'delete', child: Text('Löschen')),
        ],
      ),
    );
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'reset':
        final password = generateInitialPassword();
        final ok = await _confirm(
            context,
            'Passwort zurücksetzen?',
            'Für „${user.username}“ wird ein neues Initialpasswort gesetzt; '
                'das alte Passwort gilt sofort nicht mehr.');
        if (ok && context.mounted) {
          await _run(context, ref, () async {
            await invokeAdminUsers(ref.read(supabaseClientProvider), {
              'action': 'reset',
              'user_id': user.id,
              'password': password,
            });
            if (context.mounted) {
              await _showCredentials(context, user.username, password);
            }
          });
        }
      case 'role':
        var role = user.role;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Rolle von „${user.username}“'),
            content: StatefulBuilder(
              builder: (ctx, setState) => DropdownButtonFormField<String>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(
                      value: 'member', child: Text('Mitglied (liest)')),
                  DropdownMenuItem(
                      value: 'geraetewart',
                      child: Text('Gerätewart (bearbeitet)')),
                  DropdownMenuItem(
                      value: 'admin', child: Text('Admin (verwaltet)')),
                ],
                onChanged: (v) => setState(() => role = v ?? role),
              ),
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
        if (ok == true && context.mounted) {
          await _run(
              context,
              ref,
              () => invokeAdminUsers(ref.read(supabaseClientProvider),
                  {'action': 'set_role', 'user_id': user.id, 'role': role}));
        }
      case 'disable':
      case 'enable':
        final ok = action == 'enable' ||
            await _confirm(
                context,
                'Konto sperren?',
                '„${user.username}“ kann sich danach nicht mehr anmelden, '
                    'bis das Konto entsperrt wird.');
        if (ok && context.mounted) {
          await _run(context, ref,
              () => invokeAdminUsers(ref.read(supabaseClientProvider), {'action': action, 'user_id': user.id}));
        }
      case 'delete':
        final ok = await _confirm(
            context,
            'Konto löschen?',
            '„${user.username}“ wird endgültig gelöscht. Für zeitweiliges '
                'Stilllegen besser „Sperren“ verwenden.');
        if (ok && context.mounted) {
          await _run(context, ref,
              () => invokeAdminUsers(ref.read(supabaseClientProvider), {'action': 'delete', 'user_id': user.id}));
        }
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ja')),
        ],
      ),
    );
    return ok == true;
  }

  String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

/// Führt eine Verwaltungsaktion aus, meldet Fehler als Snackbar und lädt
/// die Liste neu.
Future<void> _run(BuildContext context, WidgetRef ref,
    Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehlgeschlagen: $e')));
    }
  } finally {
    ref.invalidate(managedUsersProvider);
  }
}
