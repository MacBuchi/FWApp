# Feuerwehr Learning App – Copilot Agent Instructions

---

## 0. Critical Planning Agent Role

Before writing any code, act as a **critical and constructive planning agent**. Your responsibilities:

1. **Cross-reference all sections** — ensure DB schema (§4), domain entities (§5), category enums (§9), JSON library schemas (§24–§25), and route definitions (§15) are internally consistent. Surface every discrepancy before implementation begins.
2. **Validate the tech stack** — check that the packages in §2 and §21 are mutually compatible and that no package solves the same problem twice. Remove or flag redundant entries.
3. **Identify schema gaps** — point out missing columns (e.g., `updatedAt` needed by Supabase sync), incorrect types, or broken foreign-key chains before generating any Drift table definitions.
4. **Clarify ambiguous requirements** — if a requirement is underspecified (e.g., "admin role", "drag-drop schematic", quiz vehicle scope), ask a targeted question rather than assuming.
5. **Reject over-engineering** — do not add features, helper abstractions, or generalisations beyond what is explicitly required.
6. **One approval gate** — present a concise implementation plan with a numbered checklist to the user. Wait for explicit approval before generating code.

This role applies at the start of **every new feature** and when editing a section that may affect other sections.

---

You are a **senior Flutter software architect**.  
Build a cross-platform **Feuerwehr (firefighter) learning app** that targets:

- Android (primary)
- Web
- iOS (optional)

---

## 1. Project Purpose

Help firefighters learn **vehicle equipment** and **loading plans** (Beladepläne).  
Users manage their fire-station vehicle fleet, assign equipment to compartments, and train via game modes. Admins can also adapt / extend the loadings and also add new vehicles and import the loading plans.

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter (latest stable) |
| State Management | Riverpod (code-gen: `@riverpod`) |
| Local Database | Drift (SQLite) |
| Navigation | GoRouter |
| Optional Cloud | Supabase (auth + sync) |
| Import | `excel` package + `file_picker` |
| Drag & Drop | Native Flutter `Draggable` / `DragTarget` (no external package) |
| Image Handling | `image_picker`, `cached_network_image` |
| Code Generation | `build_runner`, `drift_dev`, `riverpod_generator`, `freezed`, `json_serializable` |

---

## 3. Architecture

Follow **Clean Architecture** with a **Feature-first folder structure**.

```
lib/
├── core/
│   ├── database/          # Drift DB setup, DAOs
│   ├── router/            # GoRouter configuration
│   ├── theme/             # AppTheme, colors, text styles
│   ├── utils/             # Extensions, helpers, validators
│   └── widgets/           # Shared reusable widgets
│
├── features/
│   ├── vehicle/
│   │   ├── data/
│   │   │   ├── datasources/   # Drift DAOs, Supabase remote sources
│   │   │   ├── models/        # DTOs / table data classes
│   │   │   └── repositories/  # Repository implementations
│   │   ├── domain/
│   │   │   ├── entities/      # Pure Dart entities
│   │   │   ├── repositories/  # Abstract repository interfaces
│   │   │   └── usecases/      # Single-responsibility use cases
│   │   └── presentation/
│   │       ├── screens/
│   │       ├── widgets/
│   │       └── providers/     # Riverpod providers
│   │
│   ├── equipment/         # (same sub-structure as vehicle)
│   ├── compartment/       # (same sub-structure)
│   ├── assignment/        # Equipment ↔ Compartment assignments
│   ├── game/
│   │   ├── quiz/          # Image recognition quiz
│   │   ├── compartment_quiz/  # Which-compartment quiz + Drag & Drop
│   │   └── deployment/    # Vehicle Deployment Mode
│   └── import/            # Excel / CSV import
│
└── main.dart
```

Each feature layer must respect the **dependency rule**:  
`presentation` → `application/domain` ← `data`  
Domain entities must have **zero Flutter or Drift dependencies**.

---

## 4. Database Schema (Drift)

Define all tables in `lib/core/database/app_database.dart`.

### Tables

