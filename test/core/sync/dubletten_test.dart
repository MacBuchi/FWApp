/// dubletten_test.dart – Zwei Einträge, die dasselbe Gerät meinen (#67).
///
/// Geprüft wird beides, und das zweite wiegt schwerer: dass gefunden wird,
/// was wirklich doppelt ist — **und dass ein gewöhnlicher Bestand still
/// bleibt**. Eine Rückfrage, die vor jedem Veröffentlichen kommt, wird nach
/// dem dritten Mal weggeklickt, und dann schützt sie vor nichts mehr.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/dubletten.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<int> geraet(String name, {bool neu = true}) async {
    final id = await db.equipmentDao.insertEquipment(
      EquipmentItemsCompanion.insert(name: name, dirty: Value(neu)),
    );
    return id;
  }

  Future<int> fahrzeug(String name) => db.vehicleDao.insertVehicle(
    VehiclesCompanion.insert(name: name, type: 'HLF'),
  );

  Future<int> fach(int fahrzeugId, String label) =>
      db.compartmentDao.insertCompartment(
        CompartmentsCompanion.insert(vehicleId: fahrzeugId, label: label),
      );

  Future<int> lege(int fachId, int geraetId, {int anzahl = 1}) =>
      db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
          compartmentId: fachId,
          equipmentId: geraetId,
          quantity: Value(anzahl),
        ),
      );

  // ── Finden ──────────────────────────────────────────────────────────

  test('⚠️ ein gewöhnlicher Bestand meldet NICHTS', () async {
    // Der wichtigste Fall. Echte Nachbarn in einem Geräteraum: Sie teilen
    // Wörter, meinen aber verschiedene Dinge.
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    for (final name in [
      'Strahlrohr C',
      'Verteiler B-CBC',
      'Standrohr',
      'Unterflurhydrantenschlüssel',
    ]) {
      await lege(g1, await geraet(name));
    }

    expect(await findeDubletten(db), isEmpty);
  });

  test('gleiches Fach, andere Schreibweise: gefunden', () async {
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final a = await geraet('Strahlrohr C', neu: false);
    final b = await geraet('C-Strahlrohr');
    await lege(g1, a);
    await lege(g1, b);

    final treffer = await findeDubletten(db);

    expect(treffer, hasLength(1));
    expect(treffer.single.art, DublettenArt.position);
    expect(treffer.single.ort, 'HLF 20 · G1');
    expect(
      treffer.single.behalten.id,
      a,
      reason: 'Der veröffentlichte Eintrag ist oben der Schlüssel.',
    );
    expect(treffer.single.aufgeben.id, b);
  });

  test('⚠️ verschiedene Fächer sind KEINE Positions-Dublette', () async {
    // Marcus\' Regel: Fahrzeug und Geräteraum müssen identisch sein. Ein
    // Strahlrohr im Heck ist ein zweites Strahlrohr, kein doppelt erfasstes.
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final heck = await fach(v, 'Heck');
    await lege(g1, await geraet('Strahlrohr C', neu: false));
    await lege(heck, await geraet('Strahlrohr C-Storz'));

    final treffer = await findeDubletten(db);

    expect(
      treffer.where((d) => d.art == DublettenArt.position),
      isEmpty,
      reason: 'Zwei Fächer heißen zwei Stellen.',
    );
  });

  test('derselbe Typ in zwei Fächern: als Katalog-Verdacht gefunden', () async {
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final heck = await fach(v, 'Heck');
    await lege(g1, await geraet('Schlauchhalter', neu: false));
    await lege(heck, await geraet('Schlauchhalterung'));

    final treffer = await findeDubletten(db);

    expect(treffer, hasLength(1));
    expect(treffer.single.art, DublettenArt.katalog);
    expect(treffer.single.ort, 'G1 und Heck');
  });

  test(
    '⚠️ zwei längst veröffentlichte Einträge werden nicht angefasst',
    () async {
      // Bestandsdaten sind nicht die Folge des Zusammenführens. Sie ungefragt
      // aufzuräumen wäre etwas anderes als das, was gerade getan wird — und
      // die Rückfrage käme bei jedem Veröffentlichen erneut.
      final v = await fahrzeug('HLF 20');
      final g1 = await fach(v, 'G1');
      await lege(g1, await geraet('Strahlrohr C', neu: false));
      await lege(g1, await geraet('C-Strahlrohr', neu: false));

      expect(await findeDubletten(db), isEmpty);
    },
  );

  test('dasselbe Paar wird nur einmal gemeldet', () async {
    // Ein Paar erfüllt beide Regeln zugleich — gleiches Fach UND sehr
    // ähnlicher Name. Zweimal gefragt zu werden wäre verwirrend.
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final a = await geraet('Schlauchhalter', neu: false);
    final b = await geraet('Schlauchhalterung');
    await lege(g1, a);
    await lege(g1, b);

    final treffer = await findeDubletten(db);

    expect(treffer, hasLength(1));
    expect(
      treffer.single.art,
      DublettenArt.position,
      reason: 'Die Position ist die sicherere Aussage und gewinnt.',
    );
  });

  test('sind beide neu, gewinnt der ältere Eintrag', () async {
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final a = await geraet('Strahlrohr C');
    final b = await geraet('C-Strahlrohr');
    await lege(g1, a);
    await lege(g1, b);

    final treffer = await findeDubletten(db);

    expect(treffer.single.behalten.id, a);
    expect(treffer.single.aufgeben.id, b);
  });

  // ── Zusammenführen ──────────────────────────────────────────────────

  test('die Beladung zieht um, der aufgegebene Eintrag verschwindet', () async {
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final heck = await fach(v, 'Heck');
    final a = await geraet('Strahlrohr C', neu: false);
    final b = await geraet('C-Strahlrohr');
    await lege(g1, a, anzahl: 2);
    await lege(heck, b, anzahl: 3);

    await fuehreZusammen(db, behalten: a, aufgeben: b);

    expect(await db.equipmentDao.getById(b), isNull);
    final zuordnungen = await db.select(db.equipmentAssignments).get();
    expect(zuordnungen, hasLength(2));
    expect(zuordnungen.every((z) => z.equipmentId == a), isTrue);
    expect(
      zuordnungen.firstWhere((z) => z.compartmentId == heck).quantity,
      3,
      reason:
          'Die Beladung im Heck bleibt, sie hängt jetzt nur am anderen '
          'Eintrag.',
    );
  });

  test('⚠️ im selben Fach werden die Stückzahlen addiert', () async {
    // Beide haben dieselbe Beladung gezählt, jeder seinen Teil. Bliebe nur
    // eine Zeile stehen, fehlte die Hälfte der Geräte im Bestand.
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final a = await geraet('Strahlrohr C', neu: false);
    final b = await geraet('C-Strahlrohr');
    await lege(g1, a, anzahl: 2);
    await lege(g1, b, anzahl: 3);

    await fuehreZusammen(db, behalten: a, aufgeben: b);

    final zuordnungen = await db.select(db.equipmentAssignments).get();
    expect(zuordnungen, hasLength(1));
    expect(zuordnungen.single.quantity, 5);
  });

  test('⚠️ die Geräte-Einheiten überleben mitsamt ihren Codes', () async {
    // Der Aufkleber klebt am Gerät. Ginge die Einheit beim Zusammenführen
    // verloren, zeigte der Code beim nächsten Scannen ins Leere.
    final a = await geraet('Strahlrohr C', neu: false);
    final b = await geraet('C-Strahlrohr');
    final einheit = await db.inspectionDao.insertInstance(
      EquipmentInstancesCompanion.insert(
        equipmentId: b,
        identifier: const Value('SR-7'),
      ),
    );
    await db
        .into(db.equipmentTags)
        .insert(
          EquipmentTagsCompanion.insert(
            instanceId: einheit,
            code: 'FW-0007',
            kind: const Value(EquipmentTags.kindQr),
          ),
        );

    await fuehreZusammen(db, behalten: a, aufgeben: b);

    final einheiten = await db.select(db.equipmentInstances).get();
    expect(einheiten, hasLength(1));
    expect(einheiten.single.equipmentId, a);
    final codes = await db.select(db.equipmentTags).get();
    expect(codes.single.code, 'FW-0007');
    expect(codes.single.instanceId, einheit);
  });

  test('⚠️ der Lernfortschritt beider wird addiert, nicht verworfen', () async {
    // `learning_progress` hat UNIQUE(equipment_id) — schlichtes Umhängen
    // liefe in einen Constraint-Bruch, sobald beide schon abgefragt wurden.
    final a = await geraet('Strahlrohr C', neu: false);
    final b = await geraet('C-Strahlrohr');
    for (final (id, richtig, falsch) in [(a, 3, 1), (b, 4, 2)]) {
      await db
          .into(db.learningProgress)
          .insert(
            LearningProgressCompanion.insert(
              equipmentId: id,
              correctCount: Value(richtig),
              wrongCount: Value(falsch),
            ),
          );
    }

    await fuehreZusammen(db, behalten: a, aufgeben: b);

    final fortschritt = await db.select(db.learningProgress).get();
    expect(fortschritt, hasLength(1));
    expect(fortschritt.single.equipmentId, a);
    expect(fortschritt.single.correctCount, 7);
    expect(fortschritt.single.wrongCount, 3);
  });

  test(
    'der Lernfortschritt zieht um, wenn nur der aufgegebene einen hat',
    () async {
      final a = await geraet('Strahlrohr C', neu: false);
      final b = await geraet('C-Strahlrohr');
      await db
          .into(db.learningProgress)
          .insert(
            LearningProgressCompanion.insert(
              equipmentId: b,
              correctCount: const Value(5),
            ),
          );

      await fuehreZusammen(db, behalten: a, aufgeben: b);

      final fortschritt = await db.select(db.learningProgress).get();
      expect(fortschritt.single.equipmentId, a);
      expect(fortschritt.single.correctCount, 5);
    },
  );

  test(
    'gelernte Schreibweisen zeigen danach auf das behaltene Gerät',
    () async {
      final a = await geraet('Strahlrohr C', neu: false);
      final b = await geraet('C-Strahlrohr');
      await db
          .into(db.userAliases)
          .insert(UserAliasesCompanion.insert(alias: 'Rohr C', equipmentId: b));

      await fuehreZusammen(db, behalten: a, aufgeben: b);

      final aliasse = await db.select(db.userAliases).get();
      expect(aliasse.single.equipmentId, a);
    },
  );

  test('⚠️ der überlebende Eintrag gilt danach als unveröffentlicht', () async {
    // Er trägt jetzt die Beladung von zweien. Bliebe er auf „war schon
    // oben", räumte der nächste Zug die Zusammenführung wieder ab.
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final a = await geraet('Strahlrohr C', neu: false);
    final b = await geraet('C-Strahlrohr');
    await lege(g1, a);
    await lege(g1, b);

    await fuehreZusammen(db, behalten: a, aufgeben: b);

    expect((await db.equipmentDao.getById(a))!.dirty, isTrue);
    final zuordnungen = await db.select(db.equipmentAssignments).get();
    expect(zuordnungen.single.dirty, isTrue);
  });

  test('nach dem Zusammenführen ist nichts mehr zu melden', () async {
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final a = await geraet('Strahlrohr C', neu: false);
    final b = await geraet('C-Strahlrohr');
    await lege(g1, a);
    await lege(g1, b);

    final treffer = await findeDubletten(db);
    await fuehreZusammen(
      db,
      behalten: treffer.single.behalten.id,
      aufgeben: treffer.single.aufgeben.id,
    );

    expect(await findeDubletten(db), isEmpty);
  });

  test('⚠️ drei Schreibweisen: die Kette laeuft nicht ins Leere', () async {
    // Zwei Paare, die sich eine ID teilen. Ohne Umleitung nennt das zweite
    // eine Zeile, die das erste schon geloescht hat.
    final v = await fahrzeug('HLF 20');
    final g1 = await fach(v, 'G1');
    final a = await geraet('Schlauchhalter', neu: false);
    final b = await geraet('Schlauchhalterung');
    final c = await geraet('Schlauch-Halterung');
    await lege(g1, a, anzahl: 1);
    await lege(g1, b, anzahl: 2);
    await lege(g1, c, anzahl: 4);

    await fuehreAlleZusammen(db, [
      (behalten: a, aufgeben: b),
      (behalten: b, aufgeben: c),
    ]);

    expect(await db.equipmentDao.getAll(), hasLength(1));
    final zuordnungen = await db.select(db.equipmentAssignments).get();
    expect(zuordnungen, hasLength(1));
    expect(
      zuordnungen.single.quantity,
      7,
      reason: 'Keine der drei gezaehlten Mengen darf unterwegs verlorengehen.',
    );
  });

  test(
    'ein Paar, das sich durch die Kette aufloest, wird uebersprungen',
    () async {
      final a = await geraet('Schlauchhalter', neu: false);
      final b = await geraet('Schlauchhalterung');

      await fuehreAlleZusammen(db, [
        (behalten: a, aufgeben: b),
        (behalten: a, aufgeben: b),
      ]);

      expect(await db.equipmentDao.getAll(), hasLength(1));
    },
  );
}
