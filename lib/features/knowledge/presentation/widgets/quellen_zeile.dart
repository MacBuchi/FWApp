/// quellen_zeile.dart – Die Fundstelle unter einer Frage (Issue #174).
///
/// **Warum das ein eigenes Widget ist.** Die Fundstelle muss an jeder Stelle
/// stehen, an der eine Frage beantwortet wird — in der Wissensdatenbank und
/// im Party-Modus. Zwei Fassungen derselben Zeile laufen auseinander, und die
/// im Spiel wäre die, an die niemand denkt: Dort war die Quelle bis
/// Schritt 3 gar nicht vorhanden, obwohl genau dort gestritten wird, ob eine
/// Antwort stimmt.
///
/// Der Link öffnet die amtliche Fassung. Er ist nicht Zierrat, sondern der
/// Punkt der ganzen Übung: Wer am Tisch widerspricht, soll nachschlagen
/// können, statt sich auf die App zu verlassen.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';
import 'package:url_launcher/url_launcher.dart';

class QuellenZeile extends StatelessWidget {
  final Fragenquelle quelle;

  /// „Baden-Württemberg", wenn die Frage nur dort gilt. Was überall gilt,
  /// bekommt keinen Hinweis — sonst stünde er an fast jeder Frage und würde
  /// dort gelesen, wo er nichts sagt.
  final String? geltungshinweis;

  const QuellenZeile(this.quelle, {super.key, this.geltungshinweis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = theme.colorScheme.outline;
    final text = [
      quelle.stand == null || quelle.stand!.isEmpty
          ? quelle.anzeige
          : '${quelle.anzeige} (${quelle.stand})',
      if (geltungshinweis != null) 'gilt in $geltungshinweis',
    ].join(' · ');

    final hatLink = (quelle.url ?? '').trim().isNotEmpty;
    final zeile = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(hatLink ? Icons.menu_book : Icons.menu_book_outlined,
            size: 14, color: farbe),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: hatLink ? theme.colorScheme.primary : farbe,
              decoration: hatLink ? TextDecoration.underline : null,
              decorationColor: theme.colorScheme.primary,
            ),
          ),
        ),
        if (hatLink) Icon(Icons.open_in_new, size: 14, color: farbe),
      ],
    );

    if (!hatLink) return zeile;
    return InkWell(
      onTap: () => _oeffnen(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: zeile,
      ),
    );
  }

  Future<void> _oeffnen(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(quelle.url!.trim());
    var geoeffnet = false;
    if (uri != null) {
      try {
        // Kein `canLaunchUrl`-Vortest: Der hängt unter Android 11+ an der
        // Package Visibility und meldete funktionierende Links als tot
        // (dieselbe Erfahrung wie beim Lernmaterial im Gerätedetail).
        geoeffnet =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        appLog.w('Fundstelle "${quelle.url}" ließ sich nicht öffnen: $e');
      }
    }
    if (!geoeffnet) {
      messenger.showSnackBar(
          SnackBar(content: Text('Fundstelle nicht erreichbar: '
              '${quelle.url}')));
    }
  }
}
