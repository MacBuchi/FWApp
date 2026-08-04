/// fw_splash.dart – Die Startanimation (Issue #129).
///
/// Übersetzung des Entwurfs „FWApp Splash" (splash-scenes.jsx): drei Szenen —
/// **Flamme** (1,2 s), **Löschen** (1,3 s), **Logo** (1,8 s) — zusammen 4,3 s.
/// Alle Koordinaten stehen im 1080×1920-Raum der Vorlage und werden am Stück
/// skaliert, damit beim nächsten Abgleich mit dem Entwurf jede Zahl
/// wiederfindbar bleibt.
///
/// Warum ein [CustomPainter] und nicht Transform/Opacity-Widgets, obwohl der
/// Entwurf ausdrücklich auf solche Primitive reduziert wurde: Der Painter ist
/// dieselbe Rechnung, aber prüfbar. Ein Widget-Baum lässt sich nur über
/// Transform-Werte abfragen, ein Painter über das Bild — und die Frage ist
/// „kommt die Szene auf die Leinwand", nicht „steht der richtige Wert im
/// Baum" (dieselbe Überlegung wie beim Avatar).
///
/// Die Schrift ist die des Systems, nicht Barlow: Eine Schriftart mitzuliefern
/// kostet Downloadgröße für 1,8 Sekunden Anzeige.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bühne der Vorlage.
const double kSplashW = 1080;
const double kSplashH = 1920;
const double _cx = 540;
const double _cy = 860;

const _bg = Color(0xFF150C0B);
const _rotHell = Color(0xFFE5453A);
const _rot = Color(0xFFC62828);
const _rotDunkel = Color(0xFF8E1613);
const _feuer = Color(0xFFF2762A);
const _wasser = Color(0xEBC6E4FF); // rgba(198,228,255,0.92)

/// Szenendauern in Millisekunden — die Zahlen aus `OM_SCENES`.
const int kFlammeMs = 1200;
const int kLoeschenMs = 1300;
const int kLogoMs = 1800;
const int kSplashVollMs = kFlammeMs + kLoeschenMs + kLogoMs;

/// Die Kurzform: nur die Logo-Szene.
///
/// Wer die App im Gerätehaus zweimal öffnet, soll nicht zweimal 4,3 Sekunden
/// zusehen — die volle Fassung läuft nur nach Installation und Update.
const int kSplashKurzMs = 600;

/// Abschnitt einer Szene: [p] auf [a]..[b] abbilden und mit [kurve] beugen.
double _seg(double p, double a, double b, Curve kurve) =>
    kurve.transform(((p - a) / (b - a)).clamp(0.0, 1.0));

/// Auf- und wieder abschwellend (die `env`-Hilfsfunktion des Entwurfs).
double _env(double p) => math.sin(math.pi * p.clamp(0.0, 1.0));

/// Stützstellen-Interpolation wie `interpolate([…],[…])` im Entwurf.
double _keyframes(double p, List<double> stellen, List<double> werte,
    Curve kurve) {
  if (p <= stellen.first) return werte.first;
  if (p >= stellen.last) return werte.last;
  for (var i = 0; i < stellen.length - 1; i++) {
    if (p <= stellen[i + 1]) {
      final lokal = (p - stellen[i]) / (stellen[i + 1] - stellen[i]);
      return werte[i] + (werte[i + 1] - werte[i]) * kurve.transform(lokal);
    }
  }
  return werte.last;
}

/// Die Startanimation als Bild zum Zeitpunkt [fortschritt] (0..1).
class SplashPainter extends CustomPainter {
  SplashPainter({required this.fortschritt, required this.voll});

  /// 0..1 über die GESAMTE Laufzeit — welche Szene das ist, rechnet der
  /// Painter selbst aus.
  final double fortschritt;

  /// Volle Fassung (drei Szenen) oder Kurzform (nur Logo).
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

