/// cutaway_quiz_screen.dart – "Wo liegt's?": tap the correct compartment on
/// the vehicle cutaway (Schnittdarstellung) for a shown piece of equipment.
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

class CutawayQuizScreen extends ConsumerStatefulWidget {
  const CutawayQuizScreen({super.key});

  @override
  ConsumerState<CutawayQuizScreen> createState() => _CutawayQuizScreenState();
}

class _CutawayQuizScreenState extends ConsumerState<CutawayQuizScreen> {
  Vehicle? _selectedVehicle;
  bool _started = false;

  List<Compartment> _compartments = [];
  List<_CutawayQuestion> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int? _tappedCompartmentId;
  bool _answered = false;

  @override
  Widget build(BuildContext context) {
    if (!_started) return _buildSetup();
    if (_currentIndex >= _questions.length) return _buildResults();
    return _buildQuestion();
  }

  Widget _buildSetup() {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wo liegt\'s?')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Tippe in der Schnittdarstellung auf das Fach, in dem das '
                'gezeigte Gerät verlastet ist.',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            vehiclesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Fehler: $e'),
              data: (vehicles) => DropdownButtonFormField<Vehicle>(
                initialValue: _selectedVehicle,
                decoration: const InputDecoration(labelText: 'Fahrzeug'),
                items: vehicles
                    .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVehicle = v),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Quiz starten'),
              onPressed: _selectedVehicle == null ? null : _startQuiz,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startQuiz() async {
    final db = ref.read(appDatabaseProvider);
    final compartmentRows =
        await db.compartmentDao.getByVehicle(_selectedVehicle!.id);
    if (compartmentRows.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Das Fahrzeug braucht mindestens 2 Fächer für dieses Quiz.')));
      }
      return;
    }
    final compartments = compartmentRows
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

    final questions = <_CutawayQuestion>[];
    for (final c in compartmentRows) {
      final assignments = await db.assignmentDao.getByCompartment(c.id);
      for (final a in assignments) {
        final eq = await db.equipmentDao.getById(a.equipmentId);
        if (eq == null) continue;
        questions.add(_CutawayQuestion(
          equipmentId: eq.id,
          equipmentName: eq.name,
          imagePath: eq.imagePath,
          functions: jsonToStringList(eq.equipmentFunctionsJson),
          correctCompartmentId: c.id,
        ));
      }
    }
    questions.shuffle();
    if (questions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Keine Beladung für dieses Fahrzeug vorhanden.')));
      }
      return;
    }

    setState(() {
      _compartments = compartments;
      _questions = questions.take(15).toList();
      _currentIndex = 0;
      _score = 0;
      _tappedCompartmentId = null;
      _answered = false;
      _started = true;
    });
  }

  Widget _buildQuestion() {
    final q = _questions[_currentIndex];
    final tileStates = <int, CutawayTileState>{};
    if (_answered) {
      tileStates[q.correctCompartmentId] =
          const CutawayTileState(status: CutawayTileStatus.correct);
      if (_tappedCompartmentId != null &&
          _tappedCompartmentId != q.correctCompartmentId) {
        tileStates[_tappedCompartmentId!] =
            const CutawayTileState(status: CutawayTileStatus.wrong);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Wo liegt\'s? ${_currentIndex + 1}/${_questions.length}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LinearProgressIndicator(value: _currentIndex / _questions.length),
          const SizedBox(height: 16),
          EquipmentAvatar(
            imagePath: q.imagePath,
            functions: q.functions,
            size: 140,
            width: double.infinity,
          ),
          const SizedBox(height: 8),
          Text(q.equipmentName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          const Text('In welchem Fach liegt dieses Gerät?',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          VehicleCutawayView(
            compartments: _compartments,
            tileStates: tileStates,
            onTapCompartment: _answered ? null : (c) => _answer(c, q),
          ),
          if (_answered) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _next,
              child: Text(_currentIndex + 1 < _questions.length
                  ? 'Weiter'
                  : 'Ergebnis'),
            ),
          ],
        ],
      ),
    );
  }

  void _answer(Compartment c, _CutawayQuestion q) {
    final correct = c.id == q.correctCompartmentId;
    if (correct) _score++;
    ref
        .read(appDatabaseProvider)
        .learningDao
        .recordAnswer(q.equipmentId, correct: correct);
    setState(() {
      _tappedCompartmentId = c.id;
      _answered = true;
    });
  }

  void _next() {
    if (_currentIndex + 1 >= _questions.length) {
      _saveResult();
    }
    setState(() {
      _currentIndex++;
      _tappedCompartmentId = null;
      _answered = false;
    });
  }

  Future<void> _saveResult() async {
    final db = ref.read(appDatabaseProvider);
    await db.quizDao.insertResult(QuizResultsCompanion.insert(
      quizType: 'cutaway',
      score: _score,
      total: _questions.length,
      vehicleId: Value(_selectedVehicle!.id),
    ));
  }

  Widget _buildResults() {
    final pct =
        _questions.isNotEmpty ? (_score / _questions.length * 100).round() : 0;
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
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Text('$_score von ${_questions.length} richtig',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 30),
            FilledButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Nochmal spielen'),
              onPressed: () => setState(() {
                _started = false;
                _questions = [];
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _CutawayQuestion {
  final int equipmentId;
  final String equipmentName;
  final String? imagePath;
  final List<String> functions;
  final int correctCompartmentId;

  const _CutawayQuestion({
    required this.equipmentId,
    required this.equipmentName,
    this.imagePath,
    this.functions = const [],
    required this.correctCompartmentId,
  });
}
