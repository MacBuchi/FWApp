# Feuerwehr-Lernapp (FWApp)

Eine plattformübergreifende Flutter-App zum Lernen von Fahrzeugbeladung, 
Geräte­erkennung und Einsatzvorbereitung für Feuerwehrkräfte.

---

## Versionsinfo

| Eigenschaft      | Wert                     |
|------------------|--------------------------|
| App-Version      | 1.0.0+1                  |
| Flutter          | 3.41.2 (stable)          |
| Dart             | 3.11.0                   |
| Zielplattformen  | Android, iOS, Web        |

---

## Projektziel

Die App unterstützt Feuerwehrkräfte beim Erlernen von:

- **Fahrzeugbeladeplänen** – welche Geräte befinden sich in welchem Fach?
- **Gerätekunde** – Beschreibungen, technische Daten, Anwendungsfälle
- **Trainings-Spielmodi** – Quiz, Drag & Drop, Bilderkennung, Einsatzsimulation

---

## Architektur

### Clean Architecture mit Feature-first Ordnerstruktur

```
lib/
├── core/
│   ├── database/          # Drift-Datenbank, DAOs, Seeder
│   ├── router/            # GoRouter-Konfiguration
│   ├── theme/             # Material 3 Theme (rot, hell/dunkel)
│   └── utils/             # json_utils, image_utils
│
├── features/
│   ├── vehicle/           # Fahrzeugliste, -detail, -formular, Fachverwaltung
│   ├── equipment/         # Gerätedatenbank, -detail, -formular
│   ├── compartment/       # Fach-Entität + Repository
│   ├── assignment/        # Geräte-Fach-Zuordnung
│   ├── home/              # Dashboard (Statistiken, Schnellnavigation)
│   ├── game/
│   │   ├── quiz/          # Fach-Quiz (Multiple Choice + Drag & Drop)
│   │   │                  # Bilderkennungs-Quiz
│   │   └── deployment/    # Fahrzeug-Einsatzmodus
│   ├── import/            # Excel/CSV-Import
│   └── settings/          # Einstellungen (Theme, Supabase-Sync)
│
└── main.dart
```

**Dependency-Regel:** `presentation` → `domain` ← `data`  
Domain-Entitäten haben keine Flutter- oder Drift-Abhängigkeiten.

---

## Tech Stack

| Schicht          | Technologie                               |
|------------------|-------------------------------------------|
| UI               | Flutter 3.41.2 – Material 3               |
| State Management | Riverpod 3.x (`@riverpod` Code-Gen)       |
| Lokale DB        | Drift 2.21 (SQLite)                       |
| Navigation       | GoRouter 14.6                             |
| Domain-Modelle   | freezed 3.x + json_annotation            |
| Import           | `excel` + `file_picker`                  |
| Bilder           | `image_picker`, `cached_network_image`   |
| Cloud (optional) | Supabase (Auth + Sync)                   |
| Code-Gen         | `build_runner`, `drift_dev`, `freezed`, `riverpod_generator` |

Server-Setup für den Supabase-Sync: siehe [docs/SERVER-SETUP.md](docs/SERVER-SETUP.md).

---

## Abhängigkeiten (pubspec.yaml)

### Laufzeit
```yaml
flutter_riverpod: ^3.0.0
riverpod_annotation: ^4.0.0
drift: ^2.21.0
sqlite3_flutter_libs: ^0.5.29
path_provider: ^2.1.5
path: ^1.9.1
go_router: ^14.6.3
freezed_annotation: ^3.0.0
json_annotation: ^4.9.0
file_picker: ^8.1.7
image_picker: ^1.1.2
cached_network_image: ^3.4.1
excel: ^4.0.6
supabase_flutter: ^2.8.4
intl: ^0.20.2
logger: ^2.5.0
uuid: ^4.5.1
shared_preferences: ^2.3.5
package_info_plus: ^8.3.0
url_launcher: ^6.3.1
```

### Entwicklung
```yaml
build_runner: ^2.4.14
drift_dev: ^2.21.0
riverpod_generator: ^4.0.0
freezed: ^3.0.0
json_serializable: ^6.8.0
flutter_lints: ^5.0.0
```

---

## Datenbankschema (Drift / SQLite)