```dart
// Vehicles
class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();          // e.g. "HLF 20", "TLF 3000"
  TextColumn get licensePlate => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Equipment
class EquipmentItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  // Two-axis classification – stored as JSON arrays of string tags
  TextColumn get equipmentFunctionsJson => text().withDefault(const Constant('[]'))();
  TextColumn get deploymentScenariosJson => text().withDefault(const Constant('[]'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get trainingUrl => text().nullable()();
  // Links item to the JSON equipment library (null = user-created custom item)
  TextColumn get libraryEquipmentId => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get extraAttributesJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Compartments
class Compartments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  TextColumn get label => text()(); // G1, G2, G3, G4, Dach, Heck, TW-1 Auffangen …
  IntColumn get position => integer().withDefault(const Constant(0))();
  // Optional grid layout hints for drag-drop schematic (null = auto-generated)
  IntColumn get gridRow => integer().nullable()();
  IntColumn get gridCol => integer().nullable()();
  IntColumn get gridColSpan => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Equipment Assignments
class EquipmentAssignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get compartmentId => integer().references(Compartments, #id)();
  IntColumn get equipmentId => integer().references(EquipmentItems, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Quiz Results (for progress tracking)
class QuizResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get quizType => text()();      // 'compartment', 'image_recognition'
  IntColumn get score => integer()();
  IntColumn get total => integer()();
  // null = all-vehicles mode; non-null = single-vehicle quiz
  IntColumn get vehicleId => integer().nullable().references(Vehicles, #id)();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}

// Vehicles table also needs updatedAt for Supabase last-write-wins sync (§18)
// Add to Vehicles: DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
```

---

## 5. Domain Entities

All entities are **pure Dart**, use `freezed` for immutability:

```dart
@freezed
class Vehicle with _$Vehicle {
  const factory Vehicle({
    required int id,
    required String name,
    required String type,
    String? licensePlate,
    String? imagePath,
    required DateTime createdAt,
  }) = _Vehicle;
}

@freezed
class EquipmentItem with _$EquipmentItem {
  const factory EquipmentItem({
    required int id,
    required String name,
    required List<String> equipmentFunctions,   // EquipmentFunction tag strings
    required List<String> deploymentScenarios,  // DeploymentScenario tag strings
    required String description,
    String? imagePath,
    String? trainingUrl,
    String? libraryEquipmentId,
    required bool isCustom,
    required Map<String, dynamic> extraAttributes,
    required DateTime updatedAt,
  }) = _EquipmentItem;
}

@freezed
class Compartment with _$Compartment {
  const factory Compartment({
    required int id,
    required int vehicleId,
    required String label,
    required int position,
    // Optional grid hints for drag-drop schematic layout
    int? gridRow,
    int? gridCol,
    required int gridColSpan,
    required DateTime updatedAt,
  }) = _Compartment;
}

@freezed
class EquipmentAssignment with _$EquipmentAssignment {
  const factory EquipmentAssignment({
    required int id,
    required int compartmentId,
    required int equipmentId,
    required int quantity,
  }) = _EquipmentAssignment;
}
```

---

## 6. Repository Pattern

Define abstract interfaces in `domain/repositories/`, implement in `data/repositories/`.

```dart
// domain/repositories/vehicle_repository.dart
abstract class VehicleRepository {
  Future<List<Vehicle>> getAll();
  Future<Vehicle> getById(int id);
  Future<int> insert(Vehicle vehicle);
  Future<void> update(Vehicle vehicle);
  Future<void> delete(int id);
}

// data/repositories/vehicle_repository_impl.dart
class VehicleRepositoryImpl implements VehicleRepository {
  final VehicleDao _dao;
  VehicleRepositoryImpl(this._dao);
  // ... implement all methods, map Drift DataClass ↔ Entity
}
```

Apply the same pattern for: `EquipmentRepository`, `CompartmentRepository`, `AssignmentRepository`.

---

## 7. Riverpod Providers

Use `@riverpod` code generation throughout.

