/// equipment_form_screen.dart – Create / edit an equipment item.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:fwapp/core/database/standard_catalog.dart';
import 'package:fwapp/core/images/image_capture.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_item.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/equipment/presentation/screens/image_library_screen.dart';

class EquipmentFormScreen extends ConsumerStatefulWidget {
  final int? editId;

  /// Vorbelegter Name — kommt aus dem Fach-Picker („Gerät zuweisen" →
  /// „neu anlegen"), damit der Suchbegriff nicht doppelt getippt wird.
  final String? initialName;

  const EquipmentFormScreen({super.key, this.editId, this.initialName});

  @override
  ConsumerState<EquipmentFormScreen> createState() =>
      _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends ConsumerState<EquipmentFormScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String? _imagePath;
  String? _originalImagePath;
  final Set<String> _functions = {};
  final Set<String> _scenarios = {};
  bool _isSubmitting = false;
  String? _error;

  /// Katalog für das automatische Symbolbild — lädt einmal im Hintergrund.
  StandardCatalog? _katalog;

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final item =
            await ref.read(equipmentDetailProvider(widget.editId!).future);
        if (item != null && mounted) {
          _loadExisting(item);
        }
      });
    } else {
      _nameCtrl.text = widget.initialName ?? '';
    }
    StandardCatalog.load().then((k) {
      if (!mounted) return;
      _katalog = k;
      _autoSymbolbild();
    });
  }

  /// Wählt beim Benennen automatisch das Symbolbild des passenden
  /// Katalog-Geräts — der Gerätewart geht Raum für Raum durch und soll
  /// nicht für jedes Normgerät die Bildbibliothek aufmachen müssen. Ein
  /// echtes Foto wird NIE angefasst; ein automatisch gewähltes Symbolbild
  /// verschwindet wieder, wenn der Name nicht mehr passt.
  void _autoSymbolbild() {
    if (_imagePath != null && !isPictogramPath(_imagePath)) return;
    final id = _katalog?.idFuerName(_nameCtrl.text);
    final neu = id == null ? null : pictogramPath(id);
    if (neu != _imagePath) setState(() => _imagePath = neu);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Drei Wege in EINEM Menue: Die Quelle wird hier schon erfragt, deshalb
    // bekommt captureImage sie uebergeben und zeigt kein zweites Sheet.
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          if (cameraAvailable)
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Aus Galerie'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.image_search),
            title: const Text('Aus Bildbibliothek (Symbolbild)'),
            onTap: () => Navigator.pop(context, 'library'),
          ),
        ]),
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'library') {
      final asset = await pickFromImageLibrary(context);
      if (asset != null) setState(() => _imagePath = asset);
      return;
    }

    final image = await captureImage(
      context,
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (image?.path == null || !mounted) return;
    setState(() => _imagePath = image!.path!);
  }

  /// Uploads a freshly picked local image to the central bucket and rewrites
  /// imagePath to its supabase:// marker. Local mode or upload failure keeps
  /// the local path — the device that took the photo can always show it.
  Future<void> _uploadImageIfPossible(int equipmentId) async {
    final imageSync = ref.read(imageSyncServiceProvider);
    if (imageSync == null || !isLocalImagePath(_imagePath)) return;
    final repo = ref.read(equipmentRepositoryProvider);
    try {
      final marker = await imageSync.uploadEquipmentImage(
        equipmentId: equipmentId,
        localPath: _imagePath!,
        previousPath: _originalImagePath,
      );
      final saved = await repo.getById(equipmentId);
      if (saved != null) {
        await repo.update(saved.copyWith(imagePath: marker));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Foto nur lokal gespeichert – Upload '
                'fehlgeschlagen: $e')));
      }
    }
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
      int? newId;
      if (widget.editId == null) {
        newId = await repo.insert(item);
        await _uploadImageIfPossible(newId);
      } else {
        await repo.update(item);
        await _uploadImageIfPossible(widget.editId!);
      }
      ref.invalidate(equipmentListProvider);
      // Die neue ID ist das Pop-Ergebnis: Der Fach-Picker („neu anlegen")
      // weist das frisch angelegte Gerät damit direkt dem offenen Fach zu.
      if (mounted) context.pop(newId);
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
      _originalImagePath = item.imagePath;
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
              child: Stack(
                children: [
                  resolveImage(
                    path: _imagePath ?? kPlaceholderAsset,
                    width: double.infinity,
                    height: 180,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
                ],
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
          if (isPictogramPath(_imagePath))
            const Center(
              child: Chip(
                avatar: Icon(Icons.auto_awesome, size: 16),
                label: Text('Symbolbild – kein verifiziertes Foto'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name*'),
            onChanged: (_) => _autoSymbolbild(),
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
