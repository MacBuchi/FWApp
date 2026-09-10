/// lernbereiche_test.dart – Was abgeschaltet ist, wird nicht gefragt
/// (Marcus, 2026-08-28) — und was NICHT abgeschaltet ist, wird es weiterhin.
///
/// Die zweite Hälfte ist die wichtigere. Ein Filter, der zu viel wegnimmt,
/// fällt niemandem auf: Die Wissensdatenbank zeigt die Frage ja weiter, nur
/// im Quiz kommt sie nie. Genau die Sorte Fehler, die erst ein halbes Jahr
/// später als „das Quiz wiederholt sich so oft" gemeldet wird. Deshalb prüft
/// jeder Fall hier auch, was stehen bleiben muss.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> frage(String text, String gebiet, {String? kapitel}) =>
      db.wissenDao.insertFrage(WissensfragenCompanion.insert(
        gebiet: gebiet,
        frage: text,
        antwortenJson: const Value('["a","b"]'),
        richtigeJson: const Value('[0]'),
        kapitel: Value(kapitel),
        stand: const Value('freigegeben'),
      ));

  Future<void> abschalten(String gebiet, {String? kapitel}) async {
    final bestand = await db.wissenDao.getAbgeschaltet();
    await db.wissenDao.ersetzeAbgeschaltet([
      for (final b in bestand)
        AbgeschalteteLernbereicheCompanion.insert(
          gebiet: b.gebiet,
          kapitel: Value(b.kapitel),
        ),
      AbgeschalteteLernbereicheCompanion.insert(
        gebiet: gebiet,
        kapitel: Value(kapitel),
      ),
    ]);
  }

  Future<List<String>> spielbar() async =>
      (await db.wissenDao.getSpielbare()).map((f) => f.frage).toList();

  group('ein ganzes Gebiet abschalten', () {
    test('nimmt alle Fragen des Gebiets, aber kein anderes', () async {
      await frage('Atemschutz mit Kapitel?', 'atemschutz', kapitel: 'Geräte');
      await frage('Atemschutz ohne Kapitel?', 'atemschutz');
      await frage('Funk bleibt?', 'funk');

      await abschalten('atemschutz');

      expect(await spielbar(), ['Funk bleibt?']);
    });
  });

  group('ein einzelnes Kapitel abschalten', () {
    setUp(() async {
      await frage('Was ist Dekon?', 'gefahrgut', kapitel: 'Dekontamination');
      await frage('Welcher Zettel?', 'gefahrgut',
          kapitel: 'Gefahrzettel und Kennzeichnung');
      await frage('Gefahrgut ohne Kapitel?', 'gefahrgut');
    });

    test('nimmt nur dieses Kapitel', () async {
      await abschalten('gefahrgut', kapitel: 'Dekontamination');

      final uebrig = await spielbar();
      expect(uebrig, hasLength(2));
      expect(uebrig, isNot(contains('Was ist Dekon?')));
    });

    test('lässt die Fragen OHNE Kapitel desselben Gebiets in Ruhe', () async {
      // Der Fall, an dem ein naiver Vergleich scheitert: In SQL ist
      // `NULL = NULL` nicht wahr, sondern unbekannt — und genau darauf ruht
      // der Filter. Wer das „repariert", schaltet mit einem Kapitel das
      // halbe Gebiet ab, und dieser Test ist die Wache davor.
      await abschalten('gefahrgut', kapitel: 'Dekontamination');

      expect(await spielbar(), contains('Gefahrgut ohne Kapitel?'));
    });

    test('das ganze Gebiet nimmt auch die Kapitel mit', () async {
      await abschalten('gefahrgut');

      expect(await spielbar(), isEmpty);
    });
  });

  test('wieder einschalten bringt die Fragen zurück', () async {
    await frage('Kommt wieder?', 'funk');
    await abschalten('funk');
    expect(await spielbar(), isEmpty);

    // Der Zug ERSETZT den Spiegel — eine Zeile, die der Server nicht mehr
    // liefert, ist wieder eingeschaltet. Deshalb kein „delete", sondern eine
    // leere Menge.
    await db.wissenDao.ersetzeAbgeschaltet(const []);

    expect(await spielbar(), ['Kommt wieder?']);
  });

  test('eine nicht freigegebene Frage bleibt auch ohne Abschaltung draußen',
      () async {
    await db.wissenDao.insertFrage(WissensfragenCompanion.insert(
      gebiet: 'funk',
      frage: 'Noch nicht freigegeben?',
      antwortenJson: const Value('["a","b"]'),
      richtigeJson: const Value('[0]'),
    ));

    expect(await spielbar(), isEmpty);
  });

  group('istAbgeschaltet', () {
    test('ein abgeschaltetes Gebiet gilt auch für seine Kapitel', () {
      const bereiche = [
        AbgeschalteterLernbereich(id: 1, gebiet: 'gefahrgut'),
      ];
      expect(istAbgeschaltet(bereiche, 'gefahrgut'), isTrue);
      expect(istAbgeschaltet(bereiche, 'gefahrgut', kapitel: 'Dekon'), isTrue);
      expect(istAbgeschaltet(bereiche, 'funk'), isFalse);
    });

    test('ein abgeschaltetes Kapitel gilt NICHT für das ganze Gebiet', () {
      const bereiche = [
        AbgeschalteterLernbereich(id: 1, gebiet: 'gefahrgut', kapitel: 'Dekon'),
      ];
      expect(istAbgeschaltet(bereiche, 'gefahrgut', kapitel: 'Dekon'), isTrue);
      expect(istAbgeschaltet(bereiche, 'gefahrgut'), isFalse);
      expect(
          istAbgeschaltet(bereiche, 'gefahrgut', kapitel: 'Anderes'), isFalse);
    });
  });
}
