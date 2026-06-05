import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../config/map_tiles_config.dart';

/// Fond de carte du funnel : tuiles **OSM vectorielles auto-hébergées (PMTiles)**
/// rendues via `flutter_map`, en remplacement de Google Maps (suppression du
/// coût Dynamic Maps). Réutilisable par tous les écrans web (funnel, live share,
/// détail course). Les couches métier (marqueurs, itinéraires, cercles) sont
/// passées via [children] — exactement comme `GoogleMap(markers/polylines/...)`.
class BookingMap extends StatefulWidget {
  final MapController controller;
  final LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;

  /// Contraint le pan à une zone (équivalent `cameraTargetBounds` Google).
  final LatLngBounds? cameraBounds;

  /// Couches flutter_map : MarkerLayer / PolylineLayer / CircleLayer…
  final List<Widget> children;

  final void Function(TapPosition, LatLng)? onTap;
  final void Function(MapCamera, bool)? onPositionChanged;

  /// Bascule imagerie satellite (confirmation du point de dépose).
  final bool satellite;

  final bool showZoomControls;

  /// Cadrage initial sur des bounds (prioritaire sur center/zoom) —
  /// équivalent du fit `onMapCreated` Google pour les cartes statiques.
  final CameraFit? initialCameraFit;

  /// `false` = carte figée (mini-cartes récap : aucun geste).
  final bool interactive;
  /// Molette/pinch : zoome AUTOUR DU CENTRE de la carte au lieu du curseur.
  /// Utilisé en mode sélection au pin (le bonhomme = camera.center : zoomer
  /// vers le curseur déplaçait sa position GPS à chaque cran de molette).
  final bool zoomAroundCenter;

  /// Fond DÉSATURÉ (vue réseau Transport en commun) : les rubans LOOM
  /// doivent dominer — le raster passe sous un ColorFilter (saturation
  /// réduite + léger éclaircissement). Réglage client uniquement : les
  /// labels de voirie mineure restent (masquage = style serveur dédié,
  /// cf. tools/network/README.md).
  final bool muted;

  const BookingMap({
    super.key,
    required this.controller,
    required this.initialCenter,
    this.initialZoom = 13,
    this.minZoom = 5,
    this.maxZoom = 19,
    this.cameraBounds,
    this.children = const [],
    this.onTap,
    this.onPositionChanged,
    this.satellite = false,
    this.showZoomControls = true,
    this.initialCameraFit,
    this.muted = false,
    this.interactive = true,
    this.zoomAroundCenter = false,
  });

  /// Provider PMTiles + thème, chargés **une seule fois** et partagés entre
  /// toutes les instances de carte (le PMTiles est ouvert une fois).
  static Future<_MapAssets>? _assetsFuture;

  static Future<_MapAssets> _loadAssets() async {
    final styleStr = await rootBundle.loadString(MapTilesConfig.styleAsset);
    final theme =
        vtr.ThemeReader().read(jsonDecode(styleStr) as Map<String, dynamic>);
    // Voie réseau XYZ (dart2js-friendly) si un template est fourni, sinon
    // lecture directe du .pmtiles (WASM uniquement — Uint64 KO en dart2js).
    final VectorTileProvider provider;
    if (MapTilesConfig.vectorTileUrlTemplate.isNotEmpty) {
      provider = NetworkVectorTileProvider(
        urlTemplate: MapTilesConfig.vectorTileUrlTemplate,
        maximumZoom: 14,
      );
    } else {
      provider = await PmTilesVectorTileProvider.fromSource(
        MapTilesConfig.effectivePmtilesUrl,
      );
    }
    return _MapAssets(theme, provider);
  }

  @override
  State<BookingMap> createState() => _BookingMapState();
}

class _MapAssets {
  final vtr.Theme theme;
  final VectorTileProvider provider;
  _MapAssets(this.theme, this.provider);
}

class _BookingMapState extends State<BookingMap> {
  @override
  void initState() {
    super.initState();
    BookingMap._assetsFuture ??= BookingMap._loadAssets();
  }

