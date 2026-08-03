/// branding_screen.dart – Kopfbereich der Gesamtwehr pflegen (#57 P5).
///
/// Überschrift, Begrüßungstext und Kopfbild — was hier gespeichert wird, sieht
/// jedes Mitglied der Gesamtwehr auf seiner Startseite. Pflegen darf der
/// Feuerwehrkommandant dieser Wehr; der Server prüft das noch einmal.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/images/image_capture.dart';
import 'package:fwapp/core/sync/branding_providers.dart';
import 'package:fwapp/core/sync/gesamtwehr_providers.dart';
import 'package:fwapp/features/home/presentation/widgets/gesamtwehr_header.dart';

class BrandingScreen extends ConsumerStatefulWidget {
  const BrandingScreen({super.key});

  @override
  ConsumerState<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends ConsumerState<BrandingScreen> {
  final _titel = TextEditingController();
  final _text = TextEditingController();

  /// Gewähltes, noch nicht hochgeladenes Bild. Erst beim Speichern geht es in
  /// den Bucket — wer die Maske verlässt, soll nichts angerichtet haben.
  Uint8List? _neuesBild;

  /// Marker des gespeicherten Bilds; `null` heißt „keins" (auch nach dem
  /// Entfernen).
  String? _bildPfad;

  bool _uebernommen = false;
  bool _laeuft = false;

  @override
  void dispose() {
    _titel.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Felder einmalig aus dem geladenen Stand füllen. Einmalig, weil ein
  /// späteres Auffrischen sonst mitten im Tippen den Text austauschen würde.
  void _uebernimm(GesamtwehrBranding? branding) {
    if (_uebernommen || branding == null) return;
    _uebernommen = true;
    _titel.text = branding.titel ?? '';
    _text.text = branding.willkommenstext ?? '';
    _bildPfad = branding.bildPfad;
  }

  @override
  Widget build(BuildContext context) {
    final bezug = ref.watch(aktuelleGesamtwehrProvider).value;
    final darfPflegen = ref.watch(darfBrandingPflegenProvider).value ?? false;
    final brandingAsync = ref.watch(gesamtwehrBrandingProvider);
    _uebernimm(brandingAsync.value);

    return Scaffold(
      appBar: AppBar(title: const Text('Kopfbereich')),
      body: bezug == null
          ? const _Hinweis(
              icon: Icons.account_tree_outlined,
              text: 'Diese Abteilung gehört zu keiner Gesamtwehr. '
                  'Einen gemeinsamen Kopfbereich gibt es erst mit ihr.',
            )
          : !darfPflegen
              ? const _Hinweis(
                  icon: Icons.lock_outline,
                  text: 'Den Auftritt der Gesamtwehr pflegt der '
                      'Feuerwehrkommandant. Du siehst ihn auf der Startseite.',
                )
              : _Maske(
                  wehrName: bezug.name,
                  titel: _titel,
                  text: _text,
                  bildPfad: _bildPfad,
                  neuesBild: _neuesBild,
                  laeuft: _laeuft,
                  onBildWaehlen: _bildWaehlen,
                  onBildEntfernen: _bildEntfernen,
                  onSpeichern: _speichern,
                  onAenderung: () => setState(() {}),
                ),
    );
  }

  Future<void> _bildWaehlen() async {
    // saveToFile: false — die Datei bräuchte hier niemand. Das Bild gehört in
    // den Bucket, nicht auf dieses eine Gerät.
    final bild = await captureImage(context, saveToFile: false);
    if (bild == null || !mounted) return;
    setState(() => _neuesBild = bild.bytes);
  }

  void _bildEntfernen() {
    setState(() {
      _neuesBild = null;
      // Das alte Objekt bleibt im Bucket liegen (privat und klein). Aufgeräumt
      // wird nur, was ein neues Bild ersetzt — dafür sorgt der Upload selbst.
      _bildPfad = null;
    });
  }

  Future<void> _speichern() async {
    final bezug = ref.read(aktuelleGesamtwehrProvider).value;
    final dienst = ref.read(brandingServiceProvider);
    if (bezug == null || dienst == null) {
      _melde('Ohne Serververbindung lässt sich der Kopfbereich nicht '
          'speichern.');
      return;
    }

    setState(() => _laeuft = true);
    try {
      var pfad = _bildPfad;
      if (_neuesBild != null) {
        // ⚠️ Kein Rückfall auf einen lokalen Pfad wie beim Gerätefoto: Der
        // Kopf gehört der ganzen Wehr. Ein Pfad, den nur dieses Gerät kennt,
        // wäre für alle anderen ein totes Bild (Lehre aus Stufe ②).
        pfad = await dienst.bildHochladen(
          gesamtwehrId: bezug.id,
          bytes: _neuesBild!,
          bisher: _bildPfad,
        );
      }
      await dienst.speichern(
        gesamtwehrId: bezug.id,
        titel: _titel.text.trim().isEmpty ? null : _titel.text.trim(),
        willkommenstext: _text.text.trim().isEmpty ? null : _text.text.trim(),
        bildPfad: pfad,
      );
      if (!mounted) return;
      setState(() {
        _bildPfad = pfad;
        _neuesBild = null;
        _laeuft = false;
      });
      _melde('Kopfbereich gespeichert — alle Abteilungen sehen ihn.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _laeuft = false);
      _melde(gesamtwehrFehlerText(e));
    }
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Maske extends StatelessWidget {
  final String? wehrName;
  final TextEditingController titel;
  final TextEditingController text;
  final String? bildPfad;
  final Uint8List? neuesBild;
  final bool laeuft;
  final VoidCallback onBildWaehlen;
  final VoidCallback onBildEntfernen;
  final VoidCallback onSpeichern;
  final VoidCallback onAenderung;

  const _Maske({
    required this.wehrName,
    required this.titel,
    required this.text,
    required this.bildPfad,
    required this.neuesBild,
    required this.laeuft,
    required this.onBildWaehlen,
    required this.onBildEntfernen,
    required this.onSpeichern,
    required this.onAenderung,
  });

  @override
  Widget build(BuildContext context) {
    final hatBild = neuesBild != null || (bildPfad != null && bildPfad!.isNotEmpty);
    final vorschauBild = neuesBild != null
        ? Image.memory(neuesBild!, fit: BoxFit.cover)
        : gesamtwehrKopfBild(bildPfad);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('So sieht es auf der Startseite aus',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        // Dieselbe Darstellung wie die Startseite, nicht eine ähnliche.
        GesamtwehrKopf(
          titel: titel.text.trim().isEmpty ? wehrName : titel.text.trim(),
          text: text.text.trim().isEmpty ? null : text.text.trim(),
          bild: vorschauBild,
        ),
        if (titel.text.trim().isEmpty &&
            text.text.trim().isEmpty &&
            !hatBild) ...[
          const SizedBox(height: 4),
          Text(
            'Noch nichts gepflegt — dann zeigt die Startseite gar keinen Kopf.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: titel,
          onChanged: (_) => onAenderung(),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Überschrift',
            hintText: wehrName ?? 'Name der Gesamtwehr',
            helperText: 'Leer lassen zeigt den Namen der Gesamtwehr.',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: text,
          onChanged: (_) => onAenderung(),
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Begrüßungstext',
            hintText: 'Ein Satz an die Wehr — Termine, Hinweise, Willkommen.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(hatBild ? 'Kopfbild ersetzen' : 'Kopfbild wählen'),
                subtitle: Text(neuesBild != null
                    ? 'Neu gewählt — wird beim Speichern hochgeladen'
                    : 'Quer aufgenommen wirkt am besten'),
                trailing: const Icon(Icons.chevron_right),
                onTap: laeuft ? null : onBildWaehlen,
              ),
              if (hatBild)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Kopfbild entfernen'),
                  onTap: laeuft ? null : onBildEntfernen,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: laeuft ? null : onSpeichern,
          icon: laeuft
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(laeuft ? 'Wird gespeichert …' : 'Speichern'),
        ),
        const SizedBox(height: 8),
        Text(
          'Sichtbar für alle Abteilungen der Gesamtwehr, sobald sie das '
          'nächste Mal Netz haben.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Hinweis extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hinweis({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
