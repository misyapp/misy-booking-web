import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/models/schematic_plan.dart';

/// Vue du plan schématique avec ZOOM SÉMANTIQUE :
/// - le zoom/pan ne transforme QUE les positions (espacement des arrêts) ;
/// - la largeur des traits, la taille des pastilles et la POLICE des labels
///   restent CONSTANTES (lisibilité conservée à tout niveau de zoom) ;
/// - les noms d'arrêts apparaissent PROGRESSIVEMENT (déclutter glouton par
///   priorité : hubs/terminus d'abord, tous les arrêts en zoomant).
class SchematicMapView extends StatefulWidget {
  final SchematicPlan plan;
  final bool showCentreRect;
  final String centreLabel;
  final VoidCallback? onCentreTap;

  const SchematicMapView({
    super.key,
    required this.plan,
    this.showCentreRect = false,
    this.centreLabel = 'Centre-ville',
    this.onCentreTap,
  });

  @override
  State<SchematicMapView> createState() => _SchematicMapViewState();
}

class _SchematicMapViewState extends State<SchematicMapView> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _fitted = false;

  // état de geste
  double _startScale = 1.0;
  late Offset _startFocalCanvas;

  // caches
  late final List<SchStation> _sorted = [...widget.plan.stations]
    ..sort((a, b) => b.priority.compareTo(a.priority));
  final Map<String, TextPainter> _labelCache = {};

  static const double _minScale = 0.05;
  static const double _maxScale = 8.0;

  void _fit(Size vp) {
    final s = widget.plan.size;
    final k = 0.94 *
        (vp.width / s.width < vp.height / s.height
            ? vp.width / s.width
            : vp.height / s.height);
    _scale = k;
    _offset = Offset((vp.width - s.width * k) / 2, (vp.height - s.height * k) / 2);
    _fitted = true;
  }

  Offset _toCanvas(Offset screen) => (screen - _offset) / _scale;

  void _zoomAround(Offset focal, double factor) {
    final newScale = (_scale * factor).clamp(_minScale, _maxScale);
    final canvasPt = _toCanvas(focal);
    setState(() {
      _scale = newScale;
      _offset = focal - canvasPt * newScale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final vp = Size(c.maxWidth, c.maxHeight);
      if (!_fitted && vp.width.isFinite && vp.height.isFinite) _fit(vp);

      return Stack(children: [
        Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              // molette souris / scroll 2 doigts trackpad
              _zoomAround(
                  e.localPosition, e.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12);
            } else if (e is PointerScaleEvent) {
              // pinch trackpad macOS (ctrl+wheel navigateur)
              _zoomAround(e.localPosition, e.scale);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) {
              _startScale = _scale;
              _startFocalCanvas = _toCanvas(d.localFocalPoint);
            },
            onScaleUpdate: (d) {
              final newScale =
                  (_startScale * d.scale).clamp(_minScale, _maxScale);
              setState(() {
                _scale = newScale.toDouble();
                _offset = d.localFocalPoint - _startFocalCanvas * _scale;
              });
            },
            onDoubleTapDown: (d) => _zoomAround(d.localPosition, 1.6),
            onDoubleTap: () {}, // requis pour activer onDoubleTapDown
            onTapUp: (d) {
              if (widget.showCentreRect && widget.plan.centreRect != null) {
                if (widget.plan.centreRect!
                    .contains(_toCanvas(d.localPosition))) {
                  widget.onCentreTap?.call();
                }
              }
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: _SchematicPainter(
                plan: widget.plan,
                sorted: _sorted,
                labelCache: _labelCache,
                scale: _scale,
                offset: _offset,
                viewport: vp,
                showCentreRect: widget.showCentreRect,
                centreLabel: widget.centreLabel,
              ),
            ),
          ),
        ),
        // Boutons zoom — garantie universelle quel que soit le device
        Positioned(
          right: 12,
          bottom: 16,
          child: Column(children: [
            _zoomBtn(Icons.add, () =>
                _zoomAround(Offset(vp.width / 2, vp.height / 2), 1.45)),
            const SizedBox(height: 8),
            _zoomBtn(Icons.remove, () =>
                _zoomAround(Offset(vp.width / 2, vp.height / 2), 1 / 1.45)),
            const SizedBox(height: 8),
            _zoomBtn(Icons.fit_screen_rounded, () => setState(() => _fit(vp))),
          ]),
        ),
      ]);
    });
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 22, color: const Color(0xFF1D3557)),
          ),
        ),
      );
}

