/// fahrzeug_entfernen_test.dart – Ein einmal angelegtes Fahrzeug wieder
/// loswerden (Issue #127).
///
/// Warum als Widget-Test: Der Defekt war keine kaputte Logik.
/// `VehicleRepository.delete(int)` gab es seit jeher — es rief sie nur kein
/// einziger Bildschirm auf. Eine FEHLENDE Bedienstelle kann nur ein Test
/// über die Oberfläche festhalten; ein Repository-Test wäre grün gewesen,
/// während im Gerätehaus ein Vertipper für immer stehen blieb.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/vehicle/domain/loesch_umfang.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_detail_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('der Satz vor dem Entfernen', () {
    test('nennt Fächer und Beladung mit richtiger Beugung', () {
      final text =
          fahrzeugEntfernenText(name: 'HLF 20', faecher: 1, beladung: 1);
      expect(text, contains('1 Fach '));
      expect(text, contains('1 Eintrag der Beladeliste'));

      final viele =
          fahrzeugEntfernenText(name: 'HLF 20', faecher: 18, beladung: 42);
      expect(viele, contains('18 Fächer'));
      expect(viele, contains('42 Einträge der Beladeliste'));
    });

    test('sagt dazu, dass die Geräte im Bestand bleiben', () {
      // Die eigentliche Entscheidungshilfe: Ohne diesen Satz liest sich das
      // Entfernen eines Fahrzeugs wie das Löschen des halben Bestands.
      final text =
          fahrzeugEntfernenText(name: 'HLF 20', faecher: 18, beladung: 42);
      expect(text, contains('Geräte selbst bleiben im Bestand'));
      expect(text, contains('Prüfhistorie'));
    });

    test('lässt weg, was es nicht gibt', () {
      final leer = fahrzeugEntfernenText(name: 'MTW', faecher: 0, beladung: 0);
      expect(leer, contains('Es hängt nichts daran.'));
      expect(leer, isNot(contains('Fach')));
      expect(leer, isNot(contains('Beladeliste')));

      final nurFaecher =
          fahrzeugEntfernenText(name: 'MTW', faecher: 3, beladung: 0);
      expect(nurFaecher, contains('3 Fächer'));
      expect(nurFaecher, isNot(contains('Beladeliste')));
    });

    test('warnt immer davor, dass es endgültig ist', () {
      for (final (f, b) in const [(0, 0), (1, 0), (0, 1), (18, 42)]) {
        expect(
          fahrzeugEntfernenText(name: 'HLF 20', faecher: f, beladung: b),
          contains('Rückgängig machen lässt sich das nicht.'),
          reason: '$f Fächer, $b Einträge',
        );
      }
    });
  });

  group('die Bedienstelle', () {
    late AppDatabase db;
    late int vehicleId;

    setUp(() async {
      db = createTestDatabase();
      vehicleId = await db.vehicleDao.insertVehicle(
          VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
      final fach = await db.compartmentDao.insertCompartment(
          CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G1'));
      await db.compartmentDao.insertCompartment(
          CompartmentsCompanion.insert(vehicleId: vehicleId, label: 'G2'));
      final geraet = await db.equipmentDao
          .insertEquipment(EquipmentItemsCompanion.insert(name: 'Leitkegel'));
      await db.assignmentDao.insertAssignment(
        EquipmentAssignmentsCompanion.insert(
            compartmentId: fach, equipmentId: geraet),
      );
    });

    tearDown(() => db.close());

    /// Eigener Prüfstand mit ECHTEM go_router statt `buildTestApp`.
    ///
    /// Nicht Bequemlichkeit, sondern der Kern der zweiten Hälfte: Nach dem
    /// Entfernen muss der Bildschirm die Liste zeigen. Bliebe er stehen,
    /// stünde da „Fahrzeug nicht gefunden" — der Screen hängt an einer
    /// Zeile, die es nicht mehr gibt. Mit einem nackten MaterialApp könnte
    /// man das gar nicht prüfen.
    Future<void> oeffne(WidgetTester tester,
        {bool darfBearbeiten = true}) async {
      final router = GoRouter(
        initialLocation: '/vehicles/detail',
        routes: [
          GoRoute(
            path: '/vehicles',
            builder: (_, _) => const Scaffold(body: Text('Fahrzeugliste')),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (_, _) => VehicleDetailScreen(vehicleId: vehicleId),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          if (!darfBearbeiten) canEditProvider.overrideWithValue(false),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('wer nicht bearbeiten darf, sieht sie nicht', (tester) async {
      await oeffne(tester, darfBearbeiten: false);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await endTestApp(tester);
    });

    testWidgets('die Rückfrage nennt, was mitgeht', (tester) async {
      await oeffne(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fahrzeug entfernen'));
      await tester.pumpAndSettle();

      expect(find.text('Fahrzeug entfernen?'), findsOneWidget);
      expect(find.textContaining('2 Fächer'), findsOneWidget);
      expect(find.textContaining('1 Eintrag der Beladeliste'), findsOneWidget);
      await endTestApp(tester);
    });

    testWidgets('Abbrechen lässt das Fahrzeug stehen', (tester) async {
      await oeffne(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fahrzeug entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(await db.vehicleDao.getById(vehicleId), isNotNull);
      await endTestApp(tester);
    });

    testWidgets('Entfernen löscht Fahrzeug, Fächer und Beladung',
        (tester) async {
      await oeffne(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fahrzeug entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Entfernen'));
      await tester.pumpAndSettle();

      expect(await db.vehicleDao.getById(vehicleId), isNull);
      // Und der Bildschirm bleibt nicht auf dem gelöschten Fahrzeug stehen.
      expect(find.text('Fahrzeugliste'), findsOneWidget);
      expect(find.text('Fahrzeug nicht gefunden.'), findsNothing);
      // Die Kaskade ist im Schema erklärt (ON DELETE CASCADE) — aber sie
      // wirkt nur, wenn SQLite `PRAGMA foreign_keys` an hat. Genau deshalb
      // steht sie hier und nicht bloß im Kommentar.
      expect(await db.compartmentDao.getByVehicle(vehicleId), isEmpty);
      expect(await db.assignmentDao.getByVehicle(vehicleId), isEmpty);
      await endTestApp(tester);
    });

    testWidgets('das Gerät selbst überlebt das Entfernen', (tester) async {
      await oeffne(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fahrzeug entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Entfernen'));
      await tester.pumpAndSettle();

      // Das ist die Zusage aus dem Dialogtext. Sie muss stimmen.
      final geraete = await db.equipmentDao.getAll();
      expect(geraete.map((g) => g.name), contains('Leitkegel'));
      await endTestApp(tester);
    });
  });
}