```dart
// features/vehicle/presentation/providers/vehicle_providers.dart

@riverpod
VehicleRepository vehicleRepository(Ref ref) {
  final dao = ref.watch(vehicleDaoProvider);
  return VehicleRepositoryImpl(dao);
}

@riverpod
Future<List<Vehicle>> vehicleList(Ref ref) {
  return ref.watch(vehicleRepositoryProvider).getAll();
}

// For form state use StateNotifier or AsyncNotifier
@riverpod
class VehicleFormNotifier extends _$VehicleFormNotifier {
  @override
  VehicleFormState build() => VehicleFormState.initial();
  // update / submit methods
}
```

---

## 8. Feature: Vehicle Fleet Management

**Screens:**
- `VehicleListScreen` – list all vehicles with image, name, type
- `VehicleDetailScreen` – show compartments, tap to see assigned equipment
- `VehicleFormScreen` – create / edit vehicle (name, type, plate, image)
- `CompartmentManagerScreen` – add/remove/reorder compartments

---

## 9. Feature: Equipment Database

**Screens:**
- `EquipmentListScreen` – filterable by category with search bar
- `EquipmentDetailScreen` – image, description, attributes, training link
- `EquipmentFormScreen` – create / edit equipment item

### Equipment classification: two independent tag systems

Equipment is classified along **two orthogonal axes**. Both are stored as JSON arrays in the database and the JSON library.

#### Equipment Functions (what the device technically does)

```dart
enum EquipmentFunction {
  rettung, brand, wasser, pumpen, beleuchtung, strom, lueftung,
  kommunikation, messgeraete, absperren, logistik, fuehrung,
  psa, armaturen, abdichten, dekon, handwerkzeug;

  String get label => switch (this) {
    rettung       => 'Rettung',
    brand         => 'Brand',
    wasser        => 'Wasser',
    pumpen        => 'Pumpen',
    beleuchtung   => 'Beleuchtung',
    strom         => 'Strom / Energie',
    lueftung      => 'Lüftung',
    kommunikation => 'Kommunikation',
    messgeraete   => 'Messgeräte',
    absperren     => 'Absperren',
    logistik      => 'Logistik',
    fuehrung      => 'Führung',
    psa           => 'Persönliche Schutzausrüstung',
    armaturen     => 'Armaturen / Kupplungen',
    abdichten     => 'Abdichten / Leckdichtung',
    dekon         => 'Dekontamination',
    handwerkzeug  => 'Handwerkzeug',
  };
}
```

#### Deployment Scenarios (in which incident type the equipment is used)

```dart
enum DeploymentScenario {
  // Brand
  brandInnen, brandAussen, brandVegetation, brandFahrzeug,
  // Verkehrsunfall
  vuPkw, vuLkw, vuBus, vuBahn,
  // Technische Hilfeleistung
  thKlemmt, thSturm, thBaum, thEinsturz, thTier, thWasser,
  // Gefahrgut
  gefahrgutMessen, gefahrgutAbdichten, gefahrgutPumpen,
  gefahrgutAuffangen, gefahrgutDekon,
  // Wasser / Sonstiges
  hochwasser, wasserrettung, absturzsicherung, hoehenrettung;

  String get label => switch (this) {
    brandInnen          => 'Brand Innen',
    brandAussen         => 'Brand Außen',
    brandVegetation     => 'Vegetationsbrand',
    brandFahrzeug       => 'Fahrzeugbrand',
    vuPkw               => 'VU PKW',
    vuLkw               => 'VU LKW',
    vuBus               => 'VU Bus',
    vuBahn              => 'VU Bahn / Schiene',
    thKlemmt            => 'TH – Person eingeklemmt',
    thSturm             => 'TH – Sturm',
    thBaum              => 'TH – Baum',
    thEinsturz          => 'TH – Einsturz',
    thTier              => 'TH – Tier in Not',
    thWasser            => 'TH – Wasser',
    gefahrgutMessen     => 'Gefahrgut – Messen / Erkunden',
    gefahrgutAbdichten  => 'Gefahrgut – Abdichten',
    gefahrgutPumpen     => 'Gefahrgut – Umpumpen',
    gefahrgutAuffangen  => 'Gefahrgut – Auffangen',
    gefahrgutDekon      => 'Gefahrgut – Dekontamination',
    hochwasser          => 'Hochwasser',
    wasserrettung       => 'Wasserrettung',
    absturzsicherung    => 'Absturzsicherung',
    hoehenrettung       => 'Höhenrettung',
  };
}
```

