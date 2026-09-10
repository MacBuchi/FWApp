/// wissen_seeder_test.dart – Der ausgelieferte Grundstock (Issue #174).
///
/// Zwei Dinge hängen hier, die man sonst erst auf einem Gerät merkt: dass
/// ein zweiter Start den Bestand nicht verdoppelt, und dass die **wirklich
/// ausgelieferte** `party.json` sauber eingeordnet ist. Der zweite Test
/// liest die echte Datei, nicht eine erfundene — ein Tippfehler im Gebiet
/// fällt damit in der CI auf und nicht beim Kameradschaftsabend.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/game/party/data/party_inhalte.dart';
import 'package:fwapp/core/database/standard_catalog.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/knowledge/data/wissen_seeder.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  PartyInhalte inhalte(List<UnerwarteteFrage> fragen) =>
      PartyInhalte(fragen: fragen, aufgaben: const []);

  UnerwarteteFrage frage(String text,
          {String kategorie = kKategorieWissen, String? gebiet}) =>
      UnerwarteteFrage(
        frage: text,
        antworten: const ['a', 'b'],
        richtig: 0,
        kategorie: kategorie,
        gebiet: gebiet,
      );

  test('legt den Grundstock an — freigegeben und als mitgeliefert', () async {
    final n = await WissenSeeder(db).seedIfNeeded(inhalte([
      frage('Wie lang ist ein C-Schlauch?', gebiet: 'geraetekunde'),
    ]));

    expect(n, 1);
    final f = (await db.wissenDao.getAll()).single;
    expect(f.gebiet, 'geraetekunde');
    expect(f.herkunft, Fragenherkunft.mitgeliefert.schluessel);
    // Ausgeliefertes ist geprüft — es wartet auf niemanden.
    expect(f.stand, Fragenstand.freigegeben.schluessel);
    expect(await db.wissenDao.getSpielbare(), hasLength(1));
  });

  test('ein zweiter Lauf verdoppelt nichts', () async {
    // Der Seeder läuft bei JEDEM Start. Ohne diese Zusage wüchse die
    // Datenbank mit jeder App-Öffnung.
    final topf = inhalte([frage('Wie lang ist ein C-Schlauch?')]);
    await WissenSeeder(db).seedIfNeeded(topf);
    final zweiter = await WissenSeeder(db).seedIfNeeded(topf);

    expect(zweiter, 0);
    expect(await db.wissenDao.getAll(), hasLength(1));
  });

  test('erkennt eine vorhandene Frage trotz anderer Schreibweise', () async {
    await WissenSeeder(db)
        .seedIfNeeded(inhalte([frage('Wie lang ist ein C-Schlauch?')]));
    final nochmal = await WissenSeeder(db).seedIfNeeded(
        inhalte([frage('  wie LANG ist  ein C-Schlauch?  ')]));

    expect(nochmal, 0);
  });

  test('eine bearbeitete Frage bleibt, wie sie ist', () async {
    // Wer eine mitgelieferte Frage korrigiert hat, verliert die Korrektur
    // sonst beim nächsten Start.
    final topf = inhalte([frage('Wie lang ist ein C-Schlauch?')]);
    await WissenSeeder(db).seedIfNeeded(topf);
    final f = (await db.wissenDao.getAll()).single;
    await db.wissenDao.aendere(
        f.id, const WissensfragenCompanion(erklaerung: Value('Von Hand ergänzt')));

    await WissenSeeder(db).seedIfNeeded(topf);
    expect((await db.wissenDao.getAll()).single.erklaerung, 'Von Hand ergänzt');
  });

  test('ohne Gebiet im Asset landet ein Klischee bei den Klischees', () async {
    // Rückfall für ältere Asset-Fassungen: lieber sichtbar einsortiert als
    // ein Klischee im Prüfungsstoff.
    await WissenSeeder(db).seedIfNeeded(inhalte([
      frage('Was ist heiliger als jedes Fahrzeug?',
          kategorie: kKategorieKlischee),
    ]));
    expect((await db.wissenDao.getAll()).single.gebiet,
        Wissensgebiet.klischee.schluessel);
  });

  test('die AUSGELIEFERTE party.json ist vollständig eingeordnet', () async {
    // Liest die echte Datei aus dem Bündel. Ein unbekannter Gebietsschlüssel
    // fiele sonst erst auf, wenn die Frage im falschen Filter auftaucht.
    final roh = await rootBundle.loadString(kPartyAsset);
    final geparst = parsePartyInhalte(roh);
    expect(geparst.fragen, isNotEmpty);

    for (final f in geparst.fragen) {
      expect(f.gebiet, isNotNull,
          reason: 'ohne Gebiet: "${f.frage}"');
      expect(Wissensgebiet.ausSchluessel(f.gebiet), isNotNull,
          reason: 'unbekanntes Gebiet "${f.gebiet}" bei "${f.frage}"');
    }

    // Und der Grundstock landet vollständig in der Datenbank.
    final n = await WissenSeeder(db).seedIfNeeded(geparst);
    expect(n, geparst.fragen.length);
  });

  // ── Fragen, die den Fuhrpark kennen ──────────────────────────────────────

  group('seedGeraetefragen', () {
    StandardCatalog katalog() => StandardCatalog.ausEintraegen([
          for (var i = 0; i < 5; i++)
            {
              'id': 'std_$i',
              'name': 'Gerät $i',
              'equipment_functions': ['G$i'],
              'typical_use': ['Verwendung $i'],
              'description': 'Beschreibung $i.',
            },
        ]);

    test('legt sie mit Gerätebezug, Quelle und freigegeben an', () async {
      final angelegt = await WissenSeeder(db).seedGeraetefragen(katalog());
      expect(angelegt, 5);

      final f = (await db.wissenDao.getAll())
          .firstWhere((x) => x.geraet == 'std_0');
      expect(f.gebiet, Wissensgebiet.geraetekunde.schluessel);
      expect(f.herkunft, Fragenherkunft.mitgeliefert.schluessel);
      // Ausgeliefertes ist geprüft — es wartet auf niemanden.
      expect(f.stand, Fragenstand.freigegeben.schluessel);
      expect(f.quelleWerk, 'Mitgelieferter Gerätekatalog');
      expect(f.antwortenJson, contains('Verwendung 0'));
    });

    test('die markierte Antwort ist wirklich die richtige', () async {
      // Beim Anlegen werden die Antworten gemischt — wenn der Index dabei
      // nicht mitwandert, ist jede erzeugte Frage falsch, und zwar
      // unauffällig.
      await WissenSeeder(db).seedGeraetefragen(katalog());
      for (final f in await db.wissenDao.getAll()) {
        final antworten = jsonToStringList(f.antwortenJson);
        final richtige = indizesAusJson(f.richtigeJson);
        expect(richtige, hasLength(1));
        final nummer = f.geraet!.split('_').last;
        expect(antworten[richtige.single], 'Verwendung $nummer',
            reason: f.frage);
      }
    });

    test('ein zweiter Lauf verdoppelt nichts', () async {
      await WissenSeeder(db).seedGeraetefragen(katalog());
      expect(await WissenSeeder(db).seedGeraetefragen(katalog()), 0);
      expect(await db.wissenDao.getAll(), hasLength(5));
    });

    test('eine von Hand geänderte Frage bleibt unangetastet', () async {
      await WissenSeeder(db).seedGeraetefragen(katalog());
      final f = (await db.wissenDao.getAll())
          .firstWhere((x) => x.geraet == 'std_0');
      await db.wissenDao.aendere(
          f.id, const WissensfragenCompanion(erklaerung: Value('Korrigiert')));

      await WissenSeeder(db).seedGeraetefragen(katalog());

      final danach = (await db.wissenDao.getById(f.id))!;
      expect(danach.erklaerung, 'Korrigiert');
    });

    test('ein leerer Katalog legt nichts an und wirft nicht', () async {
      expect(await WissenSeeder(db).seedGeraetefragen(StandardCatalog.empty()),
          0);
    });
  });
}
