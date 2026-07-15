# FWApp – Feuerwehr-Lernapp

[![CI](https://github.com/MacBuchi/FWApp/actions/workflows/ci.yml/badge.svg)](https://github.com/MacBuchi/FWApp/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MacBuchi/FWApp)](https://github.com/MacBuchi/FWApp/releases/latest)

Eine plattformübergreifende Flutter-App für Freiwillige Feuerwehren:
**Fahrzeugbeladung lernen, Geräte verwalten, Prüftermine im Blick behalten,
Inventuren durchführen** – offline-first, mit optionalem selbst gehostetem
Sync-Server für die ganze Wehr.

Entstanden für eine Wehr in Baden-Württemberg, aber bewusst so gebaut, dass
andere Wehren sie mit eigenen Beladelisten und eigenem Server nachnutzen
können.

---

## Was die App kann

### Lernen (alle Mitglieder)

- **Lern-Dashboard** mit Streak, XP und Wochenziel
- **Fach-Quiz** („Wo liegt dieses Gerät?“), **Drag & Drop**, **Bild-Quiz**,
  **Geräte-Wissen**
- **2D-Schnittdarstellung** der Fahrzeuge: aufgeklappte Fächeransicht als
  Navigations- und Lernfläche
- Grundkatalog mit 110 Normgeräten (Beschreibungen, Funktionen,
  Einsatzszenarien) als Startpunkt

### Gerätewart / Admin

- **Gerätewart-Assistent**: Prüftermine und Ablaufdaten je Geräteinstanz,
  Fälligkeits-Dashboard, Badges
- **Import-Wizard**: Excel/CSV-Beladelisten in 4 Schritten einlesen
  (Spalten-Mapping, Fuzzy-Matching gegen den Katalog, Alias-Lernen)
- **Inventurassistent**: Fahrzeug Fach für Fach abhaken (Soll/Ist), Mängel
  dokumentieren, Abschluss-Report
- **Zentrale Gerätefotos**: am Handy fotografieren, automatisch komprimiert
  hochladen – erscheint nach dem nächsten Pull auf allen Geräten (inkl.
  Offline-Cache für den Einsatz)

### Einsatz

- **Einsatzassistent** („virtuelles Ausladen“): Entnahme-Tracking über die
  Schnittdarstellung, 100 % offline, Entnahme-Liste fürs Aufräumen

---

## Architektur in 60 Sekunden

- **Local-first:** Alle Daten liegen lokal in SQLite ([Drift](https://drift.simonbinder.eu/));
  die App funktioniert vollständig offline (Web-Build inklusive, via WASM-DB).
- **Single-Writer-Sync (optional):** Ein selbst gehosteter
  [Supabase](https://supabase.com/)-Server hält den zentralen Datenbestand.
  Nur Admins bearbeiten und **veröffentlichen** komplette Snapshots
  (`publish_snapshot()`-RPC mit Versionszähler); alle Mitglieder **lesen**
  denselben Stand per Pull. Keine Konfliktauflösung nötig – gewollt.
- **Rollen:** `admin` (bearbeiten + veröffentlichen) und `member` (lesen,
  lernen) über Supabase Auth + RLS; Mitglieder sehen keine Bearbeitungs-UI.
- **Gerätefotos:** privater Storage-Bucket; die DB speichert portable Marker
  (`supabase://…`), aufgelöst zur Laufzeit, angezeigt über
  `cached_network_image`, vorgeladen nach jedem Pull.

```text
lib/
├── core/         # Drift-DB + DAOs, Router, Theme, Sync (Pull/Publish, Fotos)
└── features/     # feature-first: vehicle, equipment, compartment, assignment,
                  # inspection, inventory, operation, game, import, home, settings
```

**Tech-Stack:** Flutter (Material 3) · Riverpod 3 (Code-Gen) · Drift/SQLite ·
GoRouter (Tabs: Start / Lernen / Fahrzeuge / Mehr) · freezed ·
supabase_flutter. Plattformen: Android, iOS, macOS, Web.

Das Datenmodell ist in [docs/data_model.drawio](docs/data_model.drawio)
skizziert; Projektstand und Historie in [docs/ROADMAP.md](docs/ROADMAP.md).

---

## Loslegen

### Nur ausprobieren

Fertiges Android-APK vom [aktuellen Release](https://github.com/MacBuchi/FWApp/releases/latest)
laden und installieren. Ohne Server läuft die App komplett lokal mit dem
mitgelieferten Demo-Datensatz (Abrollbehälter Gefahrgut mit 257 Positionen).

### Entwickeln

Voraussetzungen: Flutter 3.41.x (stable), Java 17 (für Android-Builds).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Codegen
flutter test
flutter run
```

Wichtig: Nach Änderungen an `@riverpod`-, `@freezed`- oder Drift-Dateien
**immer** `build_runner` laufen lassen und die generierten Dateien
mitcommitten – die CI prüft das. Details in
[CONTRIBUTING.md](CONTRIBUTING.md).

Für den Sync-E2E-Test lokal einen Supabase-Stack starten (Docker nötig):

```bash
supabase start
bash tool/setup_local_supabase.sh   # legt Testnutzer admin@/member@fw.local an
flutter test
```

### Eigenen Sync-Server betreiben

Komplette Anleitung (self-hosted Supabase per Docker, Schema-Migrationen,
Backups, Restore-Probe): [docs/SERVER-SETUP.md](docs/SERVER-SETUP.md).
Die App wird zur Build-Zeit auf den eigenen Server vorkonfiguriert
(`config/fwapp.local.json.example` → `config/fwapp.local.json`, dann
`flutter build … --dart-define-from-file=config/fwapp.local.json`) –
alternativ URL + Anon-Key in den App-Einstellungen eintragen.

Betrieb im Verein (Onboarding, Admin-Handbuch, Troubleshooting, Datenschutz):
[docs/BETRIEB.md](docs/BETRIEB.md).

---

## Releases

Jeder Merge auf `main` mit erhöhter `version:` in `pubspec.yaml` erzeugt
automatisch ein Git-Tag `vX.Y.Z` und ein GitHub-Release mit signiertem
Android-APK (`fwapp-vX.Y.Z.apk`) – siehe
[release.yml](.github/workflows/release.yml).

## Qualität

CI ([ci.yml](.github/workflows/ci.yml)): `flutter analyze`,
Codegen-Aktualitäts-Check, Tests inkl. Sync-E2E gegen einen lokalen
Supabase-Stack, Coverage-Gate (≥ 65 % auf den Logik-Schichten),
Web- und Android-Build.

## Mitmachen

Issues und Pull Requests sind willkommen – Konventionen und Workflow stehen
in [CONTRIBUTING.md](CONTRIBUTING.md).

## Lizenz

[MIT](LICENSE) — nachnutzen, anpassen, weitergeben ausdrücklich erwünscht,
gerade durch andere Wehren.

## Bewusst nicht im Scope

- 3D-Fahrzeugmodelle (die 2D-Schnittdarstellung ist die Entscheidung)
- Multi-Writer-Sync / Konfliktauflösung (Single-Writer bleibt)
- Einsatzdokumentation im rechtlichen Sinn (nur lokales Entnahme-Log)
