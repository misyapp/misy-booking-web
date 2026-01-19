import 'dart:async';
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

    _driversSubscription = FirestoreServices.users
        .where('isCustomer', isEqualTo: false)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((event) async {
      if (!mounted) return;

      // Utiliser la position du pickup si disponible, sinon le centre de Tana
      final centerLat = _pickupLatLng?.latitude ?? _defaultPosition.latitude;
      final centerLng = _pickupLatLng?.longitude ?? _defaultPosition.longitude;

      List<Map<String, dynamic>> driversWithDistance = [];

      // Calculer la distance de chaque chauffeur par rapport au centre
      for (int i = 0; i < event.docs.length; i++) {
        DriverModal driver = DriverModal.fromJson(event.docs[i].data() as Map);

        if (driver.currentLat != null && driver.currentLng != null) {
          var distance = getDistance(
            driver.currentLat!,
            driver.currentLng!,
            centerLat,
            centerLng,
          );

          // Limiter aux chauffeurs dans un rayon de 20km
          if (distance <= 20) {
            driversWithDistance.add({
              'distance': distance,
              'driverData': driver,
            });
          }
        }
      }

      // Trier par distance et prendre les 8 plus proches
      driversWithDistance.sort((a, b) => a['distance'].compareTo(b['distance']));
      final nearest8 = driversWithDistance.take(8).toList();

      // Créer les markers
      await _updateDriverMarkers(nearest8);
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

    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    Set<Marker> newMarkers = {};

    for (var driverInfo in drivers) {
      final DriverModal driver = driverInfo['driverData'];
      final String markerId = driver.id ?? 'driver_${drivers.indexOf(driverInfo)}';

      // Récupérer l'icône du véhicule (avec cache)
      BitmapDescriptor icon = await _getVehicleIcon(driver.vehicleType, mapProvider);

      newMarkers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: LatLng(driver.currentLat!, driver.currentLng!),
          icon: icon,
          flat: true,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _driverMarkers = newMarkers;
      });
    }
  }

  /// Récupère l'icône du véhicule depuis le cache ou la charge
  Future<BitmapDescriptor> _getVehicleIcon(String? vehicleType, GoogleMapProvider mapProvider) async {
    // Icône par défaut
    if (vehicleType == null || !vehicleMap.containsKey(vehicleType)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }

    // Vérifier le cache
    if (_vehicleIconCache.containsKey(vehicleType)) {
      return _vehicleIconCache[vehicleType]!;
    }

    // Charger l'icône depuis l'URL
    try {
      final vehicleInfo = vehicleMap[vehicleType];
      if (vehicleInfo?.marker != null && vehicleInfo!.marker.isNotEmpty) {
        final icon = await mapProvider.createMarkerImageFromNetwork(vehicleInfo.marker);
        _vehicleIconCache[vehicleType] = icon;
        return icon;
      }
    } catch (e) {
      debugPrint('Error loading vehicle marker for $vehicleType: $e');
    }

    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
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

          // Formulaire de recherche ou sélection de véhicule
          ValueListenableBuilder<bool>(
            valueListenable: _showVehicleSelection,
            builder: (context, showVehicles, _) {
              return showVehicles
                  ? _buildVehicleSelectionPanel()
                  : _buildSearchCard();
            },
          ),
        ],
      ),
    );
  }

  /// Carte Google Maps pleine page
  Widget _buildMap() {
    // Combiner les markers des chauffeurs avec les markers de pickup/destination
    Set<Marker> allMarkers = {..._driverMarkers};

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

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _defaultPosition,
        zoom: 13,
      ),
      // Utiliser le paramètre style au lieu de setMapStyle (obsolète sur web)
      style: _mapStyle,
      markers: allMarkers,
      polylines: _routePolylines,
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
              _buildNavTab('Accueil', Icons.home_outlined, true),
              _buildNavTab('Carte des transports', Icons.directions_bus_outlined, false),

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
  Widget _buildNavTab(String label, IconData icon, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton.icon(
        onPressed: () {},
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

  /// Dessine l'itinéraire entre le pickup et la destination
  Future<void> _drawRoute() async {
    if (_pickupLocation['lat'] == null || _destinationLocation['lat'] == null) {
      return;
    }

    try {
      final origin = LatLng(_pickupLocation['lat'], _pickupLocation['lng']);
      final destination = LatLng(_destinationLocation['lat'], _destinationLocation['lng']);

      // Récupérer l'itinéraire via RouteService
      final routeInfo = await RouteService.fetchRoute(
        origin: origin,
        destination: destination,
      );

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

        // Ajuster la caméra pour voir tout l'itinéraire
        _fitMapToRoute(origin, destination);
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
      // En cas d'erreur, tracer une ligne directe
      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: const PolylineId('route_fallback'),
            points: [
              LatLng(_pickupLocation['lat'], _pickupLocation['lng']),
              LatLng(_destinationLocation['lat'], _destinationLocation['lng']),
            ],
            color: MyColors.primaryColor,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };
      });
    }
  }

  /// Ajuste la caméra pour afficher tout l'itinéraire
  void _fitMapToRoute(LatLng origin, LatLng destination) {
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

            // Liste des véhicules
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: vehicleListModal.where((v) => v.active).length,
                itemBuilder: (context, index) {
                  final activeVehicles = vehicleListModal.where((v) => v.active).toList();
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
}
