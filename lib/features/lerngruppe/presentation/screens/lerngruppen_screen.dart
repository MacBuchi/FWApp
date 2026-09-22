/// lerngruppen_screen.dart – Die eigenen Lerngruppen: gründen, mit Code
/// beitreten, laufende und beendete ansehen (Issue #136).
///
/// Die Kachel im Lernen-Raster ist IMMER da, auch im Lokalmodus und ohne
/// Gesamtwehr. Was fehlt, erklärt dieser Bildschirm — eine Kachel, die je
/// nach Konto auftaucht oder nicht, findet niemand wieder, wenn er sie
/// gerade braucht.
///
/// Noch ohne Wochenaufgabe und Ranking: Die kommen mit der Punktetabelle.
/// Bis dahin ist eine Gruppe „wer macht mit, und wie lange noch".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/gesamtwehr_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/lerngruppe/domain/lerngruppe.dart';
import 'package:fwapp/features/lerngruppe/presentation/providers/lerngruppe_providers.dart';

class LerngruppenScreen extends ConsumerWidget {
  const LerngruppenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lerngruppen')),
      body: _Inhalt(),
    );
  }
}

class _Inhalt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final session = ref.watch(sessionStreamProvider).value;
    if (client == null || session == null) {
      return const _Hinweis(
        icon: Icons.cloud_off,
        titel: 'Lerngruppen laufen über den Server der Wehr',
        text:
            'Melde dich mit deinem Konto an, dann kannst du eine Lerngruppe '
            'gründen oder mit einem Code beitreten. Alle Lernmodi '
            'funktionieren auch ohne.',
      );
    }

    final org = ref.watch(meineOrganisationProvider);
    return org.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _KeineGesamtwehr(),
      data: (o) {
        final gesamtwehrId = o?.gesamtwehrId;
        if (gesamtwehrId == null) return const _KeineGesamtwehr();
        return _Liste(gesamtwehrId: gesamtwehrId);
      },
    );
  }
}

class _KeineGesamtwehr extends StatelessWidget {
  const _KeineGesamtwehr();

  @override
  Widget build(BuildContext context) => const _Hinweis(
    icon: Icons.groups_outlined,
    titel: 'Lerngruppen gibt es innerhalb einer Gesamtwehr',
    text:
        'Deine Abteilung ist noch keiner Gesamtwehr angeschlossen. Das '
        'richtet ein Admin unter Einstellungen → Abteilung & Gesamtwehr ein.',
  );
}

class _Liste extends ConsumerWidget {
  final String gesamtwehrId;
  const _Liste({required this.gesamtwehrId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gruppen = ref.watch(meineLerngruppenProvider);
    final heute = DateTime.now();
    return gruppen.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(lerngruppeFehler(e))),
      data: (alle) {
        final sortiert = sortiereLerngruppen(alle, heute);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(meineLerngruppenProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (sortiert.isEmpty) ...[
                Text(
                  'Tu dich mit ein paar Leuten aus der Wehr für ein paar '
                  'Wochen zusammen. Wer die Gruppe gründet, bekommt einen '
                  'sechsstelligen Code — den gibst du weiter, und wer ihn '
                  'eintippt, ist dabei.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
              ],
              _Knoepfe(gesamtwehrId: gesamtwehrId),
              const SizedBox(height: 16),
              for (final g in sortiert)
                _GruppenKarte(gruppe: g, laeuft: g.laeuftAm(heute)),
            ],
          ),
        );
      },
    );
  }
}

class _Knoepfe extends ConsumerWidget {
  final String gesamtwehrId;
  const _Knoepfe({required this.gesamtwehrId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Gründen'),
          onPressed: () => _gruenden(context, ref),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.pin),
          label: const Text('Mit Code beitreten'),
          onPressed: () => _beitreten(context, ref),
        ),
      ],
    );
  }

  Future<void> _gruenden(BuildContext context, WidgetRef ref) async {
    final wahl = await showDialog<({String name, int wochen})>(
      context: context,
      builder: (_) => const _GruendenDialog(),
    );
    if (wahl == null || !context.mounted) return;
    await _fuehreAus(
      context,
      ref,
      (dienst) => dienst.gruende(
        gesamtwehrId: gesamtwehrId,
        name: wahl.name,
        wochen: wahl.wochen,
      ),
    );
  }

  Future<void> _beitreten(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _CodeDialog(),
    );
    if (code == null || !context.mounted) return;
    await _fuehreAus(context, ref, (dienst) => dienst.trittBei(code));
  }
}

