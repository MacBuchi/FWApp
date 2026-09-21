/// code_anzeigen.dart – Einen Code als QR zeigen, groß genug zum Abfotografieren
/// oder Ausdrucken (Issue #177).
///
/// **Warum der Code auch als Text darunter steht.** Ein Aufkleber, dessen QR
/// beschädigt ist, ist ohne lesbaren Code wertlos — und genau das passiert
/// einem Aufkleber im Geräteraum. Der Text ist die Rückfallebene, und er ist
/// der Grund, warum die Vergabe verwechselbare Zeichen meidet.
///
/// **Warum keine Bilddatei.** Der QR entsteht als Widget. Eine PNG-Datei
/// bräuchte einen Ablageort, und auf dem Weg dorthin steht dieselbe
/// `path_provider`-Lücke wie bei den Fahrzeug-Unterlagen (#210). Wer
/// ausdrucken will, fotografiert den Bildschirm oder nimmt den Teilen-Weg
/// über den Text.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Zeigt [code] als QR in einem Dialog.
Future<void> zeigeCode(BuildContext context, String code) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code zum Aufkleben'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Weißer Grund unabhängig vom Thema: Ein QR auf dunklem Grund
              // wird von vielen Lesegeräten nicht erkannt, und im Dunkelmodus
              // wäre er genau das.
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: code,
                  size: 220,
                  backgroundColor: Colors.white,
                  // Mittlere Fehlerkorrektur: Ein Aufkleber im Geräteraum
                  // bekommt Kratzer und Öl ab.
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 18, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                'Steht der QR schief oder ist er verkratzt, hilft der Code '
                'darunter — er lässt sich eintippen.',
                style: Theme.of(ctx).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Kopieren'),
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fertig')),
        ],
      ),
    );
