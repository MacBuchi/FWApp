/// equipment_detail_screen.dart – Full equipment detail view.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
import 'package:fwapp/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
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
              if (ref.watch(isAdminProvider))
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
                  onPressed: () async {
                    final uri = Uri.tryParse(item.trainingUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
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
}
