/// draufsicht_test.dart – Die Draufsicht zeigt das Fahrzeug von oben
/// (Issue #141).
///
/// Wie beim Aufklappbild wird nicht geprüft, DASS Kacheln erscheinen,
/// sondern WO: Front oben, Fahrerseite links, Dach in der Mitte,
/// Beifahrerseite rechts, Heck unten — und auf den Längsseiten vorne über
/// Mitte über hinten. Wer diese Geometrie ändert, ändert das Bild, das die
/// Mannschaft im Kopf hat.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_top_view.dart';

Compartment _fach(
  int id,
  String label, {
  String? seite,
  String? laengsposition,
  int position = 0,
}) => Compartment(
  id: id,
  vehicleId: 1,
  label: label,
  position: position == 0 ? id : position,
  gridColSpan: 1,
  seite: seite,
  laengsposition: laengsposition,
  updatedAt: DateTime(2026),
);

/// Ein komplett verorteter HLF — nach der Konvention der App: ungerade
/// Nummern auf der Fahrerseite, gerade auf der Beifahrerseite.
List<Compartment> _hlf() => [
  _fach(1, 'MR', seite: 'front'),
  _fach(2, 'G1', seite: 'fahrerseite', laengsposition: 'vorne'),
  _fach(3, 'G2', seite: 'beifahrerseite', laengsposition: 'vorne'),
  _fach(4, 'G3', seite: 'fahrerseite', laengsposition: 'mitte'),
  _fach(5, 'G4', seite: 'beifahrerseite', laengsposition: 'mitte'),
  _fach(6, 'G5', seite: 'fahrerseite', laengsposition: 'hinten'),
  _fach(7, 'G6', seite: 'beifahrerseite', laengsposition: 'hinten'),
  _fach(8, 'GR', seite: 'heck'),
  _fach(9, 'Dachkasten', seite: 'dach'),
];

