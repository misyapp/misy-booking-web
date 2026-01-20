// ignore_for_file: unnecessary_null_comparison

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dart:ui' as ui;
import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
import '../utils/ios_map_fix.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'dart:math';
import 'dart:developer' as d;

import '../contants/global_data.dart';
import '../contants/my_colors.dart';
import '../services/route_service.dart';
import '../utils/map_utils.dart';

class GoogleMapProvider with ChangeNotifier {
  LatLng? initialPosition;
  LatLng? currentPosition;
  GoogleMapController? _controller;
  bool _isControllerInitialized = false;

  /// Getter for controller - throws if not initialized
  GoogleMapController get controller {
    if (!_isControllerInitialized || _controller == null) {
      throw StateError('GoogleMapController has not been initialized yet');
    }
    return _controller!;
  }

  /// Check if controller is ready to use
  bool get isControllerReady => _isControllerInitialized && _controller != null;

  Map<String, Marker> markers = {
    "pickup": const Marker(markerId: MarkerId("pickup"))
  };
  final Map<String, Future<BitmapDescriptor>> _markerDescriptorCache = {};
  final Map<String, Ticker> _markerAnimationTickers = {};
  Marker? _driverVehicleSnapshot;
  final List<LatLng> _driverPreviewPath = [];
  DateTime? _lastPreviewUpdate;

  // ⚡ FIX: Suivre l'état de la permission de localisation
  bool _hasLocationPermission = false;
  bool get hasLocationPermission => _hasLocationPermission;

  CameraPosition? center;
  bool visiblePolyline = false;
  bool visibleCoveredPolyline = false;
  List<LatLng> polylineCoordinates = [];
  List<LatLng> coveredPolylineCoordinates = [];
  List<LatLng> animatedPolylineCoordinates =
      []; // Pour l'animation de chargement
  Set<Polyline> polyLines = {};
  bool isAnimatingRoute = false; // Flag pour contrôler l'animation

  /// Returns the minimum distance in meters between [target] and the
  /// currently displayed navigation polyline. Returns null if no polyline is
  /// available.
  double? distanceToPolyline(LatLng target) {
    if (polylineCoordinates.length < 2) {
      return null;
    }

    double minDistance = double.infinity;
    for (int i = 0; i < polylineCoordinates.length - 1; i++) {
      final double segmentDistance = _distanceToSegmentInMeters(
        target,
        polylineCoordinates[i],
        polylineCoordinates[i + 1],
      );
      if (segmentDistance < minDistance) {
        minDistance = segmentDistance;
      }
    }

    return minDistance;
  }

  addPolyline(Polyline path) async {
    polyLines.add(path);
    notifyListeners();
  }

  updatePolyline({required String polylineName}) {
    polyLines
        .removeWhere((element) => element.polylineId.value == polylineName);
    notifyListeners();
  }

  void setMapStyle(context) async {
    // Load the dark mode map style JSON string
    bool isDarkMode = Provider.of<DarkThemeProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false)
        .darkTheme;

    String darkMapStyle = await DefaultAssetBundle.of(context).loadString(
        isDarkMode
            ? 'assets/map_styles/dark_mode.json'
            : "assets/map_styles/light_mode.json");