**Design rules:**
- Equipment may have **multiple deployment scenarios** and **multiple functions**.
- Scenario and function identifiers are **stable** – never change a value once published.
- The JSON library (§24–§25) uses the UPPER_SNAKE_CASE string form of these enums.
- The app filters the equipment list by either axis independently or combined.

---

## 10. Feature: Equipment Assignment

- Assign equipment items to compartments of a vehicle
- Each assignment stores a quantity
- Visual grid or list view per compartment
- Quick-add via search-and-select bottom sheet

---

## 11. Game Mode 1 – Compartment Quiz (Which Compartment?)

### 11a – Multiple Choice

- Show equipment image + name
- Player selects the correct compartment from 4 options
- Wrong answers are highlighted, correct answer shown
- Score tracked per session

### 11b – Drag & Drop Mode

- Show a vehicle schematic with labeled compartment zones
- Equipment cards appear one at a time; player drags into correct compartment
- Use Flutter `Draggable<EquipmentItem>` + `DragTarget<EquipmentItem>`
- Animate correct/wrong drops

```dart
Draggable<EquipmentItem>(
  data: equipment,
  feedback: EquipmentCard(equipment: equipment, isDragging: true),
  child: EquipmentCard(equipment: equipment),
),

DragTarget<EquipmentItem>(
  onAcceptWithDetails: (details) => _handleDrop(details.data, compartment),
  builder: (context, candidates, rejected) => CompartmentZone(
    label: compartment.label,
    isHighlighted: candidates.isNotEmpty,
  ),
),
```

---

## 12. Game Mode 2 – Image Recognition Quiz

- Display one equipment image
- Show 4–6 answer choices (all from local DB)
- Choices generated: 1 correct + N-1 random wrong items from same category
- Timeout option per question (configurable)
- Results screen with score and review

---

## 13. Game Mode 3 – Vehicle Deployment Mode

- User selects one or more vehicles
- App computes **combined equipment inventory** of all selected vehicles
- Display result grouped by category (TH, Brand, Gefahrgut …)
- Show quantity per item across all selected vehicles
- Useful for planning multi-vehicle deployments

---

## 14. Excel / CSV Import

Use `file_picker` + `excel` package.

### Expected columns (case-insensitive):

| Column | Required |
|---|---|
| `vehicle` | ✓ |
| `compartment` | ✓ |
| `equipment` | ✓ |
| `category` | ✓ |
| `description` | |
| `quantity` | |
| `image` | (file name, matched to imported images) |

### Import Flow:

1. User picks Excel/CSV file
2. Parse rows with `excel` package
3. Upsert vehicles → compartments → equipment → assignments in a Drift transaction
4. Report success/error count to user via SnackBar / dialog

```dart
Future<ImportResult> importFromExcel(Uint8List bytes) async {
  final excel = Excel.decodeBytes(bytes);
  // iterate sheets and rows, call repository upsert methods inside a transaction
}
```

---

## 15. Navigation (GoRouter)

