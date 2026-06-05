import 'dart:ui';

/// Helpers géométriques PURS partagés par les painters schématiques
/// (`_SchematicPainter` legacy et `SchematicPainterCts`).
class SchematicGeom {
  SchematicGeom._();

  /// Décale une polyligne écran perpendiculairement de [off] px (offset des
  /// brins d'un faisceau). Tangente par différence centrale aux sommets.
  static List<Offset> offsetPolyline(List<Offset> sp, double off) {
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

  /// Bbox de la polyligne écran vs viewport (culling).
  static bool visible(List<Offset> sp, Rect vp) {
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

  /// Path à COINS ARRONDIS : à chaque sommet interne, recule de [r] (borné à
  /// la moitié du plus court segment adjacent) le long des deux segments et
  /// raccorde par une Bézier quadratique passant par le sommet — les coudes
  /// 45°/90° de l'octi deviennent des virages doux type plan de métro.
  /// Le même path sert au casing ET aux brins (superposition parfaite).
  static Path roundedPolylinePath(List<Offset> pts, double r) {
    final path = Path();
    if (pts.isEmpty) return path;
    if (pts.length < 3 || r <= 0) {
      path.moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      return path;
    }
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final a = pts[i - 1], b = pts[i], c = pts[i + 1];
      final ab = b - a, bc = c - b;
      final lab = ab.distance, lbc = bc.distance;
      if (lab < 1e-6 || lbc < 1e-6) {
        path.lineTo(b.dx, b.dy);
        continue;
      }
      final rr = r.clamp(0.0, lab / 2).clamp(0.0, lbc / 2);
      final pIn = b - ab / lab * rr;   // point d'entrée du virage
      final pOut = b + bc / lbc * rr;  // point de sortie
      path.lineTo(pIn.dx, pIn.dy);
      path.quadraticBezierTo(b.dx, b.dy, pOut.dx, pOut.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }
}
