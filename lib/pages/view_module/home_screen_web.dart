import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:js_util' as js_util;
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/modal/total_time_distance_modal.dart';
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
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/choose_vehicle_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/request_for_ride.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/drive_on_way.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

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

  // Méthode de paiement sélectionnée
  PaymentMethodType _selectedPaymentMethod = PaymentMethodType.cash;

  // Style de carte personnalisé - POIs masqués pour éviter les clics
  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#A6B5DE"}]},{"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":3}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#BCC5E8"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.local","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road","elementType":"labels","stylers":[{"visibility":"on"}]},{"featureType":"road.highway","elementType":"labels.icon","stylers":[{"visibility":"on"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#ADD4F5"}]},{"featureType":"poi","stylers":[{"visibility":"off"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"transit.station","stylers":[{"visibility":"off"}]}]';

  // Type de carte (normal ou satellite pour confirmation)
  MapType _currentMapType = MapType.normal;

  // === Transport mode data ===
  List<TransportLineGroup> _transportLines = [];
  Set<Polyline> _transportPolylines = {};
  Set<Marker> _transportMarkers = {};
  bool _transportLinesLoaded = false;
  bool _isSearchingTransportRoute = false;
  List<TransportRoute> _foundTransportRoutes = []; // Liste des itinéraires trouvés
  int _selectedRouteIndex = -1; // Index de l'itinéraire ouvert (-1 = tous fermés)
  Set<Polyline> _transportRoutePolylines = {}; // Polylines pour l'itinéraire transport sélectionné

  // === Sélecteur d'heure pour transport ===
  bool _isDepartureTime = true; // true = "Partir", false = "Arriver"
  DateTime _selectedTransportTime = DateTime.now(); // Heure sélectionnée
  bool _isTimeSelectorExpanded = false; // Bandeau rétractable
  int _tempSelectedHour = DateTime.now().hour; // Heure temporaire pour édition
  int _tempSelectedMinute = DateTime.now().minute; // Minute temporaire pour édition

  // === Markers personnalisés pour pickup/destination ===
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;

  // === Animation de la polyline ===
  Timer? _polylineAnimationTimer;
  double _polylineAnimationOffset = 0.0;
  List<LatLng> _routeCoordinates = [];

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

  // Flags pour éviter de fermer les suggestions pendant l'interaction
  bool _isHoveringPickupSuggestions = false;
  bool _isHoveringDestinationSuggestions = false;

  // Mode sélection sur carte: 'pickup', 'destination', ou null
  String? _selectingLocationFor;

  // Planification de course: null = immédiate, sinon = date/heure planifiée
  DateTime? _scheduledDateTime;

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
    _createCustomMarkers();

    // Écouter les changements de TripProvider pour reset l'UI après course
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      tripProvider.addListener(_onTripProviderChanged);
    });
  }

  /// Callback quand TripProvider change (pour gérer le reset après course terminée)
  void _onTripProviderChanged() {
    if (!mounted) return;

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // Si on retourne à l'écran initial en mode Course, reset l'UI
    // Ne pas reset si on est en mode Transport (pour ne pas effacer les adresses lors du switch)
    if (tripProvider.currentStep == CustomTripType.setYourDestination && _mainMode.value == 0) {
      _stopPolylineAnimation();
      setState(() {
        _routePolylines = {};
        _routeCoordinates = [];
        _pickupController.clear();
        _destinationController.clear();
        _pickupLocation = {'lat': null, 'lng': null, 'address': null};
        _destinationLocation = {'lat': null, 'lng': null, 'address': null};
      });
    }
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
        Future.delayed(const Duration(milliseconds: 300), () {
          // Ne pas fermer si l'utilisateur interagit avec les suggestions
          if (!_pickupFocusNode.hasFocus && !_isHoveringPickupSuggestions) {
            _pickupSuggestions.value = [];
          }
        });
      }
    });

    _destinationFocusNode.addListener(() {
      _isDestinationFocused.value = _destinationFocusNode.hasFocus;
      if (!_destinationFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          // Ne pas fermer si l'utilisateur interagit avec les suggestions
          if (!_destinationFocusNode.hasFocus && !_isHoveringDestinationSuggestions) {
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

    try {
      _driversSubscription = FirestoreServices.users
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

          // Filtrer les clients (on veut seulement les chauffeurs)
          final isCustomer = data['isCustomer'] as bool? ?? true;
          if (isCustomer) continue;

          DriverModal driver = DriverModal.fromJson(data);

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
      debugPrint('🚕 ❌ Erreur Firestore stream: $error');
    });
    } catch (e) {
      debugPrint('🚕 ❌ Erreur création souscription Firestore: $e');
    }
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

    // Pré-charger toutes les icônes en parallèle
    final Map<String, BitmapDescriptor> iconsByVehicleType = {};
    final vehicleTypes = _driversData.values
        .map((d) => d.vehicleType)
        .where((t) => t != null)
        .cast<String>()
        .toSet();

    await Future.wait(vehicleTypes.map((type) async {
      try {
        iconsByVehicleType[type] = await _getVehicleIcon(type);
      } catch (e) {
        debugPrint('Erreur chargement icône $type: $e');
      }
    }));

    if (!mounted) return;

    // Icône par défaut
    final defaultIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);

    Set<Marker> newMarkers = {};

    for (final entry in _currentDriverPositions.entries) {
      final driverId = entry.key;
      final position = entry.value;
      final driver = _driversData[driverId];

      if (driver == null) continue;

      final heading = _currentDriverHeadings[driverId] ?? 0.0;
      final icon = (driver.vehicleType != null && iconsByVehicleType.containsKey(driver.vehicleType))
          ? iconsByVehicleType[driver.vehicleType]!
          : defaultIcon;

      newMarkers.add(
        Marker(
          markerId: MarkerId(driverId),
          position: position,
          icon: icon,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          rotation: heading,
          consumeTapEvents: true,
        ),
      );
    }

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

  /// Crée le marker rond blanc avec contour noir pour le pickup
  Future<void> _createCustomMarkers() async {
    if (_pickupMarkerIcon != null && _destinationMarkerIcon != null) return;

    // Créer le marker rond (pickup)
    _pickupMarkerIcon = await _createCircleMarker();

    // Créer le marker carré (destination)
    _destinationMarkerIcon = await _createSquareMarker();
  }

  Future<BitmapDescriptor> _createCircleMarker() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 32.0;

    // Contour noir
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Remplissage blanc
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Point central
    final centerDotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 4;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, borderPaint);
    canvas.drawCircle(center, 4, centerDotPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createSquareMarker() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 32.0;

    // Contour noir
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Remplissage blanc
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Point central
    final centerDotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(4, 4, size - 8, size - 8);

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);
    canvas.drawCircle(Offset(size / 2, size / 2), 4, centerDotPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// Démarre l'animation de la polyline (effet pulse)
  void _startPolylineAnimation() {
    _polylineAnimationTimer?.cancel();

    if (_routeCoordinates.isEmpty) return;

    _polylineAnimationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _polylineAnimationOffset += 0.02;
        if (_polylineAnimationOffset > 1.0) {
          _polylineAnimationOffset = 0.0;
        }
      });
    });
  }

  /// Arrête l'animation de la polyline
  void _stopPolylineAnimation() {
    _polylineAnimationTimer?.cancel();
    _polylineAnimationTimer = null;
  }

  /// Construit les polylines animées pour le trajet
  Set<Polyline> _buildAnimatedPolylines() {
    if (_routeCoordinates.isEmpty) return {};

    final Set<Polyline> polylines = {};

    // Polyline de base (fond noir)
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route_base'),
        points: _routeCoordinates,
        color: Colors.black,
        width: 5,
      ),
    );

    // Polyline animée (pulse blanc qui se déplace)
    if (_routeCoordinates.length > 1) {
      final pulseLength = (_routeCoordinates.length * 0.15).toInt().clamp(2, 20);
      final startIndex = (_routeCoordinates.length * _polylineAnimationOffset).toInt();
      final endIndex = (startIndex + pulseLength).clamp(0, _routeCoordinates.length);

      if (startIndex < _routeCoordinates.length) {
        final pulsePoints = _routeCoordinates.sublist(
          startIndex,
          endIndex.clamp(startIndex, _routeCoordinates.length),
        );

        if (pulsePoints.length >= 2) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route_pulse'),
              points: pulsePoints,
              color: Colors.white,
              width: 3,
            ),
          );
        }
      }
    }

    return polylines;
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

  /// Recherche combinée pour le mode transport: arrêts de transport + Google Places
  void _debouncedTransportSearch(String query, bool isPickup) {
    final timer = isPickup ? _pickupDebounceTimer : _destinationDebounceTimer;
    timer?.cancel();

    if (query.length < 2) {
      if (isPickup) {
        _pickupSuggestions.value = [];
      } else {
        _destinationSuggestions.value = [];
      }
      return;
    }

    final newTimer = Timer(_debounceDuration, () async {
      final List<Map<String, dynamic>> combinedResults = [];

      // 1. Rechercher dans les arrêts de transport (priorité)
      final stops = await _searchTransportStops(query);
      combinedResults.addAll(stops);

      // 2. Rechercher dans Google Places
      final predictions = await PlacesAutocompleteWeb.getPlacePredictions(query);
      for (final prediction in predictions) {
        combinedResults.add({
          ...prediction,
          'type': 'place',
        });
      }

      if (isPickup) {
        _pickupSuggestions.value = combinedResults;
      } else {
        _destinationSuggestions.value = combinedResults;
      }
    });

    if (isPickup) {
      _pickupDebounceTimer = newTimer;
    } else {
      _destinationDebounceTimer = newTimer;
    }
  }

  /// Recherche les arrêts de transport correspondant à la requête
  Future<List<Map<String, dynamic>>> _searchTransportStops(String query) async {
    final List<Map<String, dynamic>> results = [];
    final queryLower = query.toLowerCase();

    try {
      final stops = await TransportLinesService.instance.getAllStops();

      for (final stop in stops) {
        if (stop.name.toLowerCase().contains(queryLower)) {
          results.add({
            'type': 'stop',
            'description': stop.name,
            'stop_id': stop.id,
            'lat': stop.position.latitude,
            'lng': stop.position.longitude,
            'lines': stop.lineNumbers,
          });
        }
      }

      // Trier par pertinence (commence par la requête en premier)
      results.sort((a, b) {
        final aStartsWith = a['description'].toString().toLowerCase().startsWith(queryLower);
        final bStartsWith = b['description'].toString().toLowerCase().startsWith(queryLower);
        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        return a['description'].toString().compareTo(b['description'].toString());
      });

      // Limiter à 5 arrêts max
      return results.take(5).toList();
    } catch (e) {
      debugPrint('Error searching transport stops: $e');
      return [];
    }
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

        // Passer au champ destination si vide
        if (_destinationLocation['lat'] == null) {
          _destinationFocusNode.requestFocus();
        } else {
          // Recherche automatique mode transport si les deux champs sont remplis
          _autoSearchTransportIfReady();
        }
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
          // Mode course: _onSearch, Mode transport: recherche d'itinéraire
          if (_mainMode.value == 1) {
            _autoSearchTransportIfReady();
          } else {
            _onSearch();
          }
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
    // Retirer le listener de TripProvider
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    tripProvider.removeListener(_onTripProviderChanged);

    _driversSubscription?.cancel();
    _animationTimer?.cancel();
    _polylineAnimationTimer?.cancel();
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

          // Panel latéral selon l'étape du flux
          Consumer<TripProvider>(
            builder: (context, tripProvider, _) {
              return _buildPanelForStep(tripProvider);
            },
          ),

          // Bouton profil en haut à droite
          _buildProfileButton(),

          // Bouton recentrer sur ma position GPS
          _buildGpsButton(),
        ],
      ),
    );
  }

  bool _isLocating = false;

  /// Bouton pour recentrer la carte sur la position GPS actuelle
  Widget _buildGpsButton() {
    return Positioned(
      top: 70,
      right: 16,
      child: Material(
        elevation: 4,
        shape: const CircleBorder(),
        color: Colors.white,
        child: InkWell(
          onTap: _isLocating ? null : _centerOnCurrentLocation,
          customBorder: const CircleBorder(),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: _isLocating
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.my_location,
                    color: MyColors.primaryColor,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }

  /// Recentre la carte sur la position GPS actuelle
  Future<void> _centerOnCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      // Utilise la fonction existante qui met à jour currentPosition
      await getCurrentLocation();

      if (currentPosition != null && mounted) {
        final latLng = LatLng(currentPosition!.latitude, currentPosition!.longitude);

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );

        // Recharger les chauffeurs proches de cette position
        _reloadDriversNearPosition(latLng);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'obtenir votre position. Vérifiez les permissions.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur localisation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la localisation'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLocating = false);
    }
  }

  /// Overlay des suggestions qui s'affiche par-dessus tout (style Apple Maps)
  Widget _buildSuggestionsOverlay() {
    return ValueListenableBuilder<List>(
      valueListenable: _pickupSuggestions,
      builder: (context, pickupSuggestions, _) {
        return ValueListenableBuilder<List>(
          valueListenable: _destinationSuggestions,
          builder: (context, destSuggestions, _) {
            // Ne pas afficher si pas en mode transport ou pas de suggestions
            if (_mainMode.value != 1) return const SizedBox.shrink();

            final bool hasPickupSuggestions = pickupSuggestions.isNotEmpty;
            final bool hasDestSuggestions = destSuggestions.isNotEmpty;

            if (!hasPickupSuggestions && !hasDestSuggestions) {
              return const SizedBox.shrink();
            }

            final suggestions = hasPickupSuggestions ? pickupSuggestions : destSuggestions;
            final isPickup = hasPickupSuggestions;

            // Séparer les arrêts de transport des adresses Google
            final transportStops = suggestions.where((s) => s['type'] == 'stop').toList();
            final googlePlaces = suggestions.where((s) => s['type'] != 'stop').toList();

            return Positioned(
              top: 16,
              left: 16,
              bottom: 16,
              child: MouseRegion(
                onEnter: (_) {
                  if (isPickup) {
                    _isHoveringPickupSuggestions = true;
                  } else {
                    _isHoveringDestinationSuggestions = true;
                  }
                },
                onExit: (_) {
                  if (isPickup) {
                    _isHoveringPickupSuggestions = false;
                  } else {
                    _isHoveringDestinationSuggestions = false;
                  }
                },
                child: _WebScrollIsolator(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: Container(
                        width: 380, // Plus large que le sidebar
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 40,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Champ de recherche en haut
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.withOpacity(0.15),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search,
                                    size: 20,
                                    color: Color(0xFF86868B),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: isPickup ? _pickupController : _destinationController,
                                      focusNode: isPickup ? _pickupFocusNode : _destinationFocusNode,
                                      onChanged: isPickup ? _debouncedPickupSearch : _debouncedDestinationSearch,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF1D1D1F),
                                        letterSpacing: -0.3,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: isPickup ? 'Lieu de départ' : 'Destination',
                                        hintStyle: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF86868B),
                                          letterSpacing: -0.3,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  // Bouton X pour fermer
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (isPickup) {
                                          _pickupController.clear();
                                          _pickupSuggestions.value = [];
                                        } else {
                                          _destinationController.clear();
                                          _destinationSuggestions.value = [];
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF86868B).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Color(0xFF86868B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Premier résultat mis en avant avec bouton Itinéraire
                            if (transportStops.isNotEmpty || googlePlaces.isNotEmpty)
                              _buildFirstResultWithAction(
                                transportStops.isNotEmpty ? transportStops.first : googlePlaces.first,
                                isPickup,
                              ),

                            // Liste scrollable des autres résultats
                            Expanded(
                              child: Scrollbar(
                                thumbVisibility: true,
                                radius: const Radius.circular(4),
                                child: ListView(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  children: [
                                    // Option "Ma position" (pour pickup uniquement)
                                    if (isPickup) _buildMyPositionOptionApple(),

                                    // Section Arrêts (skip le premier si déjà affiché)
                                    if (transportStops.length > 1) ...[
                                      _buildSectionHeaderApple('Arrêts'),
                                      ...transportStops.skip(1).map((stop) => _buildTransportStopItemApple(stop, isPickup)),
                                    ] else if (transportStops.isEmpty && googlePlaces.length > 1) ...[
                                      // Section Adresses (skip le premier si déjà affiché)
                                      _buildSectionHeaderApple('Adresses'),
                                      ...googlePlaces.skip(1).map((place) => _buildAddressItemApple(place, isPickup)),
                                    ] else ...[
                                      // Afficher tous si mix
                                      if (transportStops.length > 1) ...[
                                        _buildSectionHeaderApple('Arrêts'),
                                        ...transportStops.skip(1).map((stop) => _buildTransportStopItemApple(stop, isPickup)),
                                      ],
                                      if (googlePlaces.isNotEmpty) ...[
                                        _buildSectionHeaderApple('Adresses'),
                                        ...googlePlaces.skip(transportStops.isEmpty ? 1 : 0).map((place) => _buildAddressItemApple(place, isPickup)),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Premier résultat mis en avant avec bouton Itinéraire
  Widget _buildFirstResultWithAction(Map suggestion, bool isPickup) {
    final isTransportStop = suggestion['type'] == 'stop';
    final description = suggestion['description'] ?? '';
    final lines = suggestion['lines'] as List? ?? [];

    String mainText = description;
    String? secondaryText;
    final parts = description.split(',');
    if (parts.length > 1) {
      mainText = parts[0].trim();
      secondaryText = parts.sublist(1).join(',').trim();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isTransportStop
                        ? [const Color(0xFF5856D6).withOpacity(0.9), const Color(0xFF5856D6)]
                        : [const Color(0xFFFF6B6B), const Color(0xFFFF3B30)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isTransportStop ? Icons.directions_bus : Icons.place,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (secondaryText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondaryText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF86868B),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                    // Badges transport
                    if (lines.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: lines.take(4).map<Widget>((line) {
                            return _buildTransportBadgeApple(line.toString());
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bouton Itinéraire
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (isTransportStop) {
                  _selectTransportStopSuggestion(suggestion, isPickup);
                } else if (isPickup) {
                  _selectPickupSuggestion(suggestion);
                } else {
                  _selectDestinationSuggestion(suggestion);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5357),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Itinéraire',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit le panel approprié selon l'étape actuelle du flux de réservation
  Widget _buildPanelForStep(TripProvider tripProvider) {
    final currentStep = tripProvider.currentStep;

    // Recherche initiale
    if (currentStep == null ||
        currentStep == CustomTripType.setYourDestination ||
        currentStep == CustomTripType.choosePickupDropLocation) {
      return _buildSearchCard();
    }

    // Sélection de véhicule - utiliser un panel custom pour le web
    if (currentStep == CustomTripType.chooseVehicle) {
      return _buildVehicleSelectionPanel(tripProvider);
    }

    // Confirmation du point de dépose - style app mobile
    if (currentStep == CustomTripType.confirmDestination) {
      return _buildConfirmDropLocationPanel(tripProvider);
    }

    // Recherche de chauffeurs
    if (currentStep == CustomTripType.requestForRide) {
      return _wrapInWebPanel(
        child: const RequestForRide(),
        title: 'Recherche en cours',
        useScrollView: false, // RequestForRide gère son propre layout
      );
    }

    // Chauffeur en route / Course en cours
    if (currentStep == CustomTripType.driverOnWay ||
        _isRideInProgress(tripProvider)) {
      if (tripProvider.booking != null) {
        return _wrapInWebPanel(
          child: DriverOnWay(
            booking: tripProvider.booking!,
            driver: tripProvider.acceptedDriver,
            selectedVehicle: tripProvider.selectedVehicle,
            onCancelTap: (reason) {
              tripProvider.cancelRideWithBooking(
                reason: reason,
                cancelAnotherRide: tripProvider.booking!,
              );
            },
          ),
          title: _getTitleForRideStatus(tripProvider),
          useScrollView: false, // DriveOnWay gère son propre scroll
        );
      }
    }

    // Fallback: retour à l'écran de recherche
    return _buildSearchCard();
  }

  /// Vérifie si une course est en cours (basé sur le statut du booking)
  bool _isRideInProgress(TripProvider tripProvider) {
    if (tripProvider.booking == null) return false;
    final status = tripProvider.booking!['status'];
    return status == BookingStatusType.DESTINATION_REACHED.value ||
        (status == BookingStatusType.RIDE_COMPLETE.value &&
            tripProvider.booking!['paymentStatusSummary'] == null);
  }

  /// Retourne le titre approprié selon le statut de la course
  String _getTitleForRideStatus(TripProvider tripProvider) {
    if (tripProvider.booking == null) return 'Course en cours';
    final status = tripProvider.booking!['status'];

    if (status == BookingStatusType.ACCEPTED.value) {
      return 'Chauffeur en route';
    } else if (status == BookingStatusType.DRIVER_REACHED.value) {
      return 'Chauffeur arrivé';
    } else if (status == BookingStatusType.RIDE_STARTED.value) {
      return 'Course en cours';
    } else if (status == BookingStatusType.DESTINATION_REACHED.value) {
      return 'Destination atteinte';
    }
    return 'Course en cours';
  }

  // Flag pour éviter les appels multiples à createRequest
  bool _isCreatingBooking = false;

  /// Crée le booking et démarre la recherche de chauffeurs
  Future<void> _createBookingAndStartSearch(TripProvider tripProvider) async {
    // Éviter les appels multiples
    if (_isCreatingBooking) return;
    if (tripProvider.currentStep != CustomTripType.confirmDestination) return;

    _isCreatingBooking = true;

    try {
      debugPrint('🚀 Création du booking web...');

      // Créer le booking via TripProvider (comme sur mobile)
      final success = await tripProvider.createRequest(
        vehicleDetails: tripProvider.selectedVehicle!,
        paymentMethod: _selectedPaymentMethod.value,
        pickupLocation: tripProvider.pickLocation!,
        dropLocation: tripProvider.dropLocation!,
        scheduleTime: tripProvider.rideScheduledTime,
        isScheduled: tripProvider.rideScheduledTime != null,
        promocodeDetails: tripProvider.selectedPromoCode,
      );

      if (success && mounted) {
        debugPrint('✅ Booking créé, navigation vers requestForRide');
        tripProvider.currentStep = CustomTripType.requestForRide;
      } else if (mounted) {
        debugPrint('❌ Échec création booking');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création de la course')),
        );
        _resetToSearch(tripProvider);
      }
    } catch (e) {
      debugPrint('❌ Erreur création booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        _resetToSearch(tripProvider);
      }
    } finally {
      _isCreatingBooking = false;
    }
  }

  /// Reset l'interface vers l'écran de recherche
  void _resetToSearch(TripProvider tripProvider) {
    tripProvider.currentStep = CustomTripType.setYourDestination;
    setState(() {
      _routePolylines = {};
    });
  }

  /// Encapsule un widget mobile dans un panel web avec effet glass
  /// [useScrollView] - Si false, le child gère son propre scroll (pour ChooseVehicle, etc.)
  Widget _wrapInWebPanel({
    required Widget child,
    String? title,
    bool showBackButton = false,
    VoidCallback? onBack,
    bool useScrollView = true,
  }) {
    return Positioned(
      top: 16,
      left: 16,
      bottom: 16,
      child: _WebScrollIsolator(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 320,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec logo et éventuellement bouton retour
                  if (showBackButton || title != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (showBackButton) ...[
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: onBack,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (title != null)
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Contenu du widget mobile
                  Expanded(
                    child: useScrollView
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: child,
                          )
                        : child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Index du véhicule sélectionné pour le panel web
  int _selectedVehicleIndex = -1;

  /// Panel de sélection de véhicule custom pour le web
  Widget _buildVehicleSelectionPanel(TripProvider tripProvider) {
    return Positioned(
      top: 16,
      left: 16,
      bottom: 16,
      child: _WebScrollIsolator(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec bouton retour
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => _resetToSearch(tripProvider),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Choisir un véhicule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

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
                            '${tripProvider.pickLocation?['address']?.toString().split(',').first ?? ''} → ${tripProvider.dropLocation?['address']?.toString().split(',').first ?? ''}',
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
                    child: ListView.builder(
                      itemCount: vehicleListModal.length + 1, // +1 pour transport en commun
                      itemBuilder: (context, index) {
                        // Option Transport en commun en dernier
                        if (index == vehicleListModal.length) {
                          return _buildPublicTransportOption(tripProvider);
                        }

                        final vehicle = vehicleListModal[index];
                        if (!vehicle.active) return const SizedBox.shrink();

                        final isSelected = _selectedVehicleIndex == index;
                        final price = tripProvider.calculatePrice(vehicle);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedVehicleIndex = index;
                            });
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
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bouton Commander
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedVehicleIndex >= 0
                          ? () => _onConfirmVehicleSelection(tripProvider)
                          : null,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Widget pour l'option Transport en commun
  Widget _buildPublicTransportOption(TripProvider tripProvider) {
    return InkWell(
      onTap: () {
        // Basculer vers le mode transport en gardant les adresses
        _switchToTransportWithCurrentAddresses(tripProvider);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icône bus
            Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_bus,
                color: Colors.blue.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transport en commun',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Bus, taxi-be',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Prix indicatif
            Text(
              '500 Ar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Callback quand l'utilisateur confirme le véhicule sélectionné
  void _onConfirmVehicleSelection(TripProvider tripProvider) {
    // Vérifier que l'utilisateur est connecté
    if (userData.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour commander une course'),
        ),
      );
      _navigateToLogin();
      return;
    }

    // Définir la méthode de paiement par défaut
    _selectedPaymentMethod = PaymentMethodType.cash;

    // Définir l'heure planifiée si applicable
    tripProvider.rideScheduledTime = _scheduledDateTime;

    // Zoomer sur la destination pour confirmation
    _zoomToDestinationForConfirmation(tripProvider);

    // Passer à l'étape de confirmation de la destination
    tripProvider.currentStep = CustomTripType.confirmDestination;
  }

  /// Zoom animé sur la destination pour confirmation du point de dépose
  void _zoomToDestinationForConfirmation(TripProvider tripProvider) {
    if (tripProvider.dropLocation == null) return;

    final destLat = tripProvider.dropLocation!['lat'] as double;
    final destLng = tripProvider.dropLocation!['lng'] as double;
    final destination = LatLng(destLat, destLng);

    // Activer le mode satellite pour mieux voir le point de dépose
    setState(() {
      _currentMapType = MapType.satellite;
    });

    // Zoom animé sur la destination
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: destination,
          zoom: 18.0, // Zoom élevé pour bien voir le point de dépose en satellite
        ),
      ),
    );
  }

  /// Remet la carte en mode normal
  void _resetMapToNormal() {
    setState(() {
      _currentMapType = MapType.normal;
    });
  }

  /// Panel de confirmation du point de dépose - style Apple Maps
  Widget _buildConfirmDropLocationPanel(TripProvider tripProvider) {
    final dropAddress = tripProvider.dropLocation?['address'] ?? 'Destination';
    final pickupAddress = tripProvider.pickLocation?['address'] ?? 'Départ';
    final vehicle = tripProvider.selectedVehicle;
    final price = vehicle != null ? tripProvider.calculatePrice(vehicle) : 0.0;

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: _WebScrollIsolator(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec titre
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          // Retour à la sélection de véhicule
                          tripProvider.currentStep = CustomTripType.chooseVehicle;
                          // Remettre la carte en mode normal
                          _resetMapToNormal();
                          // Recentrer sur l'itinéraire complet
                          _fitMapToRoute();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 22,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Confirmez le point de dépose',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Message d'aide pour ajuster le point de dépose
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5357).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF5357).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 20,
                          color: const Color(0xFFFF5357),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Affinez votre point exact de dépose en cliquant sur la carte',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFFF5357),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Adresse de destination avec icône
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF3B30).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.place,
                            color: Color(0xFFFF3B30),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DESTINATION',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF86868B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dropAddress,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1D1D1F),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Résumé du trajet (pickup + véhicule + prix)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        // Ligne départ
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF34C759),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pickupAddress,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Ligne véhicule + prix (dynamique)
                        Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              vehicle?.name ?? 'Véhicule',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            // Prix dynamique qui se met à jour quand la distance change
                            ValueListenableBuilder<TotalTimeDistanceModal>(
                              valueListenable: totalWilltake,
                              builder: (context, totalTime, _) {
                                final dynamicPrice = vehicle != null
                                    ? tripProvider.calculatePrice(vehicle)
                                    : 0.0;
                                return Text(
                                  '${dynamicPrice.toStringAsFixed(0)} Ar',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        // Distance et temps dynamiques
                        ValueListenableBuilder<TotalTimeDistanceModal>(
                          valueListenable: totalWilltake,
                          builder: (context, totalTime, _) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${totalTime.distance.toStringAsFixed(1)} km • ${totalTime.time} min',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bouton Confirmer
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreatingBooking
                          ? null
                          : () => _confirmDropLocationAndCreateBooking(tripProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MyColors.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: MyColors.primaryColor.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreatingBooking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Confirmer et commander',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
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

  /// Confirme le point de dépose et crée le booking
  Future<void> _confirmDropLocationAndCreateBooking(TripProvider tripProvider) async {
    if (_isCreatingBooking) return;

    setState(() {
      _isCreatingBooking = true;
    });

    try {
      debugPrint('🚀 Création du booking après confirmation du point de dépose...');

      final success = await tripProvider.createRequest(
        vehicleDetails: tripProvider.selectedVehicle!,
        paymentMethod: _selectedPaymentMethod.value,
        pickupLocation: tripProvider.pickLocation!,
        dropLocation: tripProvider.dropLocation!,
        scheduleTime: tripProvider.rideScheduledTime,
        isScheduled: tripProvider.rideScheduledTime != null,
        promocodeDetails: tripProvider.selectedPromoCode,
      );

      if (success && mounted) {
        debugPrint('✅ Booking créé avec succès');
        // Remettre la carte en mode normal
        _resetMapToNormal();
        tripProvider.currentStep = CustomTripType.requestForRide;
      } else if (mounted) {
        debugPrint('❌ Échec création booking');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création de la course')),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur création booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingBooking = false;
        });
      }
    }
  }

  /// Recentre la carte sur l'itinéraire complet
  void _fitMapToRoute() {
    if (_routeCoordinates.isEmpty) return;

    // Calculer les bounds de l'itinéraire
    double minLat = _routeCoordinates.first.latitude;
    double maxLat = _routeCoordinates.first.latitude;
    double minLng = _routeCoordinates.first.longitude;
    double maxLng = _routeCoordinates.first.longitude;

    for (final point in _routeCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // padding
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

      // Utiliser les polylines animées si on a un trajet
      if (_routeCoordinates.isNotEmpty) {
        allPolylines = _buildAnimatedPolylines();
      } else {
        allPolylines = {..._routePolylines};
      }

      // Ajouter le marker de pickup si disponible (rond blanc avec contour noir)
      if (_pickupLocation['lat'] != null) {
        allMarkers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(_pickupLocation['lat'], _pickupLocation['lng']),
            icon: _pickupMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            anchor: const Offset(0.5, 0.5),
            consumeTapEvents: true,
          ),
        );
      }

      // Ajouter le marker de destination si disponible (carré blanc avec contour noir)
      if (_destinationLocation['lat'] != null) {
        allMarkers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(_destinationLocation['lat'], _destinationLocation['lng']),
            icon: _destinationMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            anchor: const Offset(0.5, 0.5),
            consumeTapEvents: true,
          ),
        );
      }
    } else {
      // Mode Transport: lignes de transport + markers pickup/destination
      allMarkers = {..._transportMarkers};

      // Si un itinéraire transport est trouvé, afficher ses polylines, sinon les lignes générales
      if (_transportRoutePolylines.isNotEmpty) {
        allPolylines = {..._transportRoutePolylines};
      } else {
        allPolylines = {..._transportPolylines};
      }

      // Ajouter le marker de pickup si disponible (rond blanc avec contour noir)
      if (_pickupLocation['lat'] != null) {
        allMarkers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(_pickupLocation['lat'], _pickupLocation['lng']),
            icon: _pickupMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            anchor: const Offset(0.5, 0.5),
            consumeTapEvents: true,
          ),
        );
      }

      // Ajouter le marker de destination si disponible (carré blanc avec contour noir)
      if (_destinationLocation['lat'] != null) {
        allMarkers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(_destinationLocation['lat'], _destinationLocation['lng']),
            icon: _destinationMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            anchor: const Offset(0.5, 0.5),
            consumeTapEvents: true,
          ),
        );
      }
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
          // Appliquer le style plusieurs fois pour s'assurer qu'il est appliqué
          _applyMapStyleViaJS();
          Future.delayed(const Duration(milliseconds: 500), _applyMapStyleViaJS);
          Future.delayed(const Duration(seconds: 1), _applyMapStyleViaJS);
          Future.delayed(const Duration(seconds: 2), _applyMapStyleViaJS);
        }
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: false,
      mapType: _currentMapType,
      gestureRecognizers: const {},
      padding: const EdgeInsets.only(top: 70, bottom: 400),
      onTap: _onMapTap,
    );
  }

  /// Gère le tap sur la carte (pour sélectionner une position)
  void _onMapTap(LatLng latLng) {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // Si on est à l'étape de confirmation de destination, permettre d'ajuster le point de dépose
    if (tripProvider.currentStep == CustomTripType.confirmDestination) {
      _adjustDropLocation(latLng, tripProvider);
      return;
    }

    if (_selectingLocationFor != null) {
      final isPickup = _selectingLocationFor == 'pickup';
      _setLocationFromLatLng(latLng, isPickup);
    }
  }

  /// Ajuste le point de dépose quand l'utilisateur clique sur la carte
  Future<void> _adjustDropLocation(LatLng newLocation, TripProvider tripProvider) async {
    // Sauvegarder l'ancienne position pour comparaison
    final oldLat = tripProvider.dropLocation?['lat'] as double?;
    final oldLng = tripProvider.dropLocation?['lng'] as double?;

    if (oldLat == null || oldLng == null) return;

    // Calculer la distance entre l'ancien et le nouveau point
    final distance = _calculateDistanceKm(
      LatLng(oldLat, oldLng),
      newLocation,
    );

    // Obtenir l'adresse du nouveau point via reverse geocoding
    final address = await _reverseGeocode(newLocation);

    // Mettre à jour la destination
    setState(() {
      _destinationLocation = {
        'lat': newLocation.latitude,
        'lng': newLocation.longitude,
        'address': address,
      };
    });

    tripProvider.dropLocation = {
      'lat': newLocation.latitude,
      'lng': newLocation.longitude,
      'address': address,
    };

    // Mettre à jour le marqueur de destination
    _updateDestinationMarker(newLocation);

    // Si la distance a changé significativement (> 100m), recalculer le prix
    if (distance > 0.1) {
      await _recalculatePriceAfterDropChange(tripProvider);
    }

    // Afficher un feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Point de dépose ajusté: ${address.split(',').first}'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF34C759),
        ),
      );
    }
  }

  /// Recalcule le prix après changement du point de dépose
  Future<void> _recalculatePriceAfterDropChange(TripProvider tripProvider) async {
    if (tripProvider.pickLocation == null || tripProvider.dropLocation == null) return;

    try {
      // Recalculer la route et le temps/distance
      final pickupLatLng = LatLng(
        tripProvider.pickLocation!['lat'],
        tripProvider.pickLocation!['lng'],
      );
      final dropLatLng = LatLng(
        tripProvider.dropLocation!['lat'],
        tripProvider.dropLocation!['lng'],
      );

      final routeInfo = await RouteService.fetchRoute(
        origin: pickupLatLng,
        destination: dropLatLng,
      );

      // Mettre à jour les données globales
      final distanceKm = routeInfo.distanceKm ?? 0;
      final durationMinutes = (routeInfo.durationSeconds ?? 0) ~/ 60;

      totalWilltake.value = TotalTimeDistanceModal(
        time: durationMinutes,
        distance: distanceKm,
      );

      // Mettre à jour la polyline
      setState(() {
        _routeCoordinates = routeInfo.coordinates;
      });
      _startPolylineAnimation();

      debugPrint('📍 Prix recalculé: ${distanceKm.toStringAsFixed(2)} km, $durationMinutes min');
    } catch (e) {
      debugPrint('❌ Erreur recalcul prix: $e');
    }
  }

  /// Calcule la distance en km entre deux points
  double _calculateDistanceKm(LatLng from, LatLng to) {
    const double earthRadius = 6371;
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLng = _toRadians(to.longitude - from.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(from.latitude)) *
            cos(_toRadians(to.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// Met à jour le marqueur de destination sur la carte
  void _updateDestinationMarker(LatLng position) {
    // Le marqueur sera mis à jour automatiquement via le Consumer
    // car tripProvider.dropLocation a changé
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
      child: _WebScrollIsolator(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              // Liquid glass - fond très léger avec transparence
              color: const Color(0xFFF5F5F7).withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo Misy - grande taille
                Image.asset(
                  MyImagesUrl.misyLogoRose,
                  height: 42,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
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
                            // Mode Course - Planification en premier
                            _buildScheduleOptions(),

                            const SizedBox(height: 16),

                            _buildLocationInputs(),

                            const SizedBox(height: 16),

                            // Bouton Commander - rouge corail Misy
                            ValueListenableBuilder<bool>(
                              valueListenable: _isSearching,
                              builder: (context, isSearching, _) {
                                return Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    // Rouge corail Misy
                                    color: const Color(0xFFFF5357),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF5357).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: isSearching ? null : _onSearch,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: Center(
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
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: -0.2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      } else {
                        // Mode Transport avec recherche d'itinéraire
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Champs de recherche pour transport
                            _buildTransportSearchFields(),

                            const SizedBox(height: 16),

                            // Résultats de recherche ou liste des lignes
                            Expanded(
                              child: _isSearchingTransportRoute
                                  ? const Center(child: CircularProgressIndicator())
                                  : _foundTransportRoutes.isNotEmpty
                                      ? _buildTransportRouteResults()
                                      : _transportLinesLoaded
                                          ? _buildTransportLinesList()
                                          : const Center(child: CircularProgressIndicator()),
                            ),
                          ],
                        );
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

  /// Champs de recherche pour le mode Transport
  Widget _buildTransportSearchFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none, // Permet aux suggestions de dépasser
          children: [
            // Container principal avec les champs de recherche
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête style Apple
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.06),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_transit, size: 18, color: Color(0xFFFF5357)),
                        const SizedBox(width: 8),
                        const Text(
                          'Rechercher un itinéraire',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Champs Départ et Arrivée avec ligne de connexion
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icônes avec ligne de connexion
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34C759).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF34C759), width: 2),
                                    ),
                                    child: const Icon(Icons.my_location, size: 14, color: Color(0xFF34C759)),
                                  ),
                                  Container(
                                    width: 2,
                                    height: 20,
                                    color: Colors.grey.shade300,
                                  ),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3B30).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFFF3B30), width: 2),
                                    ),
                                    child: const Icon(Icons.place, size: 14, color: Color(0xFFFF3B30)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Champs de texte
                            Expanded(
                              child: Column(
                                children: [
                                  // Champ départ
                                  _buildTransportLocationField(
                                    controller: _pickupController,
                                    focusNode: _pickupFocusNode,
                                    hint: 'Point de départ',
                                    isPickup: true,
                                    label: 'DÉPART',
                                  ),
                                  const SizedBox(height: 8),
                                  // Champ destination
                                  _buildTransportLocationField(
                                    controller: _destinationController,
                                    focusNode: _destinationFocusNode,
                                    hint: 'Destination',
                                    isPickup: false,
                                    label: 'ARRIVÉE',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        Divider(color: Colors.grey.shade200, height: 1),
                        const SizedBox(height: 12),
                        _buildTimeSelector(),
                        if (_pickupLocation['lat'] != null && _destinationLocation['lat'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSearchingTransportRoute ? null : _searchTransportRoute,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5357),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSearchingTransportRoute
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Itinéraire',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Overlay des suggestions (se positionne juste en dessous du header + champs)
            ValueListenableBuilder<List>(
              valueListenable: _pickupSuggestions,
              builder: (context, pickupSuggestions, _) {
                return ValueListenableBuilder<List>(
                  valueListenable: _destinationSuggestions,
                  builder: (context, destSuggestions, _) {
                    final hasPickup = pickupSuggestions.isNotEmpty;
                    final hasDest = destSuggestions.isNotEmpty;

                    if (!hasPickup && !hasDest) return const SizedBox.shrink();

                    final suggestions = hasPickup ? pickupSuggestions : destSuggestions;
                    final isPickup = hasPickup;

                    return Positioned(
                      top: 140, // Position juste en dessous des champs
                      left: -20, // Dépasse à gauche
                      right: -60, // Dépasse à droite sur la carte
                      child: _buildSuggestionsDropdown(suggestions, isPickup),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Dropdown des suggestions qui apparaît en surcouche
  Widget _buildSuggestionsDropdown(List suggestions, bool isPickup) {
    final transportStops = suggestions.where((s) => s['type'] == 'stop').toList();
    final googlePlaces = suggestions.where((s) => s['type'] != 'stop').toList();

    return MouseRegion(
      onEnter: (_) {
        if (isPickup) {
          _isHoveringPickupSuggestions = true;
        } else {
          _isHoveringDestinationSuggestions = true;
        }
      },
      onExit: (_) {
        if (isPickup) {
          _isHoveringPickupSuggestions = false;
        } else {
          _isHoveringDestinationSuggestions = false;
        }
      },
      child: Material(
        elevation: 0,
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 450),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7).withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premier résultat avec bouton Itinéraire
                  if (transportStops.isNotEmpty || googlePlaces.isNotEmpty)
                    _buildFirstResultWithAction(
                      transportStops.isNotEmpty ? transportStops.first : googlePlaces.first,
                      isPickup,
                    ),

                  // Liste scrollable
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      radius: const Radius.circular(4),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        children: [
                          // Option Ma position
                          if (isPickup) _buildMyPositionOptionApple(),

                          // Arrêts (sauf le premier)
                          if (transportStops.length > 1) ...[
                            _buildSectionHeaderApple('Arrêts'),
                            ...transportStops.skip(1).map((stop) => _buildTransportStopItemApple(stop, isPickup)),
                          ],

                          // Adresses
                          if (googlePlaces.isNotEmpty) ...[
                            _buildSectionHeaderApple('Adresses'),
                            ...googlePlaces.skip(transportStops.isEmpty ? 1 : 0).map((place) => _buildAddressItemApple(place, isPickup)),
                          ],
                        ],
                      ),
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

  /// Sélecteur d'heure style IDF Mobilités (bandeau rétractable)
  Widget _buildTimeSelector() {
    final timeString = '${_selectedTransportTime.hour.toString().padLeft(2, '0')}:${_selectedTransportTime.minute.toString().padLeft(2, '0')}';
    final dateString = '${_selectedTransportTime.day.toString().padLeft(2, '0')}/${_selectedTransportTime.month.toString().padLeft(2, '0')}';
    final modeText = _isDepartureTime ? 'Partir' : 'Arriver';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label QUAND
        Text(
          'QUAND',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),

        // Bandeau principal (cliquable pour ouvrir/fermer)
        InkWell(
          onTap: () {
            setState(() {
              _isTimeSelectorExpanded = !_isTimeSelectorExpanded;
              if (_isTimeSelectorExpanded) {
                // Initialiser les valeurs temporaires
                _tempSelectedHour = _selectedTransportTime.hour;
                _tempSelectedMinute = _selectedTransportTime.minute;
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$modeText le $dateString à $timeString',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isTimeSelectorExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Panneau dépliant
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _isTimeSelectorExpanded
              ? Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle Partir / Arriver
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _buildTimeToggleOption('Partir', true)),
                            Expanded(child: _buildTimeToggleOption('Arriver', false)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // DATE DU TRAJET
                      Text(
                        'DATE DU TRAJET',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildDateSelector(),

                      const SizedBox(height: 16),

                      // HEURE et MINUTES
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HEURE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _buildHourSelector(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MINUTES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _buildMinuteSelector(),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Boutons Partir maintenant / Confirmer
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTransportTime = DateTime.now();
                                  _isTimeSelectorExpanded = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue.shade700,
                                side: BorderSide(color: Colors.blue.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Partir maintenant',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTransportTime = DateTime(
                                    _selectedTransportTime.year,
                                    _selectedTransportTime.month,
                                    _selectedTransportTime.day,
                                    _tempSelectedHour,
                                    _tempSelectedMinute,
                                  );
                                  _isTimeSelectorExpanded = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Confirmer',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Toggle Partir / Arriver
  Widget _buildTimeToggleOption(String label, bool isDeparture) {
    final isActive = _isDepartureTime == isDeparture;

    return InkWell(
      onTap: () {
        setState(() {
          _isDepartureTime = isDeparture;
        });
      },
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  /// Sélecteur de date
  Widget _buildDateSelector() {
    final now = DateTime.now();
    final isToday = _selectedTransportTime.day == now.day &&
                    _selectedTransportTime.month == now.month &&
                    _selectedTransportTime.year == now.year;
    final isTomorrow = _selectedTransportTime.day == now.add(const Duration(days: 1)).day &&
                       _selectedTransportTime.month == now.add(const Duration(days: 1)).month;

    String displayText;
    if (isToday) {
      displayText = "Aujourd'hui";
    } else if (isTomorrow) {
      displayText = "Demain";
    } else {
      displayText = '${_selectedTransportTime.day.toString().padLeft(2, '0')}/${_selectedTransportTime.month.toString().padLeft(2, '0')}/${_selectedTransportTime.year}';
    }

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedTransportTime,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          locale: const Locale('fr', 'FR'),
        );
        if (date != null) {
          setState(() {
            _selectedTransportTime = DateTime(
              date.year,
              date.month,
              date.day,
              _selectedTransportTime.hour,
              _selectedTransportTime.minute,
            );
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  /// Sélecteur d'heure
  Widget _buildHourSelector() {
    return InkWell(
      onTap: () => _showHourPicker(),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_tempSelectedHour.toString().padLeft(2, '0')} h',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  /// Sélecteur de minutes
  Widget _buildMinuteSelector() {
    return InkWell(
      onTap: () => _showMinutePicker(),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _tempSelectedMinute.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  /// Popup sélecteur d'heure
  void _showHourPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Sélectionner l\'heure',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: 24,
                  itemBuilder: (context, index) {
                    final isSelected = _tempSelectedHour == index;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _tempSelectedHour = index;
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index.toString().padLeft(2, '0')}h',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Popup sélecteur de minutes
  void _showMinutePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Sélectionner les minutes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: 12, // 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
                  itemBuilder: (context, index) {
                    final minute = index * 5;
                    final isSelected = _tempSelectedMinute == minute;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _tempSelectedMinute = minute;
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          minute.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildTransportLocationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isPickup,
    required String label,
  }) {
    final hasValue = controller.text.isNotEmpty;
    final hasLocation = isPickup ? _pickupLocation['lat'] != null : _destinationLocation['lat'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        // Champ
        Container(
          decoration: BoxDecoration(
            color: hasLocation ? Colors.green.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasLocation ? Colors.green.shade300 : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (query) => _debouncedTransportSearch(query, isPickup),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                    suffixIcon: hasLocation
                        ? Icon(Icons.check_circle, size: 18, color: Colors.green.shade600)
                        : null,
                  ),
                ),
              ),
              // Bouton Ma position GPS
              Tooltip(
                message: 'Utiliser ma position',
                child: InkWell(
                  onTap: () => _useCurrentLocationFor(isPickup),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.gps_fixed, size: 18, color: Colors.blue.shade600),
                  ),
                ),
              ),
              // Bouton Clear si texte présent
              if (hasValue)
                InkWell(
                  onTap: () {
                    controller.clear();
                    if (isPickup) {
                      _pickupSuggestions.value = [];
                      _pickupLocation = {'lat': null, 'lng': null, 'address': null};
                    } else {
                      _destinationSuggestions.value = [];
                      _destinationLocation = {'lat': null, 'lng': null, 'address': null};
                    }
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Recherche d'itinéraire en transport en commun
  Future<void> _searchTransportRoute() async {
    // Valider les adresses
    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un départ et une destination'),
        ),
      );
      return;
    }

    // Afficher immédiatement les markers pickup/destination et recentrer la carte
    final origin = LatLng(_pickupLocation['lat'], _pickupLocation['lng']);
    final destination = LatLng(_destinationLocation['lat'], _destinationLocation['lng']);

    // Recentrer la carte sur les deux points
    final bounds = _boundsFromLatLngList([origin, destination]);
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));

    // Activer l'état de chargement avec ligne droite entre les deux points
    setState(() {
      _isSearchingTransportRoute = true;
      _foundTransportRoutes = [];
      _selectedRouteIndex = -1; // Toutes les cards fermées
      // Afficher ligne droite pendant le chargement
      _transportRoutePolylines = {
        Polyline(
          polylineId: const PolylineId('loading_line'),
          points: [origin, destination],
          color: Colors.blue.withOpacity(0.5),
          width: 3,
          patterns: [PatternItem.dash(15), PatternItem.gap(10)],
        ),
      };
      // Markers de départ et arrivée uniquement
      _transportMarkers = {
        Marker(
          markerId: const MarkerId('loading_origin'),
          position: origin,
          icon: _pickupMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 0.5),
        ),
        Marker(
          markerId: const MarkerId('loading_destination'),
          position: destination,
          icon: _destinationMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 0.5),
        ),
      };
    });

    try {
      // Rechercher plusieurs itinéraires en transport en commun
      final routes = await TransportLinesService.instance.findMultipleRoutes(origin, destination, maxRoutes: 10);

      if (!mounted) return;

      if (routes.isNotEmpty) {
        // Filtrer pour afficher max 2 résultats:
        // 1. Le plus rapide
        // 2. Le plus rapide avec le moins de correspondances (si différent du premier)
        final filteredRoutes = _filterBestRoutes(routes);

        setState(() {
          _foundTransportRoutes = filteredRoutes;
          _selectedRouteIndex = -1; // Toutes les cards fermées par défaut
          _isSearchingTransportRoute = false;
        });

        // Afficher le premier itinéraire sur la carte (sans ouvrir la card)
        await _displayRouteOnMap(0);
      } else {
        setState(() {
          _isSearchingTransportRoute = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun itinéraire en transport en commun trouvé pour ce trajet'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error searching transport route: $e');
      if (mounted) {
        setState(() {
          _isSearchingTransportRoute = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la recherche: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Filtre les itinéraires pour n'afficher que les 2 meilleurs:
  /// 1. Le plus rapide (disponible à l'heure sélectionnée)
  /// 2. Le plus rapide avec le moins de correspondances (si différent)
  List<TransportRoute> _filterBestRoutes(List<TransportRoute> routes) {
    if (routes.isEmpty) return [];

    // Calculer l'heure de départ effective
    final DateTime effectiveDepartureTime;
    if (_isDepartureTime) {
      effectiveDepartureTime = _selectedTransportTime;
    } else {
      // Si "Arriver avant", estimer l'heure de départ en soustrayant la durée moyenne
      final avgDuration = routes.isNotEmpty
          ? routes.map((r) => r.totalDurationMinutes).reduce((a, b) => a + b) ~/ routes.length
          : 30;
      effectiveDepartureTime = _selectedTransportTime.subtract(Duration(minutes: avgDuration));
    }

    // Filtrer les itinéraires dont les transports sont disponibles à l'heure sélectionnée
    final availableRoutes = routes.where((route) {
      return _isRouteAvailableAt(route, effectiveDepartureTime);
    }).toList();

    // Si aucun itinéraire n'est disponible à cette heure, retourner tous les itinéraires
    // avec une note indiquant qu'ils ne sont pas disponibles immédiatement
    final routesToFilter = availableRoutes.isNotEmpty ? availableRoutes : routes;

    if (routesToFilter.length == 1) return routesToFilter;

    // Trier par durée (plus rapide en premier)
    final sortedByDuration = List<TransportRoute>.from(routesToFilter)
      ..sort((a, b) => a.totalDurationMinutes.compareTo(b.totalDurationMinutes));

    // Le plus rapide
    final fastest = sortedByDuration.first;

    // Chercher le plus rapide avec le moins de correspondances
    final minTransfers = routesToFilter.map((r) => r.numberOfTransfers).reduce((a, b) => a < b ? a : b);
    final routesWithMinTransfers = routesToFilter.where((r) => r.numberOfTransfers == minTransfers).toList()
      ..sort((a, b) => a.totalDurationMinutes.compareTo(b.totalDurationMinutes));

    final fastestWithFewestTransfers = routesWithMinTransfers.first;

    // Si c'est le même itinéraire, n'en retourner qu'un
    if (fastest.totalDurationMinutes == fastestWithFewestTransfers.totalDurationMinutes &&
        fastest.numberOfTransfers == fastestWithFewestTransfers.numberOfTransfers) {
      return [fastest];
    }

    // Sinon retourner les deux (plus rapide en premier)
    return [fastest, fastestWithFewestTransfers];
  }

  /// Vérifie si tous les transports d'un itinéraire sont disponibles à l'heure donnée
  bool _isRouteAvailableAt(TransportRoute route, DateTime time) {
    for (final step in route.steps) {
      if (step.type == RouteStepType.transport && step.transportType != null) {
        if (!TransportScheduleInfo.isAvailableAt(step.transportType!, time)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Gère le clic sur une card d'itinéraire (toggle ouverture/fermeture)
  Future<void> _selectTransportRoute(int index) async {
    if (index < 0 || index >= _foundTransportRoutes.length) return;

    // Si on clique sur la card déjà ouverte, on la ferme
    if (_selectedRouteIndex == index) {
      setState(() {
        _selectedRouteIndex = -1;
      });
      return;
    }

    // Sinon on ouvre la nouvelle card et on affiche l'itinéraire sur la carte
    setState(() {
      _selectedRouteIndex = index;
    });
    await _displayRouteOnMap(index);
  }

  /// Affiche un itinéraire transport sur la carte (sans changer l'état d'ouverture des cards)
  Future<void> _displayRouteOnMap(int index) async {
    if (index < 0 || index >= _foundTransportRoutes.length) return;

    final route = _foundTransportRoutes[index];
    final Set<Polyline> routePolylines = {};
    final Set<Marker> routeMarkers = {};
    final allRouteCoords = <LatLng>[];

    // Marker de départ (📍 vert)
    routeMarkers.add(Marker(
      markerId: const MarkerId('transport_origin'),
      position: route.origin,
      icon: _pickupMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      anchor: const Offset(0.5, 0.5),
      zIndex: 10,
    ));

    // Marker d'arrivée (📍 rouge)
    routeMarkers.add(Marker(
      markerId: const MarkerId('transport_destination'),
      position: route.destination,
      icon: _destinationMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      anchor: const Offset(0.5, 0.5),
      zIndex: 10,
    ));

    for (int i = 0; i < route.steps.length; i++) {
      final step = route.steps[i];
      List<LatLng> stepCoordinates = [];

      if (step.isWalking) {
        // Étape de marche: récupérer le tracé OSRM
        if (step.walkStartPosition != null && step.walkEndPosition != null) {
          try {
            final walkRoute = await RouteService.fetchRoute(
              origin: step.walkStartPosition!,
              destination: step.walkEndPosition!,
              travelMode: 'walking',
            );
            stepCoordinates = walkRoute.coordinates;
          } catch (e) {
            // Fallback: ligne droite
            debugPrint('⚠️ OSRM walking failed, using straight line: $e');
            stepCoordinates = [step.walkStartPosition!, step.walkEndPosition!];
          }
        }
      } else {
        // Étape transport: utiliser le tracé réel
        if (step.pathCoordinates.isNotEmpty) {
          stepCoordinates = step.pathCoordinates;
        } else {
          // Fallback: positions des arrêts
          if (step.startStop != null) stepCoordinates.add(step.startStop!.position);
          stepCoordinates.addAll(step.intermediateStops.map((s) => s.position));
          if (step.endStop != null) stepCoordinates.add(step.endStop!.position);
        }

        // Ajouter markers pour les arrêts de transport
        final lineColor = Color(TransportLineColors.getLineColor(
          step.lineNumber ?? '',
          step.transportType ?? TransportType.bus,
        ));

        // Marker arrêt de montée (grand cercle coloré avec icône)
        if (step.startStop != null) {
          try {
            final boardingIcon = await _createStopMarkerIcon(lineColor, isBoarding: true, transportType: step.transportType);
            routeMarkers.add(Marker(
              markerId: MarkerId('boarding_${i}_${step.startStop!.id}'),
              position: step.startStop!.position,
              icon: boardingIcon,
              anchor: const Offset(0.5, 0.5),
              zIndex: 5,
              infoWindow: InfoWindow(
                title: '🚌 Monter: ${step.startStop!.name}',
                snippet: 'Ligne ${step.lineNumber}',
              ),
            ));
          } catch (e) {
            debugPrint('⚠️ Error creating boarding marker: $e');
            routeMarkers.add(Marker(
              markerId: MarkerId('boarding_${i}_${step.startStop!.id}'),
              position: step.startStop!.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              zIndex: 5,
            ));
          }
        }

        // Markers arrêts intermédiaires (petits points blancs)
        for (int j = 0; j < step.intermediateStops.length; j++) {
          final intermediateStop = step.intermediateStops[j];
          try {
            final intermediateIcon = await _createIntermediateStopMarkerIcon();
            routeMarkers.add(Marker(
              markerId: MarkerId('intermediate_${i}_${j}_${intermediateStop.id}'),
              position: intermediateStop.position,
              icon: intermediateIcon,
              anchor: const Offset(0.5, 0.5),
              zIndex: 3,
            ));
          } catch (e) {
            debugPrint('⚠️ Error creating intermediate marker: $e');
            routeMarkers.add(Marker(
              markerId: MarkerId('intermediate_${i}_${j}_${intermediateStop.id}'),
              position: intermediateStop.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              zIndex: 3,
            ));
          }
        }

        // Marker arrêt de descente (grand cercle coloré)
        if (step.endStop != null) {
          try {
            final alightingIcon = await _createStopMarkerIcon(lineColor, isBoarding: false, transportType: step.transportType);
            routeMarkers.add(Marker(
              markerId: MarkerId('alighting_${i}_${step.endStop!.id}'),
              position: step.endStop!.position,
              icon: alightingIcon,
              anchor: const Offset(0.5, 0.5),
              zIndex: 5,
              infoWindow: InfoWindow(
                title: '🛑 Descendre: ${step.endStop!.name}',
                snippet: 'Ligne ${step.lineNumber}',
              ),
            ));
          } catch (e) {
            debugPrint('⚠️ Error creating alighting marker: $e');
            routeMarkers.add(Marker(
              markerId: MarkerId('alighting_${i}_${step.endStop!.id}'),
              position: step.endStop!.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              zIndex: 5,
            ));
          }
        }
      }

      if (stepCoordinates.length < 2) continue;

      allRouteCoords.addAll(stepCoordinates);

      // Style de la polyline
      Color lineColor;
      int width;
      List<PatternItem> patterns;

      if (step.isWalking) {
        // Marche: pointillés gris
        lineColor = Colors.grey.shade700;
        width = 4;
        patterns = [PatternItem.dash(10), PatternItem.gap(6)];
      } else {
        // Transport: ligne continue colorée
        lineColor = Color(TransportLineColors.getLineColor(step.lineNumber ?? '', step.transportType ?? TransportType.bus));
        width = 6;
        patterns = [];
      }

      routePolylines.add(
        Polyline(
          polylineId: PolylineId('transport_step_$i'),
          points: stepCoordinates,
          color: lineColor,
          width: width,
          patterns: patterns,
        ),
      );
    }

    // Recentrer sur l'itinéraire complet
    if (allRouteCoords.isNotEmpty && _mapController != null) {
      final routeBounds = _boundsFromLatLngList(allRouteCoords);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(routeBounds, 80));
    }

    if (mounted) {
      setState(() {
        _transportRoutePolylines = routePolylines;
        _transportMarkers = routeMarkers;
      });
    }
  }

  /// Cache pour les icônes de markers
  final Map<String, BitmapDescriptor> _markerIconCache = {};

  /// Crée un marker pour un arrêt de montée/descente (cercle coloré avec icône transport)
  Future<BitmapDescriptor> _createStopMarkerIcon(Color color, {required bool isBoarding, TransportType? transportType}) async {
    final cacheKey = 'stop_${color.value}_${isBoarding}_${transportType?.index ?? 0}';
    if (_markerIconCache.containsKey(cacheKey)) {
      debugPrint('🎯 Using cached marker icon: $cacheKey');
      return _markerIconCache[cacheKey]!;
    }
    debugPrint('🎨 Creating new marker icon: $cacheKey');

    final size = 36.0;
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Ombre
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(size / 2, size / 2 + 2), size / 2 - 2, shadowPaint);

    // Cercle extérieur (bordure blanche)
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, outerPaint);

    // Cercle intérieur (couleur de la ligne)
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 5, innerPaint);

    // Icône de transport au centre
    final iconText = _getTransportIconText(transportType);
    final textPainter = TextPainter(
      text: TextSpan(
        text: iconText,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _markerIconCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Retourne l'emoji/caractère pour le type de transport
  String _getTransportIconText(TransportType? type) {
    switch (type) {
      case TransportType.bus:
        return '🚌';
      case TransportType.urbanTrain:
        return '🚆';
      case TransportType.telepherique:
        return '🚡';
      default:
        return '🚏';
    }
  }

  /// Crée un petit marker blanc pour les arrêts intermédiaires
  Future<BitmapDescriptor> _createIntermediateStopMarkerIcon() async {
    const cacheKey = 'intermediate_white';
    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    final size = 12.0;
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Cercle blanc avec bordure grise
    final borderPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, whitePaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _markerIconCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Trace la route (utilisé par le mode transport)
  Future<void> _drawRoute() async {
    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) return;

    try {
      final origin = LatLng(_pickupLocation['lat'], _pickupLocation['lng']);
      final destination = LatLng(_destinationLocation['lat'], _destinationLocation['lng']);

      final routeInfo = await RouteService.fetchRoute(
        origin: origin,
        destination: destination,
      );

      setState(() {
        _routeCoordinates = routeInfo.coordinates;
        _polylineAnimationOffset = 0.0;
      });

      _startPolylineAnimation();

      if (routeInfo.coordinates.isNotEmpty && _mapController != null) {
        final bounds = _boundsFromLatLngList(routeInfo.coordinates);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  /// Affiche les résultats de recherche d'itinéraire transport
  /// Affiche les résultats style IDF Mobilités
  Widget _buildTransportRouteResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header avec bouton retour
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () {
                setState(() {
                  _foundTransportRoutes = [];
                  _transportRoutePolylines = {};
                  _transportMarkers = {};
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_foundTransportRoutes.length} itinéraire(s)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Liste des itinéraires style IDF Mobilités
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _foundTransportRoutes.length,
            itemBuilder: (context, index) {
              final route = _foundTransportRoutes[index];
              final isSelected = index == _selectedRouteIndex;

              return GestureDetector(
                onTap: () => _selectTransportRoute(index),
                child: _buildRouteCardIDF(route, isSelected),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Card d'itinéraire style IDF Mobilités (accordéon)
  Widget _buildRouteCardIDF(TransportRoute route, bool isSelected) {
    // Calculer les heures en fonction de la sélection utilisateur
    final DateTime departureTime;
    final DateTime arrivalTime;

    if (_isDepartureTime) {
      // "Partir à" : on part à l'heure sélectionnée
      departureTime = _selectedTransportTime;
      arrivalTime = _selectedTransportTime.add(Duration(minutes: route.totalDurationMinutes));
    } else {
      // "Arriver avant" : on arrive à l'heure sélectionnée
      arrivalTime = _selectedTransportTime;
      departureTime = _selectedTransportTime.subtract(Duration(minutes: route.totalDurationMinutes));
    }

    // Récupérer les étapes de transport pour les badges de lignes
    final transportSteps = route.steps.where((s) => s.type == RouteStepType.transport).toList();

    // Vérifier si l'itinéraire utilise le train ou le téléphérique
    final hasSpecialTransport = transportSteps.any((s) =>
        s.transportType == TransportType.urbanTrain ||
        s.transportType == TransportType.telepherique);

    // Vérifier la disponibilité à l'heure sélectionnée
    final isRouteAvailable = _isRouteAvailableAt(route, departureTime);

    // Obtenir les infos de service pour les transports spéciaux
    final scheduleInfos = <Widget>[];
    for (final step in transportSteps) {
      if (step.transportType == TransportType.urbanTrain ||
          step.transportType == TransportType.telepherique) {
        // Vérifier si ce transport est disponible à l'heure sélectionnée
        final isAvailable = TransportScheduleInfo.isAvailableAt(step.transportType!, departureTime);
        final nextAvailable = TransportScheduleInfo.getNextAvailableTime(step.transportType!, departureTime);
        final statusMessage = isAvailable
            ? 'Disponible'
            : 'Prochain: ${nextAvailable != null ? "${nextAvailable.hour.toString().padLeft(2, '0')}:${nextAvailable.minute.toString().padLeft(2, '0')}" : "N/A"}';
        scheduleInfos.add(_buildScheduleBadge(step.transportType!, isAvailable, statusMessage));
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.shade50
            : (isRouteAvailable ? Colors.white : Colors.orange.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? Colors.blue
              : (isRouteAvailable ? Colors.grey.shade200 : Colors.orange.shade300),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.blue.withOpacity(0.2)
                : Colors.black.withOpacity(0.08),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 3),
            spreadRadius: isSelected ? 1 : 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bannière d'avertissement si non disponible à l'heure sélectionnée
          if (!isRouteAvailable && hasSpecialTransport)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Non disponible à cette heure',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // En-tête: heures de départ/arrivée + durée + badges info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade100.withOpacity(0.5) : Colors.grey.shade50,
              borderRadius: isSelected
                  ? const BorderRadius.vertical(top: Radius.circular(11))
                  : BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Heures et durée
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatTime(departureTime)} → ${_formatTime(arrivalTime)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${route.totalDurationMinutes} min',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (route.walkingDistanceMeters > 0) ...[
                                Text(' · ', style: TextStyle(color: Colors.grey.shade400)),
                                Icon(Icons.directions_walk, size: 14, color: Colors.grey.shade500),
                                Text(
                                  ' ${route.walkingDistanceMeters}m',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                              if (route.numberOfTransfers > 0) ...[
                                Text(' · ', style: TextStyle(color: Colors.grey.shade400)),
                                Text(
                                  '${route.numberOfTransfers} corresp.',
                                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Icône expand/collapse
                    AnimatedRotation(
                      turns: isSelected ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: isSelected ? Colors.blue : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),

                // Badges de lignes style IDF Mobilités (visualisation du trajet)
                if (transportSteps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildLineBadgesRow(transportSteps),
                ],

                // Badges horaires pour train/téléphérique
                if (scheduleInfos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: scheduleInfos,
                  ),
                ],
              ],
            ),
          ),

          // Timeline des étapes + horaires détaillés (visible seulement quand sélectionné)
          if (isSelected)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRouteTimeline(route),
                    // Afficher les horaires détaillés si train ou téléphérique
                    if (hasSpecialTransport) ...[
                      const Divider(height: 24),
                      _buildScheduleDetails(transportSteps),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Badge indiquant le statut de service (en service / prochain départ)
  Widget _buildScheduleBadge(TransportType type, bool isOperating, String statusMessage) {
    final icon = type == TransportType.urbanTrain
        ? Icons.train
        : Icons.airline_seat_recline_extra;
    final name = type == TransportType.urbanTrain ? 'Train' : 'Téléph.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOperating ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOperating ? Colors.green.shade300 : Colors.orange.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isOperating ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            '$name: $statusMessage',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isOperating ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Affiche les détails des horaires pour train et téléphérique
  Widget _buildScheduleDetails(List<RouteStep> transportSteps) {
    final widgets = <Widget>[];

    for (final step in transportSteps) {
      if (step.transportType == TransportType.urbanTrain) {
        widgets.add(_buildTrainScheduleCard());
      } else if (step.transportType == TransportType.telepherique) {
        widgets.add(_buildTelepheriqueScheduleCard());
      }
    }

    // Éviter les doublons (si plusieurs étapes du même type)
    final uniqueWidgets = <Widget>[];
    bool hasTrainCard = false;
    bool hasTelepheriqueCard = false;

    for (final step in transportSteps) {
      if (step.transportType == TransportType.urbanTrain && !hasTrainCard) {
        uniqueWidgets.add(_buildTrainScheduleCard());
        hasTrainCard = true;
      } else if (step.transportType == TransportType.telepherique && !hasTelepheriqueCard) {
        uniqueWidgets.add(_buildTelepheriqueScheduleCard());
        hasTelepheriqueCard = true;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              'Horaires de service',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...uniqueWidgets,
      ],
    );
  }

  /// Card des horaires du train
  Widget _buildTrainScheduleCard() {
    final schedule = TransportScheduleInfo.trainSchedule;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.train, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Text(
                'Train TCE',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.green.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  schedule.fare,
                  style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Départs quotidiens:',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: schedule.departures.map((dep) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '${dep.time} (${dep.from})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                schedule.operatingDays,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                schedule.duration,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card des horaires du téléphérique
  Widget _buildTelepheriqueScheduleCard() {
    final schedule = TransportScheduleInfo.telepheriqueSchedule;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.airline_seat_recline_extra, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                'Téléphérique Orange',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.orange.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  schedule.fare,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Heures de service:',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildTimeSlot('Matin', schedule.morningSlot, Colors.orange),
              const SizedBox(width: 8),
              _buildTimeSlot('Après-midi', schedule.afternoonSlot, Colors.orange),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                schedule.operatingDays,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                schedule.duration,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget pour afficher un créneau horaire
  Widget _buildTimeSlot(String label, String time, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Rangée de badges de lignes style IDF Mobilités
  Widget _buildLineBadgesRow(List<RouteStep> transportSteps) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Icône marche au début
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_walk, size: 14, color: Colors.grey.shade700),
        ),

        for (int i = 0; i < transportSteps.length; i++) ...[
          // Flèche de connexion
          Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade400),

          // Badge de ligne
          _buildLineBadge(transportSteps[i]),

          // Marche entre les correspondances (sauf pour la dernière)
          if (i < transportSteps.length - 1) ...[
            Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade400),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_walk, size: 14, color: Colors.grey.shade700),
            ),
          ],
        ],

        // Flèche et destination
        Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade400),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.place, size: 14, color: Colors.red.shade700),
        ),
      ],
    );
  }

  /// Badge de ligne individuel
  Widget _buildLineBadge(RouteStep step) {
    final lineColor = Color(TransportLineColors.getLineColor(
      step.lineNumber ?? '',
      step.transportType ?? TransportType.bus,
    ));
    final icon = _getTransportIcon(step.transportType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lineColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            step.lineNumber ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge d'info (marche, correspondances)
  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Timeline des étapes style IDF Mobilités avec heures de passage
  Widget _buildRouteTimeline(TransportRoute route) {
    // Calculer l'heure cumulative pour chaque étape
    DateTime currentTime = route.departureTime ?? DateTime.now();

    return Column(
      children: route.steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == route.steps.length - 1;
        final isFirst = index == 0;

        final stepStartTime = currentTime;
        currentTime = currentTime.add(Duration(minutes: step.durationMinutes));
        final stepEndTime = currentTime;

        return _buildTimelineStep(step, isLast, isFirst, stepStartTime, stepEndTime);
      }).toList(),
    );
  }

  /// Étape de la timeline avec heures
  Widget _buildTimelineStep(RouteStep step, bool isLast, bool isFirst, DateTime startTime, DateTime endTime) {
    final isWalking = step.isWalking;
    final Color lineColor;
    final IconData icon;

    if (isWalking) {
      lineColor = Colors.grey.shade400;
      icon = Icons.directions_walk;
    } else {
      lineColor = Color(TransportLineColors.getLineColor(step.lineNumber ?? '', step.transportType ?? TransportType.bus));
      icon = _getTransportIcon(step.transportType);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne heure
        SizedBox(
          width: 45,
          child: Column(
            children: [
              Text(
                _formatTime(startTime),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${step.durationMinutes}\'',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Ligne verticale + icône
        SizedBox(
          width: 36,
          child: Column(
            children: [
              // Icône ou badge ligne
              if (isWalking)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: Icon(icon, size: 14, color: Colors.grey.shade600),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: lineColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    step.lineNumber ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              // Ligne verticale vers la prochaine étape
              if (!isLast)
                Container(
                  width: 3,
                  height: 35,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isWalking ? Colors.grey.shade300 : lineColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Contenu de l'étape
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWalking) ...[
                  // Étape de marche
                  Text(
                    step.type == RouteStepType.walkToStop
                        ? 'Marcher vers ${step.startStop?.name ?? "l\'arrêt"}'
                        : step.type == RouteStepType.walkFromStop
                            ? 'Marcher vers votre destination'
                            : 'Correspondance à pied vers ${step.endStop?.name ?? "l\'arrêt"}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${step.distanceMeters}m · ${step.durationMinutes} min',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ] else ...[
                  // Étape de transport
                  Row(
                    children: [
                      Icon(icon, size: 14, color: lineColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${step.lineName ?? "Ligne ${step.lineNumber}"}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: lineColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Point de départ
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4, right: 6),
                        decoration: BoxDecoration(
                          color: lineColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step.startStop?.name ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Info intermédiaire
                  Padding(
                    padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
                    child: Text(
                      '${step.numberOfStops} arrêt(s) · ${step.durationMinutes} min',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  // Point d'arrivée
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4, right: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: lineColor, width: 2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step.endStop?.name ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Direction
                  if (step.direction != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: lineColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Direction ${step.direction}',
                          style: TextStyle(
                            fontSize: 10,
                            color: lineColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getTransportIcon(TransportType? type) {
    switch (type) {
      case TransportType.bus:
        return Icons.directions_bus;
      case TransportType.urbanTrain:
        return Icons.train;
      case TransportType.telepherique:
        return Icons.airline_seat_recline_extra; // Placeholder for cable car
      default:
        return Icons.directions_transit;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Construit une description textuelle de l'itinéraire
  String _buildRouteDescription(TransportRoute route) {
    final parts = <String>[];
    for (final step in route.steps) {
      if (step.isWalking) {
        parts.add('Marche ${step.durationMinutes} min');
      } else {
        parts.add('${step.lineName} → ${step.endStop?.name ?? ""}');
      }
    }
    return parts.join(' • ');
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

  /// Bascule vers le mode transport en conservant les adresses actuelles et lance la recherche
  void _switchToTransportWithCurrentAddresses(TripProvider tripProvider) {
    if (!mounted) return;

    debugPrint('🚌 === SWITCH TO TRANSPORT ===');
    debugPrint('🚌 TripProvider.pickLocation: ${tripProvider.pickLocation}');
    debugPrint('🚌 TripProvider.dropLocation: ${tripProvider.dropLocation}');

    // Sauvegarder les adresses AVANT de changer quoi que ce soit
    Map<String, dynamic>? savedPickup;
    Map<String, dynamic>? savedDest;
    String? savedPickupText;
    String? savedDestText;

    // Priorité 1: TripProvider (données du flux Course)
    if (tripProvider.pickLocation != null && tripProvider.pickLocation!['lat'] != null) {
      savedPickup = Map<String, dynamic>.from(tripProvider.pickLocation!);
      savedPickupText = tripProvider.pickLocation!['address']?.toString() ?? '';
      debugPrint('🚌 Got pickup from TripProvider: $savedPickupText');
    }
    if (tripProvider.dropLocation != null && tripProvider.dropLocation!['lat'] != null) {
      savedDest = Map<String, dynamic>.from(tripProvider.dropLocation!);
      savedDestText = tripProvider.dropLocation!['address']?.toString() ?? '';
      debugPrint('🚌 Got dest from TripProvider: $savedDestText');
    }

    // Priorité 2: Variables locales (si TripProvider est vide)
    if (savedPickup == null && _pickupLocation['lat'] != null) {
      savedPickup = Map<String, dynamic>.from(_pickupLocation);
      savedPickupText = _pickupController.text;
      debugPrint('🚌 Got pickup from local: $savedPickupText');
    }
    if (savedDest == null && _destinationLocation['lat'] != null) {
      savedDest = Map<String, dynamic>.from(_destinationLocation);
      savedDestText = _destinationController.text;
      debugPrint('🚌 Got dest from local: $savedDestText');
    }

    // Remettre à l'étape initiale
    tripProvider.currentStep = CustomTripType.setYourDestination;

    // Effacer le tracé voiture
    _stopPolylineAnimation();

    // Basculer vers le mode transport
    _mainMode.value = 1;

    // Charger les lignes de transport si nécessaire
    if (!_transportLinesLoaded) {
      _loadTransportLines();
    }

    // Appliquer les adresses sauvegardées et mettre à jour l'UI
    if (mounted) {
      setState(() {
        _routePolylines = {};
        _routeCoordinates = [];
        _foundTransportRoutes = [];
        _transportRoutePolylines = {};
        _selectedRouteIndex = -1; // Toutes les cards fermées

        // Restaurer les adresses
        if (savedPickup != null) {
          _pickupLocation = savedPickup;
          _pickupController.text = savedPickupText ?? '';
        }
        if (savedDest != null) {
          _destinationLocation = savedDest;
          _destinationController.text = savedDestText ?? '';
        }
      });
    }

    debugPrint('🚌 After restore - pickup: ${_pickupLocation["address"]}, dest: ${_destinationLocation["address"]}');

    // Lancer la recherche si les deux adresses sont définies
    final hasPickup = _pickupLocation['lat'] != null;
    final hasDest = _destinationLocation['lat'] != null;
    debugPrint('🚌 hasPickup: $hasPickup, hasDest: $hasDest');

    if (hasPickup && hasDest) {
      debugPrint('🚌 Will launch search in 600ms...');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_isSearchingTransportRoute) {
          debugPrint('🚌 Launching _searchTransportRoute()');
          _searchTransportRoute();
        }
      });
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
        // Champ Pickup
        _buildLocationField(
          controller: _pickupController,
          focusNode: _pickupFocusNode,
          hint: 'Lieu de prise en charge',
          isPickup: true,
          onChanged: _debouncedPickupSearch,
          onClear: () {
            _pickupController.clear();
            _pickupSuggestions.value = [];
            _pickupLocation = {'lat': null, 'lng': null, 'address': null};
            setState(() {});
          },
        ),

        // Suggestions pickup - directement sous le champ pickup
        ValueListenableBuilder<List>(
          valueListenable: _pickupSuggestions,
          builder: (context, suggestions, _) {
            if (suggestions.isEmpty) return const SizedBox(height: 8);
            return _buildInlineSuggestionsList(suggestions, true);
          },
        ),

        // Champ Destination
        _buildLocationField(
          controller: _destinationController,
          focusNode: _destinationFocusNode,
          hint: 'Destination',
          isPickup: false,
          onChanged: _debouncedDestinationSearch,
          onClear: () {
            _destinationController.clear();
            _destinationSuggestions.value = [];
            _destinationLocation = {'lat': null, 'lng': null, 'address': null};
            setState(() {});
          },
        ),

        // Suggestions destination - directement sous le champ destination
        ValueListenableBuilder<List>(
          valueListenable: _destinationSuggestions,
          builder: (context, suggestions, _) {
            if (suggestions.isEmpty) return const SizedBox.shrink();
            return _buildInlineSuggestionsList(suggestions, false);
          },
        ),
      ],
    );
  }

  /// Liste de suggestions inline style Apple Maps - s'affiche directement sous le champ
  Widget _buildInlineSuggestionsList(List suggestions, bool isPickup) {
    // Séparer les arrêts de transport des adresses Google
    final transportStops = suggestions.where((s) => s['type'] == 'stop').toList();
    final googlePlaces = suggestions.where((s) => s['type'] != 'stop').toList();

    return MouseRegion(
      onEnter: (_) {
        if (isPickup) {
          _isHoveringPickupSuggestions = true;
        } else {
          _isHoveringDestinationSuggestions = true;
        }
      },
      onExit: (_) {
        if (isPickup) {
          _isHoveringPickupSuggestions = false;
        } else {
          _isHoveringDestinationSuggestions = false;
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          // Fond blanc neutre avec ombre pour bien ressortir
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Scrollbar(
            thumbVisibility: true,
            radius: const Radius.circular(4),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // Option "Ma position" en haut (seulement pour le départ)
                if (isPickup) _buildMyPositionOptionInline(),

                // Section Arrêts de transport
                if (transportStops.isNotEmpty)
                  ...transportStops.take(4).map((stop) => _buildSuggestionItemInline(stop, isPickup, isTransportStop: true)),

                // Section Adresses
                if (googlePlaces.isNotEmpty)
                  ...googlePlaces.take(5).map((place) => _buildSuggestionItemInline(place, isPickup, isTransportStop: false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Option "Ma position" inline
  Widget _buildMyPositionOptionInline() {
    return InkWell(
      onTap: () async {
        _pickupSuggestions.value = [];
        await _useCurrentLocationFor(true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5357).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location,
                size: 16,
                color: Color(0xFFFF5357),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Ma position',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFFF5357),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Item de suggestion inline style Apple Maps
  Widget _buildSuggestionItemInline(Map<String, dynamic> item, bool isPickup, {required bool isTransportStop}) {
    final String title = item['title'] ?? item['description'] ?? '';
    final String subtitle = item['subtitle'] ?? '';

    return InkWell(
      onTap: () async {
        if (isPickup) {
          _pickupSuggestions.value = [];
        } else {
          _destinationSuggestions.value = [];
        }

        if (isTransportStop) {
          // C'est un arrêt de transport
          final lat = item['lat'] as double?;
          final lng = item['lng'] as double?;
          if (lat != null && lng != null) {
            if (isPickup) {
              _pickupController.text = title;
              _pickupLocation = {'lat': lat, 'lng': lng, 'address': title};
            } else {
              _destinationController.text = title;
              _destinationLocation = {'lat': lat, 'lng': lng, 'address': title};
            }
            setState(() {});
          }
        } else {
          // C'est une adresse Google Places
          if (isPickup) {
            _selectPickupSuggestion(item);
          } else {
            _selectDestinationSuggestion(item);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isTransportStop
                    ? const Color(0xFFFF5357).withOpacity(0.1)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTransportStop ? Icons.directions_bus : Icons.place,
                size: 16,
                color: isTransportStop ? const Color(0xFFFF5357) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 10),
            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1D1D1F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isPickup,
    required Function(String) onChanged,
    required VoidCallback onClear,
  }) {
    final isSelecting = _selectingLocationFor == (isPickup ? 'pickup' : 'destination');

    return Container(
      decoration: BoxDecoration(
        // Style Apple - fond léger
        color: isSelecting
            ? const Color(0xFFFF5357).withOpacity(0.08)
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
        border: isSelecting
            ? Border.all(color: const Color(0xFFFF5357).withOpacity(0.4), width: 1.5)
            : Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Icône - rond pour pickup, carré pour destination (blanc avec bordure noire)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: isPickup ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isPickup ? null : BorderRadius.circular(2),
                border: Border.all(
                  color: const Color(0xFF1D1D1F),
                  width: 2,
                ),
              ),
            ),
          ),

          // Champ texte
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1D1D1F),
                letterSpacing: -0.2,
              ),
              decoration: InputDecoration(
                hintText: isSelecting ? 'Touchez la carte...' : hint,
                hintStyle: TextStyle(
                  fontSize: 14,
                  letterSpacing: -0.2,
                  color: isSelecting ? const Color(0xFFFF5357) : const Color(0xFF86868B),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                isDense: true,
              ),
            ),
          ),

          // Bouton Ma position GPS
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _useCurrentLocationFor(isPickup),
              borderRadius: BorderRadius.circular(20),
              hoverColor: Colors.grey.withOpacity(0.1),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.my_location,
                  size: 18,
                  color: Color(0xFFFF5357),
                ),
              ),
            ),
          ),

          // Bouton Sélectionner sur la carte
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _startMapSelection(isPickup),
              borderRadius: BorderRadius.circular(20),
              hoverColor: Colors.grey.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: isSelecting ? const Color(0xFFFF5357) : const Color(0xFF86868B),
                ),
              ),
            ),
          ),

          // Bouton Clear si texte présent
          if (controller.text.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                hoverColor: Colors.grey.withOpacity(0.1),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, size: 16, color: Color(0xFF86868B)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Active le mode sélection sur carte
  void _startMapSelection(bool isPickup) {
    setState(() {
      _selectingLocationFor = isPickup ? 'pickup' : 'destination';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPickup
              ? 'Cliquez sur la carte pour définir le lieu de prise en charge'
              : 'Cliquez sur la carte pour définir la destination',
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: MyColors.primaryColor,
      ),
    );
  }

  /// Utilise la position GPS actuelle pour le champ spécifié
  Future<void> _useCurrentLocationFor(bool isPickup) async {
    try {
      await getCurrentLocation();

      if (currentPosition != null) {
        final latLng = LatLng(currentPosition!.latitude, currentPosition!.longitude);
        await _setLocationFromLatLng(latLng, isPickup);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'obtenir votre position')),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur GPS: $e');
    }
  }

  /// Définit une location à partir de coordonnées (reverse geocoding via Google API)
  Future<void> _setLocationFromLatLng(LatLng latLng, bool isPickup) async {
    // Afficher un indicateur de chargement
    if (isPickup) {
      _pickupController.text = 'Chargement...';
    } else {
      _destinationController.text = 'Chargement...';
    }

    try {
      // Reverse geocoding via Google Geocoding API
      final address = await _reverseGeocode(latLng);

      setState(() {
        if (isPickup) {
          _pickupController.text = address;
          _pickupLocation = {
            'lat': latLng.latitude,
            'lng': latLng.longitude,
            'address': address,
          };
          _pickupLatLng = latLng;
          _reloadDriversNearPosition(latLng);
        } else {
          _destinationController.text = address;
          _destinationLocation = {
            'lat': latLng.latitude,
            'lng': latLng.longitude,
            'address': address,
          };
        }
        _selectingLocationFor = null;
      });

      // Centrer la carte sur le point
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
    } catch (e) {
      debugPrint('Erreur reverse geocoding: $e');
      // En cas d'erreur, utiliser juste les coordonnées
      setState(() {
        final address = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
        if (isPickup) {
          _pickupController.text = address;
          _pickupLocation = {
            'lat': latLng.latitude,
            'lng': latLng.longitude,
            'address': address,
          };
        } else {
          _destinationController.text = address;
          _destinationLocation = {
            'lat': latLng.latitude,
            'lng': latLng.longitude,
            'address': address,
          };
        }
        _selectingLocationFor = null;
      });
    }
  }

  /// Reverse geocoding via Google Geocoding API
  Future<String> _reverseGeocode(LatLng latLng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${latLng.latitude},${latLng.longitude}'
        '&key=$googleMapApiKey'
        '&language=fr',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          // Chercher une adresse formatée appropriée
          for (final result in data['results']) {
            final types = result['types'] as List?;
            // Préférer les adresses de rue ou les points d'intérêt
            if (types != null &&
                (types.contains('street_address') ||
                    types.contains('route') ||
                    types.contains('premise') ||
                    types.contains('point_of_interest'))) {
              return result['formatted_address'] ?? 'Position sélectionnée';
            }
          }
          // Sinon prendre la première adresse
          return data['results'][0]['formatted_address'] ?? 'Position sélectionnée';
        }
      }
    } catch (e) {
      debugPrint('Erreur reverse geocoding: $e');
    }

    // Fallback: coordonnées brutes
    return '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
  }

  /// Liste de suggestions étendue style Apple Maps (prend tout l'espace disponible)
  Widget _buildExpandedSuggestionsList(List suggestions, bool isPickup) {
    final transportStops = suggestions.where((s) => s['type'] == 'stop').toList();
    final googlePlaces = suggestions.where((s) => s['type'] != 'stop').toList();

    return MouseRegion(
      onEnter: (_) {
        if (isPickup) {
          _isHoveringPickupSuggestions = true;
        } else {
          _isHoveringDestinationSuggestions = true;
        }
      },
      onExit: (_) {
        if (isPickup) {
          _isHoveringPickupSuggestions = false;
        } else {
          _isHoveringDestinationSuggestions = false;
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          // Effet liquid glass - fond semi-transparent
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Option "Ma position" (pour pickup uniquement)
                if (isPickup) _buildMyPositionOptionApple(),

                // Liste scrollable des suggestions
                Flexible(
                  child: Scrollbar(
                    thumbVisibility: true,
                    radius: const Radius.circular(4),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        // Section Arrêts
                        if (transportStops.isNotEmpty) ...[
                          _buildSectionHeaderApple('Arrêts'),
                          ...transportStops.map((stop) => _buildTransportStopItemApple(stop, isPickup)),
                        ],
                        // Section Adresses
                        if (googlePlaces.isNotEmpty) ...[
                          _buildSectionHeaderApple('Adresses'),
                          ...googlePlaces.map((place) => _buildAddressItemApple(place, isPickup)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(List suggestions, bool isPickup) {
    // Séparer les arrêts de transport des adresses Google
    final transportStops = suggestions.where((s) => s['type'] == 'stop').toList();
    final googlePlaces = suggestions.where((s) => s['type'] != 'stop').toList();

    // Envelopper dans MouseRegion pour détecter le survol et éviter la fermeture pendant le scroll
    return MouseRegion(
      onEnter: (_) {
        if (isPickup) {
          _isHoveringPickupSuggestions = true;
        } else {
          _isHoveringDestinationSuggestions = true;
        }
      },
      onExit: (_) {
        if (isPickup) {
          _isHoveringPickupSuggestions = false;
        } else {
          _isHoveringDestinationSuggestions = false;
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          // Effet liquid glass - fond semi-transparent avec blur
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Scrollbar(
              thumbVisibility: true,
              radius: const Radius.circular(4),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  // Option "Ma position" en haut (seulement pour le départ)
                  if (isPickup) _buildMyPositionOptionApple(),

                  // Section Arrêts de transport
                  if (transportStops.isNotEmpty) ...[
                    _buildSectionHeaderApple('Arrêts'),
                    ...transportStops.take(6).map((stop) => _buildTransportStopItemApple(stop, isPickup)),
                  ],

                  // Section Adresses
                  if (googlePlaces.isNotEmpty) ...[
                    _buildSectionHeaderApple('Adresses'),
                    ...googlePlaces.take(6).map((place) => _buildAddressItemApple(place, isPickup)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Option "Ma position" style Apple
  Widget _buildMyPositionOptionApple() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          _pickupSuggestions.value = [];
          await _useCurrentLocationFor(true);
          _autoSearchTransportIfReady();
        },
        hoverColor: Colors.grey.withOpacity(0.08),
        splashColor: Colors.grey.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icône bleue style Apple
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF5AC8FA),
                      const Color(0xFFFF5357),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.my_location,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ma position',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D1D1F),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// En-tête de section style Apple
  Widget _buildSectionHeaderApple(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 14,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  /// Item arrêt de transport style Apple
  Widget _buildTransportStopItemApple(Map suggestion, bool isPickup) {
    final lines = suggestion['lines'] as List? ?? [];
    final description = suggestion['description'] ?? '';

    // Extraire le nom de l'arrêt et l'adresse
    String stopName = description;
    String? address;
    final parts = description.split(',');
    if (parts.length > 1) {
      stopName = parts[0].trim();
      address = parts.sublist(1).join(',').trim();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectTransportStopSuggestion(suggestion, isPickup),
        hoverColor: Colors.grey.withOpacity(0.08),
        splashColor: Colors.grey.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône pin style Apple (bleu pour transport)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF5856D6).withOpacity(0.9),
                      const Color(0xFF5856D6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom de l'arrêt
                    Text(
                      stopName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Adresse en gris
                    if (address != null && address.isNotEmpty)
                      Text(
                        address,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // Badges des lignes
                    if (lines.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: lines.take(4).map<Widget>((line) {
                            return _buildTransportBadgeApple(line.toString());
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Badge de ligne de transport style Apple
  Widget _buildTransportBadgeApple(String lineNumber) {
    Color bgColor;
    IconData? icon;
    String displayText = lineNumber;

    if (lineNumber.toUpperCase().contains('TRAIN') || lineNumber.toUpperCase().contains('TCE')) {
      bgColor = const Color(0xFF34C759); // Vert Apple
      icon = Icons.train;
      displayText = 'TCE';
    } else if (lineNumber.toUpperCase().contains('TELEPH')) {
      bgColor = const Color(0xFFFF9500); // Orange Apple
      icon = Icons.airline_seat_recline_extra;
      displayText = 'TEL';
    } else {
      bgColor = const Color(0xFFFF5357); // Bleu Apple
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            displayText.length > 6 ? displayText.substring(0, 6) : displayText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Item adresse style Apple
  Widget _buildAddressItemApple(Map suggestion, bool isPickup) {
    final description = suggestion['description'] ?? '';

    // Séparer nom et adresse
    String mainText = description;
    String? secondaryText;
    final parts = description.split(',');
    if (parts.length > 1) {
      mainText = parts[0].trim();
      secondaryText = parts.sublist(1).join(',').trim();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isPickup) {
            _selectPickupSuggestion(suggestion);
          } else {
            _selectDestinationSuggestion(suggestion);
          }
        },
        hoverColor: Colors.grey.withOpacity(0.08),
        splashColor: Colors.grey.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône pin rouge style Apple
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFFF6B6B),
                      const Color(0xFFFF3B30),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.place,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondaryText != null && secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondaryText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Option "Ma position" pour utiliser la géolocalisation
  Widget _buildMyPositionOption() {
    return InkWell(
      onTap: () async {
        // Utiliser la position actuelle via la méthode existante
        _pickupSuggestions.value = [];
        await _useCurrentLocationFor(true);
        _autoSearchTransportIfReady();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.my_location,
                size: 20,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Ma position',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  /// En-tête de section (Arrêts, Adresses)
  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Item pour un arrêt de transport (style IDF Mobilités)
  Widget _buildTransportStopItem(Map suggestion, bool isPickup) {
    final lines = suggestion['lines'] as List? ?? [];
    final description = suggestion['description'] ?? '';

    // Extraire le nom de l'arrêt et la commune/adresse
    String stopName = description;
    String? subtitle;

    // Tenter de séparer nom et adresse (souvent séparés par une virgule)
    final parts = description.split(',');
    if (parts.length > 1) {
      stopName = parts[0].trim();
      subtitle = parts.sublist(1).join(',').trim();
    }

    return InkWell(
      onTap: () => _selectTransportStopSuggestion(suggestion, isPickup),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône arrêt
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_bus_outlined,
                size: 20,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 14),
            // Nom et badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom de l'arrêt en bleu (style lien)
                  Text(
                    stopName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1565C0), // Bleu lien
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Adresse/commune en dessous
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Badges des lignes de transport
                  if (lines.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: lines.take(5).map<Widget>((line) {
                          return _buildSuggestionLineBadge(line.toString());
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Badge pour une ligne de transport (dans les suggestions)
  Widget _buildSuggestionLineBadge(String lineNumber) {
    // Couleurs selon le type de ligne
    Color badgeColor;
    Color textColor = Colors.white;
    IconData? icon;

    if (lineNumber.toUpperCase().contains('TRAIN') || lineNumber.toUpperCase().contains('TCE')) {
      badgeColor = const Color(0xFF4CAF50); // Vert pour train
      icon = Icons.train;
    } else if (lineNumber.toUpperCase().contains('TELEPH')) {
      badgeColor = const Color(0xFFFF9800); // Orange pour téléphérique
      icon = Icons.airline_seat_recline_extra;
    } else {
      badgeColor = const Color(0xFF2196F3); // Bleu pour bus
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            lineNumber.length > 10 ? lineNumber.substring(0, 10) : lineNumber,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Item pour une adresse Google Places
  Widget _buildAddressItem(Map suggestion, bool isPickup) {
    final description = suggestion['description'] ?? '';

    // Tenter de séparer le nom principal et l'adresse complète
    String mainText = description;
    String? secondaryText;

    final parts = description.split(',');
    if (parts.length > 1) {
      mainText = parts[0].trim();
      secondaryText = parts.sublist(1).join(',').trim();
    }

    return InkWell(
      onTap: () {
        if (isPickup) {
          _selectPickupSuggestion(suggestion);
        } else {
          _selectDestinationSuggestion(suggestion);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône lieu
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.place_outlined,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 14),
            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF212121),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondaryText != null && secondaryText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        secondaryText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sélectionne un arrêt de transport comme point de départ ou d'arrivée
  void _selectTransportStopSuggestion(Map suggestion, bool isPickup) {
    final location = {
      'lat': suggestion['lat'],
      'lng': suggestion['lng'],
      'address': suggestion['description'],
    };

    if (isPickup) {
      _pickupController.text = suggestion['description'] ?? '';
      _pickupSuggestions.value = [];
      _pickupLocation = location;
      // Passer au champ destination si vide
      if (_destinationLocation['lat'] == null) {
        _destinationFocusNode.requestFocus();
      }
    } else {
      _destinationController.text = suggestion['description'] ?? '';
      _destinationSuggestions.value = [];
      _destinationLocation = location;
    }

    // Centrer la carte sur l'arrêt sélectionné
    if (suggestion['lat'] != null && suggestion['lng'] != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(suggestion['lat'], suggestion['lng']),
          15,
        ),
      );
    }

    setState(() {});

    // Recherche automatique si les deux champs sont remplis (mode transport)
    _autoSearchTransportIfReady();
  }

  /// Déclenche automatiquement la recherche d'itinéraire transport si les deux adresses sont remplies
  void _autoSearchTransportIfReady() {
    if (_mainMode.value == 1 && // Mode transport
        _pickupLocation['lat'] != null &&
        _destinationLocation['lat'] != null &&
        !_isSearchingTransportRoute &&
        _foundTransportRoutes.isEmpty) {
      // Petite attente pour laisser l'UI se mettre à jour
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _searchTransportRoute();
        }
      });
    }
  }

  Widget _buildScheduleOptions() {
    final isScheduled = _scheduledDateTime != null;
    final displayText = isScheduled
        ? _formatScheduledDateTime(_scheduledDateTime!)
        : 'Maintenant';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label style Apple
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'QUAND',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF86868B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showSchedulePicker,
            borderRadius: BorderRadius.circular(10),
            hoverColor: Colors.grey.withOpacity(0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isScheduled
                    ? const Color(0xFFFF5357).withOpacity(0.08)
                    : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(10),
                border: isScheduled
                    ? Border.all(color: const Color(0xFFFF5357).withOpacity(0.3))
                    : Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    isScheduled ? Icons.event : Icons.access_time_rounded,
                    size: 18,
                    color: isScheduled ? const Color(0xFFFF5357) : const Color(0xFF86868B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: isScheduled ? const Color(0xFFFF5357) : const Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                  if (isScheduled)
                    InkWell(
                      onTap: () {
                        setState(() => _scheduledDateTime = null);
                      },
                      child: const Icon(Icons.close, size: 18, color: Color(0xFF86868B)),
                    )
                  else
                    const Icon(Icons.chevron_right, size: 18, color: Color(0xFF86868B)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatScheduledDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.day == now.day && dt.month == now.month && dt.year == now.year;
    final isTomorrow = dt.day == now.day + 1 && dt.month == now.month && dt.year == now.year;

    String dayStr;
    if (isToday) {
      dayStr = "Aujourd'hui";
    } else if (isTomorrow) {
      dayStr = 'Demain';
    } else {
      dayStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    }

    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$dayStr à $timeStr';
  }

  void _showSchedulePicker() {
    showDialog(
      context: context,
      builder: (context) => _SchedulePickerDialog(
        initialDateTime: _scheduledDateTime,
        onConfirm: (dateTime) {
          setState(() => _scheduledDateTime = dateTime);
        },
        onImmediate: () {
          setState(() => _scheduledDateTime = null);
        },
      ),
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

      // Un seul appel API pour récupérer la route, la distance et le temps
      final routeInfo = await _fetchRouteAndUpdateMap();

      if (routeInfo == null) {
        _isSearching.value = false;
        return;
      }

      // Mettre à jour le temps et la distance depuis les données de la route
      final distanceKm = routeInfo.distanceKm ?? 0;
      final durationMinutes = (routeInfo.durationSeconds ?? 0) ~/ 60;

      totalWilltake.value = TotalTimeDistanceModal(
        time: durationMinutes,
        distance: distanceKm,
      );

      // Passer à l'étape de sélection de véhicule
      tripProvider.currentStep = CustomTripType.chooseVehicle;
    } catch (e) {
      debugPrint('Error during search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }

    _isSearching.value = false;
  }

  Future<RouteInfo?> _fetchRouteAndUpdateMap() async {
    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) return null;

    try {
      final origin = LatLng(_pickupLocation['lat'], _pickupLocation['lng']);
      final destination = LatLng(_destinationLocation['lat'], _destinationLocation['lng']);

      final routeInfo = await RouteService.fetchRoute(
        origin: origin,
        destination: destination,
      );

      final polylinePoints = routeInfo.coordinates;

      setState(() {
        // Stocker les coordonnées pour l'animation
        _routeCoordinates = polylinePoints;
        _polylineAnimationOffset = 0.0;
      });

      // Démarrer l'animation de la polyline
      _startPolylineAnimation();

      // Zoom pour afficher tout l'itinéraire
      if (polylinePoints.isNotEmpty && _mapController != null) {
        final bounds = _boundsFromLatLngList(polylinePoints);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      }

      return routeInfo;
    } catch (e) {
      debugPrint('Error fetching route: $e');
      return null;
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.grey.withOpacity(0.08),
        splashColor: Colors.grey.withOpacity(0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            // Rouge corail Misy quand sélectionné, transparent sinon
            color: isSelected
                ? const Color(0xFFFF5357)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF5357).withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              // Blanc quand sélectionné, gris foncé sinon
              color: isSelected
                  ? Colors.white
                  : const Color(0xFF1D1D1F),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget qui isole les événements pour empêcher la propagation vers la carte Google Maps
class _WebScrollIsolator extends StatelessWidget {
  final Widget child;

  const _WebScrollIsolator({required this.child});

  @override
  Widget build(BuildContext context) {
    // Utiliser simplement PointerInterceptor pour bloquer les événements vers Google Maps
    return PointerInterceptor(
      child: child,
    );
  }
}

/// Dialog pour choisir entre course immédiate ou planifiée
class _SchedulePickerDialog extends StatefulWidget {
  final DateTime? initialDateTime;
  final Function(DateTime) onConfirm;
  final VoidCallback onImmediate;

  const _SchedulePickerDialog({
    this.initialDateTime,
    required this.onConfirm,
    required this.onImmediate,
  });

  @override
  State<_SchedulePickerDialog> createState() => _SchedulePickerDialogState();
}

class _SchedulePickerDialogState extends State<_SchedulePickerDialog> {
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.initialDateTime ?? now.add(const Duration(hours: 1));
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _selectedHour = initial.hour;
    // Arrondir aux 15 minutes
    _selectedMinute = (initial.minute ~/ 15) * 15;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quand partir ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Option immédiate
            InkWell(
              onTap: () {
                widget.onImmediate();
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.initialDateTime == null
                      ? MyColors.primaryColor.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: widget.initialDateTime == null
                      ? Border.all(color: MyColors.primaryColor)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.flash_on, color: MyColors.primaryColor),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Maintenant',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (widget.initialDateTime == null)
                      Icon(Icons.check, color: MyColors.primaryColor),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // Sélecteur de date
            const Text('Date', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildDateSelector(),

            const SizedBox(height: 16),

            // Sélecteur d'heure
            const Text('Heure', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildTimeSelector(),

            const SizedBox(height: 24),

            // Bouton confirmer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final scheduled = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    _selectedHour,
                    _selectedMinute,
                  );
                  widget.onConfirm(scheduled);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Planifier la course'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final dates = List.generate(7, (i) => now.add(Duration(days: i)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dates.map((date) {
          final isSelected = date.day == _selectedDate.day &&
              date.month == _selectedDate.month;
          final isToday = date.day == now.day;

          String label;
          if (isToday) {
            label = "Auj.";
          } else if (date.day == now.day + 1) {
            label = "Dem.";
          } else {
            label = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][date.weekday - 1];
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedDate = date),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? MyColors.primaryColor
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Row(
      children: [
        // Sélecteur d'heure
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedHour,
                isExpanded: true,
                items: List.generate(24, (i) => i).map((hour) {
                  return DropdownMenuItem(
                    value: hour,
                    child: Text('${hour.toString().padLeft(2, '0')}h'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedHour = value);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        // Sélecteur de minutes (par 15 min)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMinute,
                isExpanded: true,
                items: [0, 15, 30, 45].map((min) {
                  return DropdownMenuItem(
                    value: min,
                    child: Text(min.toString().padLeft(2, '0')),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedMinute = value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