/// Führt den Vorgang aus und öffnet danach die Gruppe — dort steht der Code
/// zum Weitergeben bzw. wer schon drin ist. Fehler landen in der Snackbar.
Future<void> _fuehreAus(
  BuildContext context,
  WidgetRef ref,
  Future<Lerngruppe> Function(LerngruppeService) vorgang,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final dienst = ref.read(lerngruppeServiceProvider);
  if (dienst == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Kein Server verbunden.')),
    );
    return;
  }
  try {
    final gruppe = await vorgang(dienst);
    if (context.mounted) context.push('/lerngruppen/${gruppe.id}');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(lerngruppeFehler(e))));
  }
}

class _GruppenKarte extends StatelessWidget {
  final Lerngruppe gruppe;
  final bool laeuft;
  const _GruppenKarte({required this.gruppe, required this.laeuft});

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    // Beendete Gruppen gedämpft statt versteckt: Wer dabei war, soll man
    // weiter sehen können — die Policy liefert sie ohnehin mit.
    return Opacity(
      opacity: laeuft ? 1 : 0.6,
      child: Card(
        child: ListTile(
          leading: Icon(
            laeuft ? Icons.groups : Icons.history,
            color: laeuft ? farben.primary : farben.onSurfaceVariant,
          ),
          title: Text(gruppe.name),
          subtitle: Text(gruppe.laufzeitText(DateTime.now())),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/lerngruppen/${gruppe.id}'),
        ),
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  final IconData icon;
  final String titel;
  final String text;
  const _Hinweis({required this.icon, required this.titel, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              titel,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Name und Laufzeit. Eigener StatefulWidget-Dialog wie `_NameDialog` in
/// gesamtwehr_screen.dart: Pop über den Dialog-Kontext, Controller stirbt
/// erst im dispose (die Ausblend-Animation rendert das Feld noch).
class _GruendenDialog extends StatefulWidget {
  const _GruendenDialog();

  @override
  State<_GruendenDialog> createState() => _GruendenDialogState();
}

class _GruendenDialogState extends State<_GruendenDialog> {
  final _name = TextEditingController();
  int _wochen = kLerngruppenStandardWochen;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _fertig() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, wochen: _wochen));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Lerngruppe gründen'),
    // Zwei Felder: ohne Scrollen überlappen auf kleinen Schirmen Knöpfe und
    // zweites Feld (AGENTS.md).
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Name der Gruppe',
              hintText: 'z. B. Truppmann-Lerngruppe Herbst',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _fertig(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _wochen,
            decoration: const InputDecoration(labelText: 'Laufzeit'),
            items: [
              for (final w in kLerngruppenLaufzeiten)
                DropdownMenuItem(value: w, child: Text('$w Wochen')),
            ],
            onChanged: (w) => setState(() => _wochen = w ?? _wochen),
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
        onPressed: _name.text.trim().isEmpty ? null : _fertig,
        child: const Text('Gründen'),
      ),
    ],
  );
}

/// Der Code wird hier schon geprüft: Sechs Ziffern kann die App selbst
/// zählen, dafür braucht es keinen Weg zum Server.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String? get _gueltig => normalisiereCode(_code.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mit Code beitreten'),
    content: TextField(
      controller: _code,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Beitrittscode',
        hintText: '123 456',
        helperText: 'Sechs Ziffern — bekommst du von jemandem aus der Gruppe',
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) {
        final code = _gueltig;
        if (code != null) Navigator.pop(context, code);
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed:
            _gueltig == null ? null : () => Navigator.pop(context, _gueltig),
        child: const Text('Beitreten'),
      ),
    ],
  );
}