Future<void> _zeige(
  WidgetTester tester,
  List<Compartment> faecher, {
  bool kompakt = false,
  Map<int, CutawayTileState> tileStates = const {},
  void Function(Compartment)? onTap,
}) async {
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: VehicleTopView(
            compartments: faecher,
            kompakt: kompakt,
            tileStates: tileStates,
            onTapCompartment: onTap,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('die Plätze einer Längsseite', () {
    test('mit Längsposition liegt jedes Fach fest', () {
      final slots = VehicleTopView.laengsSlots([
        _fach(1, 'G5', laengsposition: 'hinten'),
        _fach(2, 'G1', laengsposition: 'vorne'),
        _fach(3, 'G3', laengsposition: 'mitte'),
      ]);
      expect(slots[0].single.label, 'G1');
      expect(slots[1].single.label, 'G3');
      expect(slots[2].single.label, 'G5');
    });

    test('eine fehlende Position lässt den Platz sichtbar frei', () {
      // G1 vorne, G5 hinten, nichts in der Mitte — die Lücke ist echte
      // Ortsinformation und wird nicht zusammengeschoben.
      final slots = VehicleTopView.laengsSlots([
        _fach(1, 'G1', laengsposition: 'vorne'),
        _fach(2, 'G5', laengsposition: 'hinten'),
      ]);
      expect(slots[0].single.label, 'G1');
      expect(slots[1], isEmpty);
      expect(slots[2].single.label, 'G5');
    });

    test('ohne Positionen rücken die Fächer der Reihe nach auf', () {
      // Die Sortier-Reihenfolge wird als Fahrtrichtung gelesen — ein
      // Fahrzeug ohne Positionsangaben sieht trotzdem nach etwas aus.
      final slots = VehicleTopView.laengsSlots([
        _fach(1, 'G1', position: 1),
        _fach(2, 'G3', position: 2),
      ]);
      expect(slots[0].single.label, 'G1');
      expect(slots[1].single.label, 'G3');
      expect(slots[2], isEmpty);
    });

    test('verschwinden darf nichts, auch wenn der Platz nicht reicht', () {
      final slots = VehicleTopView.laengsSlots([
        for (var i = 1; i <= 5; i++) _fach(i, 'F$i', position: i),
      ]);
      expect(slots.expand((s) => s), hasLength(5));
      // Der Überhang sammelt sich im hintersten Platz.
      expect(slots[2].map((c) => c.label), containsAll(['F3', 'F4', 'F5']));
    });

    test('gemischt gewinnt die gesetzte Position ihren Platz', () {
      final slots = VehicleTopView.laengsSlots([
        _fach(1, 'Ohne', position: 1),
        _fach(2, 'Mitte', laengsposition: 'mitte'),
      ]);
      expect(slots[0].single.label, 'Ohne');
      expect(slots[1].single.label, 'Mitte');
    });
  });

  group('wann die Draufsicht ein Bild ergibt', () {
    test('erst mit mindestens einer bekannten Seite', () {
      expect(VehicleTopView.hatVerortung([_fach(1, 'G1')]), isFalse);
      expect(
        VehicleTopView.hatVerortung([
          _fach(1, 'Rätsel', seite: 'anhaengerkupplung'),
        ]),
        isFalse,
      );
      expect(
        VehicleTopView.hatVerortung([_fach(1, 'G1', seite: 'fahrerseite')]),
        isTrue,
      );
    });
  });

  group('die Geometrie', () {
    testWidgets('Front oben, Heck unten, Fahrerseite links, Dach dazwischen', (
      tester,
    ) async {
      await _zeige(tester, _hlf());

      double y(String text) => tester.getCenter(find.text(text)).dy;
      double x(String text) => tester.getCenter(find.text(text)).dx;

      // Längsachse von oben nach unten = Fahrtrichtung.
      expect(y('MR'), lessThan(y('G1')));
      expect(y('G1'), lessThan(y('G3')));
      expect(y('G3'), lessThan(y('G5')));
      expect(y('G5'), lessThan(y('GR')));

      // Querachse: Fahrerseite links, Dach in der Mitte, Beifahrerseite
      // rechts — der Blick von oben, Fahrtrichtung nach oben.
      expect(x('G1'), lessThan(x('Dachkasten')));
      expect(x('Dachkasten'), lessThan(x('G2')));

      // Gleiche Längsposition = gleiche Höhe, links wie rechts.
      expect(y('G1'), moreOrLessEquals(y('G2'), epsilon: 1));
      expect(y('G3'), moreOrLessEquals(y('G4'), epsilon: 1));
    });

    testWidgets('ein Fach ohne Seite bleibt sichtbar — unter dem Schema', (
      tester,
    ) async {
      await _zeige(tester, [
        _fach(1, 'G1', seite: 'fahrerseite'),
        _fach(2, 'Ablage'),
        _fach(3, 'Rätsel', seite: 'anhaengerkupplung'),
      ]);
      expect(find.text('OHNE SEITE'), findsOneWidget);
      expect(find.text('Ablage'), findsOneWidget);
      // Server neuer als die App: Ein unbekannter Wert geht nicht verloren.
      expect(find.text('Rätsel'), findsOneWidget);
    });

    testWidgets('Tippen liefert das Fach', (tester) async {
      Compartment? getippt;
      await _zeige(tester, _hlf(), onTap: (c) => getippt = c);
      await tester.tap(find.text('G3'));
      expect(getippt?.label, 'G3');
    });

    testWidgets('die Zähler stehen in der großen Ansicht …', (tester) async {
      await _zeige(
        tester,
        _hlf(),
        tileStates: {2: const CutawayTileState(itemCount: 15)},
      );
      expect(find.text('15 Geräte'), findsOneWidget);
      expect(find.text('FAHRTRICHTUNG ▲'), findsOneWidget);
    });

    testWidgets('… und im Mini-Schema steht nur das Bild', (tester) async {
      await _zeige(
        tester,
        _hlf(),
        kompakt: true,
        tileStates: {2: const CutawayTileState(itemCount: 15)},
      );
      expect(find.text('15 Geräte'), findsNothing);
      expect(find.text('FAHRTRICHTUNG ▲'), findsNothing);
      expect(find.text('G1'), findsOneWidget);
    });
  });
}
