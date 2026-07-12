// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(inspectionRepository)
final inspectionRepositoryProvider = InspectionRepositoryProvider._();

final class InspectionRepositoryProvider
    extends
        $FunctionalProvider<
          InspectionRepository,
          InspectionRepository,
          InspectionRepository
        >
    with $Provider<InspectionRepository> {
  InspectionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inspectionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inspectionRepositoryHash();

  @$internal
  @override
  $ProviderElement<InspectionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InspectionRepository create(Ref ref) {
    return inspectionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InspectionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InspectionRepository>(value),
    );
  }
}

String _$inspectionRepositoryHash() =>
    r'ae51016ea6522102b16cdfa7fc52170d7006ec28';

/// Everything overdue or due within [withinDays], ordered by due date.

@ProviderFor(dueInspectionsStream)
final dueInspectionsStreamProvider = DueInspectionsStreamFamily._();

/// Everything overdue or due within [withinDays], ordered by due date.

final class DueInspectionsStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DueInspectionEntry>>,
          List<DueInspectionEntry>,
          Stream<List<DueInspectionEntry>>
        >
    with
        $FutureModifier<List<DueInspectionEntry>>,
        $StreamProvider<List<DueInspectionEntry>> {
  /// Everything overdue or due within [withinDays], ordered by due date.
  DueInspectionsStreamProvider._({
    required DueInspectionsStreamFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'dueInspectionsStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dueInspectionsStreamHash();

  @override
  String toString() {
    return r'dueInspectionsStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<DueInspectionEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DueInspectionEntry>> create(Ref ref) {
    final argument = this.argument as int;
    return dueInspectionsStream(ref, withinDays: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DueInspectionsStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dueInspectionsStreamHash() =>
    r'2c1ce3f04abe956b50ac9e2b6496622f91a95f60';

/// Everything overdue or due within [withinDays], ordered by due date.

final class DueInspectionsStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<DueInspectionEntry>>, int> {
  DueInspectionsStreamFamily._()
    : super(
        retry: null,
        name: r'dueInspectionsStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Everything overdue or due within [withinDays], ordered by due date.

  DueInspectionsStreamProvider call({int withinDays = 30}) =>
      DueInspectionsStreamProvider._(argument: withinDays, from: this);

  @override
  String toString() => r'dueInspectionsStreamProvider';
}

/// Per-vehicle (overdue, dueSoon) counts for list badges.

@ProviderFor(vehicleDueCountsStream)
final vehicleDueCountsStreamProvider = VehicleDueCountsStreamProvider._();

/// Per-vehicle (overdue, dueSoon) counts for list badges.

final class VehicleDueCountsStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, DueCounts>>,
          Map<int, DueCounts>,
          Stream<Map<int, DueCounts>>
        >
    with
        $FutureModifier<Map<int, DueCounts>>,
        $StreamProvider<Map<int, DueCounts>> {
  /// Per-vehicle (overdue, dueSoon) counts for list badges.
  VehicleDueCountsStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleDueCountsStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleDueCountsStreamHash();

  @$internal
  @override
  $StreamProviderElement<Map<int, DueCounts>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<int, DueCounts>> create(Ref ref) {
    return vehicleDueCountsStream(ref);
  }
}

String _$vehicleDueCountsStreamHash() =>
    r'6e9b2bbf8543c02037f15679fe6bbb99bf20acc1';

/// Instances of one equipment type (for EquipmentDetailScreen).

@ProviderFor(instancesByEquipmentStream)
final instancesByEquipmentStreamProvider = InstancesByEquipmentStreamFamily._();

/// Instances of one equipment type (for EquipmentDetailScreen).

final class InstancesByEquipmentStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EquipmentInstance>>,
          List<EquipmentInstance>,
          Stream<List<EquipmentInstance>>
        >
    with
        $FutureModifier<List<EquipmentInstance>>,
        $StreamProvider<List<EquipmentInstance>> {
  /// Instances of one equipment type (for EquipmentDetailScreen).
  InstancesByEquipmentStreamProvider._({
    required InstancesByEquipmentStreamFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'instancesByEquipmentStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$instancesByEquipmentStreamHash();

  @override
  String toString() {
    return r'instancesByEquipmentStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<EquipmentInstance>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<EquipmentInstance>> create(Ref ref) {
    final argument = this.argument as int;
    return instancesByEquipmentStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InstancesByEquipmentStreamProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$instancesByEquipmentStreamHash() =>
    r'626975e825dd4ed72fec2944b434b3019522e0cc';

/// Instances of one equipment type (for EquipmentDetailScreen).

final class InstancesByEquipmentStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<EquipmentInstance>>, int> {
  InstancesByEquipmentStreamFamily._()
    : super(
        retry: null,
        name: r'instancesByEquipmentStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Instances of one equipment type (for EquipmentDetailScreen).

  InstancesByEquipmentStreamProvider call(int equipmentId) =>
      InstancesByEquipmentStreamProvider._(argument: equipmentId, from: this);

  @override
  String toString() => r'instancesByEquipmentStreamProvider';
}

/// Schedules of one instance.

@ProviderFor(schedulesByInstanceStream)
final schedulesByInstanceStreamProvider = SchedulesByInstanceStreamFamily._();

/// Schedules of one instance.

final class SchedulesByInstanceStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InspectionSchedule>>,
          List<InspectionSchedule>,
          Stream<List<InspectionSchedule>>
        >
    with
        $FutureModifier<List<InspectionSchedule>>,
        $StreamProvider<List<InspectionSchedule>> {
  /// Schedules of one instance.
  SchedulesByInstanceStreamProvider._({
    required SchedulesByInstanceStreamFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'schedulesByInstanceStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$schedulesByInstanceStreamHash();

  @override
  String toString() {
    return r'schedulesByInstanceStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<InspectionSchedule>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<InspectionSchedule>> create(Ref ref) {
    final argument = this.argument as int;
    return schedulesByInstanceStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SchedulesByInstanceStreamProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$schedulesByInstanceStreamHash() =>
    r'4de30d475c07841413f281018978ade8466b48cc';

/// Schedules of one instance.

final class SchedulesByInstanceStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<InspectionSchedule>>, int> {
  SchedulesByInstanceStreamFamily._()
    : super(
        retry: null,
        name: r'schedulesByInstanceStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Schedules of one instance.

  SchedulesByInstanceStreamProvider call(int instanceId) =>
      SchedulesByInstanceStreamProvider._(argument: instanceId, from: this);

  @override
  String toString() => r'schedulesByInstanceStreamProvider';
}
