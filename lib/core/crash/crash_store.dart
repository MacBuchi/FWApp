/// crash_store.dart – Hält Abstürze auf dem Gerät fest, damit sie beim
/// nächsten Start gemeldet werden können (Issue #34).
///
/// Warum lokal statt direkt an ein Crash-Backend: Ein selbst gehostetes
/// GlitchTip ist entschieden, aber blockiert (AGENTS.md „Zurückgestellt" — die
/// VM zieht ohne IPv4 keine Container-Images). Bis dahin wäre die Alternative
/// „gar nichts", und Feldabstürze blieben unsichtbar. Der Bericht landet
/// deshalb erst auf dem Gerät und geht beim nächsten Start über den bereits
/// bestehenden Feedback→GitHub-Issue-Kanal raus — mit Stacktrace und Version,
/// die bei einer freiwilligen Rückmeldung sonst fehlen.
///
/// **Reichweite:** Das erfasst Dart-Fehler aus `FlutterError.onError` und
/// `PlatformDispatcher.onError`, also genau das, was main.dart heute schon
/// loggt. Ein harter nativer Absturz beendet den Prozess, bevor Dart-Code
/// läuft — der ist hiermit nicht abgedeckt.
///
/// ⚠️ **Diese Umsetzung weicht vom Bauplan „Route A" der
/// Observability-Guideline im DocuHub ab** (dort produktiv an PilzBuddy
/// gemessen). Offen sind: synchrones Schreiben im Handler statt `unawaited`,
/// Dedupe-Fingerprint, Log-Ring-Buffer im Bericht und eine eigene Senke statt
/// eines Issues pro Absturz. Für harte Abstürze und ANRs braucht es **kein**
/// Backend, sondern `getHistoricalProcessExitReasons` (ab Android 11, ohne
/// Berechtigung). Details und Reihenfolge stehen in AGENTS.md.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Schlüssel in den SharedPreferences.
const kCrashReportsKey = 'crash_reports';

/// Mehr als diese Zahl an Berichten wird nicht aufgehoben — die ältesten
/// fliegen raus. Verhindert, dass eine Absturzschleife die Prefs vollschreibt.
const kMaxStoredCrashes = 3;

/// Stacktraces werden hart gekürzt. Die obersten Frames tragen die Information;
/// ein vollständiger Trace kann Dutzende Kilobyte haben und würde sowohl die
/// Prefs als auch das GitHub-Issue sprengen.
const kMaxStackChars = 4000;

/// Ein festgehaltener Absturz.
class CrashReport {
  /// Zeitpunkt in UTC.
  final DateTime time;

  /// `1.4.9 (Build 17)` — ohne die ist ein Bericht kaum auswertbar.
  final String appVersion;

  /// Woher der Fehler kam, z. B. `Flutter framework` oder `Async`.
  final String source;
  final String error;
  final String stackTrace;

  const CrashReport({
    required this.time,
    required this.appVersion,
    required this.source,
    required this.error,
    required this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'appVersion': appVersion,
        'source': source,
        'error': error,
        'stackTrace': stackTrace,
      };

  static CrashReport? fromJson(Map<String, dynamic> json) {
    final time = DateTime.tryParse(json['time'] as String? ?? '');
    if (time == null) return null;
    return CrashReport(
      time: time,
      appVersion: json['appVersion'] as String? ?? 'unbekannt',
      source: json['source'] as String? ?? 'unbekannt',
      error: json['error'] as String? ?? '',
      stackTrace: json['stackTrace'] as String? ?? '',
    );
  }

  /// Text für das GitHub-Issue bzw. die Zwischenablage.
  String toReportText() => '''
Absturz vom ${time.toLocal()}
App-Version: $appVersion
Quelle: $source

$error

$stackTrace''';
}

/// Kürzt einen Stacktrace auf [kMaxStackChars] und vermerkt das sichtbar,
/// damit niemand einen abgeschnittenen Trace für vollständig hält.
String truncateStack(String stack, {int max = kMaxStackChars}) {
  if (stack.length <= max) return stack;
  return '${stack.substring(0, max)}\n… (gekürzt)';
}

/// Serialisiert eine Liste von Berichten und behält nur die [kMaxStoredCrashes]
/// jüngsten. Rein, damit der Test das Kappen direkt prüfen kann.
String encodeCrashReports(List<CrashReport> reports,
    {int max = kMaxStoredCrashes}) {
  final kept = reports.length <= max
      ? reports
      : reports.sublist(reports.length - max);
  return jsonEncode(kept.map((r) => r.toJson()).toList());
}

/// Gegenstück zu [encodeCrashReports]. Unlesbare Einträge werden übersprungen
/// statt zu werfen: Ein kaputter Bericht darf den Start nicht blockieren.
List<CrashReport> decodeCrashReports(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CrashReport.fromJson)
        .nonNulls
        .toList();
  } catch (e) {
    appLog.w('Absturzberichte unlesbar, werden verworfen', error: e);
    return const [];
  }
}

/// Schreibt und liest die Berichte in den SharedPreferences.
///
/// Bewusst SharedPreferences statt einer Datei: Die App bindet das Paket
/// ohnehin ein, es funktioniert auf allen Zielplattformen inklusive Web, und
/// der Datenumfang ist durch [kMaxStoredCrashes] und [kMaxStackChars] gedeckelt.
class CrashStore {
  final SharedPreferences _prefs;

  CrashStore(this._prefs);

  List<CrashReport> load() => decodeCrashReports(_prefs.getString(kCrashReportsKey));

  Future<void> record(CrashReport report) async {
    final reports = [...load(), report];
    await _prefs.setString(kCrashReportsKey, encodeCrashReports(reports));
  }

  Future<void> clear() => _prefs.remove(kCrashReportsKey);
}

/// Global gehalten, weil die Fehler-Handler in main.dart keinen `Ref` haben:
/// `FlutterError.onError` wird vor `runApp` gesetzt und läuft ausserhalb des
/// Provider-Baums. Bleibt `null`, solange die Prefs nicht geladen sind — dann
/// geht der Bericht verloren, was hinnehmbar ist (der reine Startpfad).
CrashStore? globalCrashStore;

/// Nimmt einen Absturz entgegen. Fängt eigene Fehler ab: Ein Fehlschlag beim
/// Festhalten darf den ohnehin schon fehlerhaften Zustand nicht verschlimmern.
Future<void> recordCrash({
  required String source,
  required Object error,
  StackTrace? stackTrace,
  required String appVersion,
}) async {
  final store = globalCrashStore;
  if (store == null) return;
  try {
    await store.record(CrashReport(
      time: DateTime.now().toUtc(),
      appVersion: appVersion,
      source: source,
      error: error.toString(),
      stackTrace: truncateStack(stackTrace?.toString() ?? ''),
    ));
  } catch (e) {
    appLog.w('Absturzbericht konnte nicht gespeichert werden', error: e);
  }
}

/// Die beim Start vorgefundenen Berichte (also die des *vorherigen* Laufs).
final pendingCrashesProvider =
    FutureProvider<List<CrashReport>>((ref) async {
  final store = globalCrashStore;
  if (store == null) return const [];
  return store.load();
});
