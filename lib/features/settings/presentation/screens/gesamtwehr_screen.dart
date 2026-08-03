/// gesamtwehr_screen.dart – Abteilung & Gesamtwehr (Issue #57 Phase 3).
///
/// Ein Screen für beide Seiten desselben Vorgangs: Die anfragende Abteilung
/// sieht hier ihren Antrag, die aufnehmende Gesamtwehr ihre Entscheidung.
/// Welche Hälfte erscheint, hängt allein daran, ob die eigene Abteilung schon
/// zu einer Gesamtwehr gehört — deshalb keine zwei Screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/branding_providers.dart';
import 'package:fwapp/core/sync/gesamtwehr_providers.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/rollen.dart';
import 'package:fwapp/core/sync/sync_providers.dart';

class GesamtwehrScreen extends ConsumerWidget {
  const GesamtwehrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisation = ref.watch(meineOrganisationProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abteilung & Gesamtwehr'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: () {
              ref.invalidate(meineOrganisationProvider);
              ref.invalidate(offeneAnfragenProvider);
              ref.invalidate(eigenerAntragProvider);
            },
          ),
        ],
      ),
      body: organisation.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Hinweis(
          icon: Icons.cloud_off,
          text: 'Die Abteilung konnte nicht geladen werden:\n'
              '${gesamtwehrFehlerText(e)}',
        ),
        data: (org) {
          if (org == null) {
            return const _Hinweis(
              icon: Icons.link_off,
              text: 'Dieser Server kennt noch keine Abteilungen. '
                  'Die Gesamtwehr gibt es erst ab Serverstand 1.5.5.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _AbteilungsKarte(org: org),
              if (!org.verbunden) _OhneKlammer(org: org, isAdmin: isAdmin),
              if (org.verbunden) _SchwesterAbteilungen(org: org),
              if (org.verbunden && isAdmin) ...[
                _WeitereAbteilung(org: org),
                const _OffeneAnfragen(),
              ],
              if (org.verbunden) const _KopfbereichKarte(),
              const SizedBox(height: 8),
              const _Erklaerung(),
            ],
          );
        },
      ),
    );
  }
}

class _AbteilungsKarte extends ConsumerWidget {
  final MeineOrganisation org;
  const _AbteilungsKarte({required this.org});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farben = Theme.of(context).colorScheme;
    final kommandiert = ref.watch(meineKommandoGesamtwehrenProvider).value;
    final darfAbteilung = darfAbteilungUmbenennen(
      abteilungId: org.abteilungId,
      gesamtwehrId: org.gesamtwehrId,
      mitgliedschaften: ref.watch(meineMitgliedschaftenProvider).value,
      kommandierteGesamtwehren: kommandiert,
    );
    // Die Wehr umbenennen darf nur ihr Feuerwehrkommandant — enger als die
    // Abteilung, aus demselben Grund wie beim Kopfbereich: Sonst ändert der
    // Kommandant der kleinsten Abteilung den Auftritt der ganzen Wehr.
    final darfWehr = org.gesamtwehrId != null &&
        (kommandiert?.contains(org.gesamtwehrId) ?? false);

