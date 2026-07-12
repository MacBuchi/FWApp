/// drag_drop_screen.dart – Drag equipment cards onto the correct compartment
/// in the vehicle cutaway (Schnittdarstellung).
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

class DragDropScreen extends ConsumerStatefulWidget {
  const DragDropScreen({super.key});

  @override
  ConsumerState<DragDropScreen> createState() => _DragDropScreenState();
}

class _DragDropScreenState extends ConsumerState<DragDropScreen> {
  Vehicle? _selectedVehicle;
  bool _started = false;

  List<_DragItem> _remaining = [];
  List<Compartment> _compartments = [];
  int _score = 0;
  int _total = 0;

  /// Brief correct/wrong flash on the tile that received a drop.
  final Map<int, CutawayTileStatus> _flash = {};

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
                initialValue: _selectedVehicle,
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
    final compartmentRows =
        await db.compartmentDao.getByVehicle(_selectedVehicle!.id);
    final items = <_DragItem>[];
    final zones = compartmentRows
        .map((c) => Compartment(
              id: c.id,
              vehicleId: c.vehicleId,
              label: c.label,
              position: c.position,
              gridRow: c.gridRow,
              gridCol: c.gridCol,
              gridColSpan: c.gridColSpan,
              updatedAt: c.updatedAt,
            ))
        .toList();

    for (final c in compartmentRows) {
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
      _compartments = zones;
      _flash.clear();
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
          // Cutaway as drop surface
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: VehicleCutawayView(
                compartments: _compartments,
                tileStates: {
                  for (final e in _flash.entries)
                    e.key: CutawayTileState(status: e.value),
                },
                tileWrapperBuilder: (compartment, tile) =>
                    DragTarget<_DragItem>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (details) =>
                      _onDrop(details.data, compartment),
                  builder: (ctx, candidates, rejected) => AnimatedScale(
                    scale: candidates.isNotEmpty ? 1.05 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: tile,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDrop(_DragItem item, Compartment compartment) {
    if (_flash.isNotEmpty) return; // ignore drops during the feedback flash
    final correct = item.correctCompartmentId == compartment.id;
    if (correct) _score++;

    setState(() {
      _flash[compartment.id] =
          correct ? CutawayTileStatus.correct : CutawayTileStatus.wrong;
      if (!correct) {
        // Also show where it belongs.
        _flash[item.correctCompartmentId] = CutawayTileStatus.correct;
      }
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _flash.clear();
        _remaining.removeAt(0);
        if (_remaining.isEmpty) _saveResult();
      });
    });
  }

  Future<void> _saveResult() async {
    final db = ref.read(appDatabaseProvider);
    await db.quizDao.insertResult(QuizResultsCompanion.insert(
      quizType: 'dragdrop',
      score: _score,
      total: _total,
      vehicleId: Value(_selectedVehicle?.id),
    ));
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

