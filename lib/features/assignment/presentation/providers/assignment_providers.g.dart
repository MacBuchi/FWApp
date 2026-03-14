// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assignment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(assignmentRepository)
final assignmentRepositoryProvider = AssignmentRepositoryProvider._();

final class AssignmentRepositoryProvider
    extends
        $FunctionalProvider<
          AssignmentRepository,
          AssignmentRepository,
          AssignmentRepository
        >
    with $Provider<AssignmentRepository> {
  AssignmentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assignmentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assignmentRepositoryHash();

  @$internal
  @override
  $ProviderElement<AssignmentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AssignmentRepository create(Ref ref) {
    return assignmentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssignmentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssignmentRepository>(value),
    );
  }
}

String _$assignmentRepositoryHash() =>
    r'abfb3e657851080a9d1151f1d53c708b7a8279d3';

@ProviderFor(assignmentListStream)
final assignmentListStreamProvider = AssignmentListStreamFamily._();

final class AssignmentListStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EquipmentAssignment>>,
          List<EquipmentAssignment>,
          Stream<List<EquipmentAssignment>>
        >
    with
        $FutureModifier<List<EquipmentAssignment>>,
        $StreamProvider<List<EquipmentAssignment>> {
  AssignmentListStreamProvider._({
    required AssignmentListStreamFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'assignmentListStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assignmentListStreamHash();

  @override
  String toString() {
    return r'assignmentListStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<EquipmentAssignment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<EquipmentAssignment>> create(Ref ref) {
    final argument = this.argument as int;
    return assignmentListStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AssignmentListStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assignmentListStreamHash() =>
    r'850f43e64ccb8f85c2f3c1a9e1048bee88c1d0f5';

final class AssignmentListStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<EquipmentAssignment>>, int> {
  AssignmentListStreamFamily._()
    : super(
        retry: null,
        name: r'assignmentListStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssignmentListStreamProvider call(int compartmentId) =>
      AssignmentListStreamProvider._(argument: compartmentId, from: this);

  @override
  String toString() => r'assignmentListStreamProvider';
}

@ProviderFor(assignmentsByVehicle)
final assignmentsByVehicleProvider = AssignmentsByVehicleFamily._();

final class AssignmentsByVehicleProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EquipmentAssignment>>,
          List<EquipmentAssignment>,
          FutureOr<List<EquipmentAssignment>>
        >
    with
        $FutureModifier<List<EquipmentAssignment>>,
        $FutureProvider<List<EquipmentAssignment>> {
  AssignmentsByVehicleProvider._({
    required AssignmentsByVehicleFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'assignmentsByVehicleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assignmentsByVehicleHash();

  @override
  String toString() {
    return r'assignmentsByVehicleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<EquipmentAssignment>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EquipmentAssignment>> create(Ref ref) {
    final argument = this.argument as int;
    return assignmentsByVehicle(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AssignmentsByVehicleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assignmentsByVehicleHash() =>
    r'0d298fbb1e8601eb801a987a2bef8203c43e78ac';

final class AssignmentsByVehicleFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<EquipmentAssignment>>, int> {
  AssignmentsByVehicleFamily._()
    : super(
        retry: null,
        name: r'assignmentsByVehicleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssignmentsByVehicleProvider call(int vehicleId) =>
      AssignmentsByVehicleProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'assignmentsByVehicleProvider';
}
