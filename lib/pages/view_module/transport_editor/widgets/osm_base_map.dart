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
  final InteractionOptions? interactionOptions;

  const OsmBaseMap({
    super.key,
    required this.controller,
    required this.children,
    this.initialCenter,
    this.initialZoom = 13,
    this.onTap,
    this.onLongPress,
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
        const _AttributionOverlay(),
      ],
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
