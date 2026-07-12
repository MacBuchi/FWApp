/// assignment_providers.dart – Riverpod providers for assignment feature.
library;
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/assignment/data/repositories/assignment_repository_impl.dart';
import 'package:fwapp/features/assignment/domain/entities/equipment_assignment.dart';
import 'package:fwapp/features/assignment/domain/repositories/assignment_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assignment_providers.g.dart';

@Riverpod(keepAlive: true)
AssignmentRepository assignmentRepository(Ref ref) =>
    AssignmentRepositoryImpl(ref.watch(assignmentDaoProvider));

@riverpod
Stream<List<EquipmentAssignment>> assignmentListStream(
        Ref ref, int compartmentId) =>
    ref.watch(assignmentRepositoryProvider).watchByCompartment(compartmentId);

@riverpod
Future<List<EquipmentAssignment>> assignmentsByVehicle(
        Ref ref, int vehicleId) =>
    ref.watch(assignmentRepositoryProvider).getByVehicle(vehicleId);
