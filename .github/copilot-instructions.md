# Feuerwehr Learning App – Copilot Agent Instructions

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
| Drag & Drop | `flutter_draggable_gridview` or native Flutter `Draggable` / `DragTarget` |
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
  TextColumn get category => text()();      // TH, Brand, Gefahrgut, Sonstiges
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get trainingUrl => text().nullable()();
  TextColumn get extraAttributesJson => text().withDefault(const Constant('{}'))(); // JSON map for extendable attributes
}

// Compartments
class Compartments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  TextColumn get label => text()(); // G1, G2, G3, G4, Dach, Heck
  IntColumn get position => integer().withDefault(const Constant(0))();
}

// Equipment Assignments
class EquipmentAssignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get compartmentId => integer().references(Compartments, #id)();
  IntColumn get equipmentId => integer().references(EquipmentItems, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
}

// Quiz Results (for progress tracking)
class QuizResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get quizType => text()();      // 'compartment', 'image_recognition'
  IntColumn get score => integer()();
  IntColumn get total => integer()();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}
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
    required String category,
    required String description,
    String? imagePath,
    String? trainingUrl,
    required Map<String, dynamic> extraAttributes,
  }) = _EquipmentItem;
}

@freezed
class Compartment with _$Compartment {
  const factory Compartment({
    required int id,
    required int vehicleId,
    required String label,
    required int position,
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

**Categories enum:**

```dart
enum EquipmentCategory {
  technischeHilfeleistung,
  brandeinsatz,
  gefahrguteinsatz,
  rettung,
  sonstiges;

  String get label => switch (this) {
    technischeHilfeleistung => 'Technische Hilfeleistung',
    brandeinsatz => 'Brandeinsatz',
    gefahrguteinsatz => 'Gefahrguteinsatz',
    rettung => 'Rettung',
    sonstiges => 'Sonstiges',
  };
}
```

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
  # Utils
  logger: ^2.4.0
  uuid: ^4.4.0

dev_dependencies:
  flutter_test:
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
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 23. Key Implementation Notes

1. **Drift database** must be a singleton, provide via Riverpod using `@Riverpod(keepAlive: true)`
2. **Image storage**: save images to app documents directory; store only the relative path in DB
3. **Quiz answer generation**: pull N random items from same category excluding the correct answer; shuffle all options
4. **Drag & Drop**: track `isDraggingOver` state per compartment in a local `StateProvider` for visual feedback
5. **Deployment Mode**: aggregate assignments by `equipmentId` across all selected vehicles; group result by `category`
6. **Import transaction**: wrap entire Excel import in a single Drift `transaction()` to ensure atomicity
7. **Web support**: use `drift/web.dart` with `WasmDatabase` for web builds
8. **Seed data**: provide at least 2 sample vehicles (HLF 20, TLF 3000) each with 4 compartments and 10+ equipment items so the app is usable immediately after install