    final wartet = org.freigegeben
        ? null
        : Chip(
            label: const Text('wartet'),
            backgroundColor: farben.tertiaryContainer,
          );

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.fire_truck),
            title: Text(org.abteilungName),
            subtitle: Text(org.freigegeben
                ? 'Deine Abteilung'
                : 'Deine Abteilung — noch nicht freigegeben'),
            trailing: _Anhang(
              chip: wartet,
              stift: darfAbteilung
                  ? _Stift(
                      tooltip: 'Abteilung umbenennen',
                      onTap: () => _benenneAbteilungUm(
                          context, ref, org.abteilungId, org.abteilungName),
                    )
                  : null,
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.account_tree),
            title: Text(org.gesamtwehrName ?? 'Keiner Gesamtwehr angeschlossen'),
            subtitle: Text(org.verbunden
                ? 'Gesamtwehr — ihre Abteilungen sehen einander lesend'
                : 'Die Abteilung arbeitet eigenständig'),
            trailing: darfWehr
                ? _Stift(
                    tooltip: 'Gesamtwehr umbenennen',
                    onTap: () => _benenneWehrUm(context, ref, org.gesamtwehrId!,
                        org.gesamtwehrName ?? ''),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Die Schwestern derselben Gesamtwehr — nur für den, der sie auch umbenennen
/// darf. Ohne diese Karte käme der Feuerwehrkommandant an alles außer der
/// eigenen Abteilung nicht heran: Der Rest des Screens zeigt immer nur die
/// Heimat-Abteilung aus dem Profil, nicht die gewählte.
class _SchwesterAbteilungen extends ConsumerWidget {
  final MeineOrganisation org;
  const _SchwesterAbteilungen({required this.org});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kommandiert = ref.watch(meineKommandoGesamtwehrenProvider).value;
    final mitgliedschaften = ref.watch(meineMitgliedschaftenProvider).value;
    final alle = ref.watch(abteilungenProvider).value ?? const [];
    final schwestern = [
      for (final a in alle)
        if (a.id != org.abteilungId && a.gesamtwehrId == org.gesamtwehrId)
          a,
    ];
    final benennbar = [
      for (final a in schwestern)
        if (darfAbteilungUmbenennen(
          abteilungId: a.id,
          gesamtwehrId: a.gesamtwehrId,
          mitgliedschaften: mitgliedschaften,
          kommandierteGesamtwehren: kommandiert,
        ))
          a,
    ];
    if (benennbar.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Weitere Abteilungen der Gesamtwehr',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final a in benennbar)
            ListTile(
              leading: const Icon(Icons.fire_truck_outlined),
              title: Text(a.name),
              trailing: _Stift(
                tooltip: 'Abteilung umbenennen',
                onTap: () => _benenneAbteilungUm(context, ref, a.id, a.name),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stift extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  const _Stift({required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: tooltip,
        onPressed: onTap,
      );
}

/// Chip und Stift nebeneinander, ohne dass eines von beiden ein leeres
/// `Row` erzwingt — `trailing: null` lässt der ListTile ihren Platz.
class _Anhang extends StatelessWidget {
  final Widget? chip;
  final Widget? stift;
  const _Anhang({this.chip, this.stift});

  @override
  Widget build(BuildContext context) {
    if (chip == null) return stift ?? const SizedBox.shrink();
    if (stift == null) return chip!;
    return Row(mainAxisSize: MainAxisSize.min, children: [chip!, stift!]);
  }
}

Future<void> _benenneAbteilungUm(
  BuildContext context,
  WidgetRef ref,
  String id,
  String bisher,
) async {
  final name = await _frageName(
    context,
    titel: 'Abteilung umbenennen',
    feld: 'Name der Abteilung',
    beispiel: 'z. B. 02 - Babstadt',
    vorbelegt: bisher,
    knopf: 'Umbenennen',
  );
  if (name == null || name == bisher || !context.mounted) return;
  await _fuehreAus(context, ref, 'Heißt jetzt „$name".',
      (dienst) => dienst.benenneAbteilungUm(id, name));
}

Future<void> _benenneWehrUm(
  BuildContext context,
  WidgetRef ref,
  String id,
  String bisher,
) async {
  final name = await _frageName(
    context,
    titel: 'Gesamtwehr umbenennen',
    feld: 'Name der Gesamtwehr',
    beispiel: 'z. B. Freiwillige Feuerwehr Musterstadt',
    vorbelegt: bisher,
    knopf: 'Umbenennen',
  );
  if (name == null || name == bisher || !context.mounted) return;
  await _fuehreAus(context, ref, 'Heißt jetzt „$name".',
      (dienst) => dienst.benenneGesamtwehrUm(id, name));
}

/// Die Seite ohne Klammer: gründen oder beitreten — oder warten.
class _OhneKlammer extends ConsumerWidget {
  final MeineOrganisation org;
  final bool isAdmin;
  const _OhneKlammer({required this.org, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final antrag = ref.watch(eigenerAntragProvider).value;

    if (antrag != null && antrag.laeuft) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.hourglass_top),
          title: const Text('Antrag läuft'),
          subtitle: const Text(
              'Die Gesamtwehr muss den Anschluss noch bestätigen. '
              'Bis dahin arbeitet die Abteilung normal weiter.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          if (antrag != null && antrag.status == 'rejected')
            ListTile(
              leading: Icon(Icons.info_outline,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Der letzte Antrag wurde abgelehnt'),
              subtitle: Text(antrag.antwort ?? 'Ohne Begründung.'),
            ),
          if (isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.add_home_work),
              title: const Text('Gesamtwehr gründen'),
              subtitle: const Text(
                  'Die Klammer über mehrere Abteilungen — deine wird das '
                  'erste Mitglied'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _gruenden(context, ref),
            ),
            const Divider(indent: 16, endIndent: 16),
          ],
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('Anschluss beantragen'),
            subtitle: const Text(
                'An eine bestehende Gesamtwehr — deren Admin entscheidet'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _beantragen(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _gruenden(BuildContext context, WidgetRef ref) async {
    final name = await _frageName(
      context,
      titel: 'Gesamtwehr gründen',
      feld: 'Name der Gesamtwehr',
      beispiel: 'z. B. Gesamtfeuerwehr Musterstadt',
    );
    if (name == null || !context.mounted) return;
    await _fuehreAus(context, ref, 'Gesamtwehr „$name" gegründet.',
        (dienst) => dienst.gruendeGesamtwehr(name));
  }

  Future<void> _beantragen(BuildContext context, WidgetRef ref) async {
    final wehren = await ref.read(gesamtwehrenProvider.future);
    if (!context.mounted) return;
    if (wehren.isEmpty) {
      _melde(context, 'Auf diesem Server gibt es noch keine Gesamtwehr.');
      return;
    }
    final wahl = await showDialog<({String id, String nachricht})>(
      context: context,
      builder: (_) => _AntragDialog(wehren: wehren),
    );
    if (wahl == null || !context.mounted) return;
    await _fuehreAus(context, ref, 'Antrag gestellt.',
        (dienst) => dienst.beantrageVerbindung(wahl.id,
            nachricht: wahl.nachricht));
  }
}

class _WeitereAbteilung extends ConsumerWidget {
  final MeineOrganisation org;
  const _WeitereAbteilung({required this.org});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: ListTile(
          leading: const Icon(Icons.add_business),
          title: const Text('Weitere Abteilung anlegen'),
          subtitle: Text('In „${org.gesamtwehrName ?? 'deiner Gesamtwehr'}" — '
              'sofort einsatzbereit, du bürgst als Admin dafür'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final name = await _frageName(
              context,
              titel: 'Abteilung anlegen',
              feld: 'Name der Abteilung',
              beispiel: 'z. B. Abteilung Nord',
            );
            if (name == null || !context.mounted) return;
            await _fuehreAus(context, ref, 'Abteilung „$name" angelegt.',
                (dienst) => dienst.legeAbteilungAn(name));
          },
        ),
      );
}

/// Einstieg in die Branding-Pflege (#57 P5). Nur für den Feuerwehrkommandanten
/// dieser Wehr — enger als der übrige Screen, der auch Gerätewarten offensteht.
class _KopfbereichKarte extends ConsumerWidget {
  const _KopfbereichKarte();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref.watch(darfBrandingPflegenProvider).value ?? false)) {
      return const SizedBox.shrink();
    }
    final gepflegt =
        !(ref.watch(gesamtwehrBrandingProvider).value?.istLeer ?? true);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.photo_size_select_actual_outlined),
        title: const Text('Kopfbereich der Startseite'),
        subtitle: Text(gepflegt
            ? 'Bild und Begrüßung — sehen alle Abteilungen'
            : 'Noch nicht eingerichtet — Bild und Begrüßung für alle '
                'Abteilungen'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/gesamtwehr/kopfbereich'),
      ),
    );
  }
}

class _OffeneAnfragen extends ConsumerWidget {
  const _OffeneAnfragen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anfragen = ref.watch(offeneAnfragenProvider).value ?? const [];
    if (anfragen.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Offene Anfragen',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final a in anfragen)
            ListTile(
              leading: const Icon(Icons.mark_email_unread),
              title: Text(a.abteilungName),
              subtitle: Text(a.nachricht ?? 'Möchte sich anschließen.'),
              isThreeLine: a.nachricht != null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Ablehnen',
                    onPressed: () => _entscheiden(context, ref, a, false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: 'Freigeben',
                    onPressed: () => _entscheiden(context, ref, a, true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _entscheiden(BuildContext context, WidgetRef ref,
      VerbindungsAnfrage a, bool freigeben) async {
    // Pop über den Dialog-Kontext, siehe _frageName.
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(freigeben ? 'Anschluss freigeben?' : 'Antrag ablehnen?'),
        content: Text(freigeben
            ? '„${a.abteilungName}" wird Teil deiner Gesamtwehr. Beide '
                'Abteilungen können danach den Bestand der jeweils anderen '
                'lesen — bearbeiten weiterhin nur die eigene.'
            : '„${a.abteilungName}" bleibt eigenständig. Ein neuer Antrag '
                'ist jederzeit möglich.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(freigeben ? 'Freigeben' : 'Ablehnen'),
          ),
        ],
      ),
    );
    if (bestaetigt != true || !context.mounted) return;
    await _fuehreAus(
      context,
      ref,
      freigeben
          ? '„${a.abteilungName}" ist jetzt Teil der Gesamtwehr.'
          : 'Antrag abgelehnt.',
      (dienst) => dienst.entscheide(a.id, freigeben: freigeben),
    );
  }
}

class _AntragDialog extends StatefulWidget {
  final List<GesamtwehrInfo> wehren;
  const _AntragDialog({required this.wehren});

  @override
  State<_AntragDialog> createState() => _AntragDialogState();
}

class _AntragDialogState extends State<_AntragDialog> {
  late String _gewaehlt = widget.wehren.first.id;
  final _nachricht = TextEditingController();

  @override
  void dispose() {
    _nachricht.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Anschluss beantragen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _gewaehlt,
              decoration: const InputDecoration(labelText: 'Gesamtwehr'),
              items: [
                for (final w in widget.wehren)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _gewaehlt = v ?? _gewaehlt),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nachricht,
              decoration: const InputDecoration(
                labelText: 'Nachricht (optional)',
                hintText: 'Wer ihr seid, wer angefragt hat',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, (id: _gewaehlt, nachricht: _nachricht.text)),
            child: const Text('Antrag stellen'),
          ),
        ],
      );
}

class _Erklaerung extends StatelessWidget {
  const _Erklaerung();

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Jede Abteilung führt ihren eigenen Bestand und veröffentlicht ihn '
            'selbst. Die Gesamtwehr verbindet mehrere Abteilungen: Sie sehen '
            'den Bestand der anderen, ändern können sie ihn nicht. Nur der '
            'Admin der Gesamtwehr darf überall bearbeiten.',
          ),
        ),
      );
}

