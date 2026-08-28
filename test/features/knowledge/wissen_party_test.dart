/// wissen_party_test.dart – Der Weg einer Wissensfrage ins Spiel
/// (Issue #174).
///
/// Der Anlass ist ein echter Verlust: Die Umwandlung baute die Spielfrage
/// aus Text, Antworten und Erklärung — und ließ **Quelle und
/// Geltungsbereich fallen**. In der Wissensdatenbank stand die Fundstelle,
/// am Tisch nicht, und ausgerechnet dort wird über eine Antwort gestritten.
/// Der Test hält den Weg zusammen, damit ein neues Feld nicht wieder still
/// auf halber Strecke liegen bleibt.
library;

import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<WissensfrageData> anlegen({
    List<String> antworten = const ['Fünf Jahre', 'Drei Jahre', 'Sechs Jahre'],
    Set<int> richtige = const {0},
    String geltung = 'land',
    String? land = 'BW',
    bool mitQuelle = true,
  }) async {
    final id = await db.wissenDao.insertFrage(
      WissensfragenCompanion.insert(
        gebiet: Wissensgebiet.rechtUndOrganisation.schluessel,
        frage: 'Für wie lange wird der Kommandant gewählt?',
        antwortenJson: Value(stringListToJson(antworten)),
        richtigeJson: Value(indizesZuJson(richtige)),
        quelleWerk: Value(mitQuelle ? 'FwG BW' : null),
        quelleFundstelle: Value(mitQuelle ? '§ 8 Abs. 2' : null),
        quelleStand: Value(mitQuelle ? '2025-02-25' : null),
        quelleUrl: Value(mitQuelle
            ? 'https://www.landesrecht-bw.de/perma?a=FeuerwG_BW'
            : null),
        geltung: Value(geltung),
        land: Value(land),
        stand: Value(Fragenstand.freigegeben.schluessel),
      ),
    );
    return (await db.wissenDao.getAll()).firstWhere((z) => z.id == id);
  }

  test('Fundstelle und Landeshinweis reisen mit ins Spiel', () async {
    final z = await anlegen();
    final p = wissensfrageAlsPartyFrage(z, Random(1));

    expect(p.quelle?.werk, 'FwG BW');
    expect(p.quelle?.anzeige, 'FwG BW · § 8 Abs. 2');
    expect(p.quelle?.stand, '2025-02-25');
    // Der Link ist der eigentliche Zweck: Wer widerspricht, soll nachlesen
    // können, statt sich auf die App zu verlassen.
    expect(p.quelle?.url, contains('landesrecht-bw.de'));
    expect(p.geltungshinweis, 'Baden-Württemberg');
  });

  test('was bundesweit gilt, bekommt keinen Landeshinweis', () async {
    // Sonst stünde er an fast jeder Frage und würde dort gelesen, wo er
    // nichts sagt.
    final z = await anlegen(geltung: 'bund', land: null);
    expect(wissensfrageAlsPartyFrage(z, Random(1)).geltungshinweis, isNull);
  });

  test('eine Frage ohne Quelle bleibt ohne Quelle, nicht mit leerer', () async {
    final z = await anlegen(mitQuelle: false);
    expect(wissensfrageAlsPartyFrage(z, Random(1)).quelle, isNull);
  });

  test('auch die Notfassung einer kaputten Zeile nennt ihre Quelle', () async {
    // Die Zeile ohne Antworten ist der Ausweichpfad in der Umwandlung —
    // er hatte die Quelle als Erster verloren, weil ihn niemand ansieht.
    final z = await anlegen(antworten: const [], richtige: const {});
    final p = wissensfrageAlsPartyFrage(z, Random(1));
    expect(p.antworten, hasLength(1));
    expect(p.quelle?.werk, 'FwG BW');
    expect(p.geltungshinweis, 'Baden-Württemberg');
  });

  test('die richtige Antwort überlebt das Mischen', () async {
    // Gemischt wird bei jeder Umwandlung; die Zusage lautet, dass der
    // Index danach auf denselben TEXT zeigt wie vorher.
    for (var i = 0; i < 20; i++) {
      final p = wissensfrageAlsPartyFrage(await anlegen(), Random(i));
      expect(p.richtigeAntwort.text, 'Fünf Jahre');
    }
  });
}
