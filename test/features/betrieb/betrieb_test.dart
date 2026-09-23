/// betrieb_test.dart – Modell, Warnstufen und der Ablauf „ernennen, sonst
/// einladen" der KreisDatenMeister-Konsole (Issue #101), ohne Server.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/betrieb/domain/betrieb.dart';
import 'package:fwapp/features/betrieb/presentation/providers/betrieb_providers.dart';

KdmWehr _wehr({
  int kommandanten = 2,
  int einladungen = 0,
  bool still = false,
}) => KdmWehr(
  id: 'g',
  name: 'Musterstadt',
  stillgelegtAm: still ? DateTime(2026, 9, 1) : null,
  kommandanten: [
    for (var i = 0; i < kommandanten; i++)
      KdmKommandant(userId: 'k$i', name: 'K$i'),
  ],
  offeneEinladungen: einladungen,
);

void main() {
  test('liest die Zeile von kdm_gesamtwehren', () {
    final w = KdmWehr.fromJson({
      'id': 'g1',
      'name': 'Feuerwehr Musterstadt',
      'created_at': '2026-09-23T08:00:00Z',
      'stillgelegt_am': null,
      'abteilungen': [
        {'id': 'a1', 'name': 'Mitte'},
        {'id': 'a2', 'name': 'Nord'},
      ],
      'mitglieder': 14,
      'kommandanten': [
        {'user_id': 'u1', 'name': 'Erika', 'email': 'erika@example.org'},
        {'user_id': 'u2', 'name': '  ', 'email': null},
      ],
      'offene_einladungen': 1,
      'zuletzt_veroeffentlicht': '2026-09-20T10:00:00Z',
    });
    expect(w.abteilungen.map((a) => a.name), ['Mitte', 'Nord']);
    expect(w.mitglieder, 14);
    expect(w.kommandanten.first.email, 'erika@example.org');
    // Ein Konto ohne Namen steht nicht als leere Zeile da.
    expect(w.kommandanten.last.name, 'Unbenannt');
    expect(w.stillgelegt, isFalse);
    expect(w.zuletztVeroeffentlicht, isNotNull);
  });

  group('Warnung', () {
    test('ohne Kommandant und ohne Einladung: dringend', () {
      final w = _wehr(kommandanten: 0).warnung!;
      expect(w.dringend, isTrue);
      expect(w.text, contains('Niemand kann hier einladen'));
    });

    test('ohne Kommandant, aber mit Einladung unterwegs: nicht dringend', () {
      final w = _wehr(kommandanten: 0, einladungen: 1).warnung!;
      expect(w.dringend, isFalse);
      expect(w.text, contains('unterwegs'));
    });

    test('ein Kommandant: Aussperr-Schutz fehlt', () {
      expect(_wehr(kommandanten: 1).warnung!.text, contains('ausgesperrt'));
    });

    test('zwei Kommandanten oder stillgelegt: nichts zu tun', () {
      expect(_wehr().warnung, isNull);
      expect(_wehr(kommandanten: 0, still: true).warnung, isNull);
    });
  });

  test('Veröffentlichungsstand als Satz', () {
    expect(veroeffentlichtText(null), 'noch nie veröffentlicht');
    expect(
      veroeffentlichtText(DateTime(2026, 9, 3)),
      'zuletzt veröffentlicht am 03.09.2026',
    );
  });

  group('Kommandant hinzufügen', () {
    test('mit Konto: ernannt, keine Einladung', () async {
      var eingeladen = false;
      final weg = await kommandantHinzufuegen(
        ernenne: () async {},
        ladeEin: () async => eingeladen = true,
      );
      expect(weg, KommandantWeg.ernannt);
      expect(eingeladen, isFalse);
    });

    test('ohne Konto: Einladung', () async {
      final weg = await kommandantHinzufuegen(
        ernenne:
            () async =>
                throw Exception(
                  'Kein bestaetigtes Konto zu dieser Adresse - bitte einladen',
                ),
        ladeEin: () async {},
      );
      expect(weg, KommandantWeg.eingeladen);
    });

    test('ein anderer Fehler kommt durch und lädt NICHT ein', () async {
      // Etwa „stillgelegt" oder keine Berechtigung — daraus eine Einladung
      // zu machen, verschleierte den eigentlichen Grund.
      var eingeladen = false;
      await expectLater(
        kommandantHinzufuegen(
          ernenne:
              () async => throw Exception('Nur fuer den KreisDatenMeister'),
          ladeEin: () async => eingeladen = true,
        ),
        throwsA(isA<Exception>()),
      );
      expect(eingeladen, isFalse);
    });
  });

  group('Fehlertexte', () {
    test('übersetzt die Meldungen der kdm-Funktionen', () {
      expect(
        betriebFehlerText(Exception('Nur fuer den KreisDatenMeister')),
        contains('nur der KreisDatenMeister'),
      );
      expect(
        betriebFehlerText(Exception('Diese Gesamtwehr gibt es nicht')),
        'Diese Gesamtwehr gibt es nicht mehr.',
      );
      expect(
        betriebFehlerText(Exception('ClientException: Failed host lookup')),
        'Keine Verbindung zum Server.',
      );
    });

    test(
      'schon übersetzte Einladungsfehler bleiben, nur ohne „Exception:"',
      () {
        expect(
          betriebFehlerText(
            Exception('Für diese Adresse ist bereits eine Einladung offen.'),
          ),
          'Für diese Adresse ist bereits eine Einladung offen.',
        );
      },
    );

    test('eine angelegte Wehr ohne Einladung sagt beides', () {
      final text = betriebFehlerText(
        EinladungFehlgeschlagen(
          'g',
          Exception('Keine gültige E-Mail-Adresse.'),
        ),
      );
      expect(text, contains('angelegt'));
      expect(text, contains('Keine gültige E-Mail-Adresse.'));
      expect(text, contains('Kommandant hinzufügen'));
    });
  });
}
