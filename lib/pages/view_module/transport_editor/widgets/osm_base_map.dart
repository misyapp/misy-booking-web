import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Carte flutter_map avec tiles OSM + attribution obligatoire.
/// Centre par défaut sur Antananarivo.
class OsmBaseMap extends StatelessWidget {
  final MapController controller;
  final LatLng? initialCenter;
  final double initialZoom;
  final List<Widget> children;
  final void Function(TapPosition, LatLng)? onTap;
  final void Function(TapPosition, LatLng)? onLongPress;
  final void Function(MapEvent)? onMapEvent;
  final InteractionOptions? interactionOptions;

  const OsmBaseMap({
    super.key,
    required this.controller,
    required this.children,
    this.initialCenter,
    this.initialZoom = 13,
    this.onTap,
    this.onLongPress,
    this.onMapEvent,
    this.interactionOptions,
  });

  static const LatLng antananarivo = LatLng(-18.8792, 47.5079);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter ?? antananarivo,
        initialZoom: initialZoom,
        minZoom: 5,
        maxZoom: 19,
        onTap: onTap,
        onLongPress: onLongPress,
        onMapEvent: onMapEvent,
        interactionOptions: interactionOptions ??
            const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.misy.booking_web',
          maxZoom: 19,
          tileProvider: NetworkTileProvider(),
        ),
        ...children,
        _ZoomControls(controller: controller),
        const _AttributionOverlay(),
      ],
    );
  }
}

/// Boutons +/− en overlay à droite de la carte. Utilisent `MapController.move`
/// avec le centre courant et le zoom ±1, clampé [5, 19] pour cohérence avec
/// `minZoom`/`maxZoom` de `MapOptions`.
class _ZoomControls extends StatelessWidget {
  final MapController controller;
  const _ZoomControls({required this.controller});

  void _zoom(double delta) {
    final cam = controller.camera;
    final next = (cam.zoom + delta).clamp(5.0, 19.0);
    if (next == cam.zoom) return;
    controller.move(cam.center, next);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomButton(icon: Icons.add, onTap: () => _zoom(1)),
            const SizedBox(height: 6),
            _ZoomButton(icon: Icons.remove, onTap: () => _zoom(-1)),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}

class _AttributionOverlay extends StatelessWidget {
  const _AttributionOverlay();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