```dart
final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
  GoRoute(path: '/vehicles', builder: (_, __) => const VehicleListScreen()),
  GoRoute(path: '/vehicles/:id', builder: (_, state) => VehicleDetailScreen(id: int.parse(state.pathParameters['id']!))),
  GoRoute(path: '/vehicles/:id/compartments', builder: (_, state) => CompartmentManagerScreen(vehicleId: int.parse(state.pathParameters['id']!))),
  GoRoute(path: '/equipment', builder: (_, __) => const EquipmentListScreen()),
  GoRoute(path: '/equipment/:id', builder: (_, state) => EquipmentDetailScreen(id: int.parse(state.pathParameters['id']!))),
  GoRoute(path: '/game', builder: (_, __) => const GameMenuScreen()),
  GoRoute(path: '/game/compartment-quiz', builder: (_, __) => const CompartmentQuizScreen()),
  GoRoute(path: '/game/drag-drop', builder: (_, __) => const DragDropScreen()),
  GoRoute(path: '/game/image-quiz', builder: (_, __) => const ImageRecognitionQuizScreen()),
  GoRoute(path: '/game/deployment', builder: (_, __) => const DeploymentModeScreen()),
  GoRoute(path: '/import', builder: (_, __) => const ImportScreen()),
  GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
]);
```

---

## 16. Home Screen

Display a dashboard with:
- Quick stats: vehicle count, equipment count
- Navigation cards to: Fleet, Equipment DB, Games, Import
- Recent quiz score summary

---

## 17. Offline First (Priority #1)

- All data stored locally in Drift/SQLite
- App must be **fully functional with no network connection**
- Supabase sync is strictly **optional** and runs in background when online
- On first launch, pre-seed database with sample vehicles and equipment
- Import always writes to local DB first

---

## 18. Optional Supabase Sync

- Mirror tables: `vehicles`, `equipment_items`, `compartments`, `equipment_assignments`
- Use `supabase_flutter` package
- Sync strategy: **last-write-wins** with `updated_at` timestamps
- Auth: email/password or anonymous session
- Only sync if user explicitly enables it in Settings

---

## 19. UI / UX Guidelines

- Use `Material 3` design (`useMaterial3: true`)
- Primary color: **red** (`Colors.red.shade700`) — firefighter theme
- Dark mode support via `ThemeData` brightness
- German locale (`de_DE`) for all UI labels
- All user-facing strings must be in German
- Consistent `AppBar` with back navigation via GoRouter
- Responsive layout: use `LayoutBuilder` / `AdaptiveScaffold` for tablet/web

---

## 20. Code Standards

- All new files must include a header doc comment describing the file's purpose
- Use `freezed` for all domain entities and state classes
- Use `@riverpod` code generation — no manual `StateProvider` unless trivial
- Each use case is a single class with a `call()` method
- DAOs return Drift `DataClass` objects; repositories map them to domain entities
- No business logic in widgets; widgets call providers only
- Unit test use cases and repositories; widget tests for game screens
- Use `logger` package for structured logging (no `print()`)
- All async operations must handle errors with `AsyncValue` in Riverpod

---

## 21. pubspec.yaml Dependencies (starting point)

```yaml
dependencies:
  flutter:
    sdk: flutter
  # State
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  # Database
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0
  # Navigation
  go_router: ^14.0.0
  # Models
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
  # UI / Files
  file_picker: ^8.0.0
  image_picker: ^1.1.0
  cached_network_image: ^3.3.0
  # Import
  excel: ^4.0.0
  # Cloud (optional)
  supabase_flutter: ^2.5.0
  # Localisation (German locale)
  intl: ^0.19.0
  # Utils
  logger: ^2.4.0
  uuid: ^4.4.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  build_runner: ^2.4.0
  drift_dev: ^2.18.0
  riverpod_generator: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  custom_lint: ^0.6.0
  riverpod_lint: ^2.3.0
```

---

## 22. Code Generation

Always run after modifying annotated files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

> `flutter pub run` is deprecated as of Dart 2.18 — always use `dart run`.

---

## 23. Key Implementation Notes

