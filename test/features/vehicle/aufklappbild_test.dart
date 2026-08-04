/// aufklappbild_test.dart – Der Beladeplan sieht aus wie das Fahrzeug
/// (Issue #126).
///
/// Marcus' Meldung aus dem Feld: „genau die Fahrzeuggeometrie sollte
/// abgebildet sein". Geprüft wird deshalb nicht, dass irgendwelche Kacheln
/// erscheinen, sondern **wo** sie stehen: Dach oben, dann einmal um das
/// Fahrzeug herum — und dass ein Fahrzeug ohne Seitenangaben unverändert
/// aussieht wie vorher.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

Compartment _fach(int id, String label, {String? seite, int? row, int? col}) =>
    Compartment(
      id: id,
      vehicleId: 1,
      label: label,
      position: id,
      gridRow: row,
      gridCol: col,
      gridColSpan: 1,
      seite: seite,
      updatedAt: DateTime(2026),
    );

Future<void> _zeige(WidgetTester tester, List<Compartment> faecher) async {
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: VehicleCutawayView(compartments: faecher),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('die Aufteilung', () {
    test('ohne jede Seitenangabe bleibt alles wie vorher', () {
      // Rückwärtskompatibilität: Ein Fahrzeug, das noch niemand zugeordnet
      // hat, soll sich nicht plötzlich anders anfühlen — genau EIN Bereich,
      // und der ohne Überschrift.
      final bereiche = VehicleCutawayView.layoutBereiche([
        _fach(1, 'G1'),
        _fach(2, 'G2'),
      ]);
      expect(bereiche, hasLength(1));
      expect(bereiche.single.seite, isNull);
      expect(bereiche.single.reihen.expand((r) => r), hasLength(2));
    });

    test('mit Seiten entstehen Bereiche in der Reihenfolge ums Fahrzeug', () {
      final bereiche = VehicleCutawayView.layoutBereiche([
        _fach(1, 'G2', seite: 'beifahrerseite'),
        _fach(2, 'GR', seite: 'heck'),
        _fach(3, 'G1', seite: 'fahrerseite'),
        _fach(4, 'Dachkasten', seite: 'dach'),
      ]);
      expect(bereiche.map((b) => b.seite),
          ['dach', 'fahrerseite', 'heck', 'beifahrerseite']);
    });

    test('leere Bereiche entstehen gar nicht', () {
      // Ein Fahrzeug ohne Frontfach zeigt keine Überschrift „Front".
      final bereiche = VehicleCutawayView.layoutBereiche([
        _fach(1, 'G1', seite: 'fahrerseite'),
      ]);
      expect(bereiche.map((b) => b.seite), ['fahrerseite']);
    });

    test('nicht zugeordnete Fächer kommen ans Ende, nicht dazwischen', () {
      final bereiche = VehicleCutawayView.layoutBereiche([
        _fach(1, 'Ablage'),
        _fach(2, 'G1', seite: 'fahrerseite'),
      ]);
      expect(bereiche.map((b) => b.seite), ['fahrerseite', null]);
      expect(bereiche.last.reihen.expand((r) => r).single.label, 'Ablage');
    });

    test('ein unbekannter Wert geht NICHT verloren', () {
      // Server neuer als die App: Ein Fach, das man nicht mehr sieht, wäre
      // schlimmer als eines unter der falschen Überschrift.
      final bereiche = VehicleCutawayView.layoutBereiche([
        _fach(1, 'G1', seite: 'fahrerseite'),
        _fach(2, 'Rätsel', seite: 'anhaengerkupplung'),
      ]);
      final alle =
          bereiche.expand((b) => b.reihen).expand((r) => r).map((c) => c.label);
      expect(alle, containsAll(['G1', 'Rätsel']));
      expect(bereiche.last.seite, isNull);
    });

    test('innerhalb eines Bereichs gilt weiter das Raster', () {
      final bereiche = VehicleCutawayView.layoutBereiche([
        _fach(1, 'G3', seite: 'fahrerseite', row: 0, col: 1),
        _fach(2, 'G1', seite: 'fahrerseite', row: 0, col: 0),
        _fach(3, 'G5', seite: 'fahrerseite', row: 1, col: 0),
      ]);
      final reihen = bereiche.single.reihen;
      expect(reihen, hasLength(2));
      expect(reihen.first.map((c) => c.label), ['G1', 'G3']);
      expect(reihen.last.map((c) => c.label), ['G5']);
    });
  });

  group('die Ansicht', () {
    testWidgets('ohne Seitenangaben steht keine Überschrift da',
        (tester) async {
      await _zeige(tester, [_fach(1, 'G1'), _fach(2, 'G2')]);
      expect(find.text('OHNE SEITE'), findsNothing);
      expect(find.text('FAHRERSEITE'), findsNothing);
      expect(find.text('G1'), findsOneWidget);
    });

    testWidgets('mit Seiten steht das Dach oben und die Beifahrerseite unten',
        (tester) async {
      await _zeige(tester, [
        _fach(1, 'G2', seite: 'beifahrerseite'),
        _fach(2, 'GR', seite: 'heck'),
        _fach(3, 'G1', seite: 'fahrerseite'),
        _fach(4, 'Dachkasten', seite: 'dach'),
      ]);

      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(y('DACH'), lessThan(y('FAHRERSEITE')));
      expect(y('FAHRERSEITE'), lessThan(y('HECK')));
      expect(y('HECK'), lessThan(y('BEIFAHRERSEITE')));
      // Und jedes Fach steht unter seiner Überschrift.
      expect(y('Dachkasten'), greaterThan(y('DACH')));
      expect(y('Dachkasten'), lessThan(y('FAHRERSEITE')));
      expect(y('G2'), greaterThan(y('BEIFAHRERSEITE')));
    });

    testWidgets('ein nicht zugeordnetes Fach bleibt sichtbar', (tester) async {
      await _zeige(tester, [
        _fach(1, 'G1', seite: 'fahrerseite'),
        _fach(2, 'Ablage'),
      ]);
      expect(find.text('OHNE SEITE'), findsOneWidget);
      expect(find.text('Ablage'), findsOneWidget);
    });
  });
}
