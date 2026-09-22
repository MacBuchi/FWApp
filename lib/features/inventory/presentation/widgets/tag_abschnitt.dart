/// tag_abschnitt.dart – Codes an einer Geräte-Einheit verwalten
/// (Issues #177/#179).
///
/// **Zwei Wege, ein Ergebnis.** „Code vergeben" erzeugt einen eigenen Code
/// zum Ausdrucken, „Code eintragen" übernimmt einen, der schon auf dem Gerät
/// steht — der Hersteller-Barcode eines Pressluftatmers etwa. Danach sind
/// beide dasselbe: ein Schlüssel, der beim Abhaken auf diese Einheit zeigt.
///
/// **Warum der Code doppelt geprüft wird.** Die Spalte ist `unique`, ein
/// zweiter Versuch bricht also ohnehin ab. Vorher nachzusehen ist trotzdem
/// nicht überflüssig: Nur so lässt sich sagen, **an welchem** Gerät der Code
/// schon klebt — und das ist die Auskunft, die der Gerätewart braucht,
/// während er vor dem Fach steht.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inventory/data/nfc_dienst.dart';
import 'package:fwapp/features/inventory/presentation/providers/tag_providers.dart';
import 'package:fwapp/features/inventory/presentation/screens/nfc_lesen_screen.dart';
import 'package:fwapp/features/inventory/presentation/screens/code_scannen_screen.dart';
import 'package:fwapp/features/inventory/presentation/widgets/code_anzeigen.dart';

