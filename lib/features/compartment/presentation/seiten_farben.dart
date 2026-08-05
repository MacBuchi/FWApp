/// seiten_farben.dart – Feste Farben je Fahrzeugseite (Issue #141).
///
/// Die Seite IST die Farbe: Beifahrerseite warm (Rost), Fahrerseite kühl
/// (Stahlblau), Heck grün, Dach ocker, Front violett. Die Merkregel dazu:
/// **Beifahrerseite = warm, Fahrerseite = kühl.**
///
/// Bewusst KEINE Theme-Farben — dieselbe Art Ausnahme wie Grün/Rot im Quiz:
/// Die Zuordnung Seite→Farbe ist Lernstoff. Wer die Farbpalette der App
/// wechselt, muss auf derselben blauen Fahrerseite weiterlernen wie vorher,
/// sonst ist der Anker im Kopf weg.
library;

import 'package:flutter/material.dart';

/// Farbtrio einer Fahrzeugseite.
class SeitenFarbe {
  /// Kräftig: Chips, ausgewählte Kacheln, eingefärbte Sheet-Köpfe.
  /// Text darauf ist immer weiß.
  final Color akzent;

  final Color _flaecheHell;
  final Color _textHell;

  const SeitenFarbe({
    required this.akzent,
    required Color flaeche,
    required Color text,
  }) : _flaecheHell = flaeche,
       _textHell = text;

  /// Zarte Kachel-Fläche. Im Dunkeln eine Akzent-Lasur statt Pastell —
  /// die hellen Töne würden dort leuchten wie Warnwesten.
  Color flaeche(Brightness b) =>
      b == Brightness.light ? _flaecheHell : akzent.withValues(alpha: 0.26);

  /// Text auf [flaeche].
  Color text(Brightness b) =>
      b == Brightness.light
          ? _textHell
          : Color.lerp(akzent, Colors.white, 0.75)!;

  /// Kachelrand auf [flaeche].
  Color rand(Brightness b) =>
      b == Brightness.light
          ? akzent.withValues(alpha: 0.35)
          : akzent.withValues(alpha: 0.55);
}

/// Farben je Seite — Schlüssel wie in `kFahrzeugSeiten`.
const kSeitenFarben = <String, SeitenFarbe>{
  'beifahrerseite': SeitenFarbe(
    akzent: Color(0xFFB4462E),
    flaeche: Color(0xFFF7DCD2),
    text: Color(0xFF7D2C1A),
  ),
  'fahrerseite': SeitenFarbe(
    akzent: Color(0xFF2E6E8E),
    flaeche: Color(0xFFD8E7EE),
    text: Color(0xFF1D4A61),
  ),
  'heck': SeitenFarbe(
    akzent: Color(0xFF4E7A46),
    flaeche: Color(0xFFDCE8D8),
    text: Color(0xFF33512D),
  ),
  'dach': SeitenFarbe(
    akzent: Color(0xFF8A6A2F),
    flaeche: Color(0xFFEFE3CC),
    text: Color(0xFF5D4718),
  ),
  'front': SeitenFarbe(
    akzent: Color(0xFF6B5B8A),
    flaeche: Color(0xFFE3DDEE),
    text: Color(0xFF463A5E),
  ),
};

/// Farbe einer Seite; `null` für „Ohne Seite" und unbekannte Werte — der
/// Aufrufer fällt dann auf neutrale Theme-Farben zurück.
SeitenFarbe? seitenFarbe(String? seite) => kSeitenFarben[seite];
