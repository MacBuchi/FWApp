/// user_management_screen.dart – Nutzerverwaltung (M7 Etappe 3; Rollen je
/// Abteilung seit Nutzerkonzept Stufe 1, Issue #98): Konten anlegen
/// (Nutzername + Initialpasswort), Passwort zurücksetzen, Mitgliedschaften
/// (Rolle je Abteilung) pflegen, Feuerwehrkommandanten ernennen,
/// sperren/entsperren, löschen. Nur für Verwalter erreichbar (Tile im
/// Mehr-Tab ist isAdmin-gated); die Edge Function prüft die Hierarchie
/// serverseitig nochmal — wer welche Rolle wo vergeben darf, entscheidet
/// dort `darfVerwalten`.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/auth_utils.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/rollen.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/settings/presentation/providers/einladung_providers.dart';
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
        data: (users) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            const _EinladungenAbschnitt(),
            const Divider(height: 24),
            for (var i = 0; i < users.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              _UserTile(user: users[i]),
            ],
          ],
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
    // Ohne Auswahl legt der Server das Konto in die Abteilung des
    // Anlegenden — deshalb ist `null` hier ein gültiger Zustand und nicht
    // „vergessen".
    final abteilungen = ref.read(abteilungenProvider).value ?? const [];
    final eigene = ref.read(myAbteilungIdProvider).value;
    String? abteilung = abteilungen.any((a) => a.id == eigene) ? eigene : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nutzer anlegen'),
          // Scrollbar: verhindert Button-Überlappung auf kleinen Screens
          // mit offener Tastatur (Feldtest Pixel XL).
          content: SingleChildScrollView(
              child: Column(
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
                // Anzeigenamen aus dem Nutzerkonzept; ein frisches
                // Zettel-Konto ohne echte Mail ist ein Truppmann.
                items: const [
                  DropdownMenuItem(
                      value: 'member', child: Text('Truppmann (liest)')),
                  DropdownMenuItem(
                      value: 'geraetewart',
                      child: Text('Gerätewart (bearbeitet)')),
                  DropdownMenuItem(
                      value: 'admin',
                      child: Text('Abteilungskommandant (verwaltet)')),
                ],
                onChanged: (v) => setState(() => role = v ?? 'member'),
              ),
              if (abteilungen.length > 1) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: abteilung,
                  decoration: const InputDecoration(labelText: 'Abteilung'),
                  items: [
                    for (final a in abteilungen)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => abteilung = v ?? abteilung),
                ),
              ],
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
          )),
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
        if (abteilung != null) 'abteilung_id': abteilung,
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

