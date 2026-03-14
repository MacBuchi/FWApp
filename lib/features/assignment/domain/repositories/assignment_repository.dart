/// assignment_repository.dart – Abstract interface for equipment-assignment data access.
import 'package:fwapp/features/assignment/domain/entities/equipment_assignment.dart';

abstract class AssignmentRepository {
  Future<List<EquipmentAssignment>> getByCompartment(int compartmentId);
  Stream<List<EquipmentAssignment>> watchByCompartment(int compartmentId);
  Future<List<EquipmentAssignment>> getByVehicle(int vehicleId);
  Future<int> insert(EquipmentAssignment assignment);
  Future<void> update(EquipmentAssignment assignment);
  Future<void> delete(int id);
}
