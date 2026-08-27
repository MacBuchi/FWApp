/// fahrzeug_unterlagen.dart – Unterlagen und Bilder am Fahrzeug (Issue #182).
///
/// Betriebsanleitung, Fahrzeugschein, Prüfbescheinigung. Der Punkt ist nicht
/// das Anhängen, sondern das **Lesen ohne Netz**: Das Fahrzeug steht selten
/// im WLAN des Gerätehauses, und eine Anleitung, die man nur mit Empfang
/// öffnen kann, fehlt genau dann, wenn sie gebraucht wird.
///
/// Deshalb sagt jede Zeile ausdrücklich, ob sie **auf diesem Gerät** liegt —
/// und es gibt einen Knopf, der alles auf einmal holt.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/vehicle/data/anhang_speicher.dart';
import 'package:fwapp/features/vehicle/presentation/providers/anhang_providers.dart';
import 'package:open_filex/open_filex.dart';

class FahrzeugUnterlagen extends ConsumerStatefulWidget {
  const FahrzeugUnterlagen({super.key, required this.vehicleId});

  final int vehicleId;

  @override
  ConsumerState<FahrzeugUnterlagen> createState() => _FahrzeugUnterlagenState();
}

class _FahrzeugUnterlagenState extends ConsumerState<FahrzeugUnterlagen> {
  bool _laeuft = false;

  @override
  Widget build(BuildContext context) {
    final anhaengeAsync =
        ref.watch(fahrzeugAnhaengeProvider(widget.vehicleId));
    final darfBearbeiten = ref.watch(canEditProvider);
    final anhaenge = anhaengeAsync.value ?? const <VehicleAttachmentData>[];
    final fehlenLokal =
        anhaenge.where((a) => !_liegtHier(a)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Unterlagen',
                  style: Theme.of(context).textTheme.titleMedium),
              if (darfBearbeiten)
                TextButton.icon(
                  onPressed: _laeuft ? null : _hinzufuegen,
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('Anhängen'),
                ),
            ],
          ),
        ),
        if (anhaenge.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              darfBearbeiten
                  ? 'Noch nichts angehängt. Betriebsanleitung, Fahrzeugschein '
                      'oder Prüfbescheinigung als PDF oder Foto.'
                  : 'Für dieses Fahrzeug sind keine Unterlagen hinterlegt.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ...anhaenge.map(_zeile),
        // Der Knopf steht nur da, wenn er etwas zu tun hat — und er ist der
        // Unterschied zwischen „angehängt" und „im Einsatz verfügbar".
        if (fehlenLokal.isNotEmpty && !kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: OutlinedButton.icon(
              onPressed: _laeuft ? null : () => _allesHolen(fehlenLokal),
              icon: const Icon(Icons.download_for_offline_outlined, size: 18),
              label: Text('${fehlenLokal.length} für den Einsatz '
                  'herunterladen'),
            ),
          ),
      ],
    );
  }

  /// Liegt die Datei wirklich auf diesem Gerät? Ein Pfad allein genügt
  /// nicht — die Datei kann gelöscht worden sein, und dann wäre die
  /// Offline-Zusage eine Behauptung.
  bool _liegtHier(VehicleAttachmentData a) {
    final pfad = a.localPath;
    if (pfad == null || kIsWeb) return false;
    return File(pfad).existsSync();
  }

  Widget _zeile(VehicleAttachmentData a) {
    final theme = Theme.of(context);
    final hier = _liegtHier(a);
    return ListTile(
      leading: a.kind == 'image' && hier
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: resolveImage(
                  path: a.localPath, width: 40, height: 40, fit: BoxFit.cover),
            )
          : Icon(a.kind == 'image'
              ? Icons.image_outlined
              : Icons.picture_as_pdf_outlined),
      title: Text(a.title),
      subtitle: Row(
        children: [
          Icon(hier ? Icons.offline_pin : Icons.cloud_outlined,
              size: 14,
              color: hier ? Colors.green.shade700 : theme.colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            hier ? 'auf diesem Gerät' : 'nur auf dem Server',
            style: theme.textTheme.bodySmall?.copyWith(
                color:
                    hier ? Colors.green.shade700 : theme.colorScheme.outline),
          ),
          if (a.sizeBytes > 0) ...[
            const SizedBox(width: 8),
            Text(_groesse(a.sizeBytes), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      trailing: ref.watch(canEditProvider)
          ? IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: theme.colorScheme.error,
              tooltip: 'Entfernen',
              onPressed: _laeuft ? null : () => _entfernen(a),
            )
          : null,
      onTap: _laeuft ? null : () => _oeffnen(a),
    );
  }

  String _groesse(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  Future<void> _hinzufuegen() async {
    final auswahl = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final datei = auswahl?.files.singleOrNull;
    if (datei == null || !mounted) return;

    final bytes = datei.bytes ??
        (datei.path == null ? null : await File(datei.path!).readAsBytes());
    if (bytes == null) {
      _sagen('Die Datei ließ sich nicht lesen.');
      return;
    }

    setState(() => _laeuft = true);
    try {
      await ref.read(anhangSpeicherProvider).hinzufuegen(
            vehicleId: widget.vehicleId,
            dateiname: datei.name,
            bytes: bytes,
            abteilungId: ref.read(anhangAbteilungProvider),
          );
    } on AnhangAbgelehnt catch (e) {
      _sagen(e.grund);
    } catch (e) {
      _sagen('Anhängen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  Future<void> _oeffnen(VehicleAttachmentData a) async {
    setState(() => _laeuft = true);
    final pfad = await ref.read(anhangSpeicherProvider).sicherstellenLokal(a);
    if (!mounted) return;
    setState(() => _laeuft = false);

    if (pfad == null) {
      _sagen('Die Datei liegt nicht auf diesem Gerät und ließ sich gerade '
          'nicht laden.');
      return;
    }
    // `open_filex` und nicht `launchUrl`: Ein file://-URI wird auf Android
    // seit Version 7 abgelehnt, es braucht einen FileProvider.
    final ergebnis = await OpenFilex.open(pfad);
    if (!mounted || ergebnis.type == ResultType.done) return;
    _sagen('Kein Programm zum Öffnen gefunden (${a.mimeType}).');
  }

  Future<void> _allesHolen(List<VehicleAttachmentData> fehlend) async {
    setState(() => _laeuft = true);
    var geholt = 0;
    for (final a in fehlend) {
      if (await ref.read(anhangSpeicherProvider).sicherstellenLokal(a) !=
          null) {
        geholt++;
      }
    }
    if (!mounted) return;
    setState(() => _laeuft = false);
    _sagen(geholt == fehlend.length
        ? 'Alle Unterlagen liegen jetzt auf diesem Gerät.'
        : '$geholt von ${fehlend.length} geladen — der Rest braucht eine '
            'Verbindung.');
  }

  Future<void> _entfernen(VehicleAttachmentData a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unterlage entfernen?'),
        content: Text('„${a.title}" wird von diesem Gerät und vom Server '
            'gelöscht. Das lässt sich nicht rückgängig machen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Entfernen')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _laeuft = true);
    await ref.read(anhangSpeicherProvider).entfernen(a,
        abteilungId: ref.read(anhangAbteilungProvider));
    if (mounted) setState(() => _laeuft = false);
  }

  void _sagen(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }
}
