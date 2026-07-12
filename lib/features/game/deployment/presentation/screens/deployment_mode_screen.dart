 /// deployment_mode_screen.dart – Multi-vehicle deployment analysis.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class DeploymentModeScreen extends ConsumerStatefulWidget {
  const DeploymentModeScreen({super.key});

  @override
  ConsumerState<DeploymentModeScreen> createState() =>
      _DeploymentModeState();
}

class _DeploymentModeState extends ConsumerState<DeploymentModeScreen> {
  final Set<int> _selectedVehicleIds = {};
  List<_DeploymentEntry> _results = [];
  bool _computed = false;
  bool _computing = false;

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einsatzplanung')),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (vehicles) => Column(
          children: [
            // Vehicle selector
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fahrzeuge auswählen:',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: vehicles.map((v) {
                      final sel =
                          _selectedVehicleIds.contains(v.id);
                      return FilterChip(
                        label: Text(v.name),
                        selected: sel,
                        onSelected: (val) => setState(() {
                          if (val) {
                            _selectedVehicleIds.add(v.id);
                          } else {
                            _selectedVehicleIds.remove(v.id);
                          }
                          _computed = false;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: _computing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.calculate),
                    label: const Text('Beladung analysieren'),
                    onPressed: _selectedVehicleIds.isEmpty || _computing
                        ? null
                        : () => _compute(vehicles),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Results
            if (_computed)
              Expanded(
                child: _results.isEmpty
                    ? const Center(
                        child: Text('Keine gemeinsamen Geräte gefunden.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final e = _results[i];
                          return ListTile(
                            leading: resolveImage(
                              path: e.imagePath ?? kPlaceholderAsset,
                              width: 44,
                              height: 44,
                            ),
                            title: Text(e.name),
                            subtitle: Text(e.functions
                                .map((f) =>
                                    EquipmentFunction.fromJson(f)
                                        ?.label ??
                                    f)
                                .join(', ')),
                            trailing: Text(
                              '× ${e.totalQuantity}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _compute(List<Vehicle> vehicles) async {
    setState(() => _computing = true);
    final db = ref.read(appDatabaseProvider);
    final Map<int, _DeploymentEntry> totals = {};

    for (final id in _selectedVehicleIds) {
      final assignments = await db.assignmentDao.getByVehicle(id);
      for (final a in assignments) {
        if (totals.containsKey(a.equipmentId)) {
          totals[a.equipmentId] = totals[a.equipmentId]!
              .copyWithQuantity(totals[a.equipmentId]!.totalQuantity + a.quantity);
        } else {
          final eq = await db.equipmentDao.getById(a.equipmentId);
          if (eq == null) continue;
          totals[a.equipmentId] = _DeploymentEntry(
            equipmentId: eq.id,
            name: eq.name,
            imagePath: eq.imagePath,
            functions: jsonToStringList(eq.equipmentFunctionsJson),
            totalQuantity: a.quantity,
          );
        }
      }
    }

    final sorted = totals.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      _results = sorted;
      _computed = true;
      _computing = false;
    });
  }
}

class _DeploymentEntry {
  final int equipmentId;
  final String name;
  final String? imagePath;
  final List<String> functions;
  final int totalQuantity;

  const _DeploymentEntry({
    required this.equipmentId,
    required this.name,
    this.imagePath,
    required this.functions,
    required this.totalQuantity,
  });

  _DeploymentEntry copyWithQuantity(int qty) => _DeploymentEntry(
        equipmentId: equipmentId,
        name: name,
        imagePath: imagePath,
        functions: functions,
        totalQuantity: qty,
      );
}
