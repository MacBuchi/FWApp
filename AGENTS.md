# FWApp — Arbeitsregeln

Lern- und Verwaltungs-App für eine Freiwillige Feuerwehr: Fahrzeuge, Beladung,
Geräteprüfung, Inventur, Import-Assistent, Einsatzassistent und Lernspiele.
**Offline-first im Einsatz.** Drift/SQLite als Laufzeitspeicher, Supabase als
zentrale DB mit Snapshot-Sync und RLS, **Riverpod 3 mit Codegen**, go_router,
freezed, Material 3. Zielplattformen: **Android** (Hauptziel, APK-Verteilung
ohne Play Store) und **Web** (PWA, für Admins und als iPhone-Zwischenlösung).
iOS/macOS sind nicht im Blick.

Bundle-ID: **`com.feuerwehr.fwapp`**

> ⚠️ Abweichung von der Portfolio-Konvention `de.macbuchi.<app>`: Die ID ist
> seit v1.0.0 im Umlauf. Ändern würde die Update-Kette aller Installationen
> zerreißen — sie bleibt, wie sie ist.

Projektübergreifende Guidelines (Architektur, State, Datenhaltung, Navigation,
Theming, Fehlerbehandlung, Observability, Testing, CI, Signing,
In-App-Update/-Feedback) liegen im DocuHub:
`/Volumes/MacStore/Programming/ProgrammingGuidelineDocuHub/`. **Diese Datei
beschreibt nur, was für FWApp davon abweicht oder zusätzlich gilt.**

> Bis 2026-07-31 wiederholte diese Datei den halben DocuHub — Toolchain,
> Release-Mechanik, Signing, In-App-Update. Genau das ist der Motor für Drift:
> Eine Regel ändert sich im Hub und veraltet hier still. Wer etwas ergänzt,
> prüft zuerst, ob es in eine Guideline gehört statt hierher.

Beitragsregeln für Außenstehende stehen in [CONTRIBUTING.md](CONTRIBUTING.md).
Widersprechen sich beide, gilt CONTRIBUTING.md für alles, was einen PR betrifft.

## Architektur-Leitplanken (nicht verhandelbar)

- **Local-first:** Die App muss ohne Netz vollständig funktionieren (Einsatz!).
  Kein Feature darf den lokalen Betrieb an eine Serververbindung binden.
- **Single-Writer-Sync:** Editoren (Admin/Gerätewart) veröffentlichen komplette
  Snapshots mit Versionszähler, Mitglieder lesen. Keine CRDTs, keine
  Offline-Write-Queues, keine Konfliktauflösung.
- **Sicherheit liegt in Supabase-RLS**, nie im Client. Router-Guards und
  ausgeblendete UI sind Komfort, nicht die Schutzschicht.
- **Prüf- und Inventurdaten** hängen an physischen Geräteinstanzen
  (`EquipmentInstances`) bzw. an Snapshots — nie an `EquipmentAssignments`,
  die überleben Re-Importe nicht.
- **Fälligkeiten** (`dueAt`) werden denormalisiert gespeichert, nie in Queries
  berechnet.

## Workflow

Es gilt die GitHub-Guideline des DocuHub. FWApp-spezifisch bzw. betont:

