/// changelog_test.dart – Parser für die mitgelieferte CHANGELOG.md (Issue #51).
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/changelog/changelog.dart';

void main() {
  group('parseChangelog', () {
    test('liest Version, Datum und Abschnitte', () {
      final releases = parseChangelog('''
# Änderungen

Vorwort, das nicht im Ergebnis auftauchen darf.

## [1.2.0] – 2026-07-17

### Neu

- Erster Punkt
- Zweiter Punkt

### Behoben

- Dritter Punkt
''');

      expect(releases, hasLength(1));
      final r = releases.single;
      expect(r.version, '1.2.0');
      expect(r.date, '2026-07-17');
      expect(r.sections.map((s) => s.title), ['Neu', 'Behoben']);
      expect(r.sections.first.entries, ['Erster Punkt', 'Zweiter Punkt']);
      expect(r.sections.last.entries, ['Dritter Punkt']);
    });

    test('hält die Reihenfolge der Versionen aus der Datei ein', () {
      final releases = parseChangelog('''
## [2.0.0] – 2026-01-02

### Neu

- neu

## [1.0.0] – 2026-01-01

### Neu

- alt
''');
      expect(releases.map((r) => r.version), ['2.0.0', '1.0.0']);
    });

    test('fügt umbrochene Punkte wieder zusammen', () {
      final releases = parseChangelog('''
## [1.0.0] – 2026-01-01

### Neu

- Ein Punkt, der über
  zwei Zeilen läuft
- Ein kurzer
''');
      expect(releases.single.sections.single.entries, [
        'Ein Punkt, der über zwei Zeilen läuft',
        'Ein kurzer',
      ]);
    });

    test('akzeptiert Überschriften ohne Klammern, Datum und Bindestrich-Trenner',
        () {
      final releases = parseChangelog('''
## 1.0.0 - 2026-01-01

### Neu

- mit Bindestrich

## 0.9.0

### Neu

- ohne Datum
''');
      expect(releases.map((r) => r.version), ['1.0.0', '0.9.0']);
      expect(releases.first.date, '2026-01-01');
      expect(releases.last.date, isNull);
    });

    test('ignoriert Link-Definitionen und leere Abschnitte', () {
      final releases = parseChangelog('''
## [1.0.0] – 2026-01-01

### Neu

- etwas

### Leer

[1.0.0]: https://example.com/compare/v0.9.0...v1.0.0
''');
      expect(releases.single.sections.map((s) => s.title), ['Neu']);
    });

    test('liefert eine leere Liste für Text ohne Versionen', () {
      expect(parseChangelog('Nur Prosa, keine Überschrift.'), isEmpty);
      expect(parseChangelog(''), isEmpty);
    });
  });

  group('die ausgelieferte CHANGELOG.md', () {
    // Die Datei ist Asset und Anzeige-Quelle zugleich (Issue #51). Ein Tippfehler
    // im Format fällt sonst erst auf dem Gerät auf, wo der Screen leer bleibt.
    late final List<ChangelogRelease> releases =
        parseChangelog(File('CHANGELOG.md').readAsStringSync());

    test('ist parsebar und nicht leer', () {
      expect(releases, isNotEmpty);
    });

    test('trägt für jede Version ein Datum und mindestens einen Punkt', () {
      for (final r in releases) {
        expect(r.date, isNotNull, reason: 'Version ${r.version} ohne Datum');
        expect(r.sections, isNotEmpty,
            reason: 'Version ${r.version} ohne Abschnitte');
        for (final s in r.sections) {
          expect(s.entries, isNotEmpty,
              reason: 'Version ${r.version}, Abschnitt "${s.title}" ist leer');
        }
      }
    });

    test('enthält die Version aus pubspec.yaml als obersten Eintrag', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
              multiLine: true)
          .firstMatch(pubspec)
          ?.group(1);
      expect(version, isNotNull, reason: 'pubspec.yaml ohne version:');
      expect(releases.first.version, version,
          reason: 'Der oberste CHANGELOG-Eintrag muss die Version aus '
              'pubspec.yaml sein — sonst liefert ein Release Notizen für '
              'eine Version aus, die es nicht gibt.');
    });

    test('nennt jede Version genau einmal', () {
      final versions = releases.map((r) => r.version).toList();
      expect(versions.toSet(), hasLength(versions.length));
    });
  });
}
