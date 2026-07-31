/// palette_picker_test.dart – Farbthema-Auswahl in den Einstellungen
/// (Issue #58): Wechsel per Tippen, eigenes Thema über die Regler und die
/// Sperre für Nicht-Admins.
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/theme/app_palette.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:fwapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:fwapp/features/settings/presentation/widgets/palette_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';
import '../../helpers/widget_harness.dart';

/// PalettePicker braucht ein Material darüber (ListTile) und einen
/// Scaffold-Kontext für das Bottom-Sheet — im Screen ist beides da.
const _pickerHost = Scaffold(body: SingleChildScrollView(child: PalettePicker()));

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  testWidgets('zeigt alle Paletten plus das eigene Thema', (tester) async {
    await tester.pumpWidget(buildTestApp(db: db, home: _pickerHost));
    await tester.pumpAndSettle();

    for (final p in kAppPalettes) {
      expect(find.text(p.name), findsOneWidget);
    }
    expect(find.text('Eigenes'), findsOneWidget);
  });

  testWidgets('Tippen wechselt die Palette und merkt sie sich',
      (tester) async {
    await tester.pumpWidget(buildTestApp(db: db, home: _pickerHost));
    await tester.pumpAndSettle();

    final target = kAppPalettes[1];
    await tester.tap(find.text(target.name));
    await tester.pumpAndSettle();

    final container = containerOf(tester);
    expect(container.read(appPaletteProvider).value?.id, target.id);
    // Die Beschreibung unter „Farbthema" folgt der Auswahl.
    expect(find.text(target.description), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_palette'), target.id);
  });

  testWidgets('eigenes Farbthema: Regler übernehmen setzt custom',
      (tester) async {
    await tester.pumpWidget(buildTestApp(db: db, home: _pickerHost));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eigenes'));
    await tester.pumpAndSettle();
    expect(find.text('Eigenes Farbthema'), findsOneWidget);

    // Farbton verschieben, damit der übernommene Wert nicht zufällig der
    // Rückfallfarbe entspricht und der Test grün wäre, ohne etwas zu zeigen.
    final hue = find.byType(Slider).first;
    await tester.drag(hue, const Offset(120, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    final palette = containerOf(tester).read(appPaletteProvider).value;
    expect(palette?.id, kCustomPaletteId);
    expect(palette?.seed, isNot(kCustomPaletteFallbackSeed));
  });

  testWidgets('Abbrechen im Farbwähler ändert nichts', (tester) async {
    await tester.pumpWidget(buildTestApp(db: db, home: _pickerHost));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eigenes'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).first, const Offset(120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(appPaletteProvider).value?.id,
        kDefaultPaletteId);
  });

  testWidgets('ohne Admin-Rechte ist das Farbthema gesperrt', (tester) async {
    await tester.pumpWidget(buildTestApp(
      db: db,
      home: const SettingsScreen(),
      overrides: [isAdminProvider.overrideWithValue(false)],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Legt die Verwaltung der Wehr fest.'), findsOneWidget);
    expect(find.byType(PalettePicker), findsNothing);
  });
}
