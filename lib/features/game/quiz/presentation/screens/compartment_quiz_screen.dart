/// compartment_quiz_screen.dart – Multiple-choice: which compartment for this equipment?
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';
import 'package:fwapp/features/compartment/presentation/seiten_farben.dart';
import 'package:fwapp/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class CompartmentQuizScreen extends ConsumerStatefulWidget {
  const CompartmentQuizScreen({super.key});

  @override
  ConsumerState<CompartmentQuizScreen> createState() =>
      _CompartmentQuizScreenState();
}

class _CompartmentQuizScreenState
    extends ConsumerState<CompartmentQuizScreen> {
  Vehicle? _selectedVehicle;
  bool _quizStarted = false;

  // Quiz state
  List<_QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answered = false;

  @override
  Widget build(BuildContext context) {
    if (!_quizStarted) return _buildSetup();
    if (_currentIndex >= _questions.length) return _buildResults();
    return _buildQuestion();
  }

  Widget _buildSetup() {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Fach-Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Wähle ein Fahrzeug oder starte mit allen:',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            vehiclesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Fehler: $e'),
              data: (vehicles) => DropdownButtonFormField<Vehicle?>(
                initialValue: _selectedVehicle,
                decoration:
                    const InputDecoration(labelText: 'Fahrzeug (optional)'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Alle Fahrzeuge')),
                  ...vehicles.map((v) =>
                      DropdownMenuItem(value: v, child: Text(v.name))),
                ],
                onChanged: (v) => setState(() => _selectedVehicle = v),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Quiz starten'),
              onPressed: () => _startQuiz(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startQuiz() async {
    final db = ref.read(appDatabaseProvider);
    final vehicleRepo = ref.read(vehicleRepositoryProvider);
    final allVehicles = _selectedVehicle != null
        ? [_selectedVehicle!]
        : await vehicleRepo.getAll();

    final questions = <_QuizQuestion>[];
    for (final v in allVehicles) {
      final compartments = await db.compartmentDao.getByVehicle(v.id);
      if (compartments.length < 2) continue;
      for (final c in compartments) {
        final assignments = await db.assignmentDao.getByCompartment(c.id);
        for (final a in assignments) {
          final eq = await db.equipmentDao.getById(a.equipmentId);
          if (eq == null) continue;
          // Wrong options: other compartments
          //
          // Die Antworten tragen die Verortung mit (Issue #167): Alle vier
          // zeigen Seite und Längsposition, verraten also nichts — aber wer
          // das Quiz spielt, lernt die Konvention nebenbei mit.
          final wrong = compartments
              .where((x) => x.id != c.id)
              .map(_QuizOption.ausFach)
              .toList();
          if (wrong.length < 3) continue;
          wrong.shuffle();
          final options = [_QuizOption.ausFach(c), ...wrong.take(3)]
            ..shuffle();
          questions.add(_QuizQuestion(
            equipmentId: eq.id,
            equipmentName: eq.name,
            imagePath: eq.imagePath,
            functions: jsonToStringList(eq.equipmentFunctionsJson),
            correctAnswer: c.label,
            options: options,
          ));
        }
      }
    }

    questions.shuffle();
    if (questions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Nicht genug Daten für ein Quiz. Bitte zuerst Fahrzeuge und Beladungen anlegen.')));
      }
      return;
    }

    setState(() {
      _questions = questions.take(20).toList();
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _answered = false;
      _quizStarted = true;
    });
  }

  Widget _buildQuestion() {
    final q = _questions[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Fach-Quiz ${_currentIndex + 1}/${_questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Progress
            LinearProgressIndicator(
                value: _currentIndex / _questions.length),
            const SizedBox(height: 16),
            // Equipment photo or category pictogram
            EquipmentAvatar(
              imagePath: q.imagePath,
              functions: q.functions,
              size: 160,
              width: double.infinity,
            ),
            const SizedBox(height: 12),
            Text(q.equipmentName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('In welchem Fach befindet sich dieses Gerät?',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            // Options
            ...q.options.map((opt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _answered
                            ? opt.label == q.correctAnswer
                                ? Colors.green.withValues(alpha: 0.15)
                                : opt.label == _selectedAnswer
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : null
                            : null,
                        side: BorderSide(
                          color: _answered
                              ? opt.label == q.correctAnswer
                                  ? Colors.green
                                  : opt.label == _selectedAnswer
                                      ? Colors.red
                                      : Colors.grey
                              : Colors.grey,
                          width:
                              _answered && opt.label == q.correctAnswer ? 2 : 1,
                        ),
                        // Waagerecht ausdrücklich: `symmetric(vertical:)`
                        // setzt die Seiten auf 0, und der Farbpunkt klebte
                        // am Rand.
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                      ),
                      onPressed:
                          _answered ? null : () => _answer(opt.label, q),
                      child: _AntwortInhalt(option: opt),
                    ),
                  ),
                )),
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
      ),
    );
  }

  void _answer(String choice, _QuizQuestion q) {
    final correct = choice == q.correctAnswer;
    if (correct) _score++;
    ref
        .read(appDatabaseProvider)
        .learningDao
        .recordAnswer(q.equipmentId, correct: correct);
    setState(() {
      _selectedAnswer = choice;
      _answered = true;
    });
  }

  void _next() {
    if (_currentIndex + 1 >= _questions.length) {
      _saveResult();
    }
    setState(() {
      _currentIndex++;
      _selectedAnswer = null;
      _answered = false;
    });
  }

  Future<void> _saveResult() async {
    final db = ref.read(appDatabaseProvider);
    await db.quizDao.insertResult(QuizResultsCompanion.insert(
      quizType: 'compartment',
      score: _score,
      total: _questions.length,
    ));
  }

  Widget _buildResults() {
    final pct = _questions.isNotEmpty
        ? (_score / _questions.length * 100).round()
        : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Ergebnis')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                  _quizStarted = false;
                  _questions = [];
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Antwortknopf-Inhalt: Farbpunkt, Fachname, Ortsangabe darunter.
///
/// Dasselbe Bild wie die Fach-Karten im Fahrzeugmenü (Punkt links, Verortung
/// als Unterzeile) — wer im Quiz „G5 · Fahrerseite · hinten" liest, findet es
/// dort genauso wieder.
class _AntwortInhalt extends StatelessWidget {
  final _QuizOption option;
  const _AntwortInhalt({required this.option});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = seitenFarbe(option.seite);
    final ort = option.verortung;
    return Row(
      children: [
        if (farbe != null) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: farbe.akzent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(option.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (ort != null)
                Text(ort,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Eine Antwortmöglichkeit: der Fachname und wo das Fach liegt.
///
/// Verglichen wird weiter über [label] — die Antwort ist der Fachname, nicht
/// die Verortung. Die Ortsangabe ist Beiwerk der Anzeige (Issue #167).
class _QuizOption {
  final String label;
  final String? seite;
  final String? laengsposition;

  const _QuizOption({
    required this.label,
    this.seite,
    this.laengsposition,
  });

  factory _QuizOption.ausFach(CompartmentData c) => _QuizOption(
        label: c.label,
        seite: c.seite,
        laengsposition: c.laengsposition,
      );

  /// „Fahrerseite · hinten", oder null für ein Fach ohne Seite — dann bleibt
  /// die Zeile weg, statt „Ohne Seite" als Antwort-Beiwerk zu behaupten.
  ///
  /// Auch weg, wenn sie nur den Fachnamen wiederholt: Ein Fach „Dach" mit der
  /// Unterzeile „Dach" sieht nach Fehler aus, nicht nach Hilfe.
  String? get verortung {
    if (seite == null) return null;
    final ort = verortungAnzeigename(seite, laengsposition);
    return ort.toLowerCase() == label.trim().toLowerCase() ? null : ort;
  }
}

class _QuizQuestion {
  final int equipmentId;
  final String equipmentName;
  final String? imagePath;
  final List<String> functions;
  final String correctAnswer;
  final List<_QuizOption> options;

  const _QuizQuestion({
    required this.equipmentId,
    required this.equipmentName,
    this.imagePath,
    this.functions = const [],
    required this.correctAnswer,
    required this.options,
  });
}
