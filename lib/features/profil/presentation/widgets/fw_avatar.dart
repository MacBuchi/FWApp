/// fw_avatar.dart – Der Feuerwehr-Avatar, gezeichnet (Issue #100).
///
/// Eins-zu-eins-Übersetzung der SVG-Vorlage „FWAvatar" aus dem Entwurf in
/// einen [CustomPainter]. Alle Koordinaten stehen im 200×200-Raum der
/// Vorlage und werden am Stück skaliert — so bleibt beim nächsten Abgleich
/// mit dem Entwurf jede Zahl wiederfindbar. Wer hier etwas verschiebt,
/// verschiebt es gegenüber dem Entwurf.
///
/// Warum ein Painter und kein SVG-Paket: Der Kopf ist parametrisiert (acht
/// Werte), ein SVG wäre also ohnehin zur Laufzeit zusammenzusetzen — und
/// eine Abhängigkeit mehr für Formen, die Canvas von Haus aus kann.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/features/profil/domain/avatar_konfiguration.dart';

/// Zeichnet [konfiguration] als runden Kopf mit Kantenlänge [groesse].
class FwAvatar extends StatelessWidget {
  const FwAvatar({
    super.key,
    required this.konfiguration,
    this.groesse = 40,
    this.semantikLabel,
  });

  final AvatarKonfiguration konfiguration;
  final double groesse;

  /// Beschriftung für Screenreader. Ohne Angabe bleibt der Kopf stumm — er
  /// steht überall neben dem Namen, und „Avatar" zweimal vorzulesen hilft
  /// niemandem.
  final String? semantikLabel;

  @override
  Widget build(BuildContext context) {
    final bild = SizedBox.square(
      dimension: groesse,
      child: CustomPaint(painter: AvatarPainter(konfiguration)),
    );
    return semantikLabel == null
        ? ExcludeSemantics(child: bild)
        : Semantics(label: semantikLabel, image: true, child: bild);
  }
}

/// Der eigentliche Zeichner. Öffentlich, damit Tests direkt auf ihn malen
/// können, ohne ein Widget aufzubauen.
class AvatarPainter extends CustomPainter {
  AvatarPainter(this.k);

  final AvatarKonfiguration k;

