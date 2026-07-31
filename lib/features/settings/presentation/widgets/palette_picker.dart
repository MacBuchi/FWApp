/// palette_picker.dart – Auswahl des Farbthemas in den Einstellungen
/// (Issue #58).
///
/// Die Kachel zeigt nicht den rohen Seed, sondern die Farbe, die Material
/// daraus tatsächlich macht — sonst wählt der Nutzer nach einem Ton, den er
/// später nirgends wiederfindet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/theme/app_palette.dart';
import 'package:fwapp/core/theme/app_theme.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';

/// Die Farbe, die eine Palette in der aktuellen Helligkeit wirklich erzeugt —
/// über denselben Weg wie das echte Theme, damit Vorschau und Ergebnis nicht
/// auseinanderlaufen.
ColorScheme schemeForPalette(AppPalette palette, Brightness brightness) =>
    schemeFor(palette, brightness);

class PalettePicker extends ConsumerWidget {
  const PalettePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paletteAsync = ref.watch(appPaletteProvider);
    final brightness = Theme.of(context).brightness;

    return paletteAsync.when(
      loading: () => const ListTile(title: Text('Lade...')),
      error: (e, _) => ListTile(title: Text('Fehler: $e')),
      data: (current) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Farbthema'),
            subtitle: Text(current.description),
          ),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final p in kAppPalettes)
                  _Swatch(
                    label: p.name,
                    color: schemeForPalette(p, brightness).primary,
                    selected: current.id == p.id,
                    onTap: () =>
                        ref.read(appPaletteProvider.notifier).select(p),
                  ),
                _Swatch(
                  label: 'Eigenes',
                  color: current.id == kCustomPaletteId
                      ? schemeForPalette(current, brightness).primary
                      : null,
                  selected: current.id == kCustomPaletteId,
                  onTap: () => _pickCustom(context, ref, current),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustom(
    BuildContext context,
    WidgetRef ref,
    AppPalette current,
  ) async {
    final seed = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomColorSheet(
        initial: current.id == kCustomPaletteId
            ? current.seed
            : kCustomPaletteFallbackSeed,
      ),
    );
    if (seed == null) return;
    await ref.read(appPaletteProvider.notifier).setCustomSeed(seed);
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;

  /// `null` beim eigenen Thema, solange keine Farbe gewählt wurde.
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 84,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color ?? theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: color == null
                    ? Icon(Icons.colorize, color: theme.colorScheme.onSurface)
                    : (selected
                        ? Icon(Icons.check,
                            color: ThemeData.estimateBrightnessForColor(
                                        color!) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black)
                        : null),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eigenes Farbthema über HSV-Regler.
///
/// Bewusst ohne Fremdpaket: Drei Regler und eine Vorschau lösen die Aufgabe,
/// und ein Farbwähler-Paket wäre eine dauerhafte Abhängigkeit für einen
/// Bildschirm, den man einmal im Jahr öffnet.
class CustomColorSheet extends StatefulWidget {
  const CustomColorSheet({super.key, required this.initial});

  final Color initial;

  @override
  State<CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<CustomColorSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = schemeForPalette(
      AppPalette(
        id: kCustomPaletteId,
        name: '',
        description: '',
        seed: _color,
      ),
      theme.brightness,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Eigenes Farbthema', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Die gewählte Farbe ist der Ausgangspunkt — Material leitet '
              'daraus Flächen, Schrift und Kontraste ab.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _PreviewBar(scheme: preview),
            const SizedBox(height: 16),
            _Slider(
              label: 'Farbton',
              value: _hsv.hue,
              max: 360,
              // Der Regler zeigt den Verlauf, den er einstellt — sonst rät man.
              gradient: [
                for (var h = 0.0; h <= 360; h += 60)
                  HSVColor.fromAHSV(1, h, 1, 1).toColor(),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            _Slider(
              label: 'Sättigung',
              value: _hsv.saturation,
              max: 1,
              gradient: [
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            _Slider(
              label: 'Helligkeit',
              value: _hsv.value,
              max: 1,
              gradient: [
                Colors.black,
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _color),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Übernehmen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Zeigt, was aus der Farbe wird — nicht nur die Farbe selbst.
class _PreviewBar extends StatelessWidget {
  const _PreviewBar({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    Widget block(Color c, Color on, String label) => Expanded(
          child: Container(
            height: 56,
            color: c,
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(color: on, fontSize: 11, height: 1.1)),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          block(scheme.primary, scheme.onPrimary, 'Primär'),
          block(scheme.primaryContainer, scheme.onPrimaryContainer, 'Fläche'),
          block(scheme.secondaryContainer, scheme.onSecondaryContainer, 'Akzent'),
          block(scheme.surfaceContainerHighest, scheme.onSurface, 'Karte'),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.max,
    required this.gradient,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final List<Color> gradient;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(colors: gradient),
                ),
              ),
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 12,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(value: value, max: max, onChanged: onChanged),
            ),
          ],
        ),
      ],
    );
  }
}
