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
      // A device that has pulled the central dataset must not be re-seeded
      // with the bundled demo library — the published data is authoritative.
      final syncMeta = await (_db.select(_db.syncMeta)
            ..where((t) => t.id.equals(1)))
          .getSingleOrNull();
      if ((syncMeta?.lastPulledVersion ?? 0) > 0) {
        _log.i('Central dataset present – skipping library seed.');
        return;
      }

      // Check if already seeded: look for any row with libraryEquipmentId set
      final existing = await _db.equipmentDao.getAll();
      final seeded =
          existing.any((e) => e.libraryEquipmentId != null);
      // Standard-Grunddatenbank (Normbeladung) — idempotent per item. Muss
      // vor dem Demo-Fahrzeug laufen, dessen Beladeplan Katalog-IDs referenziert.
      await _seedCatalog();
      if (!seeded) {
        _log.i('Starting library seed...');
        await _seedVehicle('hlf20_demo');
        _log.i('Library seed complete.');
      } else {
        _log.i('Library already seeded – skipping full seed.');
      }
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

  /// Seeds the standard equipment catalog (Normbeladung) so imports of new
  /// Beladelisten match against a broad base database. Items are plain
  /// equipment rows without assignments; idempotent via libraryEquipmentId.
  Future<void> _seedCatalog() async {
    final catalogJson = await _loadJson(
        'assets/equipment_library/catalog/standard_catalog.json');
    if (catalogJson == null) return;
    final items = (catalogJson['items'] as List?) ?? [];
    var created = 0;
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final id = item['id'] as String;
      final existing = await _db.equipmentDao.getByLibraryId(id);
      if (existing != null) continue;
      await _db.equipmentDao.insertEquipment(EquipmentItemsCompanion.insert(
        name: item['name'] as String,
        shortName: Value(item['short_name'] as String?),
        libraryEquipmentId: Value(id),
        isCustom: const Value(false),
        equipmentFunctionsJson: Value(jsonEncode(
            ((item['equipment_functions'] as List?)?.cast<String>()) ?? [])),
        description: Value((item['description'] as String?) ?? ''),
        typicalUseJson: Value(jsonEncode(
            ((item['typical_use'] as List?)?.cast<String>()) ?? [])),
        trainingQuestionsJson: Value(jsonEncode(
            ((item['training_questions'] as List?)?.cast<String>()) ?? [])),
      ));
      created++;
    }
    if (created > 0) {
      _log.i('Standard-Katalog: $created Geräte ergänzt.');
    }
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
