/// vehicle_providers.dart – Riverpod providers for the vehicle feature.
library;
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/vehicle/data/repositories/vehicle_repository_impl.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/domain/repositories/vehicle_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vehicle_providers.g.dart';

@Riverpod(keepAlive: true)
VehicleRepository vehicleRepository(Ref ref) =>
    VehicleRepositoryImpl(ref.watch(vehicleDaoProvider));

@riverpod
Future<List<Vehicle>> vehicleList(Ref ref) =>
    ref.watch(vehicleRepositoryProvider).getAll();

@riverpod
Stream<List<Vehicle>> vehicleListStream(Ref ref) =>
    ref.watch(vehicleRepositoryProvider).watchAll();

@riverpod
Future<Vehicle?> vehicleDetail(Ref ref, int id) =>
    ref.watch(vehicleRepositoryProvider).getById(id);

@riverpod
Future<int> vehicleCount(Ref ref) =>
    ref.watch(vehicleRepositoryProvider).count();

// ─── Form Notifier ────────────────────────────────────────────

class VehicleFormState {
  final String name;
  final String type;
  final String licensePlate;
  final String? imagePath;
  final bool isSubmitting;
  final String? error;

  const VehicleFormState({
    this.name = '',
    this.type = '',
    this.licensePlate = '',
    this.imagePath,
    this.isSubmitting = false,
    this.error,
  });

  VehicleFormState copyWith({
    String? name,
    String? type,
    String? licensePlate,
    String? imagePath,
    bool clearImage = false,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) =>
      VehicleFormState(
        name: name ?? this.name,
        type: type ?? this.type,
        licensePlate: licensePlate ?? this.licensePlate,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
      );
}

@riverpod
class VehicleFormNotifier extends _$VehicleFormNotifier {
  @override
  VehicleFormState build() => const VehicleFormState();

  void load(Vehicle v) {
    state = VehicleFormState(
      name: v.name,
      type: v.type,
      licensePlate: v.licensePlate ?? '',
      imagePath: v.imagePath,
    );
  }

  void setName(String v) => state = state.copyWith(name: v);
  void setType(String v) => state = state.copyWith(type: v);
  void setLicensePlate(String v) => state = state.copyWith(licensePlate: v);
  void setImagePath(String? v) =>
      state = state.copyWith(imagePath: v, clearImage: v == null);

  Future<bool> submit({int? editId}) async {
    if (state.name.trim().isEmpty || state.type.trim().isEmpty) {
      state = state.copyWith(error: 'Name und Typ sind Pflichtfelder.');
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(vehicleRepositoryProvider);
      if (editId == null) {
        await repo.insert(Vehicle(
          id: 0,
          name: state.name.trim(),
          type: state.type.trim(),
          licensePlate:
              state.licensePlate.trim().isEmpty ? null : state.licensePlate.trim(),
          imagePath: state.imagePath,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      } else {
        final existing = await repo.getById(editId);
        if (existing == null) return false;
        await repo.update(existing.copyWith(
          name: state.name.trim(),
          type: state.type.trim(),
          licensePlate:
              state.licensePlate.trim().isEmpty ? null : state.licensePlate.trim(),
          imagePath: state.imagePath,
        ));
      }
      ref.invalidate(vehicleListProvider);
      ref.invalidate(vehicleListStreamProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
          isSubmitting: false, error: 'Fehler beim Speichern: $e');
      return false;
    }
  }
}
