import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/models/schematic_plan.dart';
import 'package:rider_ride_hailing_app/widget/transport/schematic_geom.dart';
import 'package:rider_ride_hailing_app/widget/transport/schematic_label_layout.dart';

/// Painter du plan schématique en SYMBOLOGIE CTS (Strasbourg) — derrière
/// `--dart-define=SCHEMATIC_CTS=true`. L'ancien `_SchematicPainter` reste
/// le fallback intact.
///
/// Alphabet (validé 05/06/2026) :
/// - rubans colorés par ligne + CASING blanc global du faisceau ;
/// - épaisseur ∝ densité du corridor (nb de lignes du tronçon, borné) —
///   troncs épais, antennes fines ;
/// - tier 1 (train/téléphérique) : style « voie ferrée » (trait +
///   traverses blanches perpendiculaires) ;
/// - arrêt simple = tiret blanc en travers ; correspondance = pastille
///   blanche cerclée ; terminus = capsule orientée ; pôle = double anneau ;
/// - pastilles de numéro de ligne le long des antennes + aux terminus ;
/// - coins arrondis aux coudes (cf. [SchematicGeom.roundedPolylinePath]) ;
/// - fond crème, eau bleu clair ; labels = [PlacedLabel] pré-calculés par
///   [SchematicLabelLayout] (mémoïsés par palier de zoom dans le state).
class SchematicPainterCts extends CustomPainter {
  final SchematicPlan plan;
  final CtsGeomCache geom;
  final List<PlacedLabel> placedLabels;
  final Map<String, TextPainter> labelCache;
  final double scale;
  final Offset offset;
  final Size viewport;
  final bool showCentreRect;
  final String centreLabel;

  SchematicPainterCts({
    required this.plan,
    required this.geom,
    required this.placedLabels,
    required this.labelCache,
    required this.scale,
    required this.offset,
    required this.viewport,
    required this.showCentreRect,
    required this.centreLabel,
  });

  // ---- constantes ÉCRAN (jamais × scale) ----
  static const Color _bg = Color(0xFFFBF8F2); // crème
  static const Color _navy = Color(0xFF1D3557);
  static const Color _waterColor = Color(0xFF9FC7E8);
  static const Color _waterFill = Color(0x559FC7E8);
  static const double _casingPx = 1.6; // bord blanc de chaque côté
  static const double _cornerR = 6.0;  // rayon des coudes arrondis
  static const double _chipEveryPx = 170.0; // intervalle pastilles numéro

  Offset _s(Offset p) => p * scale + offset;

  /// Épaisseur de brin ∝ densité du corridor (antenne fine → tronc épais).
  double _strandW(SchEdge e) {
    if (geom.nMax <= 1) return 2.4;
    final t = ((e.lines.length - 1) / (geom.nMax - 1)).clamp(0.0, 1.0);
    return 2.2 + 1.3 * t;
  }

  double _spacing(SchEdge e) => _strandW(e) + 0.7;

  /// Demi-largeur totale du faisceau (brins + casing).
  double _bundleHalf(SchEdge e) {
    final n = e.lines.length;
    return ((n - 1) * _spacing(e) + _strandW(e)) / 2 + _casingPx;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vp = Offset.zero & viewport;
    canvas.drawRect(vp, Paint()..color = _bg);

    _paintWater(canvas);

    // Casing blanc global PUIS rubans, tiers 2/3 d'abord, tier 1 au-dessus.
    final screenEdges = <(SchEdge, List<Offset>)>[];
    for (final e in plan.edges) {
      final sp = e.pts.map(_s).toList();
      if (!SchematicGeom.visible(sp, vp)) continue;
      screenEdges.add((e, sp));
    }
    for (final (e, sp) in screenEdges) {
      _paintCasing(canvas, e, sp);
    }
    for (final tier1 in [false, true]) {
      for (final (e, sp) in screenEdges) {
        _paintStrands(canvas, e, sp, tier1: tier1);
      }
    }

    _paintStations(canvas, vp);
    _paintChips(canvas, vp, screenEdges);
    _paintContinuations(canvas, vp);
    _paintLabels(canvas, vp);
    if (showCentreRect && plan.centreRect != null) _paintCentreRect(canvas);
  }

  // ---- tracés ----

