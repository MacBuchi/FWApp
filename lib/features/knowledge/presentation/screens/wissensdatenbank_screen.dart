/// wissensdatenbank_screen.dart – Die Wissensdatenbank ansehen, ergänzen und
/// freigeben (Issue #174).
///
/// **Drei Leute schauen hier hinein, und sie wollen Verschiedenes:** Wer
/// lernt, will wissen, was es an Stoff gibt. Wer eine gute Frage im Kopf hat,
/// will sie loswerden. Wer Gerätewart ist, will sehen, was auf ihn wartet.
/// Deshalb steht der Freigabe-Stapel oben und nicht in einem Untermenü — was
/// niemand sieht, gibt niemand frei.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';
import 'package:fwapp/features/knowledge/presentation/widgets/frage_formular.dart';

class WissensdatenbankScreen extends ConsumerStatefulWidget {
  const WissensdatenbankScreen({super.key});

  @override
  ConsumerState<WissensdatenbankScreen> createState() =>
      _WissensdatenbankScreenState();
}

class _WissensdatenbankScreenState
    extends ConsumerState<WissensdatenbankScreen> {
  Wissensgebiet? _gebiet;

  @override
  Widget build(BuildContext context) {
    final alleAsync = ref.watch(wissensfragenProvider);
    final darfFreigeben = ref.watch(canEditProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wissensdatenbank'),
        actions: const [AbteilungAction()],
      ),
      // Einreichen darf jeder mit Konto — das war die ausdrückliche Vorgabe.
      // Kein Rechte-Gate am Knopf, das Gate sitzt bei der Freigabe.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formularOeffnen(darfFreigeben: darfFreigeben),
        icon: const Icon(Icons.add),
        label: const Text('Frage einreichen'),
      ),
      body: alleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (alle) => _inhalt(alle, darfFreigeben),
      ),
    );
  }

  Widget _inhalt(List<WissensfrageData> alle, bool darfFreigeben) {
    final offen = alle
        .where((f) => f.stand == Fragenstand.eingereicht.schluessel)
        .toList();
    final freigegeben = alle
        .where((f) => f.stand == Fragenstand.freigegeben.schluessel)
        .where((f) => _gebiet == null || f.gebiet == _gebiet!.schluessel)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (offen.isNotEmpty) ...[
          _ueberschrift(darfFreigeben
              ? '${offen.length} wartet auf deine Freigabe'
              : '${offen.length} eingereicht, wartet auf Freigabe'),
          ...offen.map((f) => _zeile(f, darfFreigeben, offen: true)),
          const Divider(height: 32),
        ],
        _gebietsfilter(alle),
        if (freigegeben.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _gebiet == null
                  ? 'Noch keine freigegebenen Fragen.'
                  : 'In „${_gebiet!.label}" ist noch nichts freigegeben. '
                      'Du kannst die erste Frage beisteuern.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...freigegeben.map((f) => _zeile(f, darfFreigeben)),
      ],
    );
  }

  Widget _ueberschrift(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  /// Die Gebiete mit ihrer Anzahl. Leere Gebiete bleiben sichtbar — sie sind
  /// die Einladung, dort etwas beizusteuern, und eine Lücke, die man nicht
  /// sieht, füllt niemand.
  Widget _gebietsfilter(List<WissensfrageData> alle) {
    final zaehlung = <String, int>{};
    for (final f in alle) {
      if (f.stand != Fragenstand.freigegeben.schluessel) continue;
      zaehlung[f.gebiet] = (zaehlung[f.gebiet] ?? 0) + 1;
    }
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          FilterChip(
            label: Text('Alle (${zaehlung.values.fold(0, (a, b) => a + b)})'),
            selected: _gebiet == null,
            onSelected: (_) => setState(() => _gebiet = null),
          ),
          for (final g in Wissensgebiet.values) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text('${g.symbol} ${g.label} (${zaehlung[g.schluessel] ?? 0})'),
              selected: _gebiet == g,
              onSelected: (_) => setState(() => _gebiet = g),
            ),
          ],
        ],
      ),
    );
  }

  Widget _zeile(WissensfrageData z, bool darfFreigeben,
      {bool offen = false}) {
    final f = zuWissensfrage(z);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Text(f.gebiet.symbol, style: const TextStyle(fontSize: 22)),
        title: Text(f.frage,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          f.gebiet.label,
          if (f.herkunft == Fragenherkunft.mitgeliefert) 'mitgeliefert',
          if (f.eingereichtVon != null) 'von ${f.eingereichtVon}',
        ].join(' · '), style: theme.textTheme.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < f.antworten.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          i == f.richtig
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: i == f.richtig
                              ? Colors.green.shade700
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f.antworten[i])),
                      ],
                    ),
                  ),
                if (f.erklaerung != null) ...[
                  const SizedBox(height: 8),
                  Text(f.erklaerung!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 8),
                _aktionen(z, f, darfFreigeben, offen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aktionen(
      WissensfrageData z, Wissensfrage f, bool darfFreigeben, bool offen) {
    if (offen && darfFreigeben) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => setzeStand(ref, z, Fragenstand.abgelehnt),
            child: const Text('Ablehnen'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => setzeStand(ref, z, Fragenstand.freigegeben),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Freigeben'),
          ),
        ],
      );
    }
    if (offen) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('Wartet auf den Gerätewart.',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    if (!darfFreigeben || !f.loeschbar) {
      // Mitgeliefertes ist nicht löschbar — es käme beim nächsten Start
      // ohnehin wieder, und ein Knopf, der nichts bewirkt, ist schlimmer
      // als keiner.
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => _entfernenBestaetigen(z, f),
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text('Entfernen'),
      ),
    );
  }

  Future<void> _entfernenBestaetigen(
      WissensfrageData z, Wissensfrage f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Frage entfernen?'),
        content: Text('„${f.frage}" wird aus der Wissensdatenbank der '
            'Gesamtwehr entfernt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Entfernen')),
        ],
      ),
    );
    if (ok == true && mounted) await entferneFrage(ref, z);
  }

  Future<void> _formularOeffnen({required bool darfFreigeben}) async {
    final eingabe = await showDialog<FrageEingabe>(
      context: context,
      builder: (_) => FrageFormular(vorgabe: _gebiet),
    );
    if (eingabe == null || !mounted) return;

    await reicheFrageEin(
      ref,
      gebiet: eingabe.gebiet,
      frage: eingabe.frage,
      antworten: eingabe.antworten,
      richtig: eingabe.richtig,
      erklaerung: eingabe.erklaerung,
      // Wer freigeben darf, muss sich nicht selbst genehmigen.
      sofortFreigeben: darfFreigeben,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(darfFreigeben
            ? 'Frage aufgenommen — sie ist ab sofort im Spiel.'
            : 'Danke! Der Gerätewart schaut sie sich an.')));
  }
}
