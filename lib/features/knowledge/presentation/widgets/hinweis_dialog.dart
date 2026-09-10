/// hinweis_dialog.dart – „Da stimmt etwas nicht" an einer Frage (Issue #194).
///
/// Marcus in der App: „Bei Quizfragen (egal ob allgemein oder FW Spezifisch)
/// kann der Nutzer einen Kommentar / Änderungswunsch bzw Hinweis abgeben. Bei
/// globalen Fragen kann das über den Feedback Bot eingesammelt und
/// kategorisiert werden. Bei Eigenen Fragen sollte das beim Gerätewart
/// landen."
///
/// **Warum der Dialog sagt, wohin es geht.** Weil die beiden Wege verschieden
/// öffentlich sind: Der eine endet in einem Issue im öffentlichen Repo, der
/// andere beim Gerätewart der eigenen Wehr. Wer das nicht weiß, schreibt in
/// den falschen. Derselbe Grund, aus dem der Feedback-Dialog seinen
/// Öffentlichkeits-Hinweis trägt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/profil/presentation/providers/profil_providers.dart';
import 'package:fwapp/features/feedback/data/feedback_repository.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';

/// Zeigt den Dialog und meldet den Hinweis auf dem passenden Weg.
///
/// Gibt zurück, was dem Nutzer zu sagen ist — `null`, wenn er abgebrochen
/// hat. Der Aufrufer zeigt daraus den SnackBar; so bleibt die Meldung an der
/// Stelle, an der auch der Bildschirm noch steht.
Future<String?> zeigeHinweisDialog(
  BuildContext context,
  WidgetRef ref,
  WissensfrageData z,
) async {
  final f = zuWissensfrage(z);
  final hatWehr = ref.read(wissenGesamtwehrProvider) != null;
  final weg = hinweisWegFuer(z, hatWehr: hatWehr);

  if (weg == Hinweisweg.nurLokal) {
    return 'Diese Frage steht nur auf diesem Gerät — es gibt niemanden, '
        'dem man sie melden könnte.';
  }

  final steuerung = TextEditingController();
  final ergebnis = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Hinweis zur Frage'),
        // ⚠️ Scrollbar, nicht aus Vorsicht: Auf dem Pixel XL im Querformat
        // bleiben unter der Tastatur wenige Zeilen übrig, und ohne das hier
        // schiebt das Textfeld die Knöpfe aus dem Bild (Lehre aus v1.3.1).
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('„${f.frage}"',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              Text(
                weg == Hinweisweg.bot
                    ? 'Diese Frage wird mit der App ausgeliefert — sie ist '
                        'in jeder Wehr dieselbe. Dein Hinweis geht deshalb '
                        'an die Entwicklung und wird dort öffentlich '
                        'sichtbar.'
                    : 'Diese Frage gehört eurer Wehr. Dein Hinweis geht an '
                        'den Gerätewart und bleibt in der Wehr.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: steuerung,
                autofocus: true,
                maxLines: 4,
                maxLength: kFeedbackMaxLength,
                decoration: const InputDecoration(
                  labelText: 'Was stimmt nicht?',
                  hintText: 'z. B. „Antwort b) ist seit der Neufassung 2024 '
                      'auch richtig."',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, steuerung.text.trim()),
            child: const Text('Senden'),
          ),
        ],
      );
    },
  );
  steuerung.dispose();

  if (ergebnis == null) return null;
  // Dieselbe Untergrenze wie der Server (`check char_length between 3 and
  // 2000`) — hier abgefangen, damit das Nein nicht als „Senden
  // fehlgeschlagen" ankommt.
  if (ergebnis.length < 3) {
    return 'Schreib bitte kurz, was nicht stimmt.';
  }

  try {
    if (weg == Hinweisweg.bot) {
      // ⚠️ Die ERSTE ZEILE ist die Frage — daraus baut der Bot die
      // Überschrift des Issues (tool/feedback_bot.py, FIRST_LINE_TITLE).
      // Ohne sie hieße jedes Issue „Frage-Hinweis: Antwort b) ist seit …",
      // und niemand wüsste, zu welcher Frage.
      await ref.read(feedbackSenderProvider)(
        type: FeedbackType.frage,
        message: [
          f.frage,
          '',
          ergebnis,
          '',
          'Gebiet: ${f.gebiet.label}'
              '${f.kapitel == null ? '' : ' · ${f.kapitel}'}',
          if (f.quelle != null) 'Quelle: ${f.quelle!.anzeige}',
        ].join('\n'),
      );
      return 'Danke! Der Hinweis ist bei der Entwicklung.';
    }

    await meldeFragenhinweis(
      ref,
      frageRemoteId: z.remoteId!,
      text: ergebnis,
      // Der selbst gewählte Name, sonst der Nutzername, sonst nichts —
      // `von_name` ist rein informativ, ein fehlender Wert ist kein Fehler.
      melderName: ref.read(meinProfilProvider).value?.name,
    );
    return 'Danke! Der Gerätewart schaut sich das an.';
  } catch (e) {
    return 'Senden fehlgeschlagen: $e';
  }
}