| Tabelle                  | Beschreibung                                        |
|--------------------------|-----------------------------------------------------|
| `Vehicles`               | Fahrzeuge (Name, Typ, Kennzeichen, Bild)            |
| `Compartments`           | Fächer je Fahrzeug (Label, Position, Grid-Hints)    |
| `EquipmentItems`         | Gerätedatenbank (Name, Funktionen, Szenarien, JSON) |
| `EquipmentAssignments`   | Zuordnungen Gerät ↔ Fach mit Menge                  |
| `QuizResults`            | Trainingsergebnisse (Typ, Score, Fahrzeugreferenz)  |

### Geräteklassifikation (zweiachsig)

Jedes Gerät wird entlang **zwei unabhängiger Achsen** klassifiziert:

| Achse                  | Werte (Auszug)                                             |
|------------------------|------------------------------------------------------------|
| `EquipmentFunction`    | `rettung`, `brand`, `wasser`, `pumpen`, `dekon`, … (17)   |
| `DeploymentScenario`   | `vuPkw`, `brandInnen`, `thKlemmt`, `hochwasser`, … (23)   |

Beide werden als JSON-Arrays (UPPER_SNAKE_CASE) in der DB gespeichert.

---

## Features

### Fahrzeugverwaltung
- Fahrzeugliste mit Bild, Name und Typ
- Detailansicht mit Fächern und zugewiesenen Geräten (aufklappbar)
- Fahrzeug anlegen / bearbeiten (inkl. Foto aus Galerie oder Kamera)
- Fächerverwaltung: Hinzufügen, Umbenennen, Neu­anordnen, Löschen

### Gerätedatenbank
- Volltext-Suche + Filter nach Funktion und Einsatzszenario
- Detailansicht mit Beschreibung, technischen Daten, Trainingslink
- Gerät anlegen / bearbeiten (Multi-Select für Funktion & Szenario)

### Trainings-Spielmodi

| Modus                   | Beschreibung                                                 |
|-------------------------|--------------------------------------------------------------|
| **Fach-Quiz**           | Wo ist dieses Gerät? – 4 Antwortmöglichkeiten               |
| **Drag & Drop**         | Gerätekarten per Drag in die richtigen Fachzonen ziehen      |
| **Bilderkennungs-Quiz** | Gerät anhand des Fotos erkennen – Multiple Choice            |
| **Einsatz-Modus**       | Mehrere Fahrzeuge auswählen → kombinierte Geräteliste        |

### Excel / CSV-Import
- Datei über `file_picker` auswählen
- Spalten `vehicle`, `compartment`, `equipment`, `quantity` werden erkannt
- Upsert von Fahrzeugen → Fächern → Geräten → Zuordnungen in einer Transaktion
- Alias-Auflösung über `assets/equipment_library/aliases.json`
- Neue, nicht auflösbare Einträge werden als `isCustom = true` angelegt

### Einstellungen
- Hell-/Dunkel-Modus (persistent via SharedPreferences)
- Supabase-Sync aktivieren + URL und Anon-Key konfigurieren
- Bibliotheksversion anzeigen + Update suchen
- App-Version (aus `package_info_plus`)

---

## Geräte-Content-Bibliothek (JSON-Assets)

```
assets/equipment_library/
├── metadata.json                          # Bibliotheksversion
├── aliases.json                           # Importalias-Mapping
└── vehicles/
    └── ab_g/
        ├── vehicle.json                   # Fahrzeugmetadaten AB-G
        ├── loading_plan.json              # Beladeplan (13 Fächer, 257 Positionen)
        └── equipment/                     # 257 Gerätedefinitionen (.json)
```

### AB-G (Abrollbehälter Gefahrgut) – Initialdatensatz v1.0.0
- **257 eindeutige Geräte** in 13 Fächern (Dach, G1–G4, Heck, TW-1 bis TW-6)
- Quelle: Beladeliste AB-G, Stand 2025-01-29
- Generiert mit `tools/generate_ab_g_data.py`

### First-Launch-Seeding
Beim ersten Start werden alle JSON-Assets idempotent in die Drift-DB eingespielt:
1. `vehicle.json` → `Vehicles`-Tabelle
2. `loading_plan.json` → `Compartments` + `EquipmentAssignments`
3. `equipment/{id}.json` → `EquipmentItems` (wenn `libraryEquipmentId` noch nicht vorhanden)

---

## Navigation (GoRouter)

