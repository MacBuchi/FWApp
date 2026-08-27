/// fahrzeug_unterlagen_test.dart – Der Unterlagen-Abschnitt am Fahrzeug
/// (Issue #182).
///
/// Die eine Zusage, die hier hängt und sonst nirgends: **Jede Zeile sagt, ob
/// die Datei auf DIESEM Gerät liegt.** Ohne diese Unterscheidung wäre
/// „angehängt" eine Behauptung, die erst im Funkloch auffliegt — und dort
/// braucht man die Betriebsanleitung.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/vehicle/data/anhang_speicher.dart';
import 'package:fwapp/features/vehicle/presentation/providers/anhang_providers.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/fahrzeug_unterlagen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late AnhangSpeicher speicher;
  late int fahrzeug;

  setUp(() async {
    db = createTestDatabase();
    tempDir = await Directory.systemTemp.createTemp('fwapp_unterlagen_test');
    speicher = AnhangSpeicher(db: db, ordner: () async => tempDir);
    fahrzeug = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpe(WidgetTester tester, {bool darfBearbeiten = true}) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        anhangSpeicherProvider.overrideWithValue(speicher),
        if (!darfBearbeiten) canEditProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [FahrzeugUnterlagen(vehicleId: fahrzeug)],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Ein Anhang, der wirklich auf diesem „Gerät" liegt.
  ///
  /// `runAsync`, weil hier eine echte Datei geschrieben wird — siehe Kopf.
  Future<void> lokalerAnhang(WidgetTester tester, String name) =>
      tester.runAsync(() => speicher.hinzufuegen(
            vehicleId: fahrzeug,
            dateiname: name,
            bytes: Uint8List.fromList(List.filled(2048, 7)),
          ));

  /// Ein Anhang, den nur der Server hat — der Fall, den die Offline-Anzeige
  /// überhaupt erst nötig macht.
  Future<void> nurAufDemServer(String name) =>
      db.attachmentDao.insertAttachment(VehicleAttachmentsCompanion.insert(
        vehicleId: fahrzeug,
        title: name,
        storagePath: Value('supabase://vehicle-attachments/abt/$name'),
        sizeBytes: const Value(5 * 1024 * 1024),
      ));

  testWidgets('ohne Anhänge steht da, was hier hingehört', (tester) async {
    await pumpe(tester);

    expect(find.text('Unterlagen'), findsOneWidget);
    expect(find.textContaining('Betriebsanleitung'), findsOneWidget);
    expect(find.text('Anhängen'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('wer nicht bearbeiten darf, sieht weder Anhängen noch Löschen',
      (tester) async {
    await lokalerAnhang(tester, 'Fahrzeugschein.pdf');
    await pumpe(tester, darfBearbeiten: false);

    expect(find.text('Fahrzeugschein.pdf'), findsOneWidget);
    expect(find.text('Anhängen'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    // Und der Hinweistext ist ein anderer — „häng doch was an" wäre für
    // jemanden ohne Rechte ein Angebot, das ins Leere läuft.
    expect(find.textContaining('keine Unterlagen hinterlegt'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('eine lokale Datei meldet sich als „auf diesem Gerät"',
      (tester) async {
    await lokalerAnhang(tester, 'Betriebsanleitung.pdf');
    await pumpe(tester);

    expect(find.text('Betriebsanleitung.pdf'), findsOneWidget);
    expect(find.text('auf diesem Gerät'), findsOneWidget);
    expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    // Nichts zu holen, also kein Knopf.
    expect(find.textContaining('für den Einsatz herunterladen'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('was nur der Server hat, sagt genau das — mit Knopf zum Holen',
      (tester) async {
    await nurAufDemServer('Pruefbescheinigung.pdf');
    await pumpe(tester);

    expect(find.text('nur auf dem Server'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(find.text('1 für den Einsatz herunterladen'), findsOneWidget);
    // Die Größe hilft bei der Entscheidung, ob man das jetzt über Mobilfunk
    // holen will.
    expect(find.text('5.0 MB'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('gemischt: der Knopf zählt nur, was fehlt', (tester) async {
    await lokalerAnhang(tester, 'hier.pdf');
    await nurAufDemServer('dort.pdf');
    await nurAufDemServer('auch-dort.pdf');
    await pumpe(tester);

    expect(find.text('auf diesem Gerät'), findsOneWidget);
    expect(find.text('nur auf dem Server'), findsNWidgets(2));
    expect(find.text('2 für den Einsatz herunterladen'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('ein Pfad auf eine gelöschte Datei gilt nicht als vorhanden',
      (tester) async {
    // Der Fall, der die Anzeige zur Lüge machen würde: Die Zeile trägt einen
    // localPath, aber die Datei ist weg (Speicher aufgeräumt, App neu
    // installiert). Dann ist sie nicht offline verfügbar.
    await lokalerAnhang(tester, 'weg.pdf');
    final anhang = (await db.attachmentDao.getByVehicle(fahrzeug)).single;
    await tester.runAsync(() => File(anhang.localPath!).delete());
    await pumpe(tester);

    expect(find.text('nur auf dem Server'), findsOneWidget);
    expect(find.text('auf diesem Gerät'), findsNothing);

    await endTestApp(tester);
  });

  testWidgets('Löschen fragt nach und nimmt die Zeile dann weg',
      (tester) async {
    // Bewusst ein Anhang OHNE lokale Datei: Das Löschen der Datei selbst
    // prüft `anhang_speicher_test.dart` in einem normalen `test()`, wo echte
    // Ein-/Ausgabe funktioniert. Hier geht es um Dialog und Liste — und ein
    // `File.delete()` im Fake-Async-Zone-Rumpf würde diesen Test aufhängen.
    await nurAufDemServer('weg-damit.pdf');
    await pumpe(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Unterlage entfernen?'), findsOneWidget);

    await tester.tap(find.text('Entfernen'));
    await tester.pumpAndSettle();

    expect(find.text('weg-damit.pdf'), findsNothing);
    expect(await db.attachmentDao.getByVehicle(fahrzeug), isEmpty);

    await endTestApp(tester);
  });

  testWidgets('Abbrechen löscht nichts', (tester) async {
    await nurAufDemServer('bleibt.pdf');
    await pumpe(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.text('bleibt.pdf'), findsOneWidget);
    expect(await db.attachmentDao.getByVehicle(fahrzeug), hasLength(1));

    await endTestApp(tester);
  });
}
