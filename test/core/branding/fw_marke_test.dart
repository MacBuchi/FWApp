/// fw_marke_test.dart – Die Bildmarke in der App und im Icon sind dieselbe
/// (Issue #175).
///
/// ⚠️ **Der eigentliche Test ist der erste.** Das App-Icon entsteht aus
/// `assets/branding/app_icon.svg`, die Startanimation und der
/// Anmeldebildschirm zeichnen aus `fw_marke.dart`. Läuft das auseinander,
/// trägt das Gerät ein anderes Zeichen als die App — und es fällt niemandem
/// auf, weil beide für sich richtig aussehen.
library;

import 'dart:io';

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/branding/fw_marke.dart';

/// Leerraum vereinheitlichen, damit Zeilenumbrüche in der SVG nichts
/// bedeuten.
String _eng(String s) => s.replaceAll(RegExp(r'[\s]+'), ' ').trim();

void main() {
  test('die Pfade stehen wörtlich so in der Icon-Quelle', () {
    final svg = _eng(File('assets/branding/app_icon.svg').readAsStringSync());

    for (final (name, pfad) in [
      ('Helm', kHelmPfad),
      ('Stirnschild', kStirnschildPfad),
      ('Haken', kHakenPfad),
    ]) {
      expect(svg, contains(_eng(pfad)),
          reason: '$name weicht von assets/branding/app_icon.svg ab. Wer das '
              'Icon ändert, ändert fw_marke.dart mit — sonst trägt das Gerät '
              'ein anderes Zeichen als die App.');
    }
  });

  test('auch das Abzeichen stimmt mit der Icon-Quelle überein', () {
    final svg = _eng(File('assets/branding/app_icon.svg').readAsStringSync());
    expect(svg, contains('cx="${kAbzeichenMitte.dx.toInt()}"'));
    expect(svg, contains('cy="${kAbzeichenMitte.dy.toInt()}"'));
    expect(svg, contains('r="${kAbzeichenRing.toInt()}"'));
    expect(svg, contains('r="${kAbzeichenScheibe.toInt()}"'));
  });

  group('fwPfad', () {
    test('liest M, L, C und Z', () {
      final p = fwPfad('M 0,0 L 10,0 C 20,0 30,10 30,20 Z');
      expect(p.getBounds().right, 30);
      expect(p.getBounds().bottom, 20);
    });

    test('nach einem M zählen weitere Paare als Linien', () {
      // So steht es in der Spezifikation; ohne das wäre „M 0,0 10,0"
      // stillschweigend ein zweiter Startpunkt.
      final p = fwPfad('M 0,0 10,0 10,10 Z');
      expect(p.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    test('Helm und Abzeichen füllen genau den Kasten, an dem '
        'ausgerichtet wird', () {
      // Stimmt das nicht, sitzt die Marke in Animation und Anmeldung
      // verschoben — und zwar überall gleich falsch. Der Kasten ist
      // zugleich der, auf den die SVG ihre Marke zentriert
      // (`translate(-546 -609)`), also muss er hier dieselben Zahlen
      // ergeben.
      final gesamt = fwPfad(kHelmPfad).getBounds().expandToInclude(
          Rect.fromCircle(center: kAbzeichenMitte, radius: kAbzeichenRing));
      expect(gesamt, kMarkeKasten);
      expect(gesamt.center, const Offset(546, 609));
    });

    test('ein relativer Befehl wird nicht still verschluckt', () {
      // Lieber laut scheitern als etwas Falsches zeichnen.
      expect(() => fwPfad('M 0,0 c 1,1 2,2 3,3'), throwsFormatException);
    });

    test('ein Pfad ohne Befehl ist ein Fehler', () {
      expect(() => fwPfad('10 20'), throwsFormatException);
    });
  });
}
