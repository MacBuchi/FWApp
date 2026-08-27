/// database_providers.dart – Riverpod provider for the AppDatabase singleton.
library;
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  // Jede Abteilung hat ihre eigene Datei (Issue #57 Phase 2): Beim Wechsel
  // baut sich der Provider neu auf, alle DAO-Provider und Streams folgen
  // automatisch. `null` = eigene Abteilung in der angestammten Datei.
  final abteilungId = ref.watch(selectedAbteilungIdProvider);
  final db = AppDatabase.create(abteilungId: abteilungId);
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
VehicleDao vehicleDao(Ref ref) =>
    ref.watch(appDatabaseProvider).vehicleDao;

@Riverpod(keepAlive: true)
CompartmentDao compartmentDao(Ref ref) =>
    ref.watch(appDatabaseProvider).compartmentDao;

@Riverpod(keepAlive: true)
EquipmentDao equipmentDao(Ref ref) =>
    ref.watch(appDatabaseProvider).equipmentDao;

@Riverpod(keepAlive: true)
AssignmentDao assignmentDao(Ref ref) =>
    ref.watch(appDatabaseProvider).assignmentDao;

@Riverpod(keepAlive: true)
AttachmentDao attachmentDao(Ref ref) =>
    ref.watch(appDatabaseProvider).attachmentDao;

@Riverpod(keepAlive: true)
QuizDao quizDao(Ref ref) => ref.watch(appDatabaseProvider).quizDao;

@Riverpod(keepAlive: true)
InspectionDao inspectionDao(Ref ref) =>
    ref.watch(appDatabaseProvider).inspectionDao;

@Riverpod(keepAlive: true)
LearningDao learningDao(Ref ref) =>
    ref.watch(appDatabaseProvider).learningDao;

@Riverpod(keepAlive: true)
InventoryDao inventoryDao(Ref ref) =>
    ref.watch(appDatabaseProvider).inventoryDao;
