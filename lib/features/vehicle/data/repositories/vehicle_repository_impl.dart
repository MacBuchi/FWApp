/// vehicle_repository_impl.dart – Drift-backed implementation of VehicleRepository.
library;
import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/domain/repositories/vehicle_repository.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  final VehicleDao _dao;
  VehicleRepositoryImpl(this._dao);

  @override
  Future<List<Vehicle>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<Vehicle>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toEntity).toList());

  @override
  Future<Vehicle?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<int> insert(Vehicle vehicle) => _dao.insertVehicle(
        VehiclesCompanion.insert(
          name: vehicle.name,
          type: vehicle.type,
          licensePlate: Value(vehicle.licensePlate),
          imagePath: Value(vehicle.imagePath),
        ),
      );

  @override
  Future<void> update(Vehicle vehicle) => _dao.updateVehicle(
        VehiclesCompanion(
          id: Value(vehicle.id),
          name: Value(vehicle.name),
          type: Value(vehicle.type),
          licensePlate: Value(vehicle.licensePlate),
          imagePath: Value(vehicle.imagePath),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(int id) => _dao.deleteVehicle(id);

  @override
  Future<int> count() => _dao.count();

  Vehicle _toEntity(VehicleData row) => Vehicle(
        id: row.id,
        name: row.name,
        type: row.type,
        licensePlate: row.licensePlate,
        imagePath: row.imagePath,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}
