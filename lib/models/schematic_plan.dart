import 'dart:ui';

/// Modèle du plan schématique consommé par le `SchematicPainter`.
/// Produit hors-ligne par `tools/schema/octi2json.py` (sortie LOOM → JSON).
/// Coordonnées en espace « canvas » (le painter applique zoom/pan dessus).
class SchematicPlan {
  final Size size;
  final List<SchEdge> edges;
  final List<SchStation> stations;
  final List<SchWater> water;
  final List<SchContinuation> continuations;
  final Rect? centreRect;

  SchematicPlan({
    required this.size,
    required this.edges,
    required this.stations,
    required this.water,
    required this.continuations,
    this.centreRect,
  });

  factory SchematicPlan.fromJson(Map<String, dynamic> j) {
    Offset pt(List<dynamic> p) =>
        Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());

    final s = (j['size'] as List).map((e) => (e as num).toDouble()).toList();
    Rect? cr;
    if (j['centreRect'] != null) {
      final r = (j['centreRect'] as List).map((e) => (e as num).toDouble()).toList();
      cr = Rect.fromLTWH(r[0], r[1], r[2], r[3]);
    }
    return SchematicPlan(
      size: Size(s[0], s[1]),
      centreRect: cr,
      edges: (j['edges'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return SchEdge(
          pts: (m['pts'] as List).map((p) => pt(p as List)).toList(),
          lines: (m['lines'] as List).map((l) {
            final lm = l as Map<String, dynamic>;
            return SchLine(_color(lm['color'] as String),
                (lm['tier'] as num).toInt());
          }).toList(),
        );
      }).toList(),
      stations: (j['stations'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return SchStation(
          pos: Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()),
          name: (m['name'] ?? '') as String,
          kind: (m['kind'] ?? 'stop') as String,
          tier: (m['tier'] as num?)?.toInt() ?? 2,
          n: (m['n'] as num?)?.toInt() ?? 1,
        );
      }).toList(),
      water: (j['water'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return SchWater(
          kind: (m['kind'] ?? 'river') as String,
          label: (m['label'] ?? '') as String,
          pts: (m['pts'] as List).map((p) => pt(p as List)).toList(),
        );
      }).toList(),
      continuations: ((j['continuations'] ?? const []) as List).map((e) {
        final m = e as Map<String, dynamic>;
        return SchContinuation(
          pos: Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()),
          dir: Offset((m['dx'] as num).toDouble(), (m['dy'] as num).toDouble()),
          n: (m['n'] as num?)?.toInt() ?? 1,
        );
      }).toList(),
    );
  }

  static Color _color(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class SchLine {
  final Color color;
  final int tier;
  const SchLine(this.color, this.tier);
}

class SchEdge {
  final List<Offset> pts;
  final List<SchLine> lines;
  const SchEdge({required this.pts, required this.lines});
}

class SchStation {
  final Offset pos;
  final String name;
  final String kind; // stop | terminus | interchange
  final int tier;
  final int n; // nombre de lignes desservies
  const SchStation({
    required this.pos,
    required this.name,
    required this.kind,
    required this.tier,
    required this.n,
  });

  /// Priorité d'affichage du label (plus haut = montré en premier au dézoom).
  int get priority {
    if (kind == 'interchange') return 100 + n;
    if (tier == 1) return 90;
    if (kind == 'terminus') return 60;
    return n; // stops : par nb de lignes
  }
}

class SchWater {
  final String kind; // river | canal | lake (lake : pts = [centre], glyphe)
  final String label;
  final List<Offset> pts;
  const SchWater({
    required this.kind,
    required this.label,
    required this.pts,
  });
}

/// Ligne coupée par la zone : la ligne CONTINUE hors du plan (flèche).
class SchContinuation {
  final Offset pos;   // nœud-frontière (espace canvas)
  final Offset dir;   // direction sortante unitaire (espace écran)
  final int n;        // nb de lignes concernées
  const SchContinuation({required this.pos, required this.dir, required this.n});
}