class TagAbschnitt extends ConsumerWidget {
  final int instanceId;
  final bool bearbeitbar;
  const TagAbschnitt({
    super.key,
    required this.instanceId,
    required this.bearbeitbar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsDerEinheitProvider(instanceId));

    return tagsAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      error: (e, _) => Text('Fehler: $e'),
      data:
          (tags) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tags.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Kein Code hinterlegt.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ...tags.map((t) => _TagZeile(tag: t, bearbeitbar: bearbeitbar)),
              if (bearbeitbar)
                OverflowBar(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Code vergeben'),
                      onPressed: () => _vergeben(context, ref),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Code scannen'),
                      onPressed: () => _scannen(context, ref),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Code eintragen'),
                      onPressed: () => _eintragen(context, ref),
                    ),
                    // Nur wo es NFC gibt (#176) — sonst wäre es ein Knopf, der
                    // eine Erklärung öffnet statt etwas zu tun.
                    if (NfcDienst.unterstuetzt)
                      TextButton.icon(
                        icon: const Icon(Icons.nfc),
                        label: const Text('NFC-Tag'),
                        onPressed: () => _nfcTag(context, ref),
                      ),
                  ],
                ),
            ],
          ),
    );
  }

  Future<void> _vergeben(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final dienst = ref.read(tagDienstProvider);
    try {
      final code = await dienst.vergebeCode(instanceId);
      if (!context.mounted) return;
      // Direkt zeigen statt nur zu melden: Der Code wird vergeben, UM
      // ausgedruckt zu werden — ihn erst suchen zu müssen wäre ein Umweg
      // durch die eigene Oberfläche.
      await zeigeCode(context, code);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ging nicht: $e')));
    }
  }

  /// Scannt einen Code und verknüpft ihn — derselbe Weg wie die
  /// Tastatureingabe, nur mit der Kamera als Quelle.
  Future<void> _scannen(BuildContext context, WidgetRef ref) async {
    final dienst = ref.read(tagDienstProvider);
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => CodeScannenScreen(
              titel: 'Code verknüpfen',
              // Gibt eine Meldung zurück und bleibt offen, wenn der Code schon
              // klebt: Dann greift man zum nächsten Aufkleber, statt den
              // Bildschirm neu zu öffnen.
              beiFund: (roh) async {
                final ergebnis = await dienst.verknuepfe(instanceId, roh);
                return switch (ergebnis) {
                  TagVerknuepft() => null,
                  TagLeer() => 'Da stand kein Code.',
                  TagSchonVergeben(:final code, :final geraet) =>
                    'Der Code $code klebt schon auf: $geraet.',
                };
              },
            ),
      ),
    );
  }

  /// Verknüpft ein NFC-Tag mit der Einheit (#176).
  ///
  /// **Erst schreiben, dann verknüpfen, und beides kann danebengehen.** Die
  /// App versucht, ihren eigenen Code auf das Tag zu schreiben — das ist der
  /// saubere Fall: Der Code steht dann auf dem Gegenstand und lässt sich
  /// auch mit einem fremden Lesegerät nachvollziehen.
  ///
  /// Geht das nicht — billige Aufkleber und Prüfplaketten sind oft
  /// schreibgeschützt oder schon beschrieben —, **ist das kein Fehlschlag**:
  /// Dann übernimmt die App die Seriennummer des Tags. Die ist
  /// unveränderlich und eindeutig, und mehr braucht ein Code nicht. Das Tag
  /// bleibt also brauchbar, statt abgelehnt zu werden.
  Future<void> _nfcTag(BuildContext context, WidgetRef ref) async {
    const nfc = NfcDienst();
    final dienst = ref.read(tagDienstProvider);

    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => NfcLesenScreen(
              titel: 'NFC-Tag verknüpfen',
              anleitung:
                  'Das Handy an das Tag halten. Die App beschreibt es, '
                  'wenn es das zulässt — sonst genügt seine Seriennummer.',
              beiFund: (fund) async {
                // Schon verknüpft? Dann nichts überschreiben, sondern sagen, wo
                // es klebt. Ein zweites Mal zu schreiben verlöre die bestehende
                // Zuordnung des Tags.
                for (final vorhanden in fund.kandidaten) {
                  final treffer = await dienst.schlageNach(vorhanden);
                  if (treffer != null) {
                    return 'Dieses Tag klebt schon auf: ${treffer.geraetename}.';
                  }
                }

                final code = await dienst.naechsterFreierCode();
                final lage = await nfc.schreibe(fund.tag, code);
                final (
                  String zuVerknuepfen,
                  bool selbst,
                  String vorspann,
                ) = switch (lage) {
                  NfcSchreibLage.geschrieben => (code, true, 'Tag beschrieben'),
                  NfcSchreibLage.schreibgeschuetzt ||
                  NfcSchreibLage.zuKlein => (
                    fund.seriennummer ?? '',
                    false,
                    'Tag ist schreibgeschützt — Seriennummer übernommen',
                  ),
                  NfcSchreibLage.misslungen => ('', false, ''),
                };
                if (lage == NfcSchreibLage.misslungen) {
                  return 'Das Tag war zu früh weg. Noch einmal anhalten.';
                }
                if (zuVerknuepfen.isEmpty) {
                  return 'Dieses Tag lässt sich weder beschreiben noch an seiner '
                      'Seriennummer erkennen.';
                }

                final ergebnis = await dienst.verknuepfe(
                  instanceId,
                  zuVerknuepfen,
                  artDesTags: EquipmentTags.kindNfc,
                  selbstVergeben: selbst,
                );
                return switch (ergebnis) {
                  TagVerknuepft(:final code) => '$vorspann: $code',
                  TagLeer() => 'Auf dem Tag stand nichts Verwertbares.',
                  TagSchonVergeben(:final code, :final geraet) =>
                    'Der Code $code klebt schon auf: $geraet.',
                };
              },
            ),
      ),
    );
  }

  Future<void> _eintragen(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final eingabe = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Code eintragen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Der Code, der auf dem Gerät steht — '
                    'Hersteller-Barcode, Prüfplakette oder ein eigener '
                    'Aufkleber.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Code'),
                    onSubmitted: (v) => Navigator.pop(ctx, v),
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
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Eintragen'),
              ),
            ],
          ),
    );
    if (eingabe == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final dienst = ref.read(tagDienstProvider);
    final ergebnis = await dienst.verknuepfe(instanceId, eingabe);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (ergebnis) {
          TagVerknuepft(:final code) => 'Code $code eingetragen.',
          TagLeer() => 'Da stand kein Code.',
          TagSchonVergeben(:final code, :final geraet) =>
            'Der Code $code klebt schon auf: $geraet.',
        }),
      ),
    );
  }
}

class _TagZeile extends ConsumerWidget {
  final EquipmentTagData tag;
  final bool bearbeitbar;
  const _TagZeile({required this.tag, required this.bearbeitbar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: Icon(
        tag.kind == EquipmentTags.kindNfc ? Icons.nfc : Icons.qr_code_2,
        size: 20,
      ),
      title: Text(tag.code, style: const TextStyle(fontFamily: 'monospace')),
      subtitle: Text(
        [
          tag.selfIssued
              ? 'von der App vergeben — antippen zum Aufkleben'
              : 'übernommen',
          // Sichtbar machen, was sonst still danebengeht: Ein Code, der die
          // anderen Geräte noch nicht erreicht hat, wird bei der nächsten
          // Inventur von niemandem sonst erkannt. Der Hinweis verschwindet von
          // selbst, sobald der Abgleich gelaufen ist.
          if (tag.dirty) 'noch nicht übertragen',
        ].join(' · '),
      ),
      onTap: tag.selfIssued ? () => zeigeCode(context, tag.code) : null,
      trailing:
          bearbeitbar
              ? IconButton(
                icon: const Icon(Icons.link_off, size: 20),
                tooltip: 'Code entfernen',
                onPressed: () => ref.read(tagDienstProvider).entferne(tag),
              )
              : null,
    );
  }
}
