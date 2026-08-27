/// frage_formular.dart – Das geführte Anlegen einer Frage (Issue #174).
///
/// „Auch das geführte Anlegen von Fragen würde Sinn machen." — Geführt heißt
/// hier: Die Antwortfelder stehen schon da, die richtige wird angetippt
/// statt beschrieben, und was nicht in Ordnung ist, sagt das Formular
/// **beim Absenden mit einem Satz**, nicht mit einem roten Rahmen ohne
/// Erklärung.
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
  final int richtig;
  final String? erklaerung;

  const FrageEingabe({
    required this.gebiet,
    required this.frage,
    required this.antworten,
    required this.richtig,
    this.erklaerung,
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
  int _richtig = 0;

  @override
  void dispose() {
    _frage.dispose();
    _erklaerung.dispose();
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
            Text('Antworten — die richtige antippen',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            // Radio statt Kästchen: Genau eine Antwort ist richtig, und die
            // Form soll das sagen, bevor jemand es versucht. `RadioGroup`
            // statt `groupValue` je Knopf — das ist seit Flutter 3.32 der
            // Weg, der Rest ist abgekündigt.
            RadioGroup<int>(
              groupValue: _richtig,
              onChanged: (v) => setState(() => _richtig = v ?? 0),
              child: Column(
                children: [
                  for (var i = 0; i < _antworten.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Radio<int>(value: i),
                          Expanded(
                            child: TextField(
                              controller: _antworten[i],
                              textCapitalization:
                                  TextCapitalization.sentences,
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
            const SizedBox(height: 8),
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
    // drei Antworten hat, lässt das vierte Feld stehen.
    final antworten = _antworten
        .map((c) => c.text.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    final richtigerText = _richtig < _antworten.length
        ? _antworten[_richtig].text.trim()
        : '';
    final richtig = antworten.indexOf(richtigerText);

    final fehler = pruefeFrage(
      frage: _frage.text,
      antworten: antworten,
      richtig: richtig,
    );
    if (fehler != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(fehler)));
      return;
    }

    Navigator.of(context).pop(FrageEingabe(
      gebiet: _gebiet,
      frage: _frage.text.trim(),
      antworten: antworten,
      richtig: richtig,
      erklaerung: _erklaerung.text.trim().isEmpty
          ? null
          : _erklaerung.text.trim(),
    ));
  }
}
