/// library_seeder_test.dart – Tests idempotency and correctness of LibrarySeeder.
/// Uses an in-memory Drift database and the real asset bundle (loaded via
/// TestWidgetsFlutterBinding) so no mocking of rootBundle is required.
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/library_seeder.dart';
import 'package:fwapp/core/utils/image_utils.dart';

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

    test('every catalog item starts with its pictogram as image', () async {
      await seeder.seedIfNeeded();
      final items = await db.equipmentDao.getAll();
      expect(
          items.every((e) =>
              e.imagePath == pictogramPath(e.libraryEquipmentId!)),
          isTrue);
    });

    test('backfill sets pictograms but never overwrites photos', () async {
      await seeder.seedIfNeeded();
      final items = await db.equipmentDao.getAll();
      // Bestand simulieren: ein Gerät ohne Bild, eines mit echtem Foto.
      await db.equipmentDao.patchEquipment(items[0].id,
          const EquipmentItemsCompanion(imagePath: Value(null)));
      await db.equipmentDao.patchEquipment(items[1].id,
          const EquipmentItemsCompanion(
              imagePath: Value('supabase://equipment-images/foto.jpg')));

      await seeder.seedIfNeeded();

      final after = await db.equipmentDao.getAll();
      final restored =
          after.firstWhere((e) => e.id == items[0].id);
      final photo = after.firstWhere((e) => e.id == items[1].id);
      expect(restored.imagePath,
          pictogramPath(restored.libraryEquipmentId!));
      expect(photo.imagePath, 'supabase://equipment-images/foto.jpg');
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

  // ── Verortung des Demo-Fahrzeugs (Issue #167) ────────────────────────────

  /// Ohne Seite ist die Draufsicht nicht einmal erreichbar — die App
  /// begrüßte jeden neuen Nutzer mit grauen Kacheln, obwohl die Farbe der
  /// Seite das ist, was gelernt werden soll.
  group('Verortung', () {
    /// Ein Demo-Fahrzeug aus der Zeit VOR #167: Fächer ohne Seite, plus eine
    /// Bibliothekszeile, damit der Seeder sich für „schon geseedet" hält.
    Future<int> alteInstallation() async {
      final vehicleId = await db.vehicleDao.insertVehicle(
          VehiclesCompanion.insert(name: 'HLF 20 (Demo)', type: 'HLF 20'));
      for (final label in ['G1 – Löschangriff', 'Dach', 'Mannschaftsraum']) {
        await db.compartmentDao.insertCompartment(
            CompartmentsCompanion.insert(
                vehicleId: vehicleId, label: label));
      }
      await db.equipmentDao.insertEquipment(EquipmentItemsCompanion.insert(
        name: 'Bereits geseedet',
        libraryEquipmentId: const Value('sentinel_library_id'),
      ));
      return vehicleId;
    }

    Future<Map<String, ({String? seite, String? laengsposition})>> faecherVon(
        int vehicleId) async {
      final rows = await db.compartmentDao.getByVehicle(vehicleId);
      return {
        for (final c in rows)
          c.label: (seite: c.seite, laengsposition: c.laengsposition),
      };
    }

    test('der frische Seed verortet jedes Fach', () async {
      await seeder.seedIfNeeded();
      final vehicle = (await db.vehicleDao.getAll()).single;
      final faecher = await faecherVon(vehicle.id);

      expect(faecher, hasLength(_expectedCompartments));
      expect(faecher.values.where((f) => f.seite == null), isEmpty,
          reason: 'Ohne Seite bliebe das Demo-Fahrzeug grau');
      // Dieselbe Konvention wie in den Vorlagen (#144): ungerade Nummern
      // Fahrerseite, gerade Beifahrerseite, G1/G2 vorne … G5/G6 hinten.
      expect(faecher['G1 – Löschangriff'],
          (seite: 'fahrerseite', laengsposition: 'vorne'));
      expect(faecher['G6 – Werkzeug & Sonstiges'],
          (seite: 'beifahrerseite', laengsposition: 'hinten'));
      expect(faecher['GR – Pumpe & Wasser (Heck)'],
          (seite: 'heck', laengsposition: null));
      expect(faecher['Dach'], (seite: 'dach', laengsposition: null));
      expect(faecher['Mannschaftsraum'], (seite: 'front', laengsposition: null));
    });

    test('trägt die Verortung auf einer alten Installation nach', () async {
      final vehicleId = await alteInstallation();

      await seeder.seedIfNeeded();

      final faecher = await faecherVon(vehicleId);
      expect(faecher['G1 – Löschangriff'],
          (seite: 'fahrerseite', laengsposition: 'vorne'));
      expect(faecher['Dach'], (seite: 'dach', laengsposition: null));
    });

    test('überschreibt keine selbst gesetzte Seite', () async {
      final vehicleId = await alteInstallation();
      final dach = (await db.compartmentDao.getByVehicle(vehicleId))
          .firstWhere((c) => c.label == 'Dach');
      await (db.update(db.compartments)..where((t) => t.id.equals(dach.id)))
          .write(const CompartmentsCompanion(seite: Value('heck')));

      await seeder.seedIfNeeded();

      // Wer sein Demo-Fahrzeug selbst verortet hat, behält seine Zuordnung.
      expect((await faecherVon(vehicleId))['Dach']?.seite, 'heck');
    });

    test('fasst gleichnamige Fächer anderer Fahrzeuge nicht an', () async {
      await alteInstallation();
      final echtes = await db.vehicleDao.insertVehicle(
          VehiclesCompanion.insert(name: 'LF 20', type: 'LF 20'));
      // „Dach" heißt an fast jedem Fahrzeug so — der Nachtrag darf nur das
      // Demo-Fahrzeug aus vehicle.json betreffen.
      await db.compartmentDao.insertCompartment(
          CompartmentsCompanion.insert(vehicleId: echtes, label: 'Dach'));

      await seeder.seedIfNeeded();

      expect((await faecherVon(echtes))['Dach']?.seite, isNull);
    });
  });
}
