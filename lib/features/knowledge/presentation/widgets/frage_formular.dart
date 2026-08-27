/// frage_formular.dart – Das geführte Anlegen einer Frage (Issue #174).
///
/// „Auch das geführte Anlegen von Fragen würde Sinn machen." — Geführt heißt
/// hier: Die Antwortfelder stehen schon da, die richtigen werden angehakt
/// statt beschrieben, und was nicht in Ordnung ist, sagt das Formular
/// **beim Absenden mit einem Satz**, nicht mit einem roten Rahmen ohne
/// Erklärung.
///
/// ⚠️ **Kästchen, keine Auswahlknöpfe.** Im amtlichen Prüfungsstoff sind
/// Mehrfachantworten der Normalfall — im Fragenkatalog des Innenministeriums
/// BW haben nur 79 von 210 Fragen genau eine richtige Antwort. Ein
/// Auswahlknopf würde zwei Drittel des Stoffs unerfassbar machen.
///
/// Geprüft wird mit [pruefeFrage] aus der Domäne — derselben Funktion, die
/// später den CSV-Import bewachen muss. Zwei Fassungen derselben Regel
/// laufen auseinander, und dann kommt durch den Import herein, was das
/// Formular abweist.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

/// Was das Formular zurückgibt.
class FrageEingabe {
  final Wissensgebiet gebiet;
  final String frage;
  final List<String> antworten;
  final Set<int> richtige;
  final String? erklaerung;
  final Fragenquelle? quelle;
  final Geltungsbereich geltung;
  final String? land;

  const FrageEingabe({
    required this.gebiet,
    required this.frage,
    required this.antworten,
    required this.richtige,
    this.erklaerung,
    this.quelle,
    this.geltung = Geltungsbereich.bund,
    this.land,
  });
}

class FrageFormular extends StatefulWidget {
  const FrageFormular({super.key, this.vorgabe});

  /// Vorgewähltes Gebiet — wer aus einem Gebiet heraus anlegt, meint meist
  /// dieses.
  final Wissensgebiet? vorgabe;

  @override
  State<FrageFormular> createState() => _FrageFormularState();
}

class _FrageFormularState extends State<FrageFormular> {
  late Wissensgebiet _gebiet =
      widget.vorgabe ?? Wissensgebiet.geraetekunde;
  final _frage = TextEditingController();
  final _erklaerung = TextEditingController();

  /// Vier Felder sind der Normalfall einer Quizfrage; zwei genügen, sechs
  /// sind die Grenze (siehe [pruefeFrage]).
  final List<TextEditingController> _antworten =
      List.generate(4, (_) => TextEditingController());

  /// Angehakte Antworten. Eine Menge, weil Mehrfachantworten der Normalfall
  /// sind — siehe Kopf.
  final Set<int> _richtige = {0};

  final _quelleWerk = TextEditingController();
  final _quelleFundstelle = TextEditingController();
  Geltungsbereich _geltung = Geltungsbereich.bund;
  String _land = 'BW';

  @override
  void dispose() {
    _frage.dispose();
    _erklaerung.dispose();
    _quelleWerk.dispose();
    _quelleFundstelle.dispose();
    for (final c in _antworten) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Frage einreichen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Wissensgebiet>(
              initialValue: _gebiet,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Sachgebiet', border: OutlineInputBorder()),
              items: [
                for (final g in Wissensgebiet.values)
                  DropdownMenuItem(
                    value: g,
                    child: Text('${g.symbol}  ${g.label}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (g) => setState(() => _gebiet = g ?? _gebiet),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _frage,
              autofocus: true,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Die Frage',
                hintText: 'z. B. „Wie lang ist ein C-Druckschlauch?“',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Antworten — alle richtigen anhaken',
                style: theme.textTheme.labelLarge),
            Text(
              'Mehrere dürfen richtig sein. Im Prüfungsbogen ist das die '
              'Regel, nicht die Ausnahme.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < _antworten.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _richtige.contains(i),
                      onChanged: (an) => setState(() {
                        if (an == true) {
                          _richtige.add(i);
                        } else {
                          _richtige.remove(i);
                        }
                      }),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _antworten[i],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Antwort ${i + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_antworten.length < 6)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                      () => _antworten.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Antwort hinzufügen'),
                ),
              ),
            const SizedBox(height: 16),
            Text('Woher stammt die Antwort?',
                style: theme.textTheme.labelLarge),
            Text(
              'Steht später unter der Frage. Ohne Fundstelle lässt sich eine '
              'Antwort nicht nachprüfen und bei einer Gesetzesänderung nicht '
              'wiederfinden.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _quelleWerk,
                    decoration: const InputDecoration(
                      labelText: 'Werk',
                      hintText: 'FwDV 10',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _quelleFundstelle,
                    decoration: const InputDecoration(
                      labelText: 'Fundstelle',
                      hintText: '§ 8 Abs. 2',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<Geltungsbereich>(
              segments: const [
                ButtonSegment(
                    value: Geltungsbereich.bund, label: Text('Bundesweit')),
                ButtonSegment(
                    value: Geltungsbereich.land, label: Text('Landesrecht')),
              ],
              selected: {_geltung},
              onSelectionChanged: (a) => setState(() => _geltung = a.first),
            ),
            if (_geltung == Geltungsbereich.land) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _land,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Land', border: OutlineInputBorder(),
                    isDense: true),
                items: [
                  for (final e in kBundeslaender.entries)
                    DropdownMenuItem(
                        value: e.key,
                        child:
                            Text(e.value, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _land = v ?? _land),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _erklaerung,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Erklärung (freiwillig)',
                hintText: 'Was sollte man dazu wissen?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _absenden,
          child: const Text('Einreichen'),
        ),
      ],
    );
  }

  void _absenden() {
    // Leere Felder am Ende sind kein Fehler, sondern der Normalfall: Wer nur
    // drei Antworten hat, lässt das vierte Feld stehen. Die Indizes müssen
    // deshalb NACH dem Zusammenstreichen neu bestimmt werden — sonst zeigt
    // ein Haken auf Feld 4 in einer Liste, die nur noch drei Einträge hat.
    final gefuellt = <int, String>{};
    for (var i = 0; i < _antworten.length; i++) {
      final text = _antworten[i].text.trim();
      if (text.isNotEmpty) gefuellt[i] = text;
    }
    final antworten = gefuellt.values.toList();
    final reihenfolge = gefuellt.keys.toList();
    final richtige = {
      for (final alt in _richtige)
        if (reihenfolge.contains(alt)) reihenfolge.indexOf(alt),
    };

    final fehler = pruefeFrage(
      frage: _frage.text,
      antworten: antworten,
      richtige: richtige,
    );
    if (fehler != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(fehler)));
      return;
    }

    final werk = _quelleWerk.text.trim();
    Navigator.of(context).pop(FrageEingabe(
      gebiet: _gebiet,
      frage: _frage.text.trim(),
      antworten: antworten,
      richtige: richtige,
      erklaerung: _erklaerung.text.trim().isEmpty
          ? null
          : _erklaerung.text.trim(),
      quelle: werk.isEmpty
          ? null
          : Fragenquelle(
              werk: werk,
              fundstelle: _quelleFundstelle.text.trim().isEmpty
                  ? null
                  : _quelleFundstelle.text.trim(),
            ),
      geltung: _geltung,
      land: _geltung == Geltungsbereich.land ? _land : null,
    ));
  }
}
