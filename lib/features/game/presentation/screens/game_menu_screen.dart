/// game_menu_screen.dart – Navigation hub for all training game modes.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GameMenuScreen extends StatelessWidget {
  const GameMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lernen')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
        children: [
          _GameCard(
            icon: Icons.quiz,
            title: 'Fach-Quiz',
            subtitle: 'Welches Fach gehört zu diesem Gerät?',
            color: Colors.indigo,
            onTap: () => context.push('/game/compartment-quiz'),
          ),
          _GameCard(
            icon: Icons.pan_tool,
            title: 'Drag & Drop',
            subtitle: 'Weise Geräte den richtigen Fächern zu',
            color: Colors.teal,
            onTap: () => context.push('/game/drag-drop'),
          ),
          _GameCard(
            icon: Icons.image_search,
            title: 'Bild-Erkennung',
            subtitle: 'Erkenne Geräte anhand ihrer Fotos',
            color: Colors.deepOrange,
            onTap: () => context.push('/game/image-quiz'),
          ),
          _GameCard(
            icon: Icons.grid_view,
            title: 'Wo liegt\'s?',
            subtitle: 'Tippe das richtige Fach in der Schnittdarstellung',
            color: Colors.blue.shade800,
            onTap: () => context.push('/game/cutaway-quiz'),
          ),
          _GameCard(
            icon: Icons.style,
            title: 'Geräte-Wissen',
            subtitle: 'Karteikarten mit Trainingsfragen',
            color: Colors.purple.shade700,
            onTap: () => context.push('/game/flashcards'),
          ),
          _GameCard(
            icon: Icons.directions_car,
            title: 'Einsatzplanung',
            subtitle: 'Analysiere kombinierte Fahrzeugbeladung',
            color: Colors.green.shade700,
            onTap: () => context.push('/game/deployment'),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 40),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
