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
import 'package:fwapp/core/sync/temp_rechte_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/profil/presentation/widgets/fw_avatar.dart';
import 'package:fwapp/features/settings/domain/zustellung.dart';
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
        onPressed: () => _zugangszettelAnlegen(context, ref),
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
}

/// Legt ein Zettel-Konto an (Nutzername + Initialpasswort auf Papier).
///
/// Top-Level und mit Vorbelegung, weil es zwei Wege hierher gibt: der Knopf
/// „Nutzer anlegen" und — seit Issue #121 — die gescheiterte Einladung, bei
/// der die Mail nachweislich nicht ankommt. Im zweiten Fall sind Rolle und
/// Abteilung bereits entschieden; sie noch einmal auszuwählen wäre eine
/// Gelegenheit, es anders zu machen als beabsichtigt.
///
/// [statt] ist die Einladung, die dieses Konto ersetzt: Nach dem Anlegen
/// wird sie zurückgezogen, sonst stünde sie weiter als „offen" in der Liste
/// und blockierte die Adresse für einen späteren zweiten Versuch.
Future<void> _zugangszettelAnlegen(
  BuildContext context,
  WidgetRef ref, {
  String? nameVorschlag,
  String? rolleVorschlag,
  String? abteilungVorschlag,
  Einladung? statt,
}) async {
  final usernameCtrl = TextEditingController(text: nameVorschlag ?? '');
  final passwordCtrl =
      TextEditingController(text: generateInitialPassword());
  var role = rolleVorschlag ?? 'member';
  String? error;
  // Ohne Auswahl legt der Server das Konto in die Abteilung des
  // Anlegenden — deshalb ist `null` hier ein gültiger Zustand und nicht
  // „vergessen".
  final abteilungen = ref.read(abteilungenProvider).value ?? const [];
  final eigene = ref.read(myAbteilungIdProvider).value;
  final vorgabe = abteilungVorschlag ?? eigene;
  String? abteilung = abteilungen.any((a) => a.id == vorgabe) ? vorgabe : null;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(statt == null ? 'Nutzer anlegen' : 'Zugangszettel statt Mail'),
        // Scrollbar: verhindert Button-Überlappung auf kleinen Screens
        // mit offener Tastatur (Feldtest Pixel XL).
        content: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (statt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'An ${statt.email} kommt keine Mail an. Dieses Konto '
                  'bekommt stattdessen einen Zettel — die Einladung wird '
                  'dabei zurückgezogen.\n\n'
                  'Ein Zettel-Konto kann sein Passwort später NICHT selbst '
                  'zurücksetzen; dafür braucht es eine erreichbare Adresse.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
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
    // ⚠️ Erst anlegen, DANN zurückziehen. Andersherum stünde die Person
    // ohne alles da, wenn das Anlegen scheitert — die Einladung wäre schon
    // weg. Scheitert umgekehrt das Zurückziehen, gibt es das Konto und die
    // Einladung bleibt sichtbar offen; das ist von Hand zu heilen und fällt
    // wenigstens auf.
    if (statt != null) {
      await invokeAdminUsers(ref.read(supabaseClientProvider), {
        'action': 'invite_revoke',
        'einladung_id': statt.id,
      });
      ref.invalidate(offeneEinladungenProvider);
    }
    ref.invalidate(managedUsersProvider);
    if (context.mounted) {
      await _showCredentials(context, username, passwordCtrl.text);
    }
  });
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
    // Zustellung (Issue #121). Kommt nach — die Liste soll nicht darauf
    // warten; bis dahin steht bei jeder Zeile „Zustellung nicht prüfbar".
    final zustellung =
        ref.watch(einladungZustellungProvider).value ?? Zustellstand.leer;

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
            _EinladungsZeile(
              einladung: e,
              zustellung: zustellung.fuer(e.id),
              abteilungen: abteilungen,
            ),
        if (zustellung.gekuerzt > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Die Zustellung wurde nur für die ersten '
              '${offen.length - zustellung.gekuerzt} Einladungen geprüft.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
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

/// Eine offene Einladung — samt der Frage, ob sie überhaupt angekommen ist
/// (Issue #121).
///
/// Vor #121 stand hier für jede Zeile dasselbe: eine Sanduhr und „wartet auf
/// Bestätigung". Eine von Brevo verworfene Einladung sah damit exakt aus wie
/// eine, die zugestellt im Postfach lag — der Kommandant wartete auf etwas,
/// das nie kam, und der Eingeladene wusste nicht einmal davon.
class _EinladungsZeile extends ConsumerWidget {
  const _EinladungsZeile({
    required this.einladung,
    required this.zustellung,
    required this.abteilungen,
  });

  final Einladung einladung;
  final Zustellung zustellung;
  final List<AbteilungInfo> abteilungen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = einladung;
    final gescheitert = zustellung.zustand == Zustellzustand.gescheitert;
    final scheme = Theme.of(context).colorScheme;

    // Nur das Scheitern bekommt Farbe. Ein grüner Haken für „zugestellt"
    // wäre eine Beruhigung, die nicht trägt: Zugestellt heisst noch lange
    // nicht gelesen — die Mail kann im Spam-Ordner liegen, so wie im Feld
    // geschehen.
    final zeit = zustellung.zeit;
    return ListTile(
      leading: Icon(
        switch (zustellung.zustand) {
          Zustellzustand.gescheitert => Icons.report_gmailerrorred,
          Zustellzustand.zugestellt => Icons.mark_email_read_outlined,
          _ => Icons.hourglass_empty,
        },
        color: gescheitert ? scheme.error : null,
      ),
      title: Text(e.anzeigename?.isNotEmpty == true ? e.anzeigename! : e.email),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${e.email}\n'
            '${rolleAnzeigename(e.role, kommandant: e.alsKommandant)} · '
            '${abteilungsName(e.abteilungId, abteilungen)} · '
            'wartet auf Bestätigung',
          ),
          Text(
            zustellungText(zustellung) +
                (zeit == null ? '' : ' · ${_fmtUhr(zeit)}'),
            style: TextStyle(
              fontSize: 12,
              color: gescheitert ? scheme.error : scheme.outline,
              fontWeight: gescheitert ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (wahl) => _einladungAktion(context, ref, e, wahl),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'invite_resend', child: Text('Erneut senden')),
          // Steht bei JEDER Einladung, nicht nur bei den gescheiterten:
          // Ohne Brevo-Schlüssel weiss der Server gar nicht, welche das
          // sind — und dann wäre der Ausweg genau dort weg, wo er am
          // nötigsten ist.
          PopupMenuItem(
              value: 'zettel', child: Text('Zugangszettel stattdessen')),
          PopupMenuItem(value: 'invite_revoke', child: Text('Zurückziehen')),
        ],
      ),
    );
  }
}

