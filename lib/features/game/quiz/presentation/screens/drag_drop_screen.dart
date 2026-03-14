/// drag_drop_screen.dart – Drag equipment cards into the correct compartment zone.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class DragDropScreen extends ConsumerStatefulWidget {
  const DragDropScreen({super.key});

  @override
  ConsumerState<DragDropScreen> createState() => _DragDropScreenState();
}

class _DragDropScreenState extends ConsumerState<DragDropScreen> {
  Vehicle? _selectedVehicle;
  bool _started = false;

  List<_DragItem> _remaining = [];
  List<_CompartmentZone> _zones = [];
  int _score = 0;
  int _total = 0;
  final Map<int, bool> _zoneHighlight = {};

  @override
  Widget build(BuildContext context) {
    if (!_started) return _buildSetup();
    if (_remaining.isEmpty && _total > 0) return _buildResults();
    return _buildGame();
  }

  Widget _buildSetup() {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Drag & Drop')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Wähle ein Fahrzeug:',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            vehiclesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Fehler: $e'),
              data: (vehicles) => DropdownButtonFormField<Vehicle>(
                value: _selectedVehicle,
                decoration: const InputDecoration(labelText: 'Fahrzeug'),
                items: vehicles
                    .map((v) => DropdownMenuItem(
                        value: v, child: Text(v.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVehicle = v),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Spiel starten'),
              onPressed:
                  _selectedVehicle == null ? null : () => _startGame(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGame() async {
    if (_selectedVehicle == null) return;
    final db = ref.read(appDatabaseProvider);
    final compartments =
        await db.compartmentDao.getByVehicle(_selectedVehicle!.id);
    final items = <_DragItem>[];
    final zones = <_CompartmentZone>[];

    for (final c in compartments) {
      zones.add(_CompartmentZone(id: c.id, label: c.label));
      final assignments = await db.assignmentDao.getByCompartment(c.id);
      for (final a in assignments) {
        final eq = await db.equipmentDao.getById(a.equipmentId);
        if (eq == null) continue;
        items.add(_DragItem(
          equipmentId: eq.id,
          equipmentName: eq.name,
          imagePath: eq.imagePath,
          correctCompartmentId: c.id,
        ));
      }
    }
    items.shuffle();

    if (items.isEmpty || zones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Keine Daten vorhanden.')));
      }
      return;
    }

    setState(() {
      _remaining = items.take(15).toList();
      _zones = zones;
      _score = 0;
      _total = _remaining.length;
      _started = true;
    });
  }

  Widget _buildGame() {
    if (_remaining.isEmpty) return _buildResults();
    final current = _remaining.first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Drag & Drop  $_score / $_total'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
              value: 1 - _remaining.length / _total),
        ),
      ),
      body: Column(
        children: [
          // Current equipment card to drag
          Padding(
            padding: const EdgeInsets.all(16),
            child: const Text('Ziehe das Gerät in das richtige Fach:',
                style: TextStyle(fontSize: 15)),
          ),
          Draggable<_DragItem>(
            data: current,
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 130,
                child: _EquipmentCard(item: current, isDragging: true),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: SizedBox(
                  width: 130, child: _EquipmentCard(item: current)),
            ),
            child: SizedBox(
                width: 130, child: _EquipmentCard(item: current)),
          ),
          const SizedBox(height: 12),
          // Compartment zones grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: _zones.length,
              itemBuilder: (context, i) {
                final zone = _zones[i];
                return DragTarget<_DragItem>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (details) =>
                      _onDrop(details.data, zone),
                  builder: (ctx, candidates, rejected) {
                    final isHighlighted = candidates.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isHighlighted
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(zone.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
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

  void _onDrop(_DragItem item, _CompartmentZone zone) {
    final correct = item.correctCompartmentId == zone.id;
    if (correct) _score++;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(correct
            ? '✓ Richtig! ${item.equipmentName} → ${zone.label}'
            : '✗ Falsch! ${item.equipmentName} gehört nicht in ${zone.label}'),
        backgroundColor: correct ? Colors.green : Colors.red,
        duration: const Duration(milliseconds: 1500),
      ),
    );

    setState(() => _remaining.removeAt(0));
  }

  Widget _buildResults() {
    final pct =
        _total > 0 ? (_score / _total * 100).round() : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Ergebnis')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: pct >= 80
                  ? Colors.green
                  : pct >= 50
                      ? Colors.orange
                      : Colors.red,
              child: Text('$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text('$_score von $_total richtig',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Nochmal'),
              onPressed: () => setState(() {
                _started = false;
                _remaining = [];
                _total = 0;
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final _DragItem item;
  final bool isDragging;

  const _EquipmentCard({required this.item, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isDragging ? 0 : 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            resolveImage(
              path: item.imagePath ?? kPlaceholderAsset,
              width: 64,
              height: 64,
            ),
            const SizedBox(height: 4),
            Text(item.equipmentName,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _DragItem {
  final int equipmentId;
  final String equipmentName;
  final String? imagePath;
  final int correctCompartmentId;

  const _DragItem({
    required this.equipmentId,
    required this.equipmentName,
    this.imagePath,
    required this.correctCompartmentId,
  });
}

class _CompartmentZone {
  final int id;
  final String label;
  const _CompartmentZone({required this.id, required this.label});
}
