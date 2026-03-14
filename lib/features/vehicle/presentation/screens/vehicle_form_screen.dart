/// vehicle_form_screen.dart – Create / edit a vehicle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  final int? editId;
  const VehicleFormScreen({super.key, this.editId});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) {
      // Load existing vehicle data once, after the first frame so that
      // Riverpod providers are fully wired up.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final vehicle =
            await ref.read(vehicleDetailProvider(widget.editId!).future);
        if (vehicle != null && mounted) {
          ref.read(vehicleFormProvider.notifier).load(vehicle);
          _nameCtrl.text = vehicle.name;
          _typeCtrl.text = vehicle.type;
          _plateCtrl.text = vehicle.licensePlate ?? '';
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Ask for desired size/quality before opening the gallery
    final sizeOption = await showModalBottomSheet<_ImageSize>(
      context: context,
      builder: (_) => const _ImageSizeSheet(),
    );
    if (sizeOption == null || !mounted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: sizeOption.maxDim,
      maxHeight: sizeOption.maxDim,
      imageQuality: sizeOption.quality,
    );
    if (file != null && mounted) {
      ref.read(vehicleFormProvider.notifier).setImagePath(file.path);
    }
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(vehicleFormProvider.notifier)
        .submit(editId: widget.editId);
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehicleFormProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editId == null ? 'Fahrzeug anlegen' : 'Fahrzeug bearbeiten'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image preview – tap to change
          GestureDetector(
            onTap: _pickImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  resolveImage(
                    path: state.imagePath ?? kPlaceholderAsset,
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
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Bild auswählen / ändern'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name*'),
            onChanged: ref.read(vehicleFormProvider.notifier).setName,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _typeCtrl,
            decoration:
                const InputDecoration(labelText: 'Fahrzeugtyp* (z.B. HLF 20)'),
            onChanged: ref.read(vehicleFormProvider.notifier).setType,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _plateCtrl,
            decoration:
                const InputDecoration(labelText: 'Kennzeichen (optional)'),
            onChanged:
                ref.read(vehicleFormProvider.notifier).setLicensePlate,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.isSubmitting ? null : _submit,
            child: state.isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}

// ─── Image size selection ──────────────────────────────────────────────────

enum _ImageSize {
  original(null, null, 'Original', 'Volle Auflösung, keine Komprimierung'),
  large(1024, 85, 'Groß', 'Max. 1024 × 1024 px  –  empfohlen'),
  medium(600, 80, 'Mittel', 'Max. 600 × 600 px'),
  small(300, 75, 'Klein', 'Max. 300 × 300 px');

  const _ImageSize(this.maxDim, this.quality, this.label, this.sublabel);
  final double? maxDim;
  final int? quality;
  final String label;
  final String sublabel;
}

class _ImageSizeSheet extends StatelessWidget {
  const _ImageSizeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Bildgröße wählen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final size in _ImageSize.values)
              ListTile(
                leading: Icon(_sizeIcon(size)),
                title: Text(size.label),
                subtitle: Text(size.sublabel),
                onTap: () => Navigator.of(context).pop(size),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _sizeIcon(_ImageSize size) => switch (size) {
        _ImageSize.original => Icons.image_outlined,
        _ImageSize.large    => Icons.photo_size_select_large,
        _ImageSize.medium   => Icons.photo_size_select_actual,
        _ImageSize.small    => Icons.photo_size_select_small,
      };
}
