/// equipment_detail_screen.dart – Full equipment detail view.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/images/image_capture.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/equipment_type_sync.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/core/widgets/abteilung_switcher.dart';
import 'package:fwapp/core/widgets/geteilter_bestand_hinweis.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
import 'package:fwapp/features/feedback/data/feedback_repository.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_item.dart';
import 'package:fwapp/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/equipment/presentation/screens/image_library_screen.dart';
import 'package:fwapp/features/inspection/presentation/widgets/equipment_instances_section.dart';

class EquipmentDetailScreen extends ConsumerWidget {
  final int equipmentId;
  const EquipmentDetailScreen({super.key, required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(equipmentDetailProvider(equipmentId));

    return itemAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
      data: (item) {
        if (item == null) {
          return const Scaffold(
              body: Center(child: Text('Gerät nicht gefunden.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(item.name),
            actions: [
              if (ref.watch(canEditProvider)) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Bearbeiten',
                  onPressed: () =>
                      context.push('/equipment/$equipmentId/edit'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Weitere Aktionen',
                  // Die Detailseite liegt in der ShellRoute: Ohne den
                  // Wurzel-Navigator läge das Menü UNTER der
                  // NavigationBar (AGENTS.md § Stolperfallen).
                  useRootNavigator: true,
                  itemBuilder: (_) => [
                    // Vorschlagen kann man nur, was NICHT schon im Katalog
                    // steht — und nur angemeldet, denn der Vorschlag läuft
                    // über die Feedback-Tabelle (Issue #103).
                    if (item.libraryEquipmentId == null &&
                        ref.read(sessionStreamProvider).value != null)
                      const PopupMenuItem(
                        value: 'vorschlagen',
                        child: ListTile(
                          leading: Icon(Icons.outbox_outlined),
                          title: Text('Für den Katalog vorschlagen'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'entfernen',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Gerät entfernen'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'entfernen') _entfernen(context, ref, item);
                    if (v == 'vorschlagen') _vorschlagen(context, ref, item);
                  },
                ),
              ],
              const AbteilungAction(),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Photo or category pictogram banner
              EquipmentAvatar(
                imagePath: item.imagePath,
                functions: item.equipmentFunctions,
                size: 200,
                width: double.infinity,
              ),

              // Symbolbild-Hinweis: automatisch zugeordnetes Piktogramm aus
              // der Bildbibliothek, kein verifiziertes Foto.
              if (isPictogramPath(item.imagePath)) ...[
                const SizedBox(height: 6),
                const Center(
                  child: Chip(
                    avatar: Icon(Icons.auto_awesome, size: 16),
                    label: Text('Symbolbild – kein verifiziertes Foto'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],

              // Photo workflow (M2): admins capture/replace the photo right
              // here — one tap per device on the Gerätehaus walk-through.
              if (ref.watch(canEditProvider)) ...[
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: Text(item.imagePath == null ||
                            item.imagePath!.isEmpty ||
                            isPictogramPath(item.imagePath)
                        ? 'Foto aufnehmen'
                        : 'Foto ersetzen'),
                    onPressed: () => _changeImage(context, ref, item),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Woher kommt dieses Gerät — nur von hier oder aus dem
              // geteilten Bestand der Gesamtwehr (Stufe ②, Issue #99)?
              if (item.typeDirty && item.remoteTypeId != null) ...[
                const GeteilterBestandHinweis(
                  offen: true,
                  text: 'Änderung noch nicht verteilt — sie geht beim '
                      'nächsten Aktualisieren an die Gesamtwehr.',
                ),
                const SizedBox(height: 12),
              ] else if (item.remoteTypeId != null) ...[
                const GeteilterBestandHinweis(
                  text: 'Geteilter Bestand der Gesamtwehr — dieses Gerät '
                      'steht allen Abteilungen gleich zur Verfügung.',
                ),
                const SizedBox(height: 12),
              ],

              // Custom item banner
              if (item.isCustom)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Benutzerdefiniertes Gerät – nicht aus der Bibliothek',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),

              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Beschreibung',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(item.description),
              ],

              // Equipment Functions
              if (item.equipmentFunctions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Funktion',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: item.equipmentFunctions
                      .map((f) => Chip(
                            label: Text(
                                EquipmentFunction.fromJson(f)?.label ??
                                    f),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],

              // Deployment Scenarios
              if (item.deploymentScenarios.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Einsatzszenarien',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: item.deploymentScenarios
                      .map((s) => Chip(
                            label: Text(
                                DeploymentScenario.fromJson(s)?.label ??
                                    s),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                          ))
                      .toList(),
                ),
              ],

              // Typical use (from library)
              if (item.typicalUse.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Typische Verwendung',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                ...item.typicalUse.map((u) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(u)),
                        ],
                      ),
                    )),
              ],

              // Extra attributes (technical data)
              if (item.extraAttributes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Technische Daten',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                ...item.extraAttributes.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.key}: ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Expanded(child: Text('${e.value}')),
                        ],
                      ),
                    )),
              ],

              // Training questions (flashcard content, from library)
              if (item.trainingQuestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Trainingsfragen',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                ...item.trainingQuestions.map((q) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.help_outline, size: 18),
                          const SizedBox(width: 6),
                          Expanded(child: Text(q)),
                        ],
                      ),
                    )),
              ],

              // Physical instances with Prüfterminen (Gerätewart)
              const SizedBox(height: 16),
              EquipmentInstancesSection(equipmentId: equipmentId),

              // Training URL
              if (item.trainingUrl != null &&
                  item.trainingUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Lernmaterial öffnen'),
                  // Kein canLaunchUrl-Vortest: der ist unter Android 11+ von
                  // der Package Visibility abhängig und meldete den Knopf
                  // stumm als tot. launchUrl selbst sagt, ob es geklappt hat.
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final uri = Uri.tryParse(item.trainingUrl!);
                    var opened = false;
                    if (uri != null) {
                      try {
                        opened = await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } catch (e) {
                        appLog.w('Lernmaterial "${item.trainingUrl}" '
                            'ließ sich nicht öffnen: $e');
                      }
                    }
                    if (!opened) {
                      messenger.showSnackBar(SnackBar(
                        content: Text('Link ließ sich nicht öffnen: '
                            '${item.trainingUrl}'),
                      ));
                    }
                  },
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  /// Einen selbst angelegten Gerätetyp für den globalen Katalog vorschlagen
  /// (Issue #103, docs/NUTZERKONZEPT.md §5).
  ///
  /// Der Vorschlag reist auf dem bestehenden Feedback-Weg: Tabelle
  /// `feedback` → Bot → öffentliches Issue mit eigenem Label. Deshalb steht
  /// hier derselbe Öffentlichkeits-Hinweis wie im Feedback-Dialog — der Text
  /// landet für jeden lesbar auf GitHub.
  Future<void> _vorschlagen(
      BuildContext context, WidgetRef ref, EquipmentItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final abteilung = abteilungsName(
      ref.read(selectedAbteilungIdProvider) ??
          ref.read(myAbteilungIdProvider).value,
      ref.read(abteilungenProvider).value ?? const [],
    );
    final text = katalogVorschlagText(
      name: item.name,
      kurzname: item.shortName,
      beschreibung: item.description,
      abteilung: abteilung,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Für den Katalog vorschlagen?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Das geht an die Entwicklung, damit der Typ in den '
                  'mitgelieferten Gerätekatalog aufgenommen werden kann. '
                  'Übermittelt wird genau das hier:'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(text,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
              const SizedBox(height: 12),
              Text(
                'Kein Foto — der Text erscheint öffentlich auf GitHub.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vorschlagen')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await submitFeedback(
        ref.read(supabaseClientProvider),
        type: FeedbackType.katalog,
        message: text,
      );
      messenger.showSnackBar(const SnackBar(
          content: Text('Vorschlag ist raus — danke! 📖')));
    } catch (e) {
      appLog.w('Katalog-Vorschlag fehlgeschlagen', error: e);
      messenger.showSnackBar(const SnackBar(
          content: Text('Senden fehlgeschlagen. Internetverbindung prüfen?')));
    }
  }

  /// Gerät entfernen — löschen oder archivieren (Stufe ②, Issue #99).
  ///
  /// Die Entscheidung trifft nicht der Bedienende, sondern die Verwendung:
  /// Wirklich gelöscht wird nur, was in KEINER anderen Abteilung mehr hängt;
  /// sonst wird der Typ archiviert und überlebt dort, wo er gebraucht wird
  /// (Marcus' Regel, docs/NUTZERKONZEPT.md §4). Zentral ist beides derselbe
  /// Vorgang — der Unterschied ist, was hier ehrlich angesagt wird.
  Future<void> _entfernen(
      BuildContext context, WidgetRef ref, EquipmentItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final typen = ref.read(equipmentTypeSyncProvider);
    final geteilt = item.remoteTypeId != null && typen != null;

    // Was hier hängt, weiß die lokale Datei — auch ohne Netz. Was in den
    // anderen Abteilungen hängt, weiß nur der Server.
    final hier = await ref.read(equipmentRepositoryProvider)
        .verwendungHier(item.id);
    VerwendungAnderswo anderswo;
    try {
      anderswo = geteilt
          ? await typen.verwendungAnderswo(item.id)
          : const VerwendungAnderswo();
    } catch (e) {
      // Ohne die fremden Abteilungen ist „löschen oder archivieren" nicht zu
      // entscheiden. Raten wäre hier der teuerste Fehler: Ein hartes Löschen
      // risse einer anderen Abteilung die Beladung auf.
      appLog.w('Verwendung des Gerätetyps nicht ermittelbar', error: e);
      messenger.showSnackBar(const SnackBar(
          content: Text('Zum Entfernen braucht es eine Serververbindung — '
              'sonst ist nicht zu sehen, ob eine andere Abteilung das '
              'Gerät noch benutzt.')));
      return;
    }
    if (!context.mounted) return;

    final archivieren = anderswo.nurArchivieren;
    final zeilen = <String>[
      if (archivieren)
        '${anderswo.abteilungen} andere '
            '${anderswo.abteilungen == 1 ? "Abteilung benutzt" : "Abteilungen benutzen"} '
            '„${item.name}" noch. Es wird deshalb nur archiviert: Dort '
            'bleibt es erhalten, aus dem gemeinsamen Katalog verschwindet es.'
      else if (geteilt)
        '„${item.name}" wird aus dem geteilten Bestand der Gesamtwehr '
            'gelöscht — in allen Abteilungen. Keine andere Abteilung '
            'benutzt es.'
      else
        '„${item.name}" wird gelöscht.',
      if (hier.zuordnungen + hier.exemplare > 0)
        'Hier hängen daran ${hier.zuordnungen} '
            '${hier.zuordnungen == 1 ? "Zuordnung" : "Zuordnungen"} '
            'und ${hier.exemplare} '
            '${hier.exemplare == 1 ? "Exemplar" : "Exemplare"}. '
            'Sie gehen mit verloren, samt Prüfhistorie.',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(archivieren ? 'Gerät archivieren?' : 'Gerät löschen?'),
        content: SingleChildScrollView(child: Text(zeilen.join('\n\n'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(archivieren ? 'Archivieren' : 'Löschen'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      // Erst zentral, dann lokal: Andersherum wäre das Gerät hier weg und
      // käme beim nächsten vollen Zug wortlos zurück.
      if (geteilt) await typen.ausBestandNehmen(item.id);
      await ref.read(equipmentRepositoryProvider).delete(item.id);
    } on TypKonfliktException {
      messenger.showSnackBar(const SnackBar(
          content: Text('Jemand hat das Gerät zwischenzeitlich geändert. '
              'Bitte erst „Jetzt aktualisieren", dann erneut entscheiden.')));
      return;
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Entfernen fehlgeschlagen: $e')));
      return;
    }

    // Kein `invalidate` hier: Die Liste hängt am Strom und merkt das
    // Löschen von selbst, und ein Auffrischen mitten im Seitenwechsel würde
    // die abgehende Seite noch einmal bauen lassen.
    if (context.mounted) context.pop();
    messenger.showSnackBar(SnackBar(
        content: Text(archivieren
            ? '„${item.name}" archiviert.'
            : '„${item.name}" gelöscht.')));
  }

  /// Bildquelle wählen: Foto (Kamera/Galerie, wird zentral hochgeladen)
  /// oder Symbolbild aus der Bildbibliothek.
  Future<void> _changeImage(
      BuildContext context, WidgetRef ref, EquipmentItem item) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Foto aufnehmen'),
            subtitle: const Text('Wird zentral hochgeladen'),
            onTap: () => Navigator.pop(context, 'photo'),
          ),
          ListTile(
            leading: const Icon(Icons.image_search),
            title: const Text('Symbolbild aus Bildbibliothek'),
            subtitle: const Text('Intuitive Suche über alle Normgeräte'),
            onTap: () => Navigator.pop(context, 'library'),
          ),
        ]),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'library') {
      await _pickFromLibrary(context, ref, item);
    } else {
      await _captureAndUploadPhoto(context, ref, item);
    }
  }

  Future<void> _pickFromLibrary(
      BuildContext context, WidgetRef ref, EquipmentItem item) async {
    final asset = await pickFromImageLibrary(context);
    if (asset == null) return;
    await ref
        .read(equipmentRepositoryProvider)
        .update(item.copyWith(imagePath: asset));
    // Das Symbolbild ist ein mitgeliefertes Asset — es gilt auf jedem Gerät
    // und darf deshalb sofort an die Gesamtwehr (Stufe ②).
    final geteilt =
        await typenSofortTeilen(ref.read(equipmentTypeSyncProvider));
    ref.invalidate(equipmentDetailProvider(item.id));
    ref.invalidate(equipmentListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(geteilt
              ? 'Symbolbild übernommen — alle Abteilungen sehen es.'
              : 'Symbolbild übernommen. Zum Verteilen an alle '
                  'Geräte: Einstellungen → Veröffentlichen.')));
    }
  }

