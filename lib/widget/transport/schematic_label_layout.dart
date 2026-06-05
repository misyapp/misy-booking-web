import 'dart:math' as math;
import 'dart:ui';

import 'package:rider_ride_hailing_app/models/schematic_plan.dart';

/// Placement AUTOMATIQUE des labels d'arrêts du plan schématique CTS.
///
/// Module PUR (aucune dépendance Canvas/TextPainter — la mesure du texte est
/// injectée) → testable en isolation. Contrat produit (validé 05/06/2026) :
/// - glouton par ordre de priorité ([SchStation.priority] décroissant) :
///   majeurs (pole/interchange/terminus) d'abord, EN GRAS ; arrêts simples
///   ensuite, masquables — JAMAIS tronqués (la bbox réelle est mesurée,
///   plus de maxWidth/ellipsis) ;
/// - ~8 positions candidates autour de l'arrêt, angles {0°, ±45°} seulement,
///   jamais de vertical ;
/// - collision par AABB réelles (labels déjà posés + segments de tracés) via
///   grille spatiale — un label ne chevauche ni un autre label ni un ruban ;
/// - un arrêt sans candidat libre est MASQUÉ (~10 % toléré) ; un passage
///   « force-directed léger » ne s'acharne que sur les MAJEURS non placés ;
/// - tout est en ESPACE ÉCRAN : l'appelant mémoïse par palier de zoom et
///   translate au pan (aucun recalcul par frame).
class SchematicLabelLayout {
  SchematicLabelLayout._();

  /// Mesure du texte (largeur/hauteur en px écran) — injectée :
  /// TextPainter en prod, stub déterministe dans les tests.
  static List<PlacedLabel> layoutLabels({
    required List<SchStation> stationsByPriority,
    required List<ScreenSegment> edgeSegments,
    required Map<SchStation, Offset> screenPos,
    required Rect viewport,
    required Size Function(String text, {required bool bold}) measure,
    double symbolRadius = 6.0,
    double gap = 3.0,
  }) {
    final grid = _SpatialGrid(cell: 64.0);
    for (final s in edgeSegments) {
      grid.addSegment(s);
    }

    final placed = <PlacedLabel>[];
    final unplacedMajors = <SchStation>[];

    for (final st in stationsByPriority) {
      if (st.name.isEmpty) continue;
      final p = screenPos[st];
      if (p == null || !viewport.inflate(40).contains(p)) continue;
      final bold = _isMajor(st);
      final size = measure(st.name, bold: bold);
      final label = _tryPlace(st, p, size, bold, grid, viewport,
          symbolRadius: symbolRadius, gap: gap);
      if (label != null) {
        placed.add(label);
        grid.addLabel(label.aabb);
      } else if (bold) {
        unplacedMajors.add(st);
      }
    }

    // Force-directed LÉGER : seulement les majeurs restés sans place —
    // on éloigne progressivement l'ancre le long des 8 directions
    // autorisées (≤ 5 crans de 6 px) et on re-teste. Pas d'ILP.
    for (final st in unplacedMajors) {
      final p = screenPos[st]!;
      final size = measure(st.name, bold: true);
      PlacedLabel? label;
      for (var push = 1; push <= 5 && label == null; push++) {
        label = _tryPlace(st, p, size, true, grid, viewport,
            symbolRadius: symbolRadius + push * 6.0, gap: gap);
      }
      if (label != null) {
        placed.add(label);
        grid.addLabel(label.aabb);
      }
      // sinon : masqué (assumé — clusters denses au dézoom).
    }
    return placed;
  }

  static bool _isMajor(SchStation st) =>
      st.kind == 'pole' || st.kind == 'interchange' || st.kind == 'terminus';

  /// Essaie les ~8 candidats dans l'ordre de préférence ; null si aucun.
  static PlacedLabel? _tryPlace(
    SchStation st,
    Offset p,
    Size size,
    bool bold,
    _SpatialGrid grid,
    Rect viewport, {
    required double symbolRadius,
    required double gap,
  }) {
    final w = size.width, h = size.height;
    final r = symbolRadius + gap;
    // (ancre du COIN GAUCHE-MILIEU du texte, angle). Ordre de préférence
    // cartographique : droite, droite-haut, droite-bas, gauche, gauche-haut,
    // gauche-bas, puis diagonales 45° (NE montant, SE descendant).
    final candidates = <({Offset a, int angle})>[
      (a: Offset(p.dx + r, p.dy - h / 2), angle: 0),
      (a: Offset(p.dx + r * 0.8, p.dy - h - r * 0.3), angle: 0),
      (a: Offset(p.dx + r * 0.8, p.dy + r * 0.3), angle: 0),
      (a: Offset(p.dx - r - w, p.dy - h / 2), angle: 0),
      (a: Offset(p.dx - r * 0.8 - w, p.dy - h - r * 0.3), angle: 0),
      (a: Offset(p.dx - r * 0.8 - w, p.dy + r * 0.3), angle: 0),
      (a: Offset(p.dx + r * 0.7, p.dy - r * 0.7 - h), angle: -45),
      (a: Offset(p.dx + r * 0.7, p.dy + r * 0.7), angle: 45),
    ];
    for (final c in candidates) {
      final aabb = aabbFor(c.a, size, c.angle);
      if (!viewport.inflate(8).overlaps(aabb)) {
        continue; // entièrement hors écran
      }
      // Tolérance : on ignore les segments au contact immédiat du symbole
      // d'ancrage (le label peut toucher SON arrêt, pas les rubans voisins).
      if (grid.collides(aabb, ignoreNear: p, ignoreRadius: symbolRadius + 1)) {
        continue;
      }
      return PlacedLabel(
        station: st,
        anchor: c.a,
        angleDeg: c.angle,
        bold: bold,
        aabb: aabb,
      );
    }
    return null;
  }

