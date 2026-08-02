/// geteilter_typ_ui_test.dart – Die Oberfläche zum geteilten Typ-Bestand
/// (Nutzerkonzept Stufe ②, Issue #99).
///
/// Der Sync stand schon; sichtbar war davon nichts. Diese Tests halten die
/// drei Bedienstellen fest, die dazugekommen sind:
///
///   1. Jede Pflege über die Repository-Schicht ist eine Änderung am TYP und
///      wird zum Verteilen vorgemerkt (Seeder und Import gehen bewusst am
///      Repository vorbei und bleiben still).
///   2. Das Bearbeiten-Formular darf nichts verlieren, was es gar nicht
///      anzeigt — seit Stufe ② verteilt sich so ein Verlust an die ganze Wehr.
///   3. Entfernen fragt vorher, was daran hängt, und sagt „löschen" oder
///      „archivieren" ehrlich an.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/router/app_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_item.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_detail_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_form_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  // ── 1. Vormerken ────────────────────────────────────────────────────────

  group('Pflege am Gerät ist Pflege am geteilten Typ', () {
    test('anlegen und ändern werden zum Verteilen vorgemerkt', () async {
      final repo = EquipmentRepositoryImpl(db.equipmentDao);
      final id = await repo.insert(EquipmentItem(
        id: 0,
        name: 'Kübelspritze',
        equipmentFunctions: const [],
        deploymentScenarios: const [],
        description: '',
        isCustom: true,
        extraAttributes: const {},
        updatedAt: DateTime.now(),
      ));
      expect((await db.equipmentDao.getById(id))?.typeDirty, isTrue,
          reason: 'ein neuer Typ gehört in den Bestand der Gesamtwehr');

      // Abgeräumt, wie es der Push tut — und dann eine Änderung.
      await db.equipmentDao.patchEquipment(
          id,
          const EquipmentItemsCompanion(
            typeDirty: Value(false),
            remoteTypeId: Value('typ-1'),
          ));
      final gespeichert = (await repo.getById(id))!;
      await repo.update(gespeichert.copyWith(description: 'mit Pumpe'));

      final zeile = await db.equipmentDao.getById(id);
      expect(zeile?.typeDirty, isTrue);
      expect(zeile?.remoteTypeId, 'typ-1',
          reason: 'die Verbindung zum geteilten Typ darf eine Bearbeitung '
              'überleben');
    });

    test('der Seeder-Weg am Repository vorbei bleibt still', () async {
      // 110 Katalog-Geräte liegen auf jedem Gerät. Würden sie vorgemerkt,
      // schöbe der erste Start den ganzen Katalog Zeile für Zeile hoch.
      final id = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: 'C-Rohr'));
      expect((await db.equipmentDao.getById(id))?.typeDirty, isFalse);
    });
  });

  // ── 2. Nichts verlieren ─────────────────────────────────────────────────

  testWidgets('Bearbeiten verliert nicht, was im Formular kein Feld hat',
      (tester) async {
    // Das Formular zeigt Name, Beschreibung, URL, Bild, Funktionen und
    // Szenarien — mehr nicht. Trainingsfragen, typische Verwendung,
    // technische Daten und die Katalog-Herkunft stehen in keinem Feld.
    final id = await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(
      name: 'Wärmebildkamera',
      libraryEquipmentId: const Value('std_wbk'),
      isCustom: const Value(false),
      trainingQuestionsJson: const Value('["Wofür?"]'),
      typicalUseJson: const Value('["Personensuche"]'),
      extraAttributesJson: const Value('{"Gewicht":"1,2 kg"}'),
    ));

    await tester.pumpWidget(
        buildTestApp(db: db, home: EquipmentFormScreen(editId: id)));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Name*'), 'Wärmebildkamera 2');
    // Der Knopf steht unter der Kante — im flachen Prüfstand ist das die
    // Regel, nicht die Ausnahme (AGENTS.md § Stolperfallen).
    await tester.dragUntilVisible(
        find.text('Speichern'), find.byType(ListView), const Offset(0, -120));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    final zeile = (await db.equipmentDao.getById(id))!;
    expect(zeile.name, 'Wärmebildkamera 2');
    expect(zeile.trainingQuestionsJson, '["Wofür?"]');
    expect(zeile.typicalUseJson, '["Personensuche"]');
    expect(zeile.extraAttributesJson, '{"Gewicht":"1,2 kg"}');
    expect(zeile.libraryEquipmentId, 'std_wbk',
        reason: 'die Katalog-Herkunft ist die Kennung, über die der Server '
            'Typen zusammenführt');
    expect(zeile.isCustom, isFalse);
    await endTestApp(tester);
  });

  // ── 3. Herkunft anzeigen ────────────────────────────────────────────────

  group('die Detailseite sagt, wie weit eine Änderung reicht', () {
    Future<void> zeige(WidgetTester tester, int id,
        {bool canEdit = true}) async {
      await tester.pumpWidget(buildTestApp(
        db: db,
        home: EquipmentDetailScreen(equipmentId: id),
        overrides: [canEditProvider.overrideWithValue(canEdit)],
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('verbunden: geteilter Bestand der Gesamtwehr', (tester) async {
      final id = await db.equipmentDao.insertEquipment(
          EquipmentItemsCompanion.insert(
              name: 'Halligan-Tool', remoteTypeId: const Value('typ-1')));
      await zeige(tester, id);
      expect(find.textContaining('Geteilter Bestand der Gesamtwehr'),
          findsOneWidget);
      await endTestApp(tester);
    });

    testWidgets('vorgemerkt: die Änderung ist noch nicht draußen',
        (tester) async {
      final id = await db.equipmentDao.insertEquipment(
          EquipmentItemsCompanion.insert(
        name: 'Halligan-Tool',
        remoteTypeId: const Value('typ-1'),
        typeDirty: const Value(true),
      ));
      await zeige(tester, id);
      expect(find.textContaining('noch nicht verteilt'), findsOneWidget);
      await endTestApp(tester);
    });

    testWidgets('ohne Gesamtwehr steht dort gar nichts', (tester) async {
      final id = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: 'Leitkegel'));
      await zeige(tester, id);
      expect(find.textContaining('Gesamtwehr'), findsNothing);
      await endTestApp(tester);
    });

    testWidgets('ohne Schreibrecht gibt es kein Entfernen', (tester) async {
      final id = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: 'Leitkegel'));
      await zeige(tester, id, canEdit: false);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await endTestApp(tester);
    });
  });

  // ── 4. Entfernen ────────────────────────────────────────────────────────

  group('Entfernen', () {
    late int id;

    setUp(() async {
      id = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: 'Leitkegel'));
    });

    // Mit dem ECHTEN Router: Das Entfernen poppt am Ende die Seite weg, und
    // das Menü liegt in der ShellRoute — beides gibt es in einem flachen
    // Prüfstand nicht, und genau dort saßen #79 und #96.
    Future<void> oeffneDialog(WidgetTester tester) async {
      await tester.pumpWidget(buildRoutedTestApp(db: db));
      await tester.pumpAndSettle();
      containerOf(tester).read(routerProvider).go('/equipment/$id');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gerät entfernen'));
      await tester.pumpAndSettle();
    }

    testWidgets('ohne geteilten Bestand wird schlicht gelöscht',
        (tester) async {
      await oeffneDialog(tester);
      expect(find.text('Gerät löschen?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect(await db.equipmentDao.getById(id), isNull);
      await endTestApp(tester);
    });

    testWidgets('Abbrechen löscht nichts', (tester) async {
      await oeffneDialog(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
      await tester.pumpAndSettle();
      expect(await db.equipmentDao.getById(id), isNotNull);
      await endTestApp(tester);
    });

    testWidgets('was hier dranhängt, steht vorher im Dialog', (tester) async {
      // Der teure Teil des Entfernens ist die Kaskade: Zuordnungen und
      // Exemplare samt Prüfhistorie gehen mit. Das muss dastehen, BEVOR
      // jemand auf Löschen tippt.
      final vehicleId = await db.vehicleDao
          .insertVehicle(VehiclesCompanion.insert(name: 'LF', type: 'LF'));
      final fach = await db.compartmentDao.insertCompartment(
          CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
      await db.assignmentDao.insertAssignment(
          EquipmentAssignmentsCompanion.insert(
              compartmentId: fach, equipmentId: id));
      await db.inspectionDao.insertInstance(
          EquipmentInstancesCompanion.insert(equipmentId: id));

      await oeffneDialog(tester);
      expect(find.textContaining('1 Zuordnung'), findsOneWidget);
      expect(find.textContaining('1 Exemplar'), findsOneWidget);
      expect(find.textContaining('Prüfhistorie'), findsOneWidget);
      await endTestApp(tester);
    });
  });
}
