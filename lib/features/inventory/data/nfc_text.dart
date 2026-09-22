/// nfc_text.dart – Der Textdatensatz auf einem NFC-Tag, gelesen und
/// geschrieben (Issue #176).
///
/// **Warum das hier und nicht im Plugin steht.** `nfc_manager` liefert einen
/// NDEF-Datensatz als drei Byte-Felder und hört dort auf — den Text
/// herauszuholen ist Sache des Aufrufers. Das NFC-Forum beschreibt dafür ein
/// eigenes kleines Format, und genau an dieser Stelle gehen Codes still
/// kaputt: Wer die ersten Bytes für Text hält, liest „deFW-7K2M9Q" statt
/// „FW-7K2M9Q" — ein Code, der auf nichts passt, ohne dass irgendwo ein
/// Fehler auftaucht.
///
/// **Der Aufbau** (NFC Forum, RTD Text):
///
/// ```
/// [Statusbyte][Sprachkürzel][Text]
///  Bit 7 = 1  → Text ist UTF-16, sonst UTF-8
///  Bit 6      → reserviert, muss 0 sein
///  Bit 5..0   → Länge des Sprachkürzels in Bytes
/// ```
///
/// Deshalb ist das hier eine **reine Funktion ohne Plugin**: Sie ist der
/// Teil, der sich prüfen lässt, und sie ist der Teil, an dem es schiefgeht.
/// Was darüber liegt (Antenne, Berechtigung, Sitzung) kann nur ein Gerät
/// beantworten.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Sprachkürzel, das geschriebene Tags tragen. Nur ein Hinweis für fremde
/// Leser — der Code selbst ist sprachlos.
const kNfcSprache = 'de';

/// Baut die Nutzlast eines Text-Datensatzes mit [text].
///
/// Immer UTF-8: Das ist die Empfehlung des NFC-Forums, jeder Leser versteht
/// es, und ein Code aus [kTagPrefix] und dem eigenen Alphabet ist ohnehin
/// reines ASCII.
Uint8List nfcTextNutzlast(String text, {String sprache = kNfcSprache}) {
  final sprachBytes = ascii.encode(sprache);
  if (sprachBytes.length > 0x3F) {
    throw ArgumentError.value(sprache, 'sprache', 'Kürzel ist zu lang');
  }
  return Uint8List.fromList([
    // Bit 7 = 0 (UTF-8), Bits 5..0 = Länge des Kürzels.
    sprachBytes.length,
    ...sprachBytes,
    ...utf8.encode(text),
  ]);
}

/// Holt den Text aus der Nutzlast eines Text-Datensatzes.
///
/// Gibt `null` zurück, wenn [nutzlast] keiner ist — abgeschnitten, leer oder
/// mit einer Kürzellänge, die über das Ende hinauszeigt. **Nicht werfen:** Am
/// Gerät hält jemand ein fremdes Tag an, und daraus wird „von diesem Tag
/// lesen wir nichts", nicht ein Absturz mitten in der Inventur.
String? nfcTextAusNutzlast(Uint8List nutzlast) {
  if (nutzlast.isEmpty) return null;
  final status = nutzlast[0];
  final sprachLaenge = status & 0x3F;
  final start = 1 + sprachLaenge;
  // `>` und nicht `>=`: Ein Datensatz darf leeren Text tragen. Der ist dann
  // leer und nicht kaputt — `normalisiereTagCode` wirft ihn danach weg.
  if (start > nutzlast.length) return null;

  final textBytes = nutzlast.sublist(start);
  // Bit 7 gesetzt heißt UTF-16. Selten, aber es gibt Tags, die von anderen
  // Programmen so beschrieben wurden — sie als UTF-8 zu lesen ergäbe
  // Zeichensalat mit Nullbytes dazwischen, also wieder einen Code, der auf
  // nichts passt.
  if (status & 0x80 != 0) return _ausUtf16(textBytes);
  try {
    return utf8.decode(textBytes);
  } on FormatException {
    return null;
  }
}

/// UTF-16 mit Byte-Order-Mark; ohne BOM gilt Big-Endian, so steht es in der
/// Spezifikation.
String? _ausUtf16(Uint8List bytes) {
  if (bytes.length.isOdd) return null;
  var ab = 0;
  var kleinZuerst = false;
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      kleinZuerst = true;
      ab = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      ab = 2;
    }
  }
  final einheiten = <int>[];
  for (var i = ab; i + 1 < bytes.length; i += 2) {
    einheiten.add(kleinZuerst
        ? bytes[i] | (bytes[i + 1] << 8)
        : (bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(einheiten);
}

/// Die Seriennummer eines Tags als Code, groß und ohne Trenner.
///
/// **Der Rückfallweg für Tags, die sich nicht beschreiben lassen.** Billige
/// Aufkleber und viele Prüfplaketten sind schreibgeschützt oder tragen
/// bereits etwas — ihre Seriennummer ist trotzdem eindeutig und
/// unveränderlich, und mehr braucht ein Code nicht. Der Vorsatz macht
/// sichtbar, woher er kommt, und hält ihn von einem vergebenen Code
/// (`FW-…`) auseinander.
String nfcSeriennummerCode(Uint8List id) =>
    '$kNfcSeriennummerPrefix${id.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

/// Vorsatz der Codes, die aus einer Tag-Seriennummer entstehen.
const kNfcSeriennummerPrefix = 'NFC-';
