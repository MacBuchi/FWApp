/// equipment_matcher_test.dart – Exact/alias/fuzzy matching behaviour.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/import/data/equipment_matcher.dart';
import 'package:fwapp/features/import/domain/import_models.dart';

EquipmentItemData _item(int id, String name,
        {String? libraryId, String? shortName}) =>
    EquipmentItemData(
      id: id,
      name: name,
      shortName: shortName,
      equipmentFunctionsJson: '[]',
      deploymentScenariosJson: '[]',
      description: '',
      isCustom: false,
      extraAttributesJson: '{}',
      trainingQuestionsJson: '[]',
      typicalUseJson: '[]',
      libraryEquipmentId: libraryId,
      updatedAt: DateTime(2026),
    );

void main() {
  final matcher = EquipmentMatcher(
    equipment: [
      _item(1, 'Kübelspritze', libraryId: 'kuebelspritze'),
      _item(2, 'Chemikalienanzug Typ 1a-ET Modell OneSuit Pro in Tasche',
          libraryId: 'chemikalienanzug', shortName: 'Chemikalienanzug OneSuit'),
      _item(3, 'Feuerwehr-Werkzeugkasten nach DIN 14881',
          libraryId: 'werkzeugkasten'),
      _item(4, 'Spineboard'),
    ],
    bundledAliases: const {
      'kuebelspritze': ['Kübelspritze mit Zubehör', 'Eimerspritze'],
    },
    userAliases: [
      UserAliasData(
          id: 1,
          alias: 'CSA Anzug',
          equipmentId: 2,
          updatedAt: DateTime(2026)),
    ],
  );

  test('normalize folds umlauts and punctuation', () {
    expect(EquipmentMatcher.normalize('Kübelspritze,  Größe-2!'),
        'kuebelspritze groesse 2');
  });

  test('exact match is case- and umlaut-insensitive', () {
    final m = matcher.match('KÜBELSPRITZE');
    expect(m.kind, MatchKind.exact);
    expect(m.best!.equipmentId, 1);
  });

  test('bundled alias resolves', () {
    final m = matcher.match('Eimerspritze');
    expect(m.kind, MatchKind.alias);
    expect(m.best!.equipmentId, 1);
  });

  test('learned user alias resolves', () {
    final m = matcher.match('csa anzug');
    expect(m.kind, MatchKind.alias);
    expect(m.best!.equipmentId, 2);
  });

  test('short name works as alias', () {
    final m = matcher.match('Chemikalienanzug OneSuit');
    expect(m.kind, MatchKind.alias);
    expect(m.best!.equipmentId, 2);
  });

  test('fuzzy match on abbreviated/reordered name', () {
    final m = matcher.match('Werkzeugkasten DIN 14881 Feuerwehr');
    expect(m.kind, MatchKind.fuzzy);
    expect(m.best!.equipmentId, 3);
    expect(m.suggestions.first.equipmentId, 3);
  });

  test('unrelated name yields none, possibly with weak suggestions', () {
    final m = matcher.match('Motorkettensäge');
    expect(m.kind, MatchKind.none);
    expect(m.best, isNull);
  });
}
