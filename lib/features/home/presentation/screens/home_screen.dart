/// home_screen.dart – Persönliches Lern-Dashboard (Start tab): Tagesserie,
/// XP/Level, Wochenziel, "Weiterlernen"-Empfehlung, letzte Ergebnisse.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/home/presentation/providers/dashboard_providers.dart';
import 'package:fwapp/features/home/presentation/widgets/home_banners.dart';
import 'package:fwapp/features/inspection/presentation/providers/inspection_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final isAdmin = ref.watch(canEditProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Moin! 👋')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HomeBanners(),
            Row(
              children: [
                Expanded(child: _StreakCard(stats: stats)),
                const SizedBox(width: 12),
                Expanded(child: _LevelCard(stats: stats)),
              ],
            ),
            const SizedBox(height: 12),
            _WeekGoalCard(stats: stats),
            const SizedBox(height: 12),
            if (stats.suggestion != null)
              _SuggestionCard(suggestion: stats.suggestion!),
            if (isAdmin) const _InspectionsCard(),
            if (stats.recentResults.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text('Letzte Übungen',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ...stats.recentResults.map((r) => _ResultTile(
                    quizType: r.quizType,
                    score: r.score,
                    total: r.total,
                    playedAt: r.playedAt,
                  )),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final DashboardStats stats;
  const _StreakCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final active = stats.streakDays > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(active ? '🔥' : '🩶', style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text('${stats.streakDays}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              stats.streakDays == 1 ? 'Tag Serie' : 'Tage Serie',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (active && !stats.trainedToday)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Heute noch üben!',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800)),
              ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final DashboardStats stats;
  const _LevelCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.military_tech,
                size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text('Level ${stats.level}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text('${stats.xp} XP',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: stats.levelProgress, minHeight: 6),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekGoalCard extends ConsumerWidget {
  final DashboardStats stats;
  const _WeekGoalCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = stats.weekSessions >= stats.weekGoal;
    return Card(
      child: ListTile(
        leading: Icon(done ? Icons.emoji_events : Icons.flag,
            color: done
                ? Colors.amber.shade700
                : Theme.of(context).colorScheme.primary),
        title: Text(done ? 'Wochenziel erreicht!' : 'Wochenziel'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (stats.weekSessions / stats.weekGoal).clamp(0.0, 1.0),
              minHeight: 6,
            ),
          ),
        ),
        trailing: Text('${stats.weekSessions}/${stats.weekGoal}',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16)),
        onTap: () => _editGoal(context, ref),
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, WidgetRef ref) async {
    final goal = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Übungen pro Woche'),
        children: [3, 5, 7, 10, 14]
            .map((g) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, g),
                  child: Text('$g Übungen'),
                ))
            .toList(),
      ),
    );
    if (goal != null) {
      await ref.read(weekGoalProvider.notifier).set(goal);
    }
  }
}

class _SuggestionCard extends StatelessWidget {
  final LearnSuggestion suggestion;
  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final percent = (suggestion.coverage * 100).round();
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.play_circle_fill,
            size: 36, color: Theme.of(context).colorScheme.primary),
        title: const Text('Weiterlernen',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${suggestion.vehicleName} · Fach ${suggestion.compartmentLabel} · '
            '$percent % geübt'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/game/cutaway-quiz'),
      ),
    );
  }
}

/// Gerätewart-Hinweis — nur für Admins auf dem Dashboard.
class _InspectionsCard extends ConsumerWidget {
  const _InspectionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(dueInspectionsStreamProvider()).value ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final overdue = entries.where((e) => e.isOverdue(now)).length;
    final dueSoon = entries.length - overdue;
    final color =
        overdue > 0 ? Colors.red.shade700 : Colors.orange.shade800;
    return Card(
      child: ListTile(
        leading: Icon(Icons.fact_check, color: color),
        title: const Text('Prüftermine'),
        subtitle: Text([
          if (overdue > 0) '$overdue überfällig',
          if (dueSoon > 0) '$dueSoon bald fällig',
        ].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/inspections'),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String quizType;
  final int score;
  final int total;
  final DateTime playedAt;

  const _ResultTile({
    required this.quizType,
    required this.score,
    required this.total,
    required this.playedAt,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (score / total * 100).round() : 0;
    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: pct >= 80
              ? Colors.green
              : pct >= 50
                  ? Colors.orange
                  : Colors.red,
          child: Text('$pct%',
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
        title: Text(switch (quizType) {
          'compartment' => 'Fach-Quiz',
          'cutaway' => 'Wo liegt\'s?',
          'flashcards' => 'Geräte-Wissen',
          'dragdrop' => 'Drag & Drop',
          _ => 'Bild-Quiz',
        }),
        subtitle: Text('$score/$total richtig'),
        trailing: Text(
          '${playedAt.day.toString().padLeft(2, '0')}.'
          '${playedAt.month.toString().padLeft(2, '0')}.'
          '${playedAt.year}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