class _Hinweis extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hinweis({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

// ── Gemeinsame Helfer ─────────────────────────────────────────────────────

Future<String?> _frageName(
  BuildContext context, {
  required String titel,
  required String feld,
  required String beispiel,
  String vorbelegt = '',
  String knopf = 'Anlegen',
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      titel: titel,
      feld: feld,
      beispiel: beispiel,
      vorbelegt: vorbelegt,
      knopf: knopf,
    ),
  );
  final sauber = name?.trim();
  return (sauber == null || sauber.isEmpty) ? null : sauber;
}

/// Eigener StatefulWidget-Dialog aus zwei im Feld gelernten Gründen
/// (v1.6.0): Der Pop muss über den Dialog-eigenen Kontext laufen — der
/// Screen hängt im verschachtelten Navigator der Shell-Route, der Dialog im
/// Root-Navigator; über den Screen-Kontext trifft der Pop den falschen
/// Navigator und „Anlegen" tut sichtbar nichts. Und der Controller darf
/// erst im State-dispose sterben, nicht direkt nach showDialog — die
/// Ausblend-Animation rendert das Textfeld noch.
class _NameDialog extends StatefulWidget {
  final String titel;
  final String feld;
  final String beispiel;
  final String vorbelegt;
  final String knopf;
  const _NameDialog({
    required this.titel,
    required this.feld,
    required this.beispiel,
    this.vorbelegt = '',
    this.knopf = 'Anlegen',
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _steuerung = TextEditingController(text: widget.vorbelegt)
    // Beim Umbenennen steht der alte Name schon da; der Cursor gehört ans
    // Ende, sonst tippt man beim ersten Zeichen mitten hinein.
    ..selection = TextSelection.collapsed(offset: widget.vorbelegt.length);

  @override
  void dispose() {
    _steuerung.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.titel),
        content: TextField(
          controller: _steuerung,
          autofocus: true,
          decoration: InputDecoration(
              labelText: widget.feld, hintText: widget.beispiel),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _steuerung.text),
            child: Text(widget.knopf),
          ),
        ],
      );
}

/// Führt einen Vorgang aus und meldet das Ergebnis — Erfolg wie Fehler landen
/// beide in derselben Snackbar, damit kein Vorgang stumm bleibt.
Future<void> _fuehreAus(
  BuildContext context,
  WidgetRef ref,
  String erfolg,
  Future<void> Function(GesamtwehrService) vorgang,
) async {
  final dienst = ref.read(gesamtwehrServiceProvider);
  if (dienst == null) {
    _melde(context, 'Kein Server verbunden.');
    return;
  }
  try {
    await vorgang(dienst);
    if (context.mounted) _melde(context, erfolg);
  } catch (e) {
    if (context.mounted) _melde(context, gesamtwehrFehlerText(e));
  }
}

void _melde(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));
}
