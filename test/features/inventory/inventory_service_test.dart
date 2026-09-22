/// inventory_service_test.dart – Inventurassistent-Logik: Soll-Snapshot beim
/// Start, Status setzen, Summary-Aggregation, Resume statt Doppelanlage.
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inventory/presentation/providers/inventory_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InventoryService service;
  late int vehicleId;
  late int compartmentId;

  setUp(() async {
    db = createTestDatabase();
    service = InventoryService(db);
    vehicleId = await db.vehicleDao
        .insertVehicle(VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF'));
    compartmentId = await db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
    for (final (name, qty) in [('Spineboard', 1), ('Feuerlöscher', 2)]) {
      final eq = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: name));
      await db.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
              compartmentId: compartmentId,
              equipmentId: eq,
              quantity: Value(qty)));
    }
  });

  tearDown(() => db.close());

  test('startOrResume snapshottet die Soll-Beladung', () async {
    final sessionId = await service.startOrResume(vehicleId);
    final checks = await db.inventoryDao.getChecks(sessionId);
    expect(checks, hasLength(2));
    expect(checks.map((c) => c.equipmentName),
        containsAll(['Spineboard', 'Feuerlöscher']));
    expect(checks.every((c) => c.status == InventoryChecks.statusOpen), isTrue);
    final loescher =
        checks.firstWhere((c) => c.equipmentName == 'Feuerlöscher');
    expect(loescher.targetQuantity, 2);
    expect(loescher.compartmentLabel, 'G1');
  });

  test('startOrResume nimmt offene Session wieder auf statt neu anzulegen',
      () async {
    final first = await service.startOrResume(vehicleId);
    final second = await service.startOrResume(vehicleId);
    expect(second, first);
    // Keine doppelten Checks.
    expect(await db.inventoryDao.getChecks(first), hasLength(2));
  });

  test('Status setzen und Summary-Aggregation', () async {
    final sessionId = await service.startOrResume(vehicleId);
    final checks = await db.inventoryDao.getChecks(sessionId);
    await service.setStatus(checks[0].id, InventoryChecks.statusOk);
    await service.setStatus(checks[1].id, InventoryChecks.statusMissing,
        note: 'nicht auffindbar');

    final updated = await db.inventoryDao.getChecks(sessionId);
    final summary = InventorySummary.from(updated);
    expect(summary.total, 2);
    expect(summary.checked, 2);
    expect(summary.ok, 1);
    expect(summary.missing, 1);
    expect(summary.complete, isTrue);
    expect(summary.hasIssues, isTrue);
    expect(
        updated.firstWhere((c) => c.status == InventoryChecks.statusMissing).note,
        'nicht auffindbar');
  });

  test('„in Reparatur" zählt als geprüft und als Abweichung', () async {
    // Der Zustand kam mit #178 dazu. Er darf nicht in `checked` fehlen —
    // sonst gilt eine vollständig durchgegangene Inventur als unfertig und
    // der Gerätewart sucht ein Gerät, das er selbst weggegeben hat.
    final sessionId = await service.startOrResume(vehicleId);
    final checks = await db.inventoryDao.getChecks(sessionId);
    await service.setStatus(checks[0].id, InventoryChecks.statusOk);
    await service.setStatus(checks[1].id, InventoryChecks.statusRepair,
        note: 'bei der Prüfstelle');

    final summary =
        InventorySummary.from(await db.inventoryDao.getChecks(sessionId));
    expect(summary.repair, 1);
    expect(summary.checked, 2);
    expect(summary.complete, isTrue);
    expect(summary.hasIssues, isTrue);
    // Und es ist KEIN fehlendes Gerät — die beiden dürfen nicht verschmelzen.
    expect(summary.missing, 0);
    expect(summary.damaged, 0);
  });

  test('ein Gerät in Reparatur erscheint im Bericht', () async {
    // Gegen den Fehler, der beim Hinzufügen eines Zustands am leichtesten
    // passiert: Die Aggregation kennt ihn, die Mängelliste filtert ihn weg.
    final sessionId = await service.startOrResume(vehicleId);
    final checks = await db.inventoryDao.getChecks(sessionId);
    await service.setStatus(checks[0].id, InventoryChecks.statusRepair);

    final updated = await db.inventoryDao.getChecks(sessionId);
    final abweichungen = updated
        .where((c) => InventorySummary.abweichendeStatus.contains(c.status));
    expect(abweichungen, hasLength(1));
    expect(abweichungen.first.status, InventoryChecks.statusRepair);
  });

  group('Abhaken per Code (#177/#179)', () {
    /// Legt eine Einheit des Geräts [name] mit Code [code] an.
    Future<void> tagge(String name, String code, {int? fach}) async {
      final eq = (await db.equipmentDao.getAll())
          .firstWhere((e) => e.name == name);
      final instanz = await db.into(db.equipmentInstances).insert(
          EquipmentInstancesCompanion.insert(
              equipmentId: Value(eq.id).value,
              compartmentId: Value(fach ?? compartmentId)));
      await db.tagDao.insertTag(
          EquipmentTagsCompanion.insert(instanceId: instanz, code: code));
    }

    test('ein Code hakt sein Gerät ab', () async {
      await tagge('Spineboard', 'FW-AAAAAAA');
      final sessionId = await service.startOrResume(vehicleId);

      final ergebnis = await service.hakeCodeAb(sessionId, 'FW-AAAAAAA');
      expect(ergebnis, isA<Abgehakt>());
      final a = ergebnis as Abgehakt;
      expect(a.geraet, 'Spineboard');
      expect(a.fach, 'G1');
      expect(a.ist, 1);
      expect(a.soll, 1);

      final check = (await db.inventoryDao.getChecks(sessionId))
          .firstWhere((c) => c.equipmentName == 'Spineboard');
      expect(check.status, InventoryChecks.statusOk);
      expect(check.actualQuantity, 1);
    });

    test('der Code darf getippt sein, wie er will', () async {
      // Derselbe Weg wie beim Scanner: normalisiert wird im Dienst.
      await tagge('Spineboard', 'FW-AAAAAAA');
      final sessionId = await service.startOrResume(vehicleId);
      expect(await service.hakeCodeAb(sessionId, '  fw-aaaaaaa\n'),
          isA<Abgehakt>());
    });

    test('bei Soll 2 gilt erst der zweite Scan als vollständig', () async {
      // Sonst meldete das erste von zwei Stücken das Fach als fertig.
      await tagge('Feuerlöscher', 'FW-BBBBBBB');
      await tagge('Feuerlöscher', 'FW-CCCCCCC');
      final sessionId = await service.startOrResume(vehicleId);

      final erst = await service.hakeCodeAb(sessionId, 'FW-BBBBBBB');
      expect((erst as Abgehakt).ist, 1);
      var check = (await db.inventoryDao.getChecks(sessionId))
          .firstWhere((c) => c.equipmentName == 'Feuerlöscher');
      expect(check.status, InventoryChecks.statusOpen,
          reason: 'Ein Stück von zwei ist noch nicht vollständig.');
      expect(check.actualQuantity, 1);

      final zweit = await service.hakeCodeAb(sessionId, 'FW-CCCCCCC');
      expect((zweit as Abgehakt).ist, 2);
      check = (await db.inventoryDao.getChecks(sessionId))
          .firstWhere((c) => c.equipmentName == 'Feuerlöscher');
      expect(check.status, InventoryChecks.statusOk);
    });

    test('derselbe Aufkleber zweimal zählt nur einmal', () async {
      // ⚠️ Der Fehler, der diesen Test erzwungen hat: Die Kamera liefert
      // denselben Code, solange er im Bild ist. Vor #179 stieg die Stückzahl
      // bei jedem Bild weiter — sieben Sekunden ruhig gehalten ergaben „3
      // von 4", also ein Fach, das sich selbst als vollständig meldet.
      await tagge('Feuerlöscher', 'FW-BBBBBBB');   // Soll 2
      final sessionId = await service.startOrResume(vehicleId);

      final erst = await service.hakeCodeAb(sessionId, 'FW-BBBBBBB');
      expect((erst as Abgehakt).ist, 1);

      final nochmal = await service.hakeCodeAb(sessionId, 'FW-BBBBBBB');
      expect(nochmal, isA<SchonGezaehlt>(),
          reason: 'Dieselbe Einheit liegt nicht zweimal da.');
      expect((nochmal as SchonGezaehlt).ist, 1);

      final check = (await db.inventoryDao.getChecks(sessionId))
          .firstWhere((c) => c.equipmentName == 'Feuerlöscher');
      expect(check.actualQuantity, 1);
      expect(check.status, InventoryChecks.statusOpen,
          reason: 'Ein Stück von zwei bleibt unvollständig, egal wie oft '
              'die Kamera es liest.');
    });

    test('zwei verschiedene Einheiten zählen beide', () async {
      // Die Gegenprobe zur Sperre oben: Sie darf nicht zu viel sperren.
      await tagge('Feuerlöscher', 'FW-BBBBBBB');
      await tagge('Feuerlöscher', 'FW-CCCCCCC');
      final sessionId = await service.startOrResume(vehicleId);

      await service.hakeCodeAb(sessionId, 'FW-BBBBBBB');
      final zweit = await service.hakeCodeAb(sessionId, 'FW-CCCCCCC');
      expect((zweit as Abgehakt).ist, 2);

      final check = (await db.inventoryDao.getChecks(sessionId))
          .firstWhere((c) => c.equipmentName == 'Feuerlöscher');
      expect(check.status, InventoryChecks.statusOk);
    });

    test('ein unbekannter Code hakt nichts ab', () async {
      final sessionId = await service.startOrResume(vehicleId);
      expect(await service.hakeCodeAb(sessionId, 'FW-ZZZZZZZ'),
          isA<CodeUnbekannt>());
      final checks = await db.inventoryDao.getChecks(sessionId);
      expect(checks.every((c) => c.status == InventoryChecks.statusOpen),
          isTrue);
    });

    test('ein Gerät von einem anderen Fahrzeug wird benannt, nicht gezählt',
        () async {
      // Der Fall, den man vor dem Fach wirklich hat: falscher Aufkleber
      // gegriffen. „Nichts passiert" wäre die schlechteste Antwort.
      final anderes = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: 'Wärmebildkamera'));
      final instanz = await db.into(db.equipmentInstances).insert(
          EquipmentInstancesCompanion.insert(equipmentId: anderes));
      await db.tagDao.insertTag(EquipmentTagsCompanion.insert(
          instanceId: instanz, code: 'FW-DDDDDDD'));

      final sessionId = await service.startOrResume(vehicleId);
      final ergebnis = await service.hakeCodeAb(sessionId, 'FW-DDDDDDD');
      expect(ergebnis, isA<CodeNichtInDieserInventur>());
      expect((ergebnis as CodeNichtInDieserInventur).geraet,
          'Wärmebildkamera');
    });

    test('eine leere Eingabe ist kein Fund', () async {
      final sessionId = await service.startOrResume(vehicleId);
      expect(await service.hakeCodeAb(sessionId, '   '), isA<CodeLeer>());
    });
  });

  group('Abhaken per NFC-Tag (#176)', () {
    /// Wie oben, aber der Code kommt vom Tag statt vom Aufkleber.
    Future<void> tagge(String name, String code) async {
      final eq = (await db.equipmentDao.getAll())
          .firstWhere((e) => e.name == name);
      final instanz = await db.into(db.equipmentInstances).insert(
          EquipmentInstancesCompanion.insert(
              equipmentId: Value(eq.id).value,
              compartmentId: Value(compartmentId)));
      await db.tagDao.insertTag(EquipmentTagsCompanion.insert(
          instanceId: instanz,
          code: code,
          kind: const Value(EquipmentTags.kindNfc)));
    }

    test('der zweite Kandidat zählt, wenn der erste ins Leere zeigt',
        () async {
      // ⚠️ Der Fall, um den es geht: Das Tag trug schon eine fremde
      // Aufschrift, die App hat es deshalb über seine SERIENNUMMER
      // verknüpft. Wer nur den Text probiert, meldet „klebt auf keinem
      // erfassten Gerät" — obwohl es klebt.
      await tagge('Spineboard', 'NFC-041ABCDEF0');
      final sessionId = await service.startOrResume(vehicleId);

      final ergebnis = await service.hakeKandidatenAb(
          sessionId, ['Inventar 2019 Halle B', 'NFC-041ABCDEF0']);

      expect(ergebnis, isA<Abgehakt>());
      expect((ergebnis as Abgehakt).geraet, 'Spineboard');
    });

    test('der erste Treffer gewinnt', () async {
      // Ein Tag, das beschrieben UND über seine Seriennummer bekannt ist.
      // Der Text steht vorn, weil wir ihn selbst daraufgeschrieben haben.
      await tagge('Spineboard', 'FW-7K2M9Q');
      await tagge('Feuerlöscher', 'NFC-041ABCDEF0');
      final sessionId = await service.startOrResume(vehicleId);

      final ergebnis = await service
          .hakeKandidatenAb(sessionId, ['FW-7K2M9Q', 'NFC-041ABCDEF0']);

      expect((ergebnis as Abgehakt).geraet, 'Spineboard');
    });

    test('kennt der Bestand keinen der beiden, bleibt es dabei', () async {
      final sessionId = await service.startOrResume(vehicleId);
      expect(
        await service
            .hakeKandidatenAb(sessionId, ['Irgendwas', 'NFC-00000000']),
        isA<CodeUnbekannt>(),
      );
    });

    test('ein Tag ohne alles ist kein Fund', () async {
      // Kommt vor: ein leeres Tag, dessen Seriennummer das Gerät nicht
      // herausgibt. Daraus darf kein Absturz und keine falsche Meldung
      // werden.
      final sessionId = await service.startOrResume(vehicleId);
      expect(await service.hakeKandidatenAb(sessionId, []), isA<CodeLeer>());
    });

    test('derselbe Aufkleber zweimal zählt einmal — auch über NFC', () async {
      // Dieselbe Zusicherung wie beim Scannen, auf dem neuen Weg: Android
      // meldet ein liegendes Tag wieder und wieder.
      await tagge('Feuerlöscher', 'NFC-041ABCDEF0');
      final sessionId = await service.startOrResume(vehicleId);

      final erst =
          await service.hakeKandidatenAb(sessionId, ['NFC-041ABCDEF0']);
      final nochmal =
          await service.hakeKandidatenAb(sessionId, ['NFC-041ABCDEF0']);

      expect(erst, isA<Abgehakt>());
      expect(nochmal, isA<SchonGezaehlt>());
      expect((nochmal as SchonGezaehlt).ist, 1,
          reason: 'Der Bestand darf vom Liegenbleiben nicht wachsen.');
    });
  });

  test('finish schließt die Session (kein Resume mehr)', () async {
    final sessionId = await service.startOrResume(vehicleId);
    await service.finish(sessionId, doneBy: 'Marcus');
    final session = await db.inventoryDao.getSession(sessionId);
    expect(session!.finishedAt, isNotNull);
    expect(session.doneBy, 'Marcus');
    // Neuer Start legt eine frische Session an.
    final next = await service.startOrResume(vehicleId);
    expect(next, isNot(sessionId));
  });
}
