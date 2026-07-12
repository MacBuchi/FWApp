/// compartment_repository.dart – Abstract interface for compartment data access.
library;
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';

abstract class CompartmentRepository {
  Future<List<Compartment>> getByVehicle(int vehicleId);
  Stream<List<Compartment>> watchByVehicle(int vehicleId);
  Future<Compartment?> getById(int id);
  Future<int> insert(Compartment compartment);
  Future<void> update(Compartment compartment);
  Future<void> delete(int id);
}
