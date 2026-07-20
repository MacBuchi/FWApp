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
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // Design-Auswahl (seit v1.4.1: System/Hell/Dunkel statt Bool-Schalter).
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

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

  // Regressionstest zu Issue #27: Ab Android 11 sieht eine App nur die
  // Pakete, die sie im <queries>-Block deklariert. Fehlt dort der
  // VIEW/https-Eintrag, meldet canLaunchUrl still `false` — der Browser-
  // Fallback des Update-Dialogs ("Im Browser laden") läuft dann ins Leere,
  // ohne dass irgendwo ein Fehler auftaucht. Der Test prüft genau diese
  // Sichtbarkeit; auf Android ≤ 10 greift die Beschränkung nicht, dort ist
  // er nur eine Bestätigung, dass überhaupt ein Browser da ist.
  testWidgets('Ein Browser ist für https-Links sichtbar (Package Visibility)',
      (tester) async {
    if (!Platform.isAndroid) return;
    expect(
      await canLaunchUrl(Uri.parse('https://github.com/MacBuchi/FWApp')),
      isTrue,
      reason: 'Kein Handler für https sichtbar — fehlt der VIEW/https-Intent '
          'im <queries>-Block von AndroidManifest.xml?',
    );
  });
}
