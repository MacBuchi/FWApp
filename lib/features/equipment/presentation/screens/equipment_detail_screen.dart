/// equipment_detail_screen.dart – Full equipment detail view.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
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
              if (ref.watch(canEditProvider))
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Bearbeiten',
                  onPressed: () =>
                      context.push('/equipment/$equipmentId/edit'),
                ),
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
    ref.invalidate(equipmentDetailProvider(item.id));
    ref.invalidate(equipmentListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Symbolbild übernommen. Zum Verteilen an alle '
              'Geräte: Einstellungen → Veröffentlichen.')));
    }
  }

  /// Camera on mobile, gallery/file dialog elsewhere. Uploads to the central
  /// bucket when connected; otherwise the photo stays local to this device.
  Future<void> _captureAndUploadPhoto(
      BuildContext context, WidgetRef ref, EquipmentItem item) async {
    final picker = ImagePicker();
    final source = picker.supportsImageSource(ImageSource.camera)
        ? ImageSource.camera
        : ImageSource.gallery;
    // Bounded pick: forces JPEG (no iOS HEIC) and keeps originals small.
    final file = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (file == null || !context.mounted) return;

    var newPath = file.path;
    var uploaded = false;
    final imageSync = ref.read(imageSyncServiceProvider);
    if (imageSync != null) {
      try {
        newPath = await imageSync.uploadEquipmentImage(
          equipmentId: item.id,
          localPath: file.path,
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

    await ref
        .read(equipmentRepositoryProvider)
        .update(item.copyWith(imagePath: newPath));
    ref.invalidate(equipmentDetailProvider(item.id));
    ref.invalidate(equipmentListProvider);
    if (context.mounted && uploaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto hochgeladen. Zum Verteilen an alle Geräte: '
              'Einstellungen → Veröffentlichen.')));
    }
  }
}
