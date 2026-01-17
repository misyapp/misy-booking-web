import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Classe utilitaire pour gérer les problèmes de zoom Google Maps sur iOS
/// Solution complète pour l'application Misy
class MapUtils {
  // ❌ PAS DE FALLBACK - Toujours utiliser la vraie position GPS
  static const double _defaultZoom = 14.0;
  static const double _minZoom = 1.0;  // Permet zoom out mais départ à 12.0
  static const double _maxZoom = 18.0;

  /// Configure la GoogleMap avec les paramètres optimisés pour iOS
  /// - Zoom initial 12.0 sur Madagascar en attendant le GPS
  /// - Padding safe pour les bottom sheets
  /// - PAS DE FALLBACK fictif - Attend le vrai GPS puis recentre
  static Widget buildOptimizedGoogleMap({
    required Function(GoogleMapController) onMapCreated,
    required Set<Marker> markers,
    required Set<Polyline> polylines,
    LatLng? initialPosition,
    double bottomPadding = 0,
    Function(CameraPosition)? onCameraMove,
    VoidCallback? onCameraIdle,
  }) {
    // Position initiale : GPS réel ou Madagascar en attendant le GPS
    final initialTarget = initialPosition ?? const LatLng(-18.9, 47.5);
    // Zoom raisonnable en attendant GPS (pas de globe view)
    final initialZoom = initialPosition != null ? _defaultZoom : 12.0;
    
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) async {
        onMapCreated(controller);
        
        // CORRECTIF iOS : Forcer un recentrage après création sur iOS
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _iosZoomFix(controller, initialTarget);
        }
      },
      
      // CONFIGURATION ZOOM : Empêche les zooms extrêmes sur iOS
      minMaxZoomPreference: const MinMaxZoomPreference(_minZoom, _maxZoom),
      
      // Position initiale : GPS réel ou vue globe
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: initialZoom,
      ),
      
      // Markers et polylines
      markers: markers,
      polylines: polylines,
      
      // Configuration UI
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      
      // PADDING SAFE : Limité pour éviter les problèmes iOS
      padding: EdgeInsets.only(
        bottom: _calculateSafePadding(bottomPadding),
      ),
      
      // Callbacks
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
    );
  }

  /// Calcule un padding sécurisé pour éviter les problèmes de zoom iOS
  static double _calculateSafePadding(double requestedPadding) {
    if (Platform.isIOS) {
      // Sur iOS, limiter le padding à 40% de l'écran maximum
      return requestedPadding.clamp(0.0, 300.0);
    }
    return requestedPadding;
  }

  /// CORRECTIF iOS : Force un zoom approprié après création de la carte
  static Future<void> _iosZoomFix(GoogleMapController controller, LatLng position) async {
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: _defaultZoom,
            bearing: 0.0,
          ),
        ),
      );
      debugPrint('🍎 iOS zoom fix appliqué sur: $position');
    } catch (e) {
      debugPrint('❌ Erreur iOS zoom fix: $e');
    }
  }

  /// Centre la carte intelligemment selon le contexte
  /// - 1 point : centrage simple avec zoom par défaut
  /// - 2 points : fitBounds sécurisé avec marges
  /// - Aucun point : ne fait rien (pas de fallback)
  static Future<void> smartCenter({
    required GoogleMapController controller,
    LatLng? startPoint,
    LatLng? endPoint,
    LatLng? userPosition,
    double bottomSheetHeightRatio = 0.0,
  }) async {
    try {
      // Cas 1 : Deux points (départ + arrivée) → fitBounds
      if (startPoint != null && endPoint != null) {
        await _fitTwoPoints(controller, startPoint, endPoint, bottomSheetHeightRatio);
        return;
      }

      // Cas 2 : Un seul point → centrage simple
      final singlePoint = startPoint ?? endPoint ?? userPosition;
      if (singlePoint != null) {
        await _centerOnSinglePoint(controller, singlePoint);
        return;
      }

      // Cas 3 : Aucun point → ne rien faire
      debugPrint('⚠️ Aucun point disponible pour le centrage');

    } catch (e) {
      debugPrint('❌ Erreur smartCenter: $e');
    }
  }

  /// FitBounds sécurisé pour deux points avec correctif iOS
  static Future<void> _fitTwoPoints(
    GoogleMapController controller,
    LatLng point1,
    LatLng point2,
    double bottomSheetHeightRatio,
  ) async {
    // Calculer les bounds
    final bounds = _calculateBounds([point1, point2]);
    
    if (Platform.isIOS) {
      // CORRECTIF iOS : Calcul manuel du zoom pour éviter le dézoom extrême
      await _iosSafeFitBounds(controller, bounds, bottomSheetHeightRatio);
    } else {
      // Android : utilisation standard
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
    
    debugPrint('🗺️ FitBounds: ${point1} → ${point2}');
  }

  /// Centrage simple sur un point unique
  static Future<void> _centerOnSinglePoint(GoogleMapController controller, LatLng point) async {
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: _defaultZoom,
          bearing: 0.0,
        ),
      ),
    );
    debugPrint('🎯 Centré sur: $point');
  }

  /// CORRECTIF iOS : FitBounds sécurisé avec calcul manuel du zoom
  static Future<void> _iosSafeFitBounds(
    GoogleMapController controller,
    LatLngBounds bounds,
    double bottomSheetHeightRatio,
  ) async {
    // Calculer le centre des bounds
    final center = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );

    // Calculer les spans pour déterminer le zoom approprié
    final latSpan = (bounds.northeast.latitude - bounds.southwest.latitude).abs();
    final lngSpan = (bounds.northeast.longitude - bounds.southwest.longitude).abs();
    final maxSpan = math.max(latSpan, lngSpan);

    // ZOOM SÉCURISÉ : Calcul basé sur les spans géographiques
    double zoom = _defaultZoom;
    if (maxSpan > 0.5) {
      zoom = 9.0;  // Très grande distance
    } else if (maxSpan > 0.2) {
      zoom = 10.0;
    } else if (maxSpan > 0.1) {
      zoom = 11.0;
    } else if (maxSpan > 0.05) {
      zoom = 12.0;
    } else if (maxSpan > 0.02) {
      zoom = 13.0;
    } else if (maxSpan > 0.01) {
      zoom = 14.0;
    } else {
      zoom = 15.0;
    }

    // Ajustement pour bottom sheet : dézoomer légèrement si grande bottom sheet
    if (bottomSheetHeightRatio > 0.5) {
      zoom -= 0.5;
    }

    // S'assurer que le zoom reste dans les limites sécurisées
    zoom = zoom.clamp(_minZoom, _maxZoom);

    // Appliquer le zoom calculé
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: center,
          zoom: zoom,
          bearing: 0.0,
        ),
      ),
    );

    debugPrint('🍎 iOS SafeFitBounds: zoom=$zoom, span=$maxSpan');
  }

  /// Calcule les bounds optimaux pour une liste de points
  static LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      // Pas de fallback - retourner bounds par défaut (sera ignoré par l'appelant)
      return LatLngBounds(
        southwest: const LatLng(-90, -180),
        northeast: const LatLng(90, 180),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Ajouter une marge de sécurité (5% de chaque côté)
    final latMargin = (maxLat - minLat) * 0.05;
    final lngMargin = (maxLng - minLng) * 0.05;

    return LatLngBounds(
      southwest: LatLng(minLat - latMargin, minLng - lngMargin),
      northeast: LatLng(maxLat + latMargin, maxLng + lngMargin),
    );
  }

  /// Centrage adaptatif selon la taille de la bottom sheet
  /// Déplace le centre de la carte vers le haut si grande bottom sheet
  static Future<void> adaptiveCenter({
    required GoogleMapController controller,
    required LatLng position,
    required double screenHeight,
    required double bottomSheetHeightRatio,
  }) async {
    // Calculer l'offset vertical selon la taille de la bottom sheet
    double latOffset = 0.0;
    if (bottomSheetHeightRatio > 0.3) {
      // Plus la bottom sheet est grande, plus on remonte le centre
      final offsetRatio = (bottomSheetHeightRatio - 0.3) * 0.5;
      latOffset = offsetRatio * 0.01; // ~1km vers le nord
    }

    final adjustedPosition = LatLng(
      position.latitude + latOffset,
      position.longitude,
    );

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: adjustedPosition,
          zoom: _defaultZoom,
          bearing: 0.0,
        ),
      ),
    );

    debugPrint('📐 Centrage adaptatif: offset=$latOffset, ratio=$bottomSheetHeightRatio');
  }

  /// Vérifie si une position GPS est valide (dans Madagascar)
  static bool isValidMadagascarPosition(LatLng? position) {
    if (position == null) return false;

    // Bounds approximatifs de Madagascar
    const double minLat = -25.6;
    const double maxLat = -11.9;
    const double minLng = 43.2;
    const double maxLng = 50.5;

    return position.latitude >= minLat &&
           position.latitude <= maxLat &&
           position.longitude >= minLng &&
           position.longitude <= maxLng;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🧭 NOUVELLE FONCTION : Ajustement itinéraire au-dessus du bottom sheet
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 🎯 Ajuste l'affichage de l'itinéraire pour qu'il soit visible au-dessus du bottom sheet
  ///
  /// Cette fonction utilise une approche en 2 étapes :
  /// 1. **FitBounds** : Ajuste la caméra pour inclure tout l'itinéraire
  /// 2. **ScrollBy** : Décale la caméra vers le haut pour compenser le bottom sheet
  ///
  /// **Paramètres :**
  /// - `controller` : Le contrôleur Google Maps
  /// - `routePoints` : Les points de l'itinéraire (polyline décodée)
  /// - `context` : Le contexte pour obtenir les dimensions d'écran
  /// - `bottomViewRatio` : Le ratio de hauteur du bottom sheet (ex: 0.35 = 35% de l'écran)
  /// - `padding` : Le padding autour de l'itinéraire en pixels (défaut: 60)
  ///
  /// **Exemple d'utilisation :**
  /// ```dart
  /// await MapUtils.fitRouteAboveBottomView(
  ///   controller: mapController,
  ///   routePoints: decodedPolylinePoints,
  ///   context: context,
  ///   bottomViewRatio: 0.35,
  /// );
  /// ```
  ///
  /// **Critères de validation :**
  /// - ✅ L'itinéraire complet est visible sans être caché par le bottom sheet
  /// - ✅ Le zoom s'ajuste automatiquement à la longueur du trajet
  /// - ✅ Aucun dézoom excessif ni décalage latéral
  /// - ✅ Animation fluide, sans blocage
  static Future<void> fitRouteAboveBottomView({
    required GoogleMapController controller,
    required List<LatLng> routePoints,
    required BuildContext context,
    required double bottomViewRatio,
    double padding = 60.0,
  }) async {
    if (routePoints.isEmpty) {
      debugPrint('⚠️ fitRouteAboveBottomView: Liste de points vide, opération annulée');
      return;
    }

    if (routePoints.length == 1) {
      debugPrint('⚠️ fitRouteAboveBottomView: Un seul point, centrage simple');
      await controller.animateCamera(
        CameraUpdate.newLatLng(routePoints.first),
      );
      return;
    }

    try {
      debugPrint('🗺️ fitRouteAboveBottomView: Ajustement pour ${routePoints.length} points, bottom sheet: ${(bottomViewRatio * 100).toInt()}%');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 0️⃣ CAPTURER LES DONNÉES DU CONTEXT AVANT LES AWAIT
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final screenHeight = MediaQuery.of(context).size.height;
      final topPadding = MediaQuery.of(context).padding.top; // Status bar / notch

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 1️⃣ CALCULER LES BOUNDS DE L'ITINÉRAIRE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      double minLat = routePoints.first.latitude;
      double maxLat = routePoints.first.latitude;
      double minLng = routePoints.first.longitude;
      double maxLng = routePoints.first.longitude;

      for (var point in routePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      double latSpan = maxLat - minLat;
      double lngSpan = maxLng - minLng;

      debugPrint('📐 Bounds originaux: lat ${latSpan.toStringAsFixed(5)}° × lng ${lngSpan.toStringAsFixed(5)}°');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 2️⃣ CALCULER LA ZONE VISIBLE (entre status bar et bottom sheet)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final bottomSheetHeight = screenHeight * bottomViewRatio;
      final topMargin = topPadding + 60; // Status bar + marge de sécurité
      final visibleMapHeight = screenHeight - bottomSheetHeight - topMargin;

      debugPrint('📐 Zone visible: ${visibleMapHeight.toInt()}px (écran: ${screenHeight.toInt()}px, bottom: ${bottomSheetHeight.toInt()}px, top: ${topMargin.toInt()}px)');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 3️⃣ AJOUTER DES MARGES AUTOUR DU RECTANGLE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // Marge latérale de 10%
      final lngMargin = lngSpan * 0.10;
      minLng -= lngMargin;
      maxLng += lngMargin;

      // Marge en haut de 15% pour éviter que le polyline touche le status bar
      final topLatMargin = latSpan * 0.15;
      maxLat += topLatMargin;

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 4️⃣ CALCULER L'EXPANSION VERS LE SUD BASÉE SUR LA GÉOMÉTRIE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // Le centre de la carte doit être décalé pour que l'itinéraire
      // apparaisse centré dans la zone visible (pas au milieu de l'écran)
      //
      // Calcul : Si bottom sheet = 55%, zone visible = 45% en haut
      // Le centre de la zone visible est à 22.5% depuis le haut
      // Le centre de l'écran est à 50%
      // Donc on doit décaler le centre de la carte vers le bas de (50% - 22.5%) = 27.5%
      // Pour la carte, ça signifie agrandir les bounds vers le SUD

      final visibleAreaRatio = 1.0 - bottomViewRatio - (topMargin / screenHeight);
      final visibleCenterRatio = (topMargin / screenHeight) + (visibleAreaRatio / 2);
      final screenCenterRatio = 0.5;
      final offsetRatio = screenCenterRatio - visibleCenterRatio;

      // Convertir le ratio en expansion de latitude
      // Plus le bottom sheet est grand, plus on doit agrandir vers le sud
      final heightRatioOfRoute = latSpan / (latSpan + (latSpan * offsetRatio * 2));
      final expansionFactor = (1.0 / heightRatioOfRoute) - 1.0;

      // Ajouter une expansion additionnelle basée sur le bottom sheet ratio
      // pour garantir que même les petits trajets restent visibles
      final minExpansion = bottomViewRatio * 1.5;
      final finalExpansionFactor = math.max(expansionFactor, minExpansion);

      // Agrandir vers le SUD pour remonter l'itinéraire visuellement
      final extraLatSpan = (maxLat - minLat) * finalExpansionFactor;
      final adjustedMinLat = minLat - extraLatSpan;

      debugPrint('📐 Expansion: facteur=${finalExpansionFactor.toStringAsFixed(2)}, extra=${extraLatSpan.toStringAsFixed(5)}°');

      final bounds = LatLngBounds(
        southwest: LatLng(adjustedMinLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 5️⃣ AJUSTER LA CAMÉRA
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );

      debugPrint('✅ fitRouteAboveBottomView: Itinéraire ajusté avec succès');
    } catch (e) {
      debugPrint('❌ fitRouteAboveBottomView: Erreur lors de l\'ajustement: $e');
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLng(routePoints.first),
        );
      } catch (fallbackError) {
        debugPrint('❌ fitRouteAboveBottomView: Erreur fallback: $fallbackError');
      }
    }
  }

  /// 📏 Calcule les bounds à partir d'une liste de points
  ///
  /// Méthode utilitaire pour obtenir les bounds sans animer la caméra.
  /// Utile pour des calculs préalables ou des validations.
  static LatLngBounds? calculateBoundsFromPoints(List<LatLng> points) {
    if (points.isEmpty) return null;
    if (points.length == 1) {
      // Pour un seul point, créer un petit carré autour
      final point = points.first;
      const delta = 0.001; // ~100m
      return LatLngBounds(
        southwest: LatLng(point.latitude - delta, point.longitude - delta),
        northeast: LatLng(point.latitude + delta, point.longitude + delta),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// 📐 Calcule le centre géographique d'une liste de points
  static LatLng? calculateCenterFromPoints(List<LatLng> points) {
    if (points.isEmpty) return null;

    double totalLat = 0;
    double totalLng = 0;

    for (var point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }

    return LatLng(
      totalLat / points.length,
      totalLng / points.length,
    );
  }

  /// 🎯 Centre le rectangle de la polyline dans la zone visible au-dessus du bottom sheet
  ///
  /// Cette méthode calcule les bounds exacts de la polyline, puis centre la caméra
  /// de manière à ce que tout le rectangle soit visible dans la zone au-dessus du bottom sheet.
  ///
  /// **Approche** :
  /// 1. Calculer les bounds (rectangle englobant) de tous les points
  /// 2. Calculer le centre géographique du rectangle
  /// 3. Calculer le zoom optimal pour que tout soit visible
  /// 4. Décaler le centre vers le NORD pour compenser le bottom sheet
  /// 5. Appliquer ce centre décalé avec le zoom calculé
  ///
  /// **Paramètres** :
  /// - `controller` : Le contrôleur Google Maps
  /// - `routePoints` : Les points de l'itinéraire (polyline)
  /// - `context` : Le contexte pour obtenir les dimensions d'écran
  /// - `bottomViewRatio` : Le ratio du bottom sheet (ex: 0.55 = 55%)
  /// - `paddingPercent` : Padding en pourcentage du span (défaut: 0.15 = 15%)
  static Future<void> centerPolylineInVisibleArea({
    required GoogleMapController controller,
    required List<LatLng> routePoints,
    required BuildContext context,
    required double bottomViewRatio,
    double paddingPercent = 0.15,
  }) async {
    if (routePoints.isEmpty) {
      debugPrint('⚠️ centerPolylineInVisibleArea: Liste de points vide');
      return;
    }

    if (routePoints.length == 1) {
      debugPrint('⚠️ centerPolylineInVisibleArea: Un seul point, centrage simple');
      await controller.animateCamera(
        CameraUpdate.newLatLng(routePoints.first),
      );
      return;
    }

    try {
      // Capturer la hauteur d'écran AVANT tout await
      final screenHeight = MediaQuery.of(context).size.height;

      debugPrint(
          '🎯 centerPolylineInVisibleArea: ${routePoints.length} points, bottom sheet: ${(bottomViewRatio * 100).toInt()}%');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 1️⃣ CALCULER LES BOUNDS DU RECTANGLE DE LA POLYLINE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      double minLat = routePoints.first.latitude;
      double maxLat = routePoints.first.latitude;
      double minLng = routePoints.first.longitude;
      double maxLng = routePoints.first.longitude;

      for (var point in routePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      double latSpan = maxLat - minLat;
      double lngSpan = maxLng - minLng;

      debugPrint('📐 Rectangle de la polyline:');
      debugPrint('   Sud-Ouest: ${minLat.toStringAsFixed(6)}, ${minLng.toStringAsFixed(6)}');
      debugPrint('   Nord-Est: ${maxLat.toStringAsFixed(6)}, ${maxLng.toStringAsFixed(6)}');
      debugPrint('   Span: ${latSpan.toStringAsFixed(6)}° × ${lngSpan.toStringAsFixed(6)}°');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 2️⃣ AJOUTER DU PADDING AU RECTANGLE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final latPadding = latSpan * paddingPercent;
      final lngPadding = lngSpan * paddingPercent;

      minLat -= latPadding;
      maxLat += latPadding;
      minLng -= lngPadding;
      maxLng += lngPadding;

      latSpan = maxLat - minLat;
      lngSpan = maxLng - minLng;

      debugPrint('📐 Rectangle avec padding ${(paddingPercent * 100).toInt()}%:');
      debugPrint('   Nouveau span: ${latSpan.toStringAsFixed(6)}° × ${lngSpan.toStringAsFixed(6)}°');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 3️⃣ CALCULER LE CENTRE GÉOGRAPHIQUE DU RECTANGLE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      debugPrint('📍 Centre géographique du rectangle: ${centerLat.toStringAsFixed(6)}, ${centerLng.toStringAsFixed(6)}');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 4️⃣ CALCULER LE ZOOM OPTIMAL
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final maxSpan = math.max(latSpan, lngSpan);

      double zoom = _defaultZoom;
      if (maxSpan > 0.5) {
        zoom = 9.0;
      } else if (maxSpan > 0.2) {
        zoom = 10.0;
      } else if (maxSpan > 0.1) {
        zoom = 11.0;
      } else if (maxSpan > 0.05) {
        zoom = 12.0;
      } else if (maxSpan > 0.02) {
        zoom = 13.0;
      } else if (maxSpan > 0.01) {
        zoom = 14.0;
      } else if (maxSpan > 0.005) {
        zoom = 15.0;
      } else {
        zoom = 16.0;
      }

      zoom = zoom.clamp(_minZoom, _maxZoom);

      debugPrint('🔍 Zoom calculé: $zoom (pour span max: ${maxSpan.toStringAsFixed(6)}°)');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 5️⃣ CALCULER LE DÉCALAGE POUR CENTRER DANS LA ZONE VISIBLE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // Zone visible = zone au-dessus du bottom sheet
      final visibleAreaHeight = screenHeight * (1 - bottomViewRatio);

      // Centre de la zone visible (en pixels depuis le haut)
      final visibleAreaCenter = visibleAreaHeight / 2;

      // Centre de l'écran complet
      final screenCenter = screenHeight / 2;

      // Décalage en pixels vers le haut
      final offsetPixels = screenCenter - visibleAreaCenter;

      // Convertir le décalage pixels en degrés latitude
      // Facteur réduit pour éviter de pousser l'itinéraire trop haut
      // 0.5 garde l'itinéraire bien centré dans la zone visible au-dessus du bottom sheet
      const double correctionFactor = 0.5;
      final offsetDegrees = offsetPixels * (latSpan / visibleAreaHeight) * correctionFactor;

      // Nouveau centre décalé vers le SUD (latitude plus basse)
      // IMPORTANT : On SOUSTRAIT car pour afficher le rectangle plus HAUT sur l'écran,
      // la caméra doit regarder plus vers le SUD (latitude diminue)
      final adjustedCenterLat = centerLat - offsetDegrees;

      debugPrint('🧮 Calcul du décalage:');
      debugPrint('   Hauteur écran: ${screenHeight.toInt()}px');
      debugPrint('   Hauteur zone visible: ${visibleAreaHeight.toInt()}px (${((1 - bottomViewRatio) * 100).toInt()}%)');
      debugPrint('   Centre zone visible: ${visibleAreaCenter.toInt()}px depuis le haut');
      debugPrint('   Centre écran: ${screenCenter.toInt()}px depuis le haut');
      debugPrint('   Décalage pixels: ${offsetPixels.toInt()}px');
      debugPrint('   Facteur correctif: $correctionFactor');
      debugPrint('   Décalage latitude: ${offsetDegrees.toStringAsFixed(6)}°');
      debugPrint('   Centre ajusté: ${adjustedCenterLat.toStringAsFixed(6)}, $centerLng');

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 6️⃣ APPLIQUER LE CENTRE AJUSTÉ AVEC LE ZOOM CALCULÉ
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(adjustedCenterLat, centerLng),
            zoom: zoom,
            bearing: 0.0,
          ),
        ),
      );

      debugPrint('✅ centerPolylineInVisibleArea: Rectangle centré avec succès');
    } catch (e) {
      debugPrint('❌ centerPolylineInVisibleArea: Erreur: $e');
    }
  }
}