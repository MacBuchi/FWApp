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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> settle(WidgetTester tester) async =>
    tester.pumpAndSettle(const Duration(milliseconds: 250));

/// Pumpt, bis [finder] fündig wird.
///
/// `pumpAndSettle` reicht hier nicht: Die Einstellungen hängen an
/// asynchronen Providern (SharedPreferences, Drift). Solange die auf I/O
/// warten, steht kein Frame an — `pumpAndSettle` kehrt also sofort zurück,
/// während noch „Lade…“ auf dem Schirm steht. Auf dem schnellen Emulator
/// gewinnt das Rennen meist der Provider, auf einem echten Pixel XL nicht.
/// Alle gerade gebauten Text-Widgets — die einzige Sicht auf den Bildschirm,
/// die man bei einem Geräte-Lauf hat.
List<String> visibleTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .toList();

/// Trifft [finder] gerade etwas?
///
/// `evaluate()` ist auf `.first`/`.last`-Findern nicht harmlos: Solange nichts
/// passt, werfen sie `Bad state: No element` statt eine leere Liste zu
/// liefern — beim Warten auf noch nicht geladene Inhalte also genau dann,
/// wenn man es am wenigsten brauchen kann.
bool matches(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  for (var waited = Duration.zero;
      waited < timeout;
      waited += const Duration(milliseconds: 100)) {
    if (matches(finder)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Ohne die Liste des tatsächlich Sichtbaren ist ein Fehlschlag auf einem
  // Gerät kaum zu deuten — man sieht den Bildschirm ja nicht.
  fail('Nach ${timeout.inSeconds}s nicht gefunden: '
      '${finder.describeMatch(Plurality.one)}'
      '\nSichtbar: ${visibleTexts(tester)}');
}

/// Wartet auf [finder] und scrollt das Ziel in den sichtbaren Bereich.
///
/// Nötig, weil das Testgerät nicht zwingend hochkant liegt: Der Pixel XL im
/// Testrig meldet 683 × 411 dp. In diesem flachen Fenster rutschen
/// Listeneinträge unter die Navigationsleiste — `tester.tap` trifft dann die
/// Leiste und der Test wandert wortlos in einen anderen Tab, statt dem Link
/// zu folgen.
Future<void> ensureVisible(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App startet, Navigation und Sync-Einstellungen erreichbar',
      (tester) async {
    await app.main();
    await settle(tester);

    // Start-Dashboard mit Bottom-Navigation.
    await waitFor(tester, find.text('Start'));
    expect(find.text('Mehr'), findsWidgets);

    // Mehr → Einstellungen.
    await tester.tap(find.text('Mehr').last);
    await settle(tester);
    final settingsTile = find.widgetWithText(ListTile, 'Einstellungen').first;
    await ensureVisible(tester, settingsTile);
    await tester.tap(settingsTile);
    await settle(tester);

    // Design-Auswahl (seit v1.4.1: System/Hell/Dunkel statt Bool-Schalter).
    // Steht oben im Screen, wird also vor dem Scrollen geprüft.
    await waitFor(tester, find.text('Design'));
    expect(find.text('System'), findsOneWidget);

    // Sync-Sektion vorhanden.
    await ensureVisible(tester, find.text('Supabase-Sync aktivieren'));

    // Wenn Sync aktiv und nicht angemeldet: Login-Dialog öffnen und den
    // Nutzername-Login (M7 Etappe 3) sichtprüfen, dann abbrechen.
    final loginTile = find.text('Mit Abteilung verbinden');
    if (matches(loginTile)) {
      await ensureVisible(tester, loginTile);
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