  /// Camera on mobile, gallery/file dialog elsewhere. Uploads to the central
  /// bucket when connected; otherwise the photo stays local to this device.
  Future<void> _captureAndUploadPhoto(
      BuildContext context, WidgetRef ref, EquipmentItem item) async {
    // Quelle waehlen, zuschneiden, drehen (Issue #56). Das Ergebnis liegt als
    // Bytes vor und geht direkt in den Upload — das funktioniert auch in der
    // Web-App, wo es keinen lokalen Dateipfad gibt.
    final image = await captureImage(context);
    if (image == null || !context.mounted) return;

    // Ohne Server bleibt nur der lokale Pfad; in der Web-App gibt es den
    // nicht, dann ist das Foto ohne Upload nicht speicherbar.
    var newPath = image.path;
    var uploaded = false;
    final imageSync = ref.read(imageSyncServiceProvider);
    if (imageSync != null) {
      try {
        newPath = await imageSync.uploadEquipmentImageBytes(
          equipmentId: item.id,
          bytes: image.bytes,
          previousPath: item.imagePath,
        );
        uploaded = true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Foto nur lokal gespeichert – Upload '
                  'fehlgeschlagen: $e')));
        }
      }
    }

    // Kein Pfad und kein Upload: nichts zu speichern. Ohne diese Pruefung
    // wuerde copyWith(imagePath: null) das vorhandene Bild loeschen.
    if (newPath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Foto konnte nicht gespeichert werden — dafür '
                'braucht es eine Serververbindung.')));
      }
      return;
    }

    await ref
        .read(equipmentRepositoryProvider)
        .update(item.copyWith(imagePath: newPath));
    // Nur ein hochgeladenes Foto ist teilbar; ein reiner Gerätepfad bliebe
    // für die anderen Abteilungen tot — der Push hält solche Zeilen selbst
    // zurück, hier wird gar nicht erst danach gefragt.
    final geteilt = uploaded &&
        await typenSofortTeilen(ref.read(equipmentTypeSyncProvider));
    ref.invalidate(equipmentDetailProvider(item.id));
    ref.invalidate(equipmentListProvider);
    if (context.mounted && uploaded) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(geteilt
              ? 'Foto hochgeladen — alle Abteilungen sehen es.'
              : 'Foto hochgeladen. Zum Verteilen an alle Geräte: '
                  'Einstellungen → Veröffentlichen.')));
    }
  }
}
