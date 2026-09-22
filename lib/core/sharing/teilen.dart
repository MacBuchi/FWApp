/// teilen.dart – Text oder Textdatei über das Teilen-Blatt des Systems,
/// mit der Zwischenablage als ehrlichem Rückfall.
///
/// Herausgezogen aus der Nutzerverwaltung (Issue #165) und dem Fragen-Import
/// (#194), als der Inventur-Export (#178) die dritte Stelle wurde. Die beiden
/// Fassungen waren bis auf den Meldungstext gleich.
///
/// ⚠️ **`mailToFallbackEnabled: false` ist Absicht.** Ohne Web-Share-API —
/// also in jedem Desktop-Browser — öffnet share_plus sonst einen
/// MAIL-Entwurf, ausgerechnet den Weg, den das Teilen-Blatt ersetzen soll.
/// Ohne den Rückfall wirft das Paket stattdessen, und dann ist die
/// Zwischenablage die ehrlichere Antwort: Der Text ist da, der Nutzer weiß
/// es, und er fügt ihn dort ein, wo er ihn haben will.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Teilt [text]; mit [dateiname] als Datei mit diesem Namen, sonst als
/// reinen Text.
///
/// [sacheImRueckfall] benennt das Geteilte in der Rückfall-Meldung („die
/// Vorlage liegt in der Zwischenablage"), damit dort nicht für jeden Aufruf
/// dasselbe blasse „der Text" steht.
///
/// Gibt zurück, ob das Teilen-Blatt aufging. `false` heißt: Der Inhalt liegt
/// in der Zwischenablage und der Nutzer hat eine Meldung gesehen.
Future<bool> teile(
  BuildContext context,
  String text, {
  String? dateiname,
  String sacheImRueckfall = 'der Text',
  String? betreff,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: betreff,
        fileNameOverrides: dateiname == null ? null : [dateiname],
        mailToFallbackEnabled: false,
      ),
    );
    return true;
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Teilen geht hier nicht — $sacheImRueckfall liegt in '
          'der Zwischenablage.',
        ),
      ),
    );
    return false;
  }
}
