import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';
import 'dart:js_util' as js_util;
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:rider_ride_hailing_app/pages/auth_module/web_auth_screen.dart'
    show WebAuthMode, WebAuthScreen;
import 'package:rider_ride_hailing_app/pages/auth_module/edit_profile_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/phone_number_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/my_booking_screen.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/services/guest_storage_service.dart';
import 'package:rider_ride_hailing_app/models/guest_session.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/request_for_ride.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/drive_on_way.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_public/stop_card.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_public/transport_public_panel.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart' show TransportLine, TransportLineGroup;
import 'package:rider_ride_hailing_app/functions/print_function.dart' show myCustomPrintStatement;
import 'package:rider_ride_hailing_app/widget/home_mode_toggle.dart';
import 'package:rider_ride_hailing_app/widget/transport/stop_marker_factory.dart';
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

  // Rôle éditeur terrain transport (custom claim transport_editor)
  bool _isTransportEditor = false;

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

  // === Mode public (transport en commun) ===
  // Toggle Course / Transport en commun. La carte reste partagée — seules les
  // couches et le panneau gauche changent.
  HomeMode _homeMode = HomeMode.course;

  // Gate : pour le moment, le mode "Transport en commun" n'est exposé qu'au
  // compte admin@misyapp.com. Les autres utilisateurs ne voient ni le toggle
  // ni la sidebar dédiée. À retirer quand la feature sera publique.
  static const String _publicModeAdminEmail = 'admin@misyapp.com';
  bool _isPublicModeAdmin = false;
  StreamSubscription<User?>? _authSubscription;

  // Polylines + markers du réseau taxi-be pour l'overlay de la carte. Calculés
  // au load + à chaque palier de zoom franchi (filtrage type IDFM : moins de
  // lignes visibles à zoom faible).
  Set<Polyline> _publicTransportPolylines = {};
  Set<Marker> _publicTransportMarkers = {};
  bool _publicTransportLoaded = false;

  // Ligne sélectionnée dans la liste (= mise en évidence sur la carte). Null
  // = toutes les lignes (filtrées par zoom) affichées normalement.
  String? _publicSelectedLine;

  // Zoom courant de la carte. Suivi via [GoogleMap.onCameraMove] pour piloter
  // le filtrage zoom-dependent des lignes/stops.
  double _publicMapZoom = 13.0;

  // Stops dédupliqués générés au dernier rebuild des couches. Permet de
  // retrouver les métadonnées à l'ouverture de la card de stop.
  Map<String, _PublicStopAggregate> _publicStopsByKey = {};

  // Stop sélectionné par l'utilisateur (clic sur un marker). Affiche la card
  // flottante + agrandit le marker correspondant.
  String? _publicSelectedStop;

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
    _initializeAndSubscribe();
    _readUrlParameters();
    _restorePendingScheduledBooking();
    _createCustomMarkers();
    _checkTransportEditorRole();
    _watchPublicModeGate();

    // Écouter les changements de TripProvider pour reset l'UI après course
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      tripProvider.addListener(_onTripProviderChanged);
    });
  }

  Future<void> _checkTransportEditorRole() async {
    final ok = await AdminAuthService.instance
        .isTransportEditor(forceRefresh: true);
    if (mounted && ok != _isTransportEditor) {
      setState(() => _isTransportEditor = ok);
    }
  }

  /// Callback quand TripProvider change (pour gérer le reset après course terminée)
  void _onTripProviderChanged() {
    if (!mounted) return;

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // Si on retourne à l'écran initial en mode Course, reset l'UI
    // Ne pas reset si on est en mode Transport (pour ne pas effacer les adresses lors du switch)
    if (tripProvider.currentStep == CustomTripType.setYourDestination) {
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

  /// Restaure une réservation planifiée laissée en attente avant le login
  /// (cas : l'user a fait "Planifier" sur beta.misy.app, a été redirigé vers
  /// l'écran de connexion, puis revient ici une fois authentifié).
  Future<void> _restorePendingScheduledBooking() async {
    if (!kIsWeb) return;
    try {
      // Si déjà restauré via _readUrlParameters (URL params toujours présents),
      // on s'arrête là — pas besoin de doubler la logique.
      if (_pickupLocation['lat'] != null && _destinationLocation['lat'] != null) return;

      final auth = Provider.of<CustomAuthProvider>(context, listen: false);
      final fbUser = auth.currentUser;
      // Ne pas restaurer si toujours anonyme : l'user n'a pas finalisé son login
      if (fbUser == null || fbUser.isAnonymous) return;

      final svc = GuestStorageService();
      final saved = await svc.getBookingData();
      if (saved == null) return;

      final additional = saved['additionalData'] as Map<String, dynamic>?;
      final scheduledAtIso = additional?['scheduledAt'] as String?;
      if (scheduledAtIso == null) return; // pas un trajet planifié

      print('🔁 Restauration réservation planifiée post-login: $scheduledAtIso');

      final pickupLoc = saved['pickupLocation'] as Map?;
      final destLoc = saved['destinationLocation'] as Map?;
      if (pickupLoc != null && pickupLoc['lat'] != null && pickupLoc['lng'] != null) {
        _pickupLocation = Map<String, dynamic>.from(pickupLoc);
        _pickupLatLng = LatLng(pickupLoc['lat'] as double, pickupLoc['lng'] as double);
        _pickupController.text = (pickupLoc['address'] ?? saved['pickupAddress'] ?? '').toString();
      }
      if (destLoc != null && destLoc['lat'] != null && destLoc['lng'] != null) {
        _destinationLocation = Map<String, dynamic>.from(destLoc);
        _destinationController.text = (destLoc['address'] ?? saved['destinationAddress'] ?? '').toString();
      }
      try {
        final parsed = DateTime.parse(scheduledAtIso).toLocal();
        if (parsed.isAfter(DateTime.now())) {
          final tripProvider = Provider.of<TripProvider>(context, listen: false);
          tripProvider.rideScheduledTime = parsed;
        }
      } catch (e) {
        debugPrint('Invalid pending scheduledAt: $e');
      }

      // Effacer la persistance + auto-search
      await svc.clearBookingData();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _pickupLocation['lat'] != null && _destinationLocation['lat'] != null) {
          _onSearch();
        }
      });
    } catch (e) {
      debugPrint('Error restoring pending booking: $e');
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
        final scheduledAtStr = params['scheduledAt'];

        print('📍 URL params: pickup=$pickup, destination=$destination, scheduledAt=$scheduledAtStr');

        // Trajet planifié (deep-link depuis beta.misy.app → "Planifier mon trajet")
        if (scheduledAtStr != null && scheduledAtStr.isNotEmpty) {
          try {
            final parsed = DateTime.parse(scheduledAtStr).toLocal();
            if (parsed.isAfter(DateTime.now())) {
              final tripProvider = Provider.of<TripProvider>(context, listen: false);
              tripProvider.rideScheduledTime = parsed;
              print('📅 Scheduled deep-link → rideScheduledTime = $parsed');
            } else {
              print('⚠️ scheduledAt déjà dans le passé, ignoré: $parsed');
            }
          } catch (e) {
            print('❌ scheduledAt invalide: $scheduledAtStr ($e)');
          }
        }

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
            // Si les 2 champs ont des coordonnées (ex: deep-link depuis beta.misy.app) → auto-search
            if (_pickupLocation['lat'] != null && _destinationLocation['lat'] != null) {
              print('📍 Deep-link complet → _onSearch() auto (→ choix véhicule)');
              _onSearch();
              return;
            }
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
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Met à jour [_isPublicModeAdmin] selon l'utilisateur courant. Quand le
  /// gate se ferme (logout, switch de compte non-admin), on force le retour
  /// en mode Course pour ne pas laisser l'utilisateur sur une UI cachée.
  void _watchPublicModeGate() {
    void apply(User? user) {
      final isAdmin = user?.email == _publicModeAdminEmail;
      if (!mounted) return;
      if (isAdmin == _isPublicModeAdmin) return;
      setState(() {
        _isPublicModeAdmin = isAdmin;
        if (!isAdmin && _homeMode == HomeMode.publicTransport) {
          _homeMode = HomeMode.course;
          _publicSelectedLine = null;
        }
      });
    }

    apply(FirebaseAuth.instance.currentUser);
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(apply);
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

          // Carte de l'arrêt sélectionné en mode Transport en commun.
          if (_homeMode == HomeMode.publicTransport &&
              _isPublicModeAdmin &&
              _publicSelectedStop != null &&
              _publicStopsByKey[_publicSelectedStop] != null)
            StopCard(
              stopName: _publicStopsByKey[_publicSelectedStop]!.name,
              position: _publicStopsByKey[_publicSelectedStop]!.position,
              lineNumbers: _publicStopsByKey[_publicSelectedStop]!.lines.toList()
                ..sort(),
              onClose: _dismissPublicStopCard,
              onLineTap: (lineNumber) {
                _onPublicLineSelected(lineNumber);
              },
            ),
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
  /// Construit le panel approprié selon l'étape actuelle du flux de réservation
  Widget _buildPanelForStep(TripProvider tripProvider) {
    final currentStep = tripProvider.currentStep;

    // En mode "Transport en commun" : sidebar dédiée, peu importe l'étape
    // Course (les 2 modes sont isolés). Gardé derrière le flag admin tant
    // que la feature n'est pas publique.
    if (_homeMode == HomeMode.publicTransport && _isPublicModeAdmin) {
      return TransportPublicPanel(
        mode: _homeMode,
        onModeChanged: _setHomeMode,
        selectedLine: _publicSelectedLine,
        onLineSelected: _onPublicLineSelected,
      );
    }

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
                      itemCount: vehicleListModal.length,
                      itemBuilder: (context, index) {
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
              } else if (value == 'transport-editor') {
                Navigator.of(context).pushNamed('/transport-editor');
              } else if (value == 'profile') {
                push(context: context, screen: const EditProfileScreen());
              } else if (value == 'trips') {
                push(context: context, screen: const MyBookingScreen());
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
              if (_isTransportEditor) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'transport-editor',
                  child: Row(
                    children: [
                      Icon(Icons.edit_road, color: Color(0xFF1565C0)),
                      SizedBox(width: 8),
                      Text('Éditeur terrain',
                          style: TextStyle(color: Color(0xFF1565C0))),
                    ],
                  ),
                ),
              ],
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
    final Set<Marker> allMarkers = {..._driverMarkers};
    final Set<Polyline> allPolylines = _routeCoordinates.isNotEmpty
        ? _buildAnimatedPolylines()
        : {..._routePolylines};

    if (_pickupLocation['lat'] != null) {
      allMarkers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_pickupLocation['lat'], _pickupLocation['lng']),
          icon: _pickupMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
        ),
      );
    }

    if (_destinationLocation['lat'] != null) {
      allMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(
              _destinationLocation['lat'], _destinationLocation['lng']),
          icon: _destinationMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
        ),
      );
    }

    // Couches mode "Transport en commun" — fusionnées par-dessus les layers
    // Course quand on est en mode public. La carte reste UNIQUE entre les 2.
    if (_homeMode == HomeMode.publicTransport) {
      allPolylines.addAll(_publicTransportPolylines);
      allMarkers.addAll(_publicTransportMarkers);
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
      onCameraMove: _onPublicCameraMove,
    );
  }

  /// Gère le tap sur la carte (pour sélectionner une position)
  void _onMapTap(LatLng latLng) {
    // Mode public : pas de sélection de position via tap (réservé Phase 2).
    if (_homeMode == HomeMode.publicTransport) return;

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

  // ─────────────────────── Mode public (Transport en commun) ───────────────────────

  void _setHomeMode(HomeMode mode) {
    if (_homeMode == mode) return;
    if (mode == HomeMode.publicTransport && !_isPublicModeAdmin) return;
    setState(() {
      _homeMode = mode;
      _publicSelectedLine = null;
      _publicSelectedStop = null;
    });
    if (mode == HomeMode.publicTransport && !_publicTransportLoaded) {
      _loadPublicTransportLayers();
    }
  }

  void _onPublicLineSelected(String? lineNumber) {
    setState(() {
      _publicSelectedLine = lineNumber;
      _publicSelectedStop = null;
    });
    _rebuildPublicTransportLayers();
    if (lineNumber != null) _zoomToPublicLine(lineNumber);
  }

  /// Charge le bundle public si pas déjà fait, puis calcule les Set de
  /// polylines + markers pour l'affichage du réseau sur la carte.
  Future<void> _loadPublicTransportLayers() async {
    try {
      await PublicTransportService.instance.ensureLoaded();
      if (!mounted) return;
      await _rebuildPublicTransportLayers();
      setState(() => _publicTransportLoaded = true);
    } catch (e) {
      myCustomPrintStatement('PublicTransportLayers: erreur chargement $e');
    }
  }

  /// Recalcule les Set polyline/marker selon le zoom + la sélection.
  ///
  /// Stratégie type IDF Mobilités :
  /// - Polylines : épaisses, semi-transparentes, filtrées par zoom
  ///   (`PublicTransportService.visibleLineNumbersForZoom`). Aller et retour
  ///   sont rendus comme 2 polylines distinctes (pas de fusion smart : trop
  ///   de risques de trous dans le rendu sur les lignes circulaires).
  /// - Stops : marker custom = carré arrondi couleur ligne avec numéro,
  ///   uniquement à zoom élevé (>= 13). Au-dessous, la carte serait illisible.
  /// - Sélection d'une ligne : seule cette ligne est rendue (polyline +
  ///   stops). Les autres sont totalement masquées pour focus immédiat.
  /// - Dedupe stops : un même arrêt servi par 2 directions n'est rendu
  ///   qu'une fois (lookup par position arrondie).
  Future<void> _rebuildPublicTransportLayers() async {
    final svc = PublicTransportService.instance;
    final selected = _publicSelectedLine;
    final selectedStop = _publicSelectedStop;
    final dpr =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;

    // Filtrage zoom-dependent (axes longs prioritaires à dezoom).
    // La ligne sélectionnée force sa visibilité même si le zoom l'aurait
    // exclue (UX : elle vient d'être tappée dans la liste).
    final visibleByZoom = svc.visibleLineNumbersForZoom(_publicMapZoom);
    Set<String> visible;
    if (selected != null) {
      // Mode "une ligne sélectionnée" : on n'affiche QUE cette ligne, les
      // autres sont totalement masquées (focus net, pas d'atténuation).
      visible = {selected};
    } else {
      visible = visibleByZoom;
    }

    final polylines = <Polyline>{};
    // Stops uniquement à zoom élevé (sinon clutter type IDF Mobilités sur
    // toute la métropole). À zoom 13 on voit le réseau, à 14+ les arrêts
    // se détaillent.
    final showStops = _publicMapZoom >= 14;

    // Liste plate avant clustering. Permet de dédupliquer un arrêt aller +
    // son équivalent retour qui sont à des positions légèrement décalées
    // (typiquement 15-30m, de chaque côté de la rue).
    final rawStops = <_RawStop>[];

    // Ordre d'itération : on dessine les lignes les MOINS importantes en
    // premier pour que les plus longues (= les axes) passent par-dessus
    // visuellement. Le marker d'un cluster prend la couleur/numéro de la
    // ligne la plus importante (cf. plus bas).
    final byImportance = svc.linesByImportance;
    final renderOrder = [
      for (var i = byImportance.length - 1; i >= 0; i--) byImportance[i],
    ];
    final orderedGroups = <TransportLineGroup>[
      for (final ln in renderOrder)
        if (svc.getLineGroup(ln) != null) svc.getLineGroup(ln)!,
    ];

    for (final group in orderedGroups) {
      if (!visible.contains(group.lineNumber)) continue;

      final meta = svc.metadataFor(group.lineNumber);
      final color =
          meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
      final isSelected = selected != null;
      const lineOpacity = 0.62;
      final width = isSelected ? 7 : 5;

      void addPolyline(TransportLine? line, String dir) {
        if (line == null || line.coordinates.length < 2) return;
        polylines.add(Polyline(
          polylineId: PolylineId('pt_${group.lineNumber}_$dir'),
          points: line.coordinates,
          color: color.withOpacity(lineOpacity),
          width: width,
          zIndex: isSelected ? 5 : 1,
          consumeTapEvents: false,
        ));
      }

      void collectStops(TransportLine? line) {
        if (line == null) return;
        if (!showStops) return;
        for (final stop in line.stops) {
          rawStops.add(_RawStop(
            position: stop.position,
            name: stop.name,
            lineNumber: group.lineNumber,
            color: color,
          ));
        }
      }

      addPolyline(group.aller, 'aller');
      addPolyline(group.retour, 'retour');
      collectStops(group.aller);
      collectStops(group.retour);
    }

    // Clustering proximité 35m : un arrêt servi en aller + retour (positions
    // souvent légèrement décalées des 2 côtés de la rue) ne donne qu'1 seul
    // marker. Si plusieurs lignes desservent le même point, on les agrège
    // sur le même cluster.
    final clusters = <_PublicStopAggregate>[];
    for (final raw in rawStops) {
      _PublicStopAggregate? match;
      for (final c in clusters) {
        if (_metersBetween(c.position, raw.position) <= 35.0) {
          match = c;
          break;
        }
      }
      if (match != null) {
        match.lines.add(raw.lineNumber);
        // Conserve le nom le plus informatif (priorité au plus long non-vide).
        if (raw.name.length > match.name.length) match.name = raw.name;
      } else {
        clusters.add(_PublicStopAggregate(
          key: _stopKey(raw.position),
          position: raw.position,
          name: raw.name,
          primaryLine: raw.lineNumber,
          primaryColor: raw.color,
        ));
      }
    }

    // Choix de la "ligne primaire" pour chaque cluster :
    // - Si une ligne est sélectionnée et passe par ce cluster → c'est elle.
    // - Sinon : la ligne la PLUS importante (= longueur totale max) qui
    //   passe par ce cluster. Cohérent avec l'ordre de dessin des polylines
    //   (la plus importante est posée en dernier → visible au-dessus).
    final importanceRank = <String, int>{
      for (var i = 0; i < byImportance.length; i++) byImportance[i]: i,
    };
    for (final c in clusters) {
      if (selected != null && c.lines.contains(selected)) {
        final selectedMeta = svc.metadataFor(selected);
        c.primaryLine = selected;
        c.primaryColor = selectedMeta != null
            ? Color(selectedMeta.colorValue)
            : const Color(0xFF1565C0);
        continue;
      }
      String? best;
      var bestRank = 1 << 30;
      for (final ln in c.lines) {
        final rank = importanceRank[ln] ?? (1 << 30);
        if (rank < bestRank) {
          bestRank = rank;
          best = ln;
        }
      }
      if (best != null && best != c.primaryLine) {
        final meta = svc.metadataFor(best);
        c.primaryLine = best;
        c.primaryColor = meta != null
            ? Color(meta.colorValue)
            : const Color(0xFF1565C0);
      }
    }

    final stopsByKey = <String, _PublicStopAggregate>{
      for (final c in clusters) c.key: c,
    };

    // Génération des markers custom pour les stops collectés.
    final markers = <Marker>{};
    for (final agg in stopsByKey.values) {
      final isStopSelected = selectedStop == agg.key;
      final icon = await StopMarkerFactory.create(
        label: agg.primaryLine,
        color: agg.primaryColor,
        devicePixelRatio: dpr,
        large: isStopSelected,
      );
      markers.add(Marker(
        markerId: MarkerId('stop_${agg.key}'),
        position: agg.position,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        zIndex: isStopSelected ? 100 : 10,
        consumeTapEvents: true,
        onTap: () => _onPublicStopTap(agg),
      ));
    }

    if (!mounted) return;
    setState(() {
      _publicTransportPolylines = polylines;
      _publicTransportMarkers = markers;
      _publicStopsByKey = stopsByKey;
    });
  }

  /// Tap sur un stop : on l'agrandit + on affiche la card flottante.
  void _onPublicStopTap(_PublicStopAggregate agg) {
    setState(() => _publicSelectedStop = agg.key);
    _rebuildPublicTransportLayers();
  }

  void _dismissPublicStopCard() {
    setState(() => _publicSelectedStop = null);
    _rebuildPublicTransportLayers();
  }

  static String _stopKey(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

  /// Distance Haversine en mètres entre 2 points. Utilisée pour dédupliquer
  /// les arrêts aller/retour d'une même ligne (souvent décalés 15-30m car
  /// posés de chaque côté d'une route à 2 voies).
  static double _metersBetween(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180.0;
    final dLng = (b.longitude - a.longitude) * 3.141592653589793 / 180.0;
    final lat1 = a.latitude * 3.141592653589793 / 180.0;
    final lat2 = b.latitude * 3.141592653589793 / 180.0;
    final h = (1 - cos(dLat)) / 2 +
        cos(lat1) * cos(lat2) * (1 - cos(dLng)) / 2;
    return 2 * r * asin(sqrt(h));
  }

  /// Reagit au déplacement de caméra : tracking de zoom pour le filtrage.
  /// Recompute les couches uniquement quand on franchit un seuil entier
  /// (évite les rebuilds frame-rate pendant le pinch).
  void _onPublicCameraMove(CameraPosition pos) {
    if (_homeMode != HomeMode.publicTransport) return;
    final newZoom = pos.zoom;
    if (newZoom.floor() != _publicMapZoom.floor()) {
      _publicMapZoom = newZoom;
      // Relayer le rebuild après la frame courante pour ne pas bloquer le
      // pan/zoom interaction (les rebuilds Bitmap async peuvent jitter).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _homeMode == HomeMode.publicTransport) {
          _rebuildPublicTransportLayers();
        }
      });
    } else {
      _publicMapZoom = newZoom;
    }
  }

  /// Zoom la caméra sur les bounds d'une ligne donnée (aller + retour).
  void _zoomToPublicLine(String lineNumber) {
    final group = PublicTransportService.instance.getLineGroup(lineNumber);
    if (group == null || _mapController == null) return;
    final pts = <LatLng>[
      ...?group.aller?.coordinates,
      ...?group.retour?.coordinates,
    ];
    if (pts.length < 2) return;
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
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
                // Logo Misy - grande taille (cliquable → misy.app)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://misy.app'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Image.asset(
                      MyImagesUrl.misyLogoRose,
                      height: 42,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Toggle Course / Transport en commun. Gardé visible
                // uniquement pour admin@misyapp.com tant que le mode public
                // n'est pas exposé à tous les utilisateurs.
                if (_isPublicModeAdmin) ...[
                  HomeModeToggle(
                    current: _homeMode,
                    onChanged: _setHomeMode,
                  ),
                  const SizedBox(height: 16),
                ],

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildScheduleOptions(),
                      const SizedBox(height: 16),
                      _buildLocationInputs(),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isSearching,
                        builder: (context, isSearching, _) {
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5357),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5357)
                                      .withOpacity(0.3),
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
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
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
  /// En-tête de section style Apple
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

      // Auth check : trajet planifié + utilisateur anonyme/absent → forcer login
      // Les params (pickup, destination, scheduledAt) sont persistés dans la
      // session invité pour être rejoués automatiquement après authentification.
      final auth = Provider.of<CustomAuthProvider>(context, listen: false);
      final fbUser = auth.currentUser;
      final isAnonymous = fbUser == null || fbUser.isAnonymous;
      if (tripProvider.rideScheduledTime != null && isAnonymous) {
        try {
          final svc = GuestStorageService();
          GuestSession? current = await svc.getGuestSession();
          current ??= GuestSession.create();
          await svc.updateBookingData(
            currentSession: current,
            bookingData: {
              'pickupLocation': tripProvider.pickLocation,
              'pickupAddress': tripProvider.pickLocation?['address'],
              'destinationLocation': tripProvider.dropLocation,
              'destinationAddress': tripProvider.dropLocation?['address'],
              'hasActiveBooking': true,
              'additionalData': {
                'scheduledAt': tripProvider.rideScheduledTime!.toIso8601String(),
              },
            },
          );
        } catch (e) {
          debugPrint('GuestStorage save failed: $e');
        }
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PhoneNumberScreen()),
          );
        }
        _isSearching.value = false;
        return;
      }

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

  void _showWebAuthDialog(WebAuthMode mode) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Auth",
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => WebAuthScreen(initialMode: mode),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }

  void _navigateToLogin() {
    if (kIsWeb) {
      _showWebAuthDialog(WebAuthMode.login);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _navigateToSignUp() {
    if (kIsWeb) {
      _showWebAuthDialog(WebAuthMode.signup);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
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

/// Stop "brut" en sortie d'un GeoJSON, avant clustering par proximité.
class _RawStop {
  final LatLng position;
  final String name;
  final String lineNumber;
  final Color color;

  const _RawStop({
    required this.position,
    required this.name,
    required this.lineNumber,
    required this.color,
  });
}

/// Aggregate utilisé pour dédupliquer les arrêts du réseau public sur la carte.
/// Plusieurs lignes peuvent desservir le même point — et l'aller / le retour
/// d'une même ligne sont souvent à 15-30m l'un de l'autre. On clusterise dans
/// un rayon de 35m (cf. `_metersBetween`) → 1 seul marker.
class _PublicStopAggregate {
  final String key;
  final LatLng position;
  String name;
  String primaryLine;
  Color primaryColor;
  final Set<String> lines = <String>{};

  _PublicStopAggregate({
    required this.key,
    required this.position,
    required this.name,
    required this.primaryLine,
    required this.primaryColor,
  });
}
