/// equipment_repository_impl.dart – Drift-backed EquipmentRepository implementation.
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

  @override
  Future<int> insert(EquipmentItem item) => _dao.insertEquipment(
        EquipmentItemsCompanion.insert(
          name: item.name,
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
          name: Value(item.name),
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
  Future<List<EquipmentItem>> search(String query) async {
    final rows = await _dao.search(query);
    return rows.map(_toEntity).toList();
  }

  EquipmentItem _toEntity(EquipmentItemData row) => EquipmentItem(
        id: row.id,
        name: row.name,
        equipmentFunctions: jsonToStringList(row.equipmentFunctionsJson),
        deploymentScenarios: jsonToStringList(row.deploymentScenariosJson),
        description: row.description,
        imagePath: row.imagePath,
        trainingUrl: row.trainingUrl,
        libraryEquipmentId: row.libraryEquipmentId,
        isCustom: row.isCustom,
        extraAttributes: jsonToMap(row.extraAttributesJson),
        updatedAt: row.updatedAt,
      );
}
