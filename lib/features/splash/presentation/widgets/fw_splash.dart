/// fw_splash.dart – Die Startanimation (Issues #129/#175).
///
/// **Was sie erzählt — und warum sie neu ist.** Die erste Fassung zeigte
/// Flamme → Löschen → Logo, also den EINSATZ. Das passte nicht: Diese App
/// ist die Zeit davor. Beladen, lernen, prüfen — damit im Einsatz alles da
/// ist. Drei Szenen: **Fach** (1,2 s), **Prüfen** (1,3 s), **Zeichen**
/// (1,8 s), zusammen 4,3 s.
///
/// Dazu kam der Grund aus #175: Die alte Marke war eine weiße Flamme auf
/// rotem Verlauf und damit kaum von der Tinder-Marke zu unterscheiden.
///
/// ⚠️ **Die Marke wird NICHT hier gezeichnet**, sondern kommt aus
/// `core/branding/fw_marke.dart` — derselben Geometrie wie das App-Icon.
/// Eine eigene Zeichnung hier hieße: zwei Marken, die auseinanderlaufen.
///
/// Alle Koordinaten stehen im 1080×1920-Raum und werden am Stück skaliert.
///
/// Warum ein [CustomPainter] und nicht Transform/Opacity-Widgets: Der
/// Painter ist dieselbe Rechnung, aber prüfbar. Ein Widget-Baum lässt sich
/// nur über Transform-Werte abfragen, ein Painter über das Bild — und die
/// Frage ist „kommt die Szene auf die Leinwand", nicht „steht der richtige
/// Wert im Baum".
///
/// Die Schrift ist die des Systems: Eine Schriftart mitzuliefern kostet
/// Downloadgröße für zwei Sekunden Anzeige.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fwapp/core/branding/fw_marke.dart';

/// Bühne.
const double kSplashW = 1080;
const double kSplashH = 1920;
const double _cx = 540;
const double _cy = 860;

/// Der Grund ist derselbe flache Ton wie beim App-Icon — die Animation ist
/// das Icon in Bewegung, nicht ein zweites Erscheinungsbild.
const _rot = Color(0xFFC62828);
const _weiss = Colors.white;

/// Szenendauern in Millisekunden.
const int kFachMs = 1200;
const int kPruefenMs = 1300;
const int kZeichenMs = 1800;
const int kSplashVollMs = kFachMs + kPruefenMs + kZeichenMs;

/// Die Kurzform: nur die Zeichen-Szene.
///
/// Wer die App im Gerätehaus zweimal öffnet, soll nicht zweimal 4,3 Sekunden
/// zusehen — die volle Fassung läuft nur nach Installation und Update.
const int kSplashKurzMs = 600;

/// Das Fach, in dem die erste Szene spielt.
final Rect _fachAussen =
    Rect.fromCenter(center: const Offset(_cx, 830), width: 660, height: 470);
final Rect _fachInnen = _fachAussen.deflate(26);

/// Abschnitt einer Szene: [p] auf [a]..[b] abbilden und mit [kurve] beugen.
double _seg(double p, double a, double b, Curve kurve) =>
    kurve.transform(((p - a) / (b - a)).clamp(0.0, 1.0));

/// Die Startanimation als Bild zum Zeitpunkt [fortschritt] (0..1).
class SplashPainter extends CustomPainter {
  SplashPainter({required this.fortschritt, required this.voll});

  /// 0..1 über die GESAMTE Laufzeit — welche Szene das ist, rechnet der
  /// Painter selbst aus.
  final double fortschritt;

