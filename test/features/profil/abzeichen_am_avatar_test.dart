/// abzeichen_am_avatar_test.dart – Das Leistungsabzeichen am Kopf und in
/// Worten (Issue #135).
///
/// Der Kopf selbst wird gemalt und ist damit schwer zu befragen; die Marke
/// ist bewusst ein Widget darüber (der Painter bleibt eine 1:1-Übersetzung
/// des Entwurfs). Genau deshalb lässt sie sich hier direkt prüfen: welches
/// Metall, welche Größe, wo sie sitzt — und ob ein Screenreader sie findet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';
import 'package:fwapp/features/profil/domain/leistungsabzeichen.dart';
import 'package:fwapp/features/profil/presentation/widgets/abzeichen_zeile.dart';
import 'package:fwapp/features/profil/presentation/widgets/fw_avatar.dart';

const _kopf = AvatarKonfiguration();

Future<void> _zeige(WidgetTester tester, Widget kind) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: kind))));

Icon _marke(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.military_tech));

void main() {
  group('die Marke am Kopf', () {
    testWidgets('ohne Stufe hängt nichts am Avatar', (tester) async {
      // Wichtig, weil der Kopf auch dort steht, wo es keine Stufe gibt: im
      // Vorlagen-Raster und in der Nutzerverwaltung.
      await _zeige(tester, const FwAvatar(konfiguration: _kopf));
      expect(find.byIcon(Icons.military_tech), findsNothing);
    });

    testWidgets('trägt das Metall der erreichten Stufe', (tester) async {
      for (final stufe in Leistungsabzeichen.values) {
        await _zeige(tester, FwAvatar(konfiguration: _kopf, abzeichen: stufe));
        expect(_marke(tester).color, kAbzeichenFarben[stufe], reason: '$stufe');
      }
    });

    testWidgets('wächst mit dem Kopf', (tester) async {
      // Im Profil ist der Kopf 132 groß, in der Einstellungs-Kachel 40. Eine
      // feste Markengröße wäre an einem der beiden Orte falsch.
      await _zeige(
        tester,
        const FwAvatar(
          konfiguration: _kopf,
          groesse: 40,
          abzeichen: Leistungsabzeichen.bronze,
        ),
      );
      final klein = _marke(tester).size!;
      await _zeige(
        tester,
        const FwAvatar(
          konfiguration: _kopf,
          groesse: 132,
          abzeichen: Leistungsabzeichen.bronze,
        ),
      );
      expect(_marke(tester).size!, greaterThan(klein));
    });

    testWidgets('sitzt links unten, wo das Rollen-Abzeichen nicht steht',
        (tester) async {
      // In der Nutzerverwaltung klebt rechts unten am selben Kopf das
      // Rollen-Abzeichen (`_KontoAvatar`). Wandert die Marke dorthin, liegen
      // zwei Zeichen übereinander und beide sind unlesbar.
      await _zeige(
        tester,
        const FwAvatar(
          konfiguration: _kopf,
          groesse: 100,
          abzeichen: Leistungsabzeichen.gold,
        ),
      );
      final kopf = tester.getRect(find.byType(FwAvatar));
      final marke = tester.getCenter(find.byIcon(Icons.military_tech));
      expect(marke.dx, lessThan(kopf.center.dx), reason: 'nicht links');
      expect(marke.dy, greaterThan(kopf.center.dy), reason: 'nicht unten');
    });

    testWidgets('ist auch dann vorlesbar, wenn der Kopf stumm bleibt',
        (tester) async {
      // Der Regelfall: In der Einstellungs-Kachel steht der Kopf ohne
      // Beschriftung (er wiederholte sonst den Namen). Die Stufe steht dort
      // aber in KEINEM Text daneben — ohne eigene Beschriftung wäre sie für
      // einen Screenreader schlicht nicht vorhanden.
      await _zeige(
        tester,
        const FwAvatar(
          konfiguration: _kopf,
          abzeichen: Leistungsabzeichen.silber,
        ),
      );
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Leistungsabzeichen in Silber'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('die Zeile daneben', () {
    testWidgets('nennt Stufe und Entfernung im Klartext', (tester) async {
      await _zeige(tester, const AbzeichenZeile(level: 4));
      expect(find.text('Leistungsabzeichen in Bronze'), findsOneWidget);
      expect(find.text('Noch 4 Level bis Silber.'), findsOneWidget);
    });

    testWidgets('sagt vor der ersten Stufe, dass noch keine da ist',
        (tester) async {
      await _zeige(tester, const AbzeichenZeile(level: 1));
      expect(find.text('Noch kein Leistungsabzeichen'), findsOneWidget);
      // Und das Symbol trägt dann keine Metallfarbe — sonst stünde ein
      // bronzenes Abzeichen neben „noch keines".
      expect(
        _marke(tester).color,
        isNot(kAbzeichenFarben[Leistungsabzeichen.bronze]),
      );
    });

    testWidgets('bleibt in der schmalen Level-Karte kurz', (tester) async {
      // Die Karte ist eine halbe Bildschirmbreite breit; der lange Satz
      // passt dort nicht.
      await _zeige(tester, const AbzeichenZeile(level: 9, kompakt: true));
      expect(find.text('Silber'), findsOneWidget);
      expect(find.text('Leistungsabzeichen in Silber'), findsNothing);
      expect(find.text('Noch 6 Level bis Gold.'), findsOneWidget);
    });
  });
}
