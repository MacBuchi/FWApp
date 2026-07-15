/// catalog_seeder_test.dart – Standard-Grunddatenbank: seeding is idempotent
/// and its aliases resolve typical Beladelisten-Schreibweisen.
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/library_seeder.dart';
import 'package:fwapp/features/import/data/equipment_matcher.dart';
import 'package:fwapp/features/import/domain/import_models.dart';
import 'package:fwapp/features/import/presentation/providers/import_wizard_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await LibrarySeeder(db).seedIfNeeded();
  });

  tearDown(() => db.close());

  test('Katalog wird geseedet, Demo-Fahrzeug referenziert ihn (idempotent)',
      () async {
    final count = await db.equipmentDao.count();
    // Nur der 110er-Katalog – der Demo-Beladeplan legt keine eigenen
    // Geräte an, sondern verweist auf Katalog-Einträge.
    expect(count, 110);

    final kegel = await db.equipmentDao.getByLibraryId('std_leitkegel');
    expect(kegel, isNotNull);
    expect(kegel!.name, 'Verkehrsleitkegel 500 mm');
    expect(kegel.isCustom, isFalse);

    // Zweiter Lauf legt nichts doppelt an.
    await LibrarySeeder(db).seedIfNeeded();
    expect(await db.equipmentDao.count(), count);
  });

  test('Katalog-Aliasse lösen typische Beladelisten-Schreibweisen auf',
      () async {
    final equipment = await db.equipmentDao.getAll();
    final catalogAliases = parseCatalogAliases(
        File('assets/equipment_library/catalog/standard_catalog.json')
            .readAsStringSync());
    final matcher = EquipmentMatcher(
        equipment: equipment, bundledAliases: catalogAliases);

    for (final (raw, expectedLibraryId) in [
      ('Pylone', 'std_leitkegel'),
      ('TS 8/8', 'std_tragkraftspritze'),
      ('HSR', 'std_hohlstrahlrohr'),
      ('B-Schlauch', 'std_b_druckschlauch_20m'),
      ('Greifzug', 'std_mehrzweckzug'),
      ('Rettungsschere', 'std_schneidgeraet'),
    ]) {
      final match = matcher.match(raw);
      expect(match.kind, isIn([MatchKind.exact, MatchKind.alias]),
          reason: '$raw sollte direkt aufgelöst werden');
      final target = equipment
          .firstWhere((e) => e.id == match.best!.equipmentId);
      expect(target.libraryEquipmentId, expectedLibraryId,
          reason: '$raw → falsches Ziel: ${target.name}');
    }
  });
}
