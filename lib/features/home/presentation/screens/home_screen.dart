/// home_screen.dart – Dashboard with stats, quick navigation, and recent quiz scores.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:fwapp/core/database/database_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleCountAsync = ref.watch(vehicleCountProvider);
    final equipmentCountAsync = ref.watch(equipmentCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feuerwehr-Lernapp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.fire_truck,
                  label: 'Fahrzeuge',
                  valueAsync: vehicleCountAsync,
                  onTap: () => context.go('/vehicles'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.inventory_2,
                  label: 'Geräte',
                  valueAsync: equipmentCountAsync,
                  onTap: () => context.go('/equipment'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Schnellzugriff',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          // Navigation grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _NavCard(
                icon: Icons.fire_truck,
                label: 'Fahrzeugflotte',
                color: Colors.red.shade700,
                onTap: () => context.go('/vehicles'),
              ),
              _NavCard(
                icon: Icons.inventory_2,
                label: 'Gerätedatenbank',
                color: Colors.orange.shade700,
                onTap: () => context.go('/equipment'),
              ),
              _NavCard(
                icon: Icons.sports_esports,
                label: 'Trainings-\nSpielmodi',
                color: Colors.green.shade700,
                onTap: () => context.go('/game'),
              ),
              _NavCard(
                icon: Icons.upload_file,
                label: 'Beladeplan\nimportieren',
                color: Colors.blue.shade700,
                onTap: () => context.push('/import'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Letzte Ergebnisse',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _RecentQuizResults(),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final AsyncValue<int> valueAsync;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.valueAsync,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(height: 8),
              valueAsync.when(
                loading: () => const CircularProgressIndicator(strokeWidth: 2),
                error: (_, __) => const Text('?'),
                data: (n) => Text('$n',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentQuizResults extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return FutureBuilder(
      future: db.quizDao.getRecent(limit: 5),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final results = snapshot.data!;
        if (results.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Noch kein Quiz gespielt.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: results.map((r) {
            final pct = r.total > 0
                ? (r.score / r.total * 100).round()
                : 0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: pct >= 80
                    ? Colors.green
                    : pct >= 50
                        ? Colors.orange
                        : Colors.red,
                child: Text('$pct%',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11)),
              ),
              title: Text(r.quizType == 'compartment'
                  ? 'Fach-Quiz'
                  : 'Bild-Quiz'),
              subtitle: Text(
                  '${r.score}/${r.total} Punkte'),
              trailing: Text(
                _formatDate(r.playedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }
}
