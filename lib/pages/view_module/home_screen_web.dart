import 'dart:async';
import 'dart:math';
import 'dart:js_util' as js_util;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/places_autocomplete_web.dart';
import 'package:rider_ride_hailing_app/services/route_service.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'package:rider_ride_hailing_app/services/osrm_service.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart' show LoginPage;
import 'package:rider_ride_hailing_app/pages/auth_module/signup_screen.dart' show SignUpScreen;
import 'package:rider_ride_hailing_app/pages/view_module/transport_map_screen.dart';

/// Page d'accueil Web style Uber - version allégée
/// Affiche une carte pleine page avec:
/// - Header avec logo + onglets + boutons connexion
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

  // Focus nodes pour gérer le focus des champs
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  // Position par défaut: Antananarivo, Madagascar (centre ville)
  static const LatLng _defaultPosition = LatLng(-18.8792, 47.5079);

  // Subscription pour les chauffeurs en ligne
  StreamSubscription<QuerySnapshot>? _driversSubscription;

  // Markers pour la carte (chauffeurs)
  Set<Marker> _driverMarkers = {};

  // Polylines pour l'itinéraire
  Set<Polyline> _routePolylines = {};

  // Position du pickup pour charger les chauffeurs proches
  LatLng? _pickupLatLng;

  // État pour afficher le panneau de sélection de véhicule
  final ValueNotifier<bool> _showVehicleSelection = ValueNotifier(false);
  final ValueNotifier<int> _selectedVehicleIndex = ValueNotifier(-1);

  // Index spécial pour "Transport en commun" dans la liste des véhicules
  static const int _publicTransportIndex = -2;

  // Style de carte personnalisé - JSON minifié pour compatibilité web
  // Fond gris clair, routes bleu lavande, eau bleue
  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#A6B5DE"}]},{"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":3}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#BCC5E8"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.local","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road","elementType":"labels","stylers":[{"visibility":"on"}]},{"featureType":"road.highway","elementType":"labels.icon","stylers":[{"visibility":"on"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#ADD4F5"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"poi","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"on"},{"color":"#B0B0B0"}]},{"featureType":"poi.business","elementType":"labels.text","stylers":[{"visibility":"off"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"transit.station.bus","elementType":"labels.text","stylers":[{"visibility":"on"},{"color":"#000000"}]},{"featureType":"transit.station.bus","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"transit.station.bus","elementType":"labels.icon","stylers":[{"visibility":"on"},{"color":"#4A4A4A"}]}]';

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

  // ========== MODE TRANSPORT EN COMMUN ==========
  // Mode actuel: 0 = Accueil (courses), 1 = Transport en commun
  int _currentMode = 0;

  // Données transport en commun
  List<TransportLineGroup> _transportLineGroups = [];
  bool _isLoadingTransportLines = false;
  Set<Polyline> _transportPolylines = {};
  Set<Marker> _transportStopMarkers = {};
  final Set<String> _visibleTransportLines = {};
  final Map<TransportType, bool> _transportTypeFilters = {
    TransportType.bus: true,
    TransportType.urbanTrain: true,
    TransportType.telepherique: true,
  };

  // Itinéraire transport en commun
  TransportRoute? _currentTransportRoute;
  bool _isCalculatingTransportRoute = false;
  Set<Polyline> _transportRoutePolylines = {};
  Set<Marker> _transportRouteMarkers = {};
  int _transportPanelMode = 0; // 0 = Lignes, 1 = Itinéraire

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
    _subscribeToOnlineDrivers();
  }

  void _setupFocusListeners() {
    _pickupFocusNode.addListener(() {
      _isPickupFocused.value = _pickupFocusNode.hasFocus;
      if (!_pickupFocusNode.hasFocus) {
        // Délai pour permettre la sélection avant de masquer
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

      // Utiliser la position du pickup si disponible, sinon le centre de Tana
      final centerLat = _pickupLatLng?.latitude ?? _defaultPosition.latitude;
      final centerLng = _pickupLatLng?.longitude ?? _defaultPosition.longitude;

      debugPrint('🚕 Centre de recherche: $centerLat, $centerLng');

      List<Map<String, dynamic>> driversWithDistance = [];

      // Calculer la distance de chaque chauffeur par rapport au centre
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

            // Limiter aux chauffeurs dans un rayon de 20km
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

      // Trier par distance et prendre les 8 plus proches
      driversWithDistance.sort((a, b) => a['distance'].compareTo(b['distance']));
      final nearest8 = driversWithDistance.take(8).toList();

      debugPrint('🚕 ${nearest8.length} chauffeurs les plus proches à afficher');

      // Créer les markers
      await _updateDriverMarkers(nearest8);
    }, onError: (error) {
      debugPrint('🚕 ❌ Erreur Firestore: $error');
    });
  }

  /// Recharge les chauffeurs autour d'une nouvelle position
  void _reloadDriversNearPosition(LatLng position) {
    _pickupLatLng = position;
    _subscribeToOnlineDrivers();
  }

  // Cache des icônes de véhicules pour éviter de les recharger
  final Map<String, BitmapDescriptor> _vehicleIconCache = {};

  /// Met à jour les markers des chauffeurs sur la carte
  Future<void> _updateDriverMarkers(List<Map<String, dynamic>> drivers) async {
    if (!mounted) return;

    debugPrint('🚗 Mise à jour des markers: ${drivers.length} chauffeurs, vehicleMap: ${vehicleMap.length} entrées');

    Set<Marker> newMarkers = {};

    for (var driverInfo in drivers) {
      final DriverModal driver = driverInfo['driverData'];
      final String markerId = driver.id ?? 'driver_${drivers.indexOf(driverInfo)}';

      // Récupérer l'icône du véhicule (avec cache, taille réduite)
      BitmapDescriptor icon = await _getVehicleIcon(driver.vehicleType);

      // Calculer la rotation du marker basée sur le heading du chauffeur
      double rotation = _calculateDriverHeading(driver);

      newMarkers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: LatLng(driver.currentLat!, driver.currentLng!),
          icon: icon,
          flat: true,
          rotation: rotation,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: driver.vehicleType ?? 'Chauffeur'),
        ),
      );
    }

    debugPrint('🚗 ${newMarkers.length} markers créés');

    if (mounted) {
      setState(() {
        _driverMarkers = newMarkers;
      });
    }
  }

  /// Calcule le heading (direction) du chauffeur en degrés
  /// Utilise le heading stocké, ou le calcule depuis oldLat/oldLng vers currentLat/currentLng
  double _calculateDriverHeading(DriverModal driver) {
    // Si le chauffeur a un heading stocké, l'utiliser
    if (driver.heading != null && driver.heading != 0) {
      debugPrint('🧭 ${driver.firstName}: heading Firestore = ${driver.heading}°');
      return driver.heading!;
    }

    // Sinon, calculer le heading depuis l'ancienne position vers la position actuelle
    if (driver.oldLat != null && driver.oldLng != null &&
        driver.currentLat != null && driver.currentLng != null) {
      // Vérifier que les positions sont différentes (sinon bearing = 0)
      final latDiff = (driver.currentLat! - driver.oldLat!).abs();
      final lngDiff = (driver.currentLng! - driver.oldLng!).abs();

      if (latDiff > 0.00001 || lngDiff > 0.00001) {
        final bearing = _bearingBetween(
          driver.oldLat!, driver.oldLng!,
          driver.currentLat!, driver.currentLng!,
        );
        debugPrint('🧭 ${driver.firstName}: bearing calculé = ${bearing.toStringAsFixed(1)}° (old: ${driver.oldLat}, ${driver.oldLng} -> current: ${driver.currentLat}, ${driver.currentLng})');
        return bearing;
      }
    }

    // Par défaut: utiliser une rotation aléatoire basée sur l'ID du chauffeur
    // pour éviter que tous les markers pointent dans la même direction
    final randomRotation = (driver.id.hashCode % 360).toDouble();
    debugPrint('🧭 ${driver.firstName}: rotation par défaut (hashCode) = ${randomRotation.toStringAsFixed(1)}°');
    return randomRotation;
  }

  /// Calcule l'angle (bearing) entre deux points géographiques
  double _bearingBetween(double lat1, double lng1, double lat2, double lng2) {
    final double dLng = _degreesToRadians(lng2 - lng1);
    final double lat1Rad = _degreesToRadians(lat1);
    final double lat2Rad = _degreesToRadians(lat2);

    final double y = sin(dLng) * cos(lat2Rad);
    final double x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

    double bearing = atan2(y, x);
    bearing = _radiansToDegrees(bearing);
    return (bearing + 360) % 360; // Normaliser entre 0 et 360
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;
  double _radiansToDegrees(double radians) => radians * 180 / pi;

  /// Taille des icônes de véhicules en pixels
  static const int _markerSize = 40;

  /// Récupère l'icône du véhicule depuis le cache ou la charge (taille réduite)
  Future<BitmapDescriptor> _getVehicleIcon(String? vehicleType) async {
    // Si vehicleMap est vide ou vehicleType inconnu, utiliser un marker cyan par défaut
    if (vehicleType == null || vehicleMap.isEmpty || !vehicleMap.containsKey(vehicleType)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }

    // Clé de cache incluant la taille
    final cacheKey = '${vehicleType}_$_markerSize';

    // Vérifier le cache
    if (_vehicleIconCache.containsKey(cacheKey)) {
      return _vehicleIconCache[cacheKey]!;
    }

    // Charger l'icône depuis l'URL avec taille réduite
    try {
      final vehicleInfo = vehicleMap[vehicleType];
      if (vehicleInfo?.marker != null && vehicleInfo!.marker.isNotEmpty) {
        final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
        final icon = await mapProvider.createResizedMarkerFromNetwork(
          vehicleInfo.marker,
          targetWidth: _markerSize,
        );
        _vehicleIconCache[cacheKey] = icon;
        debugPrint('🚗 Icône chargée pour $vehicleType (${_markerSize}px)');
        return icon;
      }
    } catch (e) {
      debugPrint('🚗 Erreur chargement icône $vehicleType: $e');
    }

    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
  }

  /// Recherche d'adresse avec debouncing pour le pickup
  void _debouncedPickupSearch(String query) {
    _pickupDebounceTimer?.cancel();

    if (query.length < _minCharsForSearch) {
      _pickupSuggestions.value = [];
      return;
    }

    if (query == _lastPickupQuery) return;

    _pickupDebounceTimer = Timer(_debounceDuration, () async {
      _lastPickupQuery = query;
      // Utiliser l'API JavaScript de Google Places pour le web
      final predictions = await PlacesAutocompleteWeb.getPlacePredictions(query);
      _pickupSuggestions.value = predictions;
    });
  }

  /// Recherche d'adresse avec debouncing pour la destination
  void _debouncedDestinationSearch(String query) {
    _destinationDebounceTimer?.cancel();

    if (query.length < _minCharsForSearch) {
      _destinationSuggestions.value = [];
      return;
    }

    if (query == _lastDestinationQuery) return;

    _destinationDebounceTimer = Timer(_debounceDuration, () async {
      _lastDestinationQuery = query;
      // Utiliser l'API JavaScript de Google Places pour le web
      final predictions = await PlacesAutocompleteWeb.getPlacePredictions(query);
      _destinationSuggestions.value = predictions;
    });
  }

  /// Sélection d'une suggestion de pickup
  Future<void> _selectPickupSuggestion(Map suggestion) async {
    _isSearching.value = true;
    _pickupController.text = suggestion['description'] ?? '';
    _pickupSuggestions.value = [];

    try {
      // Utiliser l'API JavaScript de Google Places pour le web
      final details = await PlacesAutocompleteWeb.getPlaceDetails(suggestion['place_id']);
      if (details != null && details['result'] != null && details['result']['geometry'] != null) {
        final location = details['result']['geometry']['location'];
        _pickupLocation = {
          'lat': location['lat'],
          'lng': location['lng'],
          'address': suggestion['description'],
        };

        final pickupPosition = LatLng(location['lat'], location['lng']);

        // Animer la carte vers la position sélectionnée
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(pickupPosition, 14),
        );

        // Recharger les chauffeurs autour du lieu de prise en charge
        _reloadDriversNearPosition(pickupPosition);

        // Passer au champ destination
        _destinationFocusNode.requestFocus();
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }

    _isSearching.value = false;
  }

  /// Sélection d'une suggestion de destination
  Future<void> _selectDestinationSuggestion(Map suggestion) async {
    _isSearching.value = true;
    _destinationController.text = suggestion['description'] ?? '';
    _destinationSuggestions.value = [];

    try {
      // Utiliser l'API JavaScript de Google Places pour le web
      final details = await PlacesAutocompleteWeb.getPlaceDetails(suggestion['place_id']);
      if (details != null && details['result'] != null && details['result']['geometry'] != null) {
        final location = details['result']['geometry']['location'];
        _destinationLocation = {
          'lat': location['lat'],
          'lng': location['lng'],
          'address': suggestion['description'],
        };

        // Unfocus pour masquer le clavier
        FocusScope.of(context).unfocus();

        // Passer automatiquement au flow suivant si pickup est aussi renseigné
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte Google Maps pleine page
          _buildMap(),

          // Header avec logo et navigation
          _buildHeader(),

          // Panneau latéral gauche selon le mode
          if (_currentMode == 0)
            // Mode Accueil: Formulaire de recherche ou sélection de véhicule
            ValueListenableBuilder<bool>(
              valueListenable: _showVehicleSelection,
              builder: (context, showVehicles, _) {
                return showVehicles
                    ? _buildVehicleSelectionPanel()
                    : _buildSearchCard();
              },
            )
          else
            // Mode Transport: Panneau des lignes de transport
            _buildTransportPanel(),
        ],
      ),
    );
  }

  /// Carte Google Maps pleine page
  Widget _buildMap() {
    Set<Marker> allMarkers = {};
    Set<Polyline> allPolylines = {};

    if (_currentMode == 0) {
      // Mode Accueil: afficher les chauffeurs
      allMarkers = {..._driverMarkers};
      allPolylines = {..._routePolylines};

      // Ajouter le marker de pickup si disponible
      if (_pickupLocation['lat'] != null) {
        allMarkers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(_pickupLocation['lat'], _pickupLocation['lng']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Départ'),
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
            infoWindow: const InfoWindow(title: 'Arrivée'),
          ),
        );
      }
    } else {
      // Mode Transport: afficher les lignes et arrêts
      allMarkers = {..._transportStopMarkers, ..._transportRouteMarkers};
      allPolylines = {..._transportPolylines, ..._transportRoutePolylines};
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _defaultPosition,
        zoom: 13,
      ),
      // Utiliser le paramètre style au lieu de setMapStyle (obsolète sur web)
      style: _mapStyle,
      markers: allMarkers,
      polylines: allPolylines,
      onMapCreated: (controller) {
        _mapController = controller;
        // Appliquer le style via JS pour compatibilité web
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
    );
  }

  /// Applique le style de carte via JavaScript pour contourner les limitations de Flutter Web
  void _applyMapStyleViaJS() {
    try {
      // Appeler la fonction JS définie dans index.html via js_util
      final window = js_util.globalThis;
      final fn = js_util.getProperty(window, 'applyMisyMapStyle');
      if (fn != null) {
        js_util.callMethod(window, 'applyMisyMapStyle', []);
      }
    } catch (e) {
      debugPrint('Error applying map style via JS: $e');
    }
  }

  /// Header avec logo Misy + onglets navigation + bouton Mon compte
  Widget _buildHeader() {
    return ValueListenableBuilder(
      valueListenable: userData,
      builder: (context, user, _) {
        final isLoggedIn = user != null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Logo Misy
              Image.asset(
                MyImagesUrl.misyLogoRose,
                height: 32,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 32),

              // Onglets de navigation principaux
              _buildNavTab(
                'Accueil',
                Icons.home_outlined,
                _currentMode == 0,
                onTap: () => _switchToMode(0),
              ),
              _buildNavTab(
                'Carte des transports',
                Icons.directions_bus_outlined,
                _currentMode == 1,
                onTap: () => _switchToMode(1),
              ),

              const Spacer(),

              // Mon compte - change selon l'état de connexion
              if (!isLoggedIn) ...[
                // Non connecté: deux boutons distincts
                TextButton(
                  onPressed: () => _navigateToLogin(),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text("S'inscrire"),
                ),
              ] else ...[
                // Connecté: bouton Mon compte avec menu déroulant
                PopupMenuButton<String>(
                  offset: const Offset(0, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: MyColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: MyColors.primaryColor,
                          child: Text(
                            (user?.firstName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mon compte',
                          style: TextStyle(
                            color: MyColors.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: MyColors.primaryColor),
                      ],
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
                    const PopupMenuItem(
                      value: 'mail',
                      child: Row(
                        children: [
                          Icon(Icons.mail_outline),
                          SizedBox(width: 8),
                          Text('Courrier'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined),
                          SizedBox(width: 8),
                          Text('Paramètres'),
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
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Onglet de navigation dans le header
  Widget _buildNavTab(String label, IconData icon, bool isActive, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 18,
          color: isActive ? MyColors.primaryColor : Colors.black54,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? MyColors.primaryColor : Colors.black54,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? MyColors.primaryColor.withOpacity(0.1) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  /// Formulaire de recherche flottant (style Uber) avec autocomplete
  Widget _buildSearchCard() {
    return Positioned(
      top: 100,
      left: 24,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titre
            const Text(
              'Commander une course',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Champs de saisie avec autocomplete
            _buildLocationInputs(),

            const SizedBox(height: 16),

            // Options de prise en charge
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
                            'Voir les prix',
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
    );
  }

  /// Champs de saisie Pickup et Destination avec autocomplete
  Widget _buildLocationInputs() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icônes avec ligne verticale (couleurs Misy)
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

  /// Liste de suggestions
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

  /// Options de prise en charge (maintenant / planifié)
  Widget _buildScheduleOptions() {
    return Column(
      children: [
        // Bouton "Prise en charge immédiate"
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

    // Vérifier que les coordonnées sont disponibles
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

      // Stocker les locations dans le provider
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

      // Calculer le temps/distance
      final totalTime = await getTotalTimeCalculate(
        '${_pickupLocation['lat']},${_pickupLocation['lng']}',
        '${_destinationLocation['lat']},${_destinationLocation['lng']}',
      );
      totalWilltake.value = totalTime;

      // Vérifier la distance minimale (1h de marche ≈ 5 km)
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

      // Dessiner l'itinéraire sur la carte
      await _drawRoute();

      // Afficher le panneau de sélection de véhicule
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

  /// Recherche d'itinéraire en transport en commun
  void _onSearchPublicTransport() {
    final pickup = _pickupController.text.trim();
    final destination = _destinationController.text.trim();

    if (pickup.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le départ et la destination'),
        ),
      );
      return;
    }

    // Vérifier que les coordonnées sont disponibles
    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une adresse dans la liste de suggestions'),
        ),
      );
      return;
    }

    // Naviguer vers TransportMapScreen avec les paramètres d'itinéraire
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransportMapScreen(
          initialMode: 1, // Mode Itinéraire
          originAddress: pickup,
          originPosition: LatLng(_pickupLocation['lat'], _pickupLocation['lng']),
          destinationAddress: destination,
          destinationPosition: LatLng(_destinationLocation['lat'], _destinationLocation['lng']),
        ),
      ),
    );
  }

  /// Dessine l'itinéraire entre le pickup et la destination
  /// Option "Transport en commun" dans la liste des véhicules
  Widget _buildPublicTransportOption() {
    const Color publicTransportColor = Color(0xFF2E7D32); // Vert

    return ValueListenableBuilder<int>(
      valueListenable: _selectedVehicleIndex,
      builder: (context, selectedIndex, _) {
        final isSelected = selectedIndex == _publicTransportIndex;

        return InkWell(
          onTap: () {
            _selectedVehicleIndex.value = _publicTransportIndex;
            // Naviguer vers la carte des transports
            _onSearchPublicTransport();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? publicTransportColor.withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? publicTransportColor
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icône bus
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    color: publicTransportColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: publicTransportColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),

                // Nom et description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transport en commun',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: publicTransportColor,
                        ),
                      ),
                      Text(
                        'Bus, taxi-be, lignes urbaines',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Flèche pour indiquer navigation
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _drawRoute() async {
    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) {
      debugPrint('🛣️ _drawRoute: pickup ou destination manquant');
      return;
    }

    debugPrint('🛣️ _drawRoute: Calcul itinéraire OSRM2...');

    try {
      final origin = LatLng(_pickupLocation['lat'], _pickupLocation['lng']);
      final destination = LatLng(_destinationLocation['lat'], _destinationLocation['lng']);

      debugPrint('🛣️ Origin: ${origin.latitude}, ${origin.longitude}');
      debugPrint('🛣️ Destination: ${destination.latitude}, ${destination.longitude}');

      // Récupérer l'itinéraire via RouteService (OSRM2)
      final routeInfo = await RouteService.fetchRoute(
        origin: origin,
        destination: destination,
      );

      debugPrint('🛣️ Route reçue: ${routeInfo.coordinates.length} points');

      if (routeInfo.coordinates.isNotEmpty) {
        setState(() {
          _routePolylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routeInfo.coordinates,
              color: MyColors.primaryColor,
              width: 5,
            ),
          };
        });

        debugPrint('🛣️ Polyline créée avec ${routeInfo.coordinates.length} points');

        // Ajuster la caméra pour voir tout l'itinéraire
        _fitMapToRoute(routeInfo.coordinates);
      }
    } catch (e, stackTrace) {
      debugPrint('🛣️ ❌ Erreur OSRM: $e');
      debugPrint('🛣️ Stack: $stackTrace');

      // Afficher l'erreur dans un snackbar pour debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route OSRM error: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // En cas d'erreur, tracer une ligne directe (pointillés)
      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: const PolylineId('route_fallback'),
            points: [
              LatLng(_pickupLocation['lat'], _pickupLocation['lng']),
              LatLng(_destinationLocation['lat'], _destinationLocation['lng']),
            ],
            color: Colors.red,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };
      });
    }
  }

  /// Ajuste la caméra pour afficher tout l'itinéraire
  void _fitMapToRoute(List<LatLng> routePoints) {
    if (_mapController == null || routePoints.isEmpty) return;

    // Calculer les bounds à partir de tous les points de l'itinéraire
    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (final point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Padding de 100 pixels pour laisser de l'espace autour de l'itinéraire
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  /// Panneau de sélection de véhicule avec les prix
  Widget _buildVehicleSelectionPanel() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    return Positioned(
      top: 100,
      left: 24,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header avec bouton retour
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    _showVehicleSelection.value = false;
                  },
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Choisissez votre course',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                  Icon(Icons.route, color: MyColors.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${totalWilltake.value.distance.toStringAsFixed(1)} km • ${totalWilltake.value.time.toStringAsFixed(0)} min',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Liste des véhicules + Transport en commun
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: vehicleListModal.where((v) => v.active).length + 1, // +1 pour transport en commun
                itemBuilder: (context, index) {
                  final activeVehicles = vehicleListModal.where((v) => v.active).toList();

                  // Dernier item = Transport en commun
                  if (index == activeVehicles.length) {
                    return _buildPublicTransportOption();
                  }

                  final vehicle = activeVehicles[index];
                  final price = tripProvider.calculatePriceForVehicle(vehicle);

                  return ValueListenableBuilder<int>(
                    valueListenable: _selectedVehicleIndex,
                    builder: (context, selectedIndex, _) {
                      final isSelected = selectedIndex == index;

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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  vehicle.image,
                                  width: 60,
                                  height: 40,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 40,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.directions_car),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Nom et capacité
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${vehicle.persons} places',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
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
                                  fontSize: 16,
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
                },
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
    );
  }

  /// Confirme la course et passe à l'étape suivante
  void _onConfirmRide() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // Vérifier si l'utilisateur est connecté
    if (userData.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour commander une course'),
        ),
      );
      _navigateToLogin();
      return;
    }

    // Passer à l'écran de demande de course
    tripProvider.setScreen(CustomTripType.requestForRide);

    // TODO: Implémenter la logique de demande de course
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

  // ========== GESTION DES MODES ==========

  /// Bascule entre le mode Accueil (0) et Transport (1)
  void _switchToMode(int mode) {
    if (_currentMode == mode) return;

    setState(() {
      _currentMode = mode;

      if (mode == 1) {
        // Mode Transport: charger les lignes et masquer les drivers
        _loadTransportLines();
      } else {
        // Mode Accueil: effacer les données transport
        _transportPolylines = {};
        _transportStopMarkers = {};
        _transportRoutePolylines = {};
        _transportRouteMarkers = {};
        _currentTransportRoute = null;
      }
    });
  }

  /// Charge les lignes de transport en commun
  Future<void> _loadTransportLines() async {
    if (_transportLineGroups.isNotEmpty) {
      // Déjà chargées, juste afficher
      _updateTransportMapElements();
      return;
    }

    setState(() => _isLoadingTransportLines = true);

    try {
      final lines = await TransportLinesService.instance.loadAllLines();
      if (mounted) {
        setState(() {
          _transportLineGroups = lines;
          _isLoadingTransportLines = false;
          // Afficher toutes les lignes par défaut
          for (final group in lines) {
            _visibleTransportLines.add(group.lineNumber);
          }
        });
        _updateTransportMapElements();
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement lignes transport: $e');
      if (mounted) {
        setState(() => _isLoadingTransportLines = false);
      }
    }
  }

  /// Met à jour les polylines et markers pour les lignes de transport visibles
  void _updateTransportMapElements() {
    final Set<Polyline> polylines = {};
    final Set<Marker> markers = {};

    for (final group in _transportLineGroups) {
      // Vérifier si cette ligne est visible et son type est activé
      if (!_visibleTransportLines.contains(group.lineNumber)) continue;
      if (!_transportTypeFilters[group.transportType]!) continue;

      // Ajouter les polylines pour chaque variante
      for (int i = 0; i < group.lines.length; i++) {
        final variant = group.lines[i];
        if (variant.coordinates.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('transport_${group.lineNumber}_$i'),
              points: variant.coordinates,
              color: Color(group.transportType.colorValue),
              width: 4,
              patterns: group.transportType == TransportType.telepherique
                  ? [PatternItem.dash(10), PatternItem.gap(5)]
                  : [],
            ),
          );
        }

        // Ajouter les markers pour les arrêts
        for (final stop in variant.stops) {
          final markerId = 'stop_${group.lineNumber}_${stop.stopId}';
          // Éviter les doublons
          if (!markers.any((m) => m.markerId.value == markerId)) {
            markers.add(
              Marker(
                markerId: MarkerId(markerId),
                position: stop.position,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  _getHueForTransportType(group.transportType),
                ),
                infoWindow: InfoWindow(
                  title: stop.name,
                  snippet: 'Ligne ${group.lineNumber}',
                ),
              ),
            );
          }
        }
      }
    }

    setState(() {
      _transportPolylines = polylines;
      _transportStopMarkers = markers;
    });
  }

  double _getHueForTransportType(TransportType type) {
    switch (type) {
      case TransportType.bus:
        return BitmapDescriptor.hueOrange;
      case TransportType.urbanTrain:
        return BitmapDescriptor.hueBlue;
      case TransportType.telepherique:
        return BitmapDescriptor.hueViolet;
    }
  }

  /// Toggle visibilité d'une ligne
  void _toggleTransportLine(String lineNumber) {
    setState(() {
      if (_visibleTransportLines.contains(lineNumber)) {
        _visibleTransportLines.remove(lineNumber);
      } else {
        _visibleTransportLines.add(lineNumber);
      }
    });
    _updateTransportMapElements();
  }

  /// Toggle filtre par type de transport
  void _toggleTransportTypeFilter(TransportType type) {
    setState(() {
      _transportTypeFilters[type] = !_transportTypeFilters[type]!;
    });
    _updateTransportMapElements();
  }

  // ========== PANNEAU TRANSPORT EN COMMUN ==========

  /// Panneau latéral pour le mode Transport
  Widget _buildTransportPanel() {
    return Positioned(
      top: 100,
      left: 20,
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header avec onglets
            _buildTransportPanelHeader(),

            // Contenu selon l'onglet
            Flexible(
              child: _transportPanelMode == 0
                  ? _buildTransportLinesContent()
                  : _buildTransportItineraryContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// Header du panneau transport avec onglets
  Widget _buildTransportPanelHeader() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTransportPanelTab(
              icon: Icons.map_outlined,
              label: 'Lignes',
              isSelected: _transportPanelMode == 0,
              onTap: () => setState(() => _transportPanelMode = 0),
            ),
          ),
          Expanded(
            child: _buildTransportPanelTab(
              icon: Icons.directions,
              label: 'Itinéraire',
              isSelected: _transportPanelMode == 1,
              onTap: () => setState(() => _transportPanelMode = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportPanelTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const Color transportColor = Color(0xFF2E7D32);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? transportColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? transportColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? transportColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Contenu: liste des lignes de transport
  Widget _buildTransportLinesContent() {
    if (_isLoadingTransportLines) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Filtres par type
        _buildTransportTypeFilters(),

        const Divider(height: 1),

        // Liste des lignes
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _transportLineGroups.length,
            itemBuilder: (context, index) {
              final group = _transportLineGroups[index];

              // Filtrer par type
              if (!_transportTypeFilters[group.transportType]!) {
                return const SizedBox.shrink();
              }

              final isVisible = _visibleTransportLines.contains(group.lineNumber);

              return ListTile(
                dense: true,
                leading: Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(group.transportType.colorValue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    group.lineNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  group.displayName,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Switch(
                  value: isVisible,
                  onChanged: (_) => _toggleTransportLine(group.lineNumber),
                  activeColor: Color(group.transportType.colorValue),
                ),
                onTap: () => _toggleTransportLine(group.lineNumber),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Filtres par type de transport
  Widget _buildTransportTypeFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTypeFilterChip(TransportType.bus, 'Bus', Icons.directions_bus),
          _buildTypeFilterChip(TransportType.urbanTrain, 'Train', Icons.train),
          _buildTypeFilterChip(TransportType.telepherique, 'Télép.', Icons.cable),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(TransportType type, String label, IconData icon) {
    final isActive = _transportTypeFilters[type]!;
    final color = Color(type.colorValue);

    return FilterChip(
      selected: isActive,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isActive ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : color)),
        ],
      ),
      selectedColor: color,
      backgroundColor: color.withOpacity(0.1),
      checkmarkColor: Colors.white,
      onSelected: (_) => _toggleTransportTypeFilter(type),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  /// Contenu: recherche d'itinéraire transport en commun
  Widget _buildTransportItineraryContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Champ Départ
          TextField(
            controller: _pickupController,
            decoration: InputDecoration(
              labelText: 'Départ',
              hintText: 'Adresse de départ',
              prefixIcon: const Icon(Icons.trip_origin, color: Colors.green),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: _debouncedPickupSearch,
          ),

          // Suggestions départ
          ValueListenableBuilder<List>(
            valueListenable: _pickupSuggestions,
            builder: (context, suggestions, _) {
              if (suggestions.isEmpty) return const SizedBox.shrink();
              return _buildSuggestionsList(suggestions, true);
            },
          ),

          const SizedBox(height: 12),

          // Champ Arrivée
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              labelText: 'Arrivée',
              hintText: 'Adresse d\'arrivée',
              prefixIcon: Icon(Icons.location_on, color: MyColors.primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: _debouncedDestinationSearch,
          ),

          // Suggestions arrivée
          ValueListenableBuilder<List>(
            valueListenable: _destinationSuggestions,
            builder: (context, suggestions, _) {
              if (suggestions.isEmpty) return const SizedBox.shrink();
              return _buildSuggestionsList(suggestions, false);
            },
          ),

          const SizedBox(height: 16),

          // Bouton Rechercher
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pickupLocation['lat'] != null && _destinationLocation['lat'] != null)
                  ? _searchTransportRoute
                  : null,
              icon: _isCalculatingTransportRoute
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: Text(_isCalculatingTransportRoute ? 'Recherche...' : 'Chercher un itinéraire'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          // Résultat de l'itinéraire
          if (_currentTransportRoute != null) ...[
            const SizedBox(height: 16),
            _buildTransportRouteResult(),
          ],
        ],
      ),
    );
  }


  /// Recherche d'itinéraire en transport en commun
  Future<void> _searchTransportRoute() async {
    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) return;

    setState(() {
      _isCalculatingTransportRoute = true;
      _currentTransportRoute = null;
      _transportRoutePolylines = {};
      _transportRouteMarkers = {};
    });

    try {
      final origin = LatLng(_pickupLocation['lat'], _pickupLocation['lng']);
      final destination = LatLng(_destinationLocation['lat'], _destinationLocation['lng']);

      final route = await TransportLinesService.instance.findRoute(origin, destination);

      if (route != null && mounted) {
        // Créer les polylines et markers pour l'itinéraire
        final Set<Polyline> routePolylines = {};
        final Set<Marker> routeMarkers = {};

        // Marker de départ
        routeMarkers.add(
          Marker(
            markerId: const MarkerId('transport_origin'),
            position: origin,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Départ', snippet: _pickupController.text),
          ),
        );

        // Marker d'arrivée
        routeMarkers.add(
          Marker(
            markerId: const MarkerId('transport_destination'),
            position: destination,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Arrivée', snippet: _destinationController.text),
          ),
        );

        // Polylines pour chaque étape
        for (int i = 0; i < route.steps.length; i++) {
          final step = route.steps[i];
          final color = step.isWalking
              ? Colors.grey.shade600
              : Color(step.transportType.colorValue);

          if (step.isWalking) {
            // Ligne pointillée pour la marche
            routePolylines.add(
              Polyline(
                polylineId: PolylineId('transport_route_$i'),
                points: [step.startStop.position, step.endStop.position],
                color: color,
                width: 4,
                patterns: [PatternItem.dot, PatternItem.gap(8)],
              ),
            );
          } else {
            // Ligne pleine pour le transport
            final lineGroup = _transportLineGroups.firstWhere(
              (g) => g.lineNumber == step.lineNumber,
              orElse: () => _transportLineGroups.first,
            );

            // Trouver les points entre les arrêts (utiliser le nom pour matcher)
            List<LatLng> points = [step.startStop.position, step.endStop.position];
            for (final line in lineGroup.lines) {
              final startIdx = line.stops.indexWhere((s) => s.name == step.startStop.name);
              final endIdx = line.stops.indexWhere((s) => s.name == step.endStop.name);
              if (startIdx >= 0 && endIdx >= 0 && startIdx < endIdx) {
                points = line.stops.sublist(startIdx, endIdx + 1).map((s) => s.position).toList();
                break;
              }
            }

            routePolylines.add(
              Polyline(
                polylineId: PolylineId('transport_route_$i'),
                points: points,
                color: color,
                width: 5,
              ),
            );
          }
        }

        setState(() {
          _currentTransportRoute = route;
          _transportRoutePolylines = routePolylines;
          _transportRouteMarkers = routeMarkers;
        });

        // Zoomer sur l'itinéraire
        _zoomToFitRoute(origin, destination);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun itinéraire trouvé')),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur recherche itinéraire: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }

    if (mounted) {
      setState(() => _isCalculatingTransportRoute = false);
    }
  }

  /// Zoome la carte pour afficher l'itinéraire
  void _zoomToFitRoute(LatLng origin, LatLng destination) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        origin.latitude < destination.latitude ? origin.latitude : destination.latitude,
        origin.longitude < destination.longitude ? origin.longitude : destination.longitude,
      ),
      northeast: LatLng(
        origin.latitude > destination.latitude ? origin.latitude : destination.latitude,
        origin.longitude > destination.longitude ? origin.longitude : destination.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// Affiche le résultat de l'itinéraire
  Widget _buildTransportRouteResult() {
    final route = _currentTransportRoute!;
    final totalPrice = route.steps
        .where((s) => !s.isWalking)
        .fold(0, (sum, s) => sum + (s.transportType == TransportType.bus ? 500 : 1000));

    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Itinéraire trouvé',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${route.totalDurationMinutes} min • ${route.steps.length} étapes • ~$totalPrice Ar',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          // Résumé des étapes
          ...route.steps.map((step) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: step.isWalking
                        ? Colors.grey.shade400
                        : Color(step.transportType.colorValue),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.isWalking ? Icons.directions_walk : Icons.directions_bus,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.isWalking
                        ? 'Marche ${step.durationMinutes} min'
                        : 'Ligne ${step.lineNumber} (${step.durationMinutes} min)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
