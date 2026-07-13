/// check_coverage.dart – CI gate: enforces a minimum line-coverage threshold
/// on the logic layers (lib/core + data/ + domain/), excluding generated code
/// and UI (presentation/). Usage:
///   dart run tool/check_coverage.dart [--min 65] [--lcov coverage/lcov.info]
library;
import 'dart:io';

void main(List<String> args) {
  var minPercent = 65.0;
  var lcovPath = 'coverage/lcov.info';
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--min') minPercent = double.parse(args[i + 1]);
    if (args[i] == '--lcov') lcovPath = args[i + 1];
  }

  final lcov = File(lcovPath);
  if (!lcov.existsSync()) {
    stderr.writeln('FEHLER: $lcovPath nicht gefunden. '
        'Vorher `flutter test --coverage` ausführen.');
    exit(2);
  }

  bool isLogicLayer(String path) {
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) {
      return false;
    }
    if (path.contains('/presentation/')) return false;
    return path.startsWith('lib/core/') ||
        path.contains('/data/') ||
        path.contains('/domain/');
  }

  var found = 0, hit = 0;
  String? current;
  var include = false;
  final perFile = <String, (int, int)>{};
  var fileFound = 0, fileHit = 0;

  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3);
      include = isLogicLayer(current);
      fileFound = 0;
      fileHit = 0;
    } else if (line.startsWith('LF:')) {
      fileFound = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      fileHit = int.parse(line.substring(3));
    } else if (line == 'end_of_record' && include && current != null) {
      found += fileFound;
      hit += fileHit;
      perFile[current] = (fileHit, fileFound);
    }
  }

  if (found == 0) {
    stderr.writeln('FEHLER: keine Logik-Schicht-Dateien im Coverage-Report.');
    exit(2);
  }

  final percent = 100.0 * hit / found;
  final sorted = perFile.entries.toList()
    ..sort((a, b) =>
        (a.value.$1 / a.value.$2).compareTo(b.value.$1 / b.value.$2));

  stdout.writeln('Logik-Schichten-Coverage: $hit/$found Zeilen = '
      '${percent.toStringAsFixed(1)}% (Schwellwert: $minPercent%)');
  stdout.writeln('Schwächste Dateien:');
  for (final e in sorted.take(5)) {
    final p = 100.0 * e.value.$1 / e.value.$2;
    stdout.writeln('  ${p.toStringAsFixed(1).padLeft(5)}%  ${e.key}');
  }

  if (percent < minPercent) {
    stderr.writeln('FEHLGESCHLAGEN: Coverage ${percent.toStringAsFixed(1)}% '
        'liegt unter dem Schwellwert von $minPercent%.');
    exit(1);
  }
  stdout.writeln('OK.');
}