/// Einladungen per Mail (Nutzerkonzept Stufe 3, Issue #100).
///
/// Steht bewusst ÜBER der Kontoliste: Für alle mit erreichbarer Adresse ist
/// das der bessere Weg — ein eingeladenes Konto kann sein Passwort selbst
/// zurücksetzen, ein Zettel-Konto (`@fw.local`) nie. Der Zettel bleibt für
/// die Truppmannschaft ohne Mailadresse.
class _EinladungenAbschnitt extends ConsumerWidget {
  const _EinladungenAbschnitt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offen = ref.watch(offeneEinladungenProvider).value ?? const [];
    final abteilungen = ref.watch(abteilungenProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Einladungen',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _einladen(context, ref),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Einladen'),
              ),
            ],
          ),
        ),
        if (offen.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Keine offene Einladung. Wer eine E-Mail-Adresse hat, wird '
              'eingeladen statt mit Zugangszettel angelegt — nur so kann er '
              'sein Passwort später selbst zurücksetzen.',
              style: TextStyle(fontSize: 12),
            ),
          )
        else
          for (final e in offen)
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: Text(
                  e.anzeigename?.isNotEmpty == true ? e.anzeigename! : e.email),
              subtitle: Text(
                '${e.email}\n'
                '${rolleAnzeigename(e.role, kommandant: e.alsKommandant)} · '
                '${abteilungsName(e.abteilungId, abteilungen)} · '
                'wartet auf Bestätigung',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (wahl) => _einladungAktion(context, ref, e, wahl),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'invite_resend', child: Text('Erneut senden')),
                  PopupMenuItem(
                      value: 'invite_revoke', child: Text('Zurückziehen')),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _einladungAktion(
      BuildContext context, WidgetRef ref, Einladung e, String aktion) async {
    if (aktion == 'invite_revoke') {
      final ok = await showDialog<bool>(
        context: context,
        // Die Route liegt in der ShellRoute — ohne den Wurzel-Navigator läge
        // der Dialog UNTER der NavigationBar, und ein Tipp knapp daneben
        // bräche ihn ab und wechselte den Tab (AGENTS.md, #79/#96).
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: const Text('Einladung zurückziehen?'),
          content: Text('${e.email} kann den Code dann nicht mehr einlösen. '
              'Die Adresse ist danach wieder frei für eine neue Einladung.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Zurückziehen')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    await _run(context, ref, () async {
      await invokeAdminUsers(ref.read(supabaseClientProvider), {
        'action': aktion,
        'einladung_id': e.id,
      });
      ref.invalidate(offeneEinladungenProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(aktion == 'invite_resend'
              ? 'Neue Einladung an ${e.email} verschickt.'
              : 'Einladung zurückgezogen.'),
        ));
      }
    });
  }

  Future<void> _einladen(BuildContext context, WidgetRef ref) async {
    final mailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    var role = 'geraetewart';
    var alsKommandant = false;
    String? error;

    final abteilungen = ref.read(abteilungenProvider).value ?? const [];
    final kommandiert =
        ref.read(meineKommandoGesamtwehrenProvider).value ?? const <String>{};
    final eigene = ref.read(myAbteilungIdProvider).value;
    var abteilung = abteilungen.any((a) => a.id == eigene)
        ? eigene
        : (abteilungen.isNotEmpty ? abteilungen.first.id : null);

    // Der Feuerwehrkommandant ist eine Gesamtwehr-Stellung — die Frage ergibt
    // nur Sinn, wenn die gewählte Abteilung an einer Gesamtwehr hängt UND der
    // Einladende dort selbst Kommandant ist. Der Server prüft es nochmal.
    bool darfKommandantErnennen(String? abteilungId) {
      for (final a in abteilungen) {
        if (a.id == abteilungId) {
          return a.gesamtwehrId != null &&
              kommandiert.contains(a.gesamtwehrId);
        }
      }
      return false;
    }

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true, // siehe oben
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Per E-Mail einladen'),
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mailCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-Mail-Adresse',
                  helperText: 'Dorthin geht der Code — muss erreichbar sein',
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Anzeigename',
                  helperText: 'Wie die Person in der Wehr gerufen wird',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rolle'),
                items: const [
                  DropdownMenuItem(
                      value: 'member', child: Text('Truppführer (liest)')),
                  DropdownMenuItem(
                      value: 'geraetewart',
                      child: Text('Gerätewart (bearbeitet)')),
                  DropdownMenuItem(
                      value: 'admin',
                      child: Text('Abteilungskommandant (verwaltet)')),
                ],
                onChanged: (v) => setState(() => role = v ?? 'geraetewart'),
              ),
              if (abteilungen.length > 1) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: abteilung,
                  decoration: const InputDecoration(labelText: 'Abteilung'),
                  items: [
                    for (final a in abteilungen)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() {
                    abteilung = v ?? abteilung;
                    if (!darfKommandantErnennen(abteilung)) {
                      alsKommandant = false;
                    }
                  }),
                ),
              ],
              if (darfKommandantErnennen(abteilung))
                CheckboxListTile(
                  value: alsKommandant,
                  onChanged: (v) => setState(() => alsKommandant = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auch Feuerwehrkommandant'),
                  subtitle: const Text(
                    'Zwei Kommandanten je Gesamtwehr sind der Schutz davor, '
                    'dass sich die Wehr aussperrt.',
                    style: TextStyle(fontSize: 12),
                  ),
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
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final mail = mailCtrl.text.trim().toLowerCase();
                if (!mail.contains('@') || !mail.contains('.')) {
                  setState(() => error =
                      'Bitte eine vollständige E-Mail-Adresse angeben.');
                  return;
                }
                if (!hatEchteMail(mail)) {
                  setState(() => error =
                      '@$kAccountDomain ist die interne Zettel-Form — dorthin '
                      'kann keine Mail zugestellt werden.');
                  return;
                }
                if (abteilung == null) {
                  setState(() => error = 'Keine Abteilung wählbar.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Einladen'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final mail = mailCtrl.text.trim().toLowerCase();
    await _run(context, ref, () async {
      await invokeAdminUsers(ref.read(supabaseClientProvider), {
        'action': 'invite',
        'email': mail,
        'anzeigename': nameCtrl.text.trim(),
        'abteilung_id': abteilung,
        'role': role,
        'als_kommandant': alsKommandant,
      });
      ref.invalidate(offeneEinladungenProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Einladung an $mail verschickt. Der Code gilt '
              'mindestens eine Stunde.'),
        ));
      }
    });
  }
}

