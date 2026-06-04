import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pin central du funnel (mode Course) : un petit bonhomme bleu posé en
/// permanence au centre de la zone visible de la carte. La carte glisse
/// dessous, **la pointe de l'aiguille = le point GPS visé** (le widget est
/// dimensionné pour que la pointe tombe exactement au centre du parent via
/// `Center`). Quand l'utilisateur attrape la carte ([grabbed]), la souris
/// « prend la main » du bonhomme : le bras se lève et le corps se soulève ;
/// au relâchement le bras redescend. Hors zone couverte ([covered] = false),
/// le bonhomme est désaturé et une chip « Zone non desservie » s'affiche.
///
/// À envelopper d'`IgnorePointer` côté appelant : il ne doit jamais
/// intercepter les gestes de la carte.
class CenterPin extends StatefulWidget {
  /// L'utilisateur tient la carte (pointer down) : bras levé, corps soulevé.
  final bool grabbed;

  /// Le point sous le pin est dans une geozone couverte.
  final bool covered;

  const CenterPin({super.key, required this.grabbed, required this.covered});

  @override
  State<CenterPin> createState() => _CenterPinState();
}

class _CenterPinState extends State<CenterPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  // Géométrie : figure+aiguille dans une boîte 56×88, pointe à (28, 86) —
  // marge en haut pour le bras levé. La boîte totale fait 2×88 de haut pour
  // que `Center` aligne la pointe (y=88 = milieu vertical) sur le centre
  // exact de la carte.
  static const double _w = 168;
  static const double _h = 176;
  static const double _figureW = 56;
  static const double _figureH = 88;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.grabbed ? 1 : 0,
    );
    // Lever de bras tonique (léger overshoot), redescente plus douce.
    _t = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant CenterPin old) {
    super.didUpdateWidget(old);
    if (widget.grabbed != old.grabbed) {
      widget.grabbed ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _w,
      height: _h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) => CustomPaint(
                size: const Size(_figureW, _figureH),
                painter: _BonhommePainter(
                  t: _t.value,
                  covered: widget.covered,
                ),
              ),
            ),
          ),
          // Chip « zone non desservie », sous la pointe (n'occulte pas le point).
          if (!widget.covered)
            Positioned(
              top: _figureH + 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: const Color(0xFFFF5357).withValues(alpha: 0.35)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 8),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.do_not_disturb_on_outlined,
                        size: 14, color: Color(0xFFFF5357)),
                    SizedBox(width: 5),
                    Text(
                      'Zone non desservie',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: Color(0xFFFF5357),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dessine le bonhomme « map person » Misy (référence : pictogramme bleu
/// clair — tête ronde détachée + buste monobloc dont l'encoche du bas forme
/// les deux jambes), cerclé de blanc pour la lisibilité sur la carte, +
/// l'aiguille ancrée au point GPS. [t] ∈ 0..1 pilote la posture : 0 = posé
/// bien droit, 1 = attrapé (un bras surgit et se tend vers le curseur, le
/// corps se soulève de l'aiguille et s'incline).
class _BonhommePainter extends CustomPainter {
  final double t;
  final bool covered;

  _BonhommePainter({required this.t, required this.covered});

  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueDark = Color(0xFF1D4FD7);
  static const Color _grey = Color(0xFF9CA3AF);
  static const Color _greyDark = Color(0xFF8B93A1);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; // 24
    final tip = Offset(cx, size.height - 2); // pointe = point GPS
    final color = covered ? _blue : _grey;
    final colorDark = covered ? _blueDark : _greyDark;

    Paint stroke(double w, Color c) => Paint()
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    final white = Paint()..color = Colors.white;
    final whiteStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // --- Ombre au sol : s'écrase quand le bonhomme se soulève.
    canvas.drawOval(
      Rect.fromCenter(center: tip, width: 15.0 - 6.0 * t, height: 4),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    // --- Aiguille fixe (le point visé ne bouge jamais).
    canvas.drawLine(Offset(cx, 63), tip, stroke(4.4, Colors.white));
    canvas.drawLine(Offset(cx, 63), tip, stroke(2.0, colorDark));
    canvas.drawCircle(tip, 2.8, white);
    canvas.drawCircle(tip, 1.7, Paint()..color = colorDark);

    // --- Figure : soulevée et inclinée pendant la prise (pivot aux pieds).
    canvas.save();
    canvas.translate(cx, 62);
    canvas.translate(0, -3.5 * t);
    canvas.rotate(-5 * math.pi / 180 * t);
    canvas.translate(-cx, -62);

    // Tête ronde détachée (gap blanc avec le buste, comme la référence).
    final head = Offset(cx, 18);
    const headR = 5.0;

    // Buste monobloc d'un seul tenant (pied unique, comme la référence) :
    // coins hauts arrondis, base légèrement arrondie.
    final silhouette = Path()
      ..addRRect(RRect.fromLTRBAndCorners(
        cx - 9, 25, cx + 9, 62,
        topLeft: const Radius.circular(4.5),
        topRight: const Radius.circular(4.5),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      ));

    // Bras « attrapé » : surgit de l'épaule droite et se tend en diagonale
    // haut-droite, dans l'espace libre à droite de la tête (jamais en
    // travers — lisibilité à 28 px). Dessiné sous le buste pour paraître
    // émerger de derrière l'épaule.
    final hand = Offset(_lerp(cx + 8, cx + 16, t), _lerp(31, 11, t));
    if (t > 0.05) {
      final shoulder = Offset(cx + 6.5, 29);
      canvas.drawLine(shoulder, hand, stroke(7.2, Colors.white));
      canvas.drawLine(shoulder, hand, stroke(5.2, color));
    }

    // Halo blanc puis silhouette pleine.
    canvas.drawPath(silhouette, whiteStroke);
    canvas.drawPath(silhouette, fill);
    canvas.drawCircle(head, headR + 1.5, white);
    canvas.drawCircle(head, headR, fill);

    // Main « attrapée » au bout du bras, cible du curseur.
    if (t > 0.05) {
      canvas.drawCircle(hand, 3.3 * t, white);
      canvas.drawCircle(hand, 2.2 * t, fill);
    }

    canvas.restore();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_BonhommePainter old) =>
      old.t != t || old.covered != covered;
}
