/// library_seeder.dart – Idempotent seeder that populates the DB from the JSON asset library.
/// Run once on first launch. Uses libraryEquipmentId to detect already-seeded rows.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show rootBundle;
import 'package:fwapp/core/database/app_database.dart';
import 'package:logger/logger.dart';

final _log = Logger();

class LibrarySeeder {
  final AppDatabase _db;
  LibrarySeeder(this._db);

  Future<void> seedIfNeeded() async {
    try {
      // Check if already seeded: look for any row with libraryEquipmentId set
      final existing = await _db.equipmentDao.getAll();
      final seeded =
          existing.any((e) => e.libraryEquipmentId != null);
      if (seeded) {
        _log.i('Library already seeded – skipping.');
        return;
      }
      _log.i('Starting library seed...');
      await _seedVehicle('ab_g');
      _log.i('Library seed complete.');
    } catch (e, st) {
      _log.e('Library seed failed', error: e, stackTrace: st);
    }
  }

  Future<void> _seedVehicle(String vehicleId) async {
    // 1. Load vehicle.json
    final vehicleJson = await _loadJson(
        'assets/equipment_library/vehicles/$vehicleId/vehicle.json');
    if (vehicleJson == null) return;

    // 2. Load loading_plan.json
    final planJson = await _loadJson(
        'assets/equipment_library/vehicles/$vehicleId/loading_plan.json');
    if (planJson == null) return;

    await _db.transaction(() async {
      // Upsert vehicle row
      int dbVehicleId;
      final vehicles = await _db.vehicleDao.getAll();
      final existing = vehicles
          .where((v) =>
              v.name == (vehicleJson['vehicle_name'] as String))
          .firstOrNull;
      if (existing != null) {
        dbVehicleId = existing.id;
      } else {
        dbVehicleId = await _db.vehicleDao.insertVehicle(
          VehiclesCompanion.insert(
            name: vehicleJson['vehicle_name'] as String,
            type: vehicleJson['vehicle_type'] as String,
          ),
        );
      }

      final compartmentsRaw =
          (planJson['compartments'] as List<dynamic>?) ?? [];
      for (final compRaw in compartmentsRaw) {
        final compMap = compRaw as Map<String, dynamic>;
        final compartmentLabel = compMap['label'] as String;
        final position = compMap['position'] as int? ?? 0;

        // Upsert compartment
        final existingComps =
            await _db.compartmentDao.getByVehicle(dbVehicleId);
        CompartmentData? compRow;
        for (final c in existingComps) {
          if (c.label == compartmentLabel) {
            compRow = c;
            break;
          }
        }
        int compartmentId;
        if (compRow != null) {
          compartmentId = compRow.id;
        } else {
          compartmentId = await _db.compartmentDao.insertCompartment(
            CompartmentsCompanion.insert(
              vehicleId: dbVehicleId,
              label: compartmentLabel,
              position: Value(position),
            ),
          );
        }

        // Process items in this compartment
        final items =
            (compMap['items'] as List<dynamic>?) ?? [];
        for (final itemRaw in items) {
          final itemMap = itemRaw as Map<String, dynamic>;
          final equipmentLibId =
              itemMap['equipment_id'] as String;
          final quantity = itemMap['quantity'] as int? ?? 1;

          // Load equipment JSON
          int equipmentId;
          final equipRow =
              await _db.equipmentDao.getByLibraryId(equipmentLibId);
          if (equipRow != null) {
            equipmentId = equipRow.id;
          } else {
            // Try to load from asset
            final eJson = await _loadJson(
                'assets/equipment_library/vehicles/$vehicleId/equipment/$equipmentLibId.json');
            String name = equipmentLibId.replaceAll('_', ' ');
            List<String> functions = [];
            List<String> scenarios = [];
            String description = '';
            String? trainingUrl;
            Map<String, dynamic> extra = {};

            if (eJson != null) {
              name = (eJson['name'] as String?) ?? name;
              functions =
                  ((eJson['equipment_functions'] as List?)
                          ?.cast<String>()) ??
                      [];
              scenarios =
                  ((eJson['deployment_scenarios'] as List?)
                          ?.cast<String>()) ??
                      [];
              description =
                  (eJson['description'] as String?) ?? '';
              if (eJson['manuals'] is List &&
                  (eJson['manuals'] as List).isNotEmpty) {
                trainingUrl = (eJson['manuals'] as List).first as String?;
              }
              if (eJson['technical_data'] is Map) {
                extra = Map<String, dynamic>.from(
                    eJson['technical_data'] as Map);
              }
            }

            equipmentId = await _db.equipmentDao.insertEquipment(
              EquipmentItemsCompanion.insert(
                name: name,
                libraryEquipmentId: Value(equipmentLibId),
                isCustom: const Value(false),
                equipmentFunctionsJson:
                    Value(jsonEncode(functions)),
                deploymentScenariosJson:
                    Value(jsonEncode(scenarios)),
                description: Value(description),
                trainingUrl: Value(trainingUrl),
                extraAttributesJson: Value(jsonEncode(extra)),
              ),
            );
          }

          // Upsert assignment
          final existingAssignments =
              await _db.assignmentDao.getByCompartment(compartmentId);
          final alreadyAssigned = existingAssignments
              .any((a) => a.equipmentId == equipmentId);
          if (!alreadyAssigned) {
            await _db.assignmentDao.insertAssignment(
              EquipmentAssignmentsCompanion.insert(
                compartmentId: compartmentId,
                equipmentId: equipmentId,
                quantity: Value(quantity),
              ),
            );
          }
        }
      }
    });
  }

  Future<Map<String, dynamic>?> _loadJson(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