class _UserTile extends ConsumerWidget {
  final ManagedUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abteilungen = ref.watch(abteilungenProvider).value ?? const [];
    final istKommandant = user.kommandantGesamtwehren.isNotEmpty;
    // Die Zettel-Form <name>@fw.local ist keine Information — sie steht
    // schon als Nutzername im Titel. Sichtbar wird die Adresse erst, wenn
    // sie eine echte ist (dann ist sie auch die Anmeldung).
    final echteMail = hatEchteMail(user.email);
    // Eine Zeile je Wirkungskreis: „Gerätewart (Grombach)" — der
    // Abteilungsname entfällt, solange es nur eine Abteilung gibt.
    final rollen = <String>[
      if (istKommandant) rolleAnzeigename(null, kommandant: true),
      for (final e in user.memberships.entries)
        abteilungen.length > 1
            ? '${rolleAnzeigename(e.value, echteMail: echteMail)} '
                '(${abteilungsName(e.key, abteilungen)})'
            : rolleAnzeigename(e.value, echteMail: echteMail),
    ];
    final details = <String>[
      if (rollen.isNotEmpty)
        rollen.join(', ')
      else ...[
        // Ohne Mitgliedschaften (Alt-Server oder verwaistes Konto): die
        // alte Darstellung — inklusive „ohne Abteilung"/„andere
        // Gesamtwehr", denn ein kaputtes Konto soll auffallen.
        rolleAnzeigename(user.role, echteMail: echteMail),
        if (abteilungen.isNotEmpty)
          abteilungsName(user.abteilungId, abteilungen),
      ],
      if (echteMail) user.email,
      if (user.banned) 'GESPERRT',
      if (user.mustChangePassword) 'Initialpasswort aktiv',
      if (user.lastSignInAt != null)
        'zuletzt ${_fmtDate(user.lastSignInAt!)}'
      else
        'noch nie angemeldet',
    ];

    // Kommandant ernennen/entlassen: nur dort, wo der Angemeldete selbst
    // Feuerwehrkommandant ist UND das Ziel eindeutig ist.
    final meineKommandos =
        ref.watch(meineKommandoGesamtwehrenProvider).value ?? const <String>{};
    final kommandantZiel = _kommandantZiel(meineKommandos, abteilungen);

