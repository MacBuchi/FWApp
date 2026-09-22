/// nfc_text_test.dart – Der Textdatensatz auf einem NFC-Tag (Issue #176).
///
/// Das ist der Teil von NFC, der sich ohne Gerät prüfen lässt — und es ist
/// der Teil, an dem ein Code still falsch wird. Ein um zwei Bytes
/// verschobener Text ergibt keinen Fehler, sondern einen Code, der auf nichts
/// passt; niemand sieht, dass „deFW-7K2M9Q" herauskam.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/inventory/data/nfc_text.dart';
import 'package:fwapp/features/inventory/data/tag_code.dart';

void main() {
  group('schreiben und wieder lesen', () {
    test('ein vergebener Code kommt unverändert zurück', () {
      const code = 'FW-7K2M9Q';
      expect(nfcTextAusNutzlast(nfcTextNutzlast(code)), code);
    });

    test('das Sprachkürzel landet NICHT im Text', () {
      // Der Fehler, um den es hier geht: Wer die Nutzlast für Text hält,
      // liest „deFW-7K2M9Q".
      final nutzlast = nfcTextNutzlast('FW-7K2M9Q');
      expect(nfcTextAusNutzlast(nutzlast), isNot(startsWith('de')));
      expect(nutzlast[0], 2, reason: 'Statusbyte: UTF-8, Kürzel zwei Bytes.');
      expect(ascii.decode(nutzlast.sublist(1, 3)), 'de');
    });

    test('Umlaute überleben', () {
      // Ein übernommener Code kann alles sein, was auf dem Gerät steht.
      const text = 'Prüfplakette 2026 – Größe 3';
      expect(nfcTextAusNutzlast(nfcTextNutzlast(text)), text);
    });

    test('das Geschriebene ist bereits normalisiert lesbar', () {
      final code = nfcTextAusNutzlast(nfcTextNutzlast('FW-7K2M9Q'))!;
      expect(normalisiereTagCode(code), 'FW-7K2M9Q');
    });
  });

  group('lesen, was andere geschrieben haben', () {
    test('ein englisches Tag mit längerem Kürzel', () {
      // Die Kürzellänge steht im Statusbyte und ist nicht immer zwei.
      final nutzlast = Uint8List.fromList([
        5, // UTF-8, Kürzel fünf Bytes
        ...ascii.encode('en-US'),
        ...utf8.encode('4006381333931'),
      ]);
      expect(nfcTextAusNutzlast(nutzlast), '4006381333931');
    });

    test('UTF-16 wird nicht als UTF-8 verdreht gelesen', () {
      // Big-Endian ohne BOM, so steht es in der Spezifikation. Als UTF-8
      // gelesen käme Zeichensalat mit Nullbytes heraus — wieder ein Code,
      // der auf nichts passt.
      final nutzlast = Uint8List.fromList([
        0x80 | 2, // Bit 7: UTF-16
        ...ascii.encode('de'),
        0x00, 0x46, 0x00, 0x57, 0x00, 0x2D, 0x00, 0x31, // 'FW-1'
      ]);
      expect(nfcTextAusNutzlast(nutzlast), 'FW-1');
    });

    test('UTF-16 mit BOM in beiden Richtungen', () {
      final grossZuerst = Uint8List.fromList(
          [0x82, ...ascii.encode('de'), 0xFE, 0xFF, 0x00, 0x41]);
      final kleinZuerst = Uint8List.fromList(
          [0x82, ...ascii.encode('de'), 0xFF, 0xFE, 0x41, 0x00]);
      expect(nfcTextAusNutzlast(grossZuerst), 'A');
      expect(nfcTextAusNutzlast(kleinZuerst), 'A');
    });
  });

  group('was ein fremdes Tag sonst so trägt', () {
    test('leer ist kein Text', () {
      expect(nfcTextAusNutzlast(Uint8List(0)), isNull);
    });

    test('eine Kürzellänge über das Ende hinaus wirft nicht', () {
      // ⚠️ Am Gerät hält jemand irgendein Tag an. Daraus muss „von diesem
      // Tag lesen wir nichts" werden, kein Absturz mitten in der Inventur.
      final kaputt = Uint8List.fromList([0x3F, ...ascii.encode('de')]);
      expect(nfcTextAusNutzlast(kaputt), isNull);
    });

    test('ein Datensatz ohne Text ist leer, nicht kaputt', () {
      final nurKuerzel = Uint8List.fromList([2, ...ascii.encode('de')]);
      expect(nfcTextAusNutzlast(nurKuerzel), '');
      // Und danach wirft ihn die Normalisierung weg — genau wie eine leere
      // Tastatureingabe.
      expect(normalisiereTagCode(nfcTextAusNutzlast(nurKuerzel)!), isNull);
    });

    test('ungültiges UTF-8 wirft nicht, sondern gilt als nichts', () {
      final murks =
          Uint8List.fromList([2, ...ascii.encode('de'), 0xC3, 0x28]);
      expect(nfcTextAusNutzlast(murks), isNull);
    });
  });

  group('Seriennummer als Rückfallweg', () {
    test('wird zu einem eindeutigen, lesbaren Code', () {
      // Für Tags, die schreibgeschützt sind oder schon etwas tragen.
      final id = Uint8List.fromList([0x04, 0x1A, 0xBC, 0xDE, 0xF0]);
      expect(nfcSeriennummerCode(id), 'NFC-041ABCDEF0');
    });

    test('führende Null geht nicht verloren', () {
      // `toRadixString` liefert „4" statt „04" — damit wären zwei
      // verschiedene Tags plötzlich derselbe Code.
      expect(nfcSeriennummerCode(Uint8List.fromList([0x04, 0x00])),
          'NFC-0400');
      expect(nfcSeriennummerCode(Uint8List.fromList([0x40, 0x00])),
          'NFC-4000');
    });

    test('ist von einem vergebenen Code zu unterscheiden', () {
      final code = nfcSeriennummerCode(Uint8List.fromList([1, 2, 3, 4]));
      expect(istEigenerCode(code), isFalse,
          reason: 'Übernommen, nicht vergeben — die App hat ihn nicht '
              'gewürfelt und kann ihn nicht ausdrucken.');
      expect(normalisiereTagCode(code), code);
    });
  });
}
