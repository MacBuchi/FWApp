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
}) =>
    Fundort(
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
}) =>
    GeraetTreffer(
      equipmentId: id,
      name: name,
      kurzname: kurzname,
      fundorte: fundorte,
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
    final spreizer = geraet(1, 'Spreizer',
        fundorte: [fundort(fach: 'G3', menge: 1)]);
    final schlauch = geraet(2, 'C-Schläuche',
        kurzname: 'C42',
        fundorte: [
          fundort(fach: 'G1', menge: 6),
          fundort(vehicleId: 2, fahrzeug: 'LF 20', fach: 'G4', menge: 4),
        ]);
    final schere = geraet(3, 'Akku-Rettungsschere',
        fundorte: [fundort(vehicleId: 2, fahrzeug: 'LF 20', fach: 'G2')]);
    final nirgends = geraet(4, 'Wärmebildkamera');
    final bestand = [spreizer, schlauch, schere, nirgends];

    SucheErgebnis suche(String eingabe, {int? vehicleId}) => sucheGeraete(
        bestand: bestand, eingabe: eingabe, vehicleId: vehicleId);

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
}
