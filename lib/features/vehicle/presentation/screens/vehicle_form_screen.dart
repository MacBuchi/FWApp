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
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
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

    // Load existing vehicle data once
    if (widget.editId != null && !_loaded) {
      ref.listen(vehicleDetailProvider(widget.editId!), (_, next) {
        next.whenData((v) {
          if (v != null && !_loaded) {
            _loaded = true;
            ref.read(vehicleFormProvider.notifier).load(v);
            _nameCtrl.text = v.name;
            _typeCtrl.text = v.type;
            _plateCtrl.text = v.licensePlate ?? '';
          }
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editId == null ? 'Fahrzeug anlegen' : 'Fahrzeug bearbeiten'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image picker
          GestureDetector(
            onTap: _pickImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: resolveImage(
                path: state.imagePath ?? kPlaceholderAsset,
                width: double.infinity,
                height: 160,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Bild auswählen'),
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
