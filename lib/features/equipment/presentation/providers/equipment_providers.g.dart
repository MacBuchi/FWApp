// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(equipmentRepository)
final equipmentRepositoryProvider = EquipmentRepositoryProvider._();

final class EquipmentRepositoryProvider
    extends
        $FunctionalProvider<
          EquipmentRepository,
          EquipmentRepository,
          EquipmentRepository
        >
    with $Provider<EquipmentRepository> {
  EquipmentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'equipmentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$equipmentRepositoryHash();

  @$internal
  @override
  $ProviderElement<EquipmentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EquipmentRepository create(Ref ref) {
    return equipmentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EquipmentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EquipmentRepository>(value),
    );
  }
}

String _$equipmentRepositoryHash() =>
    r'cd2eaf1edfc20ba257dc050b60a987ee40f01dc5';

@ProviderFor(equipmentListStream)
final equipmentListStreamProvider = EquipmentListStreamProvider._();

final class EquipmentListStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EquipmentItem>>,
          List<EquipmentItem>,
          Stream<List<EquipmentItem>>
        >
    with
        $FutureModifier<List<EquipmentItem>>,
        $StreamProvider<List<EquipmentItem>> {
  EquipmentListStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'equipmentListStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$equipmentListStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<EquipmentItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<EquipmentItem>> create(Ref ref) {
    return equipmentListStream(ref);
  }
}

String _$equipmentListStreamHash() =>
    r'001ea7a4899f230de3b05e9e2f9f7aade31d8d6e';

@ProviderFor(equipmentList)
final equipmentListProvider = EquipmentListProvider._();

final class EquipmentListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EquipmentItem>>,
          List<EquipmentItem>,
          FutureOr<List<EquipmentItem>>
        >
    with
        $FutureModifier<List<EquipmentItem>>,
        $FutureProvider<List<EquipmentItem>> {
  EquipmentListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'equipmentListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$equipmentListHash();

  @$internal
  @override
  $FutureProviderElement<List<EquipmentItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EquipmentItem>> create(Ref ref) {
    return equipmentList(ref);
  }
}

String _$equipmentListHash() => r'04ae4b45e5202df927d01ebb0a5d4d5d51993eb7';

@ProviderFor(equipmentDetail)
final equipmentDetailProvider = EquipmentDetailFamily._();

final class EquipmentDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<EquipmentItem?>,
          EquipmentItem?,
          FutureOr<EquipmentItem?>
        >
    with $FutureModifier<EquipmentItem?>, $FutureProvider<EquipmentItem?> {
  EquipmentDetailProvider._({
    required EquipmentDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'equipmentDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$equipmentDetailHash();

  @override
  String toString() {
    return r'equipmentDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EquipmentItem?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EquipmentItem?> create(Ref ref) {
    final argument = this.argument as int;
    return equipmentDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EquipmentDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$equipmentDetailHash() => r'c012f112fe272b935010c45920b129b27595241d';

final class EquipmentDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EquipmentItem?>, int> {
  EquipmentDetailFamily._()
    : super(
        retry: null,
        name: r'equipmentDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EquipmentDetailProvider call(int id) =>
      EquipmentDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'equipmentDetailProvider';
}

@ProviderFor(equipmentCount)
final equipmentCountProvider = EquipmentCountProvider._();

final class EquipmentCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  EquipmentCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'equipmentCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$equipmentCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return equipmentCount(ref);
  }
}

String _$equipmentCountHash() => r'dd71a8e0aba7b3566c6efcf3c80a0a0945908221';

@ProviderFor(equipmentSearch)
final equipmentSearchProvider = EquipmentSearchFamily._();

final class EquipmentSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EquipmentItem>>,
          List<EquipmentItem>,
          FutureOr<List<EquipmentItem>>
        >
    with
        $FutureModifier<List<EquipmentItem>>,
        $FutureProvider<List<EquipmentItem>> {
  EquipmentSearchProvider._({
    required EquipmentSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'equipmentSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$equipmentSearchHash();

  @override
  String toString() {
    return r'equipmentSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<EquipmentItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EquipmentItem>> create(Ref ref) {
    final argument = this.argument as String;
    return equipmentSearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EquipmentSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$equipmentSearchHash() => r'31f11bb6ac0abb47a454c9f60260a19b2911a971';

final class EquipmentSearchFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<EquipmentItem>>, String> {
  EquipmentSearchFamily._()
    : super(
        retry: null,
        name: r'equipmentSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EquipmentSearchProvider call(String query) =>
      EquipmentSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'equipmentSearchProvider';
}

@ProviderFor(EquipmentFilterNotifier)
final equipmentFilterProvider = EquipmentFilterNotifierProvider._();

final class EquipmentFilterNotifierProvider
    extends $NotifierProvider<EquipmentFilterNotifier, EquipmentFilter> {
  EquipmentFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'equipmentFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$equipmentFilterNotifierHash();

  @$internal
  @override
  EquipmentFilterNotifier create() => EquipmentFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EquipmentFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EquipmentFilter>(value),
    );
  }
}

String _$equipmentFilterNotifierHash() =>
    r'41af3641def84c20f8f04415fb4eed7f8731bde0';

abstract class _$EquipmentFilterNotifier extends $Notifier<EquipmentFilter> {
  EquipmentFilter build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<EquipmentFilter, EquipmentFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EquipmentFilter, EquipmentFilter>,
              EquipmentFilter,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(filteredEquipment)
final filteredEquipmentProvider = FilteredEquipmentProvider._();

final class FilteredEquipmentProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EquipmentItem>>,
          List<EquipmentItem>,
          FutureOr<List<EquipmentItem>>
        >
    with
        $FutureModifier<List<EquipmentItem>>,
        $FutureProvider<List<EquipmentItem>> {
  FilteredEquipmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredEquipmentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredEquipmentHash();

  @$internal
  @override
  $FutureProviderElement<List<EquipmentItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EquipmentItem>> create(Ref ref) {
    return filteredEquipment(ref);
  }
}

String _$filteredEquipmentHash() => r'ae9eeed341a7db0dd9841da0fba3d08c29f0f4e2';
