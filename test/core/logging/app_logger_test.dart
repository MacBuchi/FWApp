/// app_logger_test.dart – Regressionsschutz für den Filter der zentralen
/// Logger-Instanz.
///
/// Einordnung: Dieser Test kann den Fehlerfall selbst **nicht** nachstellen.
/// Er tritt nur auf, wenn Asserts wegoptimiert sind, und `flutter test` läuft
/// immer mit aktiven Asserts – dort verhält sich auch der DevelopmentFilter
/// unauffällig. Geprüft wird deshalb die Verdrahtung: dass die App-Instanz an
/// einem ProductionFilter hängt und dieser das Level ohne `assert` auswertet.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:logger/logger.dart';

void main() {
  test('appLog hängt an appLogFilter', () {
    // Der Logger-Konstruktor schreibt sein Level in den übergebenen Filter.
    // Trägt appLogFilter das Debug-Level der App, ist es derselbe Filter –
    // ein loser ProductionFilter fiele auf Logger.level (trace) zurück.
    expect(appLog, isA<Logger>()); // erzwingt die lazy Initialisierung
    expect(appLogFilter.level, Level.debug,
        reason: 'flutter test läuft im Debug-Modus');
  });

  test('appLogFilter ist ein ProductionFilter – sonst schweigt das Release',
      () {
    expect(appLogFilter, isA<ProductionFilter>());
  });

  test('ProductionFilter wertet das Level ohne assert aus', () {
    final filter = ProductionFilter()..level = Level.info;

    expect(filter.shouldLog(LogEvent(Level.debug, 'x')), isFalse);
    expect(filter.shouldLog(LogEvent(Level.info, 'x')), isTrue);
    expect(filter.shouldLog(LogEvent(Level.error, 'x')), isTrue);
  });
}
