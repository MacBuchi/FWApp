# Mitmachen an der FWApp

Danke fürs Interesse! Das Projekt wird von einer kleinen Freiwilligen
Feuerwehr getragen – Beiträge sind willkommen, solange sie die
Kernentscheidungen respektieren (siehe unten).

Diese Datei beschreibt, **wie** man beiträgt: Setup, Regeln, Tests, PR-Weg.
Die technische Tiefe – Toolchain, Signing, In-App-Update, Secrets, bekannte
Stolperfallen – steht in [AGENTS.md](AGENTS.md), dem Arbeitsgedächtnis des
Projekts. Projektübergreifende Guidelines liegen im DocuHub unter
`/Volumes/MacStore/Programming/ProgrammingGuidelineDocuHub/`; AGENTS.md hält
fest, wo die FWApp bewusst davon abweicht.

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

## Die vier wichtigsten Regeln

1. **Codegen committen:** Nach jeder Änderung an `@riverpod`-, `@freezed`-
   oder Drift-annotierten Dateien `dart run build_runner build
   --delete-conflicting-outputs` ausführen und die `.g.dart`/`.freezed.dart`
   mitcommitten. Die CI schlägt sonst fehl („Generated files are stale“).
2. **Kein Direkt-Push auf `main`:** Feature-Branch → Pull Request → alle
   CI-Checks grün („Analyze & Test“, „Build Android APK“, „Build Web“,
   „Version Guard“) → Squash-Merge. Die vier Checks sind auf `main` als
   *Required Status Checks* hinterlegt, ein PR mit rotem CI ist also nicht
   mergebar; zusätzlich muss der Branch auf dem Stand von `main` sein.
3. **Coverage-Gate:** Die Logik-Schichten (`data`/`domain`/`core`) müssen
   ≥ 65 % Testabdeckung behalten (`dart run tool/check_coverage.dart --min 65`
   nach `flutter test --coverage`).
4. **Version-Bump bis zum Merge:** Ändert ein PR ausgelieferte Dateien
   (`lib/`, `android/`, `ios/`, `macos/`, `web/`, `assets/`, `pubspec.*`),
   muss `version:` in `pubspec.yaml` steigen — sonst legt `release.yml` kein
   Tag an und die Änderung erreicht kein Gerät. Reine Doku-, Test-, `tool/`-
   oder CI-PRs brauchen keinen Bump. Wer von außen beiträgt, lässt die
   Version in Ruhe (siehe [Releases](#releases)) — den Bump setzt die
   Maintainerin bzw. der Maintainer vor dem Merge. Genau deshalb **warnt**
   der Check „Version Guard“ im PR nur und schlägt erst auf `main` fehl.

## Git-Workflow

- Branch-Namen: `feat/<thema>`, `fix/<thema>`, `docs/`, `chore/`, `ci/`
  (im Bestand existiert auch `feature/` – neue Branches bitte mit `feat/`).
- Commit- und PR-Titel im Conventional-Commits-Stil (`feat:`, `fix:`,
  `chore:`, `docs:`, `ci:`). Der Bestand enthält deutsche Prosa-Titel;
  neue Beiträge bitte im Conventional-Format.
- Merge-Strategie: Squash. Gemergte Branches löschen.
- Der Merge wird vom Maintainer gemacht – Beiträge (auch agentengestützte)
  mergen sich nicht selbst, weil ein Merge auf `main` ein Release auslösen kann.

## Tests

```bash
flutter test                      # Unit- + Widget-Tests
flutter test --coverage           # mit Coverage für das Gate
flutter test integration_test -d <gerät>   # Geräte-Smoke-Test (echtes Gerät/Emulator)
```

Widget-Tests sind der Hebel für UI-Absicherung – Layout, Zustände und
Breakpoints lassen sich pixelfrei prüfen (`tester.getSize`/`getTopLeft`,
`tester.view.physicalSize` für Breakpoints; ein RenderFlex-Overflow lässt den
Test automatisch fehlschlagen). Screenshots/Goldens sind dafür nicht nötig.
Harness: `test/helpers/widget_harness.dart` (`buildTestApp` mit
In-Memory-Drift-DB); am Testende `endTestApp(tester)` aufrufen, sonst bleiben
Drift-Stream-Timer hängen („A Timer is still pending").

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

## Android-Release-Bausteine (nicht anfassen ohne Gerätetest)

Signierung und In-App-Update hängen an einer Handvoll Manifest- und
Gradle-Details, die zusammengehören: `INTERNET` und
`REQUEST_INSTALL_PACKAGES`, der FileProvider mit Authority
`${applicationId}.ota_update_provider`, `res/xml/filepaths.xml`, der
`<queries>`-Eintrag für VIEW/https und Core Library Desugaring. Fehlt einer
davon, fällt es **erst beim Nutzer** auf – nie im Debug-Lauf.

Die vollständige Liste mit Begründung steht in
[AGENTS.md § 7–8](AGENTS.md#7-signierung--secrets). Für Beitragende gilt vor
allem: Nach jeder Änderung an Manifest, Permissions oder Plugins ist der
Geräte-Smoke-Test Pflicht (siehe [Tests](#tests)), und der Release-Keystore
wird **nie** ausgetauscht.

## Feedback

Ein Teil der Issues hier stammt direkt aus der App: Der Feedback-Dialog
schreibt in eine Supabase-Tabelle, ein Bot macht daraus **öffentliche**
GitHub-Issues. Wer am Feedback-Weg arbeitet, muss den
Öffentlichkeits-Hinweis im Dialog erhalten – Mechanik und Fallstricke stehen
in [AGENTS.md § 9](AGENTS.md#9-in-app-feedback--github-issue).

## Releases

Ein Release entsteht automatisch, wenn ein PR mit erhöhter `version:` in
`pubspec.yaml` auf `main` gemerged wird (Tag `vX.Y.Z` + signiertes APK,
siehe [.github/workflows/release.yml](.github/workflows/release.yml)).
PRs ohne Version-Bump (Doku, Refactoring) erzeugen bewusst kein Release.
Den Version-Bump macht der Maintainer beim Merge-Zeitpunkt – in eigenen PRs
bitte die Version **nicht** anfassen, sofern nicht abgesprochen.

## Sprache

Code und Bezeichner: Englisch oder Deutsch ist beides im Bestand – bitte im
jeweiligen Umfeld konsistent bleiben. UI-Texte und Doku: Deutsch (Zielgruppe
sind deutsche Feuerwehren). **Commits, PR- und Issue-Texte: Deutsch** – eine
bewusste Abweichung von der DocuHub-Vorgabe, begründet in
[AGENTS.md § 3](AGENTS.md#code-regeln).

**Keine Lokalisierung:** Es gibt bewusst kein ARB/gen-l10n-Setup – alle
UI-Texte sind hart deutsch. Die Zielgruppe ist einsprachig; ein
Übersetzungs-Layer würde nur Indirektion ohne Nutzen einführen. PRs, die
l10n-Infrastruktur einführen, bitte vorher als Issue diskutieren.