class _SchematicPainter extends CustomPainter {
  final SchematicPlan plan;
  final List<SchStation> sorted;
  final Map<String, TextPainter> labelCache;
  final double scale;
  final Offset offset;
  final Size viewport;
  final bool showCentreRect;
  final String centreLabel;

  _SchematicPainter({
    required this.plan,
    required this.sorted,
    required this.labelCache,
    required this.scale,
    required this.offset,
    required this.viewport,
    required this.showCentreRect,
    required this.centreLabel,
  });

  // constantes ÉCRAN (jamais multipliées par scale)
  static const double _spacing = 3.0; // écart entre brins d'un faisceau
  static const Color _waterColor = Color(0xFF9FC7E8);
  static const Color _waterFill = Color(0x559FC7E8);

  Offset _s(Offset p) => p * scale + offset;

  double _tierWidth(int tier) =>
      tier == 1 ? 5.2 : (tier == 2 ? 3.0 : 2.0);

  @override
  void paint(Canvas canvas, Size size) {
    final vpRect = Offset.zero & viewport;

    _paintWater(canvas);
    _paintEdges(canvas, vpRect, tier1: false);
    _paintEdges(canvas, vpRect, tier1: true); // téléphérique/train au-dessus
    _paintStations(canvas, vpRect);
    _paintContinuations(canvas, vpRect);
    _paintLabels(canvas, vpRect);
    if (showCentreRect && plan.centreRect != null) _paintCentreRect(canvas);
  }

  void _paintWater(Canvas canvas) {
    for (final w in plan.water) {
      final sp = w.pts.map(_s).toList();
      if (w.kind == 'lake') {
        // glyphe de lac stylisé (taille ÉCRAN constante) au point donné
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
        final path = Path()..addPolygon(sp, false);
        canvas.drawPath(
            path,
            Paint()
              ..color = _waterColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = w.kind == 'canal' ? 3.0 : 5.0
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round);
        if (sp.length >= 2) {
          _waterLabel(canvas, sp[sp.length ~/ 2], w.label);
        }
      }
    }
  }

  void _paintEdges(Canvas canvas, Rect vp, {required bool tier1}) {
    for (final e in plan.edges) {
      final sp = e.pts.map(_s).toList();
      if (!_visible(sp, vp)) continue;
      final n = e.lines.length;
      for (var i = 0; i < n; i++) {
        final ln = e.lines[i];
        if ((ln.tier == 1) != tier1) continue;
        final off = (i - (n - 1) / 2.0) * _spacing;
        final poly = _offsetPolyline(sp, off);
        canvas.drawPath(
            Path()..addPolygon(poly, false),
            Paint()
              ..color = ln.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = _tierWidth(ln.tier)
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round);
      }
    }
  }

  void _paintStations(Canvas canvas, Rect vp) {
    final white = Paint()..color = Colors.white;
    final black = Paint()
      ..color = const Color(0xFF1D3557)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final st in plan.stations) {
      final p = _s(st.pos);
      if (!vp.inflate(20).contains(p)) continue;
      switch (st.kind) {
        case 'interchange':
          final r = 4.6;
          canvas.drawCircle(p, r, white);
          canvas.drawCircle(p, r, black);
          break;
        case 'terminus':
          canvas.drawCircle(p, 3.4, white);
          canvas.drawCircle(
              p,
              3.4,
              Paint()
                ..color = const Color(0xFF1D3557)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6);
          break;
        default:
          canvas.drawCircle(p, 2.2, white);
          canvas.drawCircle(
              p,
              2.2,
              Paint()
                ..color = const Color(0xFF8194A8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0);
      }
    }
  }

