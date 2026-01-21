import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:js_util' as js_util;
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/places_autocomplete_web.dart';
import 'package:rider_ride_hailing_app/services/route_service.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart' show LoginPage;
import 'package:rider_ride_hailing_app/pages/auth_module/signup_screen.dart' show SignUpScreen;
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';

/// Page d'accueil Web style Uber - version allégée
/// Affiche une carte pleine page avec:
/// - Header avec logo + boutons connexion
/// - Carte Google Maps en fond
/// - Formulaire de recherche flottant à gauche avec autocomplete
class HomeScreenWeb extends StatefulWidget {
  const HomeScreenWeb({super.key});

  @override
  State<HomeScreenWeb> createState() => _HomeScreenWebState();
}

class _HomeScreenWebState extends State<HomeScreenWeb> {
  GoogleMapController? _mapController;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Mode principal: 0 = Course, 1 = Transports
  final ValueNotifier<int> _mainMode = ValueNotifier(0);

  // Focus nodes pour gérer le focus des champs
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  // Position par défaut: Antananarivo, Madagascar (Ankadifotsy)
  static const LatLng _defaultPosition = LatLng(-18.9103, 47.5305);

  // Subscription pour les chauffeurs en ligne
  StreamSubscription<QuerySnapshot>? _driversSubscription;

  // Markers pour la carte (chauffeurs)
  Set<Marker> _driverMarkers = {};

  // Animation des markers - stockage des positions actuelles et cibles
  final Map<String, LatLng> _currentDriverPositions = {};
  final Map<String, LatLng> _targetDriverPositions = {};
  final Map<String, LatLng> _startDriverPositions = {}; // Positions au début de l'animation
  final Map<String, double> _currentDriverHeadings = {};
  final Map<String, double> _targetDriverHeadings = {};
  final Map<String, double> _startDriverHeadings = {}; // Headings au début de l'animation
  final Map<String, DriverModal> _driversData = {};
  Timer? _animationTimer;
  static const Duration _animationDuration = Duration(milliseconds: 800); // Plus rapide
  static const int _animationSteps = 24; // Moins de steps mais plus fluide

  // Polylines pour l'itinéraire
  Set<Polyline> _routePolylines = {};

  // Position du pickup pour charger les chauffeurs proches
  LatLng? _pickupLatLng;

  // État pour afficher le panneau de sélection de véhicule
  final ValueNotifier<bool> _showVehicleSelection = ValueNotifier(false);
  final ValueNotifier<int> _selectedVehicleIndex = ValueNotifier(-1);

  // Style de carte personnalisé - POIs masqués pour éviter les clics
  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#A6B5DE"}]},{"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":3}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#BCC5E8"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.local","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road","elementType":"labels","stylers":[{"visibility":"on"}]},{"featureType":"road.highway","elementType":"labels.icon","stylers":[{"visibility":"on"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#ADD4F5"}]},{"featureType":"poi","stylers":[{"visibility":"off"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"transit.station","stylers":[{"visibility":"off"}]}]';

  // === Transport mode data ===
  List<TransportLineGroup> _transportLines = [];
  Set<Polyline> _transportPolylines = {};
  Set<Marker> _transportMarkers = {};
  bool _transportLinesLoaded = false;

  // Données de localisation
  Map<String, dynamic> _pickupLocation = {
    'lat': null,
    'lng': null,
    'address': null,
  };
  Map<String, dynamic> _destinationLocation = {
    'lat': null,
    'lng': null,
    'address': null,
  };

