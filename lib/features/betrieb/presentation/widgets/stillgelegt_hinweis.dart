/// stillgelegt_hinweis.dart – Hinweis auf der Startseite, wenn der
/// KreisDatenMeister die eigene Gesamtwehr stillgelegt hat (Issue #101).
///
/// Ohne ihn liefe jeder Gerätewart in eine nichtssagende Ablehnung beim
/// Veröffentlichen („permission denied") und suchte den Fehler bei sich.
/// Der Hinweis sagt, was noch geht (Nachschlagen, Lernen — es wird nichts
/// gelöscht), was nicht, und an wen man sich wendet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/betrieb/presentation/providers/betrieb_providers.dart';

class StillgelegtHinweis extends ConsumerWidget {
  const StillgelegtHinweis({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(eigeneWehrStillgelegtProvider).value != true) {
      return const SizedBox.shrink();
    }
    final kontakt = ref.watch(installationKontaktProvider).value;
    final farben = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: farben.errorContainer,
        child: ListTile(
          leading: Icon(Icons.pause_circle_outline, color: farben.error),
          title: const Text('Deine Feuerwehr ist stillgelegt'),
          subtitle: Text(
            'Nachschlagen und Lernen gehen weiter, deine Daten bleiben auf '
            'dem Gerät. Veröffentlichen, Einladen und Wissensfragen '
            'einreichen sind gesperrt.'
            '${kontakt == null ? '' : '\nKontakt: $kontakt'}',
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}