  /// Flèches « la ligne continue hors zone » (plan centre) — taille constante.
  void _paintContinuations(Canvas canvas, Rect vp) {
    const double off = 16.0; // distance au marqueur de station
    const double s = 7.5;    // taille de la flèche
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

  /// Labels progressifs : déclutter glouton par priorité (cellules occupées).
  void _paintLabels(Canvas canvas, Rect vp) {
    final occupied = <int>{};
    final cols = (viewport.width / 58).ceil() + 2;
    int cell(double x, double y) =>
        (y ~/ 13) * cols + (x ~/ 58).clamp(0, cols - 1);

    for (final st in sorted) {
      if (st.name.isEmpty) continue;
      final p = _s(st.pos);
      if (!vp.contains(p)) continue;
      final c0 = cell(p.dx, p.dy);
      final c1 = cell(p.dx + 50, p.dy);
      if (occupied.contains(c0) || occupied.contains(c1)) continue;
      occupied..add(c0)..add(c1);

      final tp = labelCache.putIfAbsent(st.name, () {
        final t = TextPainter(
          text: TextSpan(
            text: st.name,
            style: TextStyle(
              color: const Color(0xFF12263A),
              fontSize: st.kind == 'interchange' ? 11.5 : 10.0,
              fontWeight:
                  st.kind == 'stop' ? FontWeight.w500 : FontWeight.w700,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 2),
                Shadow(color: Colors.white, blurRadius: 2),
                Shadow(color: Colors.white, blurRadius: 1),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 130);
        return t;
      });
      tp.paint(canvas, Offset(p.dx + 5, p.dy - tp.height / 2));
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
    // pastille label en haut
    final tp = TextPainter(
      text: TextSpan(
        text: '⤢  $centreLabel',
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pad = const EdgeInsets.symmetric(horizontal: 12, vertical: 7);
    final chipW = tp.width + pad.horizontal;
    final chipH = tp.height + pad.vertical;
    final chip = Rect.fromLTWH(
        sr.center.dx - chipW / 2, sr.top + 8, chipW, chipH);
    canvas.drawRRect(
        RRect.fromRectAndRadius(chip, Radius.circular(chipH / 2)),
        Paint()..color = const Color(0xFF2563EB));
    tp.paint(canvas, Offset(chip.left + pad.left, chip.top + pad.top));
  }

  // ---- helpers ----
  List<Offset> _offsetPolyline(List<Offset> sp, double off) {
    if (off == 0 || sp.length < 2) return sp;
    final res = <Offset>[];
    for (var j = 0; j < sp.length; j++) {
      Offset dir;
      if (j == 0) {
        dir = sp[1] - sp[0];
      } else if (j == sp.length - 1) {
        dir = sp[j] - sp[j - 1];
      } else {
        dir = sp[j + 1] - sp[j - 1];
      }
      final len = dir.distance;
      if (len < 1e-6) {
        res.add(sp[j]);
        continue;
      }
      res.add(sp[j] + Offset(-dir.dy / len, dir.dx / len) * off);
    }
    return res;
  }

  bool _visible(List<Offset> sp, Rect vp) {
    var minx = double.infinity, miny = double.infinity;
    var maxx = -double.infinity, maxy = -double.infinity;
    for (final p in sp) {
      if (p.dx < minx) minx = p.dx;
      if (p.dy < miny) miny = p.dy;
      if (p.dx > maxx) maxx = p.dx;
      if (p.dy > maxy) maxy = p.dy;
    }
    return Rect.fromLTRB(minx, miny, maxx, maxy).inflate(8).overlaps(vp);
  }

  void _waterLabel(Canvas canvas, Offset at, String label) {
    if (label.isEmpty) return;
    final tp = TextPainter(
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
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SchematicPainter old) =>
      old.scale != scale ||
      old.offset != offset ||
      old.plan != plan ||
      old.viewport != viewport;
}
