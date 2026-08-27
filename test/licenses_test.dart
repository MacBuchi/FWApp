/// licenses_test.dart – Hält fest, dass alles Ausgelieferte lizenzrechtlich
/// geklärt ist.
///
/// Der Anlass ist ein echter Fall im Nachbar-Repo: pilzbuddy lieferte
/// Kartenglyphen aus Noto Sans aus, und deren OFL-Text lag nicht einmal im
/// Bundle. Kompiliert sauber, läuft sauber, fällt nie auf — die SIL OFL
/// verlangt aber ausdrücklich, dass ihr Text die Schrift begleitet.
///
/// FWApp hat dieses Problem heute NICHT: Es bündelt keine Schrift, und
/// jedes Asset ist Eigenerzeugnis. Genau deshalb sind die Prüfungen hier
/// überwiegend negativ formuliert — sie sollen in dem Moment rot werden, in
/// dem sich das ändert, und nicht erst, wenn jemand danach sucht.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  /// Die Einträge des `assets:`-Blocks aus `pubspec.yaml`.
  ///
  /// Bewusst per Regex statt mit einem YAML-Paket: Das wäre eine
  /// Abhängigkeit für eine Datei, die wir selbst schreiben — und der Test
  /// soll den Text prüfen, der wirklich dasteht.
  List<String> declaredAssets() {
    final lines = pubspec.split('\n');
    final start = lines.indexWhere((l) => l.trimRight() == '  assets:');
    expect(start, isNot(-1), reason: 'assets:-Block fehlt in pubspec.yaml');
    final assets = <String>[];
    for (final line in lines.skip(start + 1)) {
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      final match = RegExp(r'^\s+- (.+)$').firstMatch(line);
      // Erste Zeile, die kein Listeneintrag mehr ist, beendet den Block.
      if (match == null) break;
      assets.add(match.group(1)!.trim());
    }
    expect(assets, isNotEmpty, reason: 'Keine Assets gelesen — Regex kaputt?');
    return assets;
  }

  group('Lizenzen', () {
    /// Präfixe, unter denen ausschließlich Eigenerzeugnisse liegen, samt
    /// Beleg. Wer hier einträgt, hat entschieden — und wer fremdes Material
    /// ablegt, gehört NICHT hierher, sondern braucht dessen Lizenztext im
    /// Bundle und einen Eintrag in der Lizenzanzeige.
    const ownWorkAssets = <String, String>{
      'CHANGELOG.md': 'eigener Text',
      'assets/equipment_library/':
          'Katalogdaten selbst gepflegt; die Piktogramme erzeugt '
          'tool/generate_pictograms.py aus eigenen SVG-Silhouetten',
      'assets/vehicle_templates/': 'eigene Beladepläne',
      'assets/images/': 'eigene Grafik',
      'assets/branding/': 'eigene Bildmarke',
      'assets/game/': 'selbst geschriebene Fragen und Aufgaben (Issue #160)',
      // ⚠️ Hier steckt eine urheberrechtliche Entscheidung, keine Formalie
      // (Issue #174): Die Fragen sind SELBST FORMULIERT aus den
      // Feuerwehr-Dienstvorschriften. Die FwDV werden vom AFKzV erarbeitet
      // und von den Ländern per Erlass eingeführt — als amtliche Werke sind
      // sie nach § 5 UrhG nicht urheberrechtlich geschützt; die
      // Quellenangabe steht trotzdem an jeder Frage.
      //
      // NICHT entnommen und nicht zu entnehmen: die Lehrstoffblätter der
      // Landesfeuerwehrschule (erscheinen mit ISBN im Neckar-Verlag) und
      // DIN-Normtexte. Der Sachverhalt aus einer Norm ist frei, ihr
      // Wortlaut nicht. Wer hier eine Datei ablegt, deren Fragen aus einer
      // dieser Quellen abgeschrieben sind, trägt sie zu Unrecht ein.
      'assets/knowledge/':
          'selbst formulierte Fragen aus amtlichen Werken (§ 5 UrhG), '
          'Fundstelle an jeder Frage (Issue #174)',
    };

    test('kein ausgeliefertes Asset ohne Lizenz-Entscheidung', () {
      final unknown =
          declaredAssets()
              .where((a) => !ownWorkAssets.keys.any(a.startsWith))
              .toList();
      expect(
        unknown,
        isEmpty,
        reason:
            'Neues Asset in pubspec.yaml: ${unknown.join(", ")}. Ist es '
            'Eigenerzeugnis, gehört sein Präfix mit Begründung in '
            'ownWorkAssets. Ist es fremdes Material, gehört sein Lizenztext '
            'mit ins Bundle und in die Lizenzanzeige — die LICENSE im Repo '
            'deckt nur unseren eigenen Code.',
      );
    });

    test('es wird keine Schrift gebündelt', () {
      // Der eigentliche Wächter dieser Datei, und er ist absichtlich hart:
      // FWApp benutzt die Systemschriften. Sobald jemand einen `fonts:`-
      // Block anlegt, wird dieser Test rot — und das ist der Moment, in dem
      // die Frage nach dem Lizenztext gestellt werden muss, nicht später.
      // Freie Schriften stehen fast durchweg unter der SIL OFL, und die
      // verlangt die Weitergabe ihres Textes IM WORTLAUT zusammen mit der
      // Schrift. Ein Verweis auf die Herkunft genügt ihr nicht.
      //
      // Wer den Block einführt: Lizenzdatei neben die Schrift legen, als
      // Asset deklarieren, über LicenseRegistry registrieren — und diesen
      // Test durch die Variante aus MitFahrBar ersetzen, die Familie gegen
      // Lizenzeintrag prüft (test/licenses_test.dart dort).
      final fontsBlock = RegExp(
        r'^  fonts:\s*$',
        multiLine: true,
      ).hasMatch(pubspec);
      expect(
        fontsBlock,
        isFalse,
        reason:
            'pubspec.yaml hat jetzt einen fonts:-Block. Eine gebündelte '
            'Schrift bringt ihre eigene Lizenz mit (meist SIL OFL), und die '
            'verlangt, dass ihr Text mit ausgeliefert wird. Siehe Kommentar '
            'in diesem Test.',
      );
    });

    test('die Lizenztexte der Pakete erreichen die Nutzer', () {
      // MIT, BSD und Apache verlangen alle, dass ihr Lizenztext dem
      // ausgelieferten Produkt beiliegt — die LICENSE im Repo erfüllt das
      // nicht, die sieht auf einem Android-Gerät niemand. `showLicensePage`
      // sammelt die Texte zur Laufzeit über LicenseRegistry aus den Paketen
      // selbst ein; ohne diesen Aufruf gibt es in der App keinen Weg dorthin.
      //
      // Das ist keine Kosmetik: Der Baum trägt 199 Pakete, davon 125 unter
      // BSD-3-Clause — deren Klausel 2 nennt die Weitergabe des Textes
      // ausdrücklich als Bedingung.
      final settings =
          File(
            'lib/features/settings/presentation/screens/settings_screen.dart',
          ).readAsStringSync();
      expect(
        settings,
        contains('showLicensePage('),
        reason:
            'Der Einstieg in die Lizenzanzeige ist weg. Damit liegt kein '
            'Lizenztext mehr bei der ausgelieferten App — die Bedingung, '
            'unter der wir 199 Pakete überhaupt verwenden dürfen.',
      );
    });

    test('die Lizenzregeln für den Gesamtbestand existieren', () {
      // Der Gegenpol zu dependency-review: Der sieht nur, was ein PR NEU
      // hinzufügt. Ein Lizenzwechsel in einer bestehenden transitiven
      // Abhängigkeit käme dort nie an. Die Datei ist die Grundlage des
      // blockierenden Jobs „Lizenzen (Gesamtbestand)" — fehlt sie, bricht
      // der Job mit einem Pfadfehler ab, was nach Werkzeugproblem aussieht
      // und keins ist.
      final config = File('tool/license_config.yaml');
      expect(config.existsSync(), isTrue);
      final text = config.readAsStringSync();
      for (final forbidden in ['GPL-3.0', 'AGPL-3.0', 'LGPL-2.1']) {
        expect(
          text,
          contains(forbidden),
          reason:
              '$forbidden steht nicht mehr auf der Verbotsliste. Starkes '
              'Copyleft zwingt die ganze App unter dieselbe Lizenz; bei '
              'LGPL scheitert schon die Relink-Auflage an einem statisch '
              'gelinkten Flutter-Build.',
        );
      }
    });
  });
}
