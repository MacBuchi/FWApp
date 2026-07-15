/// import_e2e_test.dart – Full import pipeline against the bundled example
/// Beladeliste CSV: parse → detect mapping → match against the seeded
/// library → apply → verify, including idempotent re-import and alias learning.
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/library_seeder.dart';
import 'package:fwapp/features/import/data/equipment_matcher.dart';
import 'package:fwapp/features/import/data/import_parser.dart';
import 'package:fwapp/features/import/data/import_service.dart';
import 'package:fwapp/features/import/domain/import_models.dart';
import 'package:fwapp/features/import/presentation/providers/import_wizard_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const csvPath = 'examples/beladelisten/HLF20-Beispiel.csv';

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    // Seed catalog + demo vehicle so the matcher has real data.
    await LibrarySeeder(db).seedIfNeeded();
  });

  tearDown(() => db.close());

  Future<EquipmentMatcher> createMatcher() async {
    final equipment = await db.equipmentDao.getAll();
    final aliasesRaw = await File('assets/equipment_library/aliases.json')
        .readAsString();
    final bundled = parseBundledAliases(aliasesRaw);
    final userAliases = await db.select(db.userAliases).get();
    return EquipmentMatcher(
        equipment: equipment,
        bundledAliases: bundled,
        userAliases: userAliases);
  }

  test('example HLF20 CSV: mapping detected, ≥95% matched, import applies',
      () async {
    final bytes = File(csvPath).readAsBytesSync();
    final file = ImportParser.parse(csvPath, bytes);
    final table = file.tables.single;

    // Column auto-detection on the real header.
    var mapping = ImportParser.detectMapping(table.rows.first);
    expect(mapping.equipmentColumn, greaterThanOrEqualTo(0));
    expect(mapping.compartmentColumn, greaterThanOrEqualTo(0));
    expect(mapping.vehicleColumn, isNull); // list has no vehicle column
    mapping = mapping.copyWith(fixedVehicleName: 'HLF 20 Import-Test');
    expect(mapping.isValid, isTrue);

    final rows = ImportParser.applyMapping(table, mapping);
    expect(rows.length, 108); // Positionen in HLF20-Beispiel.csv

    // Matching: the CSV is the source of the seeded library, so nearly
    // everything must resolve as exact/alias.
    final matcher = await createMatcher();
    final decisions = <String, RowDecision>{};
    var matched = 0;
    var unmatchedNames = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final key = EquipmentMatcher.normalize(row.equipmentName);
      if (!seen.add(key)) continue;
      final match = matcher.match(row.equipmentName);
      if (match.kind == MatchKind.exact ||
          match.kind == MatchKind.alias ||
          match.kind == MatchKind.fuzzy) {
        matched++;
        decisions[key] = RowDecision(
            action: RowAction.useEquipment,
            equipmentId: match.best!.equipmentId);
      } else {
        unmatchedNames.add(row.equipmentName);
        decisions[key] = const RowDecision(action: RowAction.createCustom);
      }
    }
    final matchRate = matched / seen.length;
    expect(matchRate, greaterThanOrEqualTo(0.95),
        reason: 'Unerkannt: ${unmatchedNames.take(10).join(' | ')}');

    // Apply.
    final service = ImportService(db);
    final result =
        await service.apply(rows: rows, decisions: decisions);
    expect(result.assignmentsWritten, rows.length);
    expect(result.vehiclesCreated, 1);

    // Re-import is idempotent: nothing new is created.
    final second = await service.apply(rows: rows, decisions: decisions);
    expect(second.vehiclesCreated, 0);
    expect(second.compartmentsCreated, 0);
    expect(second.customItemsCreated, 0);
  });

  test('alias learning: second import resolves via UserAlias', () async {
    final matcher = await createMatcher();
    // A creative spelling that only fuzzy-matches initially.
    const creative = 'Werkzeugkasten DIN 14881 (Feuerwehr)';
    final first = matcher.match(creative);
    expect(first.kind, MatchKind.fuzzy);

    final rows = [
      const ImportRow(
        sourceRowIndex: 1,
        vehicleName: 'LF Test',
        compartmentLabel: 'G1',
        equipmentName: creative,
        quantity: 1,
      ),
    ];
    final key = EquipmentMatcher.normalize(creative);
    await ImportService(db).apply(rows: rows, decisions: {
      key: RowDecision(
        action: RowAction.useEquipment,
        equipmentId: first.best!.equipmentId,
        rememberAlias: true,
      ),
    });

    // A fresh matcher now resolves the same spelling as a direct alias.
    final matcherAfter = await createMatcher();
    final second = matcherAfter.match(creative);
    expect(second.kind, MatchKind.alias);
    expect(second.best!.equipmentId, first.best!.equipmentId);
  });
}