    // Apply the dark mode map style to the Google Map
    controller.setMapStyle(darkMapStyle);
  }

  /// ⚡ FIX: Mettre à jour l'état de la permission et activer/désactiver le point bleu GPS
  Future<void> updateLocationPermissionStatus(bool hasPermission) async {
    if (_hasLocationPermission != hasPermission) {
      _hasLocationPermission = hasPermission;
      myCustomPrintStatement('📍 Permission de localisation mise à jour: $hasPermission');
      notifyListeners();

      // Si le controller est initialisé, tenter de mettre à jour myLocationEnabled
      try {
        // Note: Google Maps ne permet pas de changer myLocationEnabled dynamiquement
        // après la création de la carte. Il faut reconstruire le widget GoogleMap.
        // C'est pourquoi on utilise notifyListeners() pour forcer la reconstruction.
        myCustomPrintStatement('🔄 GoogleMap sera reconstruit avec myLocationEnabled=$hasPermission');
      } catch (e) {
        myCustomPrintStatement('⚠️ Erreur lors de la mise à jour de myLocationEnabled: $e');
      }
    }
  }

  setPosition(lat, lng) {
    myCustomPrintStatement("lat is $lat long is $lng");
    bool isFirstPosition = initialPosition == null;

    if (isFirstPosition) {
      initialPosition =
          LatLng(double.parse(lat.toString()), double.parse(lng.toString()));
      notifyListeners();
    }
    currentPosition =
        LatLng(double.parse(lat.toString()), double.parse(lng.toString()));

    // Recentrer intelligemment sur la position à l'ouverture de l'app
    if (isFirstPosition) {
      _recenterOnUserLocationWithDynamicPadding();
    }
  }

  setController(GoogleMapController ctrlr) {
    _controller = ctrlr;
    _isControllerInitialized = true;
    myCustomPrintStatement('✅ GoogleMapController initialisé');
  }

  /// Reset le contrôleur - à appeler avant de recréer le GoogleMap
  void resetController() {
    _controller = null;
    _isControllerInitialized = false;
    myCustomPrintStatement('🔄 GoogleMapController réinitialisé');
  }

  /// Maintains a short trail following the driver marker for smooth visuals.
  void updateDriverPreviewPath(LatLng position,
      {int maxPoints = 25,
      Duration minInterval = const Duration(milliseconds: 120)}) {
    final DateTime now = DateTime.now();
    if (_lastPreviewUpdate != null &&
        now.difference(_lastPreviewUpdate!) < minInterval) {
      return;
    }
    _lastPreviewUpdate = now;

    _driverPreviewPath.add(position);
    if (_driverPreviewPath.length > maxPoints) {
      _driverPreviewPath.removeAt(0);
    }

    final Polyline previewPolyline = Polyline(
      polylineId: const PolylineId('driver_preview'),
      color: Colors.blueAccent.withOpacity(0.45),
      width: 4,
      points: List<LatLng>.from(_driverPreviewPath),
      geodesic: true,
      patterns: [PatternItem.dash(30), PatternItem.gap(20)],
    );
    polyLines.removeWhere(
        (polyline) => polyline.polylineId.value == 'driver_preview');
    polyLines.add(previewPolyline);
    notifyListeners();
  }

  void clearDriverPreviewPath() {
    _driverPreviewPath.clear();
    polyLines.removeWhere(
        (polyline) => polyline.polylineId.value == 'driver_preview');
    notifyListeners();
  }

  /// Recentre sur la position utilisateur au démarrage
  /// Simplifié pour éviter les multiples zoom/dezoom
  /// Note: Sur le menu principal (setYourDestination), le centrage est géré par getLocation() dans home_screen.dart
  void _recenterOnUserLocationWithDynamicPadding() {
    if (currentPosition == null) {
      myCustomPrintStatement(
          "🎯 Position utilisateur null - pas de recentrage initial");
      return;
    }

    try {
      // Vérifier l'écran actuel pour adapter le comportement
      final tripProvider = Provider.of<TripProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false,
      );

      final isMainMenu = tripProvider.currentStep == CustomTripType.setYourDestination;

      // Sur le menu principal: pas d'animation ici car getLocation() s'en charge déjà
      // Cela évite les multiples zoom/dezoom conflictuels
      if (isMainMenu) {
        myCustomPrintStatement(
            "🎯 Menu principal: recentrage délégué à getLocation()");
        return;
      }

      // Pour les autres écrans: comportement avec compensation bottom sheet (une seule animation)
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (currentPosition != null && isControllerReady) {
          myCustomPrintStatement(
              "🎯 Recentrage initial avec compensation fenêtre flottante");
          await _centerOnUserLocationWithBottomSheetAwareness();
        }
      });
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur recentrage position utilisateur initial: $e");
    }
  }

  /// Centre directement sur la position GPS sans compensation de fenêtre
  /// Utilisé pendant les étapes de saisie où il ne faut pas perturber l'utilisateur
  Future<void> centerOnUserLocationSimple() async {
    if (currentPosition == null || !isControllerReady) {
      myCustomPrintStatement(
          "🎯 Position ou contrôleur null - pas de recentrage simple");
      return;
    }

    try {
      myCustomPrintStatement(
          "🎯 Centrage simple sur position GPS sans compensation");

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentPosition!,
            zoom: 16.0, // Zoom standard
            bearing: 0.0,
          ),
        ),
      );

      myCustomPrintStatement(
          "✅ Centrage simple réussi sur ${currentPosition!.latitude.toStringAsFixed(6)}, ${currentPosition!.longitude.toStringAsFixed(6)}");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur centrage simple: $e");
    }
  }

  /// Méthode publique pour recentrer le point bleu dans tous les contextes
  Future<void> recenterUserLocationForAllContexts() async {
    if (currentPosition == null) {
      myCustomPrintStatement(
          "🎯 Position utilisateur null - pas de recentrage contextuel");
      return;
    }

    myCustomPrintStatement(
        "🎯 Recentrage adaptatif du point bleu pour le contexte actuel");

    try {
      await _centerOnUserLocationWithBottomSheetAwareness();
    } catch (e) {
      myCustomPrintStatement("❌ Erreur recentrage contextuél: $e");
    }
  }

  /// Centre la caméra sur la position utilisateur en tenant compte du bottom sheet
  /// Déplace la caméra vers le haut pour que le point bleu soit visible dans la zone de carte
  Future<void> _centerOnUserLocationWithBottomSheetAwareness() async {
    if (currentPosition == null) return;

    try {
      // Obtenir les informations d'écran
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenSize = MediaQuery.of(context).size;
      final screenHeight = screenSize.height;

      // Déterminer la hauteur du bottom sheet selon le contexte actuel
      double bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final bottomSheetHeightPx = screenHeight * bottomSheetHeightRatio;
      final visibleMapHeight = screenHeight - bottomSheetHeightPx;

      myCustomPrintStatement(
          "🎯 Centrage avec compensation fenêtre - Écran: ${screenHeight.toInt()}px, Fenêtre: ${bottomSheetHeightPx.toInt()}px (${(bottomSheetHeightRatio * 100).toInt()}%), Zone visible: ${visibleMapHeight.toInt()}px");

      // Calculer le décalage géographique nécessaire pour centrer le point bleu dans la zone visible
      // Formule: décaler vers le nord d'une distance proportionnelle à la taille de la fenêtre

      // Utiliser un zoom adaptatif selon la taille d'écran
      double adaptiveZoom = 16.0;
      if (screenHeight < 700) {
        adaptiveZoom = 15.5; // Zoom légèrement plus faible pour petits écrans
      } else if (screenHeight > 900) {
        adaptiveZoom = 16.5; // Zoom plus fort pour grands écrans
      }

      // Calculer précisément le centre de la zone visible
      // Zone visible = du haut de l'écran jusqu'au haut de la fenêtre
      final centerOfVisibleArea =
          visibleMapHeight / 2; // Centre de la zone visible

      // Calcul du décalage nécessaire
      // Le centre de la zone visible est plus haut que le centre de l'écran
      // donc on doit décaler la caméra vers le haut (nord) pour que le point apparaisse centré
      final screenCenter = screenHeight / 2;
      final offsetFromScreenCenter =
          screenCenter - centerOfVisibleArea; // Inversion : écran - visible

      // Convertir l'offset en pixels vers un décalage géographique plus agressif
      // À zoom 16, environ 1 degré ≈ 70km pour latitude, et 1 pixel ≈ 20-30m selon l'écran
      // Utiliser un facteur plus élevé pour compenser
      final pixelToMeters = 25.0; // Augmenté pour décalage plus visible
      final offsetInMeters = offsetFromScreenCenter * pixelToMeters;
      final latitudeOffset =
          offsetInMeters / 111000.0; // Conversion mètres vers degrés

      myCustomPrintStatement("📊 Calcul de centrage amélioré - "
          "Zone visible: ${visibleMapHeight.toInt()}px, "
          "Centre zone visible: ${centerOfVisibleArea.toInt()}px, "
          "Centre écran: ${screenCenter.toInt()}px, "
          "Offset: ${offsetFromScreenCenter.toInt()}px = ${offsetInMeters.toInt()}m = ${(latitudeOffset * 1000000).toStringAsFixed(1)}μg");

      // Créer la position ajustée pour centrer au milieu de la zone visible
      // Décaler vers le nord (latitude positive) pour que le point apparaisse plus haut
      final adjustedPosition = LatLng(
        currentPosition!.latitude +
            latitudeOffset, // Positif pour aller vers le nord
        currentPosition!.longitude,
      );

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                adjustedPosition, // Utiliser la position ajustée au lieu de la position exacte
            zoom: adaptiveZoom,
            bearing: 0.0,
          ),
        ),
      );

      myCustomPrintStatement(
          "✅ Position utilisateur centrée au milieu de la zone visible - "
          "Zoom: $adaptiveZoom, Fenêtre: ${bottomSheetHeightPx.toInt()}px (${(bottomSheetHeightRatio * 100).toInt()}%), "
          "Zone visible: ${visibleMapHeight.toInt()}px, Décalage: ${(latitudeOffset * 1000000).toStringAsFixed(1)}μg vers le nord");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur centrage position utilisateur: $e");
    }
  }

  /// Détermine la hauteur du bottom sheet selon le contexte actuel de l'application
  /// IMPORTANT : Utilise les vraies valeurs du HomeScreen pour synchronisation
  double _getBottomSheetHeightForCurrentContext() {
    try {
      // Obtenir le TripProvider pour connaître l'écran actuel
      final tripProvider = Provider.of<TripProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false,
      );

      final currentStep = tripProvider.currentStep;
      myCustomPrintStatement("📐 Détection contexte actuel: $currentStep");

      // SYNCHRONISÉ avec les vraies valeurs du HomeScreen
      // _lowestBottomSheetHeight = 0.10, _minBottomSheetHeight = 0.30, _midBottomSheetHeight = 0.55, _maxBottomSheetHeight = 0.78
      switch (currentStep) {
        case CustomTripType.setYourDestination:
          myCustomPrintStatement(
              "🏠 Contexte: Écran d'accueil - Fenêtre 'Choisissez votre trajet' (55%)");
          return 0.55; // _midBottomSheetHeight - Écran d'accueil
        case CustomTripType.choosePickupDropLocation:
        case CustomTripType.selectScheduleTime:
          myCustomPrintStatement(
              "🗺️ Contexte: Sélection d'adresse/planning (55%)");
          return 0.55; // _midBottomSheetHeight - Sélection d'adresse
        case CustomTripType.chooseVehicle:
          myCustomPrintStatement(
              "🚗 Contexte: Choix du véhicule (55% - hauteur réelle du bottom sheet)");
          return 0.55; // Hauteur réelle synchronisée avec _midBottomSheetHeight du HomeScreen
        case CustomTripType.payment:
        case CustomTripType.confirmDestination:
        case CustomTripType.requestForRide:
          myCustomPrintStatement(
              "🚗 Contexte: Étapes de réservation (50% effectif après optimisation compacte)");
          return 0.50; // Réduit de 0.55 à 0.50 car layout compact libère plus d'espace pour la carte
        case CustomTripType.paymentMobileConfirm:
          myCustomPrintStatement("💳 Contexte: Écran paymentMobileConfirm (100%)");
          return 1.0; // Plein écran pour paiement MVola/Airtel
        case CustomTripType.orangeMoneyPayment:
          myCustomPrintStatement("💳 Contexte: Écran Orange Money (78%)");
          return 0.78; // _maxBottomSheetHeight pour Orange Money
        case CustomTripType.driverOnWay:
          // Vérifier si c'est un écran de paiement
          if (tripProvider.booking != null) {
            bool isPaymentScreen =
                (tripProvider.booking!['status'] == 4 || // DESTINATION_REACHED
                    (tripProvider.booking!['status'] == 5 &&
                        tripProvider.booking!['paymentStatusSummary'] ==
                            null)); // RIDE_COMPLETE sans paiement
            if (isPaymentScreen) {
              myCustomPrintStatement("💳 Contexte: Écran de paiement (78%)");
              return 0.78; // _maxBottomSheetHeight - Écran de paiement
            }
          }
          myCustomPrintStatement("🚕 Contexte: Chauffeur en route (55%)");
          return 0.55; // _midBottomSheetHeight - Chauffeur en route
        default:
          myCustomPrintStatement(
              "⚠️ Contexte inconnu: $currentStep - utilisation valeur par défaut (30%)");
          return 0.30; // _minBottomSheetHeight par défaut
      }
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur détermination contexte, utilisation valeur par défaut: $e");
      return 0.30; // _minBottomSheetHeight en cas d'erreur
    }
  }

  /// Méthode de débogage pour vérifier le calcul de centrage au démarrage
  void _debugDisplayStartupCentering() {
    try {
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenSize = MediaQuery.of(context).size;
      final screenHeight = screenSize.height;
      final bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final bottomSheetHeightPx = screenHeight * bottomSheetHeightRatio;
      final visibleMapHeight = screenHeight - bottomSheetHeightPx;
      final centerOfVisibleArea = visibleMapHeight / 2;

      myCustomPrintStatement("🔍 DEBUG Centrage initial:");
      myCustomPrintStatement("   Écran total: ${screenHeight.toInt()}px");
      myCustomPrintStatement(
          "   Fenêtre: ${bottomSheetHeightPx.toInt()}px (${(bottomSheetHeightRatio * 100).toInt()}%)");
      myCustomPrintStatement(
          "   Zone carte visible: ${visibleMapHeight.toInt()}px");
      myCustomPrintStatement(
          "   Centre zone visible: ${centerOfVisibleArea.toInt()}px depuis le haut");
      myCustomPrintStatement(
          "   Centre écran: ${(screenHeight / 2).toInt()}px depuis le haut");
      final debugOffset = (screenHeight / 2) - centerOfVisibleArea;
      myCustomPrintStatement(
          "   Décalage caméra: ${debugOffset.toInt()}px vers le haut pour centrer le point");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur debug centrage: $e");
    }
  }
  //= LatLng(double.parse(lat), double.parse(lng))

  Future<Uint8List> getImages(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetHeight: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }
  //
  // loadData({required ValueNotifier<List<Marker>> markerNotifier}) async {
  //   for (int i = 0; i < serviceList.length; i++) {
  //     final Uint8List markIcons = await getImages(
  //       MyImagesUrl.taxiIcon,
  //       120,
  //     );
  //     markerNotifier.value.add(Marker(
  //       markerId: MarkerId(i.toString()),
  //       icon: BitmapDescriptor.fromBytes(markIcons),
  //       position: LatLng(
  //         double.parse(serviceList[i]['lat']),
  //         double.parse(
  //           serviceList[i]['lng'],
  //         ),
  //       ),
  //     ));
  //     markerNotifier.notifyListeners();
  //   }
  // }

  createUpdateMarker(
    type,
    LatLng location, {
    String? url,
    LatLng? oldLocation,
    bool animateToCenter = true,
    bool isAsset = false,
    bool draggable = false,
    BitmapDescriptor? customMarker,
    Function()? onTap,
    String? address,
    Function(LatLng)? onDragEnd,
    bool rotate = false,
    bool smoothTransition = false,
    double rotationOffsetDeg = 0,
    double? forcedRotation, // Rotation forcée (snap-to-road bearing)
  }) async {
    BitmapDescriptor iconToUse;
    if (customMarker != null) {
      iconToUse = customMarker;
    } else if (url != null) {
      // 🚀 Charger depuis cache local ou réseau (avec persistance sur disque)
      iconToUse = await ((isAsset)
          ? createMarkerImageFromAssets(url)
          : createMarkerImageFromNetwork(url));
    } else {
      iconToUse = markers[type]?.icon ?? BitmapDescriptor.defaultMarker;
    }

    bool shouldNotifyAfter = false;

    if (markers[type] == null) {
      // Si forcedRotation est fourni, l'utiliser, sinon calculer
      final double initialRotation = forcedRotation ??
          ((rotate == true)
              ? _computeRotation(oldLocation, location, rotationOffsetDeg)
              : 0.0);
      var marker = Marker(
          markerId: MarkerId(type),
          onDragEnd: onDragEnd,
          flat: true,
          draggable: draggable,
          anchor: (rotate == true || forcedRotation != null)
              ? const Offset(0.5, 0.5)
              : const Offset(0.5, 1.0),
          icon: iconToUse,
          rotation: initialRotation,
          position: location,
          onTap: onTap);
      markers[type] = marker;
      _persistDriverVehicleMarker(type);
      shouldNotifyAfter = true;
    } else {
      final previousMarker = markers[type]!;
      final previousPosition = previousMarker.position;
      // Si forcedRotation est fourni, l'utiliser, sinon calculer ou garder l'existant
      final double updatedRotation = forcedRotation ??
          ((rotate == true && previousPosition != location)
              ? _computeRotation(previousPosition, location, rotationOffsetDeg)
              : previousMarker.rotation);

      if (smoothTransition && previousPosition != location) {
        _startMarkerSmoothAnimation(
          markerId: type,
          start: previousPosition,
          target: location,
          rotation: updatedRotation,
          icon: iconToUse,
        );
      } else {
        markers[type] = previousMarker.copyWith(
          visibleParam: true,
          positionParam: location,
          iconParam: iconToUse,
          rotationParam: updatedRotation,
        );
        _persistDriverVehicleMarker(type);
        shouldNotifyAfter = true;
      }
    }

    if (shouldNotifyAfter) {
      notifyListeners();
    }

    if (animateToCenter == true) {
      animateToNewTarget(location.latitude, location.longitude);
    }
  }

  void _startMarkerSmoothAnimation({
    required String markerId,
    required LatLng start,
    required LatLng target,
    required double rotation,
    required BitmapDescriptor icon,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    if (!markers.containsKey(markerId)) {
      return;
    }

    _markerAnimationTickers[markerId]?.stop();
    _markerAnimationTickers[markerId]?.dispose();
    _markerAnimationTickers.remove(markerId);

    final int totalDurationMs = duration.inMilliseconds;
    if (totalDurationMs <= 0 || start == target) {
      markers[markerId] = markers[markerId]!.copyWith(
        visibleParam: true,
        positionParam: target,
        rotationParam: rotation,
        iconParam: icon,
      );
      _persistDriverVehicleMarker(markerId);
      notifyListeners();
      return;
    }

    // Mettre à jour immédiatement pour prendre en compte la nouvelle icône/rotation
    markers[markerId] = markers[markerId]!.copyWith(
      visibleParam: true,
      positionParam: start,
      rotationParam: rotation,
      iconParam: icon,
    );
    _persistDriverVehicleMarker(markerId);
    notifyListeners();

    late final Ticker ticker;
    ticker = Ticker((elapsed) {
      double t = elapsed.inMilliseconds / totalDurationMs;
      if (t >= 1.0) {
        t = 1.0;
      }
      final easedT = Curves.linear.transform(t);
      final currentLat = _lerpDouble(start.latitude, target.latitude, easedT);
      final currentLng = _lerpDouble(start.longitude, target.longitude, easedT);

      markers[markerId] = markers[markerId]!.copyWith(
        positionParam: LatLng(currentLat, currentLng),
        rotationParam: rotation,
        iconParam: icon,
      );
      _persistDriverVehicleMarker(markerId);
      notifyListeners();

      if (t >= 1.0) {
        ticker.stop();
        ticker.dispose();
        _markerAnimationTickers.remove(markerId);
      }
    });

    _markerAnimationTickers[markerId] = ticker;
    ticker.start();
  }

  double _lerpDouble(double start, double end, double t) {
    return start + (end - start) * t;
  }

  @override
  void dispose() {
    for (final ticker in _markerAnimationTickers.values) {
      ticker.dispose();
    }
    _markerAnimationTickers.clear();
    super.dispose();
  }

  double generateRandomDouble() {
    Random random = Random();
    // Generate a random double between 0 and 1, then scale it to the desired range (1 to 360)
    double randomDouble = 45 + (random.nextDouble() * (360 - 45));
    myCustomPrintStatement("random bearing is called ${randomDouble}");
    return randomDouble;
  }

  hideMarkers() {
    markers.forEach((final String type, final value) {
      if (markers[type]!.markerId == const MarkerId('pickup') ||
          markers[type]!.markerId == const MarkerId('drop')) {
        markers[type] = markers[type]!.copyWith(visibleParam: false);
      }
    });
    // updateMap.value++;
  }

  Future<void> animateToNewTarget(double latitude, double longitude,
      {double zoom = 15.0,
      double bearing = 0.0,
      bool preserveZoom = false}) async {
    if (!isControllerReady) {
      return;
    }

    if (preserveZoom) {
      await controller
          .animateCamera(CameraUpdate.newLatLng(LatLng(latitude, longitude)));
      return;
    }

    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(latitude, longitude),
        zoom: zoom,
        bearing: bearing,
      ),
    ));
  }

  Future<void> zoomTo(double zoom, {bool animate = true}) async {
    if (!isControllerReady) {
      return;
    }
    if (animate) {
      await controller.animateCamera(CameraUpdate.zoomTo(zoom));
    } else {
      await controller.moveCamera(CameraUpdate.zoomTo(zoom));
    }
  }

  void centerMapToAbsolutePosition({
    required LatLng referencePosition,
    required double bottomSheetHeightRatio,
    required double screenHeight,
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    if (!isControllerReady) {
      myCustomPrintStatement("Controller null, centrage annulé");
      return;
    }

    myCustomPrintStatement(
        "Début centrage absolu: $referencePosition, ratio: $bottomSheetHeightRatio");

    try {
      // PROTECTION iOS : Si les écrans de paiement sont actifs, utiliser un centrage simple
      // pour éviter les calculs complexes qui peuvent causer le dézoom

      // Récupérer la région visible actuelle pour calculer le span
      final cameraPosition = await controller.getVisibleRegion();
      final latSpan =
          cameraPosition.northeast.latitude - cameraPosition.southwest.latitude;
      final lngSpan = cameraPosition.northeast.longitude -
          cameraPosition.southwest.longitude;

      // PROTECTION iOS : Si le span est anormalement grand (signe de problème), utiliser centrage simple
      if (Platform.isIOS && (latSpan > 2.0 || lngSpan > 2.0)) {
        myCustomPrintStatement(
            "🍎 iOS Protection: Span anormal détecté ($latSpan, $lngSpan), centrage simple");
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: referencePosition,
              zoom: 14.0,
              bearing: 0.0,
            ),
          ),
        );
        return;
      }

      // Calculer où la position de référence doit apparaître sur l'écran
      // Zone visible: de 0% (haut) à (1 - bottomSheetHeightRatio) * 100%
      // Centre de la zone visible: (1 - bottomSheetHeightRatio) / 2
      final visibleCenterFromTop = (1 - bottomSheetHeightRatio) / 2;

      // Calculer l'offset depuis le centre de l'écran (0.5) vers le centre visuel
      final offsetFromScreenCenter = 0.5 - visibleCenterFromTop;

      // Convertir cet offset en coordonnées GPS
      // INVERSION: si offsetFromScreenCenter > 0 (bottom sheet grand), on doit aller vers le SUD (latitude -)
      // si offsetFromScreenCenter < 0 (bottom sheet petit), on doit aller vers le NORD (latitude +)
      final offsetLat =
          -latSpan * offsetFromScreenCenter; // INVERSION avec le signe -
      final offsetLng = 0.0; // Pas de décalage horizontal

      // Position finale de la caméra pour que la référence apparaisse au centre visuel
      final targetLat = referencePosition.latitude + offsetLat;
      final targetLng = referencePosition.longitude + offsetLng;

      myCustomPrintStatement("Animation vers: $targetLat, $targetLng");

      await controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(targetLat, targetLng)),
      );
    } catch (e) {
      // Gestion d'erreur silencieuse pour éviter les crashes
      myCustomPrintStatement("Erreur lors du centrage absolu de carte: $e");
    }
  }

  Future<BitmapDescriptor> createMarkerImageFromAssets(String assetName) async {
    return getCachedMarkerDescriptor(assetName, isAsset: true);
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  Future<void> getPolilyine(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    List<LatLng> wayPoints = const [],
    double topPaddingPercentage = 0.1,
  }) async {
    try {
      final routeInfo = await RouteService.fetchRoute(
        origin: LatLng(originLat, originLng),
        destination: LatLng(destLat, destLng),
        waypoints: wayPoints,
      );

      polylineCoordinates = routeInfo.coordinates;

      d.log(
          "polyline coordinates----------------111222------$polylineCoordinates");
    } catch (e) {
      // Handle for choose vehicle page only
      var tripProviderInstance = Provider.of<TripProvider>(
          MyGlobalKeys.navigatorKey.currentContext!,
          listen: false);
      if ((tripProviderInstance.currentStep ==
                  CustomTripType.choosePickupDropLocation ||
              tripProviderInstance.currentStep ==
                  CustomTripType.chooseVehicle) &&
          tripProviderInstance.booking == null) {
        Future.delayed(
          Duration(seconds: 2),
          () {
            tripProviderInstance
                .setScreen(CustomTripType.choosePickupDropLocation);
            showSnackbar(translate("Unable to find path results"));
          },
        );
      }
      myCustomLogStatements("erorr while getting path ${e}");

      return;
    }
    var latLngBoundResponse =
        GoogleMapProvider.getLatLongBoundsFromLatLngList(polylineCoordinates,
            topPaddingPercentage: 0.15, // Padding généreux pour plus de marge
            bottomPaddingPercentage: 0.15); // Padding généreux
    print("zoom level is that $latLngBoundResponse ");

    visiblePolyline = true;
    await updatePolyline(polylineName: "path");
    addPolyline(Polyline(
      polylineId: const PolylineId('path'),
      color: MyColors.blackThemewithC3C3C3Color(),
      width: 5,
      geodesic: true,
      visible: visiblePolyline,
      points: polylineCoordinates,
    ));

    // Démarrer l'animation seulement si on n'est PAS en driverOnWay
    // L'animation en driverOnWay cause des rebuilds excessifs et des mouvements de caméra
    var tripProviderInstance = Provider.of<TripProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false);

    if (tripProviderInstance.currentStep != CustomTripType.driverOnWay) {
      _animateRouteLoading();
    } else {
      myCustomPrintStatement('🎨 Animation de route désactivée pendant driverOnWay');
    }
  }

  double calculateZoomLevel(double distance) {
    double zoomLevel = 11;
    if (distance > 0) {
      zoomLevel = log(360 / distance) / log(2);
    }
    myCustomPrintStatement("zoom leve is that ${zoomLevel.clamp(0, 21)}");
    return zoomLevel.clamp(0, 21); // Ensures zoom level is between 0 and 21
  }

  Future<Uint8List> getBytesFromNetwork(String url) async {
    final http.Response response = await http.get(Uri.parse(url));
    return response.bodyBytes;
  }

  Future<BitmapDescriptor> createMarkerImageFromNetwork(url) async {
    return getCachedMarkerDescriptor(url, isAsset: false);
  }

  /// Crée un marker redimensionné depuis une URL réseau
  /// [url] URL de l'image
  /// [targetWidth] Largeur cible en pixels (défaut: 40)
  Future<BitmapDescriptor> createResizedMarkerFromNetwork(String url, {int targetWidth = 40}) async {
    final cacheKey = 'resized_${targetWidth}_$url';

    // Cache mémoire
    if (_markerDescriptorCache.containsKey(cacheKey)) {
      return _markerDescriptorCache[cacheKey]!;
    }

    final completer = Completer<BitmapDescriptor>();
    _markerDescriptorCache[cacheKey] = completer.future;

    try {
      final Uint8List imageData = await getBytesFromNetwork(url);

      // Décoder l'image
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: targetWidth,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Convertir en bytes
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      final Uint8List resizedBytes = byteData.buffer.asUint8List();
      final descriptor = BitmapDescriptor.fromBytes(resizedBytes);

      myCustomPrintStatement('🚗 Marker redimensionné (${targetWidth}px): $url');
      completer.complete(descriptor);
      return descriptor;
    } catch (e) {
      _markerDescriptorCache.remove(cacheKey);
      myCustomPrintStatement('❌ Erreur redimensionnement marker: $e');
      completer.completeError(e);
      rethrow;
    }
  }

  double bearingBetween(LatLng latLng1, LatLng latLng2) {
    double startLat = degreesToRadians(latLng1.latitude);
    double startLng = degreesToRadians(latLng1.longitude);
    double endLat = degreesToRadians(latLng2.latitude);
    double endLng = degreesToRadians(latLng2.longitude);

    double dLng = endLng - startLng;

    double y = sin(dLng) * cos(endLat);
    double x =
        cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);
    double radians = atan2(y, x);

    return radiansToDegrees(radians);
  }

  double degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  double radiansToDegrees(double radians) {
    return radians * (180 / pi);
  }

  double _distanceToSegmentInMeters(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
    final ui.Offset startToPoint = _toMeters(segmentStart, point);
    final ui.Offset startToEnd = _toMeters(segmentStart, segmentEnd);
    final double lengthSquared =
        startToEnd.dx * startToEnd.dx + startToEnd.dy * startToEnd.dy;

    if (lengthSquared == 0) {
      return startToPoint.distance;
    }

    double projectionRatio =
        (startToPoint.dx * startToEnd.dx + startToPoint.dy * startToEnd.dy) /
            lengthSquared;
    projectionRatio = projectionRatio.clamp(0.0, 1.0);

    final ui.Offset projection = ui.Offset(
      startToEnd.dx * projectionRatio,
      startToEnd.dy * projectionRatio,
    );
    return (startToPoint - projection).distance;
  }

  ui.Offset _toMeters(LatLng reference, LatLng point) {
    const double earthRadius = 6371000.0;
    final double lat1 = _degreesToRadians(reference.latitude);
    final double lat2 = _degreesToRadians(point.latitude);
    final double dLat = lat2 - lat1;
    final double dLng =
        _degreesToRadians(point.longitude - reference.longitude);

    final double x = dLng * cos((lat1 + lat2) / 2) * earthRadius;
    final double y = dLat * earthRadius;

    return ui.Offset(x, y);
  }

  double _computeRotation(
      LatLng? fromPosition, LatLng toPosition, double rotationOffsetDeg) {
    if (fromPosition == null ||
        (fromPosition.latitude == 0 && fromPosition.longitude == 0)) {
      return normalizeBearing(rotationOffsetDeg);
    }

    if (fromPosition.latitude == toPosition.latitude &&
        fromPosition.longitude == toPosition.longitude) {
      return normalizeBearing(rotationOffsetDeg);
    }

    final baseBearing = bearingBetween(fromPosition, toPosition);
    return normalizeBearing(baseBearing + rotationOffsetDeg);
  }

  double normalizeBearing(double bearing) {
    double normalized = bearing % 360;
    if (normalized < 0) {
      normalized += 360;
    }
    return normalized;
  }

  void ensureDriverVehicleMarkerVisible() {
    if (_driverVehicleSnapshot == null) {
      return;
    }
    bool shouldNotify = false;
    final current = markers['driver_vehicle'];
    if (current == null) {
      markers['driver_vehicle'] = _driverVehicleSnapshot!;
      shouldNotify = true;
    } else if (!current.visible) {
      markers['driver_vehicle'] = current.copyWith(visibleParam: true);
      shouldNotify = true;
    }
    if (shouldNotify) {
      notifyListeners();
    }
  }

  void clearDriverVehicleSnapshot() {
    _driverVehicleSnapshot = null;
  }

  void _persistDriverVehicleMarker(String markerKey) {
    if (markerKey == 'driver_vehicle') {
      _driverVehicleSnapshot = markers[markerKey];
    }
  }

  Future<BitmapDescriptor> getCachedMarkerDescriptor(String source,
      {required bool isAsset}) async {
    final cacheKey = isAsset ? 'asset::$source' : 'network::$source';

    // Cache mémoire pour éviter les téléchargements en double pendant la session
    if (_markerDescriptorCache.containsKey(cacheKey)) {
      return _markerDescriptorCache[cacheKey]!;
    }

    final completer = Completer<BitmapDescriptor>();
    _markerDescriptorCache[cacheKey] = completer.future;

    try {
      // 🚀 _loadMarkerDescriptorFromNetwork utilise le cache disque
      final descriptor = isAsset
          ? await _loadMarkerDescriptorFromAsset(source)
          : await _loadMarkerDescriptorFromNetwork(source);

      completer.complete(descriptor);
      return descriptor;
    } catch (e) {
      _markerDescriptorCache.remove(cacheKey);
      completer.completeError(e);
      rethrow;
    }
  }

  Future<BitmapDescriptor> _loadMarkerDescriptorFromAsset(
      String assetName) async {
    final byteData = await rootBundle.load(assetName);
    final Uint8List byteList = byteData.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(byteList);
  }

  /// 🚀 Charge l'image depuis le cache local ou le réseau
  /// Sauvegarde automatiquement sur disque pour les prochains lancements
  /// Note: Sur Web, pas de cache disque (path_provider non supporté)
  Future<BitmapDescriptor> _loadMarkerDescriptorFromNetwork(String url) async {
    try {
      Uint8List markerIconData;

      // Sur Web, pas de cache disque disponible - télécharger directement
      if (kIsWeb) {
        markerIconData = await getBytesFromNetwork(url);
        myCustomPrintStatement('🌐 Marker chargé depuis réseau (Web): $url');
      } else {
        // Sur mobile/desktop: utiliser le cache disque
        final cacheFileName = _generateCacheFileName(url);
        final cacheDir = await getTemporaryDirectory();
        final cacheFile = File('${cacheDir.path}/marker_cache/$cacheFileName');

        // Vérifier si l'image est en cache local
        if (await cacheFile.exists()) {
          // 🚀 Charger depuis le cache local (instantané)
          markerIconData = await cacheFile.readAsBytes();
          myCustomPrintStatement('📁 Marker chargé depuis cache local: $cacheFileName');
        } else {
          // Télécharger depuis le réseau
          markerIconData = await getBytesFromNetwork(url);

          // Sauvegarder dans le cache local pour les prochains lancements
          try {
            await cacheFile.parent.create(recursive: true);
            await cacheFile.writeAsBytes(markerIconData);
            myCustomPrintStatement('💾 Marker sauvegardé en cache local: $cacheFileName');
          } catch (e) {
            myCustomPrintStatement('⚠️ Erreur sauvegarde cache marker: $e');
          }
        }
      }

      return BitmapDescriptor.fromBytes(markerIconData);
    } catch (e) {
      myCustomPrintStatement('❌ Erreur chargement marker depuis réseau: $e');
      rethrow;
    }
  }

  /// Génère un nom de fichier unique basé sur l'URL (hash MD5)
  String _generateCacheFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = crypto.md5.convert(bytes);
    return '$digest.png';
  }

  /// 🚀 Précharge les images de markers de tous les types de véhicules
  /// Appelé au démarrage pour accélérer l'affichage des markers sur iOS
  Future<void> preloadVehicleMarkerImages() async {
    if (vehicleListModal.isEmpty) {
      myCustomPrintStatement('⚠️ Préchargement markers: Aucun véhicule chargé');
      return;
    }

    myCustomPrintStatement('🚀 Préchargement de ${vehicleListModal.length} images de markers véhicules...');

    final futures = <Future>[];
    for (final vehicle in vehicleListModal) {
      if (vehicle.marker.isNotEmpty) {
        futures.add(
          getCachedMarkerDescriptor(vehicle.marker, isAsset: false)
              .then((_) => myCustomPrintStatement('  ✓ Marker ${vehicle.name} préchargé'))
              .catchError((e) => myCustomPrintStatement('  ✗ Erreur marker ${vehicle.name}: $e')),
        );
      }
    }

    try {
      await Future.wait(futures).timeout(const Duration(seconds: 10));
      myCustomPrintStatement('✅ Tous les markers véhicules préchargés');
    } catch (e) {
      myCustomPrintStatement('⚠️ Timeout préchargement markers (10s) - continuera en arrière-plan');
    }
  }

  /// Centre le point GPS avec une approche alternative utilisant les bounds avec padding
  Future<void> _centerUserLocationWithPadding() async {
    if (currentPosition == null || !isControllerReady) return;

    try {
      // Obtenir les dimensions d'écran
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenSize = MediaQuery.of(context).size;
      final screenHeight = screenSize.height;

      // Déterminer la hauteur de fenêtre
      double bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final bottomSheetHeightPx = screenHeight * bottomSheetHeightRatio;

      myCustomPrintStatement(
          "🔄 Méthode alternative: centrage avec padding - Fenêtre: ${bottomSheetHeightPx.toInt()}px (${(bottomSheetHeightRatio * 100).toInt()}%)");

      // Créer des bounds centrés sur la position avec padding asymmétrique
      final latSpan = 0.005; // Petite zone autour du point
      final lngSpan = 0.005;

      final bounds = LatLngBounds(
        southwest: LatLng(
          currentPosition!.latitude - latSpan / 2,
          currentPosition!.longitude - lngSpan / 2,
        ),
        northeast: LatLng(
          currentPosition!.latitude + latSpan / 2,
          currentPosition!.longitude + lngSpan / 2,
        ),
      );

      // Centrer sur la position GPS actuelle
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );

      myCustomPrintStatement("✅ Centrage avec padding réussi sur position GPS");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur centrage avec padding: $e");
    }
  }

  /// Déclenche l'animation de l'itinéraire manuellement
  /// Utilisé lors de la transition vers le menu "Choisissez votre course"
  /// Garantit que l'itinéraire est TOUJOURS entièrement visible
  Future<void> triggerRouteAnimation() async {
    if (polylineCoordinates.isEmpty) {
      myCustomPrintStatement(
          "⚠️ Pas de coordonnées d'itinéraire pour l'animation");
      return;
    }

    myCustomPrintStatement(
        "🎬 Déclenchement manuel de l'animation d'itinéraire pour chooseVehicle avec approche FitBounds + ScrollBy");

    // NOUVELLE APPROCHE : Utiliser fitRouteAboveBottomSheet qui implémente FitBounds + ScrollBy
    await fitRouteAboveBottomSheet(
      padding: 60.0,
      // Le ratio sera automatiquement détecté pour chooseVehicle (0.55)
    );
  }

  /// Méthode optimisée qui garantit la visibilité complète de l'itinéraire
  /// Calcule automatiquement le bon padding pour éviter que l'itinéraire soit coupé
  Future<void> _showCompleteRouteWithGuaranteedVisibility() async {
    if (polylineCoordinates.isEmpty || !isControllerReady) return;

    try {
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenSize = MediaQuery.of(context).size;
      final screenHeight = screenSize.height;
      final screenWidth = screenSize.width;

      // Déterminer la hauteur exacte du bottom sheet pour le contexte "chooseVehicle"
      double bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final bottomSheetHeightPx = screenHeight * bottomSheetHeightRatio;
      final visibleMapHeight = screenHeight - bottomSheetHeightPx;

      myCustomPrintStatement("🗺️ Calcul visibilité garantie itinéraire:");
      myCustomPrintStatement(
          "   - Écran: ${screenHeight.toInt()}px x ${screenWidth.toInt()}px");
      myCustomPrintStatement(
          "   - Bottom sheet: ${bottomSheetHeightPx.toInt()}px (${(bottomSheetHeightRatio * 100).toInt()}%)");
      myCustomPrintStatement(
          "   - Zone carte visible: ${visibleMapHeight.toInt()}px");

      // Calculer les bounds de l'itinéraire
      double minLat = polylineCoordinates.first.latitude;
      double maxLat = polylineCoordinates.first.latitude;
      double minLng = polylineCoordinates.first.longitude;
      double maxLng = polylineCoordinates.first.longitude;

      for (var point in polylineCoordinates) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      final routeLatSpan = maxLat - minLat;
      final routeLngSpan = maxLng - minLng;

      // Calculer le padding nécessaire pour garantir la visibilité complète
      // Padding ULTRA généreux, surtout pour le bas (itinéraires Nord/Sud)
      final topPaddingPx = 120.0; // Marge généreuse en haut
      final bottomPaddingPx = bottomSheetHeightPx +
          180.0; // Marge très importante au-dessus du bottom sheet pour Nord/Sud
      final sidePaddingPx = 100.0; // Marges latérales généreuses

      // Convertir les paddings en pourcentages géographiques
      final topPaddingGeo = (topPaddingPx / screenHeight) * routeLatSpan;
      final bottomPaddingGeo = (bottomPaddingPx / screenHeight) * routeLatSpan;
      final sidePaddingGeo = (sidePaddingPx / screenWidth) * routeLngSpan;

      myCustomPrintStatement("📐 Padding appliqué pour visibilité garantie:");
      myCustomPrintStatement(
          "   - Top: ${topPaddingGeo.toStringAsFixed(6)} (${topPaddingPx.toInt()}px)");
      myCustomPrintStatement(
          "   - Bottom: ${bottomPaddingGeo.toStringAsFixed(6)} (${bottomPaddingPx.toInt()}px)");
      myCustomPrintStatement(
          "   - Sides: ${sidePaddingGeo.toStringAsFixed(6)} (${sidePaddingPx.toInt()}px)");

      // Animation directe vers les bounds calculés avec le ratio exact du bottom sheet
      // Le calcul précis dans IOSMapFix gère maintenant le centrage optimal
      await IOSMapFix.safeFitBounds(
        controller: controller,
        points: polylineCoordinates,
        bottomSheetRatio: bottomSheetHeightRatio, // Ratio exact sans boost artificiel
        debugSource: "guaranteedRouteVisibility",
      );

      myCustomPrintStatement("✅ Itinéraire affiché avec visibilité garantie");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur visibilité garantie, fallback: $e");
      // Fallback vers la méthode précédente
      await _animateRouteDisplayWithDynamicPadding(polylineCoordinates);
    }
  }

  /// Recentrer la carte sur la position actuelle de l'utilisateur
  /// Utilisé quand l'utilisateur revient à la page d'accueil
  Future<void> recenterOnUserLocation({double zoom = 15.0}) async {
    if (!isControllerReady) {
      myCustomPrintStatement("Controller non initialisé, recentrage annulé");
      return;
    }

    if (currentPosition == null) {
      myCustomPrintStatement("Position actuelle null, recentrage annulé");
      return;
    }

    try {
      myCustomPrintStatement(
          "🎯 Recentrage intelligent sur position utilisateur: $currentPosition");
      // Utiliser la méthode intelligente qui prend en compte le bottom sheet
      await _centerOnUserLocationWithBottomSheetAwareness();
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur recentrage intelligent, fallback classique: $e");
      // Fallback vers la méthode classique
      try {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentPosition!,
              zoom: zoom,
              bearing: 0.0,
            ),
          ),
        );
      } catch (fallbackError) {
        myCustomPrintStatement(
            "❌ Erreur lors du recentrage fallback: $fallbackError");
      }
    }
  }

  /// Animation fluide de l'affichage de l'itinéraire
  /// 1. Zoom instantané sur le point de prise en charge
  /// 2. Pause de 3 secondes sur le pickup
  /// 3. Dézoom direct en 1.5 seconde pour afficher tout l'itinéraire
  Future<void> _animateRouteDisplay(
      List<LatLng> routeCoordinates, LatLngBounds finalBounds) async {
    if (routeCoordinates.isEmpty) return;

    try {
      // Détection automatique du contexte pour adaptation
      double bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenHeight = MediaQuery.of(context).size.height;
      final visibleMapRatio =
          (screenHeight - (screenHeight * bottomSheetHeightRatio)) /
              screenHeight;

      myCustomPrintStatement(
          "🎬 Animation itinéraire 3s+1.5s - Zone visible: ${(visibleMapRatio * 100).toInt()}%");

      // Étape 1: Zoom instantané sur le point de prise en charge (sans animation)
      final pickupPoint = routeCoordinates.first;
      double pickupZoom = 17.0; // Zoom élevé pour bien voir le point de départ
      if (visibleMapRatio < 0.5) {
        pickupZoom = 16.0; // Zoom légèrement réduit pour petite zone
      } else if (visibleMapRatio > 0.75) {
        pickupZoom = 18.0; // Zoom plus fort pour grande zone
      }

      // Position instantanée sur le pickup (pas d'animation)
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pickupPoint,
            zoom: pickupZoom,
            bearing: 0.0,
          ),
        ),
      );

      myCustomPrintStatement(
          "📍 Position initiale: Point de prise en charge à zoom ${pickupZoom}");

      // Étape 2: Pause brève pour stabiliser la vue
      await Future.delayed(const Duration(milliseconds: 300));

      // Étape 3: Dézoom progressif fluide en 2 secondes vers l'itinéraire complet avec plus de marge
      double adaptivePadding;
      if (visibleMapRatio > 0.7) {
        adaptivePadding = 80.0; // Padding généreux pour grande zone
      } else if (visibleMapRatio > 0.5) {
        adaptivePadding = 100.0; // Padding élargi pour zone moyenne
      } else {
        adaptivePadding = 120.0; // Padding maximal pour zone réduite
      }

      // Animation fluide contrôlée de 1.5 seconde précise
      myCustomPrintStatement(
          "🎥 Début dézoom direct 1.5s vers itinéraire complet");

      final animationStartTime = DateTime.now();

      // SOLUTION RADICALE : Remplacer newLatLngBounds par IOSMapFix
      await IOSMapFix.safeFitBounds(
        controller: controller,
        points: polylineCoordinates,
        bottomSheetRatio: 0.4, // Estimation pour écran itinéraire
        debugSource: "timedBoundsAnimation",
      );

      final actualDuration = DateTime.now().difference(animationStartTime);

      // Si l'animation était plus rapide que 1.5s, attendre le reste pour consistance
      const targetDuration = Duration(milliseconds: 1500);
      if (actualDuration < targetDuration) {
        final remainingTime = targetDuration - actualDuration;
        myCustomPrintStatement(
            "⏱️ Animation rapide (${actualDuration.inMilliseconds}ms), attente de ${remainingTime.inMilliseconds}ms");
        await Future.delayed(remainingTime);
      }

      myCustomPrintStatement(
          "✅ Animation itinéraire terminée en 4.5s - Padding: ${adaptivePadding}px");
    } catch (e) {
      myCustomPrintStatement("Erreur lors de l'animation de l'itinéraire: $e");
      // En cas d'erreur, essayer avec un padding légèrement plus grand
      try {
        // SOLUTION RADICALE : Fallback avec IOSMapFix
        await IOSMapFix.safeFitBounds(
          controller: controller,
          points: polylineCoordinates,
          bottomSheetRatio: 0.4,
          debugSource: "timedBoundsAnimation-fallback",
        );
      } catch (fallbackError) {
        myCustomPrintStatement("Erreur de fallback: $fallbackError");
      }
    }
  }

  /// Animation de l'affichage de l'itinéraire avec pause 3s puis dézoom direct 1.5s
  Future<void> _animateRouteDisplayWithDynamicPadding(
      List<LatLng> routeCoordinates) async {
    if (routeCoordinates.isEmpty) return;

    myCustomPrintStatement(
        "🎬 Démarrage animation itinéraire 4.5s avec adaptation intelligente");

    try {
      // Étape 1: Position instantanée sur le point de prise en charge
      final pickupPoint = routeCoordinates.first;

      // Détection du contexte pour zoom adaptatif
      double bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenHeight = MediaQuery.of(context).size.height;
      final visibleMapRatio =
          (screenHeight - (screenHeight * bottomSheetHeightRatio)) /
              screenHeight;

      double pickupZoom = 17.0;
      if (visibleMapRatio < 0.5) {
        pickupZoom = 16.0; // Zoom réduit pour petite zone
      } else if (visibleMapRatio > 0.75) {
        pickupZoom = 18.0; // Zoom augmenté pour grande zone
      }

      // Position instantanée (sans animation) sur le pickup
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pickupPoint,
            zoom: pickupZoom,
            bearing: 0.0,
          ),
        ),
      );

      myCustomPrintStatement(
          "📍 Positionnement instantané sur pickup à zoom $pickupZoom");

      // Étape 2: Pause courte pour stabilisation
      await Future.delayed(const Duration(milliseconds: 300));

      // Étape 3: Dézoom progressif intelligent en 2 secondes exactement
      myCustomPrintStatement("🎥 Lancement dézoom progressif contrôlé 2.0s");
      await _executeTimedBoundsAnimation(
          routeCoordinates, const Duration(milliseconds: 2000));
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur animation principale, utilisation fallback complet: $e");
      // Fallback ultime avec animation complète
      await _executeCompleteRouteAnimation(routeCoordinates);
    }
  }

  /// Exécute l'animation complète de l'itinéraire avec pause 3s puis dézoom 1.5s
  Future<void> _executeCompleteRouteAnimation(
      List<LatLng> routeCoordinates) async {
    if (routeCoordinates.isEmpty) return;

    try {
      myCustomPrintStatement(
          "🎬 Exécution animation complète 4.5s avec adaptation automatique");

      // Détection automatique du contexte pour adaptation
      double bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenHeight = MediaQuery.of(context).size.height;
      final visibleMapRatio =
          (screenHeight - (screenHeight * bottomSheetHeightRatio)) /
              screenHeight;

      // Étape 1: Positionnement instantané sur le point de prise en charge
      final pickupPoint = routeCoordinates.first;
      double adaptivePickupZoom = 17.0;
      if (visibleMapRatio < 0.5) {
        adaptivePickupZoom = 16.0; // Zoom plus faible si peu de place
      } else if (visibleMapRatio > 0.75) {
        adaptivePickupZoom = 18.0; // Zoom plus fort si beaucoup de place
      }

      // Positionnement instantané (sans animation) sur le pickup
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pickupPoint,
            zoom: adaptivePickupZoom,
            bearing: 0.0,
          ),
        ),
      );

      myCustomPrintStatement(
          "📍 Position initiale pickup à zoom $adaptivePickupZoom");

      // Étape 2: Pause de 3 secondes sur le point de prise en charge
      myCustomPrintStatement("⏸️ Pause 3s sur point de pickup");
      await Future.delayed(const Duration(milliseconds: 3000));

      // Étape 3: Animation temporisée de 1.5 seconde exactement (direct)
      myCustomPrintStatement("🎥 Lancement animation complète direct 1.5s");
      await _executeTimedBoundsAnimation(
          routeCoordinates, const Duration(milliseconds: 1500));

      myCustomPrintStatement(
          "✅ Animation complète 4.5s terminée - Zone visible: ${(visibleMapRatio * 100).toInt()}%");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur animation fallback complète: $e");
    }
  }

  /// Exécute l'animation avec une durée contrôlée exacte
  /// Utilise une animation personnalisée pour garantir la durée de 2 secondes
  Future<void> _executeTimedBoundsAnimation(
      List<LatLng> routeCoordinates, Duration animationDuration) async {
    if (routeCoordinates.isEmpty) return;

    try {
      myCustomPrintStatement(
          "⏱️ Démarrage animation temporisée: ${animationDuration.inMilliseconds}ms");

      // Détection de la plateforme iOS
      final bool isIOS = Platform.isIOS;

      // Calculer les bounds avec adaptation contextuelle
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenSize = MediaQuery.of(context).size;
      final screenHeight = screenSize.height;

      double bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final visibleMapRatio =
          (screenHeight - (screenHeight * bottomSheetHeightRatio)) /
              screenHeight;

      // Calculer les bounds basiques de l'itinéraire
      double minLat = routeCoordinates.first.latitude;
      double maxLat = routeCoordinates.first.latitude;
      double minLng = routeCoordinates.first.longitude;
      double maxLng = routeCoordinates.first.longitude;

      for (var point in routeCoordinates) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      // Sur iOS, utiliser une approche différente pour éviter le bug de dézoom extrême
      if (isIOS) {
        myCustomPrintStatement(
            "📱 iOS détecté - utilisation de l'animation par bounds avec padding fixe");

        // Calculer le centre de l'itinéraire
        final centerLat = (minLat + maxLat) / 2;
        final centerLng = (minLng + maxLng) / 2;

        // Calculer les spans de latitude et longitude
        final latSpan = maxLat - minLat;
        final lngSpan = maxLng - minLng;

        // Utiliser un calcul de zoom basé sur les spans plutôt que sur la distance euclidienne
        // Ceci évite les erreurs de calcul qui causent le dézoom extrême
        double zoomLevel;
        final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

        // Calcul du zoom basé sur le span maximal
        // Ces valeurs sont calibrées pour éviter le dézoom extrême
        if (maxSpan > 1.0) {
          zoomLevel = 6.0; // Très grande distance
        } else if (maxSpan > 0.5) {
          zoomLevel = 7.0;
        } else if (maxSpan > 0.2) {
          zoomLevel = 8.0;
        } else if (maxSpan > 0.1) {
          zoomLevel = 9.0;
        } else if (maxSpan > 0.05) {
          zoomLevel = 10.0;
        } else if (maxSpan > 0.02) {
          zoomLevel = 11.0;
        } else if (maxSpan > 0.01) {
          zoomLevel = 12.0;
        } else if (maxSpan > 0.005) {
          zoomLevel = 13.0;
        } else if (maxSpan > 0.002) {
          zoomLevel = 14.0;
        } else if (maxSpan > 0.001) {
          zoomLevel = 15.0;
        } else {
          zoomLevel = 16.0;
        }

        // Ajuster le zoom selon la zone visible (réduction moins agressive)
        if (visibleMapRatio < 0.5) {
          zoomLevel -= 0.3; // Réduction plus douce
        }

        // S'assurer que le zoom ne descend jamais en dessous de 8 (pour éviter la vue globe sur écran paiement)
        zoomLevel = zoomLevel.clamp(8.0, 20.0);

        // Ajuster le centre verticalement pour compenser le bottom sheet
        final adjustedCenterLat =
            centerLat + latSpan * (bottomSheetHeightRatio * 0.15);
        final adjustedCenter = LatLng(adjustedCenterLat, centerLng);

        myCustomPrintStatement(
            "🎯 Animation iOS: Centre=$adjustedCenter, Zoom=$zoomLevel, Span max=$maxSpan");

        // Animation avec position et zoom calculés
        final startTime = DateTime.now();

        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: adjustedCenter,
              zoom: zoomLevel,
              bearing: 0.0,
            ),
          ),
        );

        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < animationDuration) {
          final remainingTime = animationDuration - elapsed;
          await Future.delayed(remainingTime);
        }

        myCustomPrintStatement(
            "✅ Animation iOS terminée avec zoom calculé sécurisé");
      } else {
        // Android : utiliser la méthode bounds standard qui fonctionne bien
        myCustomPrintStatement(
            "🤖 Android détecté - utilisation de l'animation bounds standard");

        // Padding adaptatif selon la zone visible - augmenté pour plus de marge
        double adaptivePaddingFactor;
        if (visibleMapRatio > 0.75) {
          adaptivePaddingFactor =
              0.15; // Zone très visible - padding confortable
        } else if (visibleMapRatio > 0.6) {
          adaptivePaddingFactor = 0.20; // Zone bien visible - padding généreux
        } else if (visibleMapRatio > 0.45) {
          adaptivePaddingFactor = 0.25; // Zone moyenne - padding élargi
        } else {
          adaptivePaddingFactor = 0.30; // Zone réduite - padding maximal
        }

        final latPadding = (maxLat - minLat) * adaptivePaddingFactor;
        final lngPadding = (maxLng - minLng) * adaptivePaddingFactor;

        // Ajustement vertical pour compenser la fenêtre
        final verticalOffset =
            (maxLat - minLat) * (bottomSheetHeightRatio * 0.1);

        final adjustedBounds = LatLngBounds(
          southwest:
              LatLng(minLat - latPadding + verticalOffset, minLng - lngPadding),
          northeast:
              LatLng(maxLat + latPadding + verticalOffset, maxLng + lngPadding),
        );

        // Padding d'animation adaptatif - augmenté pour plus de marge
        double animationPadding;
        if (visibleMapRatio > 0.7) {
          animationPadding = 80.0; // Padding généreux pour zone large
        } else if (visibleMapRatio > 0.5) {
          animationPadding = 100.0; // Padding élargi pour zone moyenne
        } else {
          animationPadding = 120.0; // Padding maximal pour zone réduite
        }

        // Animation directe avec contrôle temporel exact
        final startTime = DateTime.now();

        // SOLUTION RADICALE : Remplacer newLatLngBounds par IOSMapFix
        await IOSMapFix.safeFitBounds(
          controller: controller,
          points: routeCoordinates,
          bottomSheetRatio: visibleMapRatio < 0.5 ? 0.6 : 0.4,
          debugSource: "smartBoundsAnimation-iOS",
        );

        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < animationDuration) {
          final remainingTime = animationDuration - elapsed;
          await Future.delayed(remainingTime);
        }

        myCustomPrintStatement("✅ Animation Android terminée avec bounds");
      }
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur animation temporisée, fallback vers animation standard: $e");
      // Fallback vers la méthode standard
      await _executeSmartBoundsAnimation(routeCoordinates);
    }
  }

  /// Exécute l'animation avec bounds calculés spécifiquement pour la zone visible de la carte
  /// Adaptation automatique selon la taille et position des fenêtres contextuelles
  Future<void> _executeSmartBoundsAnimation(
      List<LatLng> routeCoordinates) async {
    if (routeCoordinates.isEmpty) return;

    try {
      myCustomPrintStatement(
          "🎯 Calcul des bounds adaptatifs avec détection automatique des fenêtres");

      // Détection de la plateforme iOS
      final bool isIOS = Platform.isIOS;

      // Obtenir les informations de contexte pour l'adaptation automatique
      final context = MyGlobalKeys.navigatorKey.currentContext!;
      final screenSize = MediaQuery.of(context).size;
      final screenHeight = screenSize.height;
      final screenWidth = screenSize.width;

      // Détection automatique de la hauteur de fenêtre actuelle
      double bottomSheetHeightRatio = _getBottomSheetHeightForCurrentContext();
      final bottomSheetHeightPx = screenHeight * bottomSheetHeightRatio;
      final visibleMapHeight = screenHeight - bottomSheetHeightPx;
      final visibleMapRatio = visibleMapHeight / screenHeight;

      myCustomPrintStatement(
          "📐 Adaptation auto: Écran ${screenHeight.toInt()}px, Fenêtre ${bottomSheetHeightPx.toInt()}px (${(bottomSheetHeightRatio * 100).toInt()}%), Zone visible ${visibleMapHeight.toInt()}px (${(visibleMapRatio * 100).toInt()}%)");

      // Calculer les bounds basiques de l'itinéraire
      double minLat = routeCoordinates.first.latitude;
      double maxLat = routeCoordinates.first.latitude;
      double minLng = routeCoordinates.first.longitude;
      double maxLng = routeCoordinates.first.longitude;

      for (var point in routeCoordinates) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      // Sur iOS, utiliser une approche par zoom calculé pour éviter le bug
      if (isIOS) {
        myCustomPrintStatement(
            "📱 iOS détecté dans fallback - utilisation du zoom calculé sécurisé");

        // Calculer le centre de l'itinéraire
        final centerLat = (minLat + maxLat) / 2;
        final centerLng = (minLng + maxLng) / 2;

        // Calculer les spans de latitude et longitude
        final latSpan = maxLat - minLat;
        final lngSpan = maxLng - minLng;

        // Utiliser le span maximal pour déterminer le zoom
        double zoomLevel;
        final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

        // Calcul du zoom basé sur le span maximal
        if (maxSpan > 1.0) {
          zoomLevel = 6.0; // Très grande distance
        } else if (maxSpan > 0.5) {
          zoomLevel = 7.0;
        } else if (maxSpan > 0.2) {
          zoomLevel = 8.0;
        } else if (maxSpan > 0.1) {
          zoomLevel = 9.0;
        } else if (maxSpan > 0.05) {
          zoomLevel = 10.0;
        } else if (maxSpan > 0.02) {
          zoomLevel = 11.0;
        } else if (maxSpan > 0.01) {
          zoomLevel = 12.0;
        } else if (maxSpan > 0.005) {
          zoomLevel = 13.0;
        } else if (maxSpan > 0.002) {
          zoomLevel = 14.0;
        } else if (maxSpan > 0.001) {
          zoomLevel = 15.0;
        } else {
          zoomLevel = 16.0;
        }

        // Ajuster selon la zone visible (réduction moins agressive)
        if (visibleMapRatio < 0.5) {
          zoomLevel -= 0.3;
        }

        // S'assurer que le zoom ne descend jamais en dessous de 8
        zoomLevel = zoomLevel.clamp(8.0, 20.0);

        // Ajuster le centre verticalement
        final adjustedCenterLat =
            centerLat + latSpan * (bottomSheetHeightRatio * 0.15);
        final adjustedCenter = LatLng(adjustedCenterLat, centerLng);

        myCustomPrintStatement(
            "🎯 Animation iOS fallback: Zoom=$zoomLevel, Span max=$maxSpan");

        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: adjustedCenter,
              zoom: zoomLevel,
              bearing: 0.0,
            ),
          ),
        );

        myCustomPrintStatement(
            "✅ Animation iOS fallback avec zoom calculé sécurisé: $zoomLevel");
      } else {
        // Android : utiliser la méthode bounds standard
        myCustomPrintStatement(
            "🤖 Android détecté dans fallback - utilisation des bounds");

        // PADDING ADAPTATIF selon la zone visible de la carte - augmenté pour plus de marge
        double adaptivePaddingFactor;
        if (visibleMapRatio > 0.75) {
          adaptivePaddingFactor = 0.15;
        } else if (visibleMapRatio > 0.6) {
          adaptivePaddingFactor = 0.20;
        } else if (visibleMapRatio > 0.45) {
          adaptivePaddingFactor = 0.25;
        } else {
          adaptivePaddingFactor = 0.30;
        }

        final latPadding = (maxLat - minLat) * adaptivePaddingFactor;
        final lngPadding = (maxLng - minLng) * adaptivePaddingFactor;

        // Ajustement vertical pour compenser la position de la fenêtre
        final verticalOffset =
            (maxLat - minLat) * (bottomSheetHeightRatio * 0.1);

        final adjustedBounds = LatLngBounds(
          southwest:
              LatLng(minLat - latPadding + verticalOffset, minLng - lngPadding),
          northeast:
              LatLng(maxLat + latPadding + verticalOffset, maxLng + lngPadding),
        );

        // Padding d'animation adaptatif
        double animationPadding;
        if (visibleMapRatio > 0.7) {
          animationPadding = 80.0;
        } else if (visibleMapRatio > 0.5) {
          animationPadding = 100.0;
        } else {
          animationPadding = 120.0;
        }

        // SOLUTION RADICALE : Remplacer newLatLngBounds par IOSMapFix
        await IOSMapFix.safeFitBounds(
          controller: controller,
          points: routeCoordinates,
          bottomSheetRatio: visibleMapRatio < 0.5 ? 0.6 : 0.4,
          debugSource: "smartBoundsAnimation-iOS",
        );

        myCustomPrintStatement(
            "✅ Animation Android fallback avec bounds réussie");
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur animation bounds intelligents: $e");
      // Fallback ultime : zoom simple sur le centre
      try {
        final centerLat =
            (routeCoordinates.first.latitude + routeCoordinates.last.latitude) /
                2;
        final centerLng = (routeCoordinates.first.longitude +
                routeCoordinates.last.longitude) /
            2;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(centerLat, centerLng),
              zoom: 13.0,
              bearing: 0.0,
            ),
          ),
        );
        myCustomPrintStatement("✅ Fallback ultime avec zoom simple réussi");
      } catch (ultimateFallbackError) {
        myCustomPrintStatement(
            "❌ Erreur fallback ultime: $ultimateFallbackError");
      }
    }
  }

  /// Animation de chargement progressif de la ligne d'itinéraire (une seule fois)
  /// La ligne se trace du point de départ vers l'arrivée avec un dégradé blanc vers noir
  Future<void> _animateRouteLoading() async {
    if (polylineCoordinates.isEmpty || isAnimatingRoute) return;

    myCustomPrintStatement("🎨 Début animation de tracé de ligne");
    isAnimatingRoute = true;
    animatedPolylineCoordinates = [];

    try {
      // Supprimer l'ancienne polyline animée si elle existe
      await updatePolyline(polylineName: "animated_path");

      const int animationDuration = 500; // 500ms pour une animation rapide
      const int frameRate = 30; // 30 FPS pour être fluide
      final int totalFrames = (animationDuration / (1000 / frameRate)).round();
      final int frameDuration = (1000 / frameRate).round();

      final int totalPoints = polylineCoordinates.length;
      myCustomPrintStatement(
          "🎨 Animation: ${totalPoints} points à tracer en ${totalFrames} frames");

      // Animation unique : tracé progressif du polyline
      for (int frame = 0; frame <= totalFrames && isAnimatingRoute; frame++) {
        final double progress = frame / totalFrames;
        final int pointsToShow =
            (totalPoints * progress).round().clamp(0, totalPoints);

        // Créer la liste des points à afficher pour cette frame
        animatedPolylineCoordinates =
            polylineCoordinates.take(pointsToShow).toList();

        if (animatedPolylineCoordinates.length >= 2) {
          // Calculer la couleur basée sur le progrès (dégradé blanc vers gris foncé)
          final int colorValue = (255 * (1 - progress * 0.8))
              .round()
              .clamp(50, 255);
          final Color animationColor =
              Color.fromARGB(255, colorValue, colorValue, colorValue);

          // Créer une polyline animée
          final animatedPolyline = Polyline(
            polylineId: const PolylineId('animated_path'),
            color: animationColor,
            width: 5,
            geodesic: true,
            visible: true,
            points: animatedPolylineCoordinates,
          );

          // Ajouter la polyline animée
          await addPolyline(animatedPolyline);
        }

        // Attendre avant la prochaine frame
        await Future.delayed(Duration(milliseconds: frameDuration));
      }

      myCustomPrintStatement("🎨 Animation de tracé terminée - polyline complet affiché");
      // Garder le polyline final affiché (ne pas le supprimer)
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de l'animation de chargement: $e");
    } finally {
      isAnimatingRoute = false;
      animatedPolylineCoordinates = [];
    }
  }

  /// Arrêter l'animation de chargement
  void stopRouteAnimation() {
    myCustomPrintStatement("🛑 Arrêt de l'animation de tracé");
    isAnimatingRoute = false;
    updatePolyline(polylineName: "animated_path");
  }

  /// Nettoyer toutes les polylines et réinitialiser l'état de la carte
  void clearAllPolylines() {
    myCustomPrintStatement(
        "🧹 Nettoyage de toutes les polylines et itinéraires");

    // Vider toutes les polylines
    polyLines.clear();

    // Réinitialiser les coordonnées
    polylineCoordinates.clear();
    coveredPolylineCoordinates.clear();
    animatedPolylineCoordinates.clear();

    // Réinitialiser les états
    visiblePolyline = false;
    visibleCoveredPolyline = false;
    isAnimatingRoute = false;

    // Notifier les listeners pour mettre à jour l'interface
    notifyListeners();
  }

  /// Recentrer la carte sur l'itinéraire existant avec padding intelligent
  Future<void> recenterOnRoute() async {
    if (polylineCoordinates.isEmpty) {
      myCustomPrintStatement("🎯 Pas d'itinéraire à recentrer");
      return;
    }

    myCustomPrintStatement(
        "🎯 Recentrage sur l'itinéraire avec padding intelligent");

    try {
      // Utiliser le système de padding intelligent du TripProvider
      final tripProvider = Provider.of<TripProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false,
      );

      tripProvider.recenterMapWithDynamicPadding(this);
    } catch (e) {
      myCustomPrintStatement("Erreur lors du recentrage intelligent: $e");
      // Fallback vers la méthode simple
      final bounds = GoogleMapProvider.getLatLongBoundsFromLatLngList(
        polylineCoordinates,
        topPaddingPercentage: 0.15, // Padding généreux pour cohérence
        bottomPaddingPercentage: 0.15,
      );

      if (bounds != null) {
        try {
          // SOLUTION RADICALE : Remplacer newLatLngBounds par IOSMapFix
          await IOSMapFix.safeFitBounds(
            controller: controller,
            points: polylineCoordinates,
            bottomSheetRatio: 0.15,
            debugSource: "showRouteToUser-fallback",
          );
        } catch (fallbackError) {
          myCustomPrintStatement("Erreur de fallback: $fallbackError");
        }
      }
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🧭 NOUVELLE MÉTHODE : Ajustement itinéraire avec la méthode FitBounds + ScrollBy
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 🎯 Ajuste l'affichage de l'itinéraire au-dessus du bottom sheet
  ///
  /// Cette méthode utilise la nouvelle fonction utilitaire `MapUtils.fitRouteAboveBottomView`
  /// qui implémente une approche simple et efficace :
  /// 1. FitBounds pour cadrer l'itinéraire
  /// 2. ScrollBy pour décaler la caméra vers le haut
  ///
  /// **Utilisation :**
  /// ```dart
  /// await googleMapProvider.fitRouteAboveBottomSheet(padding: 80);
  /// ```
  ///
  /// **Paramètres :**
  /// - `padding` : Padding autour de l'itinéraire (défaut: 60px)
  /// - `customBottomRatio` : Ratio personnalisé du bottom sheet (si null, détecté automatiquement)
  Future<void> fitRouteAboveBottomSheet({
    double padding = 60.0,
    double? customBottomRatio,
  }) async {
    if (polylineCoordinates.isEmpty) {
      myCustomPrintStatement(
          "⚠️ fitRouteAboveBottomSheet: Pas d'itinéraire à afficher");
      return;
    }

    if (!isControllerReady) {
      myCustomPrintStatement(
          "⚠️ fitRouteAboveBottomSheet: Contrôleur non initialisé");
      return;
    }

    try {
      final context = MyGlobalKeys.navigatorKey.currentContext;
      if (context == null) {
        myCustomPrintStatement(
            "⚠️ fitRouteAboveBottomSheet: Contexte non disponible");
        return;
      }

      // Déterminer le ratio du bottom sheet (auto ou personnalisé)
      final bottomSheetRatio =
          customBottomRatio ?? _getBottomSheetHeightForCurrentContext();

      myCustomPrintStatement(
          "🗺️ fitRouteAboveBottomSheet: Ajustement avec ratio ${(bottomSheetRatio * 100).toInt()}%, padding ${padding.toInt()}px");

      // Appeler la fonction utilitaire
      await MapUtils.fitRouteAboveBottomView(
        controller: controller,
        routePoints: polylineCoordinates,
        context: context,
        bottomViewRatio: bottomSheetRatio,
        padding: padding,
      );

      myCustomPrintStatement(
          "✅ fitRouteAboveBottomSheet: Ajustement terminé avec succès");
    } catch (e) {
      myCustomPrintStatement(
          "❌ fitRouteAboveBottomSheet: Erreur lors de l'ajustement: $e");
      // Fallback vers IOSMapFix si erreur
      try {
        await IOSMapFix.safeFitBounds(
          controller: controller,
          points: polylineCoordinates,
          bottomSheetRatio: customBottomRatio ?? 0.4,
          debugSource: "fitRouteAboveBottomSheet-fallback",
        );
      } catch (fallbackError) {
        myCustomPrintStatement(
            "❌ fitRouteAboveBottomSheet: Erreur fallback: $fallbackError");
      }
    }
  }

  /// Réadapte l'affichage de l'itinéraire quand la height de bottom view change
  /// Utilisé pour les écrans comme "Choisir le mode de paiement", etc.
  Future<void> adaptRouteToBottomSheetHeightChange() async {
    if (polylineCoordinates.isEmpty || !isControllerReady) {
      myCustomPrintStatement("🎯 Aucun itinéraire à réadapter");
      return;
    }

    try {
      myCustomPrintStatement(
          "🔄 Réadaptation de l'itinéraire à la nouvelle hauteur du bottom sheet");

      // ✨ NOUVELLE APPROCHE : Utiliser fitRouteAboveBottomSheet (FitBounds + ScrollBy)
      // au lieu de l'ancienne méthode _showCompleteRouteWithGuaranteedVisibility
      await fitRouteAboveBottomSheet(
        padding: 60.0,
        // Le ratio sera automatiquement détecté selon le contexte actuel
      );
    } catch (e) {
      myCustomPrintStatement(
          "❌ Erreur lors de la réadaptation de l'itinéraire: $e");
    }
  }

  static LatLngBounds? getLatLongBoundsFromLatLngList(List<LatLng> latLongList,
      {double bottomPaddingPercentage = 0.01,
      double topPaddingPercentage = 0.1}) {
    if (latLongList.isEmpty) {
      return null;
    }

    double minLat = latLongList[0].latitude;
    double maxLat = latLongList[0].latitude;
    double minLong = latLongList[0].longitude;
    double maxLong = latLongList[0].longitude;

    for (var latLong in latLongList) {
      double lat = latLong.latitude;
      double long = latLong.longitude;
      minLat = (lat < minLat) ? lat : minLat;
      maxLat = (lat > maxLat) ? lat : maxLat;
      minLong = (long < minLong) ? long : minLong;
      maxLong = (long > maxLong) ? long : maxLong;
    }

    // Calculate the latitudinal and longitudinal span
    double latSpan = maxLat - minLat;
    double longSpan = maxLong - minLong;

    // Calculate the bottom and top padding
    double latBottomPadding = latSpan * bottomPaddingPercentage;
    double latTopPadding = latSpan * topPaddingPercentage;

    // Calculate the longitudinal padding based on the larger span
    double paddingPercentage = bottomPaddingPercentage;
    if (latSpan > longSpan) {
      paddingPercentage = 0.1;
    } else {
      paddingPercentage = 0.05;
    }
    double longPadding = longSpan * paddingPercentage;

    // Adjust the bounds by the padding
    minLat -= latBottomPadding;
    maxLat += latTopPadding;
    minLong -= longPadding;
    maxLong += longPadding;

    return LatLngBounds(
        southwest: LatLng(minLat, minLong), northeast: LatLng(maxLat, maxLong));
  }

  Future<LatLngBounds> getLatLongBounds(List<List<double>> latLongList) async {
    double minLat = latLongList[0][0];
    double maxLat = latLongList[0][0];
    double minLong = latLongList[0][1];
    double maxLong = latLongList[0][1];

    for (var latLong in latLongList) {
      double lat = latLong[0];
      double long = latLong[1];
      minLat = (lat < minLat) ? lat : minLat;
      maxLat = (lat > maxLat) ? lat : maxLat;
      minLong = (long < minLong) ? long : minLong;
      maxLong = (long > maxLong) ? long : maxLong;
    }

    myCustomPrintStatement(
        "distance  min lat ---- $minLat --- max lat---- $maxLat min long ---- $minLong max long ---- $maxLong");

    return LatLngBounds(
      northeast: LatLng(maxLat, maxLong),
      southwest: LatLng(minLat, minLong),
    );
  }
}
