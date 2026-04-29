import 'dart:math' as math;
import 'dart:ui';

import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';

/// Un nœud du diagramme = un cluster d'arrêts (1 arrêt physique). Contient
/// sa position projetée sur le canvas, sa position GPS d'origine pour
/// reproductibilité, le nom le plus informatif, et l'ensemble des numéros
/// de lignes qui le desservent.
class DiagramNode {
  final String key;
  final Offset canvas;
  final LatLng latLng;
  final String name;
  final Set<String> lines;
  final Color primaryColor;

  /// `lines.length >= 2` ⇒ c'est une correspondance (rendu pastille blanc
  /// large bordé noir).
  bool get isInterchange => lines.length >= 2;

  const DiagramNode({
    required this.key,
    required this.canvas,
    required this.latLng,
    required this.name,
    required this.lines,
    required this.primaryColor,
  });
}

/// Une polyline octilinéarisée pour une ligne donnée. Contient la liste
/// ordonnée des points (Offsets canvas) qui la composent — les nœuds sont
/// préservés à leur position et les segments entre nœuds sont rendus en
/// 1 ou 2 segments orthogonaux.
class DiagramLinePath {
  final String lineNumber;
  final Color color;
  final String displayName;
  final List<Offset> points;
  // Indices dans `points` qui correspondent à des nœuds (= arrêts).
  // Les autres points sont des coudes intermédiaires.
  final List<int> stopIndices;

  const DiagramLinePath({
    required this.lineNumber,
    required this.color,
    required this.displayName,
    required this.points,
    required this.stopIndices,
  });
}

/// Pré-calcule un layout octilinéaire (Manhattan-style) du réseau public
/// pour rendu via [NetworkDiagramPainter]. Construit en une seule passe à
/// partir du [PublicTransportService] déjà chargé.
class NetworkDiagramLayout {
  /// Distance min en mètres pour fusionner 2 stops en 1 nœud (proximité).
  static const double _proximityMeters = 35.0;

  /// Distance max en mètres pour fusionner 2 stops par nom identique.
  static const double _sameNameMeters = 250.0;

  /// Tolérance angulaire pour considérer un segment comme déjà
  /// horizontal/vertical (radian). 5° de tolérance.
  static const double _octilinearEps = 5 * math.pi / 180.0;

  /// Marge interne du canvas en pixels logiques (autour du diagramme).
  static const double _padding = 80.0;

  final List<DiagramNode> nodes;
  final List<DiagramLinePath> lines;
  final Size canvasSize;

  const NetworkDiagramLayout._({
    required this.nodes,
    required this.lines,
    required this.canvasSize,
  });

  /// Calcule le layout pour un canvas de taille [targetSize]. Le résultat
  /// est mis en cache mémoire pour la session.
  static NetworkDiagramLayout? _cached;
  static Size? _cachedSize;

  static NetworkDiagramLayout compute(
    PublicTransportService svc, {
    required Size targetSize,
  }) {
    if (_cached != null &&
        _cachedSize == targetSize &&
        _cached!.lines.isNotEmpty) {
      return _cached!;
    }
    final layout = _computeImpl(svc, targetSize);
    _cached = layout;
    _cachedSize = targetSize;
    return layout;
  }

  static NetworkDiagramLayout _computeImpl(
      PublicTransportService svc, Size targetSize) {
    final groups = svc.allLines;
    if (groups.isEmpty) {
      return NetworkDiagramLayout._(
        nodes: const [],
        lines: const [],
        canvasSize: targetSize,
      );
    }

    // 1. Cluster all stops globally.
    final clusters = <_NodeBuilder>[];
    final stopToNode = <_StopRef, _NodeBuilder>{};

    for (final group in groups) {
      final meta = svc.metadataFor(group.lineNumber);
      final color = meta != null
          ? Color(meta.colorValue)
          : const Color(0xFF1565C0);

      void process(TransportLine? line) {
        if (line == null) return;
        for (var i = 0; i < line.stops.length; i++) {
          final stop = line.stops[i];
          final cluster = _findOrCreateCluster(
            clusters,
            stop,
            color,
            group.lineNumber,
          );
          stopToNode[_StopRef(group.lineNumber, line.isRetour, i)] = cluster;
        }
      }

      process(group.aller);
      process(group.retour);
    }

    // 2. Compute projection: bounds of GPS points → canvas.
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final c in clusters) {
      if (c.latLng.latitude < minLat) minLat = c.latLng.latitude;
      if (c.latLng.latitude > maxLat) maxLat = c.latLng.latitude;
      if (c.latLng.longitude < minLng) minLng = c.latLng.longitude;
      if (c.latLng.longitude > maxLng) maxLng = c.latLng.longitude;
    }
    final dLat = maxLat - minLat;
    final dLng = maxLng - minLng;
    final midLat = (minLat + maxLat) / 2;
    // Web Mercator-like : x ∝ lng × cos(midLat), y ∝ -lat (north-up).
    final cosLat = math.cos(midLat * math.pi / 180.0);

    final usableW = targetSize.width - 2 * _padding;
    final usableH = targetSize.height - 2 * _padding;
    final scaleX = dLng > 0 ? usableW / (dLng * cosLat) : 1.0;
    final scaleY = dLat > 0 ? usableH / dLat : 1.0;
    final scale = math.min(scaleX, scaleY);

