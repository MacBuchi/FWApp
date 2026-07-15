/// library_seeder_test.dart – Tests idempotency and correctness of LibrarySeeder.
/// Uses an in-memory Drift database and the real asset bundle (loaded via
/// TestWidgetsFlutterBinding) so no mocking of rootBundle is required.
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/library_seeder.dart';

import '../../helpers/test_database.dart';

// Expected values derived from assets/equipment_library/vehicles/hlf20_demo/
// (fiktive Demo-Beladung, referenziert ausschließlich Standard-Katalog-IDs).
const _expectedVehicles = 1;
const _expectedCompartments = 9;
// Nur der Standard-Katalog (Grunddatenbank) – der Demo-Beladeplan legt keine
// eigenen Geräte an, sondern verweist auf Katalog-Einträge.
const _expectedEquipmentItems = 110;
// Positionen im loading_plan.json (keine Duplikate innerhalb eines Fachs).
const _expectedAssignments = 108;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LibrarySeeder seeder;

  setUp(() {
    db = createTestDatabase();
    seeder = LibrarySeeder(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── First-run seeding ─────────────────────────────────────────────────────

  group('first-run seeding', () {
    test('inserts the expected number of vehicles', () async {
      await seeder.seedIfNeeded();
      final vehicles = await db.vehicleDao.getAll();
      expect(vehicles.length, _expectedVehicles);
    });

    test('inserts the expected number of compartments', () async {
      await seeder.seedIfNeeded();
      final vehicles = await db.vehicleDao.getAll();
      int total = 0;
      for (final v in vehicles) {
        total += (await db.compartmentDao.getByVehicle(v.id)).length;
      }
      expect(total, _expectedCompartments);
    });

    test('inserts the expected number of unique equipment items', () async {
      await seeder.seedIfNeeded();
      final items = await db.equipmentDao.getAll();
      expect(items.length, _expectedEquipmentItems);
    });

    test('inserts the expected number of assignments', () async {
      await seeder.seedIfNeeded();
      final vehicles = await db.vehicleDao.getAll();
      int total = 0;
      for (final v in vehicles) {
        total += (await db.assignmentDao.getByVehicle(v.id)).length;
      }
      expect(total, _expectedAssignments);
    });

    test('sets isCustom = false on all seeded equipment', () async {
      await seeder.seedIfNeeded();
      final items = await db.equipmentDao.getAll();
      expect(items.every((e) => !e.isCustom), isTrue);
    });

    test('sets libraryEquipmentId on all seeded equipment', () async {
      await seeder.seedIfNeeded();
      final items = await db.equipmentDao.getAll();
      expect(items.every((e) => e.libraryEquipmentId != null), isTrue);
    });

    test('every assignment references an existing compartment and equipment',
        () async {
      await seeder.seedIfNeeded();
      final vehicles = await db.vehicleDao.getAll();
      for (final v in vehicles) {
        final assignments = await db.assignmentDao.getByVehicle(v.id);
        for (final a in assignments) {
          final comp = await db.compartmentDao.getById(a.compartmentId);
          final equip = await db.equipmentDao.getById(a.equipmentId);
          expect(comp, isNotNull,
              reason: 'Assignment ${a.id} references missing compartment');
          expect(equip, isNotNull,
              reason: 'Assignment ${a.id} references missing equipment');
        }
      }
    });

    test('every assignment has quantity >= 1', () async {
      await seeder.seedIfNeeded();
      final vehicles = await db.vehicleDao.getAll();
      for (final v in vehicles) {
        final assignments = await db.assignmentDao.getByVehicle(v.id);
        for (final a in assignments) {
          expect(a.quantity, greaterThanOrEqualTo(1));
        }
      }
    });
  });

  // ── Idempotency ───────────────────────────────────────────────────────────

  group('idempotency', () {
    test('calling seedIfNeeded twice produces identical vehicle count',
        () async {
      await seeder.seedIfNeeded();
      final countAfterFirst = (await db.vehicleDao.getAll()).length;

      await seeder.seedIfNeeded();
      final countAfterSecond = (await db.vehicleDao.getAll()).length;

      expect(countAfterSecond, countAfterFirst);
    });

    test('calling seedIfNeeded twice produces identical equipment count',
        () async {
      await seeder.seedIfNeeded();
      final countAfterFirst = (await db.equipmentDao.getAll()).length;

      await seeder.seedIfNeeded();
      final countAfterSecond = (await db.equipmentDao.getAll()).length;

      expect(countAfterSecond, countAfterFirst);
    });

    test('calling seedIfNeeded twice produces identical assignment count',
        () async {
      await seeder.seedIfNeeded();
      final vehicles = await db.vehicleDao.getAll();
      int countAfterFirst = 0;
      for (final v in vehicles) {
        countAfterFirst += (await db.assignmentDao.getByVehicle(v.id)).length;
      }

      await seeder.seedIfNeeded();
      int countAfterSecond = 0;
      for (final v in await db.vehicleDao.getAll()) {
        countAfterSecond +=
            (await db.assignmentDao.getByVehicle(v.id)).length;
      }

      expect(countAfterSecond, countAfterFirst);
    });

    test('early-exit path: skips seeding when a library row already exists',
        () async {
      // Pre-populate one library row to trigger the early-return guard
      await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(
          name: 'Pre-existing library item',
          libraryEquipmentId: const Value('sentinel_library_id'),
        ),
      );

      await seeder.seedIfNeeded();

      // No vehicle seeding should have occurred
      final vehicles = await db.vehicleDao.getAll();
      expect(vehicles, isEmpty,
          reason:
              'Seeder must not insert vehicles when library rows are already present');
    });

    test('calling seedIfNeeded three times is still idempotent', () async {
      await seeder.seedIfNeeded();
      await seeder.seedIfNeeded();
      await seeder.seedIfNeeded();

      final vehicles = await db.vehicleDao.getAll();
      final items = await db.equipmentDao.getAll();
      expect(vehicles.length, _expectedVehicles);
      expect(items.length, _expectedEquipmentItems);
    });
  });
}
