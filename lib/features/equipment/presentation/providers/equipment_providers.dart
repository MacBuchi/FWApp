/// equipment_providers.dart – Riverpod providers for equipment feature.
library;
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_item.dart';
import 'package:fwapp/features/equipment/domain/repositories/equipment_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'equipment_providers.g.dart';

@Riverpod(keepAlive: true)
EquipmentRepository equipmentRepository(Ref ref) =>
    EquipmentRepositoryImpl(ref.watch(equipmentDaoProvider));

@riverpod
Stream<List<EquipmentItem>> equipmentListStream(Ref ref) =>
    ref.watch(equipmentRepositoryProvider).watchAll();

@riverpod
Future<List<EquipmentItem>> equipmentList(Ref ref) =>
    ref.watch(equipmentRepositoryProvider).getAll();

@riverpod
Future<EquipmentItem?> equipmentDetail(Ref ref, int id) =>
    ref.watch(equipmentRepositoryProvider).getById(id);

@riverpod
Future<int> equipmentCount(Ref ref) =>
    ref.watch(equipmentRepositoryProvider).count();

@riverpod
Future<List<EquipmentItem>> equipmentSearch(
        Ref ref, String query) =>
    ref.watch(equipmentRepositoryProvider).search(query);

// ─── Filter State ─────────────────────────────────────────────

class EquipmentFilter {
  final String searchQuery;
  final String? functionFilter;
  final String? scenarioFilter;

  const EquipmentFilter({
    this.searchQuery = '',
    this.functionFilter,
    this.scenarioFilter,
  });

  EquipmentFilter copyWith({
    String? searchQuery,
    String? functionFilter,
    bool clearFunction = false,
    String? scenarioFilter,
    bool clearScenario = false,
  }) =>
      EquipmentFilter(
        searchQuery: searchQuery ?? this.searchQuery,
        functionFilter:
            clearFunction ? null : (functionFilter ?? this.functionFilter),
        scenarioFilter:
            clearScenario ? null : (scenarioFilter ?? this.scenarioFilter),
      );

  bool get hasFilter =>
      searchQuery.isNotEmpty ||
      functionFilter != null ||
      scenarioFilter != null;
}

@riverpod
class EquipmentFilterNotifier extends _$EquipmentFilterNotifier {
  @override
  EquipmentFilter build() => const EquipmentFilter();

  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void setFunction(String? f) =>
      state = state.copyWith(functionFilter: f, clearFunction: f == null);
  void setScenario(String? s) =>
      state = state.copyWith(scenarioFilter: s, clearScenario: s == null);
  void clear() => state = const EquipmentFilter();
}

@riverpod
Future<List<EquipmentItem>> filteredEquipment(
    Ref ref) async {
  final filter = ref.watch(equipmentFilterProvider);
  final all = await ref.watch(equipmentListProvider.future);

  return all.where((item) {
    if (filter.searchQuery.isNotEmpty) {
      final q = filter.searchQuery.toLowerCase();
      if (!item.name.toLowerCase().contains(q) &&
          !item.description.toLowerCase().contains(q)) {
        return false;
      }
    }
    if (filter.functionFilter != null) {
      if (!item.equipmentFunctions.contains(filter.functionFilter)) return false;
    }
    if (filter.scenarioFilter != null) {
      if (!item.deploymentScenarios.contains(filter.scenarioFilter)) {
        return false;
      }
    }
    return true;
  }).toList();
}