Future<void> _einladungAktion(
    BuildContext context, WidgetRef ref, Einladung e, String aktion) async {
  if (aktion == 'zettel') {
    return _zugangszettelAnlegen(
      context,
      ref,
      nameVorschlag: zugangsnameVorschlag(e.email),
      rolleVorschlag: e.role,
      abteilungVorschlag: e.abteilungId,
      statt: e,
    );
  }
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

/// Der Kopf des Kontos mit der Rolle als kleinem Abzeichen (Issue #100).
///
/// Beides zusammen, weil beides gebraucht wird: Das Gesicht macht die Liste
/// im Gerätehaus lesbar, das Abzeichen beantwortet die Frage, für die man in
/// die Nutzerverwaltung geht. Der Kopf allein wäre hübsch und nutzlos.
class _KontoAvatar extends StatelessWidget {
  const _KontoAvatar({required this.user, required this.rollenIcon});

  final ManagedUser user;
  final IconData rollenIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gesperrte Konten verlieren die Farbe: Die Zeile ist ohnehin
          // durchgestrichen, ein fröhlicher Kopf daneben widerspricht dem.
          Opacity(
            opacity: user.banned ? 0.4 : 1,
            child: FwAvatar(konfiguration: user.avatarKopf, groesse: 40),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                rollenIcon,
                size: 14,
                color: user.banned ? Colors.red : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
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

    final meineKommandos =
        ref.watch(meineKommandoGesamtwehrenProvider).value ?? const <String>{};
    // Übungsrechte (#100): nur für Konten OHNE Schreibrolle, und nur dort, wo
    // der Angemeldete selbst erteilen darf. Ist das nicht eindeutig eine
    // Abteilung, bleibt der Eintrag weg — ein Menüpunkt, der raten müsste,
    // erteilt irgendwann das Falsche.
    final tempZiel = _uebungsZiel(
      ref.watch(meineMitgliedschaftenProvider).value,
      meineKommandos,
      abteilungen,
    );
    final laufendesRecht = tempZiel == null
        ? null
        : ref
            .watch(temporaereRechteDerAbteilungProvider(tempZiel))
            .value
            ?.where((r) => r.userId == user.id && r.laeuft)
            .firstOrNull;

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
      // Der Nutzername ist die ANMELDUNG. Sobald jemand einen eigenen
      // Anzeigenamen gewählt hat, steht oben dieser — dann gehört der
      // Nutzername sichtbar daneben, sonst weiss der Kommandant beim
      // Zurücksetzen nicht mehr, wem er den Zettel gibt.
      if (user.anzeige != user.username) user.username,
      if (echteMail) user.email,
      if (laufendesRecht != null)
        'Übungsrechte bis ${_fmtUhr(laufendesRecht.laeuftAb)}',
      if (user.banned) 'GESPERRT',
      if (user.mustChangePassword) 'Initialpasswort aktiv',
      if (user.lastSignInAt != null)
        'zuletzt ${_fmtDate(user.lastSignInAt!)}'
      else
        'noch nie angemeldet',
    ];

    // Kommandant ernennen/entlassen: nur dort, wo der Angemeldete selbst
    // Feuerwehrkommandant ist UND das Ziel eindeutig ist.
    final kommandantZiel = _kommandantZiel(meineKommandos, abteilungen);

    return ListTile(
      leading: _KontoAvatar(
        user: user,
        rollenIcon: user.banned
            ? Icons.block
            : istKommandant
                ? Icons.local_fire_department
                : switch (user.role) {
                    'admin' => Icons.admin_panel_settings,
                    'geraetewart' => Icons.build_circle,
                    _ => Icons.person,
                  },
      ),
      title: Text(user.anzeige,
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
          if (tempZiel != null)
            PopupMenuItem(
                value: 'uebung',
                child: Text(laufendesRecht != null
                    ? 'Übungsrechte beenden'
                    : 'Übungsrechte erteilen')),
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

  /// Die eine Abteilung, in der Übungsrechte für dieses Konto in Frage
  /// kommen: Der Angemeldete muss dort erteilen dürfen, und das Konto darf
  /// dort noch KEINE Schreibrolle haben (der Server lehnt das sonst mit
  /// „already permanent" ab — hier wird der Menüpunkt gar nicht erst gezeigt).
  String? _uebungsZiel(
    Map<String, String>? meineMitgliedschaften,
    Set<String> meineKommandos,
    List<AbteilungInfo> abteilungen,
  ) {
    if (meineMitgliedschaften == null) return null;
    final ziele = <String>{};
    for (final e in user.memberships.entries) {
      if (e.value == 'admin' || e.value == 'geraetewart') continue;
      final abteilung =
          abteilungen.where((a) => a.id == e.key).firstOrNull;
      if (darfTemporaeresRechtErteilen(
        abteilungId: e.key,
        gesamtwehrId: abteilung?.gesamtwehrId,
        mitgliedschaften: meineMitgliedschaften,
        kommandierteGesamtwehren: meineKommandos,
      )) {
        ziele.add(e.key);
      }
    }
    return ziele.length == 1 ? ziele.first : null;
  }

  Future<void> _uebungsrechte(BuildContext context, WidgetRef ref,
      String abteilungId, TemporaeresRecht? laufend) async {
    final dienst = ref.read(tempRechteServiceProvider);
    if (dienst == null) return;

    if (laufend != null) {
      final ok = await _confirm(
          context,
          'Übungsrechte beenden?',
          '„${user.username}“ kann danach sofort nicht mehr bearbeiten. '
              'Das Protokoll bleibt erhalten.');
      if (!ok || !context.mounted) return;
      await _run(context, ref, () => dienst.zieheZurueck(laufend.id, abteilungId),
          erfolg: 'Übungsrechte beendet.', fehlerText: tempRechtFehlerText);
      return;
    }

    final bis = await showDialog<DateTime>(
      context: context,
      // ShellRoute-Regel aus AGENTS.md: sonst liegt der Dialog unter der
      // NavigationBar.
      useRootNavigator: true,
      builder: (_) => _UebungsrechteDialog(name: user.username),
    );
    if (bis == null || !context.mounted) return;
    await _run(context, ref, () => dienst.erteile(user.id, abteilungId, bis),
        erfolg: 'Übungsrechte bis ${_fmtUhr(bis)} erteilt.',
        fehlerText: tempRechtFehlerText);
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String action,
      List<AbteilungInfo> abteilungen) async {
    switch (action) {
      case 'uebung':
        final meine = ref.read(meineMitgliedschaftenProvider).value;
        final kommandos = ref.read(meineKommandoGesamtwehrenProvider).value ??
            const <String>{};
        final ziel = _uebungsZiel(meine, kommandos, abteilungen);
        if (ziel == null) return;
        final laufend = ref
            .read(temporaereRechteDerAbteilungProvider(ziel))
            .value
            ?.where((r) => r.userId == user.id && r.laeuft)
            .firstOrNull;
        await _uebungsrechte(context, ref, ziel, laufend);
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
/// [erfolg] meldet den Vollzug — nötig überall dort, wo man das Ergebnis der
/// Liste nicht ansieht. [fehlerText] übersetzt die Absagen des Servers; ohne
/// ihn bleibt es beim technischen Wortlaut.
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  String? erfolg,
  String Function(Object)? fehlerText,
}) async {
  try {
    await action();
    if (erfolg != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erfolg)));
    }
  } catch (e) {
    if (context.mounted) {
      final text = fehlerText == null ? 'Fehlgeschlagen: $e' : fehlerText(e);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text)));
    }
  } finally {
    ref.invalidate(managedUsersProvider);
  }
}

