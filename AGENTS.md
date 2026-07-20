# AGENTS.md – FWApp

Leitplanken für Menschen und Agenten, die an der FWApp arbeiten. Basis ist das
AGENTS-Template des DocuHub unter
`/Volumes/MacStore/Programming/ProgrammingGuidelineDocuHub/` (`templates/`,
Tiefe in `guidelines/`); hier stehen die für dieses Projekt beantworteten
Entscheidungen und die bewussten Abweichungen.

Beitragsregeln für Außenstehende stehen in [CONTRIBUTING.md](CONTRIBUTING.md) —
diese Datei hier ist das technische Arbeitsgedächtnis, nicht die Einladung zum
Mitmachen. Widersprechen sich beide, gilt CONTRIBUTING.md für alles, was einen
PR betrifft.

Diese Datei ersetzt `.github/copilot-instructions.md`. Die stammte aus der
Aufbauphase und beschrieb, wie die App zu *bauen* wäre — von Rollen,
In-App-Update, Feedback-Bot, Release-Pipeline und Branch Protection wusste sie
nichts. Wer dort nachschlagen will: `git show 6dc6f5c`. Die Agent-Definition
unter `.github/agents/` bleibt bestehen, sie beschreibt eine Testrolle und
keine Projektregeln.

## 1. Projekt

**FWApp** – Lern- und Verwaltungs-App für eine Freiwillige Feuerwehr: Fahrzeuge,
Beladung, Geräteprüfung, Inventur und Lernspiele, offline-first im Einsatz.
Zielplattformen: **Android** (Hauptziel, Verteilung als APK ohne Play Store) und
**Web** (PWA, vor allem für Admins). iOS/macOS sind nicht im Blick.

Bundle-ID: **`com.feuerwehr.fwapp`**

> ⚠️ Abweichung vom Template (`de.macbuchi.<app>`): Die ID ist seit v1.0.0 im
> Umlauf. Ändern würde die Update-Kette aller Installationen zerreißen — sie
> bleibt, wie sie ist.

### Architektur-Leitplanken (nicht verhandelbar)

- **Local-first:** Drift/SQLite ist der Laufzeitspeicher; die App muss ohne Netz
  vollständig funktionieren (Einsatz!).
- **Single-Writer-Sync:** Nur Admins veröffentlichen komplette Snapshots mit
  Versionszähler, Mitglieder lesen. Keine CRDTs, keine Offline-Write-Queues,
  keine Konfliktauflösung.
- **Sicherheit liegt in Supabase-RLS**, nie im Client. Router-Guards und
  ausgeblendete UI sind Komfort, nicht die Schutzschicht.
- **Prüf- und Inventurdaten** hängen an physischen Geräteinstanzen
  (`EquipmentInstances`) bzw. Snapshots – nie an `EquipmentAssignments`, die
  überleben Re-Importe nicht.
- **Fälligkeiten** (`dueAt`) werden denormalisiert gespeichert, nie in Queries
  berechnet.

## 2. Toolchain

```text
Flutter SDK: /Volumes/MacStore/Programming/Flutter/SDK/flutter   (PATH exportieren!)
Flutter-Version: 3.41.2  — identisch in ci.yml und release.yml gepinnt
Java 17 für Android-Builds (neuere JDKs kann das Flutter-Gradle-Plugin nicht)
```

Bei lokalem Flutter-Upgrade **immer beide Workflows nachziehen** – CI und lokal
müssen dieselbe Version fahren.

```bash
flutter pub get
flutter analyze
flutter test                                                # Unit + Widget
flutter test --coverage                                     # für das Gate
dart run build_runner build --delete-conflicting-outputs    # Pflicht, siehe unten
flutter test integration_test -d <gerät>                    # Geräte-Smoke-Test
```

## 3. Architektur & Konventionen

