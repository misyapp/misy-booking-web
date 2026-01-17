import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// SOLUTION RADICALE pour les problèmes de zoom anarchique Google Maps sur iOS
/// Cette classe remplace complètement tous les appels à newLatLngBounds qui causent les bugs
class IOSMapFix {
  // Configuration zoom - permet zoom out mais départ à niveau raisonnable
  static const double minZoom = 1.0;   // Zoom minimal permis (mais départ à 12.0 si pas de GPS)
  static const double maxZoom = 18.0;
  static const double defaultZoom = 14.0;

  // ❌ PAS DE POSITION FALLBACK - Toujours utiliser la vraie position GPS
  
  /// MÉTHODE PRINCIPALE : Adapte la carte pour afficher l'itinéraire dans la zone visible
  ///
  /// LOGIQUE EN 3 ÉTAPES :
  /// 1. Récupère les limites NSEO (Nord/Sud/Est/Ouest) de l'itinéraire
  /// 2. Calcule le zoom et la position optimale pour la zone visible (au-dessus du bottom sheet)
  /// 3. Anime la caméra vers cette position
  static Future<void> safeFitBounds({
    required GoogleMapController controller,
    required List<LatLng> points,
    double bottomSheetRatio = 0.0,
    String debugSource = "unknown",
  }) async {
    if (points.isEmpty) {
      debugPrint('⚠️ IOSMapFix: Aucun point fourni, pas de mouvement');
      return;
    }

    debugPrint('📍 IOSMapFix: Adaptation carte pour ${points.length} points (bottomSheet: ${(bottomSheetRatio * 100).toInt()}%, source: $debugSource)');

    // Sur iOS et Android, utiliser le même calcul manuel pour cohérence
    await _fitBoundsToVisibleArea(controller, points, bottomSheetRatio, debugSource);
  }

