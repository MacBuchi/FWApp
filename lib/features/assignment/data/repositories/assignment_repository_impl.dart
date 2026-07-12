/// assignment_repository_impl.dart – Drift-backed AssignmentRepository implementation.
library;
import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/assignment/domain/entities/equipment_assignment.dart';
import 'package:fwapp/features/assignment/domain/repositories/assignment_repository.dart';

class AssignmentRepositoryImpl implements AssignmentRepository {
  final AssignmentDao _dao;
  AssignmentRepositoryImpl(this._dao);

  @override
  Future<List<EquipmentAssignment>> getByCompartment(int compartmentId) async {
    final rows = await _dao.getByCompartment(compartmentId);
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<EquipmentAssignment>> watchByCompartment(int compartmentId) =>
      _dao
          .watchByCompartment(compartmentId)
          .map((rows) => rows.map(_toEntity).toList());

  @override
  Future<List<EquipmentAssignment>> getByVehicle(int vehicleId) async {
    final rows = await _dao.getByVehicle(vehicleId);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<int> insert(EquipmentAssignment a) => _dao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
          compartmentId: a.compartmentId,
          equipmentId: a.equipmentId,
          quantity: Value(a.quantity),
        ),
      );

  @override
  Future<void> update(EquipmentAssignment a) => _dao.updateAssignment(
        EquipmentAssignmentsCompanion(
          id: Value(a.id),
          compartmentId: Value(a.compartmentId),
          equipmentId: Value(a.equipmentId),
          quantity: Value(a.quantity),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(int id) => _dao.deleteAssignment(id);

  EquipmentAssignment _toEntity(AssignmentData row) => EquipmentAssignment(
        id: row.id,
        compartmentId: row.compartmentId,
        equipmentId: row.equipmentId,
        quantity: row.quantity,
        updatedAt: row.updatedAt,
      );
}
