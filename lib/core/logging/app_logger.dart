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

final Logger appLog = Logger(
  filter: appLogFilter,
  // Release-Builds loggen ab Info (Debug-Geplapper kostet dort nur Zeit),
  // Debug-Builds alles.
  level: kDebugMode ? Level.debug : Level.info,
  printer: PrettyPrinter(methodCount: 0),
);
