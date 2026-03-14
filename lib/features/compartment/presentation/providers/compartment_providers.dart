/// compartment_providers.dart – Riverpod providers for compartment feature.
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/compartment/data/repositories/compartment_repository_impl.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/domain/repositories/compartment_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'compartment_providers.g.dart';

@Riverpod(keepAlive: true)
CompartmentRepository compartmentRepository(Ref ref) =>
    CompartmentRepositoryImpl(ref.watch(compartmentDaoProvider));

@riverpod
Stream<List<Compartment>> compartmentListStream(
        Ref ref, int vehicleId) =>
    ref.watch(compartmentRepositoryProvider).watchByVehicle(vehicleId);

@riverpod
Future<List<Compartment>> compartmentList(
        Ref ref, int vehicleId) =>
    ref.watch(compartmentRepositoryProvider).getByVehicle(vehicleId);
