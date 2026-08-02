/// vehicle_template_screen.dart – Fahrzeug aus einer Vorlage anlegen
/// (Issue #55).
///
/// Zwei Wege, wie im Issue beschrieben: nur mit den Geräteräumen, oder gleich
/// mit der zum Typ passenden Normbeladung. Der zweite steht nur zur Wahl, wo
/// eine belegbare Liste vorliegt — erfundene Beladung erspart keine Arbeit,
/// sie verlagert sie nur ins Aufräumen.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/images/image_capture.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/vehicle/data/vehicle_template.dart';
import 'package:fwapp/features/vehicle/data/vehicle_template_service.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class VehicleTemplateScreen extends ConsumerWidget {
  const VehicleTemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(vehicleTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fahrzeug aus Vorlage')),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Keine Vorlagen verfügbar.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = templates[i];
              return ListTile(
                leading: const Icon(Icons.fire_truck),
                title: Text(t.name),
                subtitle: Text(
                  t.hasLoading
                      ? '${t.compartments.length} Geräteräume · '
                          '${t.loading!.items.length} Positionen Normbeladung'
                      : '${t.compartments.length} Geräteräume · '
                          'keine hinterlegte Beladung',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _startFrom(context, ref, t),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startFrom(
    BuildContext context,
    WidgetRef ref,
    VehicleTemplate template,
  ) async {
    final options = await showModalBottomSheet<_TemplateOptions>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TemplateOptionsSheet(template: template),
    );
    if (options == null || !context.mounted) return;

    final service = VehicleTemplateService(ref.read(appDatabaseProvider));
    try {
      final result = await service.apply(
        template,
        name: options.name,
        licensePlate: options.plate.isEmpty ? null : options.plate,
        imagePath: options.imagePath,
        withLoading: options.withLoading,
      );
      ref.invalidate(vehicleListProvider);
      if (!context.mounted) return;

      var message = result.itemCount > 0
          ? '${options.name} angelegt: ${result.compartmentCount} Geräteräume, '
              '${result.itemCount} Positionen im Sammelfach.'
          : '${options.name} angelegt: ${result.compartmentCount} Geräteräume.';
      // Fehlende Positionen laut sagen: Wer „mit Normbeladung" wählt und
      // still ein Drittel weniger bekommt, merkt es sonst erst am Fahrzeug
      // (Issue #86 entstand genau so).
      if (result.missingEquipment.isNotEmpty) {
        message += ' ${result.missingEquipment.length} Positionen ohne '
            'Katalogeintrag übersprungen.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        duration: result.missingEquipment.isEmpty
            ? const Duration(seconds: 4)
            : const Duration(seconds: 8),
      ));
      // Zurück zur Liste, nicht nur ein Schritt: Die Vorlagenauswahl hinter
      // sich zu lassen ist nach dem Anlegen die richtige Erwartung.
      context.go('/vehicles');
    } catch (e, s) {
      appLog.w('Fahrzeug aus Vorlage fehlgeschlagen', error: e, stackTrace: s);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anlegen fehlgeschlagen: $e')),
      );
    }
  }
}

class _TemplateOptions {
  final String name;
  final String plate;
  final String? imagePath;
  final bool withLoading;

  const _TemplateOptions({
    required this.name,
    required this.plate,
    required this.withLoading,
    this.imagePath,
  });
}

class _TemplateOptionsSheet extends StatefulWidget {
  const _TemplateOptionsSheet({required this.template});

  final VehicleTemplate template;

  @override
  State<_TemplateOptionsSheet> createState() => _TemplateOptionsSheetState();
}

class _TemplateOptionsSheetState extends State<_TemplateOptionsSheet> {
  late final _nameCtrl = TextEditingController(text: widget.template.name);
  final _plateCtrl = TextEditingController();
  String? _imagePath;
  var _withLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await captureImage(context);
    if (image?.path == null || !mounted) return;
    setState(() => _imagePath = image!.path);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return Padding(
      // Tastatur schiebt den Inhalt hoch, statt die Knöpfe zu verdecken.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.name, style: Theme.of(context).textTheme.titleLarge),
              if (t.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(t.note, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name*',
                  helperText: 'z. B. „HLF 20 (Florian 1/46)"',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _plateCtrl,
                decoration:
                    const InputDecoration(labelText: 'Kennzeichen (optional)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera),
                label: Text(_imagePath == null
                    ? 'Bild hinzufügen (optional)'
                    : 'Bild ausgewählt — ändern'),
                onPressed: _pickImage,
              ),
              const SizedBox(height: 16),
              if (t.hasLoading)
                _LoadingChoice(
                  template: t,
                  withLoading: _withLoading,
                  onChanged: (v) => setState(() => _withLoading = v),
                )
              else
                _NoLoadingHint(compartments: t.compartments.length),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        final name = _nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Bitte einen Namen eingeben.')),
                          );
                          return;
                        }
                        Navigator.pop(
                          context,
                          _TemplateOptions(
                            name: name,
                            plate: _plateCtrl.text.trim(),
                            imagePath: _imagePath,
                            withLoading: _withLoading,
                          ),
                        );
                      },
                      child: const Text('Anlegen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Die Wahl „nur Geräteräume" oder „mit Normbeladung" — samt Herkunft der
/// Liste, damit niemand sie für den geprüften Stand der eigenen Wehr hält.
class _LoadingChoice extends StatelessWidget {
  const _LoadingChoice({
    required this.template,
    required this.withLoading,
    required this.onChanged,
  });

  final VehicleTemplate template;
  final bool withLoading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioGroup<bool>(
          groupValue: withLoading,
          onChanged: (v) => onChanged(v ?? false),
          child: Column(
            children: [
              RadioListTile<bool>(
                value: false,
                contentPadding: EdgeInsets.zero,
                title: const Text('Nur Geräteräume'),
                subtitle: Text(
                    '${template.compartments.length} leere Fächer anlegen'),
              ),
              RadioListTile<bool>(
                value: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Mit Normbeladung'),
                subtitle: Text('${template.loading!.items.length} Positionen '
                    'in ein Sammelfach, von dort selbst zuordnen'),
              ),
            ],
          ),
        ),
        if (withLoading) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ungeprüfte Liste — bitte durchgehen',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Die Norm schreibt vor, WAS an Bord ist — nicht, in welchem '
                  'Geräteraum. Die Positionen landen deshalb gesammelt in '
                  'einem Fach, das ihr selbst auf eure Räume verteilt.\n\n'
                  'Quelle: ${template.loading!.source}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NoLoadingHint extends StatelessWidget {
  const _NoLoadingHint({required this.compartments});

  final int compartments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Für diesen Fahrzeugtyp ist keine Beladung hinterlegt — es werden '
        '$compartments leere Geräteräume angelegt. Die Beladung kommt über '
        'den Import-Assistenten oder von Hand dazu.',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
