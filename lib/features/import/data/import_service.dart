/// import_service.dart – Applies a resolved Beladeliste import to the local
/// database in one transaction (upserts vehicles, compartments, equipment,
/// assignments; learns user aliases).
library;
import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/import/data/equipment_matcher.dart';
import 'package:fwapp/features/import/domain/import_models.dart';

class ImportService {
  final AppDatabase db;
  ImportService(this.db);

  /// [decisions] is keyed by the normalized equipment name
  /// (EquipmentMatcher.normalize) and must cover every row.
  Future<ImportApplyResult> apply({
    required List<ImportRow> rows,
    required Map<String, RowDecision> decisions,
  }) async {
    var assignmentsWritten = 0;
    var vehiclesCreated = 0;
    var compartmentsCreated = 0;
    var customItemsCreated = 0;
    var aliasesLearned = 0;
    var skipped = 0;

    await db.transaction(() async {
      // Caches, filled once — the old importer re-read whole tables per row.
      final vehicleIds = <String, int>{
        for (final v in await db.vehicleDao.getAll()) v.name.toLowerCase(): v.id
      };
      // compartment cache: '<vehicleId>|<label lower>' -> id
      final compartmentIds = <String, int>{};
      final compartmentCounts = <int, int>{};
      // custom equipment created during this run, by normalized name
      final createdCustom = <String, int>{};
      final learnedAliases = <String>{};

      for (final row in rows) {
        final key = EquipmentMatcher.normalize(row.equipmentName);
        final decision = decisions[key] ??
            const RowDecision(action: RowAction.createCustom);
        if (decision.action == RowAction.skip) {
          skipped++;
          continue;
        }

        // Equipment
        int equipmentId;
        switch (decision.action) {
          case RowAction.useEquipment:
            equipmentId = decision.equipmentId!;
            if (decision.rememberAlias && !learnedAliases.contains(key)) {
              await db.into(db.userAliases).insert(
                    UserAliasesCompanion.insert(
                      alias: row.equipmentName.trim(),
                      equipmentId: equipmentId,
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              learnedAliases.add(key);
              aliasesLearned++;
            }
          case RowAction.createCustom:
            final existing = createdCustom[key];
            if (existing != null) {
              equipmentId = existing;
            } else {
              equipmentId = await db.equipmentDao.insertEquipment(
                EquipmentItemsCompanion.insert(
                  name: row.equipmentName.trim(),
                  isCustom: const Value(true),
                ),
              );
              createdCustom[key] = equipmentId;
              customItemsCreated++;
            }
          case RowAction.skip:
            continue; // unreachable, handled above
        }

        // Vehicle
        final vehicleKey = row.vehicleName.toLowerCase();
        var vehicleId = vehicleIds[vehicleKey];
        if (vehicleId == null) {
          vehicleId = await db.vehicleDao.insertVehicle(VehiclesCompanion
              .insert(name: row.vehicleName, type: row.vehicleName));
          vehicleIds[vehicleKey] = vehicleId;
          vehiclesCreated++;
        }

        // Compartment
        if (!compartmentCounts.containsKey(vehicleId)) {
          final existing = await db.compartmentDao.getByVehicle(vehicleId);
          compartmentCounts[vehicleId] = existing.length;
          for (final c in existing) {
            compartmentIds['$vehicleId|${c.label.toLowerCase()}'] = c.id;
          }
        }
        final compartmentKey =
            '$vehicleId|${row.compartmentLabel.toLowerCase()}';
        var compartmentId = compartmentIds[compartmentKey];
        if (compartmentId == null) {
          compartmentId = await db.compartmentDao.insertCompartment(
            CompartmentsCompanion.insert(
              vehicleId: vehicleId,
              label: row.compartmentLabel,
              position: Value(compartmentCounts[vehicleId]!),
            ),
          );
          compartmentIds[compartmentKey] = compartmentId;
          compartmentCounts[vehicleId] = compartmentCounts[vehicleId]! + 1;
          compartmentsCreated++;
        }

        // Assignment (update quantity when the pair already exists)
        final assignments =
            await db.assignmentDao.getByCompartment(compartmentId);
        final existing =
            assignments.where((a) => a.equipmentId == equipmentId).firstOrNull;
        if (existing == null) {
          await db.assignmentDao.insertAssignment(
            EquipmentAssignmentsCompanion.insert(
              compartmentId: compartmentId,
              equipmentId: equipmentId,
              quantity: Value(row.quantity),
            ),
          );
        } else {
          await (db.update(db.equipmentAssignments)
                ..where((t) => t.id.equals(existing.id)))
              .write(EquipmentAssignmentsCompanion(
            quantity: Value(row.quantity),
            updatedAt: Value(DateTime.now()),
          ));
        }
        assignmentsWritten++;
      }
    });

    return ImportApplyResult(
      assignmentsWritten: assignmentsWritten,
      vehiclesCreated: vehiclesCreated,
      compartmentsCreated: compartmentsCreated,
      customItemsCreated: customItemsCreated,
      aliasesLearned: aliasesLearned,
      skipped: skipped,
    );
  }
}
