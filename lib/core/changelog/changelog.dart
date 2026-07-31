/// changelog.dart – Liest die mitgelieferte CHANGELOG.md und macht sie in der
/// App anzeigbar (Issue #51).
///
/// Die CHANGELOG.md im Repo-Wurzelverzeichnis ist die einzige Quelle: Sie wird
/// als Asset ausgeliefert und hier geparst. Damit gibt es keinen zweiten,
/// driftenden Änderungstext im Dart-Code, und die Anzeige funktioniert offline
/// — im Feld ist das der Normalfall.
///
/// Bewusst ein eigener Mini-Parser statt eines Markdown-Pakets: Erwartet wird
/// genau das Keep-a-Changelog-Format, das die Datei selbst vorgibt, und dafür
/// ist eine Volltext-Markdown-Engine samt Abhängigkeit unverhältnismäßig.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';

/// Ein Abschnitt innerhalb einer Version, z. B. „Neu" mit seinen Punkten.
class ChangelogSection {
  final String title;
  final List<String> entries;

  const ChangelogSection({required this.title, required this.entries});
}

/// Eine Version mit Datum und ihren Abschnitten.
class ChangelogRelease {
  final String version;

  /// Datum als `YYYY-MM-DD`, oder `null`, wenn die Überschrift keins trug.
  final String? date;
  final List<ChangelogSection> sections;

  const ChangelogRelease({
    required this.version,
    required this.date,
    required this.sections,
  });
}

/// `## [1.4.8] – 2026-07-31` — Klammern und Datum sind beide optional, und als
/// Trenner sind Gedankenstrich wie Bindestrich zugelassen.
final _releaseHeading = RegExp(
  r'^##\s+\[?(?<version>[0-9]+\.[0-9]+\.[0-9]+)\]?'
  r'(?:\s*[–-]\s*(?<date>\d{4}-\d{2}-\d{2}))?\s*$',
);
final _sectionHeading = RegExp(r'^###\s+(?<title>.+?)\s*$');
final _bullet = RegExp(r'^[-*]\s+(?<text>.+)$');

/// Zerlegt den Inhalt einer CHANGELOG.md in Versionen.
///
/// Alles vor der ersten `##`-Überschrift (Vorwort, Format-Hinweis) und die
/// Link-Definitionen am Dateiende fallen weg. Rein und ohne I/O, damit der
/// Test sie direkt füttern kann.
List<ChangelogRelease> parseChangelog(String markdown) {
  final releases = <ChangelogRelease>[];

  String? version;
  String? date;
  var sections = <ChangelogSection>[];
  String? sectionTitle;
  var entries = <String>[];

  void closeSection() {
    if (sectionTitle != null && entries.isNotEmpty) {
      sections.add(ChangelogSection(title: sectionTitle!, entries: entries));
    }
    sectionTitle = null;
    entries = <String>[];
  }

  void closeRelease() {
    closeSection();
    if (version != null) {
      releases.add(ChangelogRelease(
        version: version!,
        date: date,
        sections: sections,
      ));
    }
    version = null;
    date = null;
    sections = <ChangelogSection>[];
  }

  for (final rawLine in markdown.split('\n')) {
    final line = rawLine.trimRight();

    final release = _releaseHeading.firstMatch(line);
    if (release != null) {
      closeRelease();
      version = release.namedGroup('version');
      date = release.namedGroup('date');
      continue;
    }

    // Zeilen vor der ersten Versions-Überschrift gehören zum Vorwort.
    if (version == null) continue;

    final section = _sectionHeading.firstMatch(line);
    if (section != null) {
      closeSection();
      sectionTitle = section.namedGroup('title');
      continue;
    }

    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      entries.add(bullet.namedGroup('text')!.trim());
      continue;
    }

    // Fortsetzungszeile eines umbrochenen Punktes an den letzten anhängen.
    if (line.isNotEmpty && entries.isNotEmpty && rawLine.startsWith(' ')) {
      entries[entries.length - 1] = '${entries.last} ${line.trim()}';
    }
  }
  closeRelease();

  return releases;
}

/// Lädt die als Asset mitgelieferte CHANGELOG.md und parst sie.
///
/// Schlägt das fehl, liefert der Provider eine leere Liste statt zu werfen:
/// Eine kaputte Änderungsliste darf den Einstellungs-Screen nicht sprengen.
/// Der Fehler wird protokolliert, und die UI zeigt einen Hinweis.
final changelogProvider = FutureProvider<List<ChangelogRelease>>((ref) async {
  try {
    return parseChangelog(await rootBundle.loadString('CHANGELOG.md'));
  } catch (e, s) {
    appLog.w('CHANGELOG.md konnte nicht geladen werden', error: e, stackTrace: s);
    return const <ChangelogRelease>[];
  }
});
