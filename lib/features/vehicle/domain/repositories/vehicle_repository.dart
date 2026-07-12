/// vehicle_repository.dart – Abstract interface for vehicle data access.
library;
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> getAll();
  Stream<List<Vehicle>> watchAll();
  Future<Vehicle?> getById(int id);
  Future<int> insert(Vehicle vehicle);
  Future<void> update(Vehicle vehicle);
  Future<void> delete(int id);
  Future<int> count();
}
