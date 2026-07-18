/// app_smoke_test.dart – Geräte-Smoke-Test (M7-Feldtest als "Test-API").
///
/// Läuft auf einem echten Gerät/Emulator:
///   `flutter test integration_test -d <geräte-id>`
///
/// Steuert die echte App programmatisch (Widgets finden, tippen, prüfen) —
/// ersetzt die fehleranfällige Screenshot-und-Koordinaten-Steuerung per adb.
/// Der Test ist zustands-tolerant: Er funktioniert im Lokalmodus wie auch
/// mit aktiviertem Sync (angemeldet oder nicht) und ändert nichts am
/// Datenbestand — reine Navigation + Sichtprüfungen.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/main.dart' as app;
import 'package:integration_test/integration_test.dart';

Future<void> settle(WidgetTester tester) async =>
    tester.pumpAndSettle(const Duration(milliseconds: 250));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App startet, Navigation und Sync-Einstellungen erreichbar',
      (tester) async {
    await app.main();
    await settle(tester);

    // Start-Dashboard mit Bottom-Navigation.
    expect(find.text('Start'), findsWidgets);
    expect(find.text('Mehr'), findsWidgets);

    // Mehr → Einstellungen.
    await tester.tap(find.text('Mehr').last);
    await settle(tester);
    expect(find.text('Einstellungen'), findsWidgets);
    await tester.tap(find.text('Einstellungen').first);
    await settle(tester);

    // Sync-Sektion vorhanden.
    expect(find.text('Supabase-Sync aktivieren'), findsOneWidget);
    expect(find.text('Dunkles Design'), findsOneWidget);

    // Wenn Sync aktiv und nicht angemeldet: Login-Dialog öffnen und den
    // Nutzername-Login (M7 Etappe 3) sichtprüfen, dann abbrechen.
    final loginTile = find.text('Mit Abteilung verbinden');
    if (loginTile.evaluate().isNotEmpty) {
      await tester.tap(loginTile);
      await settle(tester);
      expect(find.text('Nutzername'), findsOneWidget,
          reason: 'Login fragt seit v1.3.0 nach dem Nutzernamen');
      expect(find.textContaining('Keine Registrierung nötig'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await settle(tester);
    }
  });
}
