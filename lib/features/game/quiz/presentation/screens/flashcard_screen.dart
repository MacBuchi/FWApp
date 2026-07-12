/// flashcard_screen.dart – "Geräte-Wissen": open training questions as
/// flashcards with self-grading (gewusst / nicht gewusst).
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/vehicle/domain/entities/vehicle.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  Vehicle? _selectedVehicle;
  bool _started = false;

  List<_Flashcard> _cards = [];
  int _currentIndex = 0;
  int _known = 0;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (!_started) return _buildSetup();
    if (_currentIndex >= _cards.length) return _buildResults();
    return _buildCard();
  }

  Widget _buildSetup() {
    final vehiclesAsync = ref.watch(vehicleListStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Geräte-Wissen')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Karteikarten mit Trainingsfragen zu den Geräten. '
                'Beantworte die Frage im Kopf, decke die Antwort auf und '
                'bewerte dich selbst.',
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
                      value: null, child: Text('Alle Geräte')),
                  ...vehicles.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v.name))),
                ],
                onChanged: (v) => setState(() => _selectedVehicle = v),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lernen starten'),
              onPressed: _start,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    final db = ref.read(appDatabaseProvider);

    List<EquipmentItemData> items;
    if (_selectedVehicle != null) {
      final assignments =
          await db.assignmentDao.getByVehicle(_selectedVehicle!.id);
      final ids = assignments.map((a) => a.equipmentId).toSet();
      final all = await db.equipmentDao.getAll();
      items = all.where((e) => ids.contains(e.id)).toList();
    } else {
      items = await db.equipmentDao.getAll();
    }

    final cards = <_Flashcard>[];
    for (final item in items) {
      final questions = jsonToStringList(item.trainingQuestionsJson);
      final typicalUse = jsonToStringList(item.typicalUseJson);
      for (final q in questions) {
        cards.add(_Flashcard(
          equipmentName: item.name,
          imagePath: item.imagePath,
          question: q,
          description: item.description,
          typicalUse: typicalUse,
          technicalData: jsonToMap(item.extraAttributesJson),
        ));
      }
    }
    cards.shuffle();

    if (cards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Keine Trainingsfragen vorhanden.')));
      }
      return;
    }

    setState(() {
      _cards = cards.take(20).toList();
      _currentIndex = 0;
      _known = 0;
      _revealed = false;
      _started = true;
    });
  }

  Widget _buildCard() {
    final card = _cards[_currentIndex];
    final technicalEntries = card.technicalData.entries
        .where((e) => e.key != 'image_todo')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Geräte-Wissen ${_currentIndex + 1}/${_cards.length}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LinearProgressIndicator(value: _currentIndex / _cards.length),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: resolveImage(
              path: card.imagePath ?? kPlaceholderAsset,
              width: double.infinity,
              height: 140,
            ),
          ),
          const SizedBox(height: 8),
          Text(card.equipmentName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.help_outline,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(card.question,
                          style: const TextStyle(fontSize: 16))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_revealed)
            FilledButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text('Antwort zeigen'),
              onPressed: () => setState(() => _revealed = true),
            )
          else ...[
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (card.description.isNotEmpty) ...[
                      Text(card.description),
                      const SizedBox(height: 8),
                    ],
                    if (card.typicalUse.isNotEmpty) ...[
                      const Text('Typische Verwendung:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ...card.typicalUse.map((u) => Text('• $u')),
                      const SizedBox(height: 8),
                    ],
                    if (technicalEntries.isNotEmpty) ...[
                      const Text('Technische Daten:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ...technicalEntries
                          .map((e) => Text('${e.key}: ${e.value}')),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Nicht gewusst'),
                    onPressed: () => _next(known: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700),
                    icon: const Icon(Icons.check),
                    label: const Text('Gewusst'),
                    onPressed: () => _next(known: true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _next({required bool known}) {
    if (known) _known++;
    if (_currentIndex + 1 >= _cards.length) {
      _saveResult();
    }
    setState(() {
      _currentIndex++;
      _revealed = false;
    });
  }

  Future<void> _saveResult() async {
    final db = ref.read(appDatabaseProvider);
    await db.quizDao.insertResult(QuizResultsCompanion.insert(
      quizType: 'flashcards',
      score: _known,
      total: _cards.length,
      vehicleId: Value(_selectedVehicle?.id),
    ));
  }

  Widget _buildResults() {
    final pct = _cards.isNotEmpty ? (_known / _cards.length * 100).round() : 0;
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
            Text('$_known von ${_cards.length} gewusst',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 30),
            FilledButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Nochmal lernen'),
              onPressed: () => setState(() {
                _started = false;
                _cards = [];
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _Flashcard {
  final String equipmentName;
  final String? imagePath;
  final String question;
  final String description;
  final List<String> typicalUse;
  final Map<String, dynamic> technicalData;

  const _Flashcard({
    required this.equipmentName,
    this.imagePath,
    required this.question,
    required this.description,
    required this.typicalUse,
    required this.technicalData,
  });
}