  void _paintCasing(Canvas canvas, SchEdge e, List<Offset> sp) {
    canvas.drawPath(
      SchematicGeom.roundedPolylinePath(sp, _cornerR),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = _bundleHalf(e) * 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintStrands(Canvas canvas, SchEdge e, List<Offset> sp,
      {required bool tier1}) {
    final n = e.lines.length;
    final w = _strandW(e);
    final spacing = _spacing(e);
    for (var i = 0; i < n; i++) {
      final ln = e.lines[i];
      if ((ln.tier == 1) != tier1) continue;
      final off = (i - (n - 1) / 2.0) * spacing;
      final poly = SchematicGeom.offsetPolyline(sp, off);
      final path = SchematicGeom.roundedPolylinePath(poly, _cornerR);
      final isRail = ln.tier == 1;
      canvas.drawPath(
        path,
        Paint()
          ..color = ln.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isRail ? 5.2 : w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (isRail) _paintRailTies(canvas, poly);
    }
  }

  /// Traverses « voie ferrée » du tier 1 : tirets blancs perpendiculaires
  /// posés tous les ~10 px le long de la polyligne.
  void _paintRailTies(Canvas canvas, List<Offset> poly) {
    const step = 10.0, tie = 3.4;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.butt;
    var carry = step / 2;
    for (var i = 0; i < poly.length - 1; i++) {
      final a = poly[i], b = poly[i + 1];
      final seg = b - a;
      final len = seg.distance;
      if (len < 1e-6) continue;
      final u = seg / len;
      final p = Offset(-u.dy, u.dx);
      var d = carry;
      while (d < len) {
        final c = a + u * d;
        canvas.drawLine(c - p * tie / 2, c + p * tie / 2, paint);
        d += step;
      }
      carry = d - len;
    }
  }

  // ---- arrêts (alphabet) ----

  void _paintStations(Canvas canvas, Rect vp) {
    final white = Paint()..color = Colors.white;
    final navyStroke = Paint()
      ..color = _navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final st in plan.stations) {
      final p = _s(st.pos);
      if (!vp.inflate(24).contains(p)) continue;
      final angle = geom.stationAngle[st] ?? 0.0;
      switch (st.kind) {
        case 'pole':
          // double anneau : pôle d'échange (gares routières, hubs majeurs)
          canvas.drawCircle(p, 7.4, white);
          canvas.drawCircle(p, 7.4, navyStroke);
          canvas.drawCircle(
              p,
              4.0,
              Paint()
                ..color = _navy
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4);
          break;
        case 'interchange':
          canvas.drawCircle(p, 4.8, white);
          canvas.drawCircle(p, 4.8, navyStroke);
          break;
        case 'terminus':
          // capsule orientée le long du tracé local
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(angle);
          final rr = RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 13, height: 7.5),
              const Radius.circular(4));
          canvas.drawRRect(rr, white);
          canvas.drawRRect(
              rr,
              Paint()
                ..color = _navy
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8);
          canvas.restore();
          break;
        default:
          // tiret blanc EN TRAVERS du faisceau (perpendiculaire au tracé)
          final half = (geom.stationBundleHalf[st] ?? 3.0) + 1.0;
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(angle + math.pi / 2); // perpendiculaire
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset.zero, width: half * 2, height: 2.2),
              white);
          canvas.restore();
      }
    }
  }

  // ---- pastilles de numéro de ligne ----

  /// Le long des ANTENNES (faisceaux ≤ 3 lignes) à intervalle écran, et en
  /// grappe aux terminus (toutes les lignes qui s'y terminent). Les troncs
  /// denses n'ont pas de pastilles intermédiaires (illisible) — leur
  /// composition se lit aux terminus et dans la légende.
  void _paintChips(
      Canvas canvas, Rect vp, List<(SchEdge, List<Offset>)> screenEdges) {
    for (final (e, sp) in screenEdges) {
      if (e.lines.length > 3) continue;
      var total = 0.0;
      for (var i = 0; i < sp.length - 1; i++) {
        total += (sp[i + 1] - sp[i]).distance;
      }
      if (total < _chipEveryPx * 0.8) continue;
      var next = _chipEveryPx / 2;
      var done = 0.0;
      for (var i = 0; i < sp.length - 1 && next < total; i++) {
        final a = sp[i], b = sp[i + 1];
        final len = (b - a).distance;
        while (next <= done + len && next < total) {
          final t = (next - done) / len;
          final at = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
          if (vp.inflate(20).contains(at)) {
            // une pastille par ligne du petit faisceau, empilées
            for (var k = 0; k < e.lines.length; k++) {
              final ln = e.lines[k];
              if (ln.label == null) continue;
              _chip(canvas, at.translate(0, k * 13.0 - (e.lines.length - 1) * 6.5),
                  ln.label!, ln.color);
            }
          }
          next += _chipEveryPx;
        }
        done += len;
      }
    }

    // grappes aux terminus
    geom.terminusLines.forEach((st, lines) {
      final p = _s(st.pos);
      if (!vp.inflate(30).contains(p)) return;
      var k = 0;
      for (final ln in lines) {
        if (ln.label == null) continue;
        _chip(canvas, p.translate(11.0 + (k ~/ 3) * 24.0, (k % 3) * 13.0 - 13),
            ln.label!, ln.color);
        k++;
      }
    });
  }

  void _chip(Canvas canvas, Offset at, String label, Color color) {
    final tp = labelCache.putIfAbsent('chip:$label', () {
      return TextPainter(
        text: TextSpan(
          text: _chipText(label),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    final w = (tp.width + 7).clamp(13.0, 40.0);
    const h = 10.5;
    final rect = Rect.fromCenter(center: at, width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5.25));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    canvas.drawRRect(rr, Paint()..color = color);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  /// Texte de pastille : numéros tels quels, lignes spéciales abrégées
  /// (TELEPHERIQUE_Orange → TPH, TRAIN_TCE → TCE, MAHITSY → MAH…).
  static String _chipText(String label) {
    if (label.startsWith('TELEPHERIQUE')) return 'TPH';
    if (label.startsWith('TRAIN')) return 'TCE';
    if (label.length > 5) return label.substring(0, 3).toUpperCase();
    return label;
  }

  // ---- labels d'arrêts (pré-calculés) ----

  void _paintLabels(Canvas canvas, Rect vp) {
    for (final pl in placedLabels) {
      // anchors en espace « canvas × scale » (sans offset) → translation pan
      final a = pl.anchor + offset;
      if (!vp.inflate(60).contains(a)) continue;
      final tp = labelCache.putIfAbsent(
          '${pl.bold ? 'B' : 'n'}:${pl.station.name}', () {
        return TextPainter(
          text: TextSpan(
            text: pl.station.name,
            style: TextStyle(
              color: pl.bold ? const Color(0xFF12263A) : const Color(0xFF5A6B7E),
              fontSize: pl.bold ? 11.5 : 10.0,
              fontWeight: pl.bold ? FontWeight.w700 : FontWeight.w500,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 2.5),
                Shadow(color: Colors.white, blurRadius: 2.5),
                Shadow(color: Colors.white, blurRadius: 1.5),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(); // PAS de maxWidth : jamais tronqué
      });
      if (pl.angleDeg == 0) {
        tp.paint(canvas, a);
      } else {
        canvas.save();
        canvas.translate(a.dx, a.dy);
        canvas.rotate(pl.angleDeg * math.pi / 180.0);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  // ---- eau / continuations / centre (repris du rendu legacy) ----

  void _paintWater(Canvas canvas) {
    for (final w in plan.water) {
      final sp = w.pts.map(_s).toList();
      if (w.kind == 'lake') {
        final rect = Rect.fromCenter(center: sp.first, width: 34, height: 22);
        canvas.drawOval(rect, Paint()..color = _waterFill);
        canvas.drawOval(
            rect,
            Paint()
              ..color = _waterColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6);
        _waterLabel(canvas, sp.first.translate(0, 19), w.label);
      } else {
        canvas.drawPath(
            SchematicGeom.roundedPolylinePath(sp, _cornerR),
            Paint()
              ..color = _waterColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = w.kind == 'canal' ? 3.0 : 5.0
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round);
        if (sp.length >= 2) _waterLabel(canvas, sp[sp.length ~/ 2], w.label);
      }
    }
  }

  void _waterLabel(Canvas canvas, Offset at, String label) {
    if (label.isEmpty) return;
    final tp = labelCache.putIfAbsent('water:$label', () {
      return TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFF3F7CAE),
            fontSize: 11,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.white, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintContinuations(Canvas canvas, Rect vp) {
    const double off = 16.0, s = 7.5;
    final fill = Paint()..color = const Color(0xFF37474F);
    final halo = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    for (final c in plan.continuations) {
      final base = _s(c.pos) + c.dir * off;
      if (!vp.inflate(30).contains(base)) continue;
      final u = c.dir;
      final p = Offset(-u.dy, u.dx);
      final apex = base + u * s;
      final b1 = base + p * (s * 0.62);
      final b2 = base - p * (s * 0.62);
      final path = Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b2.dx, b2.dy)
        ..close();
      canvas.drawPath(path, halo);
      canvas.drawPath(path, fill);
    }
  }

  void _paintCentreRect(Canvas canvas) {
    final r = plan.centreRect!;
    final sr = Rect.fromPoints(_s(r.topLeft), _s(r.bottomRight));
    final rr = RRect.fromRectAndRadius(sr, const Radius.circular(14));
    canvas.drawRRect(rr, Paint()..color = const Color(0x142563EB));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFF2563EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0);
    final tp = TextPainter(
      text: TextSpan(
        text: '⤢  $centreLabel',
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 7);
    final chipW = tp.width + pad.horizontal;
    final chipH = tp.height + pad.vertical;
    final chip =
        Rect.fromLTWH(sr.center.dx - chipW / 2, sr.top + 8, chipW, chipH);
    canvas.drawRRect(RRect.fromRectAndRadius(chip, Radius.circular(chipH / 2)),
        Paint()..color = const Color(0xFF2563EB));
    tp.paint(canvas, Offset(chip.left + pad.left, chip.top + pad.top));
  }

  @override
  bool shouldRepaint(SchematicPainterCts old) =>
      old.scale != scale ||
      old.offset != offset ||
      old.plan != plan ||
      old.viewport != viewport ||
      old.placedLabels != placedLabels;
}

/// Caches géométriques CANVAS-SPACE du rendu CTS, construits UNE fois par
/// plan (positions canvas immuables) : angle du tracé au droit de chaque
/// station (tirets/capsules orientés), lignes terminant à chaque terminus
/// (grappes de pastilles), demi-largeur de faisceau locale (longueur des
/// tirets), densité max (échelle d'épaisseur).
class CtsGeomCache {
  final Map<SchStation, double> stationAngle = {};
  final Map<SchStation, double> stationBundleHalf = {};
  final Map<SchStation, List<SchLine>> terminusLines = {};
  int nMax = 1;

  CtsGeomCache(SchematicPlan plan) {
    for (final e in plan.edges) {
      if (e.lines.length > nMax) nMax = e.lines.length;
    }
    // angle + densité locale : segment d'edge le plus proche de la station
    for (final st in plan.stations) {
      SchEdge? bestE;
      var bestD = double.infinity;
      var bestAngle = 0.0;
      for (final e in plan.edges) {
        for (var i = 0; i < e.pts.length - 1; i++) {
          final a = e.pts[i], b = e.pts[i + 1];
          final d = _distToSegment(st.pos, a, b);
          if (d < bestD) {
            bestD = d;
            bestE = e;
            bestAngle = math.atan2(b.dy - a.dy, b.dx - a.dx);
          }
        }
      }
      if (bestE != null && bestD < 30) {
        stationAngle[st] = bestAngle;
        final n = bestE.lines.length;
        // demi-largeur approx en px écran (constantes du painter)
        final t = nMax <= 1 ? 0.0 : ((n - 1) / (nMax - 1)).clamp(0.0, 1.0);
        final w = 2.2 + 1.3 * t;
        stationBundleHalf[st] = ((n - 1) * (w + 0.7) + w) / 2 + 1.6;
      }
      if (st.kind == 'terminus' || st.kind == 'pole') {
        // lignes des edges dont une extrémité coïncide avec la station
        final seen = <String>{};
        final lines = <SchLine>[];
        for (final e in plan.edges) {
          final touches = (e.pts.first - st.pos).distance < 2.0 ||
              (e.pts.last - st.pos).distance < 2.0;
          if (!touches) continue;
          for (final ln in e.lines) {
            final key = ln.label ?? ln.color.toString();
            if (seen.add(key)) lines.add(ln);
          }
        }
        if (st.kind == 'terminus' && lines.isNotEmpty) {
          terminusLines[st] = lines;
        }
      }
    }
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / l2;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }
}
