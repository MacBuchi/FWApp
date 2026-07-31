/// AppTheme – Material 3 theme for the FWApp.
/// Design language: modern, schlank, übersichtlich — flat outlined cards
/// instead of shadows, consistent radii, calm surfaces, Feuerwehr red as seed.
///
/// Die Farbe kommt aus einer [AppPalette] (Issue #58); alles andere — Radien,
/// Flächen, Abstände — bleibt für jede Palette gleich, damit die Auswahl das
/// Erscheinungsbild färbt und nicht umbaut.
library;
import 'package:flutter/material.dart';
import 'package:fwapp/core/theme/app_palette.dart';

/// Das Farbschema zu einem Konzept — kräftiger Akzent, ruhige Flächen.
///
/// **Warum überhaupt gemischt wird.** Material leitet aus einem Seed *alles*
/// ab, auch die Wände. Am Emulator gegenübergestellt: `fidelity` färbt die
/// halbe App rosa, `vibrant` nimmt der Primärfarbe die Kraft, und der
/// Standard `tonalSpot` wäscht ein kräftiges Feuerrot zu Pastell aus — das
/// war der Auslöser von Issue #58. Keine Variante kann es allein, weil die
/// Rollen Gegensätzliches wollen: Der Knopf soll leuchten, die Karte darunter
/// nicht.
///
/// **Die Regel beim Mischen: Ein Farbpaar wird nie getrennt.** Material
/// garantiert Kontrast nur *innerhalb* eines Schemas. Ein `primaryContainer`
/// aus dem einen und sein `onPrimaryContainer` aus dem anderen Schema ergibt
/// unlesbare Schrift. Jedes (Farbe, onFarbe)-Paar stammt deshalb geschlossen
/// aus einer Quelle (abgesichert durch den WCAG-Test in app_palette_test):
///
/// - **Leuchtende Akzente** — Knopf, Navigationspille, Fortschritt →
///   `fidelity` („palettes match seed color, even if very bright")
/// - **Getönte Blöcke** — Container-Rollen, auf denen Text steht →
///   `tonalSpot`, dessen Pastell hier genau richtig ist
/// - **Flächen und Linien** — Hintergrund, Karten, Trennlinien →
///   `neutral` („close to grayscale, a hint of chroma")
/// - **Zweitakzent** — bei Konzepten mit [AppPalette.secondarySeed] (etwa Rot
///   im Blaulicht-Konzept) kommen die vier Secondary-Rollen geschlossen aus
///   einem eigenen Schema über diesem zweiten Seed
ColorScheme schemeFor(AppPalette palette, Brightness brightness) {
  ColorScheme of(Color seed, DynamicSchemeVariant variant) =>
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        dynamicSchemeVariant: variant,
      );

  final accent = of(palette.seed, DynamicSchemeVariant.fidelity);
  final tinted = of(palette.seed, DynamicSchemeVariant.tonalSpot);
  final calm = of(palette.seed, DynamicSchemeVariant.neutral);
  // Zweitakzent gedämpfter als der Hauptakzent (tonalSpot statt fidelity):
  // Zwei Vollton-Farben nebeneinander konkurrieren, eine muss führen.
  final second = palette.secondarySeed == null
      ? null
      : of(palette.secondarySeed!, DynamicSchemeVariant.tonalSpot);

  return tinted.copyWith(
    // Akzentpaare: kräftig.
    primary: accent.primary,
    onPrimary: accent.onPrimary,
    surfaceTint: accent.primary,
    // Zweitakzent-Paare geschlossen aus dem Zweit-Schema; ohne secondarySeed
    // der kräftige Ton des Hauptseeds.
    secondary: second?.secondary ?? accent.secondary,
    onSecondary: second?.onSecondary ?? accent.onSecondary,
    secondaryContainer: second?.secondaryContainer ?? tinted.secondaryContainer,
    onSecondaryContainer:
        second?.onSecondaryContainer ?? tinted.onSecondaryContainer,
    // Container-Paare bleiben, wie tonalSpot sie liefert (Basis oben).
    // Flächen und Linien: ruhig.
    surface: calm.surface,
    onSurface: calm.onSurface,
    onSurfaceVariant: calm.onSurfaceVariant,
    surfaceDim: calm.surfaceDim,
    surfaceBright: calm.surfaceBright,
    surfaceContainerLowest: calm.surfaceContainerLowest,
    surfaceContainerLow: calm.surfaceContainerLow,
    surfaceContainer: calm.surfaceContainer,
    surfaceContainerHigh: calm.surfaceContainerHigh,
    surfaceContainerHighest: calm.surfaceContainerHighest,
    outline: calm.outline,
    outlineVariant: calm.outlineVariant,
    inverseSurface: calm.inverseSurface,
    onInverseSurface: calm.onInverseSurface,
  );
}

class AppTheme {
  static ThemeData light([AppPalette? palette]) =>
      _base(Brightness.light, palette ?? kAppPalettes.first);
  static ThemeData dark([AppPalette? palette]) =>
      _base(Brightness.dark, palette ?? kAppPalettes.first);

  static ThemeData _base(Brightness brightness, AppPalette palette) {
    final scheme = schemeFor(palette, brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      // Wo die Konzeptfarbe wirklich auftritt (Issue #58): Pille und
      // Fortschritt tragen den vollen Akzent, die Spur bleibt neutral. Vorher
      // spielten überall die Pastell-Container die Akzentrolle — in Summe
      // wirkte die App dadurch rosa statt rot.
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
      ),
    );
  }
}
