/// import_screen.dart – Excel / CSV Beladeplan import screen.

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _importing = false;
  _ImportResult? _result;

  Future<void> _pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (picked == null || picked.files.first.bytes == null) return;

    setState(() {
      _importing = true;
      _result = null;
    });

    try {
      final bytes = picked.files.first.bytes!;
      final result = await _importExcel(bytes);
      setState(() => _result = result);

      // Invalidate providers
      ref.invalidate(vehicleListStreamProvider);
      ref.invalidate(vehicleListProvider);
      ref.invalidate(equipmentListProvider);
      ref.invalidate(equipmentListStreamProvider);
    } catch (e) {
      setState(() => _result = _ImportResult(
            success: 0,
            errors: 1,
            customItems: [],
            errorMessages: ['Import fehlgeschlagen: $e'],
          ));
    } finally {
      setState(() => _importing = false);
    }
  }

  Future<_ImportResult> _importExcel(List<int> bytes) async {
    final db = ref.read(appDatabaseProvider);
    final excel = Excel.decodeBytes(bytes);

    int success = 0;
    int errors = 0;
    final errorMessages = <String>[];
    final customItems = <String>[];

    await db.transaction(() async {
      for (final table in excel.tables.values) {
        final rows = table.rows;
        if (rows.isEmpty) continue;

        // Detect header row
        final header = rows.first
            .map((c) => (c?.value?.toString() ?? '').toLowerCase().trim())
            .toList();

        final vCol =
            _colIndex(header, ['vehicle', 'fahrzeug', 'kfz']);
        final cCol =
            _colIndex(header, ['compartment', 'fach', 'bereich']);
        final eCol =
            _colIndex(header, ['equipment', 'gerät', 'bezeichnung', 'name']);
        final qCol =
            _colIndex(header, ['quantity', 'menge', 'anzahl']);

        if (vCol < 0 || cCol < 0 || eCol < 0) {
          errorMessages.add(
              'Pflicht-Spalten "Fahrzeug", "Fach" und "Gerät" nicht gefunden.');
          errors++;
          continue;
        }

        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          try {
            final vehicleName =
                row[vCol]?.value?.toString().trim() ?? '';
            final compartmentLabel =
                row[cCol]?.value?.toString().trim() ?? '';
            final equipmentName =
                row[eCol]?.value?.toString().trim() ?? '';
            final quantity = qCol >= 0
                ? int.tryParse(
                        row[qCol]?.value?.toString().trim() ?? '1') ??
                    1
                : 1;

            if (vehicleName.isEmpty ||
                compartmentLabel.isEmpty ||
                equipmentName.isEmpty) continue;

            // Upsert vehicle
            final vehicles = await db.vehicleDao.getAll();
            VehicleData? vehicle;
            for (final v in vehicles) {
              if (v.name.toLowerCase() == vehicleName.toLowerCase()) {
                vehicle = v;
                break;
              }
            }
            int vehicleId;
            if (vehicle == null) {
              vehicleId = await db.vehicleDao.insertVehicle(
                VehiclesCompanion.insert(name: vehicleName, type: vehicleName),
              );
            } else {
              vehicleId = vehicle.id;
            }

            // Upsert compartment
            final compList =
                await db.compartmentDao.getByVehicle(vehicleId);
            CompartmentData? comp;
            for (final c in compList) {
              if (c.label.toLowerCase() ==
                  compartmentLabel.toLowerCase()) {
                comp = c;
                break;
              }
            }
            int compartmentId;
            if (comp == null) {
              compartmentId = await db.compartmentDao.insertCompartment(
                CompartmentsCompanion.insert(
                  vehicleId: vehicleId,
                  label: compartmentLabel,
                  position: Value(compList.length),
                ),
              );
            } else {
              compartmentId = comp.id;
            }

            // Upsert equipment (try alias resolution first)
            final allEquipment = await db.equipmentDao.getAll();
            EquipmentItemData? equipment;
            final nameLower = equipmentName.toLowerCase();
            for (final e in allEquipment) {
              if (e.name.toLowerCase() == nameLower) {
                equipment = e;
                break;
              }
            }
            int equipmentId;
            if (equipment == null) {
              equipmentId = await db.equipmentDao.insertEquipment(
                EquipmentItemsCompanion.insert(
                  name: equipmentName,
                  isCustom: const Value(true),
                ),
              );
              customItems.add(equipmentName);
            } else {
              equipmentId = equipment.id;
            }

            // Upsert assignment
            final assignments = await db.assignmentDao
                .getByCompartment(compartmentId);
            AssignmentData? existing;
            for (final a in assignments) {
              if (a.equipmentId == equipmentId) {
                existing = a;
                break;
              }
            }
            if (existing == null) {
              await db.assignmentDao.insertAssignment(
                EquipmentAssignmentsCompanion.insert(
                  compartmentId: compartmentId,
                  equipmentId: equipmentId,
                  quantity: Value(quantity),
                ),
              );
            } else {
              await db.assignmentDao.updateAssignment(
                EquipmentAssignmentsCompanion(
                  id: Value(existing.id),
                  quantity: Value(quantity),
                ),
              );
            }
            success++;
          } catch (e) {
            errors++;
            errorMessages.add('Zeile $i: $e');
          }
        }
      }
    });

    return _ImportResult(
      success: success,
      errors: errors,
      customItems: customItems,
      errorMessages: errorMessages,
    );
  }

  int _colIndex(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final i = header.indexWhere((h) => h.contains(candidate));
      if (i >= 0) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beladeplan importieren')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Erwartete Spalten:',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    const Text(
                        '• Fahrzeug (vehicle)\n'
                        '• Fach (compartment)\n'
                        '• Gerät (equipment)\n'
                        '• Menge / quantity (optional)',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: const Text('Excel / CSV auswählen'),
              onPressed: _importing ? null : _pickAndImport,
            ),
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ImportSummary(result: _result!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  final _ImportResult result;
  const _ImportSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import abgeschlossen',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('✓ Erfolgreich: ${result.success}'),
            if (result.errors > 0)
              Text('✗ Fehler: ${result.errors}',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            if (result.customItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('⚠ ${result.customItems.length} benutzerdefinierte Geräte erstellt:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ...result.customItems
                  .map((n) => Text('  • $n', style: const TextStyle(fontSize: 12))),
            ],
            if (result.errorMessages.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                title: const Text('Fehlermeldungen',
                    style: TextStyle(fontSize: 13)),
                children: result.errorMessages
                    .map((m) => ListTile(
                          dense: true,
                          title: Text(m,
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportResult {
  final int success;
  final int errors;
  final List<String> customItems;
  final List<String> errorMessages;

  const _ImportResult({
    required this.success,
    required this.errors,
    required this.customItems,
    required this.errorMessages,
  });
}
