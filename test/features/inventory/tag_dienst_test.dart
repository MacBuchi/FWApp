/// tag_dienst_test.dart – Was beim Verknüpfen und Entfernen lokal passiert,
/// seit die Codes synchronisiert werden (Issue #177).
///
/// Geprüft wird die Stelle, an der ein Abgleich still Schaden anrichtet: der
/// Grabstein. Ein entfernter Code bleibt liegen, bis der Server davon weiß —
/// und genau deshalb muss derselbe Aufkleber sich sofort wieder verkleben
/// lassen, ohne an `unique` zu scheitern und ohne dass die Löschung danach
/// noch hochgeht.
///
/// Der Weg zum und vom Server steht in `tag_sync_e2e_test.dart`, gegen den
/// echten Stack. Hier liegt kein Netz.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/inventory/presentation/providers/tag_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TagDienst dienst;
  late int einheitA;
  late int einheitB;

  setUp(() async {
    db = createTestDatabase();
    dienst = TagDienst(db);
    final geraet = await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(name: 'Pressluftatmer'));
    einheitA = await db.inspectionDao.insertInstance(
        EquipmentInstancesCompanion.insert(
            equipmentId: geraet, identifier: const Value('Flasche 3')));
    einheitB = await db.inspectionDao.insertInstance(
        EquipmentInstancesCompanion.insert(
            equipmentId: geraet, identifier: const Value('Flasche 4')));
  });

  tearDown(() => db.close());

  test('ein neuer Code wartet aufs Hochladen', () async {
    final code = await dienst.vergebeCode(einheitA);
    final tag = await db.tagDao.findByCode(code);
    expect(tag!.dirty, isTrue,
        reason: 'Sonst bliebe der Aufkleber für immer auf diesem Gerät.');
  });

  test('ein nie geschobener Code fällt beim Entfernen ganz weg', () async {
    final code = await dienst.vergebeCode(einheitA);
    await dienst.entferne((await db.tagDao.findByCode(code))!);

    expect(await db.tagDao.findByCodeAuchEntfernt(code), isNull,
        reason: 'Er stand nie oben — es gibt nichts mitzuteilen.');
    expect(await db.tagDao.offeneTags(), isEmpty);
  });

  test('ein geschobener Code hinterlässt einen Grabstein', () async {
    final code = await dienst.vergebeCode(einheitA);
    await _alsGeschoben(db, code);

    await dienst.entferne((await db.tagDao.findByCode(code))!);

    // Für die App ist er weg …
    expect(await db.tagDao.findByCode(code), isNull);
    expect(await db.tagDao.getByInstance(einheitA), isEmpty);
    // … aber die Löschung muss noch hoch, sonst schickt ihn das nächste
    // Gerät beim Zug wieder herunter.
    final grabstein = await db.tagDao.findByCodeAuchEntfernt(code);
    expect(grabstein, isNotNull);
    expect(grabstein!.deletedAt, isNotNull);
    expect(grabstein.dirty, isTrue);
  });

  test('ein Grabstein bleibt beim Nachschlagen unsichtbar', () async {
    final code = await dienst.vergebeCode(einheitA);
    await _alsGeschoben(db, code);
    await dienst.entferne((await db.tagDao.findByCode(code))!);

    expect(await dienst.schlageNach(code), isNull,
        reason: 'Der Aufkleber ist ab — er darf nicht mehr abhaken.');
  });

  test('ein Grabstein belegt den Code weiterhin gegen Neuvergabe', () async {
    final code = await dienst.vergebeCode(einheitA);
    await _alsGeschoben(db, code);
    await dienst.entferne((await db.tagDao.findByCode(code))!);

    expect(await db.tagDao.alleCodes(), contains(code),
        reason: 'Solange er oben steht, würde ein zweiter Griff darauf den '
            'fremden Eintrag überschreiben.');
  });

  test('derselbe Aufkleber lässt sich sofort neu verkleben', () async {
    // Der Fall aus dem Geräteraum: Aufkleber abgezogen, auf das
    // Nachbargerät geklebt, alles ohne Netz.
    final code = await dienst.vergebeCode(einheitA);
    await _alsGeschoben(db, code);
    await dienst.entferne((await db.tagDao.findByCode(code))!);

    final ergebnis = await dienst.verknuepfe(einheitB, code);
    expect(ergebnis, isA<TagVerknuepft>());

    final tag = await db.tagDao.findByCode(code);
    expect(tag, isNotNull, reason: 'Er klebt wieder — auf dem neuen Gerät.');
    expect(tag!.instanceId, einheitB);
    expect(tag.deletedAt, isNull,
        reason: 'Sonst schöbe der Abgleich die Löschung hinterher und der '
            'frisch verklebte Code wäre oben tot.');
    expect(tag.dirty, isTrue);
    // Und nur EINE Zeile, sonst bräche das Einfügen an `unique` ab.
    expect((await db.tagDao.alleCodes()).length, 1);
  });

  test('ein klebender Code wird nicht doppelt vergeben', () async {
    final code = await dienst.vergebeCode(einheitA);
    final ergebnis = await dienst.verknuepfe(einheitB, code);
    expect(ergebnis, isA<TagSchonVergeben>());
    expect((ergebnis as TagSchonVergeben).geraet, 'Pressluftatmer');
  });
}

/// Tut so, als wäre der Code schon oben angekommen — das macht sonst
/// `TagSync.schiebe`, und dafür bräuchte es einen Server.
Future<void> _alsGeschoben(AppDatabase db, String code) async {
  final tag = await db.tagDao.findByCode(code);
  await db.tagDao
      .aendere(tag!.id, const EquipmentTagsCompanion(dirty: Value(false)));
}
