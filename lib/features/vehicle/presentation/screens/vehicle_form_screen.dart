/// vehicle_form_screen.dart – Create / edit a vehicle.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/images/image_capture.dart';
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
    // Quelle waehlen, zuschneiden, drehen — gemeinsam mit den Geraetebildern
    // (Issue #56). Die Groesse wird nicht mehr vorab abgefragt: captureImage
    // rechnet das Ergebnis ohnehin auf das Auslieferungsbudget.
    final image = await captureImage(context);
    if (image?.path == null || !mounted) return;
    ref.read(vehicleFormProvider.notifier).setImagePath(image!.path!);
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