  /// Le fond raster (charte) ou satellite ne nécessite ni provider ni thème
  /// vectoriel → on évite le chemin `vector_map_tiles` (cassé sur Flutter web).
  bool get _rasterMode =>
      widget.satellite || MapTilesConfig.rasterTileUrlTemplate.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_rasterMode) {
      return _map(_rasterBasemap());
    }
    // Chemin vectoriel (legacy / build WASM uniquement) : nécessite le provider.
    return FutureBuilder<_MapAssets>(
      future: BookingMap._assetsFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return _MapError(error: snap.error.toString());
        }
        if (!snap.hasData) {
          return const ColoredBox(
            color: Color(0xFFE5E9EC),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          );
        }
        final assets = snap.data!;
        return _map(VectorTileLayer(
          theme: assets.theme,
          tileProviders:
              TileProviders({MapTilesConfig.sourceName: assets.provider}),
          concurrency: 0,
          layerMode: VectorTileLayerMode.vector,
          maximumZoom: 19,
        ));
      },
    );
  }

  /// Fond raster : satellite Esri, sinon tuiles charte (tileserver-gl / pré-rendu).
  /// tileserver-gl rastérise le style à TOUS les zooms (overzoom serveur des
  /// données vectorielles z14, TileJSON maxzoom 20) → `maxNativeZoom: 19`,
  /// sinon flutter_map étire les tuiles z14 (carte/labels flous, zoom « mort »).
  /// `{r}` + `retinaMode` servent les tuiles @2x sur écrans haute densité.
  Widget _rasterBasemap() {
    if (widget.satellite) {
      return TileLayer(
        urlTemplate: MapTilesConfig.esriSatelliteUrl,
        maxNativeZoom: 19,
        maxZoom: 19,
        userAgentPackageName: 'app.misy.book',
        tileProvider: NetworkTileProvider(),
      );
    }
    final tiles = TileLayer(
      urlTemplate:
          MapTilesConfig.rasterTileUrlTemplate.replaceFirst('.png', '{r}.png'),
      retinaMode: RetinaMode.isHighDensity(context),
      maxNativeZoom: 19,
      maxZoom: 19,
      userAgentPackageName: 'app.misy.book',
      tileProvider: NetworkTileProvider(),
    );
    if (!widget.muted) return tiles;
    // Saturation ~0.45 + éclaircissement léger : matrice standard de
    // désaturation (coefficients luma Rec. 601) + offset.
    const s = 0.45;
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        r + (1 - r) * s,
        g * (1 - s),
        b * (1 - s),
        0,
        14,
        r * (1 - s),
        g + (1 - g) * s,
        b * (1 - s),
        0,
        14,
        r * (1 - s),
        g * (1 - s),
        b + (1 - b) * s,
        0,
        14,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: tiles,
    );
  }

  /// Zoom molette/pinch ancré sur le CENTRE (cf. [BookingMap.zoomAroundCenter]).
  void _onPointerSignal(PointerSignalEvent e) {
    final camera = widget.controller.camera;
    double? newZoom;
    if (e is PointerScrollEvent) {
      // Même sensibilité que flutter_map (scrollWheelVelocity 0.005).
      newZoom = camera.zoom - e.scrollDelta.dy * 0.005;
    } else if (e is PointerScaleEvent) {
      // Pinch trackpad macOS (cf. piège PointerScaleEvent du plan schématique).
      newZoom = camera.zoom + math.log(e.scale) / math.ln2;
    }
    if (newZoom == null) return;
    widget.controller.move(
      camera.center,
      newZoom.clamp(widget.minZoom, widget.maxZoom),
    );
  }

  Widget _map(Widget basemap) {
    final map = FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
          initialCenter: widget.initialCenter,
          initialZoom: widget.initialZoom,
          initialCameraFit: widget.initialCameraFit,
          minZoom: widget.minZoom,
          maxZoom: widget.maxZoom,
          onTap: widget.onTap,
          onPositionChanged: widget.onPositionChanged,
          cameraConstraint: widget.cameraBounds != null
              ? CameraConstraint.contain(bounds: widget.cameraBounds!)
              : const CameraConstraint.unconstrained(),
          interactionOptions: InteractionOptions(
            flags: widget.interactive
                ? (widget.zoomAroundCenter
                    ? InteractiveFlag.all &
                        ~InteractiveFlag.rotate &
                        ~InteractiveFlag.scrollWheelZoom
                    : InteractiveFlag.all & ~InteractiveFlag.rotate)
                : InteractiveFlag.none,
          ),
        ),
        children: [
          basemap,
          ...widget.children,
          if (widget.showZoomControls)
            _ZoomControls(controller: widget.controller),
          _Attribution(satellite: widget.satellite),
        ],
      );
    if (!widget.zoomAroundCenter) return map;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _onPointerSignal,
      child: map,
    );
  }
}

/// Boutons +/- (équivalent `zoomControlsEnabled` Google).
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
            _btn(Icons.add, () => _zoom(1)),
            const SizedBox(height: 6),
            _btn(Icons.remove, () => _zoom(-1)),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => Material(
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

/// Attribution obligatoire (OSM, + Esri en mode satellite).
class _Attribution extends StatelessWidget {
  final bool satellite;
  const _Attribution({required this.satellite});

  @override
  Widget build(BuildContext context) {
    final text = satellite ? 'Tiles © Esri' : '© OpenStreetMap contributors';
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GestureDetector(
            onTap: satellite
                ? null
                : () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
            child: Text(text,
                style: const TextStyle(fontSize: 10, color: Colors.black87)),
          ),
        ),
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  final String error;
  const _MapError({required this.error});
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFE5E9EC),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Carte indisponible\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ),
      );
}
