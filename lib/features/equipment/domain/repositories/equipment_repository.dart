/// equipment_repository.dart – Abstract interface for equipment data access.
library;
import 'package:fwapp/features/equipment/domain/entities/equipment_item.dart';

abstract class EquipmentRepository {
  Future<List<EquipmentItem>> getAll();
  Stream<List<EquipmentItem>> watchAll();
  Future<EquipmentItem?> getById(int id);
  Future<EquipmentItem?> getByLibraryId(String libraryId);
  Future<int> insert(EquipmentItem item);
  Future<void> update(EquipmentItem item);
  Future<void> delete(int id);
  Future<int> count();
  Future<List<EquipmentItem>> search(String query);
}