- **Struktur:** Feature-first unter `lib/features/<x>/{data,domain,presentation}`,
  Abhängigkeitsrichtung `presentation → domain ← data`. Nicht jedes Feature trägt
  die volle Schichtung — welche Kategorie was bekommt, steht in
  [CONTRIBUTING.md](CONTRIBUTING.md#schichtung-je-feature).
- **State Management:** **Riverpod 3 mit Codegen** (`@riverpod`). Manuelle
  Provider nur mit Begründungskommentar am Dateikopf.
- **Persistenz:** **Drift/SQLite** lokal (aktuell `schemaVersion = 4`),
  **Supabase** als zentrale DB mit Snapshot-Sync und RLS.
- **Navigation:** **go_router**, nie mit imperativem `Navigator` mischen.
  Edit-/Admin-Routen zusätzlich per `guardRedirect` in
  [app_router.dart](lib/core/router/app_router.dart) gegen Deep-Links gesichert.

### Code-Regeln

- **Sprache:** Code und Bezeichner Englisch oder Deutsch (der Bestand hat beides —
  im jeweiligen Umfeld konsistent bleiben) · UI-Strings Deutsch ·
  **GitHub (Commits, PRs, Issues) Deutsch**.

  > ⚠️ Bewusste Abweichung vom Template, das Englisch vorgibt. Die Historie,
  > alle Issues und die Feedback-Issues aus der App sind deutsch; ein
  > Sprachwechsel mitten im Bestand bringt keinen Gewinn. Zielgruppe und
  > Maintainer sind deutschsprachig.
- **Business-Logik in Services**, nicht in Providern oder Widgets.
- **`mounted` / `context.mounted` nach jedem `await`** prüfen.
- **`catch (_) {}` nur mit Begründungskommentar, nie im Kernpfad** (Sync, Seeder,
  Persistenz): mindestens `appLog.w(...)`, nutzerrelevante Fälle zusätzlich in
  der UI sichtbar machen.
- **Zweitverwendung = Extraktion:** ein Widget/Helper, der in einer zweiten Datei
  gebraucht wird, wandert nach `core/widgets/` bzw. `core/utils/` – nie kopieren.
- Datei-Header: `/// datei.dart – Zweck`.
- Nicht offensichtliche Entscheidungen im Code kommentieren, gern mit
  Issue-Referenz.

**Codegen ist Pflicht vor jedem Commit:** Nach Änderungen an `@riverpod`-,
`@freezed`- oder Drift-annotierten Dateien `dart run build_runner build
--delete-conflicting-outputs` laufen lassen und die `.g.dart`/`.freezed.dart`
mitcommitten — auch bei reinen Methodenbody-Änderungen in `@riverpod`-Dateien
(der Hash ändert sich). Die CI prüft das per `git diff --exit-code`.

### Fehler-Handler und Logging

`lib/main.dart` verdrahtet `FlutterError.onError` und
`PlatformDispatcher.instance.onError` auf `appLog`. Geloggt wird ausschließlich
über die zentrale Instanz `appLog`
([core/logging/app_logger.dart](lib/core/logging/app_logger.dart)) – kein
`Logger()` pro Datei.

## 4. Git- und PR-Workflow

- Default-Branch **`main`**, geschützt. **Kein direkter Push.**
- Feature-Branch → PR → alle Pflicht-Checks grün → **Squash-Merge**.
- Branch-Namen: `feat/`, `fix/`, `chore/`, `docs/`, `ci/`, `refactor/`
  (im Bestand existiert auch `feature/`).
- **Conventional Commits** für Commit- und PR-Titel (`feat:`, `fix:`, `chore:`,
  `ci:`, `docs:`, `test:`, `refactor:`) – auf Deutsch formuliert. Der Bestand
  enthält deutsche Prosa-Titel; neue Beiträge nutzen das Conventional-Format.
- 0 Approvals nötig (Solo-Maintainer), aber PR-Pflicht und grüne Checks.
- ⚠️ **Der Agent merged nicht selbst** – Merge auf `main` löst ein Release aus,
  das macht der Maintainer. (Der Claude-Code-Classifier blockiert `gh pr merge`
  ohnehin; das ist Absicht, kein Fehler, und wird nicht umgangen.)
- `strict: true` ist aktiv: Der Branch muss auf `main`-Stand sein, vor dem Merge
  also ggf. „Update branch".

## 5. Release-Mechanik

**Die Version in `pubspec.yaml` ist die einzige Quelle der Wahrheit.** Kein
manuelles Taggen.

1. Der PR, der eine ausgelieferte Änderung abschließt, **bumpt die Version**
   (beide Teile, z. B. `1.4.2+10` → `1.4.3+11`).
2. Merge auf `main` mit ungetaggter Version → [release.yml](.github/workflows/release.yml)
   erzeugt Tag `vX.Y.Z`, baut das signierte APK und legt das GitHub-Release an.
3. Ohne Bump gibt es kein Release. **Version Guard** warnt im PR und **failt auf
   `main`**.
4. Ausgelieferte Pfade sind `lib/ android/ ios/ macos/ web/ assets/ pubspec.*`;
   alles andere (Doku, Tests, `tool/`, `.github/`, `supabase/`) ist ausgenommen.

Den Bump setzt der Maintainer bis zum Merge — externe Beiträge fassen die
Version nicht an. Genau deshalb warnt der Guard im PR nur.

## 6. Workflows und Branch Protection

| Workflow | Inhalt |
| --- | --- |
| `ci.yml` → **Analyze & Test** | `flutter analyze`, Codegen-Staleness-Guard, Tests gegen lokalen Supabase-Stack, Coverage-Gate ≥ 65 % |
| `ci.yml` → **Build Web** / **Build Android APK** | Release-Builds als Artefakt |
| `ci.yml` → **Version Guard** | pubspec-Version vs. Vergleichsbasis; Warnung im PR, Fehler auf `main` |
| `release.yml` | Auto-Tag aus pubspec, signiertes APK, `generate_release_notes: true`, Secret-Preflight mit `exit 1` |
| `feedback.yml` | Cron alle 6 h: Supabase-Tabelle `feedback` → GitHub-Issues |

Beide Workflows haben `concurrency`: CI bricht überholte Feature-Branch-Läufe ab
(`main` ausgenommen), **Release reiht sich auf** (`cancel-in-progress: false`) —
ein abgebrochener Release-Lauf hinterließe ein Tag ohne APK.

**Branch Protection auf `main` (Ist-Stand):** Require PR · Required Checks
`Analyze & Test`, `Build Web`, `Build Android APK`, `Version Guard` ·
`strict: true` · Force-Push und Löschen blockiert · `delete_branch_on_merge: true`.
`enforce_admins` ist bewusst **aus**, damit der Maintainer im Notfall an `main`
kommt.

⚠️ **`GITHUB_TOKEN`-Regel:** Ein mit `GITHUB_TOKEN` ausgelöster Vorgang triggert
**keine** Folge-Workflows. Gewollt beim Tag-Push in `release.yml` (kein
Doppel-Lauf) — Falle, wenn irgendwann ein Bot-Issue eine Triage anstoßen soll.

## 7. Signierung & Secrets

- **Ein Keystore für immer:** `docs/private/fwapp-release.jks` +
  `fwapp-release-keystore.properties` (gitignored, Backup Pflicht). Verlust =
  Update-Kette aller Installationen dauerhaft kaputt.
- CI schreibt Keystore und `key.properties` aus Secrets und **bricht hart ab,
  wenn eines der vier Signing-Secrets fehlt** — nie still debug-signieren.
- Actions-Secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`, `FWAPP_SUPABASE_URL`,
  `FWAPP_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
- Server-URL und Anon-Key stecken bewusst im öffentlichen APK (clientseitig
  öffentlich, Zugriff schützt RLS). Lokal liegen sie in
  `config/fwapp.local.json` (gitignored).
- Instanzdetails (IPs, VM-IDs) gehören nach `docs/private/` — **nie** in die
  öffentliche Doku, dort nur Platzhalter.
- APK-Signatur prüfen mit `apksigner`, **nicht** `keytool -jarfile` (kein
  v1-Signing mehr).

## 8. In-App-Update

**Aktiv** (Verteilung läuft ohne Play Store). Der Check ist **tokenlos** gegen
`releases/latest` des öffentlichen Repos, Installation über `ota_update`,
Banner auf dem Start-Dashboard.

⚠️ Diese Android-Bausteine gehören zusammen — fehlt einer, fällt es **erst beim
Nutzer** auf, nie im Debug-Lauf:

- `INTERNET` **und** `REQUEST_INSTALL_PACKAGES` als Permissions
  (Release-Manifest braucht `INTERNET` explizit — Debug mergt sie automatisch,
  siehe v1.3.1)
- FileProvider mit Authority `${applicationId}.ota_update_provider`
- `res/xml/filepaths.xml` mit `<files-path name="ota_update" path="ota_update/"/>`
- `<queries>`-Eintrag für `VIEW`/`https` — sonst sieht die App unter Android 11+
  keinen Browser und der Fallback „Im Browser laden" scheitert still (Issue #27)
- Core Library Desugaring in `build.gradle.kts` (`desugar_jdk_libs`)

## 9. In-App-Feedback → GitHub-Issue

Weg: **DB + Bot-Workflow.** Dialog (Dashboard-Banner und „Mehr") schreibt in die
Supabase-Tabelle `feedback`; [tool/feedback_bot.py](tool/feedback_bot.py) macht
daraus öffentliche Issues und stempelt jede Zeile sofort (`processed_at`), damit
ein Abbruch keine Duplikate erzeugt.

- Der Text erscheint **öffentlich** – der Hinweis im Dialog muss erhalten bleiben.
- Banner-Dismiss nur sitzungsweit, kein Persistieren.
- ⚠️ Cloudflare Bot Fight Mode blockt den UA `Python-urllib/3.x` an der Edge mit
  403. Jeder Skript-Zugriff aufs öffentliche Gateway braucht einen eigenen
  User-Agent (der Bot setzt `fwapp-feedback-bot/1.0`).

## 10. Testen

**Pflicht nach jeder Änderung:** `flutter analyze` + `flutter test`.

- **Harness:** [test/helpers/widget_harness.dart](test/helpers/widget_harness.dart)
  (`buildTestApp` mit In-Memory-Drift-DB). Am Testende `endTestApp(tester)`
  aufrufen, sonst bleiben Drift-Stream-Timer hängen („A Timer is still pending").
- **Coverage-Gate:** Logik-Schichten ≥ 65 % (`dart run tool/check_coverage.dart
  --min 65`). Achtung: Coverage zählt eine Datei erst, wenn ein Test sie
  importiert — ein neuer Test auf bisher untesteten Code kann das Gate kippen.
- **Geräte-Smoke-Test** ([integration_test/](integration_test/)) ist Pflicht vor
  Releases mit Android-spezifischen Änderungen (Manifest, Permissions, Plugins).
  Er nutzt `waitFor()` und `ensureVisible()` und listet bei Fehlschlägen die
  sichtbaren Texte auf — siehe die Stolperfallen unten.
- **Migrationstests** für Drift ([test/core/database/migration_test.dart](test/core/database/migration_test.dart))
  samt Schema-Snapshots unter `test/core/database/generated/`.
- Kein Netzwerk in Tests. Der Sync-E2E-Test überspringt sich ohne lokalen
  Supabase-Stack selbst; in CI läuft der Stack, damit die Coverage stimmt.
- Keine Golden-Tests im Bestand (kein `CustomPainter`-Bedarf bisher).

> **Offen:** Das Template fordert ⭐ *Konfigurations-Regressionstests* — Manifest,
> FileProvider-Authority, `filepaths.xml`, Desugaring als gewöhnlicher Dart-Test,
> der die Dateien liest. FWApp prüft den `<queries>`-Eintrag bisher nur im
> Geräte-Smoke-Test, der nicht in CI läuft. Ein solcher Test hätte Issue #27 in
> CI gefangen.

## 11. Weitere Basis-Themen

- **Lints:** aktuell nur `flutter_lints`. *Offen:* Das Template empfiehlt
  zusätzlich `strict-casts`, `strict-raw-types`, `unawaited_futures`,
  `require_trailing_commas` — im Bestand noch nicht aktiviert.
- **Dependencies:** Versionen gepinnt (`^x.y.z`), **nie `any`**.
- **Theming:** ein Seed-Farbwert (`#C62828`) in
  [core/theme/app_theme.dart](lib/core/theme/app_theme.dart) speist
  `ColorScheme.fromSeed`; Screens nutzen `Theme.of(context)`. Das Icon zieht
  seine Farbe aus derselben Konstante.

  > ⚠️ Abweichung: Es gibt **keine** `AppColors`/`AppSpacing`-Token-Klassen wie im
  > Template. Für die Projektgröße reicht das Theme; eine Umstellung wäre reine
  > Churn.
- **Design folgt der Systemeinstellung** (System/Hell/Dunkel), gespeichert als
  `theme_mode`-Pref.
- **Keine Lokalisierung:** bewusst kein ARB/gen-l10n. Die Zielgruppe ist
  einsprachig; ein Übersetzungs-Layer wäre Indirektion ohne Nutzen.
- **Kein CHANGELOG.md und keine Issue-Templates** im Repo. Release-Notes
  entstehen automatisch (`generate_release_notes`), Feedback-Issues kommen aus
  der App.
- **Doku bei Refactorings mitziehen** – eine veraltete AGENTS.md kostet die
  nächste Session mehr als das Update jetzt.

## 12. Bekannte Eigenheiten und Stolperfallen

- ⚠️ **Das Pixel XL im Testrig liegt quer** – `tester.view` meldet 683 × 411 dp.
  In dem flachen Fenster rutschen Listeneinträge unter die `NavigationBar`;
  `tester.tap(find.text(...))` trifft dann die Leiste, und der Test wandert
  wortlos in einen anderen Tab. Symptom ist eine ganz andere fehlschlagende
  Sichtprüfung. Der hochkante Emulator verdeckt das komplett.
- ⚠️ **`pumpAndSettle` reicht auf echten Geräten nicht:** Solange asynchrone
  Provider auf I/O warten, steht kein Frame an – `pumpAndSettle` kehrt zurück,
  während noch „Lade…" auf dem Schirm steht. Dafür gibt es `waitFor()`.
- ⚠️ **`dart format` nicht über Bestandsdateien laufen lassen** – das Repo ist
  alt formatiert, der Tall-Style erzeugt massive Churn.
- ⚠️ **Riverpod 3:** `StateProvider` lebt in `flutter_riverpod/legacy.dart`,
  `AsyncValue.valueOrNull` heißt jetzt `.value`, und `WidgetRef` ist **kein**
  `Ref` – Helfern den Client als Parameter geben statt `Ref`.
- ⚠️ **Drift `replace()`** wirft bei partiellen Companions → `patchEquipment` /
  `write()` nutzen.
- ⚠️ **`rootBundle`-Loads in `FutureBuilder`** hängen in Widget-Tests (fake async).
- ⚠️ **AlertDialogs mit 2+ Feldern** brauchen `SingleChildScrollView` im
  `content` – sonst überlappen auf kleinen Screens Buttons und zweites Feld.
- **Die VM hat kein IPv4-Internet** (Fritz!Box beantwortet den ARP der VM-MAC
  nicht, IPv6 geht). Deshalb der Offline-Dispatcher unter
  `supabase/functions/main/` – Edge Functions dürfen **keine** externen Imports
  (`jsr:`/`npm:`) ziehen, sonst 502 beim Kaltstart.
- **Der Demo-Datenbestand ist fiktiv.** Die echte AB-G-Beladeliste ist bewusst
  aus dem Arbeitsstand entfernt; der Seeder legt Katalog **vor** Fahrzeug an.

## 13. Zurückgestellt — bewusst nicht jetzt

Diese Punkte sind analysiert und entschieden, aber absichtlich vertagt. Sie
gehören **nicht** in den nächsten PR, und sie sollen auch nicht in jeder
Session neu aufgerollt werden. Wer sie anfassen will, holt vorher Marcus'
Zustimmung ein.

### Crash-Reporting (Issue #34)

**Entschieden:** Selbst hosten, nicht sentry.io. **Vertagt:** ja, bis auf
Weiteres.

Zwei Randbedingungen, die vor dem Start geklärt sein müssen:

- **Sentry `self-hosted` ist zu groß für VM 104.** Offiziell 4 Kerne und
  16 GB RAM, rund 40 Container (Kafka, ClickHouse, Snuba, Relay, Worker).
  Neben dem Supabase-Stack ist das keine Zusatzinstallation, sondern eine
  eigene VM. Die schlankere Alternative heißt **GlitchTip**: implementiert die
  Sentry-Ingest-API, läuft also mit dem unveränderten `sentry_flutter`-SDK
  (nur die DSN zeigt woanders hin), braucht aber nur Postgres, Redis und zwei
  Django-Prozesse. Postgres ist ohnehin da.
- **Ohne IPv4 auf der VM geht gar nichts.** Neue Container-Images lassen sich
  nicht ziehen, solange die Fritz!Box den ARP der VM-MAC nicht beantwortet —
  derselbe offene Punkt, der auch den Brevo-Testversand blockiert.

Vorher zu erledigen: **Issue #39** (Release-Builds loggen gar nichts). Solange
die lokale Logging-Kette im Release stumm ist, verdeckt ein Crash-Backend nur
die Ursache.

### Mindestversions-Check (Issue #35)

**Vertagt**, obwohl es das Issue mit dem größten Schadenspotenzial ist — es ist
ein Entwurf, kein Fix, und braucht eine Server-Migration plus eine Entscheidung
darüber, ab wann eine Version zu alt ist.

Was die Analyse ergeben hat, damit es niemand zweimal herausfindet:

- Der gefährliche Pfad ist **nicht** der Pull, sondern `publish()`. Ein
  Gerätewart auf altem Stand kann per `publish_snapshot` einen Snapshot
  hochladen, der aus seiner lokalen DB gebaut ist; `jsonb_populate_recordset`
  setzt fehlende Keys kommentarlos auf NULL. Eine neu hinzugekommene
  Sync-Spalte wäre danach für die ganze Wehr leer — ohne Fehlermeldung.
  `expected_version` schützt nur gegen parallele Publishes.
- Die Server-Tabelle heißt **`dataset_meta`** (eine Zeile, `check (id = 1)`),
  nicht `sync_meta` — das ist die lokale Drift-Tabelle. Der Pull liest
  `dataset_meta` ohnehin schon, ein `minimum_supported_version` dort wäre eine
  Ein-Zeilen-Migration.
- Ein Gate darf **nicht** an `updateInfoProvider` hängen: Der liefert auf Web
  und iOS grundsätzlich `null`. Ausgerechnet die Web-App ist aber der Weg, über
  den Admins publizieren.
- `isNewerVersion` behandelt Pre-Release-Suffixe falsch (`1.5.1-rc1` wird zu
  `[1,5,0]`). Aktuell folgenlos, weil das Projekt nur `MAJOR.MINOR.PATCH+BUILD`
  verwendet und `release.yml` den Tag auf Ziffern und Punkte filtert — vor
  einer Nutzung im Gate aber zu härten.
- Local-first bleibt unangetastet: Ein Gate darf den Sync sperren, nie die App.
