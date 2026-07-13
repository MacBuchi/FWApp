/// image_quiz_screen.dart – Image recognition quiz: identify equipment from photo.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';

class ImageRecognitionQuizScreen extends ConsumerStatefulWidget {
  const ImageRecognitionQuizScreen({super.key});

  @override
  ConsumerState<ImageRecognitionQuizScreen> createState() =>
      _ImageQuizState();
}

class _ImageQuizState extends ConsumerState<ImageRecognitionQuizScreen> {
  List<_ImageQuestion> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answered = false;
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    if (!_started) return _buildIntro();
    if (_currentIndex >= _questions.length && _questions.isNotEmpty) {
      return _buildResults();
    }
    if (_questions.isEmpty) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return _buildQuestion();
  }

  Widget _buildIntro() {
    return Scaffold(
      appBar: AppBar(title: const Text('Bild-Erkennung')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_search, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Erkenne Geräte anhand ihrer Fotos.\n'
                '10 Fragen – wähle den richtigen Namen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Quiz starten'),
                onPressed: _startQuiz,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startQuiz() async {
    final all = await ref.read(equipmentListProvider.future);
    // Bild-Erkennung ergibt nur mit echten Fotos Sinn.
    final withImage = all
        .where((e) => e.imagePath != null && e.imagePath!.isNotEmpty)
        .toList();
    if (withImage.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Mindestens 4 Geräte mit Foto notwendig für die Bild-Erkennung.')));
      }
      return;
    }
    final shuffled = [...withImage]..shuffle();
    final questions = <_ImageQuestion>[];
    for (var i = 0; i < shuffled.length && questions.length < 10; i++) {
      final correct = shuffled[i];
      // Falsche Optionen dürfen aus dem Gesamtbestand kommen.
      final wrong = ([...all]..shuffle())
          .where((e) => e.id != correct.id)
          .take(3)
          .map((e) => e.name)
          .toList();
      if (wrong.length < 3) continue;
      final options = [correct.name, ...wrong]..shuffle();
      questions.add(_ImageQuestion(
        equipmentId: correct.id,
        imagePath: correct.imagePath,
        correctAnswer: correct.name,
        options: options,
      ));
    }
    setState(() {
      _questions = questions;
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _answered = false;
      _started = true;
    });
  }

  Widget _buildQuestion() {
    final q = _questions[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Bild-Quiz  ${_currentIndex + 1}/${_questions.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
              value: _currentIndex / _questions.length),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Image
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: resolveImage(
                  path: q.imagePath ?? kPlaceholderAsset,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Welches Gerät ist das?',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ...q.options.map((opt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _answered
                            ? opt == q.correctAnswer
                                ? Colors.green.withValues(alpha: 0.15)
                                : opt == _selectedAnswer
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : null
                            : null,
                        side: BorderSide(
                          color: _answered
                              ? opt == q.correctAnswer
                                  ? Colors.green
                                  : opt == _selectedAnswer
                                      ? Colors.red
                                      : Colors.grey
                              : Colors.grey,
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: _answered ? null : () => _answer(opt, q),
                      child: Text(opt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                )),
            if (_answered) ...[
              const SizedBox(height: 12),
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

  void _answer(String choice, _ImageQuestion q) {
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
    if (_currentIndex + 1 >= _questions.length) _saveResult();
    setState(() {
      _currentIndex++;
      _selectedAnswer = null;
      _answered = false;
    });
  }

  Future<void> _saveResult() async {
    final db = ref.read(appDatabaseProvider);
    await db.quizDao.insertResult(QuizResultsCompanion.insert(
      quizType: 'image_recognition',
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
            Text('$_score von ${_questions.length} richtig',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Nochmal'),
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

class _ImageQuestion {
  final int equipmentId;
  final String? imagePath;
  final String correctAnswer;
  final List<String> options;

  const _ImageQuestion({
    required this.equipmentId,
    this.imagePath,
    required this.correctAnswer,
    required this.options,
  });
}
