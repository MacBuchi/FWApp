/// code_scannen_screen.dart – Codes mit der Kamera lesen (Issue #179).
///
/// **Was dieser Bildschirm NICHT tut: entscheiden, was der Code bedeutet.**
/// Er liefert die gelesene Zeichenkette zurück, mehr nicht. Ob damit ein
/// Gerät abgehakt oder ein Tag verknüpft wird, weiß der Aufrufer — und beide
/// nehmen danach denselben Weg wie eine Tastatureingabe, durch
/// `normalisiereTagCode`. Eine zweite Auswertung hier hätte zwei Wahrheiten
/// darüber erzeugt, was ein gültiger Code ist.
///
/// **Warum eine Sperre nach jedem Fund.** Die Kamera liefert denselben Code
/// dreißigmal pro Sekunde, solange er im Bild ist. Ohne Sperre hakt ein
/// einziger Aufkleber ein Gerät auf „vollständig", zählt einen Bestand hoch
/// oder öffnet dreißig Dialoge. Die Sperre ist deshalb Teil der Funktion,
/// nicht Feinschliff.
///
/// ⚠️ **Der Web-Pfad ist ein anderer als der auf dem Gerät** (AGENTS.md,
/// Kamera). Ein grüner Durchlauf im Browser beweist für Android nichts —
/// dort entscheidet die Laufzeitberechtigung, und genau dort saßen die
/// Abstürze in v1.6.0.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CodeScannenScreen extends StatefulWidget {
  /// Titelzeile — sagt, wofür gescannt wird („Gerät abhaken", „Code
  /// verknüpfen"). Der Bildschirm selbst kennt den Unterschied nicht.
  final String titel;

  /// Rückmeldung nach jedem Fund, die über dem Bild stehen bleibt. Gibt der
  /// Aufrufer `null` zurück, wird der Bildschirm nach diesem Fund geschlossen
  /// und der Code als Ergebnis zurückgegeben.
  final Future<String?> Function(String code)? beiFund;

  const CodeScannenScreen({super.key, required this.titel, this.beiFund});

  @override
  State<CodeScannenScreen> createState() => _CodeScannenScreenState();
}

class _CodeScannenScreenState extends State<CodeScannenScreen> {
  final _controller = MobileScannerController(
    // Ein Code je Bild genügt; mehrere gleichzeitig zu lesen hieße raten,
    // welcher gemeint war.
    detectionSpeed: DetectionSpeed.normal,
  );

  /// Läuft gerade eine Auswertung? Solange das steht, werden weitere Bilder
  /// ignoriert — siehe Kopfkommentar.
  bool _beschaeftigt = false;
  String? _meldung;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _gelesen(BarcodeCapture fund) async {
    if (_beschaeftigt) return;
    final roh = fund.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (roh == null) return;

    setState(() => _beschaeftigt = true);
    try {
      if (widget.beiFund == null) {
        if (mounted) Navigator.pop(context, roh);
        return;
      }
      final meldung = await widget.beiFund!(roh);
      if (!mounted) return;
      if (meldung == null) {
        Navigator.pop(context, roh);
        return;
      }
      setState(() => _meldung = meldung);
      // Kurze Pause, sonst liest dasselbe Bild sofort wieder denselben Code.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    } finally {
      if (mounted) setState(() => _beschaeftigt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Licht',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Kamera wechseln',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _gelesen,
            // Kein Bild heißt hier nicht „kaputt": keine Kamera, keine
            // Erlaubnis, oder ein Browser ohne HTTPS. Das gehört benannt,
            // sonst steht der Nutzer vor einer schwarzen Fläche und hält sie
            // für einen Absturz.
            errorBuilder: (context, fehler) => _KeinBild(fehler: fehler),
          ),
          const _Zielrahmen(),
          if (_meldung != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Card(
                color: Theme.of(context).colorScheme.inverseSurface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _meldung!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Was statt des Kamerabildes steht, wenn es keines gibt.
class _KeinBild extends StatelessWidget {
  final MobileScannerException fehler;
  const _KeinBild({required this.fehler});

  @override
  Widget build(BuildContext context) {
    final (String titel, String rat) = switch (fehler.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
          'Kein Zugriff auf die Kamera',
          'Die Erlaubnis fehlt. In den Einstellungen des Geräts freigeben — '
              'oder den Code stattdessen eintippen.',
        ),
      MobileScannerErrorCode.unsupported => (
          'Scannen geht hier nicht',
          'Dieses Gerät oder dieser Browser stellt keine Kamera bereit. '
              'Der Code lässt sich eintippen.',
        ),
      _ => (
          'Die Kamera ließ sich nicht starten',
          'Benutzt eine andere App gerade die Kamera? Sonst hilft der Weg '
              'über die Tastatur.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48),
            const SizedBox(height: 16),
            Text(titel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(rat, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Zeigt, wohin der Code gehalten werden soll. Ohne Rahmen zielt jeder auf
/// die Bildmitte, und die Kamera fokussiert woanders.
class _Zielrahmen extends StatelessWidget {
  const _Zielrahmen();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
