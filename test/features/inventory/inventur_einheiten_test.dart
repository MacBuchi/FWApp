/// inventur_einheiten_test.dart – Welche geführten Einheiten zu welcher
/// Prüfzeile gehören (Issue #178).
///
/// Das ist der Teil, den die Tests am Export nicht abdecken: Dort kommen die
/// Einheiten fertig zugeordnet an. Hier wird zugeordnet — und ein falscher
/// Vergleich bliebe still: Die Spalte „Nicht gefunden" wäre dann einfach
/// immer leer, und niemand vermisste sie.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/inventory/presentation/providers/inventory_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int vehicleId;
  late int fachG1;
  late int fachG2;
  late int verteiler;

  setUp(() async {
    db = createTestDatabase();
    container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    vehicleId = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF'));
    fachG1 = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
    fachG2 = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(
            vehicleId: vehicleId, label: 'G2', position: const Value(1)));
    verteiler = await db.equipmentDao
        .insertEquipment(EquipmentItemsCompanion.insert(name: 'Verteiler'));
    await db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: fachG1,
            equipmentId: verteiler,
            quantity: const Value(2)));
    await db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: fachG2,
            equipmentId: verteiler,
            quantity: const Value(1)));
  });

  tearDown(() => db.close());

  Future<int> einheit(String kennung, int fach) =>
      db.inspectionDao.insertInstance(EquipmentInstancesCompanion.insert(
        equipmentId: verteiler,
        vehicleId: Value(vehicleId),
        compartmentId: Value(fach),
        identifier: Value(kennung),
      ));

  test('⚠️ die Einheit landet in der Zeile IHRES Fachs, nicht in beiden',
      () async {
    // Dasselbe Gerät steht in G1 und G2. Ordnete man nur nach Gerät zu,
    // stünde „Verteiler 3" auch in der G2-Zeile als nicht gefunden — und
    // jemand suchte im falschen Fach.
    final inG1 = await einheit('Verteiler 3', fachG1);
    final inG2 = await einheit('Verteiler 9', fachG2);
    final sessionId =
        await container.read(inventoryServiceProvider).startOrResume(vehicleId);

    final proZeile =
        await container.read(inventurEinheitenProvider(sessionId).future);
    final checks = await db.inventoryDao.getChecks(sessionId);
    final g1 = checks.firstWhere((c) => c.compartmentLabel == 'G1');
    final g2 = checks.firstWhere((c) => c.compartmentLabel == 'G2');

    expect(proZeile[g1.id]!.map((e) => e.id), [inG1]);
    expect(proZeile[g2.id]!.map((e) => e.id), [inG2]);
  });

  test('die Codes der Einheit kommen mit', () async {
    final id = await einheit('Verteiler 3', fachG1);
    await db.tagDao.insertTag(
        EquipmentTagsCompanion.insert(instanceId: id, code: 'FW-7K2M9Q'));
    final sessionId =
        await container.read(inventoryServiceProvider).startOrResume(vehicleId);

    final proZeile =
        await container.read(inventurEinheitenProvider(sessionId).future);
    final checks = await db.inventoryDao.getChecks(sessionId);
    final g1 = checks.firstWhere((c) => c.compartmentLabel == 'G1');

    expect(proZeile[g1.id]!.single.codes, ['FW-7K2M9Q']);
    expect(proZeile[g1.id]!.single.beschriftung, 'Verteiler 3 (FW-7K2M9Q)');
  });

  test('ein entfernter Code taucht im Bericht nicht mehr auf', () async {
    // Grabsteine sind abgezogene Aufkleber — im Bericht wären sie eine
    // Spur, die ins Leere führt.
    final id = await einheit('Verteiler 3', fachG1);
    await db.tagDao.insertTag(
        EquipmentTagsCompanion.insert(instanceId: id, code: 'FW-7K2M9Q'));
    final tag = await db.tagDao.findByCode('FW-7K2M9Q');
    await db.tagDao.aendere(
        tag!.id, EquipmentTagsCompanion(deletedAt: Value(DateTime.now())));

    final sessionId =
        await container.read(inventoryServiceProvider).startOrResume(vehicleId);
    final proZeile =
        await container.read(inventurEinheitenProvider(sessionId).future);
    final checks = await db.inventoryDao.getChecks(sessionId);
    final g1 = checks.firstWhere((c) => c.compartmentLabel == 'G1');

    expect(proZeile[g1.id]!.single.codes, isEmpty);
  });

  test('eine Zeile ohne geführte Einheiten bleibt leer, nicht null',
      () async {
    final sessionId =
        await container.read(inventoryServiceProvider).startOrResume(vehicleId);
    final proZeile =
        await container.read(inventurEinheitenProvider(sessionId).future);
    final checks = await db.inventoryDao.getChecks(sessionId);

    for (final c in checks) {
      expect(proZeile[c.id], isEmpty,
          reason: 'Jede Zeile bekommt einen Eintrag, damit der Export nicht '
              'zwischen „leer" und „nicht gefragt" unterscheiden muss.');
    }
  });

  test('eine Einheit im Lager gehört zu keiner Zeile', () async {
    await db.inspectionDao.insertInstance(EquipmentInstancesCompanion.insert(
        equipmentId: verteiler, identifier: const Value('Reserve')));
    final sessionId =
        await container.read(inventoryServiceProvider).startOrResume(vehicleId);

    final proZeile =
        await container.read(inventurEinheitenProvider(sessionId).future);
    expect(proZeile.values.expand((e) => e), isEmpty);
  });
}
