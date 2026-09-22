/// geraete_suche_test.dart – Was als Treffer gilt (Issue #180).
///
/// Die Fälle stammen aus dem Gerätehaus, nicht aus der Theorie: Am Handy
/// tippt niemand Umlaute, niemand kennt den amtlichen Namen auswendig, und
/// die Hälfte des Katalogs ist noch in keinem Fahrzeug eingetragen. Eine
/// Suche, die daran scheitert, ist im Einsatz wertlos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/compartment/presentation/fach_antwort.dart';
import 'package:fwapp/features/search/domain/geraete_suche.dart';

Fundort fundort({
  int vehicleId = 1,
  String fahrzeug = 'HLF 20',
  int compartmentId = 10,
  String fach = 'G1',
  String? seite = 'fahrerseite',
  int menge = 1,
}) => Fundort(
  vehicleId: vehicleId,
  fahrzeug: fahrzeug,
  compartmentId: compartmentId,
  fach: FachAntwort(label: fach, seite: seite),
  menge: menge,
);

GeraetTreffer geraet(
  int id,
  String name, {
  String? kurzname,
  List<Fundort> fundorte = const [],
  List<Geraetecode> codes = const [],
}) => GeraetTreffer(
  equipmentId: id,
  name: name,
  kurzname: kurzname,
  fundorte: fundorte,
  codes: codes,
);

