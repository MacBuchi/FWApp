/// gesamtwehr_header.dart – Eigener Kopfbereich der Gesamtwehr auf der
/// Startseite (#57 P5 Branding).
///
/// Zwei Schichten, damit die Pflegemaske dieselbe Darstellung zeigen kann wie
/// die Startseite: [GesamtwehrKopf] ist reine Anzeige aus übergebenen Werten,
/// [GesamtwehrHeader] holt sie aus den Providern. Eine zweite Nachbildung fürs
/// Vorschaubild wäre Drift — sie würde beim ersten Umbau auseinanderlaufen.
///
/// Ist nichts gepflegt, verschwindet der Kopf rückstandslos — dasselbe
/// Versprechen wie bei [HomeBanners]: kein leerer Kasten, der Platz
/// beansprucht, den er nicht füllt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/core/sync/branding_providers.dart';
import 'package:fwapp/core/utils/image_utils.dart';

/// Obergrenze für die Höhe des Kopfbilds. Bewusst nicht
/// seitenverhältnis-gebunden: Auf einem breiten Fenster fräße ein 16:9-Bild den
/// halben Bildschirm, bevor die erste Kachel kommt.
const double kGesamtwehrHeaderBildHoehe = 168;

/// Höhe des Kopfbilds für eine gegebene Fensterhöhe.
///
/// ⚠️ Im Browser bei 683×411 (Querformat-Handy) gefunden: Mit fester Höhe
/// standen Tagesserie, Level, Wochenziel und „Weiterlernen" allesamt unter der
/// Kante — die Startseite bestand aus nichts als dem Kopf. Deshalb höchstens
/// ein knappes Drittel der Fensterhöhe. Auf üblichen Höhen ändert das nichts
/// (ab 560 px greift wieder die Obergrenze).
double gesamtwehrKopfHoehe(double fensterHoehe) {
  final anteil = fensterHoehe * 0.3;
  return anteil < kGesamtwehrHeaderBildHoehe
      ? (anteil < 96 ? 96 : anteil)
      : kGesamtwehrHeaderBildHoehe;
}

/// Reine Anzeige. [bild] ist ein fertiges Widget, damit die Pflegemaske ein
/// noch nicht hochgeladenes Foto aus dem Speicher vorschauen kann — in der
/// Web-App gibt es dafür keinen Dateipfad, den man durchreichen könnte.
class GesamtwehrKopf extends StatelessWidget {
  final String? titel;
  final String? text;
  final Widget? bild;

  const GesamtwehrKopf({super.key, this.titel, this.text, this.bild});

  bool get istLeer =>
      (titel == null || titel!.isEmpty) &&
      (text == null || text!.isEmpty) &&
      bild == null;

  @override
  Widget build(BuildContext context) {
    if (istLeer) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final hatBild = bild != null;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hatBild)
            _Bildkopf(bild: bild!, titel: titel)
          else if (titel != null && titel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Text(
                titel!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
              ),
            ),
          if (text != null && text!.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(18, hatBild ? 14 : 8, 18, 16),
              child: Text(
                text!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
            )
          // Ohne Text fehlt dem Titel sonst der untere Rand; hinter einem Bild
          // schließt der Verlauf bereits bündig ab.
          else if (!hatBild)
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Bild mit Verlauf und darüberliegender Überschrift.
class _Bildkopf extends StatelessWidget {
  final Widget bild;
  final String? titel;
  const _Bildkopf({required this.bild, this.titel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: gesamtwehrKopfHoehe(MediaQuery.sizeOf(context).height),
      child: Stack(
        fit: StackFit.expand,
        children: [
          bild,
          if (titel != null && titel!.isNotEmpty) ...[
            // Der Verlauf ist kein Schmuck, sondern die Kontrast-Garantie:
            // Über einem hellen Foto wäre weiße Schrift sonst unlesbar, und
            // welches Foto der Kommandant hochlädt, wissen wir nicht.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB3000000)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Text(
                  titel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Das gepflegte Kopfbild als Widget, oder `null`, wenn keines hinterlegt ist.
Widget? gesamtwehrKopfBild(String? pfad) {
  if (pfad == null || pfad.isEmpty) return null;
  return resolveImage(
    path: pfad,
    fit: BoxFit.cover,
    // Kein grauer Kasten dahinter: Der Kopf sitzt schon auf einer Fläche des
    // Schemas, ein zweiter Grauton darunter würde beim Laden aufblitzen.
    backgroundColor: null,
    placeholder: const ColoredBox(color: Color(0x11000000)),
  );
}

class GesamtwehrHeader extends ConsumerWidget {
  const GesamtwehrHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(gesamtwehrBrandingProvider).value;
    final wehr = ref.watch(aktuelleGesamtwehrProvider).value;
    if (branding == null || branding.istLeer) return const SizedBox.shrink();

    // Antippen führt zur Pflege — aber nur für den, der auch pflegen darf.
    // Für alle anderen ist der Kopf reine Anzeige und schluckt keine Tipps.
    final darfPflegen = ref.watch(darfBrandingPflegenProvider).value ?? false;

    final kopf = GesamtwehrKopf(
      titel: branding.anzeigeTitel(wehr?.name),
      text: branding.willkommenstext,
      bild: gesamtwehrKopfBild(branding.bildPfad),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: darfPflegen
          ? Stack(
              children: [
                kopf,
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => context.push('/gesamtwehr/kopfbereich'),
                    ),
                  ),
                ),
              ],
            )
          : kopf,
    );
  }
}
