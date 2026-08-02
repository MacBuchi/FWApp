/// equipment_repository_impl.dart – Drift-backed EquipmentRepository implementation.
library;
import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_item.dart';
import 'package:fwapp/features/equipment/domain/repositories/equipment_repository.dart';

class EquipmentRepositoryImpl implements EquipmentRepository {
  final EquipmentDao _dao;
  EquipmentRepositoryImpl(this._dao);

  @override
  Future<List<EquipmentItem>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<EquipmentItem>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toEntity).toList());

  @override
  Future<EquipmentItem?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<EquipmentItem?> getByLibraryId(String libraryId) async {
    final row = await _dao.getByLibraryId(libraryId);
    return row == null ? null : _toEntity(row);
  }

  /// Jede Pflege über diese Schicht ist eine Änderung am GERÄTETYP und
  /// gehört damit der ganzen Gesamtwehr (Stufe ②, Issue #99). Das
  /// Kennzeichen sammelt sie ein; verteilt wird zeilenweise über
  /// `EquipmentTypeSync.push`, unabhängig vom Snapshot der Abteilung.
  ///
  /// Bewusst hier und nicht im DAO: Seeder und Import-Assistent schreiben
  /// direkt über das DAO, und ihre Massen gehören nicht Zeile für Zeile in
  /// den geteilten Bestand — sie kommen über den Snapshot dorthin.
  static const _typGeaendert = Value(true);

  @override
  Future<int> insert(EquipmentItem item) => _dao.insertEquipment(
        EquipmentItemsCompanion.insert(
          typeDirty: _typGeaendert,
          name: item.name,
          shortName: Value(item.shortName),
          trainingQuestionsJson:
              Value(stringListToJson(item.trainingQuestions)),
          typicalUseJson: Value(stringListToJson(item.typicalUse)),
          equipmentFunctionsJson:
              Value(stringListToJson(item.equipmentFunctions)),
          deploymentScenariosJson:
              Value(stringListToJson(item.deploymentScenarios)),
          description: Value(item.description),
          imagePath: Value(item.imagePath),
          trainingUrl: Value(item.trainingUrl),
          libraryEquipmentId: Value(item.libraryEquipmentId),
          isCustom: Value(item.isCustom),
          extraAttributesJson: Value(mapToJson(item.extraAttributes)),
        ),
      );

  @override
  Future<void> update(EquipmentItem item) => _dao.updateEquipment(
        EquipmentItemsCompanion(
          id: Value(item.id),
          typeDirty: _typGeaendert,
          name: Value(item.name),
          shortName: Value(item.shortName),
          trainingQuestionsJson:
              Value(stringListToJson(item.trainingQuestions)),
          typicalUseJson: Value(stringListToJson(item.typicalUse)),
          equipmentFunctionsJson:
              Value(stringListToJson(item.equipmentFunctions)),
          deploymentScenariosJson:
              Value(stringListToJson(item.deploymentScenarios)),
          description: Value(item.description),
          imagePath: Value(item.imagePath),
          trainingUrl: Value(item.trainingUrl),
          libraryEquipmentId: Value(item.libraryEquipmentId),
          isCustom: Value(item.isCustom),
          extraAttributesJson: Value(mapToJson(item.extraAttributes)),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(int id) => _dao.deleteEquipment(id);

  @override
  Future<int> count() => _dao.count();

  @override
  Future<({int zuordnungen, int exemplare})> verwendungHier(int id) async => (
        zuordnungen: (await _dao.assignmentsFor(id)).length,
        exemplare: (await _dao.instancesFor(id)).length,
      );

  @override
  Future<List<EquipmentItem>> search(String query) async {
    final rows = await _dao.search(query);
    return rows.map(_toEntity).toList();
  }

  EquipmentItem _toEntity(EquipmentItemData row) => EquipmentItem(
        id: row.id,
        name: row.name,
        shortName: row.shortName,
        trainingQuestions: jsonToStringList(row.trainingQuestionsJson),
        typicalUse: jsonToStringList(row.typicalUseJson),
        equipmentFunctions: jsonToStringList(row.equipmentFunctionsJson),
        deploymentScenarios: jsonToStringList(row.deploymentScenariosJson),
        description: row.description,
        imagePath: row.imagePath,
        trainingUrl: row.trainingUrl,
        libraryEquipmentId: row.libraryEquipmentId,
        isCustom: row.isCustom,
        extraAttributes: jsonToMap(row.extraAttributesJson),
        updatedAt: row.updatedAt,
        remoteTypeId: row.remoteTypeId,
        typeDirty: row.typeDirty,
      );
}