    return ListTile(
      leading: Icon(
        user.banned
            ? Icons.block
            : istKommandant
                ? Icons.local_fire_department
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
        onSelected: (action) => _onAction(context, ref, action, abteilungen),
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: 'reset', child: Text('Passwort zurücksetzen')),
          // Mitgliedschafts-Server: Rollen je Abteilung in einem Dialog.
          // Alt-Server: die beiden früheren Einzel-Dialoge.
          if (user.hatMitgliedschaften)
            const PopupMenuItem(
                value: 'mitgliedschaften', child: Text('Rollen & Abteilungen'))
          else ...[
            const PopupMenuItem(value: 'role', child: Text('Rolle ändern')),
            if (abteilungen.length > 1)
              const PopupMenuItem(
                  value: 'abteilung', child: Text('Abteilung ändern')),
          ],
          if (kommandantZiel != null)
            PopupMenuItem(
                value: 'kommandant',
                child: Text(user.kommandantGesamtwehren.contains(kommandantZiel)
                    ? 'Als Feuerwehrkommandant entlassen'
                    : 'Zum Feuerwehrkommandanten ernennen')),
          PopupMenuItem(
              value: 'email',
              child: Text(echteMail
                  ? 'E-Mail-Adresse ändern'
                  : 'E-Mail-Adresse hinterlegen')),
          // Nur sinnvoll mit echter Adresse: GoTrue verschickt ausschließlich
          // an die Adresse des Kontos, @fw.local kann niemand empfangen.
          if (echteMail)
            const PopupMenuItem(
                value: 'zugangsmail', child: Text('Passwort-Mail senden')),
          const PopupMenuItem(
              value: 'mfa', child: Text('Zwei-Faktor zurücksetzen')),
          PopupMenuItem(
              value: user.banned ? 'enable' : 'disable',
              child: Text(user.banned ? 'Entsperren' : 'Sperren')),
          const PopupMenuItem(value: 'delete', child: Text('Löschen')),
        ],
      ),
    );
  }

  /// Die Gesamtwehr, auf die sich Ernennen/Entlassen bezöge: ergibt sich
  /// aus den Abteilungen des Kontos (plus bestehender Kommandos),
  /// geschnitten mit den eigenen Kommandos — eindeutig oder gar nicht.
  String? _kommandantZiel(
      Set<String> meineKommandos, List<AbteilungInfo> abteilungen) {
    final ziele = <String>{
      for (final abteilungId in user.memberships.keys)
        for (final a in abteilungen)
          if (a.id == abteilungId && a.gesamtwehrId != null) a.gesamtwehrId!,
      ...user.kommandantGesamtwehren,
    }.where(meineKommandos.contains).toSet();
    return ziele.length == 1 ? ziele.first : null;
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String action,
      List<AbteilungInfo> abteilungen) async {
    switch (action) {
      case 'mitgliedschaften':
        await _editMitgliedschaften(context, ref, abteilungen);
      case 'kommandant':
        final meine = ref.read(meineKommandoGesamtwehrenProvider).value ??
            const <String>{};
        final ziel = _kommandantZiel(meine, abteilungen);
        if (ziel == null) return;
        final ernennen = !user.kommandantGesamtwehren.contains(ziel);
        final ok = await _confirm(
            context,
            ernennen
                ? 'Zum Feuerwehrkommandanten ernennen?'
                : 'Als Feuerwehrkommandant entlassen?',
            ernennen
                ? '„${user.username}“ darf danach in allen Abteilungen der '
                    'Gesamtwehr schreiben, Abteilungen anlegen und '
                    'Kommandanten ernennen oder entlassen.'
                : '„${user.username}“ behält alle Mitgliedschaften, verliert '
                    'aber die Gesamtwehr-Rechte.');
        if (ok && context.mounted) {
          await _run(
              context,
              ref,
              () => invokeAdminUsers(ref.read(supabaseClientProvider), {
                    'action': 'set_kommandant',
                    'user_id': user.id,
                    'gesamtwehr_id': ziel,
                    'kommandant': ernennen,
                  }));
        }
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
      case 'email':
        // Der Warnsatz ist der wichtigste Teil des Dialogs: Ab dem Speichern
        // meldet sich die Person mit der Adresse an, der Zettel-Name gilt
        // nicht mehr. Wer das nicht weiß, sperrt jemanden versehentlich aus.
        final ctrl = TextEditingController(
            text: hatEchteMail(user.email) ? user.email : '');
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('E-Mail für „${user.username}“'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'E-Mail-Adresse',
                    helperText: 'Für „Passwort vergessen“ — nur nötig für '
                        'Admins und Gerätewarte',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Achtung: Diese Person meldet sich danach mit der '
                  'E-Mail-Adresse an, nicht mehr mit dem Nutzernamen. Bitte '
                  'Bescheid geben.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
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
              () => invokeAdminUsers(ref.read(supabaseClientProvider), {
                    'action': 'set_email',
                    'user_id': user.id,
                    'email': ctrl.text.trim(),
                  }));
        }
      case 'zugangsmail':
        final ok = await _confirm(
            context,
            'Passwort-Mail senden?',
            '„${user.username}“ bekommt an ${user.email} einen Code, mit dem '
                'die Person sich selbst ein Passwort setzen kann. Kommt die '
                'Mail nicht an, stimmt die Adresse nicht.');
        if (ok && context.mounted) {
          await _run(context, ref, () async {
            // Öffentlicher Endpunkt, kein Admin-Aufruf: Genau denselben Weg
            // geht „Passwort vergessen" im Anmeldebildschirm.
            await ref
                .read(supabaseClientProvider)
                ?.auth
                .resetPasswordForEmail(user.email);
          });
        }
      case 'mfa':
        final ok = await _confirm(
            context,
            'Zwei-Faktor zurücksetzen?',
            'Für „${user.username}“ wird der zweite Faktor entfernt. Die '
                'Person meldet sich danach nur noch mit dem Passwort an und '
                'kann ihn neu einrichten. Nur machen, wenn du sicher bist, '
                'wen du vor dir hast — das ist der Weg für ein verlorenes '
                'Telefon.');
        if (ok && context.mounted) {
          await _run(
              context,
              ref,
              () => invokeAdminUsers(ref.read(supabaseClientProvider), {
                    'action': 'clear_mfa',
                    'user_id': user.id,
                  }));
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
                      value: 'member', child: Text('Truppmann (liest)')),
                  DropdownMenuItem(
                      value: 'geraetewart',
                      child: Text('Gerätewart (bearbeitet)')),
                  DropdownMenuItem(
                      value: 'admin',
                      child: Text('Abteilungskommandant (verwaltet)')),
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
      case 'abteilung':
        // Vorauswahl: die aktuelle Abteilung, sonst die erste wählbare —
        // ein Dropdown ohne gültigen Wert wirft zur Laufzeit.
        var ziel = abteilungen.any((a) => a.id == user.abteilungId)
            ? user.abteilungId!
            : abteilungen.first.id;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Abteilung von „${user.username}“'),
            content: StatefulBuilder(
              builder: (ctx, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: ziel,
                    items: [
                      for (final a in abteilungen)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => ziel = v ?? ziel),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Das Konto arbeitet danach im Bestand der neuen '
                    'Abteilung. Ein bereits eingerichtetes Gerät holt sich '
                    'den neuen Stand erst beim nächsten Pull.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
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
              () => invokeAdminUsers(ref.read(supabaseClientProvider), {
                    'action': 'set_abteilung',
                    'user_id': user.id,
                    'abteilung_id': ziel,
                  }));
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

  /// Rollen je Abteilung in einem Dialog: eine Zeile pro Abteilung,
  /// „– keine –" beendet die Mitgliedschaft dort. Gespeichert wird nur
  /// der Unterschied zum Ist-Stand (ein Aufruf je Änderung; die Function
  /// prüft jede einzeln gegen die Hierarchie).
  Future<void> _editMitgliedschaften(BuildContext context, WidgetRef ref,
      List<AbteilungInfo> abteilungen) async {
    if (abteilungen.isEmpty) return;
    final auswahl = <String, String?>{
      for (final a in abteilungen) a.id: user.memberships[a.id],
    };
    final echteMail = hatEchteMail(user.email);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rollen von „${user.username}“'),
        content: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in abteilungen) ...[
                  DropdownButtonFormField<String?>(
                    initialValue: auswahl[a.id],
                    decoration: InputDecoration(labelText: a.name),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('– keine –')),
                      for (final rolle in const [
                        'member',
                        'geraetewart',
                        'admin',
                      ])
                        DropdownMenuItem<String?>(
                            value: rolle,
                            child: Text(
                                rolleAnzeigename(rolle, echteMail: echteMail))),
                    ],
                    onChanged: (v) => setState(() => auswahl[a.id] = v),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Ohne Mitgliedschaft sieht das Konto den Bestand dieser '
                  'Abteilung nur noch lesend über die Gesamtwehr — oder gar '
                  'nicht mehr, wenn keine Mitgliedschaft übrig bleibt.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
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
    if (ok != true || !context.mounted) return;

    await _run(context, ref, () async {
      for (final a in abteilungen) {
        final vorher = user.memberships[a.id];
        final nachher = auswahl[a.id];
        if (vorher == nachher) continue;
        if (nachher == null) {
          await invokeAdminUsers(ref.read(supabaseClientProvider), {
            'action': 'remove_membership',
            'user_id': user.id,
            'abteilung_id': a.id,
          });
        } else {
          await invokeAdminUsers(ref.read(supabaseClientProvider), {
            'action': 'set_membership',
            'user_id': user.id,
            'abteilung_id': a.id,
            'role': nachher,
          });
        }
      }
    });
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
