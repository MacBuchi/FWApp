/// nfc_lesen_screen.dart – Tags berühren statt anpeilen (Issue #176).
///
/// Das Gegenstück zu `code_scannen_screen.dart`, und bewusst mit demselben
/// Zuschnitt: Der Bildschirm **bestimmt nicht, was ein Code bedeutet**. Er
/// reicht weiter, was auf dem Tag stand, und bleibt offen — ein Fach hat
/// fünfzehn Geräte, und für jedes neu zu öffnen wäre langsamer als das
/// Antippen, das damit ersetzt werden soll.
///
/// **Warum eine Sperre nach jedem Fund.** Android meldet dasselbe Tag
/// wieder, solange es an der Antenne liegt. Ohne Sperre zählte ein einziges
/// Tag ein Fach voll — derselbe Fehler, den der Kamera-Weg schon einmal
/// hatte, nur dass ihn dort erst der echte Lauf gezeigt hat.
///
/// ⚠️ **Nichts hiervon ist im Browser oder Emulator prüfbar.** Was zählt,
/// beweist ein Gerät (AGENTS.md, Kamera — dort saßen die v1.6.0-Abstürze).
library;

import 'package:flutter/material.dart';
import 'package:fwapp/features/inventory/data/nfc_dienst.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcLesenScreen extends StatefulWidget {
  /// Titelzeile — sagt, wofür gelesen wird. Der Bildschirm kennt den
  /// Unterschied nicht.
  final String titel;

  /// Was unter der Überschrift steht, bevor das erste Tag kommt.
  final String anleitung;

  /// Rückmeldung nach jedem Fund, die stehen bleibt. Gibt der Aufrufer
  /// `null` zurück, schließt der Bildschirm und liefert den Fund zurück.
  final Future<String?> Function(NfcFund fund) beiFund;

  const NfcLesenScreen({
    super.key,
    required this.titel,
    required this.beiFund,
    this.anleitung =
        'Das Handy an das Tag halten — meist an der Rückseite, '
            'oberes Drittel.',
  });

  @override
  State<NfcLesenScreen> createState() => _NfcLesenScreenState();
}

class _NfcLesenScreenState extends State<NfcLesenScreen> {
  static const _dienst = NfcDienst();

  NfcLage? _lage;
  bool _beschaeftigt = false;
  String? _meldung;

  @override
  void initState() {
    super.initState();
    _anfangen();
  }

  Future<void> _anfangen() async {
    final lage = await _dienst.lage();
    if (!mounted) return;
    setState(() => _lage = lage);
    if (lage == NfcLage.bereit) await _dienst.starte(_gelesen);
  }

  @override
  void dispose() {
    // Ohne das bleibt die Antenne an und das Gerät meldet Tags in die
    // Leere — auf Android hält die Sitzung den Bildschirm sonst wach.
    _dienst.stoppe();
    super.dispose();
  }

  Future<void> _gelesen(NfcTag tag) async {
    if (_beschaeftigt || !mounted) return;
    setState(() => _beschaeftigt = true);
    try {
      final fund = await _dienst.lies(tag);
      if (!mounted) return;
      final meldung = await widget.beiFund(fund);
      if (!mounted) return;
      if (meldung == null) {
        Navigator.pop(context, fund.kandidaten.firstOrNull);
        return;
      }
      setState(() => _meldung = meldung);
      // Kurze Pause, sonst meldet dasselbe liegende Tag sofort wieder.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    } finally {
      if (mounted) setState(() => _beschaeftigt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.titel)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_lage == null)
                const CircularProgressIndicator()
              else if (_lage != NfcLage.bereit)
                _KeinNfc(lage: _lage!)
              else ...[
                Icon(
                  Icons.nfc,
                  size: 96,
                  color:
                      _beschaeftigt
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.anleitung,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
              if (_meldung != null) ...[
                const SizedBox(height: 32),
                Card(
                  color: theme.colorScheme.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _meldung!,
                      style: TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Was statt der Anleitung steht, wenn NFC nicht zur Verfügung steht.
///
/// Jeder Fall bekommt seinen eigenen Satz: „NFC geht nicht" lässt jemanden
/// im Geräteraum ratlos stehen, „schalte es in den Einstellungen ein" nicht.
class _KeinNfc extends StatelessWidget {
  final NfcLage lage;
  const _KeinNfc({required this.lage});

  @override
  Widget build(BuildContext context) {
    final (String titel, String rat) = switch (lage) {
      NfcLage.ausgeschaltet => (
        'NFC ist ausgeschaltet',
        'In den Einstellungen des Geräts einschalten — dann hier noch '
            'einmal öffnen.',
      ),
      NfcLage.keineHardware => (
        'Dieses Gerät hat kein NFC',
        'Die Codes lassen sich mit der Kamera scannen oder eintippen.',
      ),
      _ => (
        'Hier geht NFC nicht',
        'Im Browser gibt es keinen NFC-Zugriff. In der App auf einem '
            'Android-Gerät schon.',
      ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.nfc, size: 64),
        const SizedBox(height: 16),
        Text(titel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(rat, textAlign: TextAlign.center),
      ],
    );
  }
}
