/// library_seeder.dart – Idempotent seeder that populates the DB from the JSON asset library.
/// Run once on first launch. Uses libraryEquipmentId to detect already-seeded rows.
library;
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
      if (!seeded) {
        _log.i('Starting library seed...');
        await _seedVehicle('ab_g');
        _log.i('Library seed complete.');
      } else {
        _log.i('Library already seeded – skipping full seed.');
      }
      // Always sync image paths so newly added images propagate to existing rows.
      await _syncImagePaths('ab_g');
      // Backfill training content (v2 columns) for rows seeded before v2.
      await _syncEnrichment('ab_g');
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
      final vehicleName =
          (vehicleJson['name'] ?? vehicleJson['vehicle_name'] ?? vehicleId)
              as String;
      final vehicleType =
          (vehicleJson['type'] ?? vehicleJson['vehicle_type'] ?? vehicleId)
              as String;
      final vehicles = await _db.vehicleDao.getAll();
      final existing = vehicles
          .where((v) => v.name == vehicleName)
          .firstOrNull;
      if (existing != null) {
        dbVehicleId = existing.id;
      } else {
        dbVehicleId = await _db.vehicleDao.insertVehicle(
          VehiclesCompanion.insert(
            name: vehicleName,
            type: vehicleType,
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
            String? imagePath;
            Map<String, dynamic> extra = {};

            String? shortName;
            List<String> trainingQuestions = [];
            List<String> typicalUse = [];

            if (eJson != null) {
              name = (eJson['name'] as String?) ?? name;
              shortName = eJson['short_name'] as String?;
              trainingQuestions =
                  ((eJson['training_questions'] as List?)?.cast<String>()) ??
                      [];
              typicalUse =
                  ((eJson['typical_use'] as List?)?.cast<String>()) ?? [];
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
              final images =
                  ((eJson['images'] as List?)?.cast<String>()) ?? [];
              if (images.isNotEmpty) imagePath = images.first;
              if (eJson['technical_data'] is Map) {
                extra = Map<String, dynamic>.from(
                    eJson['technical_data'] as Map);
              }
            }

            equipmentId = await _db.equipmentDao.insertEquipment(
              EquipmentItemsCompanion.insert(
                name: name,
                shortName: Value(shortName),
                libraryEquipmentId: Value(equipmentLibId),
                isCustom: const Value(false),
                equipmentFunctionsJson:
                    Value(jsonEncode(functions)),
                deploymentScenariosJson:
                    Value(jsonEncode(scenarios)),
                description: Value(description),
                imagePath: Value(imagePath),
                trainingUrl: Value(trainingUrl),
                extraAttributesJson: Value(jsonEncode(extra)),
                trainingQuestionsJson: Value(jsonEncode(trainingQuestions)),
                typicalUseJson: Value(jsonEncode(typicalUse)),
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

  /// Backfill imagePath for any already-seeded rows whose JSON now has an image.
  Future<void> _syncImagePaths(String vehicleId) async {
    final all = await _db.equipmentDao.getAll();
    final needsImage = all
        .where((e) => e.imagePath == null && e.libraryEquipmentId != null)
        .toList();
    if (needsImage.isEmpty) return;
    _log.i('Syncing image paths for ${needsImage.length} items...');
    int updated = 0;
    for (final row in needsImage) {
      final eJson = await _loadJson(
          'assets/equipment_library/vehicles/$vehicleId/equipment/${row.libraryEquipmentId}.json');
      if (eJson == null) continue;
      final images = ((eJson['images'] as List?)?.cast<String>()) ?? [];
      if (images.isEmpty) continue;
      await _db.equipmentDao.patchEquipment(
        row.id,
        EquipmentItemsCompanion(imagePath: Value(images.first)),
      );
      updated++;
    }
    if (updated > 0) _log.i('Updated image paths for $updated equipment items.');
  }

  /// Backfill v2 training content (training_questions, typical_use,
  /// short_name) for rows seeded before those columns existed.
  Future<void> _syncEnrichment(String vehicleId) async {
    final all = await _db.equipmentDao.getAll();
    final needsEnrichment = all
        .where((e) =>
            e.libraryEquipmentId != null && e.trainingQuestionsJson == '[]')
        .toList();
    if (needsEnrichment.isEmpty) return;
    _log.i('Backfilling training content for ${needsEnrichment.length} items...');
    int updated = 0;
    for (final row in needsEnrichment) {
      final eJson = await _loadJson(
          'assets/equipment_library/vehicles/$vehicleId/equipment/${row.libraryEquipmentId}.json');
      if (eJson == null) continue;
      final trainingQuestions =
          ((eJson['training_questions'] as List?)?.cast<String>()) ?? [];
      final typicalUse =
          ((eJson['typical_use'] as List?)?.cast<String>()) ?? [];
      final shortName = eJson['short_name'] as String?;
      if (trainingQuestions.isEmpty && typicalUse.isEmpty && shortName == null) {
        continue;
      }
      await _db.equipmentDao.patchEquipment(
        row.id,
        EquipmentItemsCompanion(
          shortName: Value(shortName ?? row.shortName),
          trainingQuestionsJson: Value(jsonEncode(trainingQuestions)),
          typicalUseJson: Value(jsonEncode(typicalUse)),
        ),
      );
      updated++;
    }
    if (updated > 0) _log.i('Backfilled training content for $updated items.');
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
