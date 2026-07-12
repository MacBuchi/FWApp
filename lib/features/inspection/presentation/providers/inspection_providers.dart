/// inspection_providers.dart – Riverpod providers for the inspection feature.
library;
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/inspection/data/repositories/inspection_repository_impl.dart';
import 'package:fwapp/features/inspection/domain/entities/due_inspection_entry.dart';
import 'package:fwapp/features/inspection/domain/entities/equipment_instance.dart';
import 'package:fwapp/features/inspection/domain/entities/inspection_schedule.dart';
import 'package:fwapp/features/inspection/domain/repositories/inspection_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inspection_providers.g.dart';

@Riverpod(keepAlive: true)
InspectionRepository inspectionRepository(Ref ref) =>
    InspectionRepositoryImpl(ref.watch(inspectionDaoProvider));

/// Everything overdue or due within [withinDays], ordered by due date.
@riverpod
Stream<List<DueInspectionEntry>> dueInspectionsStream(Ref ref,
        {int withinDays = 30}) =>
    ref.watch(inspectionRepositoryProvider).watchDueSoon(withinDays: withinDays);

/// Per-vehicle (overdue, dueSoon) counts for list badges.
@riverpod
Stream<Map<int, DueCounts>> vehicleDueCountsStream(Ref ref) =>
    ref.watch(inspectionRepositoryProvider).watchDueCountsByVehicle();

/// Instances of one equipment type (for EquipmentDetailScreen).
@riverpod
Stream<List<EquipmentInstance>> instancesByEquipmentStream(
        Ref ref, int equipmentId) =>
    ref
        .watch(inspectionRepositoryProvider)
        .watchInstancesByEquipment(equipmentId);

/// Schedules of one instance.
@riverpod
Stream<List<InspectionSchedule>> schedulesByInstanceStream(
        Ref ref, int instanceId) =>
    ref
        .watch(inspectionRepositoryProvider)
        .watchSchedulesByInstance(instanceId);
