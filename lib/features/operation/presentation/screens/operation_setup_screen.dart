/// operation_setup_screen.dart – Einsatz starten: Fahrzeuge und Einsatzart
/// wählen, dann ins virtuelle Ausladen.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
import 'package:fwapp/features/operation/presentation/providers/operation_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class OperationSetupScreen extends ConsumerStatefulWidget {
  const OperationSetupScreen({super.key});

  @override
  ConsumerState<OperationSetupScreen> createState() =>
      _OperationSetupScreenState();
}

class _OperationSetupScreenState extends ConsumerState<OperationSetupScreen> {
  final Set<int> _selectedVehicles = {};
  DeploymentScenario? _scenario;

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einsatz starten')),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (vehicles) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Fahrzeuge im Einsatz',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (vehicles.isEmpty)
              const Text('Noch keine Fahrzeuge angelegt.',
                  style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: vehicles
                    .map((v) => FilterChip(
                          label: Text(v.name),
                          selected: _selectedVehicles.contains(v.id),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              _selectedVehicles.add(v.id);
                            } else {
                              _selectedVehicles.remove(v.id);
                            }
                          }),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 24),
            Text('Einsatzart (optional)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
                'Passende Geräte werden beim Ausladen hervorgehoben.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<DeploymentScenario?>(
              initialValue: _scenario,
              decoration: const InputDecoration(labelText: 'Einsatzart'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Keine Auswahl')),
                ...DeploymentScenario.values.map((s) =>
                    DropdownMenuItem(value: s, child: Text(s.label))),
              ],
              onChanged: (v) => setState(() => _scenario = v),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Einsatz starten'),
              onPressed: _selectedVehicles.isEmpty
                  ? null
                  : () {
                      ref.read(operationProvider.notifier).start(
                            vehicleIds: _selectedVehicles.toList(),
                            scenario: _scenario,
                          );
                      context.pushReplacement('/operation/run');
                    },
            ),
          ],
        ),
      ),
    );
  }
}
