/// fw_marke.dart – Die Bildmarke der App als Flutter-Pfade (Issue #175).
///
/// **Warum es diese Datei gibt.** Das App-Icon liegt als SVG in
/// `assets/branding/app_icon.svg` und wird daraus in fünfzig
/// Plattformdateien gerendert. Zur Laufzeit hilft das nicht: Die
/// Startanimation zeichnet auf eine Leinwand, und der Anmeldebildschirm
/// braucht ein Widget. Beide brauchen dieselbe Form.
///
/// ⚠️ **Die Pfade unten sind wörtlich die aus der SVG-Datei.** Wer das Icon
/// ändert und diese Datei vergisst, hat zwei Marken: eine auf dem
/// Startbildschirm des Geräts und eine in der App. Genau deshalb sind sie
/// hier als ZEICHENKETTEN abgelegt und werden geparst, statt von Hand in
/// `Path`-Aufrufe übersetzt zu werden — `fw_marke_test.dart` liest die SVG
/// und vergleicht. Eine Übersetzung von Hand könnte das nicht.
library;

import 'package:flutter/widgets.dart';

/// Der Kasten, in dem die Pfade unten gezeichnet sind.
const kMarkeLeinwand = Size(1024, 1024);

/// Der tatsächlich belegte Bereich — daran wird ausgerichtet, nicht an der
/// Leinwand: Die Marke sitzt nicht in deren Mitte.
const kMarkeKasten = Rect.fromLTRB(140, 280, 952, 938);

/// Helm, Frontansicht.
const kHelmPfad = 'M 152,704 C 140,652 176,616 268,604 '
    'C 260,400 360,280 512,280 '
    'C 664,280 764,400 756,604 '
    'C 848,616 884,652 872,704 Z';

/// Stirnschild — das Zeichen, an dem man den Feuerwehrhelm vom Bauhelm
/// unterscheidet. Wird in der Grundfarbe gemalt, nicht ausgestanzt.
const kStirnschildPfad = 'M 424,396 C 480,376 544,376 600,396 '
    'C 604,496 576,564 512,600 '
    'C 448,564 420,496 424,396 Z';

/// Der Haken im Abzeichen.
const kHakenPfad = 'M 768,792 L 806,830 L 874,750 L 892,768 L 806,858 '
    'L 750,802 Z';

/// Mitte des Abzeichens, Radius des trennenden Rings und der weißen Scheibe.
const kAbzeichenMitte = Offset(820, 806);
const kAbzeichenRing = 132.0;
const kAbzeichenScheibe = 104.0;

/// Zeichnet die Marke so, dass [kMarkeKasten] genau [ziel] ausfüllt.
///
/// [vordergrund] ist die Farbe des Helms und der Scheibe, [grund] die der
/// Aussparungen. Auf farbigem Grund ist [grund] die Hintergrundfarbe — die
/// Aussparungen sind gemalt, nicht ausgestanzt (siehe Kopf der SVG).
void zeichneFwMarke(
  Canvas canvas, {
  required Rect ziel,
  required Color vordergrund,
  required Color grund,
}) {
  canvas.save();
  canvas.translate(ziel.left, ziel.top);
  canvas.scale(ziel.width / kMarkeKasten.width,
      ziel.height / kMarkeKasten.height);
  canvas.translate(-kMarkeKasten.left, -kMarkeKasten.top);

  final weiss = Paint()..color = vordergrund..isAntiAlias = true;
  final rot = Paint()..color = grund..isAntiAlias = true;

  canvas.drawPath(fwPfad(kHelmPfad), weiss);
  canvas.drawPath(fwPfad(kStirnschildPfad), rot);
  canvas.drawCircle(kAbzeichenMitte, kAbzeichenRing, rot);
  canvas.drawCircle(kAbzeichenMitte, kAbzeichenScheibe, weiss);
  canvas.drawPath(fwPfad(kHakenPfad), rot);

  canvas.restore();
}

/// Liest eine SVG-Pfadangabe.
///
/// Bewusst nur der Teil, den die Marke braucht: `M`, `C`, `L`, `Z` in
/// ABSOLUTEN Koordinaten, mit Wiederholung ohne erneuten Buchstaben. Ein
/// vollständiger Parser wäre mehr Angriffsfläche als Nutzen — und wenn
/// jemand die SVG mit anderen Befehlen schreibt, soll das hier auffallen
/// und nicht still etwas Falsches zeichnen.
Path fwPfad(String d) {
  final teile = d
      .replaceAllMapped(RegExp('([MCLZmclz])'), (m) => ' ${m[1]} ')
      .replaceAll(RegExp(r'[\s,]+'), ' ')
      .trim()
      .split(' ');
  final pfad = Path();
  var i = 0;
  var befehl = '';
  double naechste() => double.parse(teile[i++]);

  while (i < teile.length) {
    final t = teile[i];
    if (RegExp('^[MCLZ]\$').hasMatch(t)) {
      befehl = t;
      i++;
      if (befehl == 'Z') {
        pfad.close();
        continue;
      }
    } else if (befehl.isEmpty) {
      throw FormatException('Pfad beginnt ohne Befehl: $d');
    } else if (RegExp('^[mclz]\$').hasMatch(t)) {
      throw FormatException('Relative Befehle werden hier nicht gelesen: $t');
    }
    switch (befehl) {
      case 'M':
        pfad.moveTo(naechste(), naechste());
        // Nach einem M gelten weitere Zahlenpaare als L — so steht es in
        // der Spezifikation.
        befehl = 'L';
      case 'L':
        pfad.lineTo(naechste(), naechste());
      case 'C':
        pfad.cubicTo(naechste(), naechste(), naechste(), naechste(),
            naechste(), naechste());
      default:
        throw FormatException('Unbekannter Befehl: $befehl');
    }
  }
  return pfad;
}

/// Die Marke als Widget — für Bildschirme statt für eine Leinwand.
///
/// [groesse] ist die BREITE; die Höhe ergibt sich aus dem Seitenverhältnis
/// der Marke. [grund] muss die Farbe hinter dem Widget sein, weil die
/// Aussparungen gemalt und nicht ausgestanzt sind.
class FwMarke extends StatelessWidget {
  const FwMarke({
    super.key,
    required this.groesse,
    required this.vordergrund,
    required this.grund,
  });

  final double groesse;
  final Color vordergrund;
  final Color grund;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: groesse,
        height: groesse * kMarkeKasten.height / kMarkeKasten.width,
        child: CustomPaint(
          painter: _MarkePainter(vordergrund: vordergrund, grund: grund),
        ),
      );
}

class _MarkePainter extends CustomPainter {
  const _MarkePainter({required this.vordergrund, required this.grund});

  final Color vordergrund;
  final Color grund;

  @override
  void paint(Canvas canvas, Size size) => zeichneFwMarke(
        canvas,
        ziel: Offset.zero & size,
        vordergrund: vordergrund,
        grund: grund,
      );

  @override
  bool shouldRepaint(_MarkePainter alt) =>
      alt.vordergrund != vordergrund || alt.grund != grund;
}
