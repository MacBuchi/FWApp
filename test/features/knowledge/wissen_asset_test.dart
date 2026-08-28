/// wissen_asset_test.dart – Der ausgelieferte Fachbestand (Issue #174,
/// Schritt 2).
///
/// Der wichtigste Test steht unten: Er liest die **wirklich ausgelieferten**
/// Dateien, nicht erfundene. Eine Frage ohne Fundstelle, ein Tippfehler im
/// Gebiet oder eine Antwortmenge, die auf nichts zeigt, fällt damit in der
/// CI auf — und nicht beim Üben.
///
/// `bestandPruefen` gilt für jeden Bestand; was je Datei verschieden ist,
/// steht in ihren Argumenten: die erlaubten Werke und der Geltungsbereich.
library;

import 'dart:io';

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

  /// Prüfungen, die für JEDEN ausgelieferten Bestand gelten. Als Funktion,
  /// damit ein neuer Landesbestand sie mit einer Zeile erbt statt sie zu
  /// kopieren — kopierte Prüfungen werden beim Nachziehen vergessen.
  void bestandPruefen(
    String pfad, {
    required RegExp erlaubteWerke,
    required Geltungsbereich geltung,
    String? land,
    required int mindestens,
  }) {
    group('der ausgelieferte Bestand $pfad', () {
      late List<AssetFrage> fragen;
      late String roh;

      setUpAll(() async {
        roh = await rootBundle.loadString(pfad);
        fragen = parseWissensAsset(roh);
      });

      test('lässt sich vollständig lesen', () {
        // Zählt gegen die Datei selbst: Fällt eine Frage beim Parsen heraus,
        // stimmt die Zahl nicht mehr — und genau das soll auffallen.
        final imJson = RegExp(r'"frage"\s*:').allMatches(roh).length;
        expect(fragen, hasLength(imJson),
            reason: 'eine Frage ist beim Parsen herausgefallen');
        expect(fragen.length, greaterThanOrEqualTo(mindestens));
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

      test('die Quellen sind amtliche Werke, keine geschützten', () {
        // Lehrstoffblätter (Neckar-Verlag) und DIN-Normtexte sind
        // urheberrechtlich geschützt — aus ihnen wird nichts entnommen.
        for (final f in fragen) {
          expect(erlaubteWerke.hasMatch(f.quelle!.werk), isTrue,
              reason: 'unerwartete Quelle "${f.quelle!.werk}" bei '
                  '"${f.frage}"');
        }
      });

      test('der Geltungsbereich stimmt für die ganze Datei', () {
        for (final f in fragen) {
          expect(f.geltung, geltung,
              reason: 'falscher Geltungsbereich: "${f.frage}"');
          expect(f.land, land, reason: 'falsches Land: "${f.frage}"');
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
  }

  // Bundesweit gilt, was ueberall dasselbe ist: die
  // Feuerwehr-Dienstvorschriften, das Unfallverhuetungsrecht, die
  // Strassenverkehrs-Ordnung und die Technischen Regeln fuer Arbeitsstaetten.
  // Alle vier sind amtliche Werke nach § 5 UrhG.
  //
  // ⚠️ Diese Liste ist eine urheberrechtliche Entscheidung, keine Formalie.
  // Wer ein Werk ergaenzt, hat vorher zu klaeren, ob es amtlich ist — die
  // Lehrstoffblaetter der Landesfeuerwehrschule und DIN-Normtexte sind es
  // NICHT.
  bestandPruefen(
    'assets/knowledge/bund.json',
    erlaubteWerke: RegExp(r'^(FwDV \d+|DGUV .+|StVO|ASR A2\.2)$'),
    geltung: Geltungsbereich.bund,
    mindestens: 80,
  );

  // Baden-Württemberg (Issue #174, Schritt 3). Die erlaubten Werke sind
  // eng gefasst und das ist Absicht: Das Feuerwehrgesetz und die beiden
  // Verwaltungsvorschriften sind amtliche Werke nach § 5 UrhG. Wer hier ein
  // weiteres Werk einträgt, hat vorher zu klären, ob es das auch ist —
  // die Lehrstoffblätter der Landesfeuerwehrschule sind es NICHT.
  bestandPruefen(
    'assets/knowledge/bw.json',
    erlaubteWerke:
        RegExp(r'^(FwG BW|VwV Feuerwehrbekleidung|VwV Feuerwehrausbildung)$'),
    geltung: Geltungsbereich.land,
    land: 'BW',
    mindestens: 40,
  );

  group('alle Bestände zusammen', () {
    test('jedes Asset aus kWissensAssets ist auch ausgeliefert', () async {
      // Ein Eintrag in kWissensAssets ohne Zeile in pubspec.yaml lädt zur
      // Laufzeit nichts und fällt sonst nirgends auf — das Sachgebiet wäre
      // auf dem Gerät einfach leer.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final pfad in kWissensAssets) {
        expect(pubspec, contains('- $pfad'),
            reason: '$pfad steht in kWissensAssets, aber nicht in '
                'pubspec.yaml');
        // Und umgekehrt: Die Datei muss wirklich im Bundle liegen.
        await expectLater(rootBundle.loadString(pfad), completes);
      }
    });

    test('keine Frage steht in zwei Beständen', () async {
      // Eine Frage, die bundesweit UND im Landesbestand steht, käme im
      // Spiel doppelt und in der Übersicht zweimal untereinander.
      final texte = <String>[];
      for (final pfad in kWissensAssets) {
        texte.addAll(parseWissensAsset(await rootBundle.loadString(pfad))
            .map((f) => f.frage.toLowerCase()));
      }
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
          await rootBundle.loadString('assets/knowledge/bund.json'));
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
          await rootBundle.loadString('assets/knowledge/bund.json'));
      await WissenSeeder(db).seedFachbestand(fragen);
      expect(await WissenSeeder(db).seedFachbestand(fragen), 0);
      expect(await db.wissenDao.getAll(), hasLength(fragen.length));
    });
  });
}