  /// Volle Fassung (drei Szenen) oder Kurzform (nur das Zeichen).
  final bool voll;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Bildfüllend und mittig: Auf einem 16:9-Gerät ist die Bühne höher als
    // der Bildschirm; beschnitten wird oben und unten, wo nichts steht.
    final faktor = math.max(size.width / kSplashW, size.height / kSplashH);
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - kSplashW * faktor) / 2,
      (size.height - kSplashH * faktor) / 2,
    );
    canvas.scale(faktor);

    _grund(canvas);

    final p = fortschritt.clamp(0.0, 1.0);
    if (!voll) {
      _zeichen(canvas, p);
    } else {
      final ms = p * kSplashVollMs;
      if (ms < kFachMs) {
        _fach(canvas, ms / kFachMs);
      } else if (ms < kFachMs + kPruefenMs) {
        _pruefen(canvas, (ms - kFachMs) / kPruefenMs);
      } else {
        _zeichen(canvas, (ms - kFachMs - kPruefenMs) / kZeichenMs);
      }
    }
    canvas.restore();
  }

  // ── Szene 1 · Das Fach geht auf ───────────────────────────────────────────
  void _fach(Canvas canvas, double p) {
    final rahmen = _seg(p, 0, 0.34, Curves.easeOutBack);
    final rollo = _seg(p, 0.22, 0.86, Curves.easeInOutCubic);
    final inhalt = _seg(p, 0.5, 1, Curves.easeOutCubic);
    _geraeteraum(canvas, rahmen: rahmen, rollo: rollo, inhalt: inhalt);
  }

  // ── Szene 2 · Geprüft ─────────────────────────────────────────────────────
  void _pruefen(Canvas canvas, double p) {
    // Das Fach steht offen und rückt ein wenig zurück — der Blick soll auf
    // das Abzeichen gehen.
    final zuruecktreten = _seg(p, 0.3, 0.9, Curves.easeInOutCubic);
    canvas.save();
    canvas.translate(_cx, 830);
    canvas.scale(1 - 0.06 * zuruecktreten);
    canvas.translate(-_cx, -830);
    _geraeteraum(canvas, rahmen: 1, rollo: 1, inhalt: 1);
    canvas.restore();

    final kommen = _seg(p, 0.08, 0.46, Curves.easeOutBack);
    final haken = _seg(p, 0.34, 0.78, Curves.easeOutCubic);
    if (kommen <= 0.001) return;

    final mitte = Offset(_cx + 232, 1052);
    final r = 132.0 * kommen;
    canvas.drawCircle(mitte, r + 26, Paint()..color = _rot);
    canvas.drawCircle(mitte, r, Paint()..color = _weiss..isAntiAlias = true);

    // Der Haken wächst von links nach rechts ein, statt einfach da zu sein.
    if (haken > 0.001) {
      canvas.save();
      canvas.translate(mitte.dx, mitte.dy);
      canvas.scale(kommen * 132 / kAbzeichenScheibe);
      canvas.translate(-kAbzeichenMitte.dx, -kAbzeichenMitte.dy);
      canvas.clipRect(Rect.fromLTWH(
          kAbzeichenMitte.dx - 140, kAbzeichenMitte.dy - 140,
          280 * haken, 280));
      canvas.drawPath(fwPfad(kHakenPfad), Paint()..color = _rot);
      canvas.restore();
    }
  }

  // ── Szene 3 · Das Zeichen ─────────────────────────────────────────────────
  void _zeichen(Canvas canvas, double p) {
    // Das Fach verschwindet, das Zeichen bleibt: Aus dem, was die App tut,
    // wird das, was sie ist.
    final gehen = _seg(p, 0, 0.26, Curves.easeInCubic);
    if (voll && gehen < 0.999) {
      canvas.saveLayer(
        null,
        Paint()..color = _weiss.withValues(alpha: 1 - gehen),
      );
      canvas.save();
      canvas.translate(_cx, 830);
      canvas.scale(0.94 + 0.06 * (1 - gehen));
      canvas.translate(-_cx, -830);
      _geraeteraum(canvas, rahmen: 1, rollo: 1, inhalt: 1);
      canvas.restore();
      canvas.restore();
    }

    // ⚠️ Dieselben Zeiten für volle Fassung und Kurzform. Die Kurzform IST
    // diese Szene, nur ohne Vorlauf — gäbe man ihr eigene Kurven, zeigte
    // sie an derselben Stelle etwas anderes. `fw_splash_test.dart` hält das
    // fest, und es hat mich hier erwischt.
    final kommen = _seg(p, 0.16, 0.56, Curves.easeOutBack);
    final setzen = _seg(p, 0.16, 0.56, Curves.easeInOutCubic);
    final wort = _seg(p, 0.56, 0.82, Curves.easeOutCubic);
    final unter = _seg(p, 0.68, 0.94, Curves.easeOutCubic);

    if (kommen > 0.001) {
      final breite = 560.0 * (0.62 + 0.38 * kommen);
      final hoehe = breite * kMarkeKasten.height / kMarkeKasten.width;
      final y = _cy - 120 * setzen;
      zeichneFwMarke(
        canvas,
        ziel: Rect.fromCenter(
            center: Offset(_cx, y), width: breite, height: hoehe),
        vordergrund: _weiss.withValues(alpha: kommen.clamp(0, 1)),
        grund: _rot,
      );
    }

    _zeile(
      canvas,
      text: 'FWApp',
      oben: 1230 + (30 - 30 * wort),
      groesse: 156,
      gewicht: FontWeight.w700,
      abstand: -3.12,
      farbe: _weiss.withValues(alpha: wort),
    );
    _zeile(
      canvas,
      text: 'FREIWILLIGE FEUERWEHR',
      oben: 1432 + (18 - 18 * unter),
      groesse: 48,
      gewicht: FontWeight.w500,
      abstand: 14.4,
      farbe: _weiss.withValues(alpha: 0.6 * unter),
    );
  }

  // ── Bausteine ─────────────────────────────────────────────────────────────

  void _grund(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kSplashW, kSplashH),
      Paint()..color = _rot,
    );
  }

  /// Der Geräteraum: Rahmen, hochfahrender Rollladen, Inhalt.
  ///
  /// [rollo] 0 = geschlossen, 1 = ganz oben. Der Inhalt liegt darunter und
  /// wird vom Rollladen verdeckt, solange es zu ist — deshalb wird im Fach
  /// beschnitten und nicht einfach übermalt.
  void _geraeteraum(
    Canvas canvas, {
    required double rahmen,
    required double rollo,
    required double inhalt,
  }) {
    if (rahmen <= 0.001) return;
    canvas.save();
    canvas.translate(_cx, 830);
    canvas.scale(0.82 + 0.18 * rahmen);
    canvas.translate(-_cx, -830);

    final weiss = Paint()..color = _weiss..isAntiAlias = true;
    final rot = Paint()..color = _rot..isAntiAlias = true;

    canvas.drawRRect(
        RRect.fromRectAndRadius(_fachAussen, const Radius.circular(44)),
        weiss);
    canvas.drawRRect(
        RRect.fromRectAndRadius(_fachInnen, const Radius.circular(26)), rot);

    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(_fachInnen, const Radius.circular(26)));

    // Inhalt: ein aufgerollter Schlauch, ein Strahlrohr und zwei Kupplungen
    // — genug, dass das Fach beladen aussieht und nicht wie eine Karte mit
    // zwei Strichen.
    if (inhalt > 0.001) {
      final auf = _weiss.withValues(alpha: inhalt);
      final voll = Paint()..color = auf..isAntiAlias = true;
      canvas.drawCircle(
        Offset(_fachInnen.left + 150, _fachInnen.bottom - 130),
        78,
        Paint()
          ..color = auf
          ..style = PaintingStyle.stroke
          ..strokeWidth = 58
          ..isAntiAlias = true,
      );
      for (final (dy, breite) in [(-250.0, 300.0), (-170.0, 224.0)]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(_fachInnen.left + 290,
                _fachInnen.bottom + dy, breite, 46),
            const Radius.circular(23),
          ),
          voll,
        );
      }
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
            Offset(_fachInnen.left + 320 + i * 96, _fachInnen.bottom - 76),
            34, voll);
      }
    }

    // Rollladen: Lamellen, die nach oben aus dem Fach fahren. Geschlossen
    // decken sie das Fach GANZ ab — sonst sieht der erste Augenblick nicht
    // nach einem geschlossenen Fach aus, sondern nach einer Karte mit
    // Streifen.
    final hub = (_fachInnen.height + 80) * rollo;
    const lamelle = 46.0, teilung = 64.0;
    final anzahl = (_fachInnen.height / teilung).ceil() + 1;
    for (var i = 0; i < anzahl; i++) {
      final y = _fachInnen.top + 14 + i * teilung - hub;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(_fachInnen.left + 24, y, _fachInnen.width - 48,
              lamelle),
          const Radius.circular(23),
        ),
        weiss,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  /// Eine mittige Textzeile; [oben] ist die Oberkante.
  void _zeile(
    Canvas canvas, {
    required String text,
    required double oben,
    required double groesse,
    required FontWeight gewicht,
    required double abstand,
    required Color farbe,
  }) {
    if (farbe.a < 0.004) return;
    final maler = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: groesse,
          fontWeight: gewicht,
          letterSpacing: abstand,
          color: farbe,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: kSplashW);
    maler.paint(canvas, Offset((kSplashW - maler.width) / 2, oben));
  }

  @override
  bool shouldRepaint(SplashPainter old) =>
      old.fortschritt != fortschritt || old.voll != voll;
}
