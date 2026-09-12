/// fragen_import_screen.dart – Fragen aus einer Tabelle einlesen.
///
/// **Warum der Bildschirm zuerst die Vorlage anbietet.** Der erste Versuch
/// scheitert sonst an der Kopfzeile, und zwar bei jedem. Wer die Vorlage
/// nimmt, füllt sie aus und lädt sie hoch, hat die Spaltennamen nie tippen
/// müssen — und die zwei Beispielzeilen zeigen zugleich, wie eine
/// Quellenangabe und eine Mehrfachantwort aussehen.
///
/// **Warum Fehler zeilenweise stehen bleiben.** Eine Datei mit vierzig
/// Fragen und zwei Tippfehlern ist kein Fehlschlag. Die achtunddreißig guten
/// werden angeboten, die zwei anderen mit ihrer **Zeilennummer aus der
/// Tabellenkalkulation** genannt — damit man sie dort findet, wo man sie
/// geschrieben hat.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fwapp/features/import/data/import_parser.dart';
import 'package:fwapp/features/knowledge/data/fragen_import.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';
import 'package:fwapp/features/profil/presentation/providers/profil_providers.dart';
import 'package:share_plus/share_plus.dart';

class FragenImportScreen extends ConsumerStatefulWidget {
  const FragenImportScreen({super.key});

  @override
  ConsumerState<FragenImportScreen> createState() => _FragenImportState();
}

class _FragenImportState extends ConsumerState<FragenImportScreen> {
  FrageImportErgebnis? _ergebnis;
  String? _dateiname;
  String? _fehler;
  bool _laeuft = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fragen importieren')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _erklaerung(),
          const SizedBox(height: 16),
          _knoepfe(),
          if (_fehler != null) ...[
            const SizedBox(height: 16),
            _fehlerkarte(_fehler!),
          ],
          if (_ergebnis != null) ...[
            const SizedBox(height: 24),
            _befundAnzeige(_ergebnis!),
          ],
        ],
      ),
    );
  }

  Widget _erklaerung() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('So geht es', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Lade die Vorlage herunter, trag deine Fragen ein und wähle die '
              'Datei hier aus. CSV und Excel gehen beide.\n\n'
              'Pflicht sind „frage", „gebiet", mindestens „antwort1" und '
              '„antwort2" sowie „richtig". In „richtig" steht die Nummer oder '
              'der Buchstabe der richtigen Antwort — mehrere durch Komma '
              'getrennt, zum Beispiel „a, c".',
            ),
            const SizedBox(height: 8),
            Text(
              'Importierte Fragen sind sofort freigegeben. Du kannst sie '
              'danach wie jede andere bearbeiten oder entfernen.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _knoepfe() => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _laeuft ? null : _vorlageTeilen,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Vorlage'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _laeuft ? null : _dateiWaehlen,
              icon: const Icon(Icons.upload_file),
              label: const Text('Datei wählen'),
            ),
          ),
        ],
      );

  Widget _fehlerkarte(String text) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer)),
        ),
      );

  Widget _befundAnzeige(FrageImportErgebnis e) => FragenImportBefund(
        ergebnis: e,
        dateiname: _dateiname ?? '',
        aktiv: !_laeuft,
        aufUebernehmen: _uebernehmen,
      );

  Future<void> _vorlageTeilen() async {
    final messenger = ScaffoldMessenger.of(context);
    // ⚠️ `mailToFallbackEnabled: false` aus demselben Grund wie in der
    // Nutzerverwaltung: Ohne Web-Share-API öffnet share_plus sonst einen
    // Mail-Entwurf. Ohne den Rückfall wirft es, und dann ist die
    // Zwischenablage die ehrlichere Antwort.
    try {
      await SharePlus.instance.share(ShareParams(
        text: vorlageCsv(),
        fileNameOverrides: const ['fragen-vorlage.csv'],
        mailToFallbackEnabled: false,
      ));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: vorlageCsv()));
      messenger.showSnackBar(const SnackBar(
        content: Text('Teilen geht hier nicht — die Vorlage liegt in der '
            'Zwischenablage.'),
      ));
    }
  }

  Future<void> _dateiWaehlen() async {
    final gewaehlt = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt', 'xlsx', 'xls'],
      withData: true,
    );
    final datei = gewaehlt?.files.firstOrNull;
    if (datei == null || datei.bytes == null) return;

    setState(() {
      _laeuft = true;
      _fehler = null;
      _ergebnis = null;
    });
    try {
      final geparst = ImportParser.parse(datei.name, datei.bytes!);
      final vorhanden = await vorhandeneFragenSchluessel(ref);
      // Die erste Tabelle: Eine Excel-Mappe kann mehrere Blätter haben, und
      // ein Blattwähler wäre hier Zierde — die Vorlage hat genau eines.
      final ergebnis = leseFragen(geparst.tables.first,
          vorhandeneFragen: vorhanden);
      if (!mounted) return;
      setState(() {
        _ergebnis = ergebnis;
        _dateiname = datei.name;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _fehler = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _fehler = 'Die Datei ließ sich nicht lesen: $e');
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  Future<void> _uebernehmen(List<FrageImportZeile> zeilen) async {
    setState(() => _laeuft = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final anzahl = await uebernehmeImport(
        ref,
        [for (final z in zeilen) z.frage!],
        eingereichtVon: ref.read(meinProfilProvider).value?.name,
      );
      messenger.showSnackBar(SnackBar(
          content: Text('$anzahl ${anzahl == 1 ? "Frage" : "Fragen"} '
              'übernommen.')));
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _laeuft = false;
        _fehler = 'Übernehmen ging nicht: $e';
      });
    }
  }
}


