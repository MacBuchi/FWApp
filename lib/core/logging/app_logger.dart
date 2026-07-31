/// app_logger.dart – zentrale Logger-Instanz für die ganze App.
///
/// Statt `Logger()` pro Datei gibt es genau eine Instanz: einheitliches
/// Format und Level, und eine einzige Stelle, an der später weitere Sinks
/// (Datei, Remote) angebunden werden können. Die globalen Fehler-Handler in
/// main.dart schreiben in dieselbe Instanz.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logger/logger.dart';

/// Der Filter der App-Instanz – exportiert, damit die Verdrahtung überhaupt
/// prüfbar ist: `Logger` hält sein Filter-Feld privat.
///
/// **Muss ein [ProductionFilter] bleiben.** Der Paket-Default
/// [DevelopmentFilter] wertet das Level innerhalb eines `assert`-Blocks aus.
/// Im Release werden Asserts wegoptimiert, sein `shouldLog` liefert dann
/// konstant `false` – die App loggt gar nichts mehr, auch keine Fehler.
/// [ProductionFilter] wertet dasselbe Level ohne `assert` aus.
final LogFilter appLogFilter = ProductionFilter();

/// So viele Log-Zeilen hält der Ring-Buffer für Absturzberichte vor.
const kLogRingSize = 50;

/// Länge, auf die eine einzelne Zeile gekürzt wird.
///
/// Eine lange Zeile (etwa ein hineingereichter Serverfehler) würde den halben
/// Ring belegen und die Vorgeschichte verdrängen, um die es hier geht.
const kLogRingMaxLineChars = 300;

/// Die letzten Log-Zeilen im Speicher — Vorgeschichte für Absturzberichte
/// (Issue #34).
///
/// **Ein Stacktrace ohne Vorgeschichte ist oft nicht diagnostizierbar**; genau
/// daran scheitern freiwillige Nutzerberichte („ging nicht"). Der Ring hängt
/// deshalb am zentralen Logger und wird beim Absturz mitgeschrieben.
///
/// ⚠️ **Was hier nicht geloggt werden darf, landet sonst im öffentlichen
/// GitHub-Issue** — die Repos sind public. Beim Ergänzen von Log-Aufrufen
/// gilt dieselbe Regel wie für den Bericht selbst: keine Token, keine
/// Zugangsdaten, keine Nutzernamen. `test/core/crash/crash_pii_test.dart`
/// prüft das gegen eine Fake-Session.
class LogRingBuffer {
  final List<String> _lines = [];

  void add(String line) {
    // PrettyPrinter rahmt jede Meldung mit Kastengrafik ein. Ungefiltert
    // belegt eine einzige Meldung drei Ringplätze, und statt 50 Meldungen
    // trüge der Bericht knapp 17 — auf dem Emulator nachgemessen.
    final trimmed = _stripBox(line);
    if (trimmed.isEmpty) return;
    _lines.add(trimmed.length > kLogRingMaxLineChars
        ? '${trimmed.substring(0, kLogRingMaxLineChars)}…'
        : trimmed);
    if (_lines.length > kLogRingSize) {
      _lines.removeRange(0, _lines.length - kLogRingSize);
    }
  }

  /// Entfernt Rahmenzeichen und führende Kastenstriche. Reine Rahmenzeilen
  /// werden zu `''` und damit verworfen.
  static String _stripBox(String line) {
    var out = line.trim();
    // Führendes │ / ├ / ┌ / └ samt folgendem Leerraum.
    out = out.replaceFirst(RegExp(r'^[│├┌└]+\s*'), '');
    // Übrig bleibende reine Strichzeilen.
    if (RegExp(r'^[─┄╌\s]*$').hasMatch(out)) return '';
    return out.trim();
  }

  /// Älteste zuerst — so liest sich die Vorgeschichte in Ablaufrichtung.
  List<String> get lines => List.unmodifiable(_lines);

  void clear() => _lines.clear();
}

/// Der Ring der App-Instanz. Global wie der Logger selbst, weil die
/// Fehler-Handler in main.dart vor `runApp` laufen und keinen `Ref` haben.
final LogRingBuffer appLogRing = LogRingBuffer();

/// Schreibt jede Ausgabe zusätzlich in [appLogRing].
///
/// Als `LogOutput` und nicht als `LogPrinter`: Das Level filtert vorher, und
/// wir bekommen genau die Zeilen, die auch auf der Konsole landen.
class _RingOutput extends LogOutput {
  final LogOutput _delegate;
  _RingOutput(this._delegate);

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      appLogRing.add(_ansi.hasMatch(line) ? line.replaceAll(_ansi, '') : line);
    }
    _delegate.output(event);
  }

  /// PrettyPrinter setzt Farbcodes; im Bericht wären sie nur Rauschen.
  static final _ansi = RegExp(r'\x1B\[[0-9;]*m');
}

final Logger appLog = Logger(
  filter: appLogFilter,
  // Release-Builds loggen ab Info (Debug-Geplapper kostet dort nur Zeit),
  // Debug-Builds alles.
  level: kDebugMode ? Level.debug : Level.info,
  printer: PrettyPrinter(methodCount: 0),
  output: _RingOutput(ConsoleOutput()),
);
