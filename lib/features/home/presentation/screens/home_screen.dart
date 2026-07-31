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

/// Icon in getönter, abgerundeter Kachel — der moderne Ersatz für das nackte
/// Icon in der Kartenecke. Farbpaar geschlossen aus dem Schema (#58).
class _IconChip extends StatelessWidget {
  const _IconChip(this.icon, {this.muted = false, this.semanticLabel});

  final IconData icon;

  /// Gedämpfte Ausführung für inaktive Zustände (z. B. Serie gerissen).
  final bool muted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color:
            muted ? scheme.surfaceContainerHighest : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        size: 24,
        color: muted
            ? scheme.onSurfaceVariant
            : scheme.onSecondaryContainer,
        semanticLabel: semanticLabel,
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
            // Material-Icon statt Emoji: Das zuvor genutzte 🩶 stammt aus
            // Emoji 15.1 (2023) und fehlt in der Schrift älterer Geräte —
            // auf Android 10 stand hier ein Ersatzkästchen, und zwar im
            // Standardzustand auf dem ersten Bildschirm der App. Icons
            // rendern auf jeder Android-Version gleich.
            _IconChip(
              Icons.local_fire_department,
              muted: !active,
              semanticLabel: active ? 'Serie aktiv' : 'Keine Serie',
            ),
            const SizedBox(height: 12),
            Text('${stats.streakDays}',
                style: Theme.of(context).textTheme.headlineMedium),
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
            const _IconChip(Icons.military_tech),
            const SizedBox(height: 12),
            Text('Level ${stats.level}',
                style: Theme.of(context).textTheme.headlineMedium),
            Text('${stats.xp} XP',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: stats.levelProgress, minHeight: 8),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: _IconChip(
          done ? Icons.emoji_events : Icons.flag,
        ),
        title: Text(done ? 'Wochenziel erreicht!' : 'Wochenziel',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(
            value: (stats.weekSessions / stats.weekGoal).clamp(0.0, 1.0),
            minHeight: 8,
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
    final scheme = Theme.of(context).colorScheme;
    // Die eine Karte, die den vollen Konzept-Akzent trägt (Issue #58): Sie ist
    // der Haupt-Handlungsaufruf des Dashboards, alles andere bleibt ruhig.
    // Der diagonale Weiß-Schimmer liegt ÜBER der garantierten primary/
    // onPrimary-Paarung und bleibt bewusst unter 12 % Deckung — Zierde,
    // die den geprüften Kontrast nicht anfassen darf.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: InkWell(
            onTap: () => context.push('/game/cutaway-quiz'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                        size: 34, color: scheme.onPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weiterlernen',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '${suggestion.vehicleName} · '
                          'Fach ${suggestion.compartmentLabel} · '
                          '$percent % geübt',
                          style: TextStyle(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onPrimary),
                ],
              ),
            ),
          ),
        ),
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
