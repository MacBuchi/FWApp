/// fach_foto_test.dart – Foto je Geräteraum (Issue #181).
///
/// Zwei Orte, zwei Aufgaben: Im Fach-Verwalter ist das Bild der **Knopf**,
/// mit dem man es aufnimmt oder ersetzt. In der Fahrzeugansicht ist es die
/// **Auskunft** — und steht deshalb über der Geräteliste des Fachs, nicht
/// daneben: Wer nachlädt, vergleicht erst das Bild und liest dann die Liste.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/vehicle/presentation/screens/compartment_manager_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_detail_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;
  late int fahrzeug;

  setUp(() async {
    db = createTestDatabase();
    fahrzeug = await db.vehicleDao.insertVehicle(
        VehiclesCompanion.insert(name: 'HLF 20', type: 'HLF 20'));
  });
  tearDown(() => db.close());

  Future<int> fach(String label, {String? foto}) =>
      db.compartmentDao.insertCompartment(CompartmentsCompanion.insert(
        vehicleId: fahrzeug,
        label: label,
        seite: const Value('fahrerseite'),
        imagePath: Value(foto),
      ));

  Future<void> pumpe(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestApp(db: db, home: screen));
    await tester.pumpAndSettle();
  }

  group('Fach-Verwalter', () {
    testWidgets('ein Fach ohne Foto lädt sichtbar dazu ein', (tester) async {
      await fach('G1');
      await pumpe(tester, CompartmentManagerScreen(vehicleId: fahrzeug));

      // Das Kamerasymbol IST der Knopf — kein Menü, kein Umweg.
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);

      await endTestApp(tester);
    });

    testWidgets('ein Fach mit Foto zeigt es statt des Symbols',
        (tester) async {
      await fach('G1', foto: 'assets/equipment_library/images/beispiel.png');
      await pumpe(tester, CompartmentManagerScreen(vehicleId: fahrzeug));

      expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);

      await endTestApp(tester);
    });

    testWidgets('der Griff zum Umsortieren bleibt daneben stehen',
        (tester) async {
      // Das Foto darf die Bedienung dieser Liste nicht verdrängen — sie ist
      // eine Reihenfolge-Liste, und ohne Griff ließe sie sich nicht mehr
      // sortieren.
      await fach('G1', foto: 'assets/equipment_library/images/beispiel.png');
      await pumpe(tester, CompartmentManagerScreen(vehicleId: fahrzeug));

      expect(find.byIcon(Icons.drag_handle), findsOneWidget);

      await endTestApp(tester);
    });
  });

  group('Fahrzeugansicht', () {
    /// Der Fachname steht auf diesem Schirm zweimal (Schnittdarstellung und
    /// Liste) — aufgeklappt wird über die Kachel der Liste.
    Future<void> klappeAuf(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(ExpansionTile, label));
      await tester.pumpAndSettle();
    }

    testWidgets('das Fach-Foto steht im aufgeklappten Fach', (tester) async {
      final id = await fach('G1',
          foto: 'assets/equipment_library/images/beispiel.png');
      await pumpe(tester, VehicleDetailScreen(vehicleId: fahrzeug));

      // Zugeklappt gehört es nicht auf den Schirm — sonst wäre die
      // Fachliste eine Bildergalerie.
      expect(find.byKey(ValueKey('fachfoto-$id')), findsNothing);

      await klappeAuf(tester, 'G1');
      expect(find.byKey(ValueKey('fachfoto-$id')), findsOneWidget);

      await endTestApp(tester);
    });

    testWidgets('ein Tipp aufs Foto öffnet die Großansicht', (tester) async {
      // Auf einem Handy ist ein 160 Pixel hoher Streifen zu wenig, um ein
      // Fach wiederzuerkennen.
      final id = await fach('G1',
          foto: 'assets/equipment_library/images/beispiel.png');
      await pumpe(tester, VehicleDetailScreen(vehicleId: fahrzeug));
      await klappeAuf(tester, 'G1');

      expect(find.byType(InteractiveViewer), findsNothing);
      await tester.tap(find.byKey(ValueKey('fachfoto-$id')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await endTestApp(tester);
    });

    testWidgets('ein Fach ohne Foto bekommt keinen leeren Platzhalter',
        (tester) async {
      // Ein grauer Kasten „kein Bild" an jedem Fach wäre in einer Liste mit
      // dreißig Fächern nur Rauschen.
      final id = await fach('G1');
      await pumpe(tester, VehicleDetailScreen(vehicleId: fahrzeug));
      await klappeAuf(tester, 'G1');

      expect(find.byKey(ValueKey('fachfoto-$id')), findsNothing);
      expect(tester.takeException(), isNull);

      await endTestApp(tester);
    });
  });
}
