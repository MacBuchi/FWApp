/// dubletten_dialog.dart – Die Rückfrage vor dem Veröffentlichen (#67).
///
/// Getrennt von der Suche (`dubletten.dart`), wie bei der Verlustwarnung:
/// Was doppelt ist, lässt sich ohne Bildschirm prüfen — und genau das tut
/// der Test.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/dubletten.dart';

/// Was mit einem Paar geschehen soll.
typedef Zusammenfuehrung = ({int behalten, int aufgeben});

/// Fragt zu jedem gefundenen Paar, ob es dasselbe Gerät ist.
///
/// Gibt die Paare zurück, die zusammengeführt werden sollen — eine leere
/// Liste heißt „alles verschieden, weiter". `null` heißt Abbruch: Dann wird
/// auch nicht veröffentlicht.
///
/// ⚠️ **Voreingestellt ist „verschieden".** Zusammenführen löscht einen
/// Eintrag, und eine Voreinstellung, die bei Unachtsamkeit löscht, ist keine
/// Hilfe, sondern eine Falle. Wer zusammenführen will, sagt es — das sind
/// zwei Tipps, und die Namen stehen direkt daneben.
Future<List<Zusammenfuehrung>?> frageNachDubletten(
  BuildContext context,
  List<Dublette> dubletten,
) => showDialog<List<Zusammenfuehrung>>(
  context: context,
  builder: (ctx) => _DublettenDialog(dubletten: dubletten),
);

class _DublettenDialog extends StatefulWidget {
  const _DublettenDialog({required this.dubletten});

  final List<Dublette> dubletten;

  @override
  State<_DublettenDialog> createState() => _DublettenDialogState();
}

class _DublettenDialogState extends State<_DublettenDialog> {
  /// Schlüssel des Paares → wird zusammengeführt?
  final _zusammen = <String, bool>{};

  /// Schlüssel des Paares → ID des Eintrags, der bleibt.
  final _behalten = <String, int>{};

  @override
  void initState() {
    super.initState();
    for (final d in widget.dubletten) {
      _zusammen[d.schluessel] = false;
      _behalten[d.schluessel] = d.behalten.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position =
        widget.dubletten.where((d) => d.art == DublettenArt.position).toList();
    final katalog =
        widget.dubletten.where((d) => d.art == DublettenArt.katalog).toList();
    final anzahl = _zusammen.values.where((v) => v).length;

    return AlertDialog(
      title: const Text('Ist das zweimal dasselbe?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hier steht Erfasstes, das dasselbe Gerät meinen könnte. '
                'Zusammengeführt wird nur, was du dafür auswählst.',
                style: theme.textTheme.bodyMedium,
              ),
              if (position.isNotEmpty) ...[
                _Ueberschrift(
                  'Im selben Geräteraum',
                  'Gleiches Fahrzeug, gleiches Fach — meistens ein Gerät, '
                      'das zwei Leute erfasst haben.',
                ),
                ...position.map(_paar),
              ],
              if (katalog.isNotEmpty) ...[
                _Ueberschrift(
                  'Ähnliche Namen im Bestand',
                  'Liegen in verschiedenen Fächern, heißen aber fast gleich. '
                      'Schwächerer Verdacht — es können zwei echte Geräte '
                      'sein.',
                ),
                ...katalog.map(_paar),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final ergebnis = <Zusammenfuehrung>[];
            for (final d in widget.dubletten) {
              if (_zusammen[d.schluessel] != true) continue;
              final bleibt = _behalten[d.schluessel]!;
              ergebnis.add((
                behalten: bleibt,
                aufgeben:
                    bleibt == d.behalten.id ? d.aufgeben.id : d.behalten.id,
              ));
            }
            Navigator.pop(context, ergebnis);
          },
          child: Text(
            anzahl == 0
                ? 'Alles verschieden, veröffentlichen'
                : anzahl == 1
                ? '1 zusammenführen und veröffentlichen'
                : '$anzahl zusammenführen und veröffentlichen',
          ),
        ),
      ],
    );
  }

  Widget _paar(Dublette d) {
    final theme = Theme.of(context);
    final zusammen = _zusammen[d.schluessel] ?? false;
    final bleibt = _behalten[d.schluessel];

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.ort, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            // Ohne Zusammenführen sind es einfach zwei Namen; erst wenn
            // zusammengeführt wird, muss einer davon gewinnen. Vorher eine
            // Auswahl anzubieten, hieße nach etwas zu fragen, das noch keine
            // Folge hat.
            if (!zusammen)
              Text('„${d.behalten.name}" und „${d.aufgeben.name}"')
            else
              RadioGroup<int>(
                groupValue: bleibt,
                onChanged: (v) => setState(() => _behalten[d.schluessel] = v!),
                child: Column(
                  children: [
                    for (final g in [d.behalten, d.aufgeben])
                      RadioListTile<int>(
                        value: g.id,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('„${g.name}"'),
                        subtitle: Text(
                          g.dirty
                              ? 'hier erfasst, noch nicht veröffentlicht'
                              : 'steht schon im Bestand der Wehr',
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Verschieden')),
                ButtonSegment(value: true, label: Text('Dasselbe')),
              ],
              selected: {zusammen},
              showSelectedIcon: false,
              onSelectionChanged:
                  (auswahl) =>
                      setState(() => _zusammen[d.schluessel] = auswahl.first),
            ),
            if (zusammen) ...[
              const SizedBox(height: 6),
              Text(
                'Beladung, Geräte-Einheiten und aufgeklebte Codes ziehen um; '
                'der andere Eintrag verschwindet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Ueberschrift extends StatelessWidget {
  const _Ueberschrift(this.titel, this.erklaerung);

  final String titel;
  final String erklaerung;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: theme.textTheme.titleSmall),
          Text(
            erklaerung,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sucht Dubletten, fragt nach und führt das Bestätigte zusammen.
///
/// `false` heißt: nicht veröffentlichen — der Nutzer hat abgebrochen.
///
/// ⚠️ Liegt hier und nicht an den beiden Veröffentlichen-Knöpfen. „Bestand
/// aktualisieren" stand einmal dreimal ausgeschrieben, und die dritte Kopie
/// hinkte hinterher (Issue #218); ein Ablauf mit drei Schritten ist der
/// letzte, den man dupliziert.
Future<bool> klaereDubletten(BuildContext context, AppDatabase db) async {
  final dubletten = await findeDubletten(db);
  if (dubletten.isEmpty) return true;
  if (!context.mounted) return false;
  final entscheidungen = await frageNachDubletten(context, dubletten);
  if (entscheidungen == null) return false;
  await fuehreAlleZusammen(db, entscheidungen);
  return true;
}
