/// database_providers.dart – Riverpod provider for the AppDatabase singleton.
library;
import 'package:fwapp/core/database/app_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.create();
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
QuizDao quizDao(Ref ref) => ref.watch(appDatabaseProvider).quizDao;

@Riverpod(keepAlive: true)
InspectionDao inspectionDao(Ref ref) =>
    ref.watch(appDatabaseProvider).inspectionDao;
