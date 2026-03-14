// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compartment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(compartmentRepository)
final compartmentRepositoryProvider = CompartmentRepositoryProvider._();

final class CompartmentRepositoryProvider
    extends
        $FunctionalProvider<
          CompartmentRepository,
          CompartmentRepository,
          CompartmentRepository
        >
    with $Provider<CompartmentRepository> {
  CompartmentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'compartmentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$compartmentRepositoryHash();

  @$internal
  @override
  $ProviderElement<CompartmentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompartmentRepository create(Ref ref) {
    return compartmentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompartmentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompartmentRepository>(value),
    );
  }
}

String _$compartmentRepositoryHash() =>
    r'06ada8bf7151d38ba544ee3a95b3bed22dbd3a20';

@ProviderFor(compartmentListStream)
final compartmentListStreamProvider = CompartmentListStreamFamily._();

final class CompartmentListStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Compartment>>,
          List<Compartment>,
          Stream<List<Compartment>>
        >
    with
        $FutureModifier<List<Compartment>>,
        $StreamProvider<List<Compartment>> {
  CompartmentListStreamProvider._({
    required CompartmentListStreamFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'compartmentListStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$compartmentListStreamHash();

  @override
  String toString() {
    return r'compartmentListStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Compartment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Compartment>> create(Ref ref) {
    final argument = this.argument as int;
    return compartmentListStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CompartmentListStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$compartmentListStreamHash() =>
    r'da98c634c2300d3820a767218a35dc7d0830e83f';

final class CompartmentListStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Compartment>>, int> {
  CompartmentListStreamFamily._()
    : super(
        retry: null,
        name: r'compartmentListStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CompartmentListStreamProvider call(int vehicleId) =>
      CompartmentListStreamProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'compartmentListStreamProvider';
}

@ProviderFor(compartmentList)
final compartmentListProvider = CompartmentListFamily._();

final class CompartmentListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Compartment>>,
          List<Compartment>,
          FutureOr<List<Compartment>>
        >
    with
        $FutureModifier<List<Compartment>>,
        $FutureProvider<List<Compartment>> {
  CompartmentListProvider._({
    required CompartmentListFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'compartmentListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$compartmentListHash();

  @override
  String toString() {
    return r'compartmentListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Compartment>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Compartment>> create(Ref ref) {
    final argument = this.argument as int;
    return compartmentList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CompartmentListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$compartmentListHash() => r'25841509b1fa3a0a9c4bc08d66acf32d089343fb';

final class CompartmentListFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Compartment>>, int> {
  CompartmentListFamily._()
    : super(
        retry: null,
        name: r'compartmentListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CompartmentListProvider call(int vehicleId) =>
      CompartmentListProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'compartmentListProvider';
}
