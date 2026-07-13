/// import_wizard_widget_test.dart – Drives the 4-step import wizard UI:
/// file → column mapping → matching → apply, including the resolution sheet.
library;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/import/presentation/providers/import_wizard_providers.dart';
import 'package:fwapp/features/import/presentation/screens/import_wizard_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    // Known equipment so the matcher produces green rows.
    await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(name: 'Kübelspritze'));
    await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(name: 'Spineboard'));
  });

  tearDown(() => db.close());

  const csv = 'Gegenstand;Stückzahl;Lagerort\n'
      'Kübelspritze;1;G1\n'
      'Spineboard;2;G2\n'
      'Völlig Unbekanntes Spezialgerät;1;G2\n';

  testWidgets('kompletter Wizard-Durchlauf bis zum angewendeten Import',
      (tester) async {
    await tester.pumpWidget(
        buildTestApp(db: db, home: const ImportWizardScreen()));
    await tester.pumpAndSettle();

    // Schritt 0: Datei laden (der native FilePicker ist in Tests nicht
    // bedienbar → Datei direkt in den Notifier geben).
    expect(find.text('Datei auswählen'), findsOneWidget);
    final container = containerOf(tester);
    await container
        .read(importWizardProvider.notifier)
        .loadFile('beladeliste.csv', utf8.encode(csv));
    await tester.pumpAndSettle();

    // Schritt 1: Spalten wurden automatisch erkannt, Fahrzeug fehlt noch.
    expect(find.text('Erste Zeile ist Überschrift'), findsOneWidget);
    expect(find.text('Fahrzeugname *'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Fahrzeugname *'), 'LF 10');
    await tester.pumpAndSettle();
    // Vorschau zeigt die gemappten Zeilen.
    expect(find.text('Kübelspritze'), findsWidgets);
    // buildPreview lädt Alias-/Katalog-Assets (echtes I/O) — unter runAsync
    // ausführen, damit es nicht in der Fake-Async-Umgebung hängt.
    await tester.runAsync(
        () => container.read(importWizardProvider.notifier).buildPreview());
    await tester.pumpAndSettle();

    // Schritt 2: 2 grün erkannt, 1 rot (unbekannt).
    expect(find.text('2 erkannt'), findsOneWidget);
    expect(find.text('1 neu'), findsOneWidget);

    // Auflösungs-Sheet für den roten Eintrag: auf Überspringen stellen.
    await tester.tap(find.text('Völlig Unbekanntes Spezialgerät'));
    await tester.pumpAndSettle();
    expect(find.text('Als neues Gerät anlegen'), findsOneWidget);
    await tester.tap(find.text('Überspringen'));
    await tester.pumpAndSettle();
    expect(find.text('1 übersprungen'), findsOneWidget);

    await tester.tap(find.text('Weiter zur Zusammenfassung'));
    await tester.pumpAndSettle();

    // Schritt 3: Zusammenfassung + Anwenden.
    expect(find.textContaining('3 Zeilen'), findsOneWidget);
    expect(find.text('2 Geräte zugeordnet'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Import ausführen'),
        find.byType(ListView), const Offset(0, -200));
    await tester.tap(find.text('Import ausführen'));
    await tester.pumpAndSettle();

    expect(find.text('Import abgeschlossen'), findsOneWidget);
    expect(find.text('2 Zuordnungen geschrieben'), findsOneWidget);
    expect(find.text('1 Zeilen übersprungen'), findsOneWidget);

    // Datenbank-Nachweis: Fahrzeug, Fächer und Zuordnungen existieren.
    final vehicles = await db.vehicleDao.getAll();
    expect(vehicles.single.name, 'LF 10');
    final compartments =
        await db.compartmentDao.getByVehicle(vehicles.single.id);
    expect(compartments.map((c) => c.label), containsAll(['G1', 'G2']));
    final assignments =
        await db.assignmentDao.getByVehicle(vehicles.single.id);
    expect(assignments, hasLength(2));
    // Kein Custom-Gerät angelegt (der unbekannte Eintrag wurde übersprungen).
    final equipment = await db.equipmentDao.getAll();
    expect(equipment.where((e) => e.isCustom), isEmpty);
  });

  testWidgets('ungültiges Mapping blockiert den Weiter-Button',
      (tester) async {
    await tester.pumpWidget(
        buildTestApp(db: db, home: const ImportWizardScreen()));
    final container = containerOf(tester);
    await container
        .read(importWizardProvider.notifier)
        .loadFile('beladeliste.csv', utf8.encode(csv));
    await tester.pumpAndSettle();

    // Ohne Fahrzeugname ist das Mapping unvollständig → Button deaktiviert.
    await tester.dragUntilVisible(find.text('Weiter zum Abgleich'),
        find.byType(ListView), const Offset(0, -200));
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Weiter zum Abgleich'),
        matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
  });
}
