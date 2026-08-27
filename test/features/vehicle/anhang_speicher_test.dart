/// anhang_speicher_test.dart – Unterlagen am Fahrzeug (Issue #182).
///
/// Geprüft wird der Teil, der ohne Server auskommt — und das ist der
/// wichtigste: Ein Anhang muss **zuerst** lokal liegen und erst danach zum
/// Server gehen. Andersherum wäre eine abgerissene Verbindung ein
/// Datenverlust, und genau das darf einer Wehr nicht passieren, die im
/// Funkloch erfasst.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/vehicle/data/anhang_speicher.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late AnhangSpeicher speicher;

  setUp(() async {
    db = createTestDatabase();
    tempDir = await Directory.systemTemp.createTemp('fwapp_anhang_test');
    // Ohne Client: reiner Lokalbetrieb. Genau der Zustand, den die App
    // vollständig können muss (Architektur-Leitplanke).
    speicher = AnhangSpeicher(db: db, ordner: () async => tempDir);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<int> seedFahrzeug() => db.vehicleDao
      .insertVehicle(VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));

  final pdf = Uint8List.fromList(List.filled(64, 42));

  group('Erkennung', () {
    test('MIME aus der Endung, wenn der Dateiwähler keinen liefert', () {
      // Auf manchen Android-Fassungen kommt der Typ nicht mit — dann ist die
      // Endung alles, was da ist.
      expect(mimeAusName('Betriebsanleitung.PDF'), 'application/pdf');
      expect(mimeAusName('schein.jpeg'), 'image/jpeg');
      expect(mimeAusName('irgendwas.docx'), '');
    });

    test('Bild oder Dokument entscheidet die Darstellung', () {
      expect(anhangArt('image/png'), 'image');
      expect(anhangArt('application/pdf'), 'document');
    });
  });

  group('hinzufügen', () {
    test('legt die Datei lokal ab und trägt sie ein — ohne jeden Server',
        () async {
      final fahrzeug = await seedFahrzeug();
      final anhang = await speicher.hinzufuegen(
        vehicleId: fahrzeug,
        dateiname: 'Betriebsanleitung.pdf',
        bytes: pdf,
      );

      expect(anhang.title, 'Betriebsanleitung.pdf');
      expect(anhang.kind, 'document');
      expect(anhang.mimeType, 'application/pdf');
      expect(anhang.sizeBytes, 64);
      // Die Offline-Zusage: Die Datei liegt wirklich da.
      expect(anhang.localPath, isNotNull);
      expect(File(anhang.localPath!).existsSync(), isTrue);
      expect(File(anhang.localPath!).readAsBytesSync(), pdf);
      // Ohne Server gibt es keinen Marker — der kommt beim Nachreichen.
      expect(anhang.storagePath, isNull);

      expect(await db.attachmentDao.getByVehicle(fahrzeug), hasLength(1));
    });

    test('lehnt ab, was der Server ohnehin nicht annähme', () async {
      final fahrzeug = await seedFahrzeug();
      await expectLater(
        speicher.hinzufuegen(
            vehicleId: fahrzeug, dateiname: 'liste.docx', bytes: pdf),
        throwsA(isA<AnhangAbgelehnt>()),
      );
      // Nichts halb Angelegtes zurückgelassen.
      expect(await db.attachmentDao.getByVehicle(fahrzeug), isEmpty);
    });

    test('zu groß wird abgelehnt, bevor irgendetwas passiert', () async {
      // Die Prüfung liegt in der App, damit die Meldung verständlich ist —
      // ein Storage-Fehler sagt dem Gerätewart nichts.
      final fahrzeug = await seedFahrzeug();
      final riesig = Uint8List(kMaxAnhangBytes + 1);
      await expectLater(
        speicher.hinzufuegen(
            vehicleId: fahrzeug, dateiname: 'scan.pdf', bytes: riesig),
        throwsA(isA<AnhangAbgelehnt>()),
      );
      expect(tempDir.listSync(), isEmpty);
    });

    test('zwei Anhänge bekommen zwei Dateien, nicht eine', () async {
      // Zeitstempel im Namen: Ein zweiter Anhang darf den ersten nicht
      // überschreiben, auch nicht bei gleichem Dateinamen.
      final fahrzeug = await seedFahrzeug();
      final a = await speicher.hinzufuegen(
          vehicleId: fahrzeug, dateiname: 'scan.pdf', bytes: pdf);
      final b = await speicher.hinzufuegen(
          vehicleId: fahrzeug, dateiname: 'scan.pdf', bytes: pdf);

      expect(a.localPath, isNot(b.localPath));
      expect(File(a.localPath!).existsSync(), isTrue);
      expect(File(b.localPath!).existsSync(), isTrue);
    });
  });

  group('sicherstellenLokal', () {
    test('was schon hier liegt, wird nicht noch einmal geholt', () async {
      final fahrzeug = await seedFahrzeug();
      final anhang = await speicher.hinzufuegen(
          vehicleId: fahrzeug, dateiname: 'a.pdf', bytes: pdf);

      expect(await speicher.sicherstellenLokal(anhang), anhang.localPath);
    });

    test('ohne Server und ohne lokale Kopie: ehrliches null', () async {
      // Kein stiller Fehlschlag — der Aufrufer sagt dem Nutzer, dass es
      // gerade nicht geht.
      final fahrzeug = await seedFahrzeug();
      final id = await db.attachmentDao.insertAttachment(
        VehicleAttachmentsCompanion.insert(
          vehicleId: fahrzeug,
          title: 'nur-server.pdf',
          storagePath: const Value(
              'supabase://vehicle-attachments/abt/nur-server.pdf'),
        ),
      );
      final anhang = (await db.attachmentDao.getById(id))!;
      expect(await speicher.sicherstellenLokal(anhang), isNull);
    });

    test('ein Pfad auf eine gelöschte Datei gilt nicht als vorhanden',
        () async {
      // Sonst behauptet die Liste „auf diesem Gerät", und im Einsatz ist
      // nichts da. Ohne Server kann der Speicher sie nicht nachholen —
      // dann ist null die richtige Antwort.
      final fahrzeug = await seedFahrzeug();
      final anhang = await speicher.hinzufuegen(
          vehicleId: fahrzeug, dateiname: 'a.pdf', bytes: pdf);
      await File(anhang.localPath!).delete();

      expect(await speicher.sicherstellenLokal(anhang), isNull);
    });
  });

  group('entfernen', () {
    test('räumt Datei und Eintrag weg', () async {
      final fahrzeug = await seedFahrzeug();
      final anhang = await speicher.hinzufuegen(
          vehicleId: fahrzeug, dateiname: 'a.pdf', bytes: pdf);
      final pfad = anhang.localPath!;

      await speicher.entfernen(anhang);

      expect(File(pfad).existsSync(), isFalse);
      expect(await db.attachmentDao.getByVehicle(fahrzeug), isEmpty);
    });

    test('eine bereits verschwundene Datei bricht das Entfernen nicht ab',
        () async {
      final fahrzeug = await seedFahrzeug();
      final anhang = await speicher.hinzufuegen(
          vehicleId: fahrzeug, dateiname: 'a.pdf', bytes: pdf);
      await File(anhang.localPath!).delete();

      await speicher.entfernen(anhang);
      expect(await db.attachmentDao.getByVehicle(fahrzeug), isEmpty);
    });
  });

  test('das Fahrzeug zu löschen nimmt seine Anhänge mit', () async {
    // Kaskade in der lokalen Datenbank: Ein Anhang ohne Fahrzeug wäre eine
    // Zeile, die niemand mehr findet und niemand mehr löscht.
    final fahrzeug = await seedFahrzeug();
    await speicher.hinzufuegen(
        vehicleId: fahrzeug, dateiname: 'a.pdf', bytes: pdf);

    await db.vehicleDao.deleteVehicle(fahrzeug);
    expect(await db.attachmentDao.getAll(), isEmpty);
  });
}