  // Feste Farben der Vorlage, die kein Bedienelement bekommen: Die Jacke
  // ist bei jeder Wehr dunkelblau, Flasche und Visier gehören zum
  // Atemschutz-Bild und nicht zur Person.
  static const _jacke = Color(0xFF25333D);
  static const _flasche = Color(0xFFE8B33C);
  static const _visierTon = Color(0xFFBBD9EA);
  static const _augenTinte = Color(0xFF2B2320);
  static const _mundTinte = Color(0xFF3A2320);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200);
    // Ohne diesen Schnitt steht die Atemschutzflasche über den Rand hinaus:
    // Sie reicht bis y=202 und x=8, der Kreis nicht. Im Entwurf schneidet
    // das umgebende `border-radius: 50%; overflow: hidden` ab.
    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: const Offset(100, 100), radius: 100),
        ),
    );

    final hautSchatten = _dunkler(k.skin, 0.12);
    final helmDunkel = _dunkler(k.gearColor, 0.28);

    final hatHelm = k.gear == 'helmet' ||
        k.gear == 'visor' ||
        k.gear == 'scba' ||
        k.gear == 'dog';

    canvas.drawCircle(const Offset(100, 100), 100, _fuellung(k.bg));
    canvas.drawCircle(
      const Offset(100, 100),
      99,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF000000).withValues(alpha: 0.10)
        ..isAntiAlias = true,
    );

    if (k.gear == 'scba') _flascheZeichnen(canvas);

    // Jacke, Reflexstreifen, Hals, Ohren, Gesicht.
    canvas.drawPath(
      Path()
        ..moveTo(24, 200)
        ..quadraticBezierTo(100, 150, 176, 200)
        ..close(),
      _fuellung(_jacke),
    );
    canvas.drawRect(
      const Rect.fromLTWH(24, 184, 152, 7),
      _fuellung(const Color(0xFFFFD84D), 0.9),
    );
    canvas.drawRect(
      const Rect.fromLTWH(88, 138, 24, 30),
      _fuellung(hautSchatten),
    );
    canvas.drawCircle(const Offset(57, 108), 9, _fuellung(hautSchatten));
    canvas.drawCircle(const Offset(143, 108), 9, _fuellung(hautSchatten));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 104), width: 84, height: 90),
      _fuellung(k.skin),
    );

    if (k.gear == 'dog') _hundZeichnen(canvas);
    _bartZeichnen(canvas);
    _augenZeichnen(canvas);
    _mundZeichnen(canvas);
    if (k.gear == 'scba') _maskeZeichnen(canvas);
    if (k.gear == 'visor') _visierZeichnen(canvas);
    if (hatHelm) _helmZeichnen(canvas, helmDunkel);
    if (k.gear == 'cap') _kaeppiZeichnen(canvas, helmDunkel);

    canvas.restore();
  }

  // ── Bausteine ─────────────────────────────────────────────────────────────

  void _flascheZeichnen(Canvas canvas) {
    final dunkel = _dunkler(_flasche, 0.3);
    canvas.drawRRect(
      RRect.fromLTRBR(8, 106, 48, 202, const Radius.circular(20)),
      _fuellung(dunkel),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(10, 104, 46, 198, const Radius.circular(18)),
      _fuellung(_flasche),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(16, 118, 22, 178, const Radius.circular(3)),
      _fuellung(const Color(0xFFFFFFFF), 0.28),
    );
    canvas.drawRect(
      const Rect.fromLTWH(13, 140, 30, 8),
      _fuellung(const Color(0xFFFFFFFF), 0.5),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(22, 94, 34, 108, const Radius.circular(4)),
      _fuellung(const Color(0xFF3B4650)),
    );
    canvas.drawCircle(
        const Offset(28, 94), 8, _fuellung(const Color(0xFF6B7A85)));
    canvas.drawCircle(
        const Offset(28, 94), 3, _fuellung(const Color(0xFF2E353B)));
  }

  void _hundZeichnen(Canvas canvas) {
    void ohr(double cx) => canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, 112), width: 30, height: 60),
          _fuellung(k.hairColor),
        );
    ohr(52);
    ohr(148);
    canvas.drawCircle(const Offset(74, 80), 13, _fuellung(k.hairColor, 0.9));
    canvas.drawCircle(const Offset(126, 128), 9, _fuellung(k.hairColor, 0.75));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 126), width: 52, height: 40),
      _fuellung(const Color(0xFFFFF3E6)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 116), width: 18, height: 14),
      _fuellung(const Color(0xFF2B2320)),
    );
  }

  void _bartZeichnen(Canvas canvas) {
    switch (k.hair) {
      case 'beard':
        canvas.drawPath(
          Path()
            ..moveTo(58, 104)
            ..relativeQuadraticBezierTo(2, 56, 42, 56)
            ..relativeQuadraticBezierTo(40, 0, 42, -56)
            ..relativeQuadraticBezierTo(-12, 28, -42, 28)
            ..relativeQuadraticBezierTo(-30, 0, -42, -28)
            ..close(),
          _fuellung(k.hairColor),
        );
      case 'stubble':
        canvas.drawPath(
          Path()
            ..moveTo(60, 108)
            ..relativeQuadraticBezierTo(4, 50, 40, 50)
            ..relativeQuadraticBezierTo(36, 0, 40, -50)
            ..relativeQuadraticBezierTo(-12, 24, -40, 24)
            ..relativeQuadraticBezierTo(-28, 0, -40, -24)
            ..close(),
          _fuellung(k.hairColor, 0.26),
        );
      case 'mustache':
        for (final cx in const [89.0, 111.0]) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, 118), width: 24, height: 12),
            _fuellung(k.hairColor),
          );
        }
      case 'walrus':
        canvas.drawPath(
          Path()
            ..moveTo(70, 112)
            ..relativeQuadraticBezierTo(30, -8, 60, 0)
            ..relativeQuadraticBezierTo(2, 18, -14, 16)
            ..relativeQuadraticBezierTo(-16, -2, -16, -8)
            ..relativeQuadraticBezierTo(0, 6, -16, 8)
            ..relativeQuadraticBezierTo(-16, 2, -14, -16)
            ..close(),
          _fuellung(k.hairColor),
        );
    }
  }

  void _augenZeichnen(Canvas canvas) {
    final strich = _strich(_augenTinte, 5);
    Path bogen(double x) => Path()
      ..moveTo(x, 102)
      ..relativeQuadraticBezierTo(8, -11, 16, 0);
    Path linie(double x) => Path()
      ..moveTo(x, 101)
      ..relativeLineTo(17, 0);

    switch (k.eyes) {
      case 'happy':
        canvas.drawPath(bogen(76), strich);
        canvas.drawPath(bogen(108), strich);
      case 'wide':
        for (final cx in const [84.0, 116.0]) {
          canvas.drawCircle(
              Offset(cx, 100), 10, _fuellung(const Color(0xFFFFFFFF)));
        }
        for (final cx in const [85.0, 117.0]) {
          canvas.drawCircle(Offset(cx, 101), 5, _fuellung(_augenTinte));
        }
      case 'squint':
        canvas.drawPath(linie(76), strich);
        canvas.drawPath(linie(107), strich);
      case 'wink':
        canvas.drawPath(bogen(76), strich);
        canvas.drawPath(linie(107), strich);
      case 'dots':
        canvas.drawCircle(const Offset(86, 98), 6, _fuellung(_augenTinte));
        canvas.drawCircle(const Offset(114, 98), 6, _fuellung(_augenTinte));
      case 'shades':
        canvas.drawRRect(
          RRect.fromLTRBR(66, 88, 134, 110, const Radius.circular(9)),
          _fuellung(const Color(0xFF1B1B1F)),
        );
        canvas.drawRect(
          const Rect.fromLTWH(66, 92, 68, 4),
          _fuellung(const Color(0xFFFFFFFF), 0.22),
        );
    }
  }

  void _mundZeichnen(Canvas canvas) {
    final strich = _strich(_mundTinte, 5);
    switch (k.mouth) {
      case 'grin':
        canvas.drawPath(
          Path()
            ..moveTo(82, 120)
            ..relativeQuadraticBezierTo(18, 17, 36, 0),
          strich,
        );
      case 'smirk':
        canvas.drawPath(
          Path()
            ..moveTo(84, 124)
            ..relativeQuadraticBezierTo(18, 8, 32, -6),
          strich,
        );
      case 'laugh':
        canvas.drawPath(
          Path()
            ..moveTo(78, 116)
            ..relativeQuadraticBezierTo(22, 28, 44, 0)
            ..close(),
          _fuellung(_mundTinte),
        );
        canvas.drawRect(
          const Rect.fromLTWH(80, 117, 40, 5),
          _fuellung(const Color(0xFFFFFFFF)),
        );
      case 'whistle':
        canvas.drawCircle(const Offset(100, 124), 8, _fuellung(_mundTinte));
      case 'tongue':
        canvas.drawPath(
          Path()
            ..moveTo(80, 118)
            ..relativeQuadraticBezierTo(20, 20, 40, 0)
            ..close(),
          _fuellung(_mundTinte),
        );
        canvas.drawRRect(
          RRect.fromLTRBR(92, 128, 109, 142, const Radius.circular(8)),
          _fuellung(const Color(0xFFE2707A)),
        );
    }
  }

  void _maskeZeichnen(Canvas canvas) {
    final band = _strich(const Color(0xFF2E353B), 9);
    canvas.drawPath(Path()..moveTo(52, 92)..relativeLineTo(-20, 0), band);
    canvas.drawPath(Path()..moveTo(148, 92)..relativeLineTo(20, 0), band);
    canvas.drawRRect(
      RRect.fromLTRBR(54, 74, 146, 152, const Radius.circular(34)),
      _fuellung(const Color(0xFF2E353B)),
    );
    final scheibe = RRect.fromLTRBR(62, 82, 138, 128, const Radius.circular(21));
    canvas.drawRRect(scheibe, _fuellung(const Color(0xFFFFFFFF), 0.58));
    canvas.drawRRect(scheibe, _fuellung(_visierTon, 0.5));
    canvas.drawRRect(
      scheibe,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF7E8F9B)
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      Path()
        ..moveTo(72, 92)
        ..relativeQuadraticBezierTo(12, -7, 24, -3)
        ..relativeLineTo(-9, 9)
        ..relativeQuadraticBezierTo(-10, -2, -15, -6)
        ..close(),
      _fuellung(const Color(0xFFFFFFFF), 0.55),
    );
    canvas.drawCircle(
        const Offset(100, 136), 14, _fuellung(const Color(0xFF4A555E)));
    canvas.drawCircle(
        const Offset(100, 136), 7, _fuellung(const Color(0xFF20262B)));
    canvas.drawPath(
      Path()
        ..moveTo(86, 142)
        ..relativeQuadraticBezierTo(-30, 18, -48, -28),
      _strich(const Color(0xFF3B4650), 9),
    );
  }

  void _visierZeichnen(Canvas canvas) {
    final scheibe = RRect.fromLTRBR(54, 82, 146, 112, const Radius.circular(12));
    canvas.drawRRect(scheibe, _fuellung(const Color(0xFFA8CFE4), 0.55));
    canvas.drawRRect(
      scheibe,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF7E9EB2)
        ..isAntiAlias = true,
    );
  }

  void _helmZeichnen(Canvas canvas, Color dunkel) {
    canvas.drawPath(
      Path()
        ..moveTo(64, 78)
        ..arcToPoint(const Offset(136, 78),
            radius: const Radius.elliptical(38, 44))
        ..close(),
      _fuellung(k.gearColor),
    );
    canvas.drawPath(
      Path()
        ..moveTo(76, 44)
        ..relativeQuadraticBezierTo(24, -10, 48, 6)
        ..relativeQuadraticBezierTo(-24, -4, -48, -6)
        ..close(),
      _fuellung(const Color(0xFFFFFFFF), 0.18),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 80), width: 122, height: 22),
      _fuellung(dunkel),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 77), width: 122, height: 20),
      _fuellung(k.gearColor),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(86, 60, 114, 71, const Radius.circular(4)),
      _fuellung(const Color(0xFFFFFFFF), 0.88),
    );
  }

  void _kaeppiZeichnen(Canvas canvas, Color dunkel) {
    canvas.drawPath(
      Path()
        ..moveTo(66, 76)
        ..arcToPoint(const Offset(134, 76),
            radius: const Radius.elliptical(36, 38))
        ..close(),
      _fuellung(k.gearColor),
    );
    canvas.drawPath(
      Path()
        ..moveTo(66, 76)
        ..relativeQuadraticBezierTo(34, 8, 68, 0)
        ..relativeQuadraticBezierTo(20, 2, 22, 10)
        ..relativeQuadraticBezierTo(-46, 8, -90, 0)
        ..close(),
      _fuellung(dunkel),
    );
    canvas.drawCircle(const Offset(100, 42), 5, _fuellung(dunkel));
  }

  // ── Werkzeug ──────────────────────────────────────────────────────────────

  Paint _fuellung(Color c, [double deckkraft = 1]) => Paint()
    ..color = deckkraft == 1 ? c : c.withValues(alpha: deckkraft)
    ..isAntiAlias = true;

  Paint _strich(Color c, double breite) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = breite
    ..strokeCap = StrokeCap.round
    ..color = c
    ..isAntiAlias = true;

  /// Dieselbe Abdunklung wie im Entwurf (`shade(hex, -f)`): jeder Kanal mal
  /// `1 - f`. Helm und Flasche brauchen einen Schatten, der zur gewählten
  /// Farbe passt — eine feste graue Kante sieht bei Weiß und Rot gleich
  /// falsch aus.
  static Color _dunkler(Color c, double f) => Color.fromARGB(
        255,
        ((c.toARGB32() >> 16 & 0xFF) * (1 - f)).round(),
        ((c.toARGB32() >> 8 & 0xFF) * (1 - f)).round(),
        ((c.toARGB32() & 0xFF) * (1 - f)).round(),
      );

  @override
  bool shouldRepaint(AvatarPainter old) => old.k != k;
}
