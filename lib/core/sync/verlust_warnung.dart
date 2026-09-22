/// verlust_warnung.dart – Die Frage vor dem Überschreiben (Issue #214).
///
/// Getrennt von der Zählung (`snapshot_verlust.dart`), weil das eine eine
/// Oberfläche braucht und das andere nicht: Was verloren ginge, lässt sich
/// ohne Bildschirm prüfen, und genau das tut der Test.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/core/sync/snapshot_verlust.dart';

/// Fragt, ob [verlust] in Kauf genommen wird.
///
/// Der Text nennt die Zahlen. „Es könnten Daten verloren gehen" wäre eine
/// Warnung, die man wegklickt; „2 Fahrzeuge und 5 Geräte-Einheiten
/// verschwinden" ist eine, die man liest.
/// [vorgang] ist die Handlung in der Sprache des Bildschirms —
/// „Aktualisieren" oder „Wechseln". Sie steht im Fließtext und auf der
/// Schaltfläche; ein Dialog, der beim Abteilungswechsel vom „Aktualisieren"
/// spräche, ließe jemanden nach dem Knopf suchen, den er gar nicht gedrückt
/// hat.
Future<bool> darfVerlieren(
  BuildContext context,
  SnapshotVerlust verlust, {
  required bool darfVeroeffentlichen,
  String vorgang = 'Aktualisieren',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Das ist hier noch nicht veröffentlicht'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⚠️ Der Satz ist bewusst ohne Rückbezug gebaut („die es hier
                // gibt … verschwinden sie"). Der müsste sich nach Zahl UND
                // Geschlecht des letzten Postens richten — bei „1 Fahrzeug"
                // stand dort erst „die … verschwinden sie", und ein falscher
                // Satz liest sich wie ein Fehler im Programm.
                Text(
                  'Auf dem Server fehlt, was hier angelegt wurde: '
                  '${verlust.beschreibung}. Beim $vorgang wird das '
                  'gelöscht.',
                ),
                if (darfVeroeffentlichen) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Erst veröffentlichen, dann ${vorgang.toLowerCase()} '
                    '— dann bleibt alles erhalten.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Wer den Bestand pflegen darf, kann ihn vorher '
                    'veröffentlichen.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Trotzdem ${vorgang.toLowerCase()}'),
            ),
          ],
        ),
  );
  return ok ?? false;
}
