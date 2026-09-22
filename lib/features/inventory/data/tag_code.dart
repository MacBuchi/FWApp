/// tag_code.dart – Codes für Geräte-Tags: normalisieren und vergeben
/// (Issues #177/#179).
///
/// **Warum normalisiert gespeichert wird.** Derselbe Aufkleber liefert nicht
/// jedes Mal dieselbe Zeichenkette: Ein Scanner hängt gern ein Zeilenende an,
/// eine Tastatureingabe bringt Leerzeichen mit, und ob jemand „fw-7k2m9q"
/// oder „FW-7K2M9Q" tippt, ist für den Gegenstand dieselbe Aussage. Ohne
/// Normalisierung liegt derselbe Code zweimal in der Tabelle und das
/// Nachschlagen findet ihn beim Scannen nicht wieder.
///
/// **Warum die Vergabe Zeichen weglässt.** Ein vergebener Code wird
/// ausgedruckt, aufgeklebt und im Zweifel abgetippt — dann entscheidet, ob
/// man 0 und O oder 1 und I auseinanderhält. Das Alphabet unten enthält
/// deshalb keines der verwechselbaren Paare (Crockford-Base32 ohne I, L, O,
/// U). Das kostet nichts und erspart die Fehlersuche an einem Code, der
/// „ja genau so dasteht".
library;

import 'dart:math';

/// Vorsatz vergebener Codes. Macht auf dem Aufkleber sichtbar, woher er
/// kommt, und trennt sie von fremden Barcodes.
const kTagPrefix = 'FW-';

/// Zeichen ohne verwechselbare Paare — kein I, L, O, U.
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Länge des Zufallsteils. Sieben Zeichen aus 32 sind rund 34 Milliarden
/// Möglichkeiten — bei ein paar hundert Geräten ist eine Kollision damit
/// kein praktisches Thema, und geprüft wird sie trotzdem.
const _laenge = 7;

/// Bringt einen gelesenen oder getippten Code auf die Form, in der er
/// gespeichert und verglichen wird.
///
/// Leerraum fällt weg — auch mittendrin, weil Scanner ihn an Trennstellen
/// einstreuen. Kleinbuchstaben werden groß. Ein leerer Rest gilt als kein
/// Code und gibt `null` zurück, damit nirgends ein Tag mit leerem Schlüssel
/// entsteht, der auf alles passt.
String? normalisiereTagCode(String roh) {
  final ohneLeerraum = roh.replaceAll(RegExp(r'\s+'), '');
  if (ohneLeerraum.isEmpty) return null;
  return ohneLeerraum.toUpperCase();
}

/// Vergibt einen neuen Code, der in [vergeben] noch nicht vorkommt.
///
/// [vergeben] sind die bereits normalisierten Codes. Der Zufall ist
/// injizierbar, damit der Test die Kollision herstellen kann, statt auf sie
/// zu warten.
String erzeugeTagCode(Set<String> vergeben, {Random? zufall}) {
  final r = zufall ?? Random.secure();
  // Die Schranke ist Notbremse, nicht Verfahren: Bei 34 Milliarden
  // Möglichkeiten heißt „hundertmal danebengegriffen" nicht Pech, sondern
  // dass etwas anderes kaputt ist — dann lieber laut scheitern.
  for (var versuch = 0; versuch < 100; versuch++) {
    final code =
        '$kTagPrefix${List.generate(_laenge, (_) => _alphabet[r.nextInt(_alphabet.length)]).join()}';
    if (!vergeben.contains(code)) return code;
  }
  throw StateError(
    'Kein freier Tag-Code nach 100 Versuchen — das ist kein Zufall.',
  );
}

/// Ob [code] von dieser App vergeben wurde.
bool istEigenerCode(String code) => code.startsWith(kTagPrefix);
