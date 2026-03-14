/// compartment_repository_impl.dart – Drift-backed CompartmentRepository implementation.
import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/domain/repositories/compartment_repository.dart';

class CompartmentRepositoryImpl implements CompartmentRepository {
  final CompartmentDao _dao;
  CompartmentRepositoryImpl(this._dao);

  @override
  Future<List<Compartment>> getByVehicle(int vehicleId) async {
    final rows = await _dao.getByVehicle(vehicleId);
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<Compartment>> watchByVehicle(int vehicleId) =>
      _dao.watchByVehicle(vehicleId).map((rows) => rows.map(_toEntity).toList());

  @override
  Future<Compartment?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<int> insert(Compartment c) => _dao.insertCompartment(
        CompartmentsCompanion.insert(
          vehicleId: c.vehicleId,
          label: c.label,
          position: Value(c.position),
          gridRow: Value(c.gridRow),
          gridCol: Value(c.gridCol),
          gridColSpan: Value(c.gridColSpan),
        ),
      );

  @override
  Future<void> update(Compartment c) => _dao.updateCompartment(
        CompartmentsCompanion(
          id: Value(c.id),
          vehicleId: Value(c.vehicleId),
          label: Value(c.label),
          position: Value(c.position),
          gridRow: Value(c.gridRow),
          gridCol: Value(c.gridCol),
          gridColSpan: Value(c.gridColSpan),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(int id) => _dao.deleteCompartment(id);

  Compartment _toEntity(CompartmentData row) => Compartment(
        id: row.id,
        vehicleId: row.vehicleId,
        label: row.label,
        position: row.position,
        gridRow: row.gridRow,
        gridCol: row.gridCol,
        gridColSpan: row.gridColSpan,
        updatedAt: row.updatedAt,
      );
}
