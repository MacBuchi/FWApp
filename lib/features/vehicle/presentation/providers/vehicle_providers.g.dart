// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vehicleRepository)
final vehicleRepositoryProvider = VehicleRepositoryProvider._();

final class VehicleRepositoryProvider
    extends
        $FunctionalProvider<
          VehicleRepository,
          VehicleRepository,
          VehicleRepository
        >
    with $Provider<VehicleRepository> {
  VehicleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleRepositoryHash();

  @$internal
  @override
  $ProviderElement<VehicleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VehicleRepository create(Ref ref) {
    return vehicleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VehicleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VehicleRepository>(value),
    );
  }
}

String _$vehicleRepositoryHash() => r'2a35ff87fb0f92ed13ea1c975d8c4161789fe738';

@ProviderFor(vehicleList)
final vehicleListProvider = VehicleListProvider._();

final class VehicleListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Vehicle>>,
          List<Vehicle>,
          FutureOr<List<Vehicle>>
        >
    with $FutureModifier<List<Vehicle>>, $FutureProvider<List<Vehicle>> {
  VehicleListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleListHash();

  @$internal
  @override
  $FutureProviderElement<List<Vehicle>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Vehicle>> create(Ref ref) {
    return vehicleList(ref);
  }
}

String _$vehicleListHash() => r'f3750b2ea9175e271ae224d898f32218ce147491';

@ProviderFor(vehicleListStream)
final vehicleListStreamProvider = VehicleListStreamProvider._();

final class VehicleListStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Vehicle>>,
          List<Vehicle>,
          Stream<List<Vehicle>>
        >
    with $FutureModifier<List<Vehicle>>, $StreamProvider<List<Vehicle>> {
  VehicleListStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleListStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleListStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<Vehicle>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Vehicle>> create(Ref ref) {
    return vehicleListStream(ref);
  }
}

String _$vehicleListStreamHash() => r'ff25a76f8837395c86c7dde1b5d6f57978c47ae9';

@ProviderFor(vehicleDetail)
final vehicleDetailProvider = VehicleDetailFamily._();

final class VehicleDetailProvider
    extends
        $FunctionalProvider<AsyncValue<Vehicle?>, Vehicle?, FutureOr<Vehicle?>>
    with $FutureModifier<Vehicle?>, $FutureProvider<Vehicle?> {
  VehicleDetailProvider._({
    required VehicleDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'vehicleDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vehicleDetailHash();

  @override
  String toString() {
    return r'vehicleDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Vehicle?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Vehicle?> create(Ref ref) {
    final argument = this.argument as int;
    return vehicleDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vehicleDetailHash() => r'58db0b62372aaa6ed879e2cc2d844708df094a56';

final class VehicleDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Vehicle?>, int> {
  VehicleDetailFamily._()
    : super(
        retry: null,
        name: r'vehicleDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VehicleDetailProvider call(int id) =>
      VehicleDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'vehicleDetailProvider';
}

@ProviderFor(vehicleCount)
final vehicleCountProvider = VehicleCountProvider._();

final class VehicleCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  VehicleCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return vehicleCount(ref);
  }
}

String _$vehicleCountHash() => r'91db4e8ddd2a5a02c08dfbcf1e7380e562a9d3d8';

@ProviderFor(VehicleFormNotifier)
final vehicleFormProvider = VehicleFormNotifierProvider._();

final class VehicleFormNotifierProvider
    extends $NotifierProvider<VehicleFormNotifier, VehicleFormState> {
  VehicleFormNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleFormProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleFormNotifierHash();

  @$internal
  @override
  VehicleFormNotifier create() => VehicleFormNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VehicleFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VehicleFormState>(value),
    );
  }
}

String _$vehicleFormNotifierHash() =>
    r'8d897257a48e2a7d62038248cd9e6cb2a78c895b';

abstract class _$VehicleFormNotifier extends $Notifier<VehicleFormState> {
  VehicleFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<VehicleFormState, VehicleFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VehicleFormState, VehicleFormState>,
              VehicleFormState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