1. **Drift database** must be a singleton, provide via Riverpod using `@Riverpod(keepAlive: true)`
2. **Image storage**: save images to app documents directory; store only the relative path in DB
3. **Quiz answer generation**: pull N random items from same category excluding the correct answer; shuffle all options
4. **Drag & Drop**: track `isDraggingOver` state per compartment in a local `StateProvider` for visual feedback
5. **Deployment Mode**: aggregate assignments by `equipmentId` across all selected vehicles; group result by `category`
6. **Import transaction**: wrap entire Excel import in a single Drift `transaction()` to ensure atomicity
7. **Web support**: use `drift/web.dart` with `WasmDatabase` for web builds — requires a conditional database factory: `DatabaseConnection.fromExecutor(isWeb ? WasmDatabase(...) : NativeDatabase(...))`
8. **Image-path resolution**: check the path prefix to determine the rendering widget — `assets/` prefix → `Image.asset()`; all other paths (user-captured, in appDocDir) → `Image.file()`
9. **Library seeding**: on first launch, run an idempotent upsert from the JSON equipment library into `EquipmentItems`. Only insert rows where `libraryEquipmentId` is not yet present.
10. **Custom import items**: when an Excel row's equipment name cannot be resolved via `aliases.json`, create an `EquipmentItem` with `isCustom = true` and `libraryEquipmentId = null`. Show a post-import review prompt listing all custom-created items. The `EquipmentDetailScreen` shows a "Mit Bibliothekseintrag verknüpfen" action for custom items.

---

## 24. Equipment Content Library (JSON-based)

The app ships with a **structured equipment knowledge base** stored as JSON files.

This library provides:

- device descriptions
- technical specifications
- operation instructions
- images
- manufacturer references
- training information

The library is **independent of vehicles** and represents the canonical source for equipment knowledge.

### Folder Structure

assets/equipment_library/

  metadata.json

  equipment/
    fire_extinguisher.json
    hydraulic_spreader.json
    chainsaw.json
    portable_generator.json

  manufacturers/
    rosenbauer.json
    ziegler.json
    magirus.json

  images/
    equipment/
      fire_extinguisher.webp
      hydraulic_spreader.webp

    manufacturers/
      rosenbauer_spreader.webp

---

## 25. Equipment JSON Schema

Example structure for an equipment definition:

```json
{
  "id": "hydraulischer_spreizer",
  "name": "Hydraulischer Spreizer",
  "short_name": "Spreizer",
  "equipment_functions": ["RETTUNG"],
  "deployment_scenarios": ["VU_PKW", "VU_LKW", "TH_KLEMMT"],
  "description": "Hydraulisches Rettungsgerät zum Spreizen von Fahrzeugteilen bei Verkehrsunfällen.",
  "technical_data": {
    "max_spreading_force_kN": 720,
    "weight_kg": 18.5,
    "operating_pressure_bar": 700
  },
  "typical_use": [
    "Spreizen eingeklemmter Fahrzeugtüren und -dächer",
    "Schaffung von Zugangswegen zu eingeklemmten Personen"
  ],
  "training_questions": [
    "Wie wird der Spreizer korrekt angesetzt?",
    "Welcher Betriebsdruck ist für hydraulische Rettungsgeräte genormt (700 bar)?"
  ],
  "images": [],
  "manuals": [],
  "source": "equipment_library_v1"
}
```

Rules:

- `id` must be **stable and never change once published**
- names may change, IDs must remain stable
- the JSON schema must remain backward compatible

---

## 26. Equipment Name Resolution (Excel Import)

Excel imports may contain **different naming variations**.

Example:

Hydr. Spreizer  
Spreizer  
Rettungsspreizer  
Hydraulic Spreader  

These must resolve to a canonical equipment id:

```
hydraulic_spreader
```

Alias mapping file:

```
assets/equipment_library/aliases.json
```

Example:

```json
{
  "aliases": {
    "hydraulic_spreader": [
      "Hydr. Spreizer",
      "Spreizer",
      "Rettungsspreizer",
      "Hydraulic Spreader"
    ],
    "fire_extinguisher": [
      "Feuerlöscher",
      "ABC Löscher",
      "Handfeuerlöscher"
    ]
  }
}
```

Import pipeline:

Excel Row  
↓  
Normalize Text  
↓  
Resolve Equipment ID via alias mapping  
↓  
Match with Equipment Library  
↓  
Insert / Upsert into local database

---

## 27. Manufacturer Support

