/// equipment_form_screen.dart – Create / edit an equipment item.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_item.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';

class EquipmentFormScreen extends ConsumerStatefulWidget {
  final int? editId;
  const EquipmentFormScreen({super.key, this.editId});

  @override
  ConsumerState<EquipmentFormScreen> createState() =>
      _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends ConsumerState<EquipmentFormScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String? _imagePath;
  final Set<String> _functions = {};
  final Set<String> _scenarios = {};
  bool _isSubmitting = false;
  String? _error;
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _imagePath = file.path);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name ist ein Pflichtfeld.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(equipmentRepositoryProvider);
      final item = EquipmentItem(
        id: widget.editId ?? 0,
        name: _nameCtrl.text.trim(),
        equipmentFunctions: _functions.toList(),
        deploymentScenarios: _scenarios.toList(),
        description: _descCtrl.text.trim(),
        imagePath: _imagePath,
        trainingUrl: _urlCtrl.text.trim().isEmpty
            ? null
            : _urlCtrl.text.trim(),
        libraryEquipmentId: null,
        isCustom: true,
        extraAttributes: {},
        updatedAt: DateTime.now(),
      );
      if (widget.editId == null) {
        await repo.insert(item);
      } else {
        await repo.update(item);
      }
      ref.invalidate(equipmentListProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Fehler beim Speichern: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _loadExisting(EquipmentItem item) {
    _nameCtrl.text = item.name;
    _descCtrl.text = item.description;
    _urlCtrl.text = item.trainingUrl ?? '';
    setState(() {
      _imagePath = item.imagePath;
      _functions
        ..clear()
        ..addAll(item.equipmentFunctions);
      _scenarios
        ..clear()
        ..addAll(item.deploymentScenarios);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.editId != null && !_loaded) {
      ref.listen(equipmentDetailProvider(widget.editId!), (_, next) {
        next.whenData((item) {
          if (item != null && !_loaded) {
            _loaded = true;
            _loadExisting(item);
          }
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.editId == null ? 'Gerät anlegen' : 'Gerät bearbeiten'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: resolveImage(
                path: _imagePath ?? kPlaceholderAsset,
                width: double.infinity,
                height: 140,
              ),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Bild auswählen'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name*'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Beschreibung'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            decoration:
                const InputDecoration(labelText: 'Lernmaterial-URL'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          Text('Funktion',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: EquipmentFunction.values.map((f) {
              final selected = _functions.contains(f.jsonKey);
              return FilterChip(
                label: Text(f.label, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _functions.add(f.jsonKey);
                  } else {
                    _functions.remove(f.jsonKey);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Einsatzszenarien',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: DeploymentScenario.values.map((s) {
              final selected = _scenarios.contains(s.jsonKey);
              return FilterChip(
                label: Text(s.label,
                    style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _scenarios.add(s.jsonKey);
                  } else {
                    _scenarios.remove(s.jsonKey);
                  }
                }),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
