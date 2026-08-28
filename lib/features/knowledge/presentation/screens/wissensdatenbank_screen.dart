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
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';
import 'package:fwapp/features/knowledge/presentation/widgets/frage_formular.dart';
import 'package:fwapp/features/knowledge/presentation/widgets/quellen_zeile.dart';

class WissensdatenbankScreen extends ConsumerStatefulWidget {
  const WissensdatenbankScreen({super.key});

  @override
  ConsumerState<WissensdatenbankScreen> createState() =>
      _WissensdatenbankScreenState();
}

class _WissensdatenbankScreenState
    extends ConsumerState<WissensdatenbankScreen> {
  Wissensgebiet? _gebiet;

  /// Gewähltes Unterkapitel. Nur sichtbar, solange ein Gebiet gewählt ist —
  /// Kapitel gehören zu einem Gebiet und wären quer darüber sinnlos.
  String? _kapitel;

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
        .where((f) => _kapitel == null || f.kapitel == _kapitel)
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
        _kapitelfilter(alle),
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
            onSelected: (_) => setState(() {
              _gebiet = null;
              _kapitel = null;
            }),
          ),
          for (final g in Wissensgebiet.values) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text('${g.symbol} ${g.label} (${zaehlung[g.schluessel] ?? 0})'),
              selected: _gebiet == g,
              // ⚠️ Das Kapitel muss mit: Ein „Dekontamination"-Filter, der
              // nach dem Wechsel zu „Funk" stehen bleibt, zeigt eine leere
              // Liste, und der Grund dafür steht am anderen Ende des
              // Schirms.
              onSelected: (_) => setState(() {
                _gebiet = g;
                _kapitel = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  /// Die Unterkapitel des gewählten Gebiets, mit Anzahl.
  ///
  /// Erst ab zwei Kapiteln sichtbar: Ein einzelner Knopf, der nichts
  /// eingrenzt, ist kein Filter, sondern Beschriftung. Ohne gewähltes Gebiet
  /// bleibt die Zeile ganz weg — quer über alle Gebiete stünden „Dekon" und
  /// „Gefahrzettel" neben Sachgebieten, zu denen sie nicht gehören.
  Widget _kapitelfilter(List<WissensfrageData> alle) {
    if (_gebiet == null) return const SizedBox.shrink();
    final zaehlung = <String, int>{};
    for (final f in alle) {
      if (f.stand != Fragenstand.freigegeben.schluessel) continue;
      if (f.gebiet != _gebiet!.schluessel) continue;
      final k = f.kapitel;
      if (k != null) zaehlung[k] = (zaehlung[k] ?? 0) + 1;
    }
    if (zaehlung.length < 2) return const SizedBox.shrink();

    final namen = zaehlung.keys.toList()..sort();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          ChoiceChip(
            label: const Text('Alle Kapitel'),
            selected: _kapitel == null,
            onSelected: (_) => setState(() => _kapitel = null),
          ),
          for (final k in namen) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('$k (${zaehlung[k]})'),
              selected: _kapitel == k,
              onSelected: (_) => setState(() => _kapitel = k),
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
          if (f.kapitel != null) f.kapitel!,
          // Landesrecht wird benannt, Bundesweites nicht — was überall gilt,
          // braucht keinen Hinweis, was nur hier gilt schon.
          if (f.geltung == Geltungsbereich.land) f.geltungAnzeige,
          if (f.herkunft == Fragenherkunft.mitgeliefert) 'mitgeliefert',
          if (f.eingereichtVon != null) 'von ${f.eingereichtVon}',
        ].join(' · '), style: theme.textTheme.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bei einem Gefahrzettel IST das Bild die Frage — ohne es
                // steht da „Welche Gefahr zeigt dieser Gefahrzettel an?"
                // ohne den Gefahrzettel.
                if (f.bildPfad != null) ...[
                  Center(
                    child: resolveImage(
                      path: f.bildPfad,
                      height: 140,
                      backgroundColor: null,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                for (var i = 0; i < f.antworten.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          f.richtige.contains(i)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                          color: f.richtige.contains(i)
                              ? Colors.green.shade700
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f.antworten[i])),
                      ],
                    ),
                  ),
                if (f.richtige.length > 1) ...[
                  const SizedBox(height: 6),
                  Text('${f.richtige.length} Antworten sind richtig.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
                if (f.erklaerung != null) ...[
                  const SizedBox(height: 8),
                  Text(f.erklaerung!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
                // Die Fundstelle gehört sichtbar an die Frage: Eine Antwort,
                // die man nicht nachschlagen kann, ist im Zweifel wertlos —
                // und im Zweifel ist man im Einsatz (Issue #174). Ohne
                // Geltungshinweis, der steht schon in der Unterzeile.
                if (f.quelle != null) ...[
                  const SizedBox(height: 10),
                  QuellenZeile(f.quelle!),
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
      richtige: eingabe.richtige,
      quelle: eingabe.quelle,
      geltung: eingabe.geltung,
      land: eingabe.land,
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
