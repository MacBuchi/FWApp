/// splash_gate.dart – Die Startanimation vor die App legen (Issue #129).
///
/// Drei Festlegungen, die den Rest erklären:
///
/// 1. **Die Animation hält die App nicht auf.** Sie liegt ÜBER der App, die
///    darunter schon baut, seedet und zieht. Wäre sie ein eigener Bildschirm,
///    den die App erst ablösen darf, hätte man 4,3 Sekunden Startzeit
///    dazugekauft — für eine Verzierung.
///
/// 2. **Die volle Fassung läuft nur nach Installation und Update.** Wer die
///    App im Gerätehaus zweimal öffnet, sieht beim zweiten Mal die Kurzform.
///    Entschieden wird das in `main()`, weil dort die Version ohnehin
///    feststeht.
///
/// 3. **Antippen bricht ab.** Wer hinein will, kommt hinein. Eine Animation,
///    die man nicht überspringen kann, ist im Einsatzfall eine Zumutung.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/features/splash/presentation/widgets/fw_splash.dart';

/// Schlüssel des Merkers „diese Version wurde schon begrüßt".
const kSplashVersionPref = 'splash_gesehen_version';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child, required this.voll});

  final Widget child;

  /// Volle Fassung (drei Szenen, 4,3 s) statt Kurzform (Logo, 0,6 s).
  final bool voll;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

/// ⚠️ `TickerProviderStateMixin`, NICHT die Single-Variante: Hier laufen
/// zwei Controller (Ablauf und Ausblenden). Die Single-Fassung merkt das nur
/// per `assert` — im Release-Build wäre es stillschweigend falsch, und genau
/// deshalb hat es der Durchklick im Browser nicht gezeigt, der Widget-Test
/// aber sofort.
class _SplashGateState extends State<SplashGate>
    with TickerProviderStateMixin {
  late final AnimationController _lauf;
  late final AnimationController _blende;

  /// Erst wenn beides durch ist, verschwindet die Bühne aus dem Baum — bis
  /// dahin fängt sie jeden Tipp ab, damit niemand blind in die App darunter
  /// greift.
  bool _fertig = false;

  /// Steht erst nach dem ersten `build` fest (MediaQuery).
  bool? _voll;

  @override
  void initState() {
    super.initState();
    _lauf = AnimationController(vsync: this);
    _blende = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_voll != null) return;
    // Bewegungsreduzierung überstimmt alles: Wer sie eingeschaltet hat, will
    // keine 4,3 Sekunden Animation, sondern in die App.
    final ruhig = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final voll = widget.voll && !ruhig;
    _voll = voll;
    _lauf
      ..duration = Duration(milliseconds: voll ? kSplashVollMs : kSplashKurzMs)
      ..forward().whenComplete(_ausblenden);
  }

  void _ausblenden() {
    if (!mounted || _fertig) return;
    _blende.forward().whenComplete(() {
      if (mounted) setState(() => _fertig = true);
    });
  }

  @override
  void dispose() {
    _lauf.dispose();
    _blende.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fertig) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            onTap: _ausblenden,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: Listenable.merge([_lauf, _blende]),
              builder: (_, _) => Opacity(
                opacity: 1 - _blende.value,
                child: CustomPaint(
                  painter: SplashPainter(
                    fortschritt: _lauf.value,
                    voll: _voll ?? widget.voll,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