Some equipment exists in **multiple manufacturer variants**.

Examples:

- Rosenbauer
- Magirus
- Ziegler
- Holmatro
- Lukas

Manufacturers are optional metadata.  
If no manufacturer is specified, the app uses the **default equipment image**.

Example manufacturer definition:

```json
{
  "id": "rosenbauer",
  "name": "Rosenbauer",
  "website": "https://www.rosenbauer.com",
  "products": {
    "hydraulic_spreader": {
      "model": "SP49",
      "image": "rosenbauer_sp49.webp",
      "product_url": "https://www.rosenbauer.com/sp49"
    }
  }
}
```

Manufacturers may provide:

- product image
- product model
- external website link

---

## 28. Image Strategy

All images must follow these rules:

Format  
- WebP only

Resolution  
- max: 1024px  
- thumbnail: 256px  

Folder structure:

assets/images/equipment/

Use:

- `Image.asset()` for local images
- `cached_network_image` only for remote images

Images should be optimized to reduce APK size.

---

## 29. Equipment Library Versioning

The equipment content library must support **versioning**.

metadata.json example:

```json
{
  "version": "1.0.0",
  "equipment_count": 120,
  "last_updated": "2026-03-01"
}
```

Future updates may be delivered via:

- GitHub releases
- Supabase storage
- CDN download

When a newer library version is detected, the app may offer an **optional update**.

---

## 30. Equipment Classification Reference

The canonical classification system is defined in **§9**. This section is a quick alias reference.

**Do not use a single-category field.** Always use the two-axis system:
- `equipment_functions` → list of `EquipmentFunction` values (§9)
- `deployment_scenarios` → list of `DeploymentScenario` values (§9)

Both fields are stored as JSON arrays of UPPER_SNAKE_CASE strings in the DB and in the JSON library files.

---

## 31. Future Game Mode – Equipment Recognition


Possible additional game mode:

The user sees:

- a description  
- or technical specification  

Example:

"700 bar hydraulisches Rettungsgerät zum Spreizen von Fahrzeugteilen"

The user must identify the correct equipment.

Answer:

Hydraulischer Spreizer

This mode improves deeper learning of equipment capabilities rather than visual recognition alone.

---

## 32. Equipment Classification Model (Scenarios vs Functions)

Equipment must be classified using **two separate classification systems**.

This prevents mixing **deployment scenarios** with **technical equipment functions**.

The system enables:

- scenario-based training (e.g. VU_LKW)
- virtual vehicle unloading
- intelligent equipment filtering
- future readiness analysis for vehicles

### 1. Deployment Scenarios (Use Cases)

Deployment scenarios describe **in which type of incident the equipment is used**.

Examples:

Brand:

BRAND_INNEN  
BRAND_AUSSEN  
BRAND_VEGETATION  
BRAND_FAHRZEUG  

Traffic accidents:

VU_PKW  
VU_LKW  
VU_BUS  
VU_BAHN  

Technical rescue:

TH_KLEMMT  
TH_STURM  
TH_BAUM  
TH_EINSTURZ  
TH_TIER  
TH_WASSER  

Water related incidents:

HOCHWASSER  
WASSERRETTUNG  

Hazmat:

GEFAHRGUT_MESSEN  
GEFAHRGUT_ABDICHTEN  
GEFAHRGUT_PUMPEN  

Special rescue:

ABSTURZSICHERUNG  
HOEHENRETTUNG  

These scenario tags are used for:

- **virtual unloading exercises**
- **scenario-based quizzes**
- **vehicle deployment analysis**

Example:

If a user selects the scenario:

```
VU_LKW
```

the app must show all equipment items whose `deployment_scenarios` contain this tag.

---

### 2. Equipment Functions (Technical Category)

Equipment functions describe **what the device technically does**, independent of the scenario.

Recommended base categories:

RETTUNG  
BRAND  
WASSER  
PUMPEN  
BELEUCHTUNG  
STROM  
LUEFTUNG  
KOMMUNIKATION  
MESSGERAETE  
ABSPERREN  
LOGISTIK  
FUEHRUNG  

