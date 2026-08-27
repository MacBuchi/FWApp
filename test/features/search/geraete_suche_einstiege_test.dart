/// geraete_suche_einstiege_test.dart – Wie man zur Gerätesuche kommt
/// (Issue #180).
///
/// Eine Suche, die niemand findet, ist keine. Beide Einstiege hängen an
/// Stellen, die jemand beim nächsten Umbau guten Gewissens verschieben
/// würde — das Dashboard wird umsortiert, die Lupe in der Fahrzeugliste
/// zeigte bis #180 auf den Katalog. Deshalb stehen sie hier fest.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/home/presentation/screens/home_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_list_screen.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget schirm(Widget home) => buildTestApp(db: db, home: home);

  void breitesGeraet(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('die Startseite trägt eine Kachel zur Gerätesuche',
      (tester) async {
    breitesGeraet(tester);
    await tester.pumpWidget(schirm(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Gerätesuche'), findsOneWidget);
    expect(find.textContaining('Wo liegt was?'), findsOneWidget);

    await endTestApp(tester);
  });

  testWidgets('die Kachel steht vor den Lernkarten, nicht darunter',
      (tester) async {
    // „Wo liegt das?" fragt man unter Zeitdruck. Rutscht der Einstieg unter
    // das Wochenziel, ist er im Einsatz nicht mehr da.
    breitesGeraet(tester);
    await tester.pumpWidget(schirm(const HomeScreen()));
    await tester.pumpAndSettle();

    final sucheY = tester.getTopLeft(find.text('Gerätesuche')).dy;
    final wochenzielY = tester.getTopLeft(find.textContaining('Woche')).dy;
    expect(sucheY, lessThan(wochenzielY));

    await endTestApp(tester);
  });

  testWidgets('die Lupe im Fuhrpark führt in die Gerätesuche, nicht in den '
      'Katalog', (tester) async {
    // Bis Issue #180 landete man hier im Gerätekatalog — also bei der Frage,
    // welche Geräte es GIBT statt wo eines LIEGT.
    await tester.pumpWidget(schirm(const VehicleListScreen()));
    await tester.pumpAndSettle();

    final lupe = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.search), matching: find.byType(IconButton)));
    expect(lupe.tooltip, 'Gerät im Fuhrpark suchen');

    await endTestApp(tester);
  });
}
