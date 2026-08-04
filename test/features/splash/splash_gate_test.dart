/// splash_gate_test.dart – Die Startanimation liegt ÜBER der App
/// (Issue #129).
///
/// Die Aussagen, die im Feld zählen und die man nur hier prüfen kann: die App
/// baut darunter schon auf, die Kurzform ist wirklich kurz, Bewegungs-
/// reduzierung überstimmt sie, und man kommt jederzeit daran vorbei.
///
/// ⚠️ **Kein `pumpAndSettle` in diesem Test.** Es dreht die Uhr bis zum Ende
/// JEDER laufenden Animation — danach ist die Bühne immer weg, egal wie lang
/// sie eingestellt war. Zwei Gegenproben (Kurzform spielt heimlich die volle
/// Länge; Bewegungsreduzierung wird ignoriert) blieben damit grün. Gepumpt
/// wird deshalb ausschließlich in gezählten Schritten.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/splash/presentation/splash_gate.dart';
import 'package:fwapp/features/splash/presentation/widgets/fw_splash.dart';

final _splash = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is SplashPainter);

Widget _host({required bool voll, bool ruhig = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: ruhig),
      child: MaterialApp(
        home: SplashGate(
          // Eigener Schlüssel je Fassung: Ohne ihn übernimmt Flutter beim
          // zweiten `pumpWidget` denselben State — die Animation startete
          // dann gar nicht neu.
          key: ValueKey('$voll-$ruhig'),
          voll: voll,
          child: const Scaffold(body: Text('Die App')),
        ),
      ),
    );

/// Ausblenddauer plus etwas Luft, in gezählten Schritten.
const _ausblenden = 400;

/// Lässt die Uhr um genau [ms] laufen — in kleinen Schritten, ohne die
/// restliche Animation vorzuspulen.
///
/// ⚠️ Die Schrittweite ist nicht Kosmetik: Wenn der Ablauf endet, startet
/// sein `whenComplete` erst das Ausblenden. Ein einziger großer `pump`
/// springt über diesen Übergang hinweg, und die Bühne bliebe stehen,
/// obwohl sie längst weg sein müsste.
Future<void> _warte(WidgetTester tester, int ms) async {
  const schritt = 50;
  for (var vergangen = 0; vergangen < ms; vergangen += schritt) {
    await tester.pump(const Duration(milliseconds: schritt));
  }
}

void main() {
  testWidgets('die App baut UNTER der Animation — sie wird nicht aufgehalten',
      (tester) async {
    await tester.pumpWidget(_host(voll: true));
    await tester.pump();

    // Beides gleichzeitig im Baum: Wäre die Animation ein eigener
    // Bildschirm, den die App erst ablösen darf, hätte man 4,3 Sekunden
    // Startzeit dazugekauft.
    expect(_splash, findsOneWidget);
    expect(find.text('Die App'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('die volle Fassung läuft ihre 4,3 Sekunden und geht dann',
      (tester) async {
    await tester.pumpWidget(_host(voll: true));
    await _warte(tester, kSplashVollMs - 300);
    expect(_splash, findsOneWidget, reason: 'kurz vor Schluss noch da');

    await _warte(tester, 300 + _ausblenden);
    expect(_splash, findsNothing);
    expect(find.text('Die App'), findsOneWidget);
  });

  testWidgets('die Kurzform ist zu Ende, wenn die volle noch läuft',
      (tester) async {
    const messpunkt = kSplashKurzMs + _ausblenden;

    await tester.pumpWidget(_host(voll: false));
    await _warte(tester, messpunkt);
    expect(_splash, findsNothing, reason: 'Kurzform durch');

    // Dieselbe Zeit, volle Fassung — muss noch laufen. Ohne diese Hälfte
    // wäre der Test auch dann grün, wenn beide Fassungen gleich lang sind.
    await tester.pumpWidget(_host(voll: true));
    await _warte(tester, messpunkt);
    expect(_splash, findsOneWidget, reason: 'volle Fassung läuft noch');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Bewegungsreduzierung überstimmt die volle Fassung',
      (tester) async {
    await tester.pumpWidget(_host(voll: true, ruhig: true));
    await _warte(tester, kSplashKurzMs + _ausblenden);
    expect(_splash, findsNothing,
        reason: 'wer Animationen abgeschaltet hat, will in die App');
  });

  testWidgets('Antippen bricht ab', (tester) async {
    await tester.pumpWidget(_host(voll: true));
    await _warte(tester, 300);
    expect(_splash, findsOneWidget);

    await tester.tap(_splash);
    await _warte(tester, _ausblenden);
    expect(_splash, findsNothing);
    expect(find.text('Die App'), findsOneWidget);

    // Gegenprobe: ohne Tipp ist zum selben Zeitpunkt noch alles da.
    await tester.pumpWidget(_host(voll: true, ruhig: true));
    await tester.pumpWidget(_host(voll: true));
    await _warte(tester, 300 + _ausblenden);
    expect(_splash, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('solange sie läuft, fängt sie die Tipper ab', (tester) async {
    // Sonst greift jemand blind in die App darunter — und trifft eine
    // Schaltfläche, die er nie gesehen hat.
    var getroffen = false;
    await tester.pumpWidget(MaterialApp(
      home: SplashGate(
        voll: true,
        child: Scaffold(
          body: GestureDetector(
            onTap: () => getroffen = true,
            child: const SizedBox.expand(child: Text('Die App')),
          ),
        ),
      ),
    ));
    await _warte(tester, 300);
    await tester.tapAt(const Offset(200, 400));
    await _warte(tester, _ausblenden);
    expect(getroffen, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
