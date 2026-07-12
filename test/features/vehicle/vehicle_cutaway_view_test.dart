/// vehicle_cutaway_view_test.dart – layout logic and interaction of the
/// cutaway view (Schnittdarstellung).
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/compartment/domain/entities/compartment.dart';
import 'package:fwapp/features/vehicle/presentation/widgets/vehicle_cutaway_view.dart';

Compartment _c(int id, String label,
        {int? row, int? col, int span = 1, int position = 0}) =>
    Compartment(
      id: id,
      vehicleId: 1,
      label: label,
      position: position,
      gridRow: row,
      gridCol: col,
      gridColSpan: span,
      updatedAt: DateTime(2026),
    );

void main() {
  group('layoutRows', () {
    test('places compartments by gridRow/gridCol, sorted', () {
      final rows = VehicleCutawayView.layoutRows([
        _c(1, 'G2', row: 1, col: 1),
        _c(2, 'Dach', row: 0, col: 0, span: 3),
        _c(3, 'G1', row: 1, col: 0),
      ]);
      expect(rows, hasLength(2));
      expect(rows[0].single.label, 'Dach');
      expect(rows[1].map((c) => c.label), ['G1', 'G2']);
    });

    test('auto-flows unplaced compartments by position into rows of 3', () {
      final rows = VehicleCutawayView.layoutRows([
        _c(1, 'G4', position: 3),
        _c(2, 'G1', position: 0),
        _c(3, 'G2', position: 1),
        _c(4, 'G3', position: 2),
      ]);
      expect(rows, hasLength(2));
      expect(rows[0].map((c) => c.label), ['G1', 'G2', 'G3']);
      expect(rows[1].map((c) => c.label), ['G4']);
    });

    test('mixes placed rows first, then unplaced trailing rows', () {
      final rows = VehicleCutawayView.layoutRows([
        _c(1, 'Heck', position: 5),
        _c(2, 'Dach', row: 0, col: 0),
      ]);
      expect(rows[0].single.label, 'Dach');
      expect(rows[1].single.label, 'Heck');
    });
  });

  testWidgets('renders tiles, counts, due badge and handles taps',
      (tester) async {
    Compartment? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VehicleCutawayView(
          compartments: [
            _c(1, 'G1', row: 0, col: 0),
            _c(2, 'G2', row: 0, col: 1),
          ],
          tileStates: const {
            1: CutawayTileState(itemCount: 12, dueBadgeCount: 2),
          },
          onTapCompartment: (c) => tapped = c,
        ),
      ),
    ));

    expect(find.text('G1'), findsOneWidget);
    expect(find.text('G2'), findsOneWidget);
    expect(find.text('12 Geräte'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // due badge

    await tester.tap(find.text('G2'));
    expect(tapped?.id, 2);
  });
}
