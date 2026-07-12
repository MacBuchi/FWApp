/// app_database.dart – Drift database definition: tables, DAOs, and database singleton.
/// Platform-conditional connection (NativeDatabase on mobile, WasmDatabase on web).
library;
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
  TextColumn get shortName => text().nullable()();
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
  TextColumn get trainingQuestionsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get typicalUseJson =>
      text().withDefault(const Constant('[]'))();
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

/// A physical, trackable instance of an equipment type (e.g. "Flasche 3").
/// Created lazily only for items that need inspection/expiry tracking.
/// Deliberately NOT tied to EquipmentAssignments: assignments are recreated
/// on re-import, but inspection history must survive that.
@DataClassName('EquipmentInstanceData')
class EquipmentInstances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get equipmentId =>
      integer().references(EquipmentItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get vehicleId =>
      integer().nullable().references(Vehicles, #id, onDelete: KeyAction.setNull)();
  IntColumn get compartmentId => integer()
      .nullable()
      .references(Compartments, #id, onDelete: KeyAction.setNull)();
  TextColumn get identifier => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// A recurring Prüfung (kind='recurring', intervalMonths set) or a one-shot
/// Ablaufdatum (kind='expiry'). dueAt is stored denormalized and updated when
/// an inspection is logged, so due queries never compute dates.
@DataClassName('InspectionScheduleData')
class InspectionSchedules extends Table {
  static const kindRecurring = 'recurring';
  static const kindExpiry = 'expiry';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get instanceId => integer()
      .references(EquipmentInstances, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  IntColumn get intervalMonths => integer().nullable()();
  DateTimeColumn get lastDoneAt => dateTime().nullable()();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('InspectionLogData')
class InspectionLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scheduleId => integer()
      .references(InspectionSchedules, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get doneAt => dateTime()();
  TextColumn get doneBy => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// User-learned import aliases ("remember this mapping"); the bundled
/// aliases.json asset stays read-only.
@DataClassName('UserAliasData')
class UserAliases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get alias => text().unique()();
  IntColumn get equipmentId =>
      integer().references(EquipmentItems, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Single-row sync bookkeeping (id is always 1).
@DataClassName('SyncMetaData')
class SyncMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get lastPulledVersion =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();
  BoolColumn get localDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
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

  /// Partial update: writes only the columns present in [e].
  /// Use this instead of [updateEquipment] for companions that don't carry
  /// the full row (replace() throws on absent required columns).
  Future<int> patchEquipment(int id, EquipmentItemsCompanion e) =>
      (update(equipmentItems)..where((t) => t.id.equals(id))).write(e);

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

/// A due (or soon-due) schedule joined with its instance, equipment type,
/// and vehicle for display.
class DueInspection {
  final InspectionScheduleData schedule;
  final EquipmentInstanceData instance;
  final EquipmentItemData equipment;
  final VehicleData? vehicle;

  DueInspection({
    required this.schedule,
    required this.instance,
    required this.equipment,
    this.vehicle,
  });

  bool isOverdue(DateTime now) => schedule.dueAt.isBefore(now);
}

/// Overdue / due-soon counts for one vehicle (for list badges).
typedef VehicleDueCounts = ({int overdueCount, int dueSoonCount});

@DriftAccessor(tables: [
  InspectionSchedules,
  EquipmentInstances,
  InspectionLog,
  EquipmentItems,
  Vehicles,
])
class InspectionDao extends DatabaseAccessor<AppDatabase>
    with _$InspectionDaoMixin {
  InspectionDao(super.db);

  // ── Instances ──

  Stream<List<EquipmentInstanceData>> watchInstancesByEquipment(
          int equipmentId) =>
      (select(equipmentInstances)
            ..where((t) => t.equipmentId.equals(equipmentId))
            ..orderBy([(t) => OrderingTerm.asc(t.identifier)]))
          .watch();

  Future<int> insertInstance(EquipmentInstancesCompanion i) =>
      into(equipmentInstances).insert(i);

  Future<bool> updateInstance(EquipmentInstancesCompanion i) =>
      update(equipmentInstances).replace(i);

  Future<int> deleteInstance(int id) =>
      (delete(equipmentInstances)..where((t) => t.id.equals(id))).go();

  // ── Schedules ──

  Stream<List<InspectionScheduleData>> watchSchedulesByInstance(
          int instanceId) =>
      (select(inspectionSchedules)
            ..where((t) => t.instanceId.equals(instanceId))
            ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
          .watch();

  Future<int> insertSchedule(InspectionSchedulesCompanion s) =>
      into(inspectionSchedules).insert(s);

  Future<bool> updateSchedule(InspectionSchedulesCompanion s) =>
      update(inspectionSchedules).replace(s);

  Future<int> deleteSchedule(int id) =>
      (delete(inspectionSchedules)..where((t) => t.id.equals(id))).go();

  // ── Log ──

  Future<List<InspectionLogData>> getLogBySchedule(int scheduleId) =>
      (select(inspectionLog)
            ..where((t) => t.scheduleId.equals(scheduleId))
            ..orderBy([(t) => OrderingTerm.desc(t.doneAt)]))
          .get();

  Future<int> insertLogEntry(InspectionLogCompanion l) =>
      into(inspectionLog).insert(l);

  // ── Due queries ──

  /// All schedules of active instances with dueAt <= now + [withinDays],
  /// ordered by dueAt (overdue first).
  Stream<List<DueInspection>> watchDueSoon({int withinDays = 30}) {
    final cutoff = DateTime.now().add(Duration(days: withinDays));
    final query = select(inspectionSchedules).join([
      innerJoin(equipmentInstances,
          equipmentInstances.id.equalsExp(inspectionSchedules.instanceId)),
      innerJoin(equipmentItems,
          equipmentItems.id.equalsExp(equipmentInstances.equipmentId)),
      leftOuterJoin(
          vehicles, vehicles.id.equalsExp(equipmentInstances.vehicleId)),
    ])
      ..where(equipmentInstances.isActive.equals(true) &
          inspectionSchedules.dueAt.isSmallerOrEqualValue(cutoff))
      ..orderBy([OrderingTerm.asc(inspectionSchedules.dueAt)]);
    return query.watch().map((rows) => rows
        .map((row) => DueInspection(
              schedule: row.readTable(inspectionSchedules),
              instance: row.readTable(equipmentInstances),
              equipment: row.readTable(equipmentItems),
              vehicle: row.readTableOrNull(vehicles),
            ))
        .toList());
  }

  /// Per-vehicle overdue / due-soon counts (instances without a vehicle are
  /// not included). Aggregated in Dart — the due set is small by design.
  Stream<Map<int, VehicleDueCounts>> watchDueCountsByVehicle(
      {int withinDays = 30}) {
    return watchDueSoon(withinDays: withinDays).map((dues) {
      final now = DateTime.now();
      final counts = <int, ({int overdue, int dueSoon})>{};
      for (final due in dues) {
        final vehicleId = due.instance.vehicleId;
        if (vehicleId == null) continue;
        final prev = counts[vehicleId] ?? (overdue: 0, dueSoon: 0);
        counts[vehicleId] = due.isOverdue(now)
            ? (overdue: prev.overdue + 1, dueSoon: prev.dueSoon)
            : (overdue: prev.overdue, dueSoon: prev.dueSoon + 1);
      }
      return counts.map((k, v) => MapEntry(
          k, (overdueCount: v.overdue, dueSoonCount: v.dueSoon)));
    });
  }
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
    EquipmentInstances,
    InspectionSchedules,
    InspectionLog,
    UserAliases,
    SyncMeta,
  ],
  daos: [
    VehicleDao,
    CompartmentDao,
    EquipmentDao,
    AssignmentDao,
    QuizDao,
    InspectionDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(equipmentInstances);
            await m.createTable(inspectionSchedules);
            await m.createTable(inspectionLog);
            await m.createTable(userAliases);
            await m.createTable(syncMeta);
            await m.addColumn(equipmentItems, equipmentItems.shortName);
            await m.addColumn(
                equipmentItems, equipmentItems.trainingQuestionsJson);
            await m.addColumn(equipmentItems, equipmentItems.typicalUseJson);
          }
        },
        beforeOpen: (details) async {
          // SQLite defaults to foreign_keys OFF; without this the declared
          // onDelete cascades are not enforced.
          await customStatement('PRAGMA foreign_keys = ON');
        },
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
