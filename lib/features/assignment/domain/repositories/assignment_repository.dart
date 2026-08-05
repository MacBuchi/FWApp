/// assignment_repository.dart – Abstract interface for equipment-assignment data access.
library;
import 'package:fwapp/features/assignment/domain/entities/equipment_assignment.dart';

abstract class AssignmentRepository {
  Future<List<EquipmentAssignment>> getByCompartment(int compartmentId);
  Stream<List<EquipmentAssignment>> watchByCompartment(int compartmentId);
  Future<List<EquipmentAssignment>> getByVehicle(int vehicleId);
  Future<int> insert(EquipmentAssignment assignment);
  Future<void> update(EquipmentAssignment assignment);
  Future<void> delete(int id);

  /// Legt mehrere Zuweisungen auf einmal an und liefert die Zahl der wirklich
  /// geschriebenen (Issue #149). Schon Zugewiesenes wird übersprungen.
  Future<int> assignMany(int compartmentId, List<int> equipmentIds);

  /// Verschiebt Zuweisungen in ein anderes Fach; ein dort schon liegendes
  /// Gerät wird zusammengeführt (Mengen addiert).
  Future<int> moveMany(List<int> assignmentIds, int zielCompartmentId);

  Future<void> deleteMany(List<int> assignmentIds);
}
