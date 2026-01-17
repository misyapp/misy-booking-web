import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/map_utils.dart';

/// Widget Google Map optimisé pour l'application Misy
/// Résout les problèmes de zoom iOS avec bottom sheets
class MisyGoogleMap extends StatefulWidget {
  final LatLng? userPosition;
  final LatLng? startPoint;
  final LatLng? endPoint;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final double bottomSheetHeightRatio;
  final Function(GoogleMapController)? onMapCreated;
  final Function(CameraPosition)? onCameraMove;
  final VoidCallback? onCameraIdle;

  const MisyGoogleMap({
    Key? key,
    this.userPosition,
    this.startPoint,
    this.endPoint,
    this.markers = const {},
    this.polylines = const {},
    this.bottomSheetHeightRatio = 0.0,
    this.onMapCreated,
    this.onCameraMove,
    this.onCameraIdle,
  }) : super(key: key);

  @override
  State<MisyGoogleMap> createState() => _MisyGoogleMapState();
}

class _MisyGoogleMapState extends State<MisyGoogleMap> {
  GoogleMapController? _controller;
  bool _isMapReady = false;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = screenHeight * widget.bottomSheetHeightRatio;

    return MapUtils.buildOptimizedGoogleMap(
      onMapCreated: _handleMapCreated,
      markers: widget.markers,
      polylines: widget.polylines,
      initialPosition: _getInitialPosition(),
      bottomPadding: bottomPadding,
      onCameraMove: widget.onCameraMove,
      onCameraIdle: widget.onCameraIdle,
    );
  }

  /// Détermine la position initiale de la carte
  /// Retourne Madagascar center si pas de position → zoom 12.0 en attendant
  LatLng? _getInitialPosition() {
    // Priorité : Position utilisateur → Point de départ → Madagascar center
    if (widget.userPosition != null) {
      return widget.userPosition;
    }

    if (widget.startPoint != null) {
      return widget.startPoint;
    }

    // Pas de position → retourner null, MapUtils utilisera Madagascar center avec zoom 12.0
    return null;
  }

  /// Gestionnaire de création de carte avec centrage intelligent
  void _handleMapCreated(GoogleMapController controller) async {
    _controller = controller;
    _isMapReady = true;

    // Callback utilisateur
    widget.onMapCreated?.call(controller);

    // CENTRAGE INTELLIGENT après création
    await _performSmartCentering();

    // RECENTRAGE lors des changements de bottom sheet (sur iOS uniquement)
    if (Platform.isIOS) {
      _setupBottomSheetListener();
    }
  }

  /// Effectue le centrage intelligent selon le contexte
  Future<void> _performSmartCentering() async {
    if (!_isMapReady || _controller == null) return;

    await Future.delayed(const Duration(milliseconds: 300));

    await MapUtils.smartCenter(
      controller: _controller!,
      startPoint: widget.startPoint,
      endPoint: widget.endPoint,
      userPosition: widget.userPosition,
      bottomSheetHeightRatio: widget.bottomSheetHeightRatio,
    );
  }

  /// Configure l'écoute des changements de bottom sheet (iOS)
  void _setupBottomSheetListener() {
    // Sur iOS, recentrer quand la bottom sheet change de taille
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleBottomSheetChange();
      }
    });
  }

  /// Gère les changements de taille de bottom sheet
  void _handleBottomSheetChange() async {
    if (!_isMapReady || _controller == null) return;

    // Si on a les deux points, refaire un fitBounds
    if (widget.startPoint != null && widget.endPoint != null) {
      await MapUtils.smartCenter(
        controller: _controller!,
        startPoint: widget.startPoint,
        endPoint: widget.endPoint,
        bottomSheetHeightRatio: widget.bottomSheetHeightRatio,
      );
      return;
    }

    // Sinon, centrage adaptatif sur la position principale
    final position = widget.startPoint ?? widget.userPosition;
    if (position != null) {
      await MapUtils.adaptiveCenter(
        controller: _controller!,
        position: position,
        screenHeight: MediaQuery.of(context).size.height,
        bottomSheetHeightRatio: widget.bottomSheetHeightRatio,
      );
    }
  }

  /// Méthode publique pour recentrer la carte manuellement
  Future<void> recenter() async {
    if (_controller != null && _isMapReady) {
      await _performSmartCentering();
    }
  }

  /// Méthode publique pour obtenir le contrôleur de carte
  GoogleMapController? get controller => _controller;

  @override
  void didUpdateWidget(MisyGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recentrer si les points ont changé
    if (oldWidget.startPoint != widget.startPoint ||
        oldWidget.endPoint != widget.endPoint ||
        oldWidget.bottomSheetHeightRatio != widget.bottomSheetHeightRatio) {
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSmartCentering();
      });
    }
  }
}

/// Extension pour faciliter l'utilisation dans les pages existantes
extension MisyGoogleMapHelper on State {
  /// Crée un widget MisyGoogleMap prêt à l'emploi pour les écrans de paiement
  Widget buildPaymentScreenMap({
    required LatLng? userPosition,
    required LatLng? startPoint,
    required LatLng? endPoint,
    required Set<Marker> markers,
    required Set<Polyline> polylines,
    double bottomSheetHeightRatio = 0.5, // 50% par défaut pour écran paiement
    Function(GoogleMapController)? onMapCreated,
  }) {
    return MisyGoogleMap(
      userPosition: userPosition,
      startPoint: startPoint,
      endPoint: endPoint,
      markers: markers,
      polylines: polylines,
      bottomSheetHeightRatio: bottomSheetHeightRatio,
      onMapCreated: onMapCreated,
    );
  }

  /// Crée un widget MisyGoogleMap pour l'écran d'accueil
  Widget buildHomeScreenMap({
    required LatLng? userPosition,
    required Set<Marker> markers,
    double bottomSheetHeightRatio = 0.1, // 10% par défaut pour accueil
    Function(GoogleMapController)? onMapCreated,
    Function(CameraPosition)? onCameraMove,
    VoidCallback? onCameraIdle,
  }) {
    return MisyGoogleMap(
      userPosition: userPosition,
      markers: markers,
      bottomSheetHeightRatio: bottomSheetHeightRatio,
      onMapCreated: onMapCreated,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
    );
  }
}