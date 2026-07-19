/// app_logger.dart – zentrale Logger-Instanz für die ganze App.
///
/// Statt `Logger()` pro Datei gibt es genau eine Instanz: einheitliches
/// Format und Level, und eine einzige Stelle, an der später weitere Sinks
/// (Datei, Remote) angebunden werden können. Die globalen Fehler-Handler in
/// main.dart schreiben in dieselbe Instanz.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logger/logger.dart';

final Logger appLog = Logger(
  // Release-Builds loggen ab Info (Debug-Geplapper kostet dort nur Zeit),
  // Debug-Builds alles.
  level: kDebugMode ? Level.debug : Level.info,
  printer: PrettyPrinter(methodCount: 0),
);
