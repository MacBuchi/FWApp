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
flutter test integration_test -d <gerät>   # Geräte-Smoke-Test (echtes Gerät/Emulator)
```

Der Geräte-Smoke-Test (`integration_test/`) startet die echte App auf einem
angeschlossenen Gerät und prüft Navigation + Sync-Einstellungen programmatisch —
Pflicht vor Releases mit Android-spezifischen Änderungen (Manifest, Permissions,
Plugins): Nur so fallen Fehler auf, die Debug-Builds verschleiern (siehe
v1.3.1: fehlende INTERNET-Permission im Release-Manifest).

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

### Schichtung je Feature

Nicht jedes Feature trägt die volle Schichtung – das ist Absicht, nicht
Wildwuchs:

- **Synchronisierte Kern-Entitäten** (`vehicle`, `equipment`, `compartment`,
  `assignment`, `inspection`): volle Schichtung mit Entity,
  Repository-Interface (`domain`) und Drift-Implementierung (`data`).
- **Rein lokale/ephemere Features** (`home`-Dashboard, `inventory`,
  `operation`, `game`): Provider dürfen direkt auf `appDatabaseProvider`/DAOs
  zugreifen; die Entscheidung steht als Begründung im Kopf der
  Provider-Datei.
- **`import`** nutzt Services (`ImportService`, `EquipmentMatcher`) statt
  Repositories – der Wizard ist ein Ablauf, keine Entität.

Neue Features ordnen sich vor dem ersten Commit einer der Kategorien zu.

### Provider: Codegen ist der Standard

Neue Provider werden mit `@riverpod` (riverpod_generator) geschrieben.
Manuelle Provider sind nur zulässig mit Begründungskommentar am Dateikopf –
akzeptierte Gründe: Generator-Limitierung (z. B. kann er
supabase_flutter-Typen nicht abbilden, siehe `core/sync/sync_providers.dart`)
oder ein bewusst rein lokales Modul (siehe
`features/home/.../dashboard_providers.dart`).

### UI-State: handgeschrieben, freezed nur für Domain

Form-/Wizard-State (`VehicleFormState`, `ImportWizardState`) bleibt als
handgeschriebene immutable Klasse mit `copyWith` inkl. expliziter
`clearX`-Flags zum Nullen. freezed ist den Domain-Entities vorbehalten.
Bewusste Entscheidung: die wenigen State-Klassen rechtfertigen keinen
Codegen-Zyklus, und das Nullen von Feldern bleibt explizit lesbar.

### Fehlerbehandlung und Logging

- Geloggt wird über die zentrale Instanz `appLog`
  (`lib/core/logging/app_logger.dart`) – kein `Logger()` pro Datei.
- Leere Catch-Blöcke (`catch (_) {}`) nur mit Begründungskommentar direkt am
  Catch. Im Kernpfad (Sync, Seeder, Persistenz) werden Fehler nie stumm
  verschluckt: mindestens `appLog.w(...)`, nutzerrelevante Fälle zusätzlich
  in der UI sichtbar machen.

### Checkliste: neue Spalte/Tabelle

Das Schema wird an mehreren Stellen von Hand gemappt – bei jeder
Schema-Änderung alle Stationen abklappern:

1. Drift-Tabelle in `lib/core/database/app_database.dart` ändern,
   `schemaVersion` erhöhen, Migration ergänzen → `dart run build_runner
   build --delete-conflicting-outputs`.
2. Entity (`features/<x>/domain`, freezed) und Repository-Mapping
   (`features/<x>/data`: `_toEntity` + Companion-Aufbau) nachziehen.
3. Sync: `lib/core/sync/sync_service.dart` → `_buildPayload` **und**
   `_applySnapshot` (bei neuer Tabelle zusätzlich `kSyncedTables`).
4. Server: neue SQL-Migration unter `supabase/migrations/` anlegen und auf
   dem Server einspielen.
5. Seeder: `lib/core/database/library_seeder.dart`, falls das Feld aus den
   gebündelten JSON-Assets befüllt wird.
6. Tests: Drift-Schema-Snapshots (`test/core/database/generated/`) und
   Migrationstest aktualisieren.

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

**Keine Lokalisierung:** Es gibt bewusst kein ARB/gen-l10n-Setup – alle
UI-Texte sind hart deutsch. Die Zielgruppe ist einsprachig; ein
Übersetzungs-Layer würde nur Indirektion ohne Nutzen einführen. PRs, die
l10n-Infrastruktur einführen, bitte vorher als Issue diskutieren.