  /// ÉTAPE 2 : Adapter la carte pour que l'itinéraire soit visible dans la zone au-dessus du bottom sheet
  static Future<void> _fitBoundsToVisibleArea(
    GoogleMapController controller,
    List<LatLng> points,
    double bottomSheetRatio,
    String debugSource,
  ) async {
    try {
      // ÉTAPE 2.1 : Récupérer les limites NSEO (Nord/Sud/Est/Ouest) de l'itinéraire
      double nord = points.map((p) => p.latitude).reduce(math.max);   // Latitude maximale
      double sud = points.map((p) => p.latitude).reduce(math.min);    // Latitude minimale
      double est = points.map((p) => p.longitude).reduce(math.max);   // Longitude maximale
      double ouest = points.map((p) => p.longitude).reduce(math.min); // Longitude minimale

      double latSpan = nord - sud;
      double lngSpan = est - ouest;

      debugPrint('🧭 IOSMapFix: Limites NSEO de l\'itinéraire:');
      debugPrint('   Nord:  ${nord.toStringAsFixed(6)}° (maxLat)');
      debugPrint('   Sud:   ${sud.toStringAsFixed(6)}° (minLat)');
      debugPrint('   Est:   ${est.toStringAsFixed(6)}° (maxLng)');
      debugPrint('   Ouest: ${ouest.toStringAsFixed(6)}° (minLng)');
      debugPrint('   Span: ${latSpan.toStringAsFixed(6)}° × ${lngSpan.toStringAsFixed(6)}°');

      // ÉTAPE 2.2 : Ajouter des marges pour que l'itinéraire ne touche pas les bords
      double marginRatio = 0.10; // 10% de marge autour de l'itinéraire (conservateur)
      double marginLat = latSpan * marginRatio;
      double marginLng = lngSpan * marginRatio;

      // Agrandir les bounds avec les marges
      double nordAvecMarge = nord + marginLat;
      double sudAvecMarge = sud - marginLat;
      double estAvecMarge = est + marginLng;
      double ouestAvecMarge = ouest - marginLng;

      // ÉTAPE 2.3 : Calculer le centre géographique de l'itinéraire
      double centreLat = (nordAvecMarge + sudAvecMarge) / 2;
      double centreLng = (estAvecMarge + ouestAvecMarge) / 2;

      // ÉTAPE 2.4 : Calculer le zoom basé sur le span RÉEL de l'itinéraire (avec marges)
      // NE PAS ajuster le span pour le bottom sheet - on ajuste seulement la position
      double latSpanAvecMarge = nordAvecMarge - sudAvecMarge;
      double lngSpanAvecMarge = estAvecMarge - ouestAvecMarge;
      double maxSpan = math.max(latSpanAvecMarge, lngSpanAvecMarge);

      double zoom = _calculateSafeZoom(maxSpan);

      debugPrint('🔧 IOSMapFix: Calcul zoom:');
      debugPrint('   Span avec marges: ${latSpanAvecMarge.toStringAsFixed(6)}° × ${lngSpanAvecMarge.toStringAsFixed(6)}°');
      debugPrint('   Zoom calculé: $zoom');

      // ÉTAPE 2.5 : Déplacer le centre vers le haut pour compenser le bottom sheet
      // L'itinéraire doit apparaître au CENTRE de la zone visible (pas au centre de l'écran)
      // Pour cela, on doit déplacer la caméra vers le SUD (diminuer latitude)

      // Calculer le span visible à l'écran pour ce zoom
      double screenLatSpan = 1.0 / math.pow(2, zoom - 10);

      // Déplacement nécessaire = (bottomSheetRatio / 2) de l'écran
      // Facteur de correction réduit pour éviter de pousser l'itinéraire trop haut
      // 0.5 garde l'itinéraire bien centré dans la zone visible au-dessus du bottom sheet
      const double correctionFactor = 0.5;
      double offsetRatio = bottomSheetRatio / 2.0 * correctionFactor;
      double latitudeOffset = -offsetRatio * screenLatSpan; // Négatif = vers le sud

      double centreAjuste = centreLat + latitudeOffset;

      debugPrint('📐 IOSMapFix: Ajustement vertical:');
      debugPrint('   Centre original: ${centreLat.toStringAsFixed(6)}°');
      debugPrint('   Offset: ${latitudeOffset.toStringAsFixed(6)}° (vers SUD)');
      debugPrint('   Centre ajusté: ${centreAjuste.toStringAsFixed(6)}°');

      final targetPosition = LatLng(centreAjuste, centreLng);

      // ÉTAPE 2.6 : Animer la caméra vers la position calculée
      debugPrint('🎯 IOSMapFix: Animation vers position: $targetPosition, zoom: $zoom');

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: targetPosition,
            zoom: zoom,
            bearing: 0.0,
          ),
        ),
      );

      debugPrint('✅ IOSMapFix: Itinéraire adapté avec succès dans la zone visible');

    } catch (e) {
      debugPrint('❌ IOSMapFix: Erreur adaptation: $e');
    }
  }

  /// Calcule un zoom sécurisé basé sur la distance géographique
  static double _calculateSafeZoom(double maxSpan) {
    // Mapping distance → zoom avec limites strictes
    double zoom;
    
    if (maxSpan > 1.0) {        // > 111 km
      zoom = 9.0;
    } else if (maxSpan > 0.5) { // 55-111 km
      zoom = 10.0;
    } else if (maxSpan > 0.2) { // 22-55 km
      zoom = 11.0;
    } else if (maxSpan > 0.1) { // 11-22 km
      zoom = 12.0;
    } else if (maxSpan > 0.05) { // 5.5-11 km
      zoom = 13.0;
    } else if (maxSpan > 0.02) { // 2.2-5.5 km
      zoom = 14.0;
    } else if (maxSpan > 0.01) { // 1.1-2.2 km
      zoom = 15.0;
    } else {                    // < 1.1 km
      zoom = 16.0;
    }
    
    // SÉCURITÉ ABSOLUE : forcer dans les limites
    zoom = zoom.clamp(minZoom, maxZoom);
    
    debugPrint('🎯 IOSMapFix: Span=$maxSpan → Zoom=$zoom');
    return zoom;
  }


  /// Centre la carte sur un point unique (pour position utilisateur)
  static Future<void> centerOnPoint({
    required GoogleMapController controller,
    required LatLng point,
    double zoom = defaultZoom,
    String debugSource = "unknown",
  }) async {
    try {
      // Toujours utiliser un zoom sécurisé
      double safeZoom = zoom.clamp(minZoom, maxZoom);
      
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: point,
            zoom: safeZoom,
            bearing: 0.0,
          ),
        ),
      );
      
      debugPrint('📍 IOSMapFix: Centré sur $point avec zoom $safeZoom (source: $debugSource)');
    } catch (e) {
      debugPrint('❌ IOSMapFix: Erreur centrage point: $e');
    }
  }

  /// Configuration GoogleMap avec paramètres anti-zoom anarchique
  /// [hasLocationPermission] permet d'activer/désactiver le point bleu selon les permissions
  static Map<String, dynamic> getSecureMapConfig({bool hasLocationPermission = false}) {
    return {
      'minMaxZoomPreference': MinMaxZoomPreference(minZoom, maxZoom),
      'zoomGesturesEnabled': true,
      'zoomControlsEnabled': false,
      'scrollGesturesEnabled': true,
      'rotateGesturesEnabled': false, // Éviter les rotations qui causent des bugs
      'tiltGesturesEnabled': false,   // Éviter les inclinaisons qui causent des bugs
      'myLocationEnabled': hasLocationPermission,  // ⚡ FIX: Dynamique selon permission
      'myLocationButtonEnabled': false,
      'mapToolbarEnabled': false,
      'trafficEnabled': false,        // Éviter les couches supplémentaires
    };
  }

  /// Vérifie si une position est valide (coordonnées GPS valides)
  static bool isValidPosition(LatLng? position) {
    if (position == null) return false;

    // Vérifier que les coordonnées sont dans les limites valides
    return position.latitude >= -90 &&
           position.latitude <= 90 &&
           position.longitude >= -180 &&
           position.longitude <= 180 &&
           // Exclure la position 0,0 qui n'est jamais une vraie position GPS
           !(position.latitude == 0 && position.longitude == 0);
  }

  /// Débugge les informations de la caméra actuelle
  static Future<void> debugCameraState(GoogleMapController controller) async {
    try {
      final visibleRegion = await controller.getVisibleRegion();
      final latSpan = visibleRegion.northeast.latitude - visibleRegion.southwest.latitude;
      final lngSpan = visibleRegion.northeast.longitude - visibleRegion.southwest.longitude;
      
      debugPrint('📷 IOSMapFix Debug:');
      debugPrint('   Southwest: ${visibleRegion.southwest}');
      debugPrint('   Northeast: ${visibleRegion.northeast}');
      debugPrint('   Span: lat=$latSpan, lng=$lngSpan');
      debugPrint('   Span anormal: ${latSpan > 2.0 || lngSpan > 2.0}');
    } catch (e) {
      debugPrint('❌ IOSMapFix: Impossible de débugger la caméra: $e');
    }
  }
}