/// Was in einer Datei stand — als eigenes Widget, damit es ohne Dateiauswahl
/// prüfbar ist.
///
/// Die Dateiauswahl ist nativ und im Prüfstand nicht zu bedienen; läge die
/// Anzeige im Bildschirm, wäre der interessante Teil — die Zeilennummern, die
/// Doppelten, die unbekannten Spalten — ungeprüft. Genau die Stellen, an
/// denen sich jemand beim Nachbessern orientiert.
class FragenImportBefund extends StatelessWidget {
  final FrageImportErgebnis ergebnis;
  final String dateiname;
  final bool aktiv;
  final void Function(List<FrageImportZeile>) aufUebernehmen;

  const FragenImportBefund({
    super.key,
    required this.ergebnis,
    required this.dateiname,
    required this.aufUebernehmen,
    this.aktiv = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = ergebnis;
    final gut = e.uebernehmbare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateiname, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          [
            '${gut.length} ${gut.length == 1 ? "Frage" : "Fragen"} bereit',
            if (e.doppelte.isNotEmpty) '${e.doppelte.length} schon vorhanden',
            if (e.fehlerhafte.isNotEmpty)
              '${e.fehlerhafte.length} mit Fehlern',
          ].join(' · '),
          style: theme.textTheme.bodyMedium,
        ),
        if (e.unbekannteSpalten.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Der häufigste Grund, warum eine Spalte „nicht ankommt", ist ein
          // Tippfehler in ihrem Namen — und den sieht man sonst nirgends.
          Text(
            'Diese Spalten kenne ich nicht und habe sie übergangen: '
            '${e.unbekannteSpalten.join(", ")}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.tertiary),
          ),
        ],
        const SizedBox(height: 16),
        if (gut.isNotEmpty)
          FilledButton.icon(
            onPressed: aktiv ? () => aufUebernehmen(gut) : null,
            icon: const Icon(Icons.playlist_add_check),
            label: Text('${gut.length} übernehmen'),
          ),
        if (e.fehlerhafte.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Zeilen zum Nachbessern', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final z in e.fehlerhafte)
            ListTile(
              dense: true,
              leading: const Icon(Icons.error_outline),
              // Die Zeilennummer ist die aus der Tabellenkalkulation —
              // damit man die Zeile dort findet, wo man sie geschrieben hat.
              title: Text('Zeile ${z.zeile}'),
              subtitle: Text(z.fehler!),
            ),
        ],
        if (e.doppelte.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Schon im Bestand', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final z in e.doppelte)
            ListTile(
              dense: true,
              leading: const Icon(Icons.content_copy_outlined),
              title: Text('Zeile ${z.zeile}'),
              subtitle: Text(z.frage!.frage),
            ),
        ],
      ],
    );
  }
}
