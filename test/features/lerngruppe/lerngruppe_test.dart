/// lerngruppe_test.dart – Laufzeit, Sortierung, Code und Fehlertexte der
/// Lerngruppen (Issue #136), ohne Server.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/lerngruppe/domain/lerngruppe.dart';

Lerngruppe _gruppe(String id, DateTime bis) => Lerngruppe(
  id: id,
  gesamtwehrId: 'G',
  name: 'Gruppe $id',
  code: '042137',
  laeuftBis: bis,
);

void main() {
  // Nachmittags: Die Uhrzeit darf an der Tageszählung nichts ändern.
  final heute = DateTime(2026, 9, 23, 17, 45);

  group('Laufzeit', () {
    test('am letzten Tag läuft die Gruppe noch — wie auf dem Server', () {
      final g = _gruppe('a', DateTime(2026, 9, 23));
      expect(g.laeuftAm(heute), isTrue);
      expect(g.restTage(heute), 0);
      expect(g.laufzeitText(heute), 'endet heute');
    });

    test('am Tag danach ist sie beendet', () {
      final g = _gruppe('a', DateTime(2026, 9, 22));
      expect(g.laeuftAm(heute), isFalse);
      expect(g.laufzeitText(heute), 'beendet am 22.09.2026');
    });

    test('Resttage zählen Kalendertage, nicht 24-Stunden-Blöcke', () {
      final g = _gruppe('a', DateTime(2026, 11, 18));
      expect(g.restTage(heute), 56);
      expect(g.laufzeitText(heute), 'läuft noch 56 Tage, bis 18.11.2026');
      expect(
        _gruppe('b', DateTime(2026, 9, 24)).laufzeitText(heute),
        'läuft noch bis morgen',
      );
    });

    test('liest das Datum aus der Serverzeile', () {
      final g = Lerngruppe.fromJson({
        'id': 'x',
        'gesamtwehr_id': 'G',
        'name': 'Herbst',
        'code': '000123',
        'laeuft_bis': '2026-11-18',
      });
      expect(g.laeuftBis, DateTime(2026, 11, 18));
      expect(g.codeLesbar, '000 123');
    });
  });

  test('laufende zuerst, die bald endende oben; beendete danach, jüngste '
      'zuerst', () {
    final sortiert = sortiereLerngruppen([
      _gruppe('alt', DateTime(2026, 5, 1)),
      _gruppe('lang', DateTime(2026, 12, 1)),
      _gruppe('juengst', DateTime(2026, 9, 1)),
      _gruppe('bald', DateTime(2026, 9, 30)),
    ], heute);
    expect(sortiert.map((g) => g.id), ['bald', 'lang', 'juengst', 'alt']);
  });

  group('Code-Eingabe', () {
    test('nimmt Leerzeichen und Bindestriche aus dem Chat hin', () {
      expect(normalisiereCode('042137'), '042137');
      expect(normalisiereCode(' 042 137 '), '042137');
      expect(normalisiereCode('042-137'), '042137');
    });

    test('lehnt alles andere als genau sechs Ziffern ab', () {
      expect(normalisiereCode('04213'), isNull);
      expect(normalisiereCode('0421378'), isNull);
      expect(normalisiereCode('O42137'), isNull); // Buchstabe O
      expect(normalisiereCode(''), isNull);
    });
  });

  test('der Einladungstext sagt, wo der Code hingehört', () {
    final text = _gruppe('a', DateTime(2026, 11, 18)).einladungsText;
    expect(text, contains('042 137'));
    expect(text, contains('Mit Code beitreten'));
  });

  group('Fehlertexte', () {
    test('übersetzt jede Meldung der RPCs', () {
      // Wortlaute exakt aus 20260922190000_lerngruppen.sql. Wer dort eine
      // Meldung ändert, sieht es hier.
      const meldungen = {
        'Diesen Beitrittscode gibt es nicht': 'Vertippt',
        'Diese Lerngruppe ist abgelaufen': 'schon zu Ende',
        'Diese Lerngruppe gehoert zu einer anderen Feuerwehr':
            'anderen Feuerwehr',
        'Keine Berechtigung fuer diese Gesamtwehr': 'nicht zu dieser',
        'Laufzeit muss zwischen 1 und 26 Wochen liegen': '26 Wochen',
        'Kein freier Beitrittscode gefunden': 'noch einmal',
        'new row for relation "lerngruppen" violates check constraint '
                '"lerngruppen_name_check"':
            '60 Zeichen',
      };
      for (final MapEntry(key: roh, value: erwartet) in meldungen.entries) {
        final text = lerngruppeFehlerText(roh);
        expect(text, contains(erwartet), reason: roh);
        expect(text, isNot(contains('oe')), reason: 'ASCII-Umschrift: $roh');
      }
    });

    test('ohne Netz ein Satz statt einer Ausnahme', () {
      expect(
        lerngruppeFehlerText('ClientException: Failed host lookup: x'),
        contains('Keine Verbindung'),
      );
    });

    test('Unbekanntes bleibt im Original', () {
      expect(lerngruppeFehlerText('etwas ganz anderes'), 'etwas ganz anderes');
    });
  });

  test('ein Mitglied ohne Namen steht nicht als leere Zeile da', () {
    final m = LerngruppenMitglied.fromJson({
      'user_id': 'u',
      'anzeigename': '  ',
      'avatar': null,
      'beigetreten_am': '2026-09-22T10:00:00Z',
    });
    expect(m.anzeigeName, 'Unbenannt');
    expect(m.beigetretenAm, isNotNull);
  });
}