  // Suggestions autocomplete
  final ValueNotifier<List> _pickupSuggestions = ValueNotifier([]);
  final ValueNotifier<List> _destinationSuggestions = ValueNotifier([]);
  final ValueNotifier<bool> _isPickupFocused = ValueNotifier(false);
  final ValueNotifier<bool> _isDestinationFocused = ValueNotifier(false);
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);

  // Debounce timers
  Timer? _pickupDebounceTimer;
  Timer? _destinationDebounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 400);
  static const int _minCharsForSearch = 3;
  String? _lastPickupQuery;
  String? _lastDestinationQuery;

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
    _initializeAndSubscribe();
    _readUrlParameters();
  }

  /// Lit les paramètres URL pour pré-remplir les champs (depuis le widget misy.app)
  void _readUrlParameters() {
    if (!kIsWeb) return;

    try {
      print('🔍 _readUrlParameters appelée');
      print('🔍 URL complète: ${html.window.location.href}');
      final uri = Uri.parse(html.window.location.href);
      // Les paramètres sont après le # dans Flutter web
      final fragment = uri.fragment; // ex: /home?pickup=xxx&destination=yyy
      print('🔍 Fragment: $fragment');
      if (fragment.contains('?')) {
        final queryString = fragment.split('?').last;
        final params = Uri.splitQueryString(queryString);

        final pickup = params['pickup'];
        final destination = params['destination'];
        final pickupLat = params['pickupLat'];
        final pickupLng = params['pickupLng'];
        final destLat = params['destLat'];
        final destLng = params['destLng'];

        print('📍 URL params: pickup=$pickup, destination=$destination');

        // Pré-remplir le champ pickup
        if (pickup != null && pickup.isNotEmpty) {
          _pickupController.text = pickup;

          // Si on a les coordonnées, les utiliser
          if (pickupLat != null && pickupLng != null) {
            final lat = double.tryParse(pickupLat);
            final lng = double.tryParse(pickupLng);
            if (lat != null && lng != null) {
              _pickupLocation = {'lat': lat, 'lng': lng, 'address': pickup};
              _pickupLatLng = LatLng(lat, lng);
            }
          }
        }

        // Pré-remplir le champ destination
        if (destination != null && destination.isNotEmpty) {
          _destinationController.text = destination;

          // Si on a les coordonnées, les utiliser
          if (destLat != null && destLng != null) {
            final lat = double.tryParse(destLat);
            final lng = double.tryParse(destLng);
            if (lat != null && lng != null) {
              _destinationLocation = {'lat': lat, 'lng': lng, 'address': destination};
            }
          }
        }

        // Focus sur le champ approprié et déclencher l'autocomplete
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (mounted) {
            if (_pickupController.text.isNotEmpty && _pickupLocation['lat'] == null) {
              // Pickup rempli mais pas de coordonnées → focus + déclencher autocomplete
              print('📍 Déclenchement autocomplete pickup: ${_pickupController.text}');
              _pickupFocusNode.requestFocus();
              // Appeler directement l'API au lieu du debounce
              final predictions = await PlacesAutocompleteWeb.getPlacePredictions(_pickupController.text);
              print('📍 Résultats pickup: ${predictions.length}');
              if (mounted) {
                _pickupSuggestions.value = predictions;
              }
            } else if (_destinationController.text.isNotEmpty && _destinationLocation['lat'] == null) {
              // Destination remplie mais pas de coordonnées → focus + déclencher autocomplete
              print('📍 Déclenchement autocomplete destination: ${_destinationController.text}');
              _destinationFocusNode.requestFocus();
              final predictions = await PlacesAutocompleteWeb.getPlacePredictions(_destinationController.text);
              print('📍 Résultats destination: ${predictions.length}');
              if (mounted) {
                _destinationSuggestions.value = predictions;
              }
            } else if (_pickupController.text.isEmpty) {
              _pickupFocusNode.requestFocus();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur lecture URL params: $e');
    }
  }

  /// Attend que vehicleMap soit chargé avant de s'abonner aux chauffeurs
  Future<void> _initializeAndSubscribe() async {
    // Attendre que les types de véhicules soient chargés (max 5 secondes)
    int attempts = 0;
    while (vehicleMap.isEmpty && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (vehicleMap.isEmpty) {
      debugPrint('⚠️ vehicleMap toujours vide après 5s, chargement des chauffeurs quand même');
    } else {
      debugPrint('✅ vehicleMap chargé avec ${vehicleMap.length} types de véhicules');
    }

    _subscribeToOnlineDrivers();
  }

  void _setupFocusListeners() {
    _pickupFocusNode.addListener(() {
      _isPickupFocused.value = _pickupFocusNode.hasFocus;
      if (!_pickupFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_pickupFocusNode.hasFocus) {
            _pickupSuggestions.value = [];
          }
        });
      }
    });

    _destinationFocusNode.addListener(() {
      _isDestinationFocused.value = _destinationFocusNode.hasFocus;
      if (!_destinationFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_destinationFocusNode.hasFocus) {
            _destinationSuggestions.value = [];
          }
        });
      }
    });
  }

  /// S'abonne aux chauffeurs en ligne et affiche les 8 plus proches
  void _subscribeToOnlineDrivers() {
    _driversSubscription?.cancel();

    debugPrint('🚕 _subscribeToOnlineDrivers: Démarrage de la souscription...');

    _driversSubscription = FirestoreServices.users
        .where('isCustomer', isEqualTo: false)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((event) async {
      debugPrint('🚕 Snapshot reçu: ${event.docs.length} chauffeurs en ligne');

      if (!mounted) {
        debugPrint('🚕 Widget non monté, abandon');
        return;
      }

      final centerLat = _pickupLatLng?.latitude ?? _defaultPosition.latitude;
      final centerLng = _pickupLatLng?.longitude ?? _defaultPosition.longitude;

      debugPrint('🚕 Centre de recherche: $centerLat, $centerLng');

      List<Map<String, dynamic>> driversWithDistance = [];

      for (int i = 0; i < event.docs.length; i++) {
        try {
          final data = event.docs[i].data() as Map<String, dynamic>;
          DriverModal driver = DriverModal.fromJson(data);

          debugPrint('🚕 Chauffeur $i: ${driver.firstName} - lat: ${driver.currentLat}, lng: ${driver.currentLng}, vehicleType: ${driver.vehicleType}');

          if (driver.currentLat != null && driver.currentLng != null) {
            var distance = getDistance(
              driver.currentLat!,
              driver.currentLng!,
              centerLat,
              centerLng,
            );

            debugPrint('🚕   Distance: ${distance.toStringAsFixed(2)} km');

            if (distance <= 20) {
              driversWithDistance.add({
                'distance': distance,
                'driverData': driver,
              });
            }
          } else {
            debugPrint('🚕   Position manquante, ignoré');
          }
        } catch (e) {
          debugPrint('🚕 Erreur parsing chauffeur $i: $e');
        }
      }

      debugPrint('🚕 ${driversWithDistance.length} chauffeurs dans le rayon de 20km');

      driversWithDistance.sort((a, b) => a['distance'].compareTo(b['distance']));
      final nearest8 = driversWithDistance.take(8).toList();

      debugPrint('🚕 ${nearest8.length} chauffeurs les plus proches à afficher');

      await _updateDriverMarkers(nearest8);
    }, onError: (error) {
      debugPrint('🚕 ❌ Erreur Firestore: $error');
    });
  }

  void _reloadDriversNearPosition(LatLng position) {
    _pickupLatLng = position;
    _subscribeToOnlineDrivers();
  }

  final Map<String, BitmapDescriptor> _vehicleIconCache = {};

  Future<void> _updateDriverMarkers(List<Map<String, dynamic>> drivers) async {
    if (!mounted) return;

    debugPrint('🚗 Mise à jour des markers: ${drivers.length} chauffeurs, vehicleMap: ${vehicleMap.length} entrées');

    // Collecter les IDs des nouveaux drivers
    final newDriverIds = <String>{};
    bool hasNewDrivers = false;

    for (var driverInfo in drivers) {
      final DriverModal driver = driverInfo['driverData'];
      final String driverId = driver.id ?? 'driver_${drivers.indexOf(driverInfo)}';
      newDriverIds.add(driverId);

      final newPosition = LatLng(driver.currentLat!, driver.currentLng!);

      // Stocker les données du driver
      _driversData[driverId] = driver;

      // Si le driver n'existe pas encore, initialiser sa position
      if (!_currentDriverPositions.containsKey(driverId)) {
        // Nouveau driver - utiliser le heading de Firestore ou un angle aléatoire basé sur l'ID
        final initialHeading = driver.heading ?? (driverId.hashCode % 360).toDouble();
        _currentDriverPositions[driverId] = newPosition;
        _currentDriverHeadings[driverId] = initialHeading;
        _targetDriverPositions[driverId] = newPosition;
        _targetDriverHeadings[driverId] = initialHeading;
        hasNewDrivers = true;
        debugPrint('🚗 Nouveau chauffeur: $driverId heading initial: ${initialHeading.toStringAsFixed(0)}°');
      } else {
        // Driver existant - calculer le heading à partir du mouvement
        final oldPosition = _targetDriverPositions[driverId] ?? _currentDriverPositions[driverId]!;
        final newHeading = _calculateHeadingFromMovement(oldPosition, newPosition, driverId);

        _targetDriverPositions[driverId] = newPosition;
        _targetDriverHeadings[driverId] = newHeading;
      }
    }

    // Supprimer les drivers qui ne sont plus dans la liste
    _currentDriverPositions.removeWhere((id, _) => !newDriverIds.contains(id));
    _targetDriverPositions.removeWhere((id, _) => !newDriverIds.contains(id));
    _startDriverPositions.removeWhere((id, _) => !newDriverIds.contains(id));
    _currentDriverHeadings.removeWhere((id, _) => !newDriverIds.contains(id));
    _targetDriverHeadings.removeWhere((id, _) => !newDriverIds.contains(id));
    _startDriverHeadings.removeWhere((id, _) => !newDriverIds.contains(id));
    _driversData.removeWhere((id, _) => !newDriverIds.contains(id));

    // Si nouveaux chauffeurs, afficher immédiatement
    if (hasNewDrivers) {
      await _rebuildDriverMarkers();
    }

    // Démarrer l'animation pour les mouvements
    _startMarkerAnimation();
  }

  /// Démarre l'animation des markers vers leurs positions cibles
  void _startMarkerAnimation() {
    _animationTimer?.cancel();

    // Sauvegarder les positions et headings de départ pour interpolation linéaire
    _startDriverPositions.clear();
    _startDriverHeadings.clear();
    for (final driverId in _currentDriverPositions.keys) {
      _startDriverPositions[driverId] = _currentDriverPositions[driverId]!;
      _startDriverHeadings[driverId] = _currentDriverHeadings[driverId] ?? 0.0;
    }

    int currentStep = 0;
    final stepDuration = Duration(milliseconds: _animationDuration.inMilliseconds ~/ _animationSteps);

    _animationTimer = Timer.periodic(stepDuration, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      currentStep++;
      final progress = currentStep / _animationSteps;
      final isLastStep = currentStep >= _animationSteps;

      // Interpoler les positions et les headings depuis les valeurs de départ
      for (final driverId in _currentDriverPositions.keys.toList()) {
        final start = _startDriverPositions[driverId];
        final target = _targetDriverPositions[driverId];

        if (start != null && target != null) {
          // Interpolation linéaire de la position (start → target)
          final newLat = start.latitude + (target.latitude - start.latitude) * progress;
          final newLng = start.longitude + (target.longitude - start.longitude) * progress;
          _currentDriverPositions[driverId] = LatLng(newLat, newLng);

          // Interpolation de l'angle (heading) pour rotation fluide
          final startHeading = _startDriverHeadings[driverId] ?? 0.0;
          final targetHeading = _targetDriverHeadings[driverId] ?? startHeading;
          _currentDriverHeadings[driverId] = _interpolateAngle(startHeading, targetHeading, progress);
        }
      }

      // Mettre à jour les markers
      await _rebuildDriverMarkers();

      // Arrêter quand l'animation est terminée
      if (isLastStep) {
        timer.cancel();
        // S'assurer que les positions finales sont exactes
        for (final driverId in _targetDriverPositions.keys) {
          _currentDriverPositions[driverId] = _targetDriverPositions[driverId]!;
          _currentDriverHeadings[driverId] = _targetDriverHeadings[driverId] ?? _currentDriverHeadings[driverId] ?? 0;
        }
      }
    });
  }

  /// Interpole un angle en tenant compte du passage par 0/360
  double _interpolateAngle(double from, double to, double progress) {
    double diff = to - from;
    // Gérer le wrap-around pour l'angle (ex: de 350° à 10°)
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (from + diff * progress) % 360;
  }

  /// Reconstruit les markers avec les positions actuelles
  Future<void> _rebuildDriverMarkers() async {
    if (!mounted) return;

    print('🔄 _rebuildDriverMarkers: ${_currentDriverPositions.length} positions, ${_driversData.length} drivers');

    Set<Marker> newMarkers = {};

    for (final entry in _currentDriverPositions.entries) {
      final driverId = entry.key;
      final position = entry.value;
      final driver = _driversData[driverId];

      if (driver == null) {
        print('⚠️ Driver $driverId non trouvé dans _driversData');
        continue;
      }

      // Récupérer le heading actuel
      final heading = _currentDriverHeadings[driverId] ?? 0.0;

      // Charger l'icône (avec fallback)
      BitmapDescriptor icon;
      try {
        icon = await _getVehicleIcon(driver.vehicleType);
      } catch (e) {
        print('❌ Erreur chargement icône: $e');
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      }

      print('🚗 Marker $driverId: pos=${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)} rot=${heading.toStringAsFixed(0)}°');

      newMarkers.add(
        Marker(
          markerId: MarkerId(driverId),
          position: position,
          icon: icon,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          rotation: heading,
          consumeTapEvents: true, // Désactive le clic
        ),
      );
    }

    print('🔄 ${newMarkers.length} markers créés');

    if (mounted) {
      setState(() {
        _driverMarkers = newMarkers;
      });
    }
  }

  /// Calcule le heading à partir du mouvement entre deux positions
  double _calculateHeadingFromMovement(LatLng oldPosition, LatLng newPosition, String driverId) {
    final latDiff = (newPosition.latitude - oldPosition.latitude).abs();
    final lngDiff = (newPosition.longitude - oldPosition.longitude).abs();

    // Seuil minimum de mouvement pour calculer un heading (environ 1 mètre)
    const minMovement = 0.00001;

    if (latDiff > minMovement || lngDiff > minMovement) {
      final bearing = _bearingBetween(
        oldPosition.latitude, oldPosition.longitude,
        newPosition.latitude, newPosition.longitude,
      );
      debugPrint('🧭 $driverId: heading calculé = ${bearing.toStringAsFixed(0)}° (mouvement détecté)');
      return bearing;
    }

    // Pas de mouvement significatif - garder le heading actuel
    final currentHeading = _currentDriverHeadings[driverId] ?? _targetDriverHeadings[driverId] ?? 0.0;
    return currentHeading;
  }

  double _bearingBetween(double lat1, double lng1, double lat2, double lng2) {
    final double dLng = _degreesToRadians(lng2 - lng1);
    final double lat1Rad = _degreesToRadians(lat1);
    final double lat2Rad = _degreesToRadians(lat2);

    final double y = sin(dLng) * cos(lat2Rad);
    final double x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

    double bearing = atan2(y, x);
    bearing = _radiansToDegrees(bearing);
    return (bearing + 360) % 360;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;
  double _radiansToDegrees(double radians) => radians * 180 / pi;

  static const int _markerSize = 28; // Taille réduite style Uber

  Future<BitmapDescriptor> _getVehicleIcon(String? vehicleType) async {
    debugPrint('🚗 _getVehicleIcon appelé avec vehicleType: $vehicleType');
    debugPrint('🚗   vehicleMap.isEmpty: ${vehicleMap.isEmpty}, keys: ${vehicleMap.keys.toList()}');

    if (vehicleType == null || vehicleMap.isEmpty || !vehicleMap.containsKey(vehicleType)) {
      debugPrint('🚗   → Utilisation marker cyan par défaut (type non trouvé)');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }

    final cacheKey = '${vehicleType}_$_markerSize';

    if (_vehicleIconCache.containsKey(cacheKey)) {
      debugPrint('🚗   → Icône depuis cache pour $vehicleType');
      return _vehicleIconCache[cacheKey]!;
    }

    try {
      final vehicleInfo = vehicleMap[vehicleType];
      debugPrint('🚗   vehicleInfo: ${vehicleInfo?.name}, marker URL: ${vehicleInfo?.marker}');
      if (vehicleInfo?.marker != null && vehicleInfo!.marker.isNotEmpty) {
        final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
        final icon = await mapProvider.createResizedMarkerFromNetwork(
          vehicleInfo.marker,
          targetWidth: _markerSize,
        );
        _vehicleIconCache[cacheKey] = icon;
        debugPrint('🚗 ✅ Icône chargée pour $vehicleType (${_markerSize}px)');
        return icon;
      }
    } catch (e) {
      debugPrint('🚗 ❌ Erreur chargement icône $vehicleType: $e');
    }

    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
  }

  void _debouncedPickupSearch(String query) {
    _pickupDebounceTimer?.cancel();

    if (query.length < _minCharsForSearch) {
      _pickupSuggestions.value = [];
      return;
    }

    if (query == _lastPickupQuery) return;

    _pickupDebounceTimer = Timer(_debounceDuration, () async {
      _lastPickupQuery = query;
      final predictions = await PlacesAutocompleteWeb.getPlacePredictions(query);
      _pickupSuggestions.value = predictions;
    });
  }

  void _debouncedDestinationSearch(String query) {
    _destinationDebounceTimer?.cancel();

    if (query.length < _minCharsForSearch) {
      _destinationSuggestions.value = [];
      return;
    }

    if (query == _lastDestinationQuery) return;

    _destinationDebounceTimer = Timer(_debounceDuration, () async {
      _lastDestinationQuery = query;
      final predictions = await PlacesAutocompleteWeb.getPlacePredictions(query);
      _destinationSuggestions.value = predictions;
    });
  }

  Future<void> _selectPickupSuggestion(Map suggestion) async {
    _isSearching.value = true;
    _pickupController.text = suggestion['description'] ?? '';
    _pickupSuggestions.value = [];

    try {
      final details = await PlacesAutocompleteWeb.getPlaceDetails(suggestion['place_id']);
      if (details != null && details['result'] != null && details['result']['geometry'] != null) {
        final location = details['result']['geometry']['location'];
        _pickupLocation = {
          'lat': location['lat'],
          'lng': location['lng'],
          'address': suggestion['description'],
        };

        final pickupPosition = LatLng(location['lat'], location['lng']);

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(pickupPosition, 14),
        );

        _reloadDriversNearPosition(pickupPosition);
        _destinationFocusNode.requestFocus();
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }

    _isSearching.value = false;
  }

  Future<void> _selectDestinationSuggestion(Map suggestion) async {
    _isSearching.value = true;
    _destinationController.text = suggestion['description'] ?? '';
    _destinationSuggestions.value = [];

    try {
      final details = await PlacesAutocompleteWeb.getPlaceDetails(suggestion['place_id']);
      if (details != null && details['result'] != null && details['result']['geometry'] != null) {
        final location = details['result']['geometry']['location'];
        _destinationLocation = {
          'lat': location['lat'],
          'lng': location['lng'],
          'address': suggestion['description'],
        };

        FocusScope.of(context).unfocus();

        if (_pickupLocation['lat'] != null) {
          _isSearching.value = false;
          _onSearch();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }

    _isSearching.value = false;
  }

  @override
  void dispose() {
    _driversSubscription?.cancel();
    _animationTimer?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocusNode.dispose();
    _destinationFocusNode.dispose();
    _pickupDebounceTimer?.cancel();
    _destinationDebounceTimer?.cancel();
    _pickupSuggestions.dispose();
    _destinationSuggestions.dispose();
    _isPickupFocused.dispose();
    _isDestinationFocused.dispose();
    _isSearching.dispose();
    _showVehicleSelection.dispose();
    _selectedVehicleIndex.dispose();
    _mainMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte Google Maps pleine page
          _buildMap(),

          // Formulaire de recherche ou sélection de véhicule
          ValueListenableBuilder<bool>(
            valueListenable: _showVehicleSelection,
            builder: (context, showVehicles, _) {
              return showVehicles
                  ? _buildVehicleSelectionPanel()
                  : _buildSearchCard();
            },
          ),

          // Bouton profil en haut à droite
          _buildProfileButton(),
        ],
      ),
    );
  }

  Widget _buildProfileButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: ValueListenableBuilder(
        valueListenable: userData,
        builder: (context, user, _) {
          final isLoggedIn = user != null;

          if (!isLoggedIn) {
            return Row(
              children: [
                TextButton(
                  onPressed: () => _navigateToLogin(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Connexion',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _navigateToSignUp(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text("S'inscrire"),
                ),
              ],
            );
          }

          return PopupMenuButton<String>(
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: user?.profileImage != null && user!.profileImage.isNotEmpty
                    ? NetworkImage(user.profileImage)
                    : null,
                child: user?.profileImage == null || user!.profileImage.isEmpty
                    ? Icon(Icons.person, color: Colors.grey.shade600, size: 20)
                    : null,
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                final authProvider = Provider.of<CustomAuthProvider>(context, listen: false);
                authProvider.logout(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: 8),
                    Text('${user?.fullName ?? 'Mon profil'}'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'trips',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('Mes trajets'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Déconnexion', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    Set<Marker> allMarkers;
    Set<Polyline> allPolylines;

    if (_mainMode.value == 0) {
      // Mode Course: chauffeurs + itinéraire
      allMarkers = {..._driverMarkers};
      allPolylines = {..._routePolylines};

      // Ajouter le marker de pickup si disponible
      if (_pickupLocation['lat'] != null) {
        allMarkers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(_pickupLocation['lat'], _pickupLocation['lng']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            consumeTapEvents: true,
          ),
        );
      }

      // Ajouter le marker de destination si disponible
      if (_destinationLocation['lat'] != null) {
        allMarkers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(_destinationLocation['lat'], _destinationLocation['lng']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            consumeTapEvents: true,
          ),
        );
      }
    } else {
      // Mode Transport: lignes de transport
      allMarkers = {..._transportMarkers};
      allPolylines = {..._transportPolylines};
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _defaultPosition,
        zoom: 13,
      ),
      style: _mapStyle,
      markers: allMarkers,
      polylines: allPolylines,
      onMapCreated: (controller) {
        _mapController = controller;
        if (kIsWeb) {
          _applyMapStyleViaJS();
        }
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: false,
      mapType: MapType.normal,
      gestureRecognizers: const {},
      padding: const EdgeInsets.only(top: 70, bottom: 400),
      onTap: (_) {}, // Désactive les clics sur POI
    );
  }

  void _applyMapStyleViaJS() {
    try {
      final window = js_util.globalThis;
      final fn = js_util.getProperty(window, 'applyMisyMapStyle');
      if (fn != null) {
        js_util.callMethod(window, 'applyMisyMapStyle', []);
      }
    } catch (e) {
      debugPrint('Error applying map style via JS: $e');
    }
  }

  Widget _buildSearchCard() {
    return Positioned(
      top: 16,
      left: 16,
      bottom: 16,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          // Stoppe la propagation des événements de scroll vers la carte
          if (pointerSignal is PointerScrollEvent) {
            // L'événement est consommé ici
          }
        },
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.93),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo Misy
                Image.asset(
                  MyImagesUrl.misyLogoRose,
                  height: 28,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 16),

                // Onglets navigation - utilise ValueListenableBuilder pour mise à jour locale
                ValueListenableBuilder<int>(
                  valueListenable: _mainMode,
                  builder: (context, mode, _) {
                    return Row(
                      children: [
                        _buildNavTab(
                          label: 'Course',
                          isSelected: mode == 0,
                          onTap: () => _switchToMode(0),
                        ),
                        const SizedBox(width: 8),
                        _buildNavTab(
                          label: 'Transports',
                          isSelected: mode == 1,
                          onTap: () => _switchToMode(1),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Contenu selon le mode - Expanded pour prendre tout l'espace restant
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _mainMode,
                    builder: (context, mode, _) {
                      if (mode == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mode Course
                            _buildLocationInputs(),

                            const SizedBox(height: 16),

                            _buildScheduleOptions(),

                            const SizedBox(height: 16),

                            // Bouton Rechercher
                            ValueListenableBuilder<bool>(
                              valueListenable: _isSearching,
                              builder: (context, isSearching, _) {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isSearching ? null : _onSearch,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MyColors.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: isSearching
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Commander',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      } else {
                        // Mode Transport
                        return _transportLinesLoaded
                            ? _buildTransportLinesList()
                            : const Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildTransportLinesList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _transportLines.length,
      itemBuilder: (context, index) {
        final group = _transportLines[index];
        final color = Color(TransportLineColors.getLineColor(group.lineNumber, group.transportType));

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    group.lineNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                group.transportType.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _switchToMode(int mode) {
    if (_mainMode.value == mode) return;

    _mainMode.value = mode;

    // Forcer la mise à jour de la carte pour afficher les bons markers/polylines
    setState(() {});

    if (mode == 1 && !_transportLinesLoaded) {
      _loadTransportLines();
    }
  }

  Future<void> _loadTransportLines() async {
    try {
      final lines = await TransportLinesService.instance.loadAllLines();
      if (mounted) {
        setState(() {
          _transportLines = lines;
          _transportLinesLoaded = true;
        });
        _updateTransportMapDisplay();
      }
    } catch (e) {
      debugPrint('Error loading transport lines: $e');
      if (mounted) {
        setState(() {
          _transportLinesLoaded = true;
        });
      }
    }
  }

  void _updateTransportMapDisplay() {
    final Set<Polyline> newPolylines = {};
    final Set<Marker> newMarkers = {};

    for (final group in _transportLines) {
      final color = Color(TransportLineColors.getLineColor(group.lineNumber, group.transportType));

      if (group.aller != null) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('${group.lineNumber}_aller'),
            points: group.aller!.coordinates,
            color: color,
            width: 4,
          ),
        );
      }

      if (group.retour != null) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('${group.lineNumber}_retour'),
            points: group.retour!.coordinates,
            color: color.withOpacity(0.5),
            width: 3,
          ),
        );
      }
    }

    setState(() {
      _transportPolylines = newPolylines;
      _transportMarkers = newMarkers;
    });
  }

  Widget _buildLocationInputs() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icônes avec ligne verticale
            Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: MyColors.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 2,
                  height: 44,
                  color: MyColors.primaryColor,
                ),
                Container(
                  width: 10,
                  height: 10,
                  color: MyColors.primaryColor,
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Champs de texte
            Expanded(
              child: Column(
                children: [
                  // Pickup
                  TextField(
                    controller: _pickupController,
                    focusNode: _pickupFocusNode,
                    onChanged: _debouncedPickupSearch,
                    decoration: InputDecoration(
                      hintText: 'Lieu de prise en charge',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                      suffixIcon: _pickupController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                              onPressed: () {
                                _pickupController.clear();
                                _pickupSuggestions.value = [];
                                _pickupLocation = {'lat': null, 'lng': null, 'address': null};
                              },
                            )
                          : null,
                    ),
                  ),

                  Divider(color: Colors.grey.shade300, height: 1),

                  // Destination
                  TextField(
                    controller: _destinationController,
                    focusNode: _destinationFocusNode,
                    onChanged: _debouncedDestinationSearch,
                    decoration: InputDecoration(
                      hintText: 'Destination',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                      suffixIcon: _destinationController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                              onPressed: () {
                                _destinationController.clear();
                                _destinationSuggestions.value = [];
                                _destinationLocation = {'lat': null, 'lng': null, 'address': null};
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Suggestions pickup
        ValueListenableBuilder<List>(
          valueListenable: _pickupSuggestions,
          builder: (context, suggestions, _) {
            if (suggestions.isEmpty) return const SizedBox.shrink();
            return _buildSuggestionsList(suggestions, true);
          },
        ),

        // Suggestions destination
        ValueListenableBuilder<List>(
          valueListenable: _destinationSuggestions,
          builder: (context, suggestions, _) {
            if (suggestions.isEmpty) return const SizedBox.shrink();
            return _buildSuggestionsList(suggestions, false);
          },
        ),
      ],
    );
  }

  Widget _buildSuggestionsList(List suggestions, bool isPickup) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length > 5 ? 5 : suggestions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return InkWell(
            onTap: () {
              if (isPickup) {
                _selectPickupSuggestion(suggestion);
              } else {
                _selectDestinationSuggestion(suggestion);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion['description'] ?? '',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleOptions() {
    return Column(
      children: [
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Prise en charge immédiate',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onSearch() async {
    final pickup = _pickupController.text.trim();
    final destination = _destinationController.text.trim();

    if (pickup.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le lieu de prise en charge et la destination'),
        ),
      );
      return;
    }

    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une adresse dans la liste de suggestions'),
        ),
      );
      return;
    }

    _isSearching.value = true;

    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      tripProvider.pickLocation = {
        'lat': _pickupLocation['lat'],
        'lng': _pickupLocation['lng'],
        'address': _pickupLocation['address'],
      };
      tripProvider.dropLocation = {
        'lat': _destinationLocation['lat'],
        'lng': _destinationLocation['lng'],
        'address': _destinationLocation['address'],
      };

      final totalTime = await getTotalTimeCalculate(
        '${_pickupLocation['lat']},${_pickupLocation['lng']}',
        '${_destinationLocation['lat']},${_destinationLocation['lng']}',
      );
      totalWilltake.value = totalTime;

      if (totalTime.distance < minDistanceForTrip) {
        debugPrint('🚫 Distance trop courte: ${totalTime.distance} km < $minDistanceForTrip km');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aucun trajet disponible pour cette distance (${totalTime.distance.toStringAsFixed(1)} km). '
                      'La distance minimale est de ${minDistanceForTrip.toStringAsFixed(0)} km.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _isSearching.value = false;
        return;
      }

      await _drawRoute();

      _showVehicleSelection.value = true;
      _selectedVehicleIndex.value = -1;
    } catch (e) {
      debugPrint('Error during search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }

    _isSearching.value = false;
  }

  Future<void> _drawRoute() async {
    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) return;

    try {
      final origin = LatLng(_pickupLocation['lat'], _pickupLocation['lng']);
      final destination = LatLng(_destinationLocation['lat'], _destinationLocation['lng']);

      final routeInfo = await RouteService.fetchRoute(
        origin: origin,
        destination: destination,
      );

      final polylinePoints = routeInfo.coordinates;

      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: polylinePoints,
            color: MyColors.primaryColor,
            width: 5,
          ),
        };
      });

      // Zoom pour afficher tout l'itinéraire
      if (polylinePoints.isNotEmpty && _mapController != null) {
        final bounds = _boundsFromLatLngList(polylinePoints);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;

    for (final point in list) {
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

  Widget _buildVehicleSelectionPanel() {
    return Positioned(
      top: 16,
      left: 16,
      bottom: 16,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          // Stoppe la propagation des événements de scroll vers la carte
          if (pointerSignal is PointerScrollEvent) {
            // L'événement est consommé ici
          }
        },
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.93),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Misy
            Image.asset(
              MyImagesUrl.misyLogoRose,
              height: 28,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 16),

            // Header avec bouton retour
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _showVehicleSelection.value = false;
                    _selectedVehicleIndex.value = -1;
                    setState(() {
                      _routePolylines = {};
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Choisir un véhicule',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Résumé du trajet
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MyColors.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_pickupController.text.split(',').first} → ${_destinationController.text.split(',').first}',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: totalWilltake,
                    builder: (context, time, _) {
                      return Text(
                        '${time.distance.toStringAsFixed(1)} km • ${time.time} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Liste des véhicules
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...vehicleMap.entries.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final vehicleEntry = entry.value;
                      final vehicle = vehicleEntry.value;

                      return ValueListenableBuilder<int>(
                        valueListenable: _selectedVehicleIndex,
                        builder: (context, selectedIndex, _) {
                          final isSelected = selectedIndex == index;
                          final tripProvider = Provider.of<TripProvider>(context, listen: false);
                          final price = tripProvider.calculatePrice(vehicle);

                          return InkWell(
                            onTap: () {
                              _selectedVehicleIndex.value = index;
                              tripProvider.selectedVehicle = vehicle;
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? MyColors.primaryColor.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? MyColors.primaryColor
                                      : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Image du véhicule
                                  Container(
                                    width: 60,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: vehicle.image.isNotEmpty
                                        ? Image.network(
                                            vehicle.image,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.directions_car),
                                          )
                                        : const Icon(Icons.directions_car),
                                  ),
                                  const SizedBox(width: 12),
                                  // Infos véhicule
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vehicle.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${vehicle.persons} places',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Prix
                                  Text(
                                    '${price.toStringAsFixed(0)} Ar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? MyColors.primaryColor
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bouton Commander
            ValueListenableBuilder<int>(
              valueListenable: _selectedVehicleIndex,
              builder: (context, selectedIndex, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedIndex >= 0 ? _onConfirmRide : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Commander',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
          ),
        ),
      ),
      ),
    );
  }

  void _onConfirmRide() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    if (userData.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour commander une course'),
        ),
      );
      _navigateToLogin();
      return;
    }

    tripProvider.setScreen(CustomTripType.requestForRide);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Course ${tripProvider.selectedVehicle?.name} - ${tripProvider.calculatePrice(tripProvider.selectedVehicle!).toStringAsFixed(0)} Ar',
        ),
        backgroundColor: MyColors.primaryColor,
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _navigateToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  Widget _buildNavTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MyColors.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? MyColors.primaryColor : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
