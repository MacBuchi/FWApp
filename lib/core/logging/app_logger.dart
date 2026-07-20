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
  // ProductionFilter ist Pflicht, nicht Geschmackssache: Der Default
  // (DevelopmentFilter) setzt sein `shouldLog` INNERHALB eines assert-Blocks.
  // Asserts fallen im Release-Build weg, damit bleibt der Rückgabewert dort
  // immer false — es wird dann gar nichts geloggt, auch nicht ab Info, und
  // auch nicht aus den globalen Fehler-Handlern in main.dart.
  filter: ProductionFilter(),
  // Release-Builds loggen ab Info (Debug-Geplapper kostet dort nur Zeit),
  // Debug-Builds alles.
  level: kDebugMode ? Level.debug : Level.info,
  printer: PrettyPrinter(methodCount: 0),
);
