/// fahrzeugfragen_test.dart – Fahrzeugkunde aus dem eigenen Fuhrpark.
///
/// **Der Fehler, gegen den hier geprüft wird, ist wieder der unsichtbare.**
/// „Auf welchem Fahrzeug liegt der B-Druckschlauch?" hat auf einem echten
/// Fuhrpark **drei richtige Antworten** — der liegt auf jedem Wagen. Käme so
/// eine Frage durch, sähe sie aus wie jede andere, und wer sie „falsch"
/// beantwortet, sucht den Fehler bei sich statt bei der App.
///
/// Deshalb prüft jeder Test hier beide Seiten: dass die mehrdeutige Frage
/// **nicht** entsteht und die eindeutige schon.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/game/party/domain/fahrzeugfragen.dart';
import 'package:fwapp/features/game/party/domain/party_frage.dart';

void main() {
  final zufall = Random(1);

  FahrzeugStand wagen(String name, List<String> geraete, {String? kfz}) =>
      FahrzeugStand(
        name: name,
        kennzeichen: kfz,
        geraete: [for (final g in geraete) GeraetAufFahrzeug(name: g)],
      );

  List<PartyFrage> wohin(List<PartyFrage> f) =>
      f.where((x) => x.text == 'Auf welchem Fahrzeug liegt das?').toList();
  List<PartyFrage> kfzFragen(List<PartyFrage> f) => f
      .where((x) => x.text == 'Welches Kennzeichen hat dieses Fahrzeug?')
      .toList();

  group('Auf welchem Fahrzeug liegt das?', () {
    test('ein Gerät auf genau einem Wagen ergibt eine Frage', () {
      final fragen = wohin(baueFahrzeugfragen([
        wagen('HLF 20', ['Spreizer']),
        wagen('LF 20', ['Schaumrohr']),
        wagen('DLK 23/13', ['Rettungskorb']),
      ], zufall));

      expect(fragen, hasLength(3));
      final spreizer = fragen.firstWhere((f) => f.kopfzeile == 'Spreizer');
      expect(spreizer.antworten[spreizer.richtig].text, 'HLF 20');
      expect(spreizer.art, PartyFrageArt.fahrzeug);
    });

    test('ein Gerät auf MEHREREN Wagen ergibt KEINE Frage', () {
      // Der Kern: Ein B-Schlauch liegt auf jedem Wagen. Die Frage hätte drei
      // richtige Antworten.
      final fragen = wohin(baueFahrzeugfragen([
        wagen('HLF 20', ['B-Druckschlauch', 'Spreizer']),
        wagen('LF 20', ['B-Druckschlauch']),
        wagen('DLK 23/13', ['B-Druckschlauch']),
      ], zufall));

      expect(fragen.map((f) => f.kopfzeile), ['Spreizer']);
    });

    test('dasselbe Gerät zweimal auf DEMSELBEN Wagen bleibt eindeutig', () {
      // Zwei Datensätze, ein Wagen — die Antwort ist trotzdem eindeutig.
      // Gezählt werden Fahrzeuge, nicht Zeilen.
      final fragen = wohin(baueFahrzeugfragen([
        wagen('HLF 20', ['Strahlrohr', 'Strahlrohr']),
        wagen('LF 20', ['Schaumrohr']),
        wagen('DLK 23/13', ['Rettungskorb']),
      ], zufall));

      final strahlrohr =
          fragen.where((f) => f.kopfzeile == 'Strahlrohr').toList();
      expect(strahlrohr, hasLength(2), reason: 'Zwei Zeilen, zwei Fragen.');
      for (final f in strahlrohr) {
        expect(f.antworten[f.richtig].text, 'HLF 20');
      }
    });

    test('die Antworten sind verschieden und die richtige ist dabei', () {
      final fragen = wohin(baueFahrzeugfragen([
        wagen('HLF 20', ['Spreizer']),
        wagen('LF 20', ['Schaumrohr']),
        wagen('DLK 23/13', ['Rettungskorb']),
        wagen('MTW', ['Funkgerät']),
        wagen('AB-G', ['Pumpe']),
      ], zufall));

      for (final f in fragen) {
        final texte = f.antworten.map((a) => a.text).toList();
        expect(texte.toSet(), hasLength(texte.length), reason: f.kopfzeile);
        expect(texte.length, 4);
        expect(f.richtig, inInclusiveRange(0, texte.length - 1));
      }
    });
  });

  group('Welches Kennzeichen hat dieses Fahrzeug?', () {
    test('nur Fahrzeuge mit erfasstem Kennzeichen', () {
      final fragen = kfzFragen(baueFahrzeugfragen([
        wagen('HLF 20', [], kfz: 'FW-AB 1'),
        wagen('LF 20', [], kfz: 'FW-AB 2'),
        wagen('DLK 23/13', [], kfz: 'FW-AB 3'),
        wagen('MTW', []),
      ], zufall));

      expect(fragen.map((f) => f.kopfzeile),
          containsAll(['HLF 20', 'LF 20', 'DLK 23/13']));
      expect(fragen.map((f) => f.kopfzeile), isNot(contains('MTW')));
    });

    test('unter drei Kennzeichen entsteht keine Frage', () {
      final fragen = kfzFragen(baueFahrzeugfragen([
        wagen('HLF 20', [], kfz: 'FW-AB 1'),
        wagen('LF 20', [], kfz: 'FW-AB 2'),
        wagen('DLK 23/13', []),
      ], zufall));
      expect(fragen, isEmpty);
    });

    test('ein doppelt erfasstes Kennzeichen fällt heraus', () {
      // Ein Tippfehler im Bestand macht sonst zwei richtige Antworten.
      final fragen = kfzFragen(baueFahrzeugfragen([
        wagen('HLF 20', [], kfz: 'FW-AB 1'),
        wagen('LF 20', [], kfz: 'FW-AB 1'),
        wagen('DLK 23/13', [], kfz: 'FW-AB 3'),
        wagen('MTW', [], kfz: 'FW-AB 4'),
      ], zufall));

      expect(fragen.map((f) => f.kopfzeile),
          isNot(anyElement(isIn(['HLF 20', 'LF 20']))));
      expect(fragen.map((f) => f.kopfzeile),
          containsAll(['DLK 23/13', 'MTW']));
    });
  });

  test('unter drei Fahrzeugen entsteht gar nichts', () {
    // Bei zwei Wagen ist die falsche Antwort immer der jeweils andere —
    // das ist keine Frage, das ist eine Münze.
    expect(
      baueFahrzeugfragen([
        wagen('HLF 20', ['Spreizer'], kfz: 'FW-AB 1'),
        wagen('LF 20', ['Schaumrohr'], kfz: 'FW-AB 2'),
      ], zufall),
      isEmpty,
    );
  });

  test('ein leerer Fuhrpark wirft nicht', () {
    expect(baueFahrzeugfragen(const [], zufall), isEmpty);
  });
}
