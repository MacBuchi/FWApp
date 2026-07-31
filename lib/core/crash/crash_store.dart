/// crash_store.dart – Hält Abstürze auf dem Gerät fest, damit sie beim
/// nächsten Start gemeldet werden können (Issue #34).
///
/// Warum lokal statt direkt an ein Crash-Backend: Ein selbst gehostetes
/// GlitchTip ist entschieden, aber blockiert (AGENTS.md „Zurückgestellt" — die
/// VM zieht ohne IPv4 keine Container-Images). Bis dahin wäre die Alternative
/// „gar nichts", und Feldabstürze blieben unsichtbar.
///
/// ⚠️ **Der Bericht muss den Absturz überleben.** Deshalb wird im Handler
/// **synchron auf Platte** geschrieben, bevor irgendetwas anderes passiert.
/// Bis v1.5.1 lief hier `unawaited(...)` gegen asynchrone SharedPreferences —
/// die Observability-Guideline führt genau das unter „So nicht", weil es bei
/// harten Abstürzen nie ankommt. Der Pfad wird beim Start einmal aufgelöst
/// und gemerkt, damit der Handler ohne `await` schreiben kann.
///
/// **Reichweite:** Dart-Fehler aus `FlutterError.onError` und
/// `PlatformDispatcher.onError`. Ein harter nativer Absturz beendet den
/// Prozess, bevor Dart-Code läuft — dafür ist
/// `getHistoricalProcessExitReasons` vorgesehen (ab Android 11, ohne
/// Berechtigung, siehe AGENTS.md), noch nicht umgesetzt.
///
/// **Ablage:** Application-Support-Verzeichnis, nicht neben Nutzerdaten.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/crash/crash_report.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Dateiname im Application-Support-Verzeichnis.
const kCrashFileName = 'crash_reports.json';

/// Ring-Buffer-Grenze: Mehr Berichte werden nicht aufgehoben, die ältesten
/// fliegen raus. Eine Absturzschleife darf die Platte nicht füllen.
const kMaxStoredCrashes = 20;

/// Serialisiert eine Liste von Berichten und behält nur die
/// [kMaxStoredCrashes] jüngsten. Rein, damit der Test das Kappen direkt prüft.
String encodeCrashReports(List<CrashReport> reports,
    {int max = kMaxStoredCrashes}) {
  final kept =
      reports.length <= max ? reports : reports.sublist(reports.length - max);
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

/// Schreibt und liest die Berichte als Datei.
///
/// Bewusst eine Datei und keine SharedPreferences: Nur so lässt sich im
/// Fehler-Handler **synchron** schreiben.
class CrashStore {
  /// Zieldatei. Wird beim Start aufgelöst, damit [recordSync] ohne `await`
  /// auskommt.
  final File file;

  CrashStore(this.file);

  List<CrashReport> load() {
    try {
      if (!file.existsSync()) return const [];
      return decodeCrashReports(file.readAsStringSync());
    } catch (e) {
      appLog.w('Absturzberichte nicht lesbar', error: e);
      return const [];
    }
  }

  /// Hängt einen Bericht an — **synchron**, damit er einen sofortigen
  /// Prozesstod übersteht.
  void recordSync(CrashReport report) {
    final reports = [...load(), report];
    file.writeAsStringSync(encodeCrashReports(reports), flush: true);
  }

  void clear() {
    if (file.existsSync()) file.deleteSync();
  }
}

/// Global gehalten, weil die Fehler-Handler in main.dart keinen `Ref` haben:
/// `FlutterError.onError` wird vor `runApp` gesetzt und läuft ausserhalb des
/// Provider-Baums. Bleibt `null` auf Web (kein Dateisystem) und solange der
/// Pfad nicht aufgelöst ist.
CrashStore? globalCrashStore;

/// Kontext, den jeder Bericht mitbekommt. Beim Start einmal ermittelt, weil
/// der Handler dafür keine Zeit hat.
class CrashContext {
  final String appVersion;
  final String device;
  final String locale;

  const CrashContext({
    this.appVersion = 'unbekannt',
    this.device = '',
    this.locale = '',
  });
}

CrashContext globalCrashContext = const CrashContext();

/// Plattform und OS-Version, z. B. `android — Android 16 (API 36)`.
///
/// Bewusst ohne `device_info_plus`: `dart:io` liefert Plattform und
/// OS-Version ohne zusätzliche Abhängigkeit, und die tragen den Großteil der
/// Aussage. Das **Gerätemodell** fehlt dadurch — es käme erst mit dem Paket,
/// und dafür ist der Gewinn zu klein.
String describeDevice() {
  if (kIsWeb) return 'web';
  try {
    return '${Platform.operatingSystem} — ${Platform.operatingSystemVersion}';
  } catch (_) {
    // Auf exotischen Zielen kann das werfen; ein fehlendes Feld ist besser
    // als ein Absturz im Absturzpfad.
    return '';
  }
}

/// Richtet den Absturzspeicher ein. Aus main.dart **vor** den Handlern
/// aufrufen. Auf Web wirkungslos (kein beschreibbares Dateisystem).
Future<void> initCrashStore({required CrashContext context}) async {
  globalCrashContext = context;
  if (kIsWeb) return;
  try {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    globalCrashStore = CrashStore(File(p.join(dir.path, kCrashFileName)));
  } catch (e, s) {
    appLog.w('Absturzspeicher nicht verfügbar', error: e, stackTrace: s);
  }
}

/// Nimmt einen Absturz entgegen — synchron und ohne `await`.
///
/// Fängt eigene Fehler ab: Ein Fehlschlag beim Festhalten darf den ohnehin
/// schon fehlerhaften Zustand nicht verschlimmern.
void recordCrash({
  required String source,
  required Object error,
  StackTrace? stackTrace,
}) {
  final store = globalCrashStore;
  if (store == null) return;
  try {
    final errorText = error.toString();
    final stackText = stackTrace?.toString() ?? '';
    store.recordSync(CrashReport(
      time: DateTime.now().toUtc(),
      appVersion: globalCrashContext.appVersion,
      device: globalCrashContext.device,
      locale: globalCrashContext.locale,
      source: source,
      error: errorText,
      stackTrace: truncateStack(stackText),
      fingerprint: crashFingerprint(errorText, stackText),
      // Vorgeschichte aus dem Ring — ein Stacktrace allein ist oft nicht
      // diagnostizierbar.
      log: appLogRing.lines,
    ));
  } catch (e) {
    appLog.w('Absturzbericht konnte nicht gespeichert werden', error: e);
  }
}

/// Die beim Start vorgefundenen Berichte (also die des *vorherigen* Laufs),
/// **dedupliziert**: pro Fingerprint bleibt der jüngste stehen.
///
/// Ohne das erzeugt eine Absturzschleife zwanzig gleiche Meldungen, und die
/// Nutzerin sieht „20 Probleme", wo es einer ist.
final pendingCrashesProvider = FutureProvider<List<CrashReport>>((ref) async {
  final store = globalCrashStore;
  if (store == null) return const [];
  return dedupeCrashes(store.load());
});

/// Behält je Fingerprint den jüngsten Bericht, Reihenfolge nach Zeit.
List<CrashReport> dedupeCrashes(List<CrashReport> reports) {
  final newest = <String, CrashReport>{};
  for (final report in reports) {
    final existing = newest[report.fingerprint];
    if (existing == null || report.time.isAfter(existing.time)) {
      newest[report.fingerprint] = report;
    }
  }
  final result = newest.values.toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  return result;
}
