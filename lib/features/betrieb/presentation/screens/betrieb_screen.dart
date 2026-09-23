/// betrieb_screen.dart – Konsole des KreisDatenMeisters (Issue #101):
/// alle Gesamtwehren der Installation, anlegen, Kommandant hinzufügen,
/// stilllegen.
///
/// Erreichbar über Einstellungen → „KreisDatenMeister", und den Eintrag
/// sieht nur, wer es ist. Das ist Komfort: Der Schutz steckt in
/// `ist_betreiber()` in jeder Server-Funktion (AGENTS.md: Sicherheit liegt
/// in RLS, nie im Client). Wer die Route von Hand öffnet, sieht deshalb nur
/// einen Hinweis — und bekäme vom Server ohnehin nichts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/betrieb/domain/betrieb.dart';
import 'package:fwapp/features/betrieb/presentation/providers/betrieb_providers.dart';

class BetriebScreen extends ConsumerWidget {
  const BetriebScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darf = ref.watch(istBetreiberProvider);
    final ja = darf.value == true;
    return Scaffold(
      appBar: AppBar(title: const Text('KreisDatenMeister')),
      floatingActionButton:
          ja
              ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Wehr anlegen'),
                onPressed: () => _anlegen(context, ref),
              )
              : null,
      body:
          darf.isLoading && !darf.hasValue
              ? const Center(child: CircularProgressIndicator())
              : !ja
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Diese Seite ist dem KreisDatenMeister dieser Installation '
                    'vorbehalten.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : const _Liste(),
    );
  }

  Future<void> _anlegen(BuildContext context, WidgetRef ref) async {
    final eingabe = await showDialog<_Anlage>(
      context: context,
      builder: (_) => const _AnlegenDialog(),
    );
    if (eingabe == null || !context.mounted) return;
    await _fuehreAus(context, ref, (d) async {
      await d.legeWehrAn(
        wehr: eingabe.wehr,
        abteilung: eingabe.abteilung,
        kommandantMail: eingabe.mail,
        kommandantName: eingabe.name,
      );
      return '„${eingabe.wehr}" angelegt, Einladung an ${eingabe.mail} '
          'ist raus.';
    });
  }
}

class _Liste extends ConsumerWidget {
  const _Liste();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wehren = ref.watch(kdmGesamtwehrenProvider);
    return wehren.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(betriebFehlerText(e), textAlign: TextAlign.center),
            ),
          ),
      data:
          (liste) => RefreshIndicator(
            onRefresh: () => ref.refresh(kdmGesamtwehrenProvider.future),
            child: ListView(
              // Unten Platz für den FAB, sonst verdeckt er die letzte Karte.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  liste.length == 1
                      ? '1 Gesamtwehr auf dieser Installation'
                      : '${liste.length} Gesamtwehren auf dieser Installation',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                // Beim ersten Durchklick stand hier „0 Gesamtwehren", obwohl
                // es eine Abteilung gab — sie hing an keiner Gesamtwehr. Das
                // ist korrekt (die Konsole verwaltet Gesamtwehren), muss aber
                // dastehen, sonst sucht man einen Fehler.
                Text(
                  'Abteilungen ohne Gesamtwehr stehen hier nicht.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final w in liste) _WehrKarte(wehr: w),
              ],
            ),
          ),
    );
  }
}

class _WehrKarte extends ConsumerWidget {
  final KdmWehr wehr;
  const _WehrKarte({required this.wehr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    final warnung = wehr.warnung;
    final abt = wehr.abteilungen.length;
    return Card(
      color: wehr.stillgelegt ? farben.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(wehr.name, style: theme.textTheme.titleMedium),
                ),
                if (wehr.stillgelegt)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Chip(label: Text('stillgelegt')),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Aktionen',
                  onSelected:
                      (wahl) => switch (wahl) {
                        'kommandant' => _kommandant(context, ref),
                        _ => _stilllegen(context, ref),
                      },
                  itemBuilder:
                      (_) => [
                        if (!wehr.stillgelegt && wehr.abteilungen.isNotEmpty)
                          const PopupMenuItem(
                            value: 'kommandant',
                            child: Text('Kommandant hinzufügen'),
                          ),
                        PopupMenuItem(
                          value: 'still',
                          child: Text(
                            wehr.stillgelegt ? 'Reaktivieren' : 'Stilllegen',
                          ),
                        ),
                      ],
                ),
              ],
            ),
            Text(
              '${abt == 1 ? '1 Abteilung' : '$abt Abteilungen'} · '
              '${wehr.mitglieder} Mitglieder · '
              '${veroeffentlichtText(wehr.zuletztVeroeffentlicht)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              wehr.kommandanten.isEmpty
                  ? 'Kommandant: —'
                  : 'Kommandant: ${[for (final k in wehr.kommandanten) k.email == null ? k.name : '${k.name} (${k.email})'].join(', ')}',
            ),
            if (wehr.offeneEinladungen > 0)
              Text(
                wehr.offeneEinladungen == 1
                    ? '1 offene Einladung'
                    : '${wehr.offeneEinladungen} offene Einladungen',
                style: theme.textTheme.bodySmall,
              ),
            if (warnung != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      warnung.dringend
                          ? Icons.error_outline
                          : Icons.warning_amber,
                      size: 18,
                      color: warnung.dringend ? farben.error : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        warnung.text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: warnung.dringend ? farben.error : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _kommandant(BuildContext context, WidgetRef ref) async {
    final eingabe = await showDialog<_NeuerKommandant>(
      context: context,
      builder: (_) => _KommandantDialog(wehr: wehr),
    );
    if (eingabe == null || !context.mounted) return;
    await _fuehreAus(context, ref, (d) async {
      final weg = await d.fuegeKommandantHinzu(
        gesamtwehrId: wehr.id,
        abteilungId: eingabe.abteilungId,
        mail: eingabe.mail,
        name: eingabe.name,
      );
      return switch (weg) {
        KommandantWeg.ernannt =>
          '${eingabe.mail} ist jetzt Feuerwehrkommandant von „${wehr.name}".',
        KommandantWeg.eingeladen =>
          'Zu ${eingabe.mail} gibt es noch kein Konto — Einladung als '
              'Feuerwehrkommandant ist raus.',
      };
    });
  }

  Future<void> _stilllegen(BuildContext context, WidgetRef ref) async {
    final still = !wehr.stillgelegt;
    final ja = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: Text(still ? '„${wehr.name}" stilllegen?' : 'Reaktivieren?'),
            content: Text(
              still
                  ? 'Danach kann niemand in dieser Wehr mehr veröffentlichen, '
                      'einladen oder Wissensfragen einreichen. Nachschlagen und '
                      'Lernen gehen weiter, und es wird nichts gelöscht — die '
                      'Daten auf den Handys bleiben erhalten. Rückgängig über '
                      '„Reaktivieren".'
                  : 'Danach kann die Wehr wieder veröffentlichen und einladen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(still ? 'Stilllegen' : 'Reaktivieren'),
              ),
            ],
          ),
    );
    if (ja != true || !context.mounted) return;
    await _fuehreAus(context, ref, (d) async {
      await d.setzeStillgelegt(wehr.id, still);
      return still
          ? '„${wehr.name}" ist stillgelegt.'
          : '„${wehr.name}" ist wieder aktiv.';
    });
  }
}

