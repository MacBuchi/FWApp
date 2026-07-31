/// app_palette.dart – Wählbare Farbkonzepte (Issue #58).
///
/// **Warum die App bisher blass aussah:** `ColorScheme.fromSeed` benutzt ohne
/// weitere Angabe die Variante `tonalSpot`, und die baut laut Flutter-SDK
/// „pastel palettes with a low chroma" und wird ausdrücklich „not too colorful
/// even if the seedColor has a high chroma value". Ein kräftiges Feuerrot wird
/// dabei systematisch zu Staubrosa entsättigt — der Seed war nie das Problem,
/// die Variante war es. Wie die Seeds zu einem Schema werden, steht bei
/// `schemeFor` in app_theme.dart.
///
/// **Die Konzepte kommen aus der Feuerwehr-Welt, nicht aus dem Farbfächer:**
/// Florian ist der Funkrufname jedes Löschfahrzeugs (und der Markenton des
/// App-Icons), Blaulicht die Rot-Blau-Paarung des Einsatzfahrzeugs, Glut das
/// Warnorange von Einsatzkleidung und Helm.
///
/// **Marke ≠ Thema.** Icon, Splash und `manifest.json` tragen `#C62828` und
/// sind zur Bauzeit gebrannt — eine zur Laufzeit wählbare Palette kann ihnen
/// nicht folgen. Die Marke bleibt darum fest; wählbar ist nur die Farbe *in*
/// der App. Das Standardkonzept trägt genau den Markenton, damit Icon und
/// erster Bildschirm zusammenpassen.
///
/// Tag/Nacht ist bewusst **kein** Teil des Konzepts: Jedes Konzept liefert
/// beide Helligkeiten, und welche gilt, entscheidet weiterhin der
/// Design-Schalter (Standard: Systemeinstellung).
library;

import 'package:flutter/material.dart';

/// Ein wählbares Farbkonzept.
class AppPalette {
  /// Stabile ID — landet in den SharedPreferences, darf sich nie ändern.
  final String id;
  final String name;

  /// Woher die Farben kommen. Steht in der Auswahl, damit die Entscheidung
  /// nicht auf „welches Rot gefällt mir" hinausläuft.
  final String description;

  final Color seed;

  /// Zweitakzent (z. B. Rot im Blaulicht-Konzept). `null` = einfarbig, der
  /// Zweitakzent wird dann aus [seed] abgeleitet.
  final Color? secondarySeed;

  const AppPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.seed,
    this.secondarySeed,
  });
}

/// ID des Standardkonzepts. Bewusst der Markenton aus dem App-Icon.
const kDefaultPaletteId = 'florian';

/// ID des frei gewählten Themas.
const kCustomPaletteId = 'custom';

/// Fallback-Seed des eigenen Themas, bis der Nutzer eine Farbe wählt.
const kCustomPaletteFallbackSeed = Color(0xFFC62828);

/// Die mitgelieferten Konzepte, in Anzeigereihenfolge.
const kAppPalettes = <AppPalette>[
  AppPalette(
    id: kDefaultPaletteId,
    name: 'Florian',
    description: 'Feuerrot auf ruhigem Grund — der Ton des App-Icons, '
        'benannt nach dem Funkrufnamen der Löschfahrzeuge.',
    seed: Color(0xFFC62828),
  ),
  AppPalette(
    id: 'blaulicht',
    name: 'Blaulicht',
    description: 'Signalblau mit rotem Zweitakzent — die Farbpaarung des '
        'Einsatzfahrzeugs, ruhig für lange Lerneinheiten.',
    seed: Color(0xFF005387),
    secondarySeed: Color(0xFFC62828),
  ),
  AppPalette(
    id: 'glut',
    name: 'Glut',
    description: 'Warnorange wie Einsatzjacke und Helm — der warme, '
        'energische Look.',
    seed: Color(0xFFE65100),
  ),
];

/// Das Konzept zu [id], oder das Standardkonzept, wenn sie unbekannt ist.
///
/// Unbekannt heißt in der Praxis: Der Nutzer hatte ein Konzept gewählt, das
/// eine spätere Version nicht mehr kennt (so geschehen beim Umbau von den
/// RAL-Paletten auf die drei Konzepte). Dann ist die Standardfarbe die
/// richtige Antwort — nicht eine leere Oberfläche.
AppPalette paletteById(String? id, {Color? customSeed}) {
  if (id == kCustomPaletteId) {
    return AppPalette(
      id: kCustomPaletteId,
      name: 'Eigenes Farbthema',
      description: 'Selbst gewählte Farbe.',
      seed: customSeed ?? kCustomPaletteFallbackSeed,
    );
  }
  for (final p in kAppPalettes) {
    if (p.id == id) return p;
  }
  return kAppPalettes.first;
}