    final projW = dLng * cosLat * scale;
    final projH = dLat * scale;
    final offsetX = _padding + (usableW - projW) / 2;
    final offsetY = _padding + (usableH - projH) / 2;

    Offset project(LatLng p) {
      final x = (p.longitude - minLng) * cosLat * scale + offsetX;
      final y = (maxLat - p.latitude) * scale + offsetY;
      return Offset(x, y);
    }

    // 3. Build DiagramNodes from clusters (now we can compute canvas pos).
    final nodes = <DiagramNode>[];
    for (var i = 0; i < clusters.length; i++) {
      final c = clusters[i];
      c.index = i;
      c.canvas = project(c.latLng);
      nodes.add(DiagramNode(
        key: c.key,
        canvas: c.canvas,
        latLng: c.latLng,
        name: c.name,
        lines: c.lines,
        primaryColor: c.primaryColor,
      ));
    }

    // 4. For each line, build the octilinearized path.
    final paths = <DiagramLinePath>[];
    for (final group in groups) {
      final meta = svc.metadataFor(group.lineNumber);
      if (meta == null) continue;
      final color = Color(meta.colorValue);
      // Use aller as the canonical sequence. Skip retour: its path overlays
      // aller on the trunk; for V1 we don't double-render.
      final aller = group.aller;
      if (aller == null || aller.stops.length < 2) continue;

      final pts = <Offset>[];
      final stopIdx = <int>[];
      for (var i = 0; i < aller.stops.length; i++) {
        final ref = _StopRef(group.lineNumber, false, i);
        final node = stopToNode[ref];
        if (node == null) continue;
        if (pts.isEmpty) {
          pts.add(node.canvas);
          stopIdx.add(0);
          continue;
        }
        final prev = pts.last;
        final next = node.canvas;
        // Check if direct line is octilinear within tolerance.
        final dx = next.dx - prev.dx;
        final dy = next.dy - prev.dy;
        final ang = math.atan2(dy, dx);
        if (_isOctilinear(ang)) {
          pts.add(next);
          stopIdx.add(pts.length - 1);
        } else {
          // L-shape: choose elbow based on dominant axis.
          if (dx.abs() >= dy.abs()) {
            pts.add(Offset(next.dx, prev.dy));
          } else {
            pts.add(Offset(prev.dx, next.dy));
          }
          pts.add(next);
          stopIdx.add(pts.length - 1);
        }
      }

      paths.add(DiagramLinePath(
        lineNumber: group.lineNumber,
        color: color,
        displayName: meta.displayName,
        points: pts,
        stopIndices: stopIdx,
      ));
    }

    return NetworkDiagramLayout._(
      nodes: nodes,
      lines: paths,
      canvasSize: targetSize,
    );
  }

  static _NodeBuilder _findOrCreateCluster(
    List<_NodeBuilder> clusters,
    TransportStop stop,
    Color color,
    String lineNumber,
  ) {
    final stopNameNorm = _normalizeName(stop.name);
    for (final c in clusters) {
      final dist = _haversineKm(c.latLng, stop.position) * 1000;
      final sameName = stopNameNorm.isNotEmpty &&
          c.nameNorm.isNotEmpty &&
          c.nameNorm == stopNameNorm;
      if (sameName && dist <= _sameNameMeters) {
        c.lines.add(lineNumber);
        if (stop.name.length > c.name.length) {
          c.name = stop.name;
        }
        return c;
      }
      if (dist <= _proximityMeters) {
        c.lines.add(lineNumber);
        if (stop.name.length > c.name.length) {
          c.name = stop.name;
          c.nameNorm = stopNameNorm;
        }
        return c;
      }
    }
    final created = _NodeBuilder(
      key: '${stop.position.latitude.toStringAsFixed(5)},${stop.position.longitude.toStringAsFixed(5)}',
      latLng: stop.position,
      name: stop.name,
      nameNorm: stopNameNorm,
      primaryColor: color,
    );
    created.lines.add(lineNumber);
    clusters.add(created);
    return created;
  }

  static bool _isOctilinear(double angleRad) {
    // Octilinear angles: 0, ±π/4, ±π/2, ±3π/4, π.
    // V1 simplification : Manhattan only (0, ±π/2, π) — pas de 45°.
    const targets = <double>[0, math.pi / 2, math.pi, -math.pi / 2, -math.pi];
    for (final t in targets) {
      var diff = (angleRad - t).abs();
      if (diff > math.pi) diff = 2 * math.pi - diff;
      if (diff <= _octilinearEps) return true;
    }
    return false;
  }

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static String _normalizeName(String name) {
    var s = name.trim().toLowerCase();
    if (s.isEmpty) return s;
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final buf = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _NodeBuilder {
  final String key;
  final LatLng latLng;
  String name;
  String nameNorm;
  final Color primaryColor;
  final Set<String> lines = <String>{};
  Offset canvas = Offset.zero;
  int index = -1;

  _NodeBuilder({
    required this.key,
    required this.latLng,
    required this.name,
    required this.nameNorm,
    required this.primaryColor,
  });
}

class _StopRef {
  final String lineNumber;
  final bool isRetour;
  final int stopIndex;
  const _StopRef(this.lineNumber, this.isRetour, this.stopIndex);

  @override
  bool operator ==(Object other) =>
      other is _StopRef &&
      other.lineNumber == lineNumber &&
      other.isRetour == isRetour &&
      other.stopIndex == stopIndex;

  @override
  int get hashCode => Object.hash(lineNumber, isRetour, stopIndex);
}