/// Wie lange? Drei Vorgaben statt einer Zeitauswahl — im Gerätehaus tippt
/// niemand an einem Uhrzeit-Rad, und „bis Tagesende" deckt den Normalfall
/// (eine Übung an diesem Abend) vollständig ab.
class _UebungsrechteDialog extends StatefulWidget {
  final String name;
  const _UebungsrechteDialog({required this.name});

  @override
  State<_UebungsrechteDialog> createState() => _UebungsrechteDialogState();
}

class _UebungsrechteDialogState extends State<_UebungsrechteDialog> {
  /// Stunden ab jetzt; `null` = bis Tagesende (Zeitzone des Geräts).
  int? _stunden;

  DateTime get _bis => _stunden == null
      ? tagesendeAblauf()
      : DateTime.now().add(Duration(hours: _stunden!));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Übungsrechte erteilen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '„${widget.name}“ darf danach in dieser Abteilung Fahrzeuge, '
              'Fächer und Geräte anlegen und ändern — wie ein Gerätewart, '
              'aber befristet. Nutzer verwalten kann er weiterhin nicht.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            // Bewusst ListTiles statt RadioListTile: Letzteres ist seit
            // Flutter 3.32 zugunsten eines RadioGroup-Vorfahren abgekündigt,
            // und drei Zeilen Auswahl rechtfertigen den nicht.
            for (final wahl in const [
              (null, 'Bis Tagesende'),
              (2, 'Zwei Stunden'),
              (4, 'Vier Stunden'),
            ])
              ListTile(
                onTap: () => setState(() => _stunden = wahl.$1),
                title: Text(wahl.$2),
                leading: Icon(_stunden == wahl.$1
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            const SizedBox(height: 4),
            Text(
              'Läuft ab um ${_fmtUhr(_bis)}. Rechte wirken nur online — vor '
              'der Übung erteilen, nicht im Keller.',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _bis),
            child: const Text('Erteilen'),
          ),
        ],
      );
}

/// „18:00", bei einem anderen Tag mit Datum davor.
String _fmtUhr(DateTime t) {
  final uhr = '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
  final heute = DateTime.now();
  final gleicherTag =
      t.year == heute.year && t.month == heute.month && t.day == heute.day;
  return gleicherTag ? uhr : '${t.day}.${t.month}. $uhr';
}
