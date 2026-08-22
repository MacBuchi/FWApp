/// seitenfarben_test.dart – Dieselbe Farbe in JEDER Ansicht (Issue #167).
///
/// Die Seitenfarben (#141) hingen an der Draufsicht. Das Aufklappbild — und
/// damit Drag & Drop, Inventur, Einsatzplanung und die Fächerverwaltung —
/// zog seine Kacheln aus dem Theme: derselbe Geräteraum war im Fahrzeugmenü
/// blau und im Lernmodus grau. Gelernt wird aber an der Farbe.
///
/// Geprüft wird deshalb nicht, DASS es bunt ist, sondern dass beide Ansichten
/// für dasselbe Fach denselben Wert liefern — und dass Richtig/Falsch die
/// Seitenfarbe weiterhin sticht.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/compartment/presentation/seiten_farben.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_top_view.dart';

Compartment _fach(int id, String label, {String? seite, String? laengsposition}) =>
    Compartment(
      id: id,
      vehicleId: 1,
      label: label,
      position: id,
      gridColSpan: 1,
      seite: seite,
      laengsposition: laengsposition,
      updatedAt: DateTime(2026),
    );

final _faecher = [
  _fach(1, 'G1', seite: 'fahrerseite', laengsposition: 'vorne'),
  _fach(2, 'G2', seite: 'beifahrerseite', laengsposition: 'vorne'),
  _fach(3, 'Heck', seite: 'heck'),
  _fach(4, 'Ohne', seite: null),
];

/// Die Füllfarbe der Kachel, die [label] trägt: In beiden Ansichten sitzt der
/// Text in einem [Material], dessen `color` die Kachelfläche ist.
Color _kachelFarbe(WidgetTester tester, String label) => tester
    .widget<Material>(
      find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
    )
    .color!;

Future<void> _zeige(WidgetTester tester, Widget ansicht) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ansicht)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('fachKachelFarben', () {
    const scheme = ColorScheme.light();

    ({Color fill, Color border, Color fg}) farben(
      String? seite, {
      CutawayTileStatus status = CutawayTileStatus.normal,
      Brightness brightness = Brightness.light,
    }) =>
        fachKachelFarben(
          seite: seite,
          status: status,
          scheme: scheme,
          brightness: brightness,
        );

    test('nimmt die feste Farbe der Seite', () {
      expect(farben('fahrerseite').fill,
          kSeitenFarben['fahrerseite']!.flaeche(Brightness.light));
      expect(farben('beifahrerseite').fill,
          kSeitenFarben['beifahrerseite']!.flaeche(Brightness.light));
    });

    test('fällt ohne Seite auf das Theme zurück', () {
      // Ein Fahrzeug, das noch niemand verortet hat, soll sich nicht
      // plötzlich anders anfühlen.
      expect(farben(null).fill, scheme.surfaceContainerHighest);
      expect(farben('unbekannt').fill, scheme.surfaceContainerHighest);
    });

    test('Richtig und Falsch stechen die Seitenfarbe', () {
      // Im Lernmodus zählt die Rückmeldung mehr als der Ort — sonst müsste
      // man Grün von Grün unterscheiden.
      expect(farben('fahrerseite', status: CutawayTileStatus.correct).fill,
          Colors.green.shade100);
      expect(farben('heck', status: CutawayTileStatus.wrong).fill,
          Colors.red.shade100);
    });

    test('im Dunkeln eine Lasur statt Pastell', () {
      expect(farben('fahrerseite', brightness: Brightness.dark).fill,
          isNot(kSeitenFarben['fahrerseite']!.flaeche(Brightness.light)));
    });
  });

  group('beide Ansichten', () {
    testWidgets('färben dasselbe Fach gleich', (tester) async {
      await _zeige(tester, VehicleTopView(compartments: _faecher));
      final ausDraufsicht = {
        for (final l in ['G1', 'G2', 'Heck', 'Ohne']) l: _kachelFarbe(tester, l),
      };

      await _zeige(tester, VehicleCutawayView(compartments: _faecher));
      final ausAufklappbild = {
        for (final l in ['G1', 'G2', 'Heck', 'Ohne']) l: _kachelFarbe(tester, l),
      };

      expect(ausAufklappbild, ausDraufsicht);
    });

    testWidgets('Aufklappbild trägt die Seitenfarbe, nicht das Theme',
        (tester) async {
      // Die Gegenprobe zum Fehler: Vorher lieferte diese Ansicht für JEDES
      // Fach dieselbe Theme-Fläche.
      await _zeige(tester, VehicleCutawayView(compartments: _faecher));

      expect(_kachelFarbe(tester, 'G1'),
          kSeitenFarben['fahrerseite']!.flaeche(Brightness.light));
      expect(_kachelFarbe(tester, 'G2'),
          kSeitenFarben['beifahrerseite']!.flaeche(Brightness.light));
      expect(_kachelFarbe(tester, 'G1'), isNot(_kachelFarbe(tester, 'G2')));
    });

    testWidgets('Richtig/Falsch bleibt auch im Aufklappbild sichtbar',
        (tester) async {
      await _zeige(
        tester,
        VehicleCutawayView(
          compartments: _faecher,
          tileStates: const {
            1: CutawayTileState(status: CutawayTileStatus.correct),
            2: CutawayTileState(status: CutawayTileStatus.wrong),
          },
        ),
      );

      expect(_kachelFarbe(tester, 'G1'), Colors.green.shade100);
      expect(_kachelFarbe(tester, 'G2'), Colors.red.shade100);
    });

    for (final (name, ansicht) in [
      ('Aufklappbild', VehicleCutawayView.new),
      ('Draufsicht', VehicleTopView.new),
    ]) {
      testWidgets('$name zeigt Richtig/Falsch auch ohne Farbe',
          (tester) async {
        // Das Heck ist grün und „richtig" ist grün; die Beifahrerseite ist
        // rostrot und „falsch" ist rot. Auf der Fläche allein ist das kaum
        // zu unterscheiden — das Zeichen muss die Antwort tragen.
        await _zeige(
          tester,
          ansicht(
            compartments: _faecher,
            tileStates: const {
              3: CutawayTileState(status: CutawayTileStatus.correct),
              2: CutawayTileState(status: CutawayTileStatus.wrong),
            },
          ),
        );

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.byIcon(Icons.cancel), findsOneWidget);
      });

      testWidgets('$name bleibt ohne Antwort zeichenlos', (tester) async {
        await _zeige(tester, ansicht(compartments: _faecher));

        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(find.byIcon(Icons.cancel), findsNothing);
      });
    }
  });
}
