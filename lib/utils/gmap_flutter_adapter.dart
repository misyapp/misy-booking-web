// Adaptateur Google Maps → flutter_map.
//
// Migration du fond de carte (Google → OSM auto-hébergé) sans réécrire toute la
// logique : les positions/itinéraires restent typés `gmaps.LatLng` (gratuit, on
// n'instancie AUCUN widget GoogleMap), et on convertit en couches `flutter_map`
// au moment du rendu uniquement.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;

/// Conversions de coordonnées.
ll.LatLng toLL(gmaps.LatLng p) => ll.LatLng(p.latitude, p.longitude);
gmaps.LatLng toGM(ll.LatLng p) => gmaps.LatLng(p.latitude, p.longitude);

ll.LatLng? toLLn(gmaps.LatLng? p) => p == null ? null : toLL(p);

/// `gmaps.LatLngBounds` → `fm.LatLngBounds`.
fm.LatLngBounds toLLBounds(gmaps.LatLngBounds b) =>
    fm.LatLngBounds(toLL(b.northeast), toLL(b.southwest));

/// Polylines Google → flutter_map (couleur, épaisseur, pointillés conservés).
List<fm.Polyline> toFmPolylines(Iterable<gmaps.Polyline> polylines) {
  return polylines.map((p) {
    final dashed = p.patterns.isNotEmpty;
    return fm.Polyline(
      points: p.points.map(toLL).toList(),
      color: p.color,
      strokeWidth: p.width.toDouble(),
      pattern: dashed
          ? fm.StrokePattern.dashed(segments: const [10, 6])
          : const fm.StrokePattern.solid(),
    );
  }).toList();
}

/// Marqueurs Google → marqueurs flutter_map (widgets). L'icône Google est un
/// `BitmapDescriptor` opaque (non récupérable), donc on reconstruit un widget
/// d'après le `markerId` (sémantique connue du funnel). Le rendu est net
/// (widget Flutter) et plus simple que le pipeline canvas→bytes.
List<fm.Marker> toFmMarkers(Iterable<gmaps.Marker> markers) {
  return markers.map((m) {
    final id = m.markerId.value;
    return fm.Marker(
      point: toLL(m.position),
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: _markerWidget(id),
    );
  }).toList();
}

Widget _markerWidget(String id) {
  if (id == 'pickup') return _dot(const Color(0xFF1DBF73));
  if (id == 'destination') return _square(const Color(0xFFef3b30));
  if (id.startsWith('driver')) {
    return const _Pin(icon: Icons.local_taxi, color: Color(0xFF111111));
  }
  if (id.contains('origin')) return _dot(const Color(0xFF1DBF73));
  if (id.contains('dest')) return _square(const Color(0xFFef3b30));
  return _dot(const Color(0xFF2563EB));
}

Widget _dot(Color color) => Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
        ),
      ),
    );

Widget _square(Color color) => Center(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
        ),
      ),
    );

class _Pin extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Pin({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
        ),
        padding: const EdgeInsets.all(7),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

/// Cercles Google (rayon en mètres) → flutter_map (`useRadiusInMeter`).
List<fm.CircleMarker> toFmCircles(Iterable<gmaps.Circle> circles) {
  return circles
      .map((c) => fm.CircleMarker(
            point: toLL(c.center),
            radius: c.radius,
            useRadiusInMeter: true,
            color: c.fillColor,
            borderColor: c.strokeColor,
            borderStrokeWidth: c.strokeWidth.toDouble(),
          ))
      .toList();
}

/// Cadre la caméra sur un ensemble de points avec un padding (équivalent
/// `animateCamera(newLatLngBounds(...))`). Reproduit le cadrage "au-dessus du
/// bottom-sheet" via un padding asymétrique.
void fitBounds(
  fm.MapController controller,
  Iterable<gmaps.LatLng> points, {
  EdgeInsets padding = const EdgeInsets.all(48),
}) {
  final pts = points.map(toLL).toList();
  if (pts.isEmpty) return;
  controller.fitCamera(
    fm.CameraFit.bounds(
      bounds: fm.LatLngBounds.fromPoints(pts),
      padding: padding,
    ),
  );
}

/// Centre + zoom (équivalent `animateCamera(newLatLngZoom(...))`).
void moveTo(fm.MapController controller, gmaps.LatLng target, double zoom) {
  controller.move(toLL(target), zoom);
}

/// Distance (m) d'un point à la polyline la plus proche — portage de
/// `GoogleMapProvider.distanceToPolyline` côté géométrie pure.
double? distanceToPolyline(gmaps.LatLng target, List<gmaps.LatLng> line) {
  if (line.length < 2) return null;
  const dist = ll.Distance();
  final t = toLL(target);
  double? best;
  for (var i = 0; i < line.length - 1; i++) {
    final d = _distToSegment(t, toLL(line[i]), toLL(line[i + 1]), dist);
    if (best == null || d < best) best = d;
  }
  return best;
}

double _distToSegment(ll.LatLng p, ll.LatLng a, ll.LatLng b, ll.Distance dist) {
  // Approximation planaire locale (suffisante à l'échelle urbaine).
  final ax = a.longitude, ay = a.latitude;
  final bx = b.longitude, by = b.latitude;
  final px = p.longitude, py = p.latitude;
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  double t = len2 == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final proj = ll.LatLng(ay + t * dy, ax + t * dx);
  return dist(p, proj);
}

/// Zoom courant clampé aux bornes de la carte.
double clampZoom(double z) => z.clamp(5.0, 19.0).toDouble();