/// Führt einen Vorgang aus; Erfolg wie Fehler landen in derselben Snackbar,
/// damit kein Vorgang stumm bleibt.
Future<void> _fuehreAus(
  BuildContext context,
  WidgetRef ref,
  Future<String> Function(BetriebService) vorgang,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final dienst = ref.read(betriebServiceProvider);
  if (dienst == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Kein Server verbunden.')),
    );
    return;
  }
  try {
    final text = await vorgang(dienst);
    messenger.showSnackBar(SnackBar(content: Text(text)));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(betriebFehlerText(e)),
        duration: const Duration(seconds: 8),
      ),
    );
  }
}

typedef _Anlage = ({String wehr, String abteilung, String mail, String? name});
typedef _NeuerKommandant = ({String abteilungId, String mail, String? name});

bool _mailSiehtGutAus(String s) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(s.trim());

/// Vier Felder — ohne Scrollen überlappen auf kleinen Schirmen Knöpfe und
/// Felder (AGENTS.md). Eigener StatefulWidget-Dialog: Pop über den
/// Dialog-Kontext, Controller sterben erst im dispose.
class _AnlegenDialog extends StatefulWidget {
  const _AnlegenDialog();

  @override
  State<_AnlegenDialog> createState() => _AnlegenDialogState();
}

class _AnlegenDialogState extends State<_AnlegenDialog> {
  final _wehr = TextEditingController();
  final _abteilung = TextEditingController();
  final _mail = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    for (final c in [_wehr, _abteilung, _mail, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _fertig =>
      _wehr.text.trim().isNotEmpty &&
      _abteilung.text.trim().isNotEmpty &&
      _mailSiehtGutAus(_mail.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Wehr anlegen'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _wehr,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name der Gesamtwehr',
              hintText: 'z. B. Feuerwehr Musterstadt',
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _abteilung,
            decoration: const InputDecoration(
              labelText: 'Erste Abteilung',
              hintText: 'z. B. Abteilung Mitte',
              helperText: 'Weitere legt der Kommandant selbst an.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Mail des Feuerwehrkommandanten',
              helperText: 'Er bekommt eine Einladung mit Code.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Sein Name (optional)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed:
            _fertig
                ? () => Navigator.pop(context, (
                  wehr: _wehr.text.trim(),
                  abteilung: _abteilung.text.trim(),
                  mail: _mail.text.trim(),
                  name: _name.text.trim().isEmpty ? null : _name.text.trim(),
                ))
                : null,
        child: const Text('Anlegen und einladen'),
      ),
    ],
  );
}

class _KommandantDialog extends StatefulWidget {
  final KdmWehr wehr;
  const _KommandantDialog({required this.wehr});

  @override
  State<_KommandantDialog> createState() => _KommandantDialogState();
}

class _KommandantDialogState extends State<_KommandantDialog> {
  final _mail = TextEditingController();
  final _name = TextEditingController();
  late String _abteilung = widget.wehr.abteilungen.first.id;

  @override
  void dispose() {
    _mail.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kommandant hinzufügen'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Hat die Adresse schon ein Konto, wird die Person sofort '
            'Feuerwehrkommandant. Sonst bekommt sie eine Einladung.',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _mail,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Mail-Adresse'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name (optional, nur für die Einladung)',
            ),
          ),
          // Nur für den Einladungsweg nötig — eine Einladung hängt immer an
          // einer Abteilung. Bei einer einzigen gibt es nichts zu wählen.
          if (widget.wehr.abteilungen.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _abteilung,
              decoration: const InputDecoration(
                labelText: 'Abteilung (für eine Einladung)',
              ),
              items: [
                for (final a in widget.wehr.abteilungen)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _abteilung = v ?? _abteilung),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed:
            _mailSiehtGutAus(_mail.text)
                ? () => Navigator.pop(context, (
                  abteilungId: _abteilung,
                  mail: _mail.text.trim(),
                  name: _name.text.trim().isEmpty ? null : _name.text.trim(),
                ))
                : null,
        child: const Text('Hinzufügen'),
      ),
    ],
  );
}
