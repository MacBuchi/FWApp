# Mitmachen an der FWApp

Danke fürs Interesse! Das Projekt wird von einer kleinen Freiwilligen
Feuerwehr getragen – Beiträge sind willkommen, solange sie die
Kernentscheidungen respektieren (siehe unten).

## Entwicklungs-Setup

- Flutter 3.41.x (stable), Dart ≥ 3.11
- Java 17 für Android-Builds (neuere JDKs werden vom Flutter-Gradle-Plugin
  nicht unterstützt): `flutter config --jdk-dir=<pfad-zu-jdk-17>`
- Docker + [Supabase CLI](https://supabase.com/docs/guides/cli), falls du am
  Sync arbeitest (sonst optional)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
```

## Die drei wichtigsten Regeln

1. **Codegen committen:** Nach jeder Änderung an `@riverpod`-, `@freezed`-
   oder Drift-annotierten Dateien `dart run build_runner build
   --delete-conflicting-outputs` ausführen und die `.g.dart`/`.freezed.dart`
   mitcommitten. Die CI schlägt sonst fehl („Generated files are stale“).
2. **Kein Direkt-Push auf `main`:** Feature-Branch → Pull Request → alle
   CI-Checks grün („Analyze & Test“, „Build Android APK“, „Build Web“) →
   Squash-Merge.
3. **Coverage-Gate:** Die Logik-Schichten (`data`/`domain`/`core`) müssen
   ≥ 65 % Testabdeckung behalten (`dart run tool/check_coverage.dart --min 65`
   nach `flutter test --coverage`).

## Tests

```bash
flutter test                      # Unit- + Widget-Tests
flutter test --coverage           # mit Coverage für das Gate
```

Der Sync-E2E-Test überspringt sich selbst, wenn kein lokaler Supabase-Stack
läuft. Für den vollen Durchlauf:

```bash
supabase start
bash tool/setup_local_supabase.sh   # Testnutzer admin@fw.local / member@fw.local
flutter test
```

## Architektur-Leitplanken

Diese Entscheidungen sind bewusst getroffen – PRs, die sie aufweichen,
werden nicht gemerged:

- **Local-first:** Drift/SQLite ist der Laufzeitspeicher; die App muss ohne
  Netz vollständig funktionieren (Einsatz!).
- **Single-Writer-Sync:** Nur Admins veröffentlichen komplette Snapshots mit
  Versionszähler; Mitglieder lesen. Keine CRDTs, keine Offline-Write-Queues,
  keine Konfliktauflösung.
- **Prüf- und Inventurdaten** hängen an physischen Geräteinstanzen
  (`EquipmentInstances`) bzw. Snapshots – nie an `EquipmentAssignments`
  (die überleben Re-Importe nicht).
- **Fälligkeiten** (`dueAt`) werden denormalisiert gespeichert, nie in
  Queries berechnet.
- Feature-first-Struktur unter `lib/features/`, Abhängigkeitsrichtung
  `presentation → domain ← data`.

## Releases

Ein Release entsteht automatisch, wenn ein PR mit erhöhter `version:` in
`pubspec.yaml` auf `main` gemerged wird (Tag `vX.Y.Z` + signiertes APK,
siehe [.github/workflows/release.yml](.github/workflows/release.yml)).
PRs ohne Version-Bump (Doku, Refactoring) erzeugen bewusst kein Release.
Den Version-Bump macht der Maintainer beim Merge-Zeitpunkt – in eigenen PRs
bitte die Version **nicht** anfassen, sofern nicht abgesprochen.

## Sprache

Code, Bezeichner und Commit-Titel: Englisch oder Deutsch ist beides im
Bestand – bitte im jeweiligen Umfeld konsistent bleiben. UI-Texte und
Doku: Deutsch (Zielgruppe sind deutsche Feuerwehren).
