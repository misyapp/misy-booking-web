import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rider_ride_hailing_app/services/osm_stops_service.dart';

/// Affiche les arrêts de bus OSM dans la bbox visible de la carte.
/// Le nom est affiché sous le dot quand le zoom est suffisant.
class OsmStopsLayer extends StatelessWidget {
  final MapCamera camera;
  final void Function(OsmStop stop) onStopTap;

  /// Cap large pour tenir toute la zone Tana (~1800 stops max)
  static const int _maxMarkers = 2000;

  const OsmStopsLayer({
    super.key,
    required this.camera,
    required this.onStopTap,
  });

  @override
  Widget build(BuildContext context) {
    if (camera.zoom < 11) {
      return const SizedBox.shrink();
    }
    final bounds = camera.visibleBounds;
    final stops = OsmStopsService.instance.inBounds(
      latMin: bounds.south,
      latMax: bounds.north,
      lngMin: bounds.west,
      lngMax: bounds.east,
    );
    final capped = stops.length > _maxMarkers
        ? stops.sublist(0, _maxMarkers)
        : stops;

    final showLabels = camera.zoom >= 15;
    final dotSize = camera.zoom >= 14 ? 14.0 : 10.0;

    return MarkerLayer(
      markers: capped
          .map((s) => Marker(
                point: s.position,
                width: showLabels ? 120 : dotSize + 6,
                height: showLabels ? 44 : dotSize + 6,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => onStopTap(s),
                  child: Tooltip(
                    message: s.displayName,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: s.hasName
                                ? const Color(0xDD1565C0)
                                : const Color(0xDD757575),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        if (showLabels && s.hasName)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color: const Color(0x33000000), width: 0.5),
                            ),
                            child: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