```
/                        → HomeScreen (Dashboard)
/vehicles                → VehicleListScreen
/vehicles/:id            → VehicleDetailScreen
/vehicles/:id/compartments → CompartmentManagerScreen
/equipment               → EquipmentListScreen
/equipment/:id           → EquipmentDetailScreen
/game                    → GameMenuScreen
/game/compartment-quiz   → CompartmentQuizScreen
/game/drag-drop          → DragDropScreen
/game/image-quiz         → ImageRecognitionQuizScreen
/game/deployment         → DeploymentModeScreen
/import                  → ImportScreen
/settings                → SettingsScreen
```

Navigation-Tabs (ShellRoute): **Home · Fahrzeuge · Geräte · Training**

---

## Build-Anleitung

### Voraussetzungen

| Tool        | Version          | Hinweis                                                              |
|-------------|------------------|----------------------------------------------------------------------|
| Flutter     | 3.41.2 (stable)  |                                                                      |
| Dart        | 3.11.0           |                                                                      |
| Java        | 17               | Java 25 wird vom Flutter-Gradle-Plugin noch nicht unterstützt        |
| NDK         | 28.2.13676358    | In `android/app/build.gradle.kts` gepinnt                            |
| Android SDK | 35 (API 35)      |                                                                      |

#### Java-Version für Flutter konfigurieren
```bash
flutter config --jdk-dir="/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
```

### Abhängigkeiten installieren
```bash
flutter pub get
```

### Code-Generierung ausführen
Nach Änderungen an annotierten Dateien (`@freezed`, `@riverpod`, `@DriftDatabase`):
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Debug-Build
```bash
# Android APK
flutter build apk --debug

# iOS (macOS erforderlich)
flutter build ios --debug --no-codesign

# Web (WASM-Setup erforderlich für SQLite)
flutter build web --debug
```

### Release-Build
```bash
flutter build apk --release
flutter build appbundle --release
```

### Statische Analyse
```bash
flutter analyze
```

---

## Offline-First

Die App funktioniert **vollständig ohne Netzwerkverbindung**:
- Alle Daten liegen lokal in SQLite (Drift)
- Supabase-Sync ist optional und läuft nur bei aktivierter Einstellung im Hintergrund
- Beim ersten Start werden alle Fahrzeug- und Gerätedaten aus den JSON-Assets vorgeladen

---

## Bekannte Einschränkungen (v1.0.0)

- **Keine Bilder:** Gerätefotos sind noch nicht vorhanden; die App zeigt Platzhalterbilder (`assets/images/placeholder_equipment.png`)
- **Web-Build:** SQLite via `dart:ffi` ist auf Web nicht direkt verfügbar; ein WASM-basiertes Setup mit `WasmDatabase` ist für eine spätere Version geplant
- **Admin-Rolle:** Noch nicht implementiert – alle Nutzer haben vollen Zugriff (geplant für v2)
- **Supabase-Sync:** Implementierungsgerüst vorhanden, aber noch nicht vollständig getestet

---

## Geplante Features (v2)

- Bilder für alle Geräte (WebP, max. 1024 px)
- PIN-geschützter Admin-Modus
- Supabase-Sync mit Last-Write-Wins (`updated_at`)
- Web-Support via WASM-Datenbank
- Beschreibungs-Quiz (Gerät anhand technischer Daten erkennen)
- Over-the-Air-Updates der Gerätebibliothek

---

## Projektstruktur (Quelldateien)

```
lib/
├── main.dart
├── core/
│   ├── database/
│   │   ├── app_database.dart         # 5 Tabellen, 5 DAOs
│   │   ├── database_providers.dart   # Riverpod-Provider für DB + DAOs
│   │   └── library_seeder.dart       # Idempotenter JSON-Seeder
│   ├── router/
│   │   └── app_router.dart           # GoRouter + ShellRoute (4 Tabs)
│   ├── theme/
│   │   └── app_theme.dart            # Material 3, Seed-Farbe #C62828
│   └── utils/
│       ├── image_utils.dart
│       └── json_utils.dart
└── features/
    ├── assignment/                   # Geräte-Fach-Zuordnung
    ├── compartment/                  # Fach-Feature
    ├── equipment/                    # Gerätedatenbank-Feature
    ├── game/
    │   ├── deployment/               # Einsatzmodus
    │   ├── presentation/             # GameMenuScreen
    │   └── quiz/                     # Fach-Quiz, Drag & Drop, Bild-Quiz
    ├── home/                         # Dashboard
    ├── import/                       # Excel-Import
    ├── settings/                     # Einstellungen
    └── vehicle/                      # Fahrzeug-Feature
```

---

## Lizenz

Internes Schulungsprojekt. Alle Rechte vorbehalten.

