/// app_palette_test.dart – Farbthemen (Issue #58): Auflösung der Palette,
/// Persistenz der Wahl und der eigentliche Punkt des Issues — dass die Farbe
/// nicht mehr entsättigt wird.
library;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/theme/app_palette.dart';
import 'package:fwapp/core/theme/app_theme.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chroma-Ersatzmaß: Abstand des kräftigsten zum schwächsten Kanal. Reicht,
/// um „bunt" von „grau" zu unterscheiden, ohne eine Farbraum-Bibliothek.
double _chroma(Color c) {
  final r = c.r, g = c.g, b = c.b;
  final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
  final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
  return maxC - minC;
}

/// Kontrastverhältnis nach WCAG 2.1 (1:1 bis 21:1).
double _contrast(Color fg, Color bg) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final a = luminance(fg), b = luminance(bg);
  final hi = a > b ? a : b, lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('paletteById', () {
    test('findet ein mitgeliefertes Konzept', () {
      expect(paletteById('blaulicht').name, 'Blaulicht');
    });

    test('fällt bei unbekannter ID auf den Standard zurück', () {
      // Kommt vor, wenn eine spätere Version eine Palette entfernt: Der Wert
      // steht dann noch in den Preferences. Eine leere Oberfläche wäre die
      // falsche Antwort.
      expect(paletteById('gibtesnicht').id, kDefaultPaletteId);
      expect(paletteById(null).id, kDefaultPaletteId);
    });

    test('eigenes Thema nimmt den übergebenen Seed', () {
      const seed = Color(0xFF00A0B0);
      expect(paletteById(kCustomPaletteId, customSeed: seed).seed, seed);
    });

    test('eigenes Thema ohne Seed bleibt auf der Rückfallfarbe', () {
      expect(paletteById(kCustomPaletteId).seed, kCustomPaletteFallbackSeed);
    });

    test('IDs sind eindeutig', () {
      final ids = kAppPalettes.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('AppTheme', () {
    test('jede Palette ergibt eine eigene Primärfarbe', () {
      // Zwei Paletten, die auf dieselbe Farbe hinauslaufen, wären in der
      // Auswahl nicht unterscheidbar — der Nutzer tippt und nichts passiert.
      final primaries =
          kAppPalettes.map((p) => AppTheme.light(p).colorScheme.primary);
      expect(primaries.toSet().length, kAppPalettes.length);
    });

    test('fidelity bleibt näher am Seed als der Material-Standard', () {
      // Der Kern von Issue #58: `tonalSpot` baut laut SDK „pastel palettes
      // with a low chroma" und wäscht ein kräftiges Feuerrot aus. Wenn dieser
      // Test kippt, ist die Variante versehentlich zurückgestellt worden.
      const seed = Color(0xFFC62828);
      final pastel = ColorScheme.fromSeed(seedColor: seed);
      final ours = AppTheme.light().colorScheme;

      expect(_chroma(ours.primary), greaterThan(_chroma(pastel.primary)));
    });

    test('jedes Farbpaar bleibt lesbar — in jeder Palette, hell wie dunkel',
        () {
      // Das Schema mischt drei Material-Varianten (siehe schemeFor). Material
      // garantiert Kontrast aber nur *innerhalb* eines Schemas: Beim ersten
      // Versuch stammte `primaryContainer` aus `fidelity` und sein
      // `onPrimaryContainer` aus einer anderen Quelle — die
      // „Weiterlernen"-Karte wurde dunkelrot auf rot. Dieser Test hätte das
      // gefangen, deshalb steht er hier.
      for (final palette in [...kAppPalettes, paletteById(kCustomPaletteId)]) {
        for (final brightness in Brightness.values) {
          final s = schemeFor(palette, brightness);
          final pairs = <String, (Color, Color)>{
            'primary': (s.onPrimary, s.primary),
            'primaryContainer': (s.onPrimaryContainer, s.primaryContainer),
            'secondary': (s.onSecondary, s.secondary),
            'secondaryContainer': (s.onSecondaryContainer, s.secondaryContainer),
            'tertiaryContainer': (s.onTertiaryContainer, s.tertiaryContainer),
            'error': (s.onError, s.error),
            'errorContainer': (s.onErrorContainer, s.errorContainer),
            'surface': (s.onSurface, s.surface),
            'surfaceVariant': (s.onSurfaceVariant, s.surfaceContainerHighest),
            'inverseSurface': (s.onInverseSurface, s.inverseSurface),
          };
          pairs.forEach((role, pair) {
            // 4.5:1 ist die WCAG-AA-Schwelle für Fließtext.
            expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5),
                reason: '$role in ${palette.name} (${brightness.name})');
          });
        }
      }
    });

    test('hell und dunkel unterscheiden sich in der Helligkeit', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('Zweitakzent: Blaulicht trägt Rot neben Blau', () {
      // Das Blaulicht-Konzept lebt von der Rot-Blau-Paarung des
      // Einsatzfahrzeugs. Ohne secondarySeed wäre secondary nur ein weiteres
      // Blau — dann ist das Konzept still auf einfarbig zurückgefallen.
      final blaulicht = paletteById('blaulicht');
      final s = schemeFor(blaulicht, Brightness.light);
      final einfarbig = schemeFor(
        AppPalette(
          id: 'x',
          name: 'x',
          description: 'x',
          seed: blaulicht.seed,
        ),
        Brightness.light,
      );
      expect(s.secondary, isNot(einfarbig.secondary));
      // Rotanteil führt: Der Zweitakzent kommt aus dem roten Seed.
      expect(s.secondary.r, greaterThan(s.secondary.b));
    });

    test('ohne Palette gilt der Standard', () {
      expect(AppTheme.light().colorScheme.primary,
          AppTheme.light(kAppPalettes.first).colorScheme.primary);
    });
  });

  group('AppPaletteNotifier', () {
    test('ohne gespeicherte Wahl kommt der Standard', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect((await container.read(appPaletteProvider.future)).id,
          kDefaultPaletteId);
    });

    test('gespeicherte Wahl überlebt den Neustart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(appPaletteProvider.future);
      await first.read(appPaletteProvider.notifier).select(kAppPalettes[2]);
      first.dispose();

      // Neuer Container = neuer Start der App, gleiche Preferences.
      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect((await second.read(appPaletteProvider.future)).id,
          kAppPalettes[2].id);
    });

    test('eigener Seed wird gespeichert und wieder gelesen', () async {
      SharedPreferences.setMockInitialValues({});
      const seed = Color(0xFF2E7D32);
      final first = ProviderContainer();
      await first.read(appPaletteProvider.future);
      await first.read(appPaletteProvider.notifier).setCustomSeed(seed);
      expect((await first.read(appPaletteProvider.future)).seed, seed);
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final restored = await second.read(appPaletteProvider.future);
      expect(restored.id, kCustomPaletteId);
      expect(restored.seed, seed);
    });
  });
}
