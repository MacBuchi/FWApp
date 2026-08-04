/// dashboard_providers.dart – Personal learning dashboard: streak, XP/level,
/// weekly goal, and a "Weiterlernen" suggestion (weakest compartment).
/// Manual providers (no codegen) — everything is local-device data.
/// Schichtung: bewusst ohne data/domain-Schicht, direkter DAO-Zugriff
/// (rein lokales Feature, siehe CONTRIBUTING.md „Schichtung je Feature").
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// XP needed per level; deliberately simple and transparent.
const kXpPerLevel = 500;

/// Die Lern-Rechnung, an genau einer Stelle: zehn XP je richtiger Antwort,
/// 500 XP je Level. Seit Issue #135 hängt daran auch das Leistungsabzeichen —
/// hätte das seine eigene Rechnung, stünden zwei Zahlen in der App, die sich
/// widersprechen können.
int xpAusErgebnissen(Iterable<QuizResultData> results) =>
    results.fold<int>(0, (sum, r) => sum + r.score * 10);

int levelFuerXp(int xp) => xp ~/ kXpPerLevel + 1;

class LearnSuggestion {
  final int vehicleId;
  final String vehicleName;
  final String compartmentLabel;

  /// 0..1: share of the compartment's items practiced at least once.
  final double coverage;

  const LearnSuggestion({
    required this.vehicleId,
    required this.vehicleName,
    required this.compartmentLabel,
    required this.coverage,
  });
}

class DashboardStats {
  final int streakDays;
  final bool trainedToday;
  final int xp;
  final int level;
  final double levelProgress; // 0..1 within the current level
  final int weekSessions;
  final int weekGoal;
  final LearnSuggestion? suggestion;
  final List<QuizResultData> recentResults;

  const DashboardStats({
    required this.streakDays,
    required this.trainedToday,
    required this.xp,
    required this.level,
    required this.levelProgress,
    required this.weekSessions,
    required this.weekGoal,
    required this.suggestion,
    required this.recentResults,
  });
}

/// Nur das Lern-Level — für alles, was bloß das Leistungsabzeichen zeigen
/// will (Issue #135).
///
/// ⚠️ **Nicht [dashboardStatsProvider] dafür benutzen.** Der durchsucht für
/// seine „Weiterlernen"-Empfehlung jedes Fahrzeug, jedes Fach und jede
/// Zuordnung. Das ist auf der Startseite richtig und in einer
/// Einstellungs-Kachel Verschwendung — und es zog den Profil-Screen, der
/// vorher ohne Datenbank auskam, in die halbe App hinein.
///
/// `null` heißt „noch nicht geladen", nicht „Level 0": Ein Platzhalter, der
/// gleich etwas anderes behauptet, ist schlimmer als eine kurze Lücke.
final lernLevelProvider = Provider<int?>((ref) {
  final results = ref.watch(quizResultsStreamProvider).value;
  return results == null ? null : levelFuerXp(xpAusErgebnissen(results));
});

final quizResultsStreamProvider = StreamProvider<List<QuizResultData>>(
    (ref) => ref.watch(quizDaoProvider).watchAll());

final learningProgressStreamProvider =
    StreamProvider<List<LearningProgressData>>(
        (ref) => ref.watch(learningDaoProvider).watchAll());

/// Weekly goal (sessions per week), persisted on the device.
class WeekGoalNotifier extends Notifier<int> {
  static const _key = 'week_goal';

  @override
  int build() {
    SharedPreferences.getInstance()
        .then((prefs) => state = prefs.getInt(_key) ?? 5);
    return 5;
  }

  Future<void> set(int goal) async {
    state = goal.clamp(1, 21);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, state);
  }
}

final weekGoalProvider =
    NotifierProvider<WeekGoalNotifier, int>(WeekGoalNotifier.new);

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final results = ref.watch(quizResultsStreamProvider).value ?? const [];
  final progress = ref.watch(learningProgressStreamProvider).value ?? const [];
  final weekGoal = ref.watch(weekGoalProvider);
  final db = ref.watch(appDatabaseProvider);

  // ── Streak: consecutive days with at least one session, counting back
  // from today (an unbroken run ending yesterday still counts). ──
  final days = results
      .map((r) => DateTime(r.playedAt.year, r.playedAt.month, r.playedAt.day))
      .toSet();
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final trainedToday = days.contains(todayDate);
  var streak = 0;
  var cursor = trainedToday
      ? todayDate
      : todayDate.subtract(const Duration(days: 1));
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // ── XP & Level ──
  final xp = xpAusErgebnissen(results);
  final level = levelFuerXp(xp);
  final levelProgress = (xp % kXpPerLevel) / kXpPerLevel;

  // ── Weekly goal (week starts Monday) ──
  final weekStart =
      todayDate.subtract(Duration(days: todayDate.weekday - 1));
  final weekSessions =
      results.where((r) => !r.playedAt.isBefore(weekStart)).length;

  // ── Suggestion: compartment with the lowest practice coverage ──
  LearnSuggestion? suggestion;
  final vehicles = await db.vehicleDao.getAll();
  final practiced = {
    for (final p in progress)
      if (p.correctCount + p.wrongCount > 0) p.equipmentId
  };
  double bestScore = double.infinity;
  for (final vehicle in vehicles) {
    final compartments = await db.compartmentDao.getByVehicle(vehicle.id);
    for (final compartment in compartments) {
      final assignments =
          await db.assignmentDao.getByCompartment(compartment.id);
      if (assignments.length < 3) continue; // zu klein für eine Empfehlung
      final covered =
          assignments.where((a) => practiced.contains(a.equipmentId)).length;
      final coverage = covered / assignments.length;
      if (coverage < bestScore) {
        bestScore = coverage;
        suggestion = LearnSuggestion(
          vehicleId: vehicle.id,
          vehicleName: vehicle.name,
          compartmentLabel: compartment.label,
          coverage: coverage,
        );
      }
    }
  }

  return DashboardStats(
    streakDays: streak,
    trainedToday: trainedToday,
    xp: xp,
    level: level,
    levelProgress: levelProgress,
    weekSessions: weekSessions,
    weekGoal: weekGoal,
    suggestion: suggestion,
    recentResults: results.take(5).toList(),
  );
});
