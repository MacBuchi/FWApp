/// equipment_list_screen.dart – Filterable, searchable equipment database.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';

class EquipmentListScreen extends ConsumerStatefulWidget {
  const EquipmentListScreen({super.key});

  @override
  ConsumerState<EquipmentListScreen> createState() =>
      _EquipmentListScreenState();
}

class _EquipmentListScreenState extends ConsumerState<EquipmentListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(equipmentFilterProvider);
    final filteredAsync = ref.watch(filteredEquipmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geräte'),
        actions: [
          if (filter.hasFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Filter zurücksetzen',
              onPressed: () {
                ref
                    .read(equipmentFilterProvider.notifier)
                    .clear();
                _searchCtrl.clear();
              },
            ),
          if (ref.watch(isAdminProvider))
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Gerät hinzufügen',
              onPressed: () => context.push('/equipment/new'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Gerät suchen...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filter.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(equipmentFilterProvider.notifier)
                              .setSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: ref
                  .read(equipmentFilterProvider.notifier)
                  .setSearch,
            ),
          ),
          // Filter chips row
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // Function filter
                _FilterDropdown(
                  label: filter.functionFilter ?? 'Funktion',
                  isActive: filter.functionFilter != null,
                  items: EquipmentFunction.values
                      .map((e) => DropdownMenuItem(
                            value: e.jsonKey,
                            child: Text(e.label),
                          ))
                      .toList(),
                  onChanged: (v) => ref
                      .read(equipmentFilterProvider.notifier)
                      .setFunction(v),
                  onClear: () => ref
                      .read(equipmentFilterProvider.notifier)
                      .setFunction(null),
                ),
                const SizedBox(width: 8),
                // Scenario filter
                _FilterDropdown(
                  label: filter.scenarioFilter ?? 'Einsatz',
                  isActive: filter.scenarioFilter != null,
                  items: DeploymentScenario.values
                      .map((e) => DropdownMenuItem(
                            value: e.jsonKey,
                            child: Text(e.label),
                          ))
                      .toList(),
                  onChanged: (v) => ref
                      .read(equipmentFilterProvider.notifier)
                      .setScenario(v),
                  onClear: () => ref
                      .read(equipmentFilterProvider.notifier)
                      .setScenario(null),
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: filteredAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Keine Geräte gefunden.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: resolveImage(
                            path: item.imagePath ?? kPlaceholderAsset,
                            width: 48,
                            height: 48,
                          ),
                        ),
                        title: Text(item.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: item.equipmentFunctions.isNotEmpty
                            ? Text(item.equipmentFunctions
                                .map((f) =>
                                    EquipmentFunction.fromJson(f)?.label ??
                                    f)
                                .join(', '))
                            : null,
                        trailing: item.isCustom
                            ? const Chip(
                                label: Text('Benutzerdefiniert',
                                    style: TextStyle(fontSize: 10)),
                                padding: EdgeInsets.zero,
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/equipment/${item.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final bool isActive;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final VoidCallback onClear;

  const _FilterDropdown({
    required this.label,
    required this.isActive,
    required this.items,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Icon(isActive ? Icons.arrow_drop_down : Icons.arrow_drop_down,
              size: 16),
        ],
      ),
      selected: isActive,
      onSelected: (_) async {
        if (isActive) {
          onClear();
        } else {
          final result = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => ListView(
              children: [
                ...items.map((item) => ListTile(
                      title: item.child,
                      onTap: () => Navigator.pop(ctx, item.value),
                    )),
              ],
            ),
          );
          if (result != null) onChanged(result);
        }
      },
    );
  }
}