    final p = fortschritt.clamp(0.0, 1.0);
    if (!voll) {
      _logo(canvas, p);
    } else {
      final ms = p * kSplashVollMs;
      if (ms < kFlammeMs) {
        _flamme(canvas, ms / kFlammeMs);
      } else if (ms < kFlammeMs + kLoeschenMs) {
        _loeschen(canvas, (ms - kFlammeMs) / kLoeschenMs);
      } else {
        _logo(canvas, (ms - kFlammeMs - kLoeschenMs) / kLogoMs);
      }
    }
    canvas.restore();
  }

  // ── Szene 1 · Flamme ──────────────────────────────────────────────────────
  void _flamme(Canvas canvas, double p) {
    final wachsen = _seg(p, 0, 0.4, Curves.easeOutBack);
    final atmen = 1 + 0.02 * _env(p);
    _buehne(canvas, 0.3 + 0.7 * wachsen);
    _marke(canvas,
        groesse: 520,
        farbe: _feuer,
        y: _cy,
        skalierung: (0.62 + 0.38 * wachsen) * atmen);
  }

  // ── Szene 2 · Löschen ─────────────────────────────────────────────────────
  void _loeschen(Canvas canvas, double p) {
    final strahl = _seg(p, 0.06, 0.42, Curves.easeInOutCubic);
    final strahlAlpha = _keyframes(
        p, [0.02, 0.14, 0.52, 0.7], [0, 1, 1, 0], Curves.easeInOutQuad);
    final kuehlen = _seg(p, 0.36, 0.66, Curves.easeInOutCubic);
    final treffer = _env(_seg(p, 0.32, 0.7, Curves.linear));
    final ring = _seg(p, 0.4, 0.9, Curves.easeOutCubic);

    _buehne(canvas, 0.3 + 0.7 * (1 - kuehlen));

    // Der Strahl: ein Balken, der aus seinem linken Ende herauswächst.
    if (strahlAlpha > 0.001 && strahl > 0.001) {
      canvas.save();
      canvas.translate(118, 1318); // transform-origin: 0% 50%
      canvas.rotate(-41 * math.pi / 180);
      canvas.scale(strahl, 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, -12, 500, 24),
          const Radius.circular(12),
        ),
        Paint()
          ..color = _wasser.withValues(alpha: _wasser.a * strahlAlpha)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }

    // Der Ring der Wucht.
    final ringAlpha = 0.45 * _env(ring);
    if (ringAlpha > 0.001) {
      canvas.save();
      canvas.translate(_cx, _cy);
      canvas.scale(0.25 + 0.75 * ring);
      canvas.drawCircle(
        Offset.zero,
        300,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0xFFE8F2F8).withValues(alpha: ringAlpha)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }

    final zucken = 1 - 0.06 * treffer;
    _marke(canvas, groesse: 520, farbe: _feuer, y: _cy, skalierung: zucken);
    if (kuehlen > 0.001) {
      _marke(canvas,
          groesse: 520,
          farbe: Colors.white.withValues(alpha: kuehlen),
          y: _cy,
          skalierung: zucken);
    }
  }

  // ── Szene 3 · Logo ────────────────────────────────────────────────────────
  void _logo(Canvas canvas, double p) {
    final platte = _seg(p, 0.04, 0.44, Curves.easeOutBack);
    final setzen = _seg(p, 0.04, 0.44, Curves.easeInOutCubic);
    final y = _cy - 130 * setzen;
    final wort = _seg(p, 0.46, 0.76, Curves.easeOutCubic);
    final unter = _seg(p, 0.6, 0.9, Curves.easeOutCubic);

    _buehne(canvas, 0.3 + 0.25 * setzen);

    if (platte > 0.001) {
      canvas.save();
      canvas.translate(_cx, y);
      canvas.scale(0.4 + 0.6 * platte);
      const r = Rect.fromLTWH(-220, -220, 440, 440);
      final form = RRect.fromRectAndRadius(r, const Radius.circular(104));
      // Der Schlagschatten trägt die Platte — ohne ihn klebt sie flach auf
      // dem Hintergrund.
      canvas.drawRRect(
        form.shift(const Offset(0, 26)),
        Paint()
          ..color = _rot.withValues(alpha: 0.34 * platte)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
      canvas.drawRRect(
        form,
        Paint()
          ..shader = const LinearGradient(
            // 160° in CSS misst von „nach oben" im Uhrzeigersinn; das ist
            // ungefähr von oben links nach unten rechts.
            begin: Alignment(-0.34, -0.94),
            end: Alignment(0.34, 0.94),
            colors: [_rotHell, _rot, _rotDunkel],
            stops: [0, 0.58, 1],
          ).createShader(r)
          ..color = Colors.white.withValues(alpha: platte)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }

    _marke(canvas,
        groesse: 520,
        farbe: Colors.white,
        y: y,
        skalierung: 1 - 0.46 * setzen);

    _zeile(
      canvas,
      text: 'FWApp',
      oben: 1230 + (30 - 30 * wort),
      groesse: 156,
      gewicht: FontWeight.w700,
      abstand: -3.12, // -0.02em
      farbe: Colors.white.withValues(alpha: wort),
    );
    _zeile(
      canvas,
      text: 'FREIWILLIGE FEUERWEHR',
      oben: 1432 + (18 - 18 * unter),
      groesse: 48,
      gewicht: FontWeight.w500,
      abstand: 14.4, // 0.3em
      farbe: Colors.white.withValues(alpha: 0.6 * unter),
    );
  }

  // ── Bausteine ─────────────────────────────────────────────────────────────

  /// Grundfläche plus ein warmer Schein dahinter.
  void _buehne(Canvas canvas, double waerme) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kSplashW, kSplashH),
      Paint()..color = _bg,
    );
    final deckkraft = 0.18 + 0.34 * waerme;
    final kreis = Rect.fromCircle(center: const Offset(_cx, _cy), radius: 700);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kSplashW, kSplashH),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _rot.withValues(alpha: deckkraft),
            _rotDunkel.withValues(alpha: 0),
          ],
          stops: const [0, 0.7],
        ).createShader(kreis),
    );
  }

  /// Die Flamme — dieselbe Glyphe, die auch Anmeldung und Startseite tragen.
  void _marke(
    Canvas canvas, {
    required double groesse,
    required Color farbe,
    required double y,
    required double skalierung,
  }) {
    const icon = Icons.local_fire_department;
    final maler = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: groesse,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: farbe,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(_cx, y);
    canvas.scale(skalierung);
    maler.paint(canvas, Offset(-maler.width / 2, -maler.height / 2));
    canvas.restore();
  }

  /// Eine mittige Textzeile; [oben] ist die Oberkante wie im Entwurf.
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