  /// AABB écran d'un texte w×h posé à [anchor] (coin haut-gauche) et tourné
  /// de [angleDeg] autour de l'ancre — pour 0° c'est le rect lui-même, pour
  /// ±45° l'enveloppe des 4 coins tournés.
  static Rect aabbFor(Offset anchor, Size size, int angleDeg) {
    if (angleDeg == 0) {
      return Rect.fromLTWH(anchor.dx, anchor.dy, size.width, size.height);
    }
    final rad = angleDeg * math.pi / 180.0;
    final cosA = math.cos(rad), sinA = math.sin(rad);
    Offset rot(double x, double y) => Offset(
          anchor.dx + x * cosA - y * sinA,
          anchor.dy + x * sinA + y * cosA,
        );
    final corners = [
      rot(0, 0),
      rot(size.width, 0),
      rot(size.width, size.height),
      rot(0, size.height),
    ];
    var minX = corners[0].dx, maxX = corners[0].dx;
    var minY = corners[0].dy, maxY = corners[0].dy;
    for (final c in corners) {
      minX = math.min(minX, c.dx);
      maxX = math.max(maxX, c.dx);
      minY = math.min(minY, c.dy);
      maxY = math.max(maxY, c.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// Label retenu : à dessiner par le painter (rotation [angleDeg] autour de
/// [anchor], halo blanc, gras si [bold]).
class PlacedLabel {
  final SchStation station;
  final Offset anchor;
  final int angleDeg; // 0 | -45 | 45 — jamais vertical
  final bool bold;
  final Rect aabb;

  const PlacedLabel({
    required this.station,
    required this.anchor,
    required this.angleDeg,
    required this.bold,
    required this.aabb,
  });
}

/// Segment de tracé en espace écran (anti-collision label ↔ ruban).
class ScreenSegment {
  final Offset a;
  final Offset b;
  const ScreenSegment(this.a, this.b);
}

/// Grille spatiale uniforme : bboxes de labels posés + segments de tracés.
/// Test d'intersection AABB RÉELLE (pas d'occupation par cellule entière —
/// c'était la cause des labels manquants de l'ancien rendu).
class _SpatialGrid {
  final double cell;
  final Map<int, List<Rect>> _labels = {};
  final Map<int, List<ScreenSegment>> _segments = {};

  _SpatialGrid({required this.cell});

  int _key(int cx, int cy) => cx * 73856093 ^ cy * 19349663;

  Iterable<int> _cellsOf(Rect r) sync* {
    final x0 = (r.left / cell).floor(), x1 = (r.right / cell).floor();
    final y0 = (r.top / cell).floor(), y1 = (r.bottom / cell).floor();
    for (var cx = x0; cx <= x1; cx++) {
      for (var cy = y0; cy <= y1; cy++) {
        yield _key(cx, cy);
      }
    }
  }

  void addLabel(Rect r) {
    for (final k in _cellsOf(r)) {
      _labels.putIfAbsent(k, () => []).add(r);
    }
  }

  void addSegment(ScreenSegment s) {
    final r = Rect.fromPoints(s.a, s.b);
    for (final k in _cellsOf(r)) {
      _segments.putIfAbsent(k, () => []).add(s);
    }
  }

  /// Collision de [r] avec un label posé ou un segment de tracé.
  /// [ignoreNear]/[ignoreRadius] : exclut les segments touchant le symbole
  /// d'ancrage lui-même.
  bool collides(Rect r,
      {required Offset ignoreNear, required double ignoreRadius}) {
    for (final k in _cellsOf(r)) {
      for (final other in _labels[k] ?? const <Rect>[]) {
        if (r.overlaps(other)) return true;
      }
      for (final s in _segments[k] ?? const <ScreenSegment>[]) {
        if (!_segmentIntersectsRect(s, r)) continue;
        // segment au ras du symbole d'ancrage → toléré
        final d = _distToSegment(ignoreNear, s);
        if (d > ignoreRadius) return true;
      }
    }
    return false;
  }

  static bool _segmentIntersectsRect(ScreenSegment s, Rect r) {
    if (r.contains(s.a) || r.contains(s.b)) return true;
    final corners = [
      r.topLeft,
      r.topRight,
      r.bottomRight,
      r.bottomLeft,
    ];
    for (var i = 0; i < 4; i++) {
      if (_segmentsCross(s.a, s.b, corners[i], corners[(i + 1) % 4])) {
        return true;
      }
    }
    return false;
  }

  static bool _segmentsCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final d1 = cross(p3, p4, p1);
    final d2 = cross(p3, p4, p2);
    final d3 = cross(p1, p2, p3);
    final d4 = cross(p1, p2, p4);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
  }

  static double _distToSegment(Offset p, ScreenSegment s) {
    final dx = s.b.dx - s.a.dx, dy = s.b.dy - s.a.dy;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) return (p - s.a).distance;
    var t = ((p.dx - s.a.dx) * dx + (p.dy - s.a.dy) * dy) / l2;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(s.a.dx + t * dx, s.a.dy + t * dy)).distance;
  }
}
