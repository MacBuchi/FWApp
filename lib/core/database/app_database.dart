/// app_database.dart – Drift database definition: tables, DAOs, and database singleton.
/// Platform-conditional connection (NativeDatabase on mobile, WasmDatabase on web).
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────
// TABLE DEFINITIONS
// ─────────────────────────────────────────────────────────────

@DataClassName('VehicleData')
class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get licensePlate => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('CompartmentData')
class Compartments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehicleId =>
      integer().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get gridRow => integer().nullable()();
  IntColumn get gridCol => integer().nullable()();
  IntColumn get gridColSpan => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('EquipmentItemData')
class EquipmentItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get equipmentFunctionsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get deploymentScenariosJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get description =>
      text().withDefault(const Constant(''))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get trainingUrl => text().nullable()();
  TextColumn get libraryEquipmentId => text().nullable()();
  BoolColumn get isCustom =>
      boolean().withDefault(const Constant(false))();
  TextColumn get extraAttributesJson =>
      text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('AssignmentData')
class EquipmentAssignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get compartmentId =>
      integer().references(Compartments, #id, onDelete: KeyAction.cascade)();
  IntColumn get equipmentId =>
      integer().references(EquipmentItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('QuizResultData')
class QuizResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get quizType => text()();
  IntColumn get score => integer()();
  IntColumn get total => integer()();
  IntColumn get vehicleId =>
      integer().nullable().references(Vehicles, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get playedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ─────────────────────────────────────────────────────────────
// DAOs
// ─────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Vehicles])
class VehicleDao extends DatabaseAccessor<AppDatabase>
    with _$VehicleDaoMixin {
  VehicleDao(super.db);

  Future<List<VehicleData>> getAll() =>
      (select(vehicles)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Stream<List<VehicleData>> watchAll() =>
      (select(vehicles)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<VehicleData?> getById(int id) =>
      (select(vehicles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertVehicle(VehiclesCompanion v) =>
      into(vehicles).insertOnConflictUpdate(v);

  Future<bool> updateVehicle(VehiclesCompanion v) =>
      update(vehicles).replace(v);

  Future<int> deleteVehicle(int id) =>
      (delete(vehicles)..where((t) => t.id.equals(id))).go();

  Future<int> count() async {
    final count = countAll();
    final query = selectOnly(vehicles)..addColumns([count]);
    return await query.map((row) => row.read(count)!).getSingle();
  }
}

@DriftAccessor(tables: [Compartments])
class CompartmentDao extends DatabaseAccessor<AppDatabase>
    with _$CompartmentDaoMixin {
  CompartmentDao(super.db);

  Future<List<CompartmentData>> getByVehicle(int vehicleId) =>
      (select(compartments)
            ..where((t) => t.vehicleId.equals(vehicleId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  Stream<List<CompartmentData>> watchByVehicle(int vehicleId) =>
      (select(compartments)
            ..where((t) => t.vehicleId.equals(vehicleId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  Future<CompartmentData?> getById(int id) =>
      (select(compartments)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertCompartment(CompartmentsCompanion c) =>
      into(compartments).insertOnConflictUpdate(c);

  Future<bool> updateCompartment(CompartmentsCompanion c) =>
      update(compartments).replace(c);

  Future<int> deleteCompartment(int id) =>
      (delete(compartments)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [EquipmentItems])
class EquipmentDao extends DatabaseAccessor<AppDatabase>
    with _$EquipmentDaoMixin {
  EquipmentDao(super.db);

  Future<List<EquipmentItemData>> getAll() =>
      (select(equipmentItems)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Stream<List<EquipmentItemData>> watchAll() =>
      (select(equipmentItems)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<EquipmentItemData?> getById(int id) =>
      (select(equipmentItems)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<EquipmentItemData?> getByLibraryId(String libraryId) =>
      (select(equipmentItems)
            ..where((t) => t.libraryEquipmentId.equals(libraryId)))
          .getSingleOrNull();

  Future<int> insertEquipment(EquipmentItemsCompanion e) =>
      into(equipmentItems).insertOnConflictUpdate(e);

  Future<bool> updateEquipment(EquipmentItemsCompanion e) =>
      update(equipmentItems).replace(e);

  Future<int> deleteEquipment(int id) =>
      (delete(equipmentItems)..where((t) => t.id.equals(id))).go();

  Future<int> count() async {
    final count = countAll();
    final query = selectOnly(equipmentItems)..addColumns([count]);
    return await query.map((row) => row.read(count)!).getSingle();
  }

  Future<List<EquipmentItemData>> search(String query) =>
      (select(equipmentItems)
            ..where(
                (t) => t.name.like('%$query%') | t.description.like('%$query%'))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
}

@DriftAccessor(tables: [EquipmentAssignments, Compartments, EquipmentItems])
class AssignmentDao extends DatabaseAccessor<AppDatabase>
    with _$AssignmentDaoMixin {
  AssignmentDao(super.db);

  Future<List<AssignmentData>> getByCompartment(int compartmentId) =>
      (select(equipmentAssignments)
            ..where((t) => t.compartmentId.equals(compartmentId)))
          .get();

  Stream<List<AssignmentData>> watchByCompartment(int compartmentId) =>
      (select(equipmentAssignments)
            ..where((t) => t.compartmentId.equals(compartmentId)))
          .watch();

  Future<List<AssignmentData>> getByEquipment(int equipmentId) =>
      (select(equipmentAssignments)
            ..where((t) => t.equipmentId.equals(equipmentId)))
          .get();

  /// All assignments for all compartments of a vehicle.
  Future<List<AssignmentData>> getByVehicle(int vehicleId) async {
    final compIds = await (select(compartments)
          ..where((t) => t.vehicleId.equals(vehicleId)))
        .map((c) => c.id)
        .get();
    if (compIds.isEmpty) return [];
    return (select(equipmentAssignments)
          ..where((t) => t.compartmentId.isIn(compIds)))
        .get();
  }

  Future<int> insertAssignment(EquipmentAssignmentsCompanion a) =>
      into(equipmentAssignments).insertOnConflictUpdate(a);

  Future<bool> updateAssignment(EquipmentAssignmentsCompanion a) =>
      update(equipmentAssignments).replace(a);

  Future<int> deleteAssignment(int id) =>
      (delete(equipmentAssignments)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [QuizResults])
class QuizDao extends DatabaseAccessor<AppDatabase> with _$QuizDaoMixin {
  QuizDao(super.db);

  Future<List<QuizResultData>> getRecent({int limit = 10}) =>
      (select(quizResults)
            ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
            ..limit(limit))
          .get();

  Future<int> insertResult(QuizResultsCompanion r) =>
      into(quizResults).insert(r);
}

// ─────────────────────────────────────────────────────────────
// DATABASE CLASS
// ─────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Vehicles,
    Compartments,
    EquipmentItems,
    EquipmentAssignments,
    QuizResults,
  ],
  daos: [VehicleDao, CompartmentDao, EquipmentDao, AssignmentDao, QuizDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );

  static AppDatabase create() {
    if (kIsWeb) {
      // Web: use in-memory database for v1 (WasmDatabase requires separate setup)
      return AppDatabase(NativeDatabase.memory());
    }
    return AppDatabase(_openNative());
  }

  static LazyDatabase _openNative() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'fwapp.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
