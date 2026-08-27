/// wissen_asset_test.dart – Der ausgelieferte Fachbestand (Issue #174,
/// Schritt 2).
///
/// Der wichtigste Test steht unten: Er liest die **wirklich ausgelieferte**
/// `fwdv.json`, nicht eine erfundene. Eine Frage ohne Fundstelle, ein
/// Tippfehler im Gebiet oder eine Antwortmenge, die auf nichts zeigt, fällt
/// damit in der CI auf — und nicht beim Üben.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/knowledge/data/wissen_asset.dart';
import 'package:fwapp/features/knowledge/data/wissen_seeder.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseWissensAsset', () {
    test('liest Frage, Antwortmenge, Quelle und Geltungsbereich', () {
      final f = parseWissensAsset('''
      {"fragen": [{
        "gebiet": "einsatzlehre",
        "frage": "Wie ist die Mannschaftsstärke einer Gruppe?",
        "antworten": ["1/8/9", "1/5/6", "1/2/3"],
        "richtige": [0],
        "erklaerung": "Neun insgesamt.",
        "quelle": {"werk": "FwDV 3", "fundstelle": "Abschnitt 2.1",
                   "stand": "2008-02"}
      }]}''').single;

      expect(f.gebiet, Wissensgebiet.einsatzlehre);
      expect(f.richtige, {0});
      expect(f.quelle?.anzeige, 'FwDV 3 · Abschnitt 2.1');
      expect(f.quelle?.stand, '2008-02');
      // Ohne Angabe ist eine Frage bundesweit — Landesrecht ist die
      // Ausnahme, die benannt werden muss.
      expect(f.geltung, Geltungsbereich.bund);
      expect(f.land, isNull);
    });

    test('mehrere richtige Antworten kommen als Menge an', () {
      final f = parseWissensAsset('''
      {"fragen": [{
        "gebiet": "geraetekunde",
        "frage": "Welche Leitern sind genormt?",
        "antworten": ["Steckleiter", "Klappleiter", "Drehleiter"],
        "richtige": [0, 1]
      }]}''').single;
      expect(f.richtige, {0, 1});
    });

    test('eine kaputte Frage kostet sich selbst, nicht den Bestand', () {
      // Die zweite Frage hat keine markierte Antwort. Sie fällt heraus, die
      // erste bleibt — ein Tippfehler darf nicht den ganzen Grundstock
      // verhindern.
      final fragen = parseWissensAsset('''
      {"fragen": [
        {"gebiet": "loeschlehre", "frage": "Was ist Brandklasse A?",
         "antworten": ["Feste Stoffe", "Gase"], "richtige": [0]},
        {"gebiet": "loeschlehre", "frage": "Kaputte Frage?",
         "antworten": ["a", "b"], "richtige": []}
      ]}''');
      expect(fragen, hasLength(1));
      expect(fragen.single.frage, 'Was ist Brandklasse A?');
    });

    test('ein unbekanntes Gebiet wird nicht stillschweigend einsortiert', () {
      // Sonst landete die Frage in einem Sammelbecken und wäre über den
      // Filter nie wieder zu finden.
      expect(
          parseWissensAsset('''
      {"fragen": [{"gebiet": "sonstiges", "frage": "Irgendwas dazu?",
        "antworten": ["a", "b"], "richtige": [0]}]}'''),
          isEmpty);
    });

    test('Landesrecht ohne gültiges Land fällt heraus', () {
      // „Gilt im Landesrecht" ohne zu sagen, in welchem, ist keine Angabe.
      expect(
          parseWissensAsset('''
      {"fragen": [{"gebiet": "recht_organisation", "frage": "Wer wählt ihn?",
        "antworten": ["a", "b"], "richtige": [0], "geltung": "land"}]}'''),
          isEmpty);
      expect(
          parseWissensAsset('''
      {"fragen": [{"gebiet": "recht_organisation", "frage": "Wer wählt ihn?",
        "antworten": ["a", "b"], "richtige": [0], "geltung": "land",
        "land": "XX"}]}'''),
          isEmpty);
    });

    test('unlesbares JSON liefert nichts statt zu werfen', () {
      expect(parseWissensAsset('{kaputt'), isEmpty);
    });
  });

  group('der AUSGELIEFERTE Bestand', () {
    late List<AssetFrage> fragen;

    setUpAll(() async {
      fragen = parseWissensAsset(
          await rootBundle.loadString('assets/knowledge/fwdv.json'));
    });

    test('lässt sich vollständig lesen', () async {
      // Zählt gegen die Datei selbst: Fällt eine Frage beim Parsen heraus,
      // stimmt die Zahl nicht mehr — und genau das soll auffallen.
      final roh = await rootBundle.loadString('assets/knowledge/fwdv.json');
      final imJson = RegExp(r'"frage"\s*:').allMatches(roh).length;
      expect(fragen, hasLength(imJson),
          reason: 'eine Frage ist beim Parsen herausgefallen');
      expect(fragen.length, greaterThanOrEqualTo(30));
    });

    test('jede Frage nennt ihre Fundstelle', () {
      // Der ganze Zweck des Bestands: Eine Antwort, die man nicht
      // nachschlagen kann, nützt im Zweifel wenig.
      for (final f in fragen) {
        expect(f.quelle, isNotNull, reason: 'ohne Quelle: "${f.frage}"');
        expect(f.quelle!.werk, isNotEmpty);
        expect(f.quelle!.fundstelle, isNotNull,
            reason: 'ohne Fundstelle: "${f.frage}"');
        expect(f.quelle!.stand, isNotNull,
            reason: 'ohne Fassung: "${f.frage}"');
      }
    });

    test('die Quellen sind Dienstvorschriften, keine geschützten Werke', () {
      // Lehrstoffblätter (Neckar-Verlag) und DIN-Normtexte sind
      // urheberrechtlich geschützt — aus ihnen wird nichts entnommen.
      final erlaubt = RegExp(r'^(FwDV \d+|DGUV .+)$');
      for (final f in fragen) {
        expect(erlaubt.hasMatch(f.quelle!.werk), isTrue,
            reason: 'unerwartete Quelle "${f.quelle!.werk}" bei '
                '"${f.frage}"');
      }
    });

    test('der bundesweite Bestand enthält kein Landesrecht', () {
      for (final f in fragen) {
        expect(f.geltung, Geltungsbereich.bund,
            reason: 'Landesrecht im Bundes-Asset: "${f.frage}"');
      }
    });

    test('Mehrfachantworten sind dabei — sonst wäre die Erweiterung umsonst',
        () {
      final mehrfach = fragen.where((f) => f.richtige.length > 1);
      expect(mehrfach, isNotEmpty);
      // Und es sind keine Fangfragen, bei denen alles richtig ist.
      for (final f in mehrfach) {
        expect(f.richtige.length, lessThan(f.antworten.length));
      }
    });

    test('keine Frage steht zweimal drin', () {
      final texte = fragen.map((f) => f.frage.toLowerCase()).toList();
      expect(texte.toSet(), hasLength(texte.length));
    });
  });

  group('Anlegen', () {
    late AppDatabase db;
    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('der Fachbestand landet freigegeben und mit Quelle in der DB',
        () async {
      final fragen = parseWissensAsset(
          await rootBundle.loadString('assets/knowledge/fwdv.json'));
      final n = await WissenSeeder(db).seedFachbestand(fragen);

      expect(n, fragen.length);
      final zeilen = await db.wissenDao.getAll();
      expect(zeilen, hasLength(fragen.length));
      // Ausgeliefertes ist geprüft — es wartet auf niemanden.
      expect(zeilen.every((z) => z.stand == 'freigegeben'), isTrue);
      expect(zeilen.every((z) => z.herkunft == 'mitgeliefert'), isTrue);
      expect(zeilen.every((z) => (z.quelleWerk ?? '').isNotEmpty), isTrue);
      // Und die Mengen sind wirklich Mengen.
      expect(zeilen.any((z) => z.richtigeJson.contains(',')), isTrue);
    });

    test('ein zweiter Lauf verdoppelt nichts', () async {
      final fragen = parseWissensAsset(
          await rootBundle.loadString('assets/knowledge/fwdv.json'));
      await WissenSeeder(db).seedFachbestand(fragen);
      expect(await WissenSeeder(db).seedFachbestand(fragen), 0);
      expect(await db.wissenDao.getAll(), hasLength(fragen.length));
    });
  });
}