These are primarily used for:

- equipment database filtering
- quiz generation
- logical grouping in the UI

---

### 3. Equipment JSON Example

Equipment definitions in the equipment library must support both classifications.

Example:

```json
{
  "id": "hydraulic_spreader",
  "name": "Hydraulischer Spreizer",

  "equipment_functions": [
    "RETTUNG"
  ],

  "deployment_scenarios": [
    "VU_PKW",
    "VU_LKW",
    "TH_KLEMMT"
  ]
}
```

Example:

```json
{
  "id": "ventilation_fan",
  "name": "Überdrucklüfter",

  "equipment_functions": [
    "LUEFTUNG"
  ],

  "deployment_scenarios": [
    "BRAND_INNEN"
  ]
}
```

---

### 4. Design Rules

1. Equipment may have **multiple deployment scenarios**.
2. Equipment may have **multiple technical functions**, but usually only one primary function.
3. Scenario tags must remain **stable identifiers**.
4. UI labels for scenarios must be localized in German.
5. Scenario tags are intended to support **training simulations** and **virtual equipment selection**.

This classification model is the foundation for:

- the training game modes
- the virtual vehicle unloading exercises
- future capability analysis of fire vehicles.

---

## 33. Vehicle Data Source: JSON Library per Vehicle

Each vehicle's equipment data is stored as two JSON files in:

```
assets/equipment_library/vehicles/{vehicle_id}/
  vehicle.json          # vehicle metadata (name, type, deployment scenarios)
  loading_plan.json     # compartment list with equipment_id + quantity per slot
  equipment/
    {equipment_id}.json # one file per unique equipment item (knowledge only)
```

**Key separation:** equipment JSON files contain **only knowledge** (description, functions, scenarios, training questions). Quantity and compartment location are **exclusively** in `loading_plan.json`.

### `loading_plan.json` structure

```json
{
  "vehicle_id": "ab_g",
  "vehicle_name": "AB-G (Abrollbehälter Gefahrgut)",
  "vehicle_type": "AB-G",
  "compartments": [
    {
      "id": "tw3_umpumpen",
      "label": "TW-3 Umpumpen",
      "position": 8,
      "items": [
        { "equipment_id": "uebergangsstueck_vk50_vk50", "quantity": 2 }
      ]
    }
  ]
}
```

### Seeding from Library on First Launch

On first launch the app runs an idempotent upsert:
1. Read all `vehicle.json` + `loading_plan.json` files from assets
2. For each compartment item: look up `{equipment_id}.json`, insert into `EquipmentItems` if `libraryEquipmentId` not yet present
3. Create `Vehicles`, `Compartments`, and `EquipmentAssignments` rows from the loading plan
4. `isCustom = false`, `libraryEquipmentId = equipment_id` for all seeded items

### AB-G: Initial Dataset (v1.0.0)

The first complete vehicle dataset is the **AB-G (Abrollbehälter Gefahrgut)**:
- Source: Beladeliste AB-G, Stand 2025-01-29
- **257 unique equipment items** across 13 compartments (Dach, G1–G4, Heck, TW-1 through TW-6)
- Generated by `tools/generate_ab_g_data.py`

---

## 34. Admin Role (Deferred – v2)

Admin functionality is **not implemented in v1**. All users have full access to all features.

**Planned for v2:**
- PIN-protected admin mode in Settings
- Admin-only actions: delete vehicles, bulk import, link custom items to library
- Future: Supabase role claims for multi-user/team setups

---

## 35. Settings Screen

`SettingsScreen` (route `/settings`) must contain:

| Setting | Description |
|---|---|
| Dark / Light Mode | Toggle theme brightness |
| Supabase Sync | Enable / disable cloud sync |
| Supabase URL | Server URL (only shown when sync is enabled) |
| Supabase Anon Key | Credential (only shown when sync is enabled) |
| Equipment Library | Installed version + "Nach Updates suchen" button |
| App Version | App version and build number (read-only) |