void main() {
  group('suchform', () {
    test('löst Umlaute und ß auf', () {
      // Der Grund: „schlauch" ist in „Schläuche" KEINE Teilzeichenkette.
      // Ohne diese Faltung fände die häufigste Eingabe der Welt nichts.
      expect(suchform('Schläuche'), 'schlauche');
      expect(suchform('Straße'), 'strasse');
      expect(suchform('Öl-Bindemittel'), 'ol bindemittel');
    });

    test('macht aus Trennzeichen Leerzeichen', () {
      expect(suchform('HD-Schlauch'), 'hd schlauch');
      expect(suchform('C 42  /  15'), 'c 42 15');
    });
  });

  group('sucheGeraete', () {
    final spreizer = geraet(
      1,
      'Spreizer',
      fundorte: [fundort(fach: 'G3', menge: 1)],
    );
    final schlauch = geraet(
      2,
      'C-Schläuche',
      kurzname: 'C42',
      fundorte: [
        fundort(fach: 'G1', menge: 6),
        fundort(vehicleId: 2, fahrzeug: 'LF 20', fach: 'G4', menge: 4),
      ],
    );
    final schere = geraet(
      3,
      'Akku-Rettungsschere',
      fundorte: [fundort(vehicleId: 2, fahrzeug: 'LF 20', fach: 'G2')],
    );
    final nirgends = geraet(4, 'Wärmebildkamera');
    final bestand = [spreizer, schlauch, schere, nirgends];

    SucheErgebnis suche(String eingabe, {int? vehicleId}) =>
        sucheGeraete(bestand: bestand, eingabe: eingabe, vehicleId: vehicleId);

    test('leere Eingabe liefert nichts, nicht den ganzen Bestand', () {
      // Der ganze Bestand wäre keine Suche, sondern die Fahrzeugansicht.
      expect(suche('').istLeer, isTrue);
      expect(suche('   ').istLeer, isTrue);
    });

    test('findet über den ganzen Fuhrpark und nennt jeden Fundort', () {
      final treffer = suche('schlauch').treffer.single;
      expect(treffer.name, 'C-Schläuche');
      expect(treffer.fundorte.map((f) => f.fahrzeug), ['HLF 20', 'LF 20']);
      expect(treffer.gesamtmenge, 10);
    });

    test('ohne Umlaut getippt wird trotzdem gefunden', () {
      expect(suche('schlauche').treffer.single.equipmentId, 2);
    });

    test('der Kurzname zählt mit — in der Halle sagt niemand den langen', () {
      expect(suche('c42').treffer.single.equipmentId, 2);
    });

    test('mehrere Begriffe, Reihenfolge egal', () {
      // „schere akku" muss die „Akku-Rettungsschere" finden; als reine
      // Teilzeichenkette täte es das nicht.
      expect(suche('schere akku').treffer.single.equipmentId, 3);
      expect(suche('akku schere').treffer.single.equipmentId, 3);
    });

    test('alle Begriffe müssen passen', () {
      expect(suche('akku spreizer').istLeer, isTrue);
    });

    test('was nirgends verlastet ist, wird als solches gemeldet', () {
      // „Nichts gefunden" wäre falsch: Das Gerät gibt es, es ist nur in
      // keinem Fahrzeug eingetragen — bei einer Wehr, die gerade erst
      // erfasst, die häufigste und nützlichste Auskunft.
      final ergebnis = suche('wärmebild');
      expect(ergebnis.treffer, isEmpty);
      expect(ergebnis.nirgends.single.equipmentId, 4);
      expect(ergebnis.nirgends.single.istVerlastet, isFalse);
    });

    test('gar kein Treffer bleibt gar kein Treffer', () {
      expect(suche('hubschrauber').istLeer, isTrue);
    });

    group('auf ein Fahrzeug eingegrenzt', () {
      test('zeigt nur die Fundorte dieses Fahrzeugs', () {
        final treffer = suche('schlauch', vehicleId: 1).treffer.single;
        expect(treffer.fundorte, hasLength(1));
        expect(treffer.fundorte.single.fahrzeug, 'HLF 20');
        expect(treffer.fundorte.single.menge, 6);
      });

      test('„nicht hier, aber im LF 20" statt „keine Treffer"', () {
        // Das ist der eigentliche Nutzen am Fahrzeug. Ein leeres Ergebnis
        // wäre hier nicht bloß unfreundlich, sondern sachlich falsch.
        final ergebnis = suche('schere', vehicleId: 1);
        expect(ergebnis.treffer, isEmpty);
        final anderswo = ergebnis.woanders.single;
        expect(anderswo.name, 'Akku-Rettungsschere');
        expect(anderswo.fundorte.single.fahrzeug, 'LF 20');
      });

      test('nirgends verlastet bleibt nirgends verlastet', () {
        final ergebnis = suche('wärmebild', vehicleId: 1);
        expect(ergebnis.treffer, isEmpty);
        expect(ergebnis.woanders, isEmpty);
        expect(ergebnis.nirgends, hasLength(1));
      });
    });

    test('Treffer stehen alphabetisch, nicht in Datenbankreihenfolge', () {
      final namen = sucheGeraete(
        bestand: [
          geraet(1, 'Zange', fundorte: [fundort()]),
          geraet(2, 'Ölkanne', fundorte: [fundort()]),
          geraet(3, 'Axt', fundorte: [fundort()]),
        ],
        eingabe: 'a',
        vehicleId: null,
      ).treffer.map((t) => t.name);
      // „Ölkanne" sortiert unter O, nicht hinter Z — dieselbe Faltung wie
      // beim Suchen. Ohne sie stünden alle Umlaut-Geräte am Listenende.
      expect(namen, ['Axt', 'Ölkanne', 'Zange']);
    });
  });

  group('Code nachschlagen (#176)', () {
    // Der Fall aus dem Gerätehaus: Jemand findet ein Strahlrohr im falschen
    // Fach, hält die Kamera drauf — und will wissen, wo es hingehört.
    final strahlrohr = geraet(
      1,
      'Strahlrohr C',
      fundorte: [
        fundort(compartmentId: 10, fach: 'G1'),
        fundort(compartmentId: 20, fach: 'G2'),
      ],
      codes: [
        const Geraetecode(
          code: 'FW-7K2M9Q',
          kennung: 'SR 2',
          compartmentId: 20,
        ),
      ],
    );
    final spreizer = geraet(2, 'Spreizer', fundorte: [fundort(fach: 'G3')]);
    final bestand = [strahlrohr, spreizer];

    test('ein Code führt auf genau ein Gerät', () {
      final e = sucheGeraete(bestand: bestand, eingabe: 'FW-7K2M9Q');
      expect(e.treffer, hasLength(1));
      expect(e.treffer.single.name, 'Strahlrohr C');
      expect(e.codeTreffer?.kennung, 'SR 2');
    });

    test('die Einheit entscheidet über das Fach, nicht das Gerät', () {
      // ⚠️ Der Punkt: Strahlrohre liegen in G1 UND G2. Der Aufkleber klebt
      // auf EINEM Gegenstand, und der liegt in G2. „G1 oder G2" wäre keine
      // Antwort für jemanden, der es zurücklegen will.
      final e = sucheGeraete(bestand: bestand, eingabe: 'FW-7K2M9Q');
      expect(e.treffer.single.fundorte, hasLength(1));
      expect(e.treffer.single.fundorte.single.fach.label, 'G2');
    });

    test('Schreibweise und Leerraum sind egal — wie beim Scannen', () {
      // Ein Handscanner hängt gern ein Zeilenende an.
      for (final eingabe in ['fw-7k2m9q', '  FW-7K2M9Q\n', 'FW- 7K2 M9Q']) {
        expect(
          sucheGeraete(bestand: bestand, eingabe: eingabe).codeTreffer,
          isNotNull,
          reason: 'Eingabe: $eingabe',
        );
      }
    });

    test('ein Teilstück ist KEIN Code-Treffer', () {
      // ⚠️ Sonst träfe „FW" jeden vergebenen Code, und die Namenssuche wäre
      // unbrauchbar, sobald Codes im Bestand sind.
      final e = sucheGeraete(bestand: bestand, eingabe: 'FW');
      expect(e.codeTreffer, isNull);
    });

    test('was kein Code ist, sucht weiter nach Namen', () {
      final e = sucheGeraete(bestand: bestand, eingabe: 'spreizer');
      expect(e.codeTreffer, isNull);
      expect(e.treffer.single.name, 'Spreizer');
    });

    test('ein unbekannter Code fällt auf die Namenssuche zurück', () {
      // Und die findet nichts — „kein Gerät gefunden" ist hier die richtige
      // Antwort, nicht ein leerer Code-Treffer.
      final e = sucheGeraete(bestand: bestand, eingabe: 'FW-ZZZZZZZ');
      expect(e.codeTreffer, isNull);
      expect(e.istLeer, isTrue);
    });

    test('am falschen Fahrzeug sagt die Suche, wo es hingehört', () {
      // Jemand steht am MTW und hat ein Teil aus dem HLF in der Hand.
      final e = sucheGeraete(
        bestand: bestand,
        eingabe: 'FW-7K2M9Q',
        vehicleId: 99,
      );
      expect(e.treffer, isEmpty);
      expect(e.woanders.single.name, 'Strahlrohr C');
      expect(e.codeTreffer, isNotNull);
    });

    test('ein Code auf einem nirgends verlasteten Gerät sagt genau das', () {
      final reserve = geraet(
        3,
        'Pressluftatmer',
        codes: [const Geraetecode(code: 'FW-AAAAAAA', kennung: 'Reserve 1')],
      );
      final e = sucheGeraete(bestand: [reserve], eingabe: 'FW-AAAAAAA');
      expect(e.nirgends.single.name, 'Pressluftatmer');
      expect(e.codeTreffer?.kennung, 'Reserve 1');
    });

    test('eine Einheit ohne Fach erbt die Fundorte des Geräts', () {
      // Kommt vor: Code vergeben, Einheit noch keinem Fach zugeordnet.
      // Dann ist „liegt in G1 und G2" die beste Auskunft, die es gibt.
      final ohneFach = geraet(
        4,
        'Strahlrohr C',
        fundorte: [
          fundort(compartmentId: 10, fach: 'G1'),
          fundort(compartmentId: 20, fach: 'G2'),
        ],
        codes: [const Geraetecode(code: 'FW-BBBBBBB')],
      );
      final e = sucheGeraete(bestand: [ohneFach], eingabe: 'FW-BBBBBBB');
      expect(e.treffer.single.fundorte, hasLength(2));
    });
  });
}
