/// zustellung_test.dart – Kam die Einladung an? (Issue #121)
///
/// Der Fall aus dem Feld war kein Grenzfall: Eine Adresse bekam
/// `requests` → `softBounces` („Internal Error: DKIM Bad request"), die
/// andere `delivered` — und die App zeigte für beide „wartet auf
/// Bestätigung". Geprüft wird deshalb genau die Regel, die diese beiden
/// Zeilen auseinanderhält, samt der Fälle, in denen sie kippt.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/sync/auth_utils.dart';
import 'package:fwapp/features/settings/domain/zustellung.dart';

Zustellereignis _ev(String art, int minute, {String? grund}) => Zustellereignis(
      art: art,
      zeit: DateTime.utc(2026, 8, 4, 19, minute),
      grund: grund,
    );

void main() {
  group('die Einordnung', () {
    test('ohne Ereignis weiß der Server nichts — und sagt das auch', () {
      // Der wichtigste Zustand des ganzen Issues: „unbekannt" ist NICHT
      // „alles in Ordnung". Genau diese Gleichsetzung war der Fehler.
      expect(zustellungAus(const []).zustand, Zustellzustand.unbekannt);
    });

    test('angenommen, aber noch kein Ergebnis = unterwegs', () {
      expect(zustellungAus([_ev('requests', 1)]).zustand,
          Zustellzustand.unterwegs);
      // `deferred` heißt: Der Anbieter lässt warten. Kein Grund zur Sorge.
      expect(zustellungAus([_ev('requests', 1), _ev('deferred', 2)]).zustand,
          Zustellzustand.unterwegs);
    });

    test('zugestellt ist zugestellt', () {
      final z = zustellungAus([_ev('requests', 1), _ev('delivered', 2)]);
      expect(z.zustand, Zustellzustand.zugestellt);
      expect(z.zeit, DateTime.utc(2026, 8, 4, 19, 2));
    });

    test('der Fall aus dem Feld: Soft Bounce ohne Zustellung ist ein Ausfall',
        () {
      // „Vorübergehend" klingt harmlos und ist es nicht: Kommt kein
      // späteres `delivered`, ist die Mail genauso weg wie bei einem harten
      // Bounce — und niemand hat es gemerkt.
      final z = zustellungAus([
        _ev('requests', 1),
        _ev('softBounces', 2, grund: 'Internal Error: DKIM Bad request'),
      ]);
      expect(z.zustand, Zustellzustand.gescheitert);
      expect(z.grund, contains('Internal Error: DKIM Bad request'));
      expect(z.grund, contains('vorübergehend abgelehnt'));
      expect(z.zeit, DateTime.utc(2026, 8, 4, 19, 2));
    });

    test('ein geglückter Wiederholungsversuch hebt den Soft Bounce auf', () {
      // Brevo versucht es erneut. Klappt es, wäre eine Warnung falscher
      // Alarm — und falscher Alarm bringt Leute dazu, echte zu übersehen.
      final z = zustellungAus([
        _ev('softBounces', 2, grund: 'mailbox busy'),
        _ev('delivered', 5),
      ]);
      expect(z.zustand, Zustellzustand.zugestellt);
    });

    test('ein späterer Fehlversuch schlägt eine frühere Zustellung', () {
      // „Erneut senden" nach einer alten Zustellung. Eine Regel „einmal
      // zugestellt, immer zugestellt" verschwiege genau den Fall, für den
      // es den Knopf gibt.
      final z = zustellungAus([
        _ev('delivered', 2),
        _ev('hardBounces', 9, grund: 'unknown user'),
      ]);
      expect(z.zustand, Zustellzustand.gescheitert);
      expect(z.grund, contains('unknown user'));
    });

    test('bei gleicher Zeit gewinnt der Fehler', () {
      // Warnen und danebenliegen kostet einen Blick; nicht warnen kostet
      // die Einladung.
      final z = zustellungAus([_ev('delivered', 3), _ev('blocked', 3)]);
      expect(z.zustand, Zustellzustand.gescheitert);
    });

    test('die Reihenfolge der Liste ändert nichts', () {
      // Brevo liefert neueste zuerst; darauf darf sich nichts verlassen.
      final vorwaerts = zustellungAus([_ev('softBounces', 2), _ev('delivered', 5)]);
      final rueckwaerts =
          zustellungAus([_ev('delivered', 5), _ev('softBounces', 2)]);
      expect(vorwaerts.zustand, rueckwaerts.zustand);
    });

    test('unbekannte Arten zählen nicht mit', () {
      // `opened` sollte gar nicht ankommen (der Server wirft es weg, weil
      // Postfach-Scanner es auslösen). Käme es doch, darf es kein Urteil
      // begründen.
      expect(zustellungAus([_ev('opened', 4)]).zustand,
          Zustellzustand.unterwegs);
    });

    test('ohne Begründung steht wenigstens die Art da', () {
      final z = zustellungAus([_ev('invalid', 2)]);
      expect(z.grund, 'Adresse ungültig');
    });

    test('jede Fehlerart hat einen deutschen Text', () {
      for (final art in kZustellFehlerArten) {
        expect(kZustellArtText[art], isNotNull, reason: art);
      }
    });
  });

  group('die Zeile darunter', () {
    test('benennt den Zustand', () {
      expect(zustellungText(zustellungAus([_ev('delivered', 1)])), 'zugestellt');
      expect(zustellungText(zustellungAus([_ev('requests', 1)])), 'unterwegs');
      expect(zustellungText(Zustellung.unbekannt), 'Zustellung nicht prüfbar');
      expect(
        zustellungText(zustellungAus([_ev('hardBounces', 1)])),
        'unzustellbar: Adresse existiert nicht',
      );
    });
  });

  group('der Nutzername-Vorschlag fürs Zettel-Konto', () {
    test('nimmt den lokalen Teil der Adresse', () {
      expect(zugangsnameVorschlag('max.mustermann@web.de'), 'max.mustermann');
      expect(zugangsnameVorschlag('Klaus-Peter@GMX.de'), 'klaus-peter');
    });

    test('wirft weg, was in keinem Nutzernamen stehen darf', () {
      expect(zugangsnameVorschlag('jörg+feuerwehr@web.de'), 'jrgfeuerwehr');
      expect(zugangsnameVorschlag('_max_@web.de'), 'max');
    });

    test('lieber leer als krumm', () {
      // Der Vorschlag landet auf einem Zettel, den jemand abtippt. Ein
      // zurechtgebogener Name wäre schlimmer als ein leeres Feld.
      expect(zugangsnameVorschlag('a@web.de'), '');
      expect(zugangsnameVorschlag('___@web.de'), '');
      expect(zugangsnameVorschlag(''), '');
    });

    test('was herauskommt, ist immer ein gültiger Nutzername', () {
      for (final adresse in const [
        'max.mustermann@web.de',
        'jörg+feuerwehr@web.de',
        'a.b@x.de',
        'ÄÖÜ@x.de',
      ]) {
        final v = zugangsnameVorschlag(adresse);
        expect(v.isEmpty || isValidUsername(v), isTrue, reason: adresse);
      }
    });
  });
}