- **Wer mergen darf, entscheidet der Versions-Bump** (Portfolio-Regel seit
  2026-07-20), denn der Merge ist die Veröffentlichung:
  - **Ohne Bump** (nur `*.md`, `.github/`, `test/`, `tool/`, `supabase/`,
    `LICENSE`): Der Agent darf nach grüner CI selbst squash-mergen. Es entsteht
    kein Release, auf den Geräten ändert sich nichts.
  - **Mit Bump: Der Merge gehört dem Menschen.** Er löst Tag, signiertes APK
    und GitHub-Release aus — das veröffentlicht Marcus selbst.

  > Bis 2026-07-31 stand hier ein pauschales „Der Agent merged nie selbst".
  > Das legte gestapelte PR-Ketten still (im Portfolio nachgewiesen an
  > durecmix #28–#33) und traf auch PRs, die gar nichts veröffentlichen.
  > Ebenfalls gestrichen: die Behauptung, der Claude-Code-Classifier blockiere
  > `gh pr merge` ohnehin — er tut es nicht zuverlässig.

- **Sprache:** Auf GitHub wird **Englisch** gesprochen — Commit-Messages,
  PR-Titel und -Beschreibungen, Issues und Kommentare. Deutsch bleibt für
  UI-Strings, `CHANGELOG.md`, README/Nutzer-Doku und die Kommunikation mit dem
  Betreiber.

  > Umgestellt am 2026-07-31, vorher bewusst Deutsch; Grund für den Wechsel ist
  > die Einheitlichkeit mit MitFahrBar und PilzBuddy. Der Bestand bleibt
  > deutsch — nicht nachträglich übersetzen. Die Feedback-Issues aus der App
  > sind weiterhin deutsch, die schreiben Nutzer.

- **Zu jedem Versions-Bump gehört ein [CHANGELOG.md](CHANGELOG.md)-Eintrag**
  aus Anwendersicht, auf Deutsch. ⚠️ Die Datei ist **kein reines
  Repo-Dokument**: Sie wird als Asset ausgeliefert und in der App unter
  *Einstellungen → Was ist neu?* gerendert (Issue #51).
  `test/core/changelog/changelog_test.dart` erzwingt, dass der oberste Eintrag
  die Version aus `pubspec.yaml` ist.
- **Version Guard** prüft die ausgelieferten Pfade
  (`lib android ios macos web assets pubspec.*`); im PR warnt er nur, auf
  `main` schlägt er fehl. Den Bump setzt der Maintainer bis zum Merge —
  externe Beiträge fassen die Version nicht an.
- ⚠️ **Die Required Checks hängen an den `name:`-Feldern der CI-Jobs**
  („Analyze & Test", „Build Web", „Build Android APK", „Version Guard"). Wird
  ein Job umbenannt, greift die Branch Protection stillschweigend nicht mehr —
  Umbenennung immer zusammen mit den Repo-Einstellungen.
- ⚠️ **`GITHUB_TOKEN`-Regel:** Ein mit `GITHUB_TOKEN` ausgelöster Vorgang
  triggert **keine** Folge-Workflows. Gewollt beim Tag-Push in `release.yml`
  (kein Doppel-Lauf) — Falle, sobald ein Bot-Issue eine Triage anstoßen soll.
- **Zum Ausprobieren in der echten App** den Skill `flutter-run-web` oder den
  Android-Emulator nutzen. Flutter zeichnet auf Canvas — geprüft wird über
  Screenshots, die man sich ansieht. Das hat hier mehrfach Fehler gefunden,
  die alle Tests durchgelassen hatten (zuletzt: der Bildeditor öffnete im
  Shell-Navigator, und die Navigationsleiste fraß die Rahmenhöhe).

### Toolchain

```text
Flutter SDK: /Volumes/MacStore/Programming/Flutter/SDK/flutter   (PATH exportieren!)
Flutter-Version: 3.44.8  — identisch in ci.yml und release.yml gepinnt
Java 17 für Android-Builds (neuere JDKs kann das Flutter-Gradle-Plugin nicht)
```

Bei lokalem Flutter-Upgrade **beide Workflows nachziehen**, AGP/Kotlin von Hand
mitprüfen. Das SDK teilen sich alle Flutter-Projekte des Portfolios — ein
Upgrade betrifft sie mit.

⚠️ **Kein `dart format` über Bestandsdateien.** Das Repo ist alt formatiert
(Dart-3.7-Formatter, nie migriert); `dart format .` will 114 Dateien umbauen
und erzeugt dabei zwei neue `curly_braces`-Lints. CI hat deshalb **keinen**
Format-Check — anders als im Rest des Portfolios, wo er der häufigste
vermeidbare Fehlschlag ist. Die Umstellung ist ein eigener PR; bis dahin kein
pauschales Formatieren in Feature-PRs.

## Code-Konventionen

- **Riverpod 3 mit Codegen** (`@riverpod`). Manuelle Provider nur mit
  Begründungskommentar am Dateikopf.
- **Codegen ist Pflicht vor jedem Commit** (`dart run build_runner build`) —
  auch bei reinen Methodenbody-Änderungen in `@riverpod`-Dateien, der Hash
  ändert sich. CI prüft das per `git diff --exit-code`.
- Struktur feature-first unter `lib/features/<x>/{data,domain,presentation}`,
  Abhängigkeitsrichtung `presentation → domain ← data`. Welche Feature-Größe
  welche Schichtung bekommt, steht in
  [CONTRIBUTING.md](CONTRIBUTING.md#schichtung-je-feature).
- **`mounted` / `context.mounted` nach jedem `await`** prüfen.
- **`catch (_) {}` nur mit Begründungskommentar, nie im Kernpfad** (Sync,
  Seeder, Persistenz): mindestens `appLog.w(...)`, nutzerrelevante Fälle
  zusätzlich in der UI sichtbar machen.
- **Zweitverwendung = Extraktion:** ein Widget/Helper, der in einer zweiten
  Datei gebraucht wird, wandert nach `core/` — nie kopieren.
- Datei-Header: `/// datei.dart – Zweck`. Nicht offensichtliche Entscheidungen
  im Code kommentieren, gern mit Issue-Referenz.
- Geloggt wird ausschließlich über `appLog`
  ([core/logging/app_logger.dart](lib/core/logging/app_logger.dart)) — kein
  `Logger()` pro Datei.
- **Keine Lokalisierung** (kein ARB/gen-l10n): Die Zielgruppe ist einsprachig,
  ein Übersetzungs-Layer wäre Indirektion ohne Nutzen.
- **Keine Design-Token-Klassen.** Ein Seed-Farbwert (`#C62828`) in
  [core/theme/app_theme.dart](lib/core/theme/app_theme.dart) speist
  `ColorScheme.fromSeed`; Screens nutzen `Theme.of(context)`, das App-Icon
  zieht seine Farbe aus derselben Konstante. Bewusste Abweichung von der
  Theming-Guideline — für die Projektgröße reicht das Theme, eine Umstellung
  wäre reine Churn. (Issue #58 könnte das ändern.)
- **Lints:** nur `flutter_lints`. `strict-casts`, `strict-raw-types` und
  `unawaited_futures` sind bewusst offen — eigener PR, potenziell breite Churn.
- **Dependencies** gepinnt (`^x.y.z`), **nie `any`**.

## Technik-Notizen

- **Sync:** `publish_snapshot` ersetzt den zentralen Bestand vollständig.
  Daher das **Mindestversions-Gate** (Issue #35, unten) — ein alter Client
  würde neu hinzugekommene Spalten kommentarlos auf NULL setzen.
- **Signing:** `docs/private/fwapp-release.jks` +
  `fwapp-release-keystore.properties` (gitignored, Backup Pflicht). Verlust =
  Update-Kette aller Installationen dauerhaft kaputt. CI bricht hart ab, wenn
  eines der vier Signing-Secrets fehlt — nie still debug-signieren. Signatur
  prüfen mit `apksigner`, **nicht** `keytool -jarfile` (kein v1-Signing mehr).
- **Actions-Secrets:** `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`, `FWAPP_SUPABASE_URL`,
  `FWAPP_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
- Server-URL und Anon-Key stecken **bewusst** im öffentlichen APK
  (clientseitig öffentlich, Zugriff schützt RLS). Lokal in
  `config/fwapp.local.json` (gitignored). Instanzdetails (IPs, VM-IDs) gehören
  nach `docs/private/` — **nie** in die öffentliche Doku, dort nur Platzhalter.
- **In-App-Update** ist aktiv (Verteilung ohne Play Store), tokenloser Check
  gegen `releases/latest`, Installation über `ota_update`, Banner auf dem
  Start-Dashboard.
  ⚠️ Diese Android-Bausteine gehören zusammen — fehlt einer, fällt es **erst
  beim Nutzer** auf, nie im Debug-Lauf:
  - `INTERNET` **und** `REQUEST_INSTALL_PACKAGES` als Permissions (das
    Release-Manifest braucht `INTERNET` explizit, Debug mergt sie automatisch
    — das kostete v1.3.1)
  - FileProvider mit Authority `${applicationId}.ota_update_provider`
  - `res/xml/filepaths.xml` mit
    `<files-path name="ota_update" path="ota_update/"/>`
  - `<queries>`-Eintrag für `VIEW`/`https` — sonst sieht die App unter
    Android 11+ keinen Browser und der Fallback scheitert still (Issue #27)
  - Core Library Desugaring in `build.gradle.kts` (`desugar_jdk_libs`)
- **In-App-Feedback** läuft über **DB + Bot**: Der Dialog schreibt in die
  Supabase-Tabelle `feedback`, [tool/feedback_bot.py](tool/feedback_bot.py)
  macht daraus öffentliche Issues und stempelt jede Zeile sofort
  (`processed_at`), damit ein Abbruch keine Duplikate erzeugt. Der Text
  erscheint **öffentlich** — der Hinweis im Dialog muss erhalten bleiben.
  Banner-Dismiss nur sitzungsweit, kein Persistieren.
  ⚠️ Cloudflare Bot Fight Mode blockt den UA `Python-urllib/3.x` mit 403; jeder
  Skript-Zugriff aufs öffentliche Gateway braucht einen eigenen User-Agent
  (der Bot setzt `fwapp-feedback-bot/1.0`).
- **Der Demo-Datenbestand ist fiktiv.** Die echte AB-G-Beladeliste ist bewusst
  aus dem Arbeitsstand entfernt; der Seeder legt Katalog **vor** Fahrzeug an.

## Tests

**Pflicht nach jeder Änderung:** `flutter analyze` + `flutter test`.

- **Harness:** [test/helpers/widget_harness.dart](test/helpers/widget_harness.dart)
  (`buildTestApp` mit In-Memory-Drift-DB). Am Testende `endTestApp(tester)`
  aufrufen, sonst bleiben Drift-Stream-Timer hängen („A Timer is still
  pending").
- **Coverage-Gate:** Logik-Schichten ≥ 65 %
  (`dart run tool/check_coverage.dart --min 65`). ⚠️ Coverage zählt eine Datei
  erst, wenn ein Test sie importiert — neuer, ungetesteter Code kippt das Gate,
  auch wenn er selbst fehlerfrei ist.
- **Migrationstests** für Drift
  ([test/core/database/migration_test.dart](test/core/database/migration_test.dart))
  samt Schema-Snapshots unter `test/core/database/generated/`.
- **E2E gegen den echten Supabase-Stack**
  ([test/integration/sync_e2e_test.dart](test/integration/sync_e2e_test.dart)):
  überspringt sich ohne laufenden Stack selbst, in CI läuft er. Alles, was RLS,
  Trigger oder `security definer` beweist, gehört dorthin und nicht in einen
  Fake. ⚠️ Ein Skip sieht im CI-Log aus wie ein Pass — nach Änderungen dort
  einmal nachsehen, ob die Tests wirklich gelaufen sind.
- **Geräte-Smoke-Test** ([integration_test/](integration_test/)) ist Pflicht
  vor Releases mit Android-spezifischen Änderungen (Manifest, Permissions,
  Plugins). Er nutzt `waitFor()` und `ensureVisible()` und listet bei
  Fehlschlägen die sichtbaren Texte auf.
- Kein Netzwerk in Unit-/Widget-Tests. Keine Golden-Tests im Bestand.

> **Offen:** Konfigurations-Regressionstests (Manifest, FileProvider-Authority,
> `filepaths.xml`, Desugaring als gewöhnlicher Dart-Test, der die Dateien
> liest). `test/config/release_config_test.dart` deckt einen Teil ab; der
> `<queries>`-Eintrag hängt weiterhin nur am Geräte-Smoke-Test, der nicht in CI
> läuft. Ein solcher Test hätte Issue #27 in CI gefangen.

## Bekannte Eigenheiten und Stolperfallen

- ⚠️ **Das Pixel XL im Testrig liegt quer** – `tester.view` meldet 683 × 411 dp.
  In dem flachen Fenster rutschen Listeneinträge unter die `NavigationBar`;
  `tester.tap(find.text(...))` trifft dann die Leiste, und der Test wandert
  wortlos in einen anderen Tab. Symptom ist eine ganz andere fehlschlagende
  Sichtprüfung. Der hochkante Emulator verdeckt das komplett.
- ⚠️ **`pumpAndSettle` reicht auf echten Geräten nicht:** Solange asynchrone
  Provider auf I/O warten, steht kein Frame an – `pumpAndSettle` kehrt zurück,
  während noch „Lade…" auf dem Schirm steht. Dafür gibt es `waitFor()`.
- ⚠️ **`pumpAndSettle` bei dauerlaufenden Fortschrittsringen** läuft in einen
  Timeout statt in einen Fehlschlag — es wartet auf einen Ruhezustand, den ein
  `CircularProgressIndicator` nie erreicht. Betrifft den Bildaufnahme-Editor
  (Issue #56), solange das Bild lädt: dort `pump(Duration)` in einer kleinen
  Schleife.
- ⚠️ **`compute()` läuft in Widget-Tests nicht in der simulierten Zeit ab.**
  `pump(Duration)` schiebt nur die Fake-Uhr vor, das echte Isolate liefert
  dabei nie. Für solche Stellen `tester.runAsync(...)` verwenden — und
  **vorher pumpen**, damit die Route gebaut ist und ihr `initState` die Arbeit
  angestoßen hat; sonst läuft das Fenster ins Leere. Zwei aufeinanderfolgende
  echte Schritte (Isolate, dann Engine) brauchen zwei Fenster.
- ⚠️ **Riverpod 3:** `StateProvider` lebt in `flutter_riverpod/legacy.dart`,
  `AsyncValue.valueOrNull` heißt jetzt `.value`, und `WidgetRef` ist **kein**
  `Ref` – Helfern den Client als Parameter geben statt `Ref`.
- ⚠️ **Drift `replace()`** wirft bei partiellen Companions → `patchEquipment` /
  `write()` nutzen.
- ⚠️ **`drift` und `drift_dev` sind exakt gepinnt und gehören zusammen.**
  `drift_dev` hängt bei 2.34.0 fest (ab 2.34.4 verlangt es `analyzer ^13`, den
  `riverpod_generator`/`freezed` hier nicht mitgehen), und `drift` 2.34.1+
  ändert die `drift3_preview`-API, die `drift_dev` 2.34.0 benutzt. Das schlägt
  **nicht** in `flutter analyze` auf, sondern erst als Compile-Fehler beim
  Laden von `test/core/database/migration_test.dart`. Nur gemeinsam anheben.
- ⚠️ **`sqlite3_flutter_libs` ist entfernt, nicht vergessen worden.** Ab
  `sqlite3` 3.x kommen die nativen Libs über Build-Hooks aus `sqlite3` selbst;
  `sqlite3_flutter_libs 0.6.0+eol` ist eine leere Hülle. Wer den EOL-Bump
  blind übernimmt, verliert `libsqlite3.so` im APK — und merkt es erst zur
  Laufzeit auf dem Gerät, nicht im Build. Gegenprobe:
  `unzip -l build/app/outputs/flutter-apk/app-*.apk | grep libsqlite3`.
- ⚠️ **`file_picker` ab 11:** `FilePicker.platform.pickFiles(...)` gibt es
  nicht mehr, die Methoden sind jetzt statisch → `FilePicker.pickFiles(...)`.
- ⚠️ **`ReorderableListView.onReorder` ist deprecated** → `onReorderItem`. Das
  ist kein reines Umbenennen: `onReorderItem` rechnet das `newIndex--` für das
  entnommene Element bereits selbst heraus. Wer die eigene Korrekturzeile
  stehen lässt, verschiebt still um eine Position zu weit.
- ⚠️ **`rootBundle`-Loads in `FutureBuilder`** hängen in Widget-Tests
  (fake async).
- ⚠️ **AlertDialogs mit 2+ Feldern** brauchen `SingleChildScrollView` im
  `content` – sonst überlappen auf kleinen Screens Buttons und zweites Feld.
- **Die VM hat kein IPv4-Internet** (Fritz!Box beantwortet den ARP der VM-MAC
  nicht, IPv6 geht). Deshalb der Offline-Dispatcher unter
  `supabase/functions/main/` – Edge Functions dürfen **keine** externen Imports
  (`jsr:`/`npm:`) ziehen, sonst 502 beim Kaltstart.

## Zurückgestellt — bewusst nicht jetzt

Analysiert und entschieden, aber absichtlich vertagt. Gehört **nicht** in den
nächsten PR und soll nicht in jeder Session neu aufgerollt werden. Wer es
anfassen will, holt vorher Marcus' Zustimmung ein.

### Crash-Reporting (Issue #34) — umgesetzt, aber am Hausmuster vorbei

**Umgesetzt (2026-07-31, v1.5.0):** der lokale Absturzspeicher
([core/crash/crash_store.dart](lib/core/crash/crash_store.dart)). Dart-Fehler
aus `FlutterError.onError` und `PlatformDispatcher.onError` landen in den
SharedPreferences (max. 3, Stacktrace gekappt) und werden beim nächsten Start
als Banner angeboten — Meldung über den Feedback→GitHub-Kanal oder in die
Zwischenablage.

⚠️ **Das weicht in vier Punkten vom Bauplan „Route A" der Observability-Guideline
ab** (`guidelines/observability.md` im DocuHub). Der Bauplan ist an PilzBuddy
produktiv gemessen, diese Umsetzung ist es nicht — beim Nacharbeiten gilt der
Hub:

1. **Eine Senke, kein Issue pro Absturz.** Dort wurden 37 Berichte für ein
   Abmelden und 193 für abgebrochene Hintergrundaufträge gemessen. Hier bremst
   bisher nur, dass jeder Versand eine bewusste Nutzeraktion ist.
2. **Synchron auf Platte schreiben, bevor irgendetwas anderes passiert.** Hier
   läuft `unawaited(recordCrash(...))` gegen asynchrone SharedPreferences — der
   Hub führt genau das unter „So nicht", weil es bei harten Abstürzen nie
   ankommt.
3. **Dedupe-Fingerprint** (Exception-Typ + oberste eigene Frames, FNV-1a, nie
   `String.hashCode`) und Rate-Limit fehlen.
4. **Log-Ring-Buffer** fehlt: Ein Stacktrace ohne Vorgeschichte ist oft nicht
   diagnostizierbar. Dazu ein **PII-Regressionstest** — die Repos sind public.

**Korrektur einer früheren Aussage:** Hier stand, harte native Abstürze und
ANRs bräuchten das Backend. **Das stimmt nicht.** Ab Android 11 liefert
`getHistoricalProcessExitReasons` über einen MethodChannel Grund, Zeitpunkt,
Speicherstand und bei ANRs den Thread-Dump — **ohne Dienst und ohne
Berechtigung**. PilzBuddy setzt das ein (`lib/data/exit_info_repository.dart`);
der erste Feldfang dort war ein ANR, von dem sonst nur ein schwarzer Bildschirm
übrig geblieben wäre.

**Was wirklich noch das Backend braucht:** Cluster-Bildung und der Vergleich
über Releases („seit 1.4.2 dreimal so viele"). Entschieden ist Selbst-Hosting
mit **GlitchTip** statt sentry.io — Sentry `self-hosted` (4 Kerne, 16 GB, ~40
Container) ist zu groß für VM 104, GlitchTip braucht nur Postgres, Redis und
zwei Django-Prozesse. **Blockiert**, solange die VM ohne IPv4 keine
Container-Images ziehen kann (derselbe Punkt, der den Brevo-Testversand
blockiert). Die Vorbedingung Issue #39 ist seit v1.4.4 erledigt.

### Mindestversions-Check (Issue #35) — erledigt

**Umgesetzt (2026-07-31, v1.5.0).** Migration
`20260731000000_minimum_supported_version.sql`.

⚠️ **Die Migration muss auf den Server**, sonst greift nichts: per
`docker exec psql` als `supabase_admin` einspielen, danach
`NOTIFY pgrst, 'reload schema'`.

**Scharfschalten ist bewusst ein Handgriff** — die App hat auf die Spalte kein
Schreibrecht, das läuft über den Service-Role-Key:

```sql
update public.dataset_meta set minimum_supported_version = '1.5.0' where id = 1;
update public.dataset_meta set minimum_supported_version = null   where id = 1;  -- aus
```

⚠️ **Drei Aussperr-Garantien, die beim Anfassen erhalten bleiben müssen** (alle
in `test/integration/sync_e2e_test.dart` gegen die echte SQL-Funktion geprüft):

1. **NULL = kein Gate.** Die Migration allein ändert nichts am Verhalten.
2. **Nur `publish_snapshot` ist betroffen.** Pull, Lesen und der lokale Betrieb
   laufen weiter — local-first bleibt local-first. Ein abgewiesener Gerätewart
   kann weiterarbeiten, seine Daten bleiben erhalten.
3. **Fail-open.** Ist der Wert unlesbar, wird durchgelassen, nicht gesperrt.
   Sonst schnitte ein Tippfehler die ganze Wehr vom Veröffentlichen ab,
   reparierbar nur noch mit DB-Zugriff. Der CHECK auf der Spalte hält Unsinn
   ohnehin fern; fail-open ist der Notnagel dahinter.

Was die Analyse ergeben hatte und weiterhin gilt:

- Der gefährliche Pfad ist **nicht** der Pull, sondern `publish()`:
  `jsonb_populate_recordset` setzt fehlende Keys kommentarlos auf NULL, eine
  neu hinzugekommene Sync-Spalte wäre danach für die ganze Wehr leer.
  `expected_version` schützt nur gegen parallele Publishes.
- Die Server-Tabelle heißt **`dataset_meta`** (eine Zeile, `check (id = 1)`),
  nicht `sync_meta` — das ist die lokale Drift-Tabelle.
- Das Gate hängt **nicht** an `updateInfoProvider`: Der liefert auf Web und iOS
  grundsätzlich `null`, und ausgerechnet die Web-App ist der Weg, über den
  Admins publizieren. Die Version kommt aus
  [core/app_version.dart](lib/core/app_version.dart), gesetzt in `main.dart`.
- ⚠️ Die alte 2-argumentige `publish_snapshot` **musste weichen**, sonst wäre
  der Aufruf mit zwei Argumenten mehrdeutig („function is not unique").
  Alt-Clients landen dadurch bei `client_version = NULL` — genau der Fall, den
  das Gate abfängt.
