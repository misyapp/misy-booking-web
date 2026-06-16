import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rider_ride_hailing_app/widgets/booking_map.dart';
import 'package:rider_ride_hailing_app/widgets/center_pin.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';
import 'package:rider_ride_hailing_app/provider/geo_zone_provider.dart';
import 'package:rider_ride_hailing_app/services/geo_zone_service.dart';
import 'package:rider_ride_hailing_app/services/loom_network_service.dart';
import 'package:rider_ride_hailing_app/utils/gmap_flutter_adapter.dart' as gma;
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/modal/total_time_distance_modal.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/reverse_geocoder.dart';
import 'package:rider_ride_hailing_app/services/places_autocomplete_web.dart';
import 'package:rider_ride_hailing_app/services/route_service.dart';
import 'package:rider_ride_hailing_app/utils/deep_link_params.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart' show LoginPage;
import 'package:rider_ride_hailing_app/pages/auth_module/signup_screen.dart' show SignUpScreen;
import 'package:rider_ride_hailing_app/pages/auth_module/web_auth_screen.dart'
    show WebAuthMode, WebAuthScreen;
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/pages/account_web/account_shell_web.dart'
    show AccountSection;
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/pages/view_module/widgets/account_menu_web.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/phone_number_screen.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/services/guest_storage_service.dart';
import 'package:rider_ride_hailing_app/models/guest_session.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/request_for_ride.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/drive_on_way.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart' show TransportRoute, RouteStepType, TransportNode;
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
  fm.MapController? _mapController;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Focus nodes pour gérer le focus des champs
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  // Position par défaut: Antananarivo, Madagascar (Ankadifotsy)
  /// Position par défaut de la carte : la MAIRIE d'Antananarivo (Hôtel de
  /// Ville, Andohan'Analakely, avenue de l'Indépendance) — utilisée quand le
  /// GPS est absent/refusé OU que l'utilisateur est HORS des geozones Misy
  /// (visiteur à l'étranger qui pré-réserve : la carte doit montrer Tana,
  /// pas son salon à Paris). Demande produit du 05/06/2026.
  static const LatLng _defaultPosition = LatLng(-18.9086, 47.5270);

  // Bornage carte : zoom min/max + caméra limitée à ~40 km autour
  // d'Antananarivo (≈ ±0.36° lat, ±0.38° lng à cette latitude).
  static const double _minZoom = 11;
  static const double _maxZoom = 18;
  static final LatLngBounds _tanaBounds = LatLngBounds(
    southwest: const LatLng(-19.2707, 47.1496),
    northeast: const LatLng(-18.5499, 47.9114),
  );

  // Subscription pour les chauffeurs en ligne
  StreamSubscription<QuerySnapshot>? _driversSubscription;

  // Markers pour la carte (chauffeurs)
  Set<Marker> _driverMarkers = {};

  // Icônes réseau des chauffeurs par markerId (`driver_<uid>` → URL sprite du
  // type de véhicule), passées à gma.toFmMarkers. Map d'INSTANCE : un état
  // global se ferait purger par une autre instance d'écran (hot reload).
  final Map<String, String> _driverIconUrls = {};

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
  // Rôle admin transport (custom claim transport_admin). En taxibe, ouvre
  // l'accès à /admin et /iam depuis le menu utilisateur "Contribuer".
  bool _isTransportAdmin = false;

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

  // Planification de course: null = immédiate, sinon = date/heure planifiée
  DateTime? _scheduledDateTime;

  // Réservation à l'avance forcée (book.misy.app uniquement) : true quand la
  // zone du départ n'autorise pas les courses immédiates (hors Antananarivo)
  // ou via deep-link ?scheduledOnly=1 (tuile ville de province). Les chauffeurs
  // ne sont pas encore présents en instantané hors capitale.
  bool _deepLinkScheduledOnly = false;
  bool _scheduledOnlyZone = false;
  bool get _forceScheduledOnly => _deepLinkScheduledOnly || _scheduledOnlyZone;

  // Tuile ville (focus=1) → à l'ouverture, zoomer sur la ville + proposer ses
  // adresses connues (PopularDestinations centrées sur ses coordonnées).
  bool _focusCityOnOpen = false;
  double? _focusCityZoom;

  // Debounce timers
  Timer? _pickupDebounceTimer;
  Timer? _destinationDebounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 400);
  static const int _minCharsForSearch = 3;
  String? _lastPickupQuery;
  String? _lastDestinationQuery;

  // === Mode public (transport en commun) ===
  // Toggle Course / Transport en commun. La carte reste partagée — seules les
  // couches et le panneau gauche changent. La feature est ouverte à tous les
  // utilisateurs (loggés ou non) depuis 2026-05-28 — historiquement gated
  // derrière admin@misyapp.com, puis exposée publiquement après la migration
  // du subdomain taxibe.misy.app vers un redirect 301 → book.misy.app.
  HomeMode _homeMode = HomeMode.course;

  // Polylines + markers du réseau taxi-be pour l'overlay de la carte. Calculés
  // au load + à chaque palier de zoom franchi (filtrage type IDFM : moins de
  // lignes visibles à zoom faible).
  Set<Polyline> _publicTransportPolylines = {};
  Set<Marker> _publicTransportMarkers = {};
  // Billes d'arrêt = Circle Google Maps (rayon en MÈTRES) → géographiques,
  // donc elles scalent avec le zoom comme la polyline, au lieu d'un marker
  // bitmap à taille-écran fixe qui paraît énorme en vue réseau dézoomée.
  Set<Circle> _publicTransportCircles = {};
  bool _publicTransportLoaded = false;

  // Ligne sélectionnée dans la liste (= mise en évidence sur la carte). Null
  // = toutes les lignes (filtrées par zoom) affichées normalement.
  String? _publicSelectedLine;

  /// Pré-remplissage du calculateur TC via deep-link `?mode=transit&from*`/
  /// `to*` (widget de recherche de la section Transit du site) OU via la
  /// tuile « Transport en commun » du choix de véhicule. Consommés une fois
  /// par RouteCalculator (auto-recherche si les 2 sont présents).
  ({String label, LatLng pos})? _transitInitialOrigin;
  ({String label, LatLng pos})? _transitInitialDestination;

  /// Véhicules du choix de véhicule APRÈS application de la geozone du
  /// pickup : catégories désactivées filtrées (ex. Taxi/Bajaj hors zone),
  /// ordre/tarifs de zone appliqués — parité avec choose_vehicle_sheet de
  /// la riderapp. Vide tant que la zone n'a pas été résolue (fallback :
  /// vehicleListModal brut).
  List<VehicleModal> _zoneVehicles = const [];

  /// Résout la geozone du PICKUP puis filtre/tarife la liste de véhicules.
  /// À appeler à chaque entrée dans l'étape chooseVehicle (le pickup peut
  /// avoir changé). Cf. bug 05/06/2026 : le panel web ignorait les geozones
  /// (Taxi/Bajaj visibles à Tana, prix hors zone).
  Future<void> _refreshZoneVehicles(TripProvider tripProvider) async {
    try {
      double? parse(dynamic v) => double.tryParse('${v ?? ''}');
      final lat = parse(tripProvider.pickLocation?['lat']);
      final lng = parse(tripProvider.pickLocation?['lng']);
      if (lat == null || lng == null) return;
      final geo = Provider.of<GeoZoneProvider>(context, listen: false);
      await geo.updateCurrentZone(lat, lng, forceRefresh: true);
      if (!mounted) return;
      final filtered =
          geo.applyZonePricingToList(geo.applyCategoryConfig(vehicleListModal));
      setState(() {
        _zoneVehicles = filtered;
        // La liste affichée change → l'index de sélection ne vaut plus rien.
        _selectedVehicleIndex = -1;
        // book.misy.app : hors zone autorisant l'instant → réservation à l'avance.
        _scheduledOnlyZone = !geo.instantAllowedForCurrentZone;
      });
    } catch (e) {
      debugPrint('GeoZone refresh véhicules: $e');
      if (mounted) setState(() => _zoneVehicles = const []);
    }
  }

  /// True quand le mode TC a été ouvert depuis le flux Course (tuile du
  /// choix de véhicule) → le panel TC affiche un bouton « Revenir à la
  /// course » (l'état Course est intact, on y revient tel quel).
  bool _transitFromCourse = false;

  // Zoom courant de la carte. Suivi via [GoogleMap.onCameraMove] pour piloter
  // le filtrage zoom-dependent des lignes/stops.
  double _publicMapZoom = 15.5;

  // Dernière position connue de la caméra (target + zoom + bearing + tilt),
  // suivie via [GoogleMap.onCameraMove] sur les deux modes. Réappliquée au
  // switch dans [_setHomeMode] pour garantir que la carte reste figée — la
  // carte étant unique et partagée, on ne devrait pas observer de reset,
  // mais cette restauration agit en filet de sécurité contre toute
  // régression future qui forcerait un recentrage au mount du panel.
  fm.MapCamera? _lastKnownCamera;

  // Stops dédupliqués générés au dernier rebuild des couches. Permet de
  // retrouver les métadonnées à l'ouverture de la card de stop.
  Map<String, _PublicStopAggregate> _publicStopsByKey = {};

  // Stop sélectionné par l'utilisateur (clic sur un marker). Affiche la card
  // flottante + agrandit le marker correspondant.
  String? _publicSelectedStop;

  // Position pixel-écran de l'arrêt sélectionné, pour ancrer la card juste
  // au-dessus du marker (style IDFM). Mise à jour à chaque déplacement de
  // caméra. Null = card pas encore positionnée.
  Offset? _publicSelectedStopScreenPos;

  // Stop survolé par la souris (web desktop). Affiché plus grand pour
  // feedback hover style IDFM.
  String? _publicHoveredStop;

  // Itinéraire calculé sélectionné par l'utilisateur (Phase 2). Surligné
  // sur la carte par-dessus le réseau, avec marker O et D et auto-fit
  // de la caméra.
  Set<Polyline> _publicRoutePolylines = {};
  Set<Marker> _publicRouteMarkers = {};

  // Preview O→D : polyline pointillée grise + 2 markers, dessinée pendant
  // que l'utilisateur saisit son itinéraire et avant le calcul. Effacée
  // dès qu'un itinéraire est calculé/sélectionné.
  Set<Polyline> _publicPreviewPolyline = {};
  Set<Marker> _publicPreviewMarkers = {};
  /// Arrivée du trajet en cours de saisie. Non null = on MASQUE le réseau
  /// (toutes les lignes) pour ne montrer que départ + arrivée (cf. _buildMap).
  LatLng? _publicPreviewDest;

  /// Notifier pushé par le map.onTap en mode public, écouté par le
  /// calculateur d'itinéraire pour ajuster le dernier point posé (origin
  /// ou destination) selon où l'user clique.
  final ValueNotifier<LatLng?> _publicMapTapNotifier = ValueNotifier(null);

  /// Clusters d'arrêts pré-calculés UNE FOIS après le chargement du bundle.
  /// Évite de recommencer le O(N²) de clustering + snap à chaque rebuild
  /// (zoom, sélection). Les lignes desservant chaque cluster ne changent
  /// pas non plus pendant la session ; seule la ligne primaire varie selon
  /// la sélection en cours.
  List<_PublicStopAggregate> _baseClusters = const [];

  /// Tracés "faisceau-ready" de la VUE RÉSEAU, précalculés une fois à
  /// partir de [_mergedRuns] : chaque pièce (tronc/branches) est densifiée
  /// et annotée par point d'un vecteur d'offset latéral unitaire × slot.
  /// Au rebuild, l'offset réel = vecteur × largeur de brin au zoom courant
  /// → les lignes co-localisées s'écartent en brins côte à côte, en restant
  /// des polylignes CONTINUES (aucun trou). Vide → fallback tracé brut.
  ///
  /// Deux sources possibles (cf. [_loadPublicTransportLayers]) :
  /// - [_precomputeStrandRuns] : heuristique runtime (slots -1/0/+1, ≤ 3
  ///   brins) — pièces marquées `k: 0` (comportement historique) ;
  /// - [_populateStrandRunsFromLoom] (flag LOOM_NETWORK) : faisceaux LOOM
  ///   pré-calculés au build — `k` = densité du corridor (jusqu'à ~26
  ///   lignes côte à côte, brins amincis au-delà de
  ///   [LoomNetworkService.denseK]).
  Map<String,
      ({
        List<({int k, List<_StrandPt> pts})> trunk,
        List<({int k, List<_StrandPt> pts})> allerSolo,
        List<({int k, List<_StrandPt> pts})> retourSolo
      })> _strandRuns = const {};

  /// True quand [_strandRuns] vient des faisceaux LOOM (slots jusqu'à
  /// ±12,5) : au dézoom squelette les offsets sont neutralisés (cf.
  /// [_rebuildPublicTransportLayers]).
  bool _strandsFromLoom = false;

  /// Découpage aller/retour de CHAQUE ligne pour la VUE RÉSEAU, précalculé une
  /// fois par [_precomputeMergedLines] (statique, ≠ zoom). Par ligne :
  /// - `trunk`      : portions où aller≈retour (même chaussée) → 1 tronc large ;
  /// - `allerSolo`  : portions de l'aller à sens unique (branches fines) ;
  /// - `retourSolo` : portions du retour à sens unique (branches fines).
  /// Le tronc reprend la géométrie de l'aller → aucun offset, aucune médiane.
  Map<String,
          ({
            List<List<LatLng>> trunk,
            List<List<LatLng>> allerSolo,
            List<List<LatLng>> retourSolo
          })> _mergedRuns =
      const {};

  /// Widgets d'icônes des markers TRANSIT (badges circulaires d'arrêts,
  /// capsules de correspondance, terminus), par markerId. L'adaptateur
  /// flutter_map ne peut PAS lire les BitmapDescriptor de google_maps —
  /// tout marker sans entrée ici (ni iconUrl) tombe dans le fallback point
  /// bleu (cf. gma.toFmMarkers). Rempli par _rebuildPublicTransportLayers.
  final Map<String, Widget> _publicMarkerWidgets = {};

  // Cache des coordonnées écran de chaque stop visible. Recalculé à chaque
  // onCameraIdle via une interpolation linéaire depuis getVisibleRegion
  // (rapide, sync sur N stops). Utilisé par la détection de hover pour
  // trouver le stop le plus proche du curseur.
  final Map<String, Offset> _publicStopScreenPositions = {};
  Size _publicMapAreaSize = Size.zero;

  // ─── Pin central (mode Course) : bonhomme posé au centre de la carte ───
  // L'utilisateur tient la carte (pointer down → bras levé).
  bool _pinGrabbed = false;
  // Le point sous le pin est dans une geozone couverte (sinon « zone non
  // desservie » + boutons carte désactivés).
  bool _pinZoneCovered = true;
  // Settle de fin de mouvement (drag, molette, pinch) → reload chauffeurs.
  Timer? _pinIdleDebounce;
  // Dernier point traité au settle (seuil anti-bruit ~5 m).
  ll.LatLng? _lastPinSettle;
  // Sélection au pin en cours : null = aucune, true = prise en charge,
  // false = dépose. L'utilisateur déplace la carte librement puis valide
  // via le bouton flottant « Confirmer le lieu… ».
  bool? _pinSelectingPickup;
  // Garde anti-réponses croisées de l'aperçu d'adresse (Nominatim async).
  int _pinPreviewSeq = 0;

  @override
  void initState() {
    super.initState();
    _mapController = fm.MapController();
    _setupFocusListeners();
    _initializeAndSubscribe();
    _readUrlParameters();
    _restorePendingScheduledBooking();
    _createCustomMarkers();
    _checkTransportEditorRole();
    _initSilentGeolocation();

    // Écouter les changements de TripProvider pour reset l'UI après course
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      _lastTripStep = tripProvider.currentStep;
      tripProvider.addListener(_onTripProviderChanged);
    });
  }

  Future<void> _checkTransportEditorRole() async {
    final ok = await AdminAuthService.instance
        .isTransportEditor(forceRefresh: true);
    if (mounted && ok != _isTransportEditor) {
      setState(() => _isTransportEditor = ok);
    }
    final admin = await AdminAuthService.instance.isTransportAdmin();
    if (mounted && admin != _isTransportAdmin) {
      setState(() => _isTransportAdmin = admin);
    }
  }

  /// Centrage initial silencieux : si la permission GPS est DÉJÀ accordée
  /// (aucun popup — on ne passe pas par `getCurrentLocation()` qui fait
  /// `requestPermission`) et que la position tombe dans une geozone couverte
  /// (Madagascar), on centre la carte dessus + recharge les chauffeurs.
  /// Sinon la carte reste sur Antananarivo (`_defaultPosition`).
  Future<void> _initSilentGeolocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final zone =
          await GeoZoneService.getZoneForLocation(pos.latitude, pos.longitude);
      if (zone == null || !mounted) return;
      _mapController?.move(ll.LatLng(pos.latitude, pos.longitude), 15);
      _reloadDriversNearPosition(LatLng(pos.latitude, pos.longitude));
      _lastPinSettle = ll.LatLng(pos.latitude, pos.longitude);
      if (!_pinZoneCovered) setState(() => _pinZoneCovered = true);
    } catch (e) {
      debugPrint('Géoloc silencieuse ignorée: $e');
    }
  }

  /// Relâche la prise (pointer up/cancel) : le bras du bonhomme redescend et
  /// on traite le point sous le pin (le debounce de `onPositionChanged`
  /// couvre l'inertie du fling et les mouvements sans pointer — molette).
  void _releasePinGrab() {
    if (!_pinGrabbed) return;
    setState(() => _pinGrabbed = false);
    _schedulePinSettle();
  }

  /// (Re)lance le debounce de settle — appelé au relâchement et à chaque
  /// mouvement de caméra gestuel en mode Course.
  void _schedulePinSettle() {
    _pinIdleDebounce?.cancel();
    _pinIdleDebounce = Timer(const Duration(milliseconds: 350), _onPinSettle);
  }

  /// Settle du pin central : fin de mouvement carte en mode Course (relâché
  /// du drag, fin de molette/pinch). Recharge les 8 chauffeurs les plus
  /// proches du point sous le pin et met à jour la couverture geozone.
  Future<void> _onPinSettle() async {
    if (_homeMode != HomeMode.course || _mapController == null) return;
    final center = _mapController!.camera.center;

    // Seuil anti-bruit : ignorer un settle à <5 m du précédent.
    if (_lastPinSettle != null &&
        const ll.Distance().as(ll.LengthUnit.Meter, _lastPinSettle!, center) <
            5) {
      return;
    }
    _lastPinSettle = center;

    _reloadDriversNearPosition(LatLng(center.latitude, center.longitude));

    // Sélection en cours : aperçu live de l'adresse sous le pin dans le
    // champ correspondant (reverse Nominatim uniquement — haute fréquence,
    // jamais Google). La validation reste sur « Confirmer le lieu… ».
    final selecting = _pinSelectingPickup;
    if (selecting != null) {
      final seq = ++_pinPreviewSeq;
      ReverseGeocoder.instance
          .reverseGeocodeNominatim(
              latitude: center.latitude, longitude: center.longitude)
          .then((address) {
        if (!mounted ||
            seq != _pinPreviewSeq ||
            _pinSelectingPickup != selecting) {
          return;
        }
        (selecting ? _pickupController : _destinationController).text =
            address;
      });
    }

    final zone = await GeoZoneService.getZoneForLocation(
        center.latitude, center.longitude);
    final covered = zone != null;
    if (mounted && covered != _pinZoneCovered) {
      setState(() => _pinZoneCovered = covered);
    }
  }

  /// Callback quand TripProvider change (pour gérer le reset après course terminée)
  /// Dernière étape Course observée — pour ne réagir qu'aux TRANSITIONS.
  CustomTripType? _lastTripStep;

  void _onTripProviderChanged() {
    if (!mounted) return;

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final step = tripProvider.currentStep;

    // Reset de l'UI UNIQUEMENT quand on REVIENT à l'écran initial depuis une
    // autre étape (fin/annulation de course). ⚠️ currentStep DÉMARRE déjà à
    // setYourDestination : sans ce test de transition, n'importe quel
    // notifyListeners du boot (auth web, chargement véhicules…) effaçait les
    // champs pré-remplis par le deep-link beta.misy.app avant l'auto-search
    // (bug « les points départ/arrivée se perdent », 05/06/2026).
    final cameBackToStart = step == CustomTripType.setYourDestination &&
        _lastTripStep != null &&
        _lastTripStep != CustomTripType.setYourDestination;
    _lastTripStep = step;
    if (!cameBackToStart) return;

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
  ///
  /// Source des params : `DeepLinkParams.params`, capturé au tout début de main()
  /// AVANT que `usePathUrlStrategy()` + le router Flutter ne nettoient l'URL.
  /// Au moment où cet initState tourne, `window.location.href` et `Uri.base`
  /// ont déjà été ramenés à `https://book.misy.app/` (sans query-string).
  ///
  /// Deux formats supportés :
  ///  - **Query-string** (path-strategy, format envoyé par misy.app) :
  ///    `https://book.misy.app/?pickup=X&pickupLat=Y...`
  ///  - **Fragment** (legacy hash-strategy) : `https://book.misy.app/#/?pickup=X...`
  void _readUrlParameters() {
    if (!kIsWeb) return;

    try {
      print('🔍 _readUrlParameters appelée');
      print('🔍 URL au moment du initState: ${html.window.location.href}');

      // 1. Source primaire : params capturés au boot dans main().
      Map<String, String> params = Map<String, String>.from(DeepLinkParams.params);
      print('🔍 DeepLinkParams: $params');

      // 2. Fallback : si rien n'a été capturé au boot, tenter les query params
      // courants (utile pour les navigations internes qui posent des params).
      if (params.isEmpty) {
        final uri = Uri.parse(html.window.location.href);
        params = Map<String, String>.from(uri.queryParameters);
        if (params.isEmpty) {
          // 3. Dernier fallback : params dans le fragment (legacy hash-strategy).
          final fragment = uri.fragment;
          print('🔍 Fragment (fallback): $fragment');
          if (fragment.contains('?')) {
            final queryString = fragment.split('?').last;
            params = Uri.splitQueryString(queryString);
          }
        }
      }

      if (params.isNotEmpty) {
        // Langue du visiteur transmise par le site vitrine (?lang=it|pl|de|
        // mg|fr|en) : l'app s'ouvre dans la langue de la page d'origine.
        // setLocale persiste le choix (SharedPreferences misy_locale).
        final langParam = params['lang'];
        if (langParam != null) {
          for (final l in AppLocale.values) {
            if (l.name == langParam) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Provider.of<LocaleProvider>(context, listen: false)
                      .setLocale(l);
                }
              });
              break;
            }
          }
        }

        // Deep-link "Transport en commun" depuis le site (tuile "Découvrir
        // le transport en commun" → book.misy.app/?mode=transit) : bascule
        // direct dans l'onglet Transport au montage du home.
        final mode = params['mode'];
        if (mode == 'transit' || mode == 'transport') {
          // Pré-remplissage du calculateur depuis le widget de recherche du
          // site (TransitSection beta/misy.app) : from/to + coords. Les
          // params `from*`/`to*` sont DISTINCTS de pickup/destination pour
          // ne pas déclencher l'auto-search du mode Course plus bas.
          final fromLat = double.tryParse(params['fromLat'] ?? '');
          final fromLng = double.tryParse(params['fromLng'] ?? '');
          final toLat = double.tryParse(params['toLat'] ?? '');
          final toLng = double.tryParse(params['toLng'] ?? '');
          if (fromLat != null && fromLng != null) {
            _transitInitialOrigin = (
              label: params['from'] ?? '$fromLat, $fromLng',
              pos: LatLng(fromLat, fromLng),
            );
          }
          if (toLat != null && toLng != null) {
            _transitInitialDestination = (
              label: params['to'] ?? '$toLat, $toLng',
              pos: LatLng(toLat, toLng),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _setHomeMode(HomeMode.publicTransport);
          });
        }

        // Deep-link auth (CTA "Connexion"/"S'inscrire" du header beta.misy.app :
        // book.misy.app/?login=1 ou ?signup=1) : ouvrir la carte WebAuthScreen
        // dans le bon mode par-dessus la home. Remplace l'ancien push direct de
        // PhoneNumberScreen depuis le splash (écran mobile brut, hors charte).
        if (params['login'] == '1' || params['signup'] == '1') {
          final authMode = params['signup'] == '1'
              ? WebAuthMode.signup
              : WebAuthMode.login;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Ne rien ouvrir si un vrai compte est déjà connecté (lien
            // re-visité / rechargement) — l'anonyme du mode invité compte
            // comme « non connecté ».
            final user = FirebaseAuth.instance.currentUser;
            if (mounted && (user == null || user.isAnonymous)) {
              _showWebAuthDialog(authMode);
            }
          });
        }

        final pickup = params['pickup'];
        final destination = params['destination'];
        final pickupLat = params['pickupLat'];
        final pickupLng = params['pickupLng'];
        final destLat = params['destLat'];
        final destLng = params['destLng'];
        final scheduledAtStr = params['scheduledAt'];

        // Réservation à l'avance imposée (tuile ville de province : ?scheduledOnly=1).
        if (params['scheduledOnly'] == '1') {
          _deepLinkScheduledOnly = true;
        }
        // Tuile ville : ouvrir zoomé sur la ville + adresses connues.
        if (params['focus'] == '1') {
          _focusCityOnOpen = true;
          _focusCityZoom = double.tryParse(params['zoom'] ?? '');
        }

        print('📍 URL params: pickup=$pickup, destination=$destination, scheduledAt=$scheduledAtStr, scheduledOnly=$_deepLinkScheduledOnly, focus=$_focusCityOnOpen');

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
            // Tuile ville (focus=1) : pickup ancré sur la ville, destination
            // vide → zoomer sur la ville et orienter la recherche de destination
            // vers ses adresses locales (biais autocomplete Google Places).
            if (_focusCityOnOpen &&
                _pickupLocation['lat'] != null &&
                _destinationLocation['lat'] == null) {
              final cityLatLng = ll.LatLng(
                (_pickupLocation['lat'] as num).toDouble(),
                (_pickupLocation['lng'] as num).toDouble(),
              );
              _mapController?.move(cityLatLng, _focusCityZoom ?? 12.5);
              PlacesAutocompleteWeb.setLocationBias(
                cityLatLng.latitude,
                cityLatLng.longitude,
              );
              _destinationFocusNode.requestFocus();
              return;
            }
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

  /// Reconstruit les markers avec les positions actuelles.
  ///
  /// Côté flutter_map le `BitmapDescriptor` Google est opaque : l'icône réelle
  /// du type de véhicule est déclarée via [_driverIconUrls] (id préfixé
  /// `driver_`), passée à `gma.toFmMarkers` qui rend l'image réseau avec le
  /// heading conservé.
  Future<void> _rebuildDriverMarkers() async {
    if (!mounted) return;

    // Purge les icônes des chauffeurs disparus du pool.
    _driverIconUrls.removeWhere((id, _) =>
        !_currentDriverPositions.containsKey(id.substring('driver_'.length)));

    Set<Marker> newMarkers = {};

    for (final entry in _currentDriverPositions.entries) {
      final driverId = entry.key;
      final position = entry.value;
      final driver = _driversData[driverId];

      if (driver == null) continue;

      final heading = _currentDriverHeadings[driverId] ?? 0.0;
      final markerUrl = _resolveDriverMarkerUrl(driver);
      if (markerUrl != null && markerUrl.isNotEmpty) {
        _driverIconUrls['driver_$driverId'] = markerUrl;
      } else {
        // Icône non résolue → pin taxi générique. Tracer le coupable :
        // vehicleType absent du doc ou inconnu de vehicleMap (type supprimé,
        // ou course au démarrage si vehicleMap n'est pas encore chargée).
        debugPrint('🚗 ⚠️ icône non résolue pour $driverId : '
            'vehicleType=${driver.vehicleType}, '
            'vehicleMap=${vehicleMap.length} entrées');
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId('driver_$driverId'),
          position: position,
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

  /// Résout l'URL du sprite du type de véhicule d'un chauffeur :
  /// 1) `vehicleType` (id) → vehicleMap (chemin nominal) ;
  /// 2) secours données corrompues (vehicleType null après un changement de
  ///    véhicule driverapp qui écrit un objet incomplet) : id puis nom depuis
  ///    le `vehicleDetails.vehicleType` embarqué.
  String? _resolveDriverMarkerUrl(DriverModal driver) {
    final byId = vehicleMap[driver.vehicleType]?.marker;
    if (byId != null && byId.isNotEmpty) return byId;

    final embedded = driver.vehicleData?.vehicleType;
    if (embedded == null) return null;
    final embeddedId = embedded['id']?.toString();
    final byEmbeddedId =
        embeddedId != null ? vehicleMap[embeddedId]?.marker : null;
    if (byEmbeddedId != null && byEmbeddedId.isNotEmpty) return byEmbeddedId;

    final name = embedded['name']?.toString().trim().toLowerCase();
    if (name == null || name.isEmpty) return null;
    for (final v in vehicleMap.values) {
      if (v.name.trim().toLowerCase() == name && v.marker.isNotEmpty) {
        return v.marker;
      }
    }
    return null;
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

        _mapController?.move(gma.toLL(pickupPosition), 14);

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
    _pinIdleDebounce?.cancel();
    _mapController?.dispose();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Le bonhomme (pin central) ne vit que pendant la RECHERCHE d'adresses :
    // dès qu'un trajet est affiché (choix véhicule, confirmation, suivi…),
    // il disparaît — demande explicite 05/06/2026.
    final tripStep = context
        .select<TripProvider, CustomTripType?>((p) => p.currentStep);
    final pinVisible = _homeMode == HomeMode.course &&
        (tripStep == null ||
            tripStep == CustomTripType.setYourDestination ||
            tripStep == CustomTripType.choosePickupDropLocation);
    return Scaffold(
      body: LayoutBuilder(builder: (ctx, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_publicMapAreaSize != size) {
          // Schedule pour que setState ne se déclenche pas pendant le build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _publicMapAreaSize = size;
            _refreshPublicStopScreenCache();
          });
        }
        return Stack(
        children: [
          // Carte pleine page. Le Listener observe (sans consommer) les
          // pointeurs qui atteignent la carte : il pilote l'animation du pin
          // central (la souris « attrape la main » du bonhomme au drag).
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (pinVisible && !_pinGrabbed) {
                setState(() => _pinGrabbed = true);
              }
            },
            onPointerUp: (_) => _releasePinGrab(),
            onPointerCancel: (_) => _releasePinGrab(),
            child: _buildMap(),
          ),

          // Pin central : bonhomme bleu posé au centre de la zone visible,
          // UNIQUEMENT pendant la recherche d'adresses (cf. pinVisible).
          // La pointe = le point GPS visé (camera.center). IgnorePointer :
          // ne bloque jamais les gestes.
          if (pinVisible)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: CenterPin(
                    grabbed: _pinGrabbed,
                    covered: _pinZoneCovered,
                  ),
                ),
              ),
            ),

          // Sélection au pin en cours : CTA flottant « Confirmer le lieu… ».
          // L'utilisateur décale la carte autant qu'il veut, puis valide.
          if (_homeMode == HomeMode.course && _pinSelectingPickup != null)
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(child: _buildPinConfirmBar()),
            ),

          // Détection de hover en mode public : MouseRegion translucent qui
          // ne bloque pas les pointer events (clicks Google Maps OK), mais
          // capture la position du curseur pour grossir la bille survolée
          // (+ mini-carte). Curseur main quand un arrêt est sous la souris.
          if (_homeMode == HomeMode.publicTransport)
            Positioned.fill(
              child: MouseRegion(
                opaque: false,
                cursor: _publicHoveredStop != null
                    ? SystemMouseCursors.click
                    : MouseCursor.defer,
                onHover: (event) =>
                    _handlePublicMapHover(event.localPosition),
                onExit: (_) => _clearPublicMapHover(),
              ),
            ),

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
          // Ancrée au pixel-écran du marker via _publicSelectedStopScreenPos
          // (mise à jour à chaque mouvement de caméra).
          if (_homeMode == HomeMode.publicTransport &&
              _publicSelectedStop != null &&
              _publicStopsByKey[_publicSelectedStop] != null)
            Builder(
              builder: (ctx) {
                final agg = _publicStopsByKey[_publicSelectedStop]!;
                return StopCard(
                  stopName: agg.name,
                  position: agg.position,
                  lineNumbers: agg.lines.toList()..sort(),
                  screenAnchor: _publicSelectedStopScreenPos,
                  screenSize: size,
                  onClose: _dismissPublicStopCard,
                  onLineTap: (lineNumber) {
                    _onPublicLineSelected(lineNumber);
                  },
                );
              },
            ),

          // Mini-carte de SURVOL : aperçu compact (nom + pilules lignes)
          // flotté au-dessus de la bille survolée, via le cache pixel-écran
          // du hover. Non interactive (IgnorePointer) — la fiche complète
          // ci-dessus ne s'ouvre qu'au clic.
          if (_homeMode == HomeMode.publicTransport &&
              _publicHoveredStop != null &&
              _publicHoveredStop != _publicSelectedStop &&
              _publicStopsByKey[_publicHoveredStop] != null &&
              _publicStopScreenPositions[_publicHoveredStop] != null)
            Builder(
              builder: (ctx) {
                final agg = _publicStopsByKey[_publicHoveredStop]!;
                final anchor =
                    _publicStopScreenPositions[_publicHoveredStop]!;
                return Positioned(
                  left: (anchor.dx - StopMiniCard.width / 2)
                      .clamp(8.0, size.width - StopMiniCard.width - 8.0),
                  bottom: (size.height - anchor.dy + 10)
                      .clamp(8.0, size.height - 8.0),
                  width: StopMiniCard.width,
                  child: IgnorePointer(
                    child: StopMiniCard(
                      stopName: agg.name,
                      lineNumbers: agg.lines.toList()..sort(),
                    ),
                  ),
                );
              },
            ),
        ],
      );
      }),
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

        // HORS GEOZONE Misy (dashboard) → on ne recentre PAS sur le GPS de
        // l'utilisateur (visiteur à l'étranger) : cap sur la mairie
        // d'Antananarivo, cœur de la couverture. (Pas de return : le reset
        // de _isLocating est en bas, hors finally.)
        final zone = await GeoZoneService.getZoneForLocation(
            latLng.latitude, latLng.longitude);
        if (zone == null && mounted) {
          _mapController?.move(gma.toLL(_defaultPosition), 15);
          _reloadDriversNearPosition(_defaultPosition);
        } else if (mounted) {
          _mapController?.move(gma.toLL(latLng), 15);

          // Recharger les chauffeurs proches de cette position
          _reloadDriversNearPosition(latLng);
        }
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
          SnackBar(
            content: Text(TransitStrings.t('web.errLocation',
                Provider.of<LocaleProvider>(context, listen: false).locale)),
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
    // Course (les 2 modes sont isolés).
    if (_homeMode == HomeMode.publicTransport) {
      return TransportPublicPanel(
        mode: _homeMode,
        onModeChanged: _setHomeMode,
        selectedLine: _publicSelectedLine,
        onLineSelected: _onPublicLineSelected,
        onRouteSelected: _onPublicRouteSelected,
        onPointsChanged: _onPublicPointsChanged,
        mapTapNotifier: _publicMapTapNotifier,
        onRequestRideForWalk: _onRequestRideForWalk,
        initialOrigin: _transitInitialOrigin,
        initialDestination: _transitInitialDestination,
        onReturnToCourse:
            _transitFromCourse ? () => _setHomeMode(HomeMode.course) : null,
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
  /// True si le point est dans le Grand Tana (rayon ~35 km autour du
  /// centre-ville) — zone couverte par le réseau taxi-be.
  static bool _isTanaRegion(double lat, double lng) =>
      _metersBetween(LatLng(lat, lng), const LatLng(-18.8792, 47.5079)) <
      35000;

  /// Ouvre le mode Transport en commun pré-rempli avec le trajet de la
  /// course en cours → la recherche d'itinéraire se lance toute seule
  /// (même plomberie que le deep-link `?mode=transit&from*/to*`). L'état
  /// Course n'est PAS touché : le bouton « Revenir à la course » du panel
  /// TC ramène au choix de véhicule tel quel.
  void _openTransitFromCourse(TripProvider tripProvider) {
    double? parse(dynamic v) => double.tryParse('${v ?? ''}');
    final pick = tripProvider.pickLocation;
    final drop = tripProvider.dropLocation;
    final pLat = parse(pick?['lat']), pLng = parse(pick?['lng']);
    final dLat = parse(drop?['lat']), dLng = parse(drop?['lng']);
    if (pLat == null || pLng == null || dLat == null || dLng == null) return;
    String label(Map? loc, String fallback) {
      final a = loc?['address']?.toString() ?? '';
      return a.isEmpty ? fallback : a.split(',').first.trim();
    }

    setState(() {
      _transitInitialOrigin = (
        label: label(pick, '$pLat, $pLng'),
        pos: LatLng(pLat, pLng),
      );
      _transitInitialDestination = (
        label: label(drop, '$dLat, $dLng'),
        pos: LatLng(dLat, dLng),
      );
      _transitFromCourse = true; // le reset de _setHomeMode ne joue qu'en SORTIE de TC
    });
    _setHomeMode(HomeMode.publicTransport);
  }

  /// Tuile « Transport en commun » insérée en 2e position du choix de
  /// véhicule quand le trajet est dans le Grand Tana. Code couleur indigo
  /// (univers TC, distinct du corail courses — même convention que le site).
  Widget _buildTransitOptionTile(TripProvider tripProvider) {
    const indigo = Color(0xFF4F46E5);
    final locale = context.watch<LocaleProvider>().locale;
    return InkWell(
      onTap: () => _openTransitFromCourse(tripProvider),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: indigo.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: indigo.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: indigo.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_bus_filled, color: indigo),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TransitStrings.t('mode.public', locale),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    TransitStrings.t('web.transitTileSub', locale),
                    style: const TextStyle(fontSize: 12, color: indigo),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: indigo),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSelectionPanel(TripProvider tripProvider) {
    final locale = context.watch<LocaleProvider>().locale;
    // Tuile TC proposée seulement si départ ET arrivée sont dans la zone
    // couverte par le réseau taxi-be (Grand Tana).
    double? parse(dynamic v) => double.tryParse('${v ?? ''}');
    final pLat = parse(tripProvider.pickLocation?['lat']);
    final pLng = parse(tripProvider.pickLocation?['lng']);
    final dLat = parse(tripProvider.dropLocation?['lat']);
    final dLng = parse(tripProvider.dropLocation?['lng']);
    final transitEligible = pLat != null &&
        pLng != null &&
        dLat != null &&
        dLng != null &&
        _isTanaRegion(pLat, pLng) &&
        _isTanaRegion(dLat, dLng);
    // Liste zonée (catégories filtrées + tarifs de zone) ; fallback brut
    // tant que la zone n'est pas résolue.
    final zonedVehicles =
        _zoneVehicles.isNotEmpty ? _zoneVehicles : vehicleListModal;
    // Position d'insertion : 2e (index 1), ou 1re si la liste est vide.
    final transitIdx = zonedVehicles.isEmpty ? 0 : 1;
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
                      Expanded(
                        child: Text(
                          TransitStrings.t('web.chooseVehicle', locale),
                          style: const TextStyle(
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

                  // Liste des véhicules (+ tuile Transport en commun en 2e
                  // position quand le trajet est dans le Grand Tana)
                  Expanded(
                    child: ListView.builder(
                      itemCount:
                          zonedVehicles.length + (transitEligible ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (transitEligible && index == transitIdx) {
                          return _buildTransitOptionTile(tripProvider);
                        }
                        final vIndex = transitEligible && index > transitIdx
                            ? index - 1
                            : index;
                        final vehicle = zonedVehicles[vIndex];
                        if (!vehicle.active) return const SizedBox.shrink();

                        final isSelected = _selectedVehicleIndex == vIndex;
                        final price = tripProvider.calculatePrice(vehicle);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedVehicleIndex = vIndex;
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
                      child: Text(
                        TransitStrings.t('web.order', locale),
                        style: const TextStyle(
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

    // book.misy.app : hors Antananarivo, l'instant est interdit (chauffeurs pas
    // encore présents) → imposer le choix d'un créneau avant de continuer.
    if (_forceScheduledOnly && _scheduledDateTime == null) {
      final locale =
          Provider.of<LocaleProvider>(context, listen: false).locale;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(TransitStrings.t('web.scheduledOnlyNotice', locale)),
      ));
      _showSchedulePicker();
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
    _mapController?.move(gma.toLL(destination), 18.0);
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
          SnackBar(
              content: Text(TransitStrings.t('web.errCreateRide',
                  Provider.of<LocaleProvider>(context, listen: false).locale))),
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

  /// Padding pour `fitCamera` des itinéraires : réserve la largeur du panneau
  /// gauche (course / choix véhicule) afin que la route tienne dans la zone
  /// VISIBLE de la carte, pas sous le panneau. Sur écran étroit (mobile,
  /// panneau en bas), padding symétrique. Même logique que _zoomToPublicLine.
  EdgeInsets _routeFitPadding() {
    const panelRightEdge = 16.0 + 320.0; // inset gauche + largeur du panneau
    final screenW = MediaQuery.of(context).size.width;
    final wideEnough = screenW - panelRightEdge > 360;
    return wideEnough
        ? const EdgeInsets.fromLTRB(panelRightEdge + 64, 80, 48, 80)
        : const EdgeInsets.all(80);
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

    _mapController?.fitCamera(
      fm.CameraFit.bounds(
        bounds: fm.LatLngBounds(
          ll.LatLng(maxLat, maxLng),
          ll.LatLng(minLat, minLng),
        ),
        padding: _routeFitPadding(),
      ),
    );
  }

  Widget _buildProfileButton() {
    final locale = context.watch<LocaleProvider>().locale;
    // En mode Transport en commun, expose le menu "Contribuer" (raccourcis
    // éditeur / admin pour les claims correspondants, sans S'inscrire — pas
    // de notion de compte rider à ce moment-là).
    if (_homeMode == HomeMode.publicTransport) {
      return _buildTaxibeContributeButton();
    }
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
                  child: Text(
                    TransitStrings.t('web.signIn', locale),
                    style: const TextStyle(
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
                  child: Text(TransitStrings.t('web.signUp', locale)),
                ),
              ],
            );
          }

          return InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showAccountMenu(
              context,
              user: user,
              locale: locale,
              walletEnabled:
                  FeatureToggleService.instance.isDigitalWalletEnabled(),
              isEditor: _isTransportEditor,
              onActivity: () => Navigator.of(context)
                  .pushNamed('/account', arguments: AccountSection.trips),
              onWallet: () => Navigator.of(context)
                  .pushNamed('/account', arguments: AccountSection.wallet),
              onProfile: () => Navigator.of(context)
                  .pushNamed('/account', arguments: AccountSection.profile),
              onEditor: () =>
                  Navigator.of(context).pushNamed('/transport-editor'),
              onSettings: () => showAccountSettingsSheet(context, locale),
              onLogout: () =>
                  Provider.of<CustomAuthProvider>(context, listen: false)
                      .logout(context),
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
          );
        },
      ),
    );
  }

  /// Bouton "Contribuer" affiché en haut à droite en mode Transport en
  /// commun. Historiquement dédié à taxibe.misy.app, partagé maintenant
  /// avec book.misy.app après la migration de la feature transport.
  ///
  /// Logged-out : entrée pour les contributeurs terrain (signaler une
  /// erreur, créer une ligne manquante, etc.). Tap → /transport-login.
  ///
  /// Logged-in : popup avec raccourcis /editor (si claim editor) et
  /// /admin (si claim admin) + déconnexion. Pas de "Mes trajets" ni
  /// profil (UI booking).
  Widget _buildTaxibeContributeButton() {
    final locale = context.watch<LocaleProvider>().locale;
    return Positioned(
      top: 16,
      right: 16,
      child: ValueListenableBuilder(
        valueListenable: userData,
        builder: (context, user, _) {
          final isLoggedIn = user != null;
          if (!isLoggedIn) {
            return Tooltip(
              message: 'Signaler une erreur, contribuer à une ligne…',
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/login'),
                icon: const Icon(Icons.add_road,
                    size: 18, color: Colors.black87),
                label: const Text(
                  'Contribuer',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            );
          }

          // Logged-in : popup avec raccourcis editor/admin selon claims.
          return PopupMenuButton<String>(
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            tooltip: 'Espace contributeur',
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: user.profileImage.isNotEmpty
                    ? NetworkImage(user.profileImage)
                    : null,
                child: user.profileImage.isEmpty
                    ? Icon(Icons.person,
                        color: Colors.grey.shade600, size: 20)
                    : null,
              ),
            ),
            onSelected: (value) {
              if (value == 'editor') {
                Navigator.of(context).pushNamed('/editor');
              } else if (value == 'admin') {
                Navigator.of(context).pushNamed('/admin');
              } else if (value == 'iam') {
                Navigator.of(context).pushNamed('/iam');
              } else if (value == 'logout') {
                final authProvider = Provider.of<CustomAuthProvider>(
                    context,
                    listen: false);
                authProvider.logout(context);
              }
            },
            itemBuilder: (context) => [
              if (_isTransportEditor)
                const PopupMenuItem(
                  value: 'editor',
                  child: Row(
                    children: [
                      Icon(Icons.edit_road, color: Color(0xFF1565C0)),
                      SizedBox(width: 8),
                      Text('Éditeur terrain'),
                    ],
                  ),
                ),
              if (_isTransportAdmin) ...[
                const PopupMenuItem(
                  value: 'admin',
                  child: Row(
                    children: [
                      Icon(Icons.fact_check, color: Color(0xFF6A1B9A)),
                      SizedBox(width: 8),
                      Text('Admin review'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'iam',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          color: Color(0xFF6A1B9A)),
                      SizedBox(width: 8),
                      Text('Gestion des accès'),
                    ],
                  ),
                ),
              ],
              if (_isTransportEditor || _isTransportAdmin)
                const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(TransitStrings.t('web.signOut', locale),
                        style: const TextStyle(color: Colors.red)),
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
    // Pin central visible (mode Course, étapes de recherche) → la molette /
    // le pinch zooment AUTOUR DU CENTRE pour que la position GPS visée par
    // le bonhomme ne bouge pas pendant le zoom (bug rapporté 05/06/2026 :
    // « en dézoomant la position GPS est changée »).
    final tripStepForZoom =
        context.select<TripProvider, CustomTripType?>((p) => p.currentStep);
    final zoomAroundCenter = _homeMode == HomeMode.course &&
        (tripStepForZoom == null ||
            tripStepForZoom == CustomTripType.setYourDestination ||
            tripStepForZoom == CustomTripType.choosePickupDropLocation);
    final allMarkers = <Marker>{};
    final allPolylines = <Polyline>{};
    final allCircles = <Circle>{};

    if (_homeMode == HomeMode.publicTransport) {
      // Mode "Transport en commun" : carte du réseau uniquement. Aucun
      // marker chauffeur / pickup / destination ni polyline d'itinéraire
      // course ne sont rendus — les 2 modes sont strictement isolés.
      if (_publicRoutePolylines.isEmpty) {
        // Pas d'itinéraire sélectionné → on montre le réseau complet
        // + éventuel preview O→D (pointillé) en cours de saisie.
        // Tant qu'aucune arrivée n'est posée → réseau complet visible.
        // Dès que l'arrivée est saisie → on MASQUE le réseau (toutes les
        // lignes) pour ne montrer que le départ + l'arrivée.
        if (_publicPreviewDest == null) {
          allPolylines.addAll(_publicTransportPolylines);
          allMarkers.addAll(_publicTransportMarkers);
          allCircles.addAll(_publicTransportCircles);
        }
        allPolylines.addAll(_publicPreviewPolyline);
        allMarkers.addAll(_publicPreviewMarkers);
      } else {
        // Itinéraire sélectionné → on isole : seul l'itinéraire est rendu,
        // les autres lignes du réseau sont cachées (UX user-spec).
        allPolylines.addAll(_publicRoutePolylines);
        allMarkers.addAll(_publicRouteMarkers);
      }
    } else {
      // Mode Course : chauffeurs + itinéraire + pickup/destination.
      allMarkers.addAll(_driverMarkers);
      if (_routeCoordinates.isNotEmpty) {
        allPolylines.addAll(_buildAnimatedPolylines());
      } else {
        allPolylines.addAll(_routePolylines);
      }
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
    }

    return BookingMap(
      controller: _mapController!,
      zoomAroundCenter: zoomAroundCenter,
      initialCenter: gma.toLL(_defaultPosition),
      // Zoom d'ouverture serré (échelle quartier, feedback 04/06) — vaut
      // pour les DEUX modes (Course et Transport en commun).
      initialZoom: 15.5,
      // Bornes : en Transport en commun, caméra VERROUILLÉE autour de Tana
      // (réseau Tana-only, zoom 11–18). En mode Course on DÉVERROUILLE — sinon
      // le focus sur une ville de province (Nosy Be…) et le dézoom sont clampés.
      minZoom: _homeMode == HomeMode.course ? 5.0 : _minZoom,
      maxZoom: _maxZoom,
      cameraBounds:
          _homeMode == HomeMode.course ? null : gma.toLLBounds(_tanaBounds),
      satellite: _currentMapType == MapType.satellite,
      // MÊME fond de plan dans les deux onglets (demande 05/06 : avec le
      // style misy2 déjà clair, le filtre désaturé du mode TC ne se
      // distinguait plus → retiré ; BookingMap.muted reste dispo).
      onTap: (_, p) => _onMapTap(gma.toGM(p)),
      onPositionChanged: (cam, hasGesture) {
        _onPublicCameraMove(cam);
        _onPublicCameraIdle();
        // Mode Course : tout mouvement gestuel (drag, fling, molette, pinch)
        // relance le debounce de settle du pin central.
        if (_homeMode == HomeMode.course && hasGesture) {
          _schedulePinSettle();
        }
      },
      children: [
        if (allPolylines.isNotEmpty)
          fm.PolylineLayer(polylines: gma.toFmPolylines(allPolylines)),
        if (allCircles.isNotEmpty)
          fm.CircleLayer(circles: gma.toFmCircles(allCircles)),
        if (allMarkers.isNotEmpty)
          fm.MarkerLayer(
              markers: gma.toFmMarkers(allMarkers,
                  iconUrls: _driverIconUrls,
                  iconWidgets: _publicMarkerWidgets)),
      ],
    );
  }

  /// Camera idle (= fin du pan/zoom). On refresh le cache pixel-écran des
  /// stops pour que la détection de hover soit précise. Sync, peu coûteux
  /// (1 seul appel async pour les bounds, puis interpolation linéaire).
  void _onPublicCameraIdle() {
    if (_homeMode != HomeMode.publicTransport) return;
    _refreshPublicStopScreenCache();
  }

  /// Gère le tap sur la carte (pour sélectionner une position)
  void _onMapTap(LatLng latLng) {
    // Mode public : un arrêt sous le curseur ? → ouvrir sa fiche (les onTap
    // des Marker/Circle gmaps ne survivent PAS à l'adaptation flutter_map,
    // on passe donc par la détection de hover). Sinon, on délègue au
    // calculateur d'itinéraire pour ajuster le dernier point posé.
    if (_homeMode == HomeMode.publicTransport) {
      final hovAgg =
          _publicHoveredStop != null ? _publicStopsByKey[_publicHoveredStop] : null;
      if (hovAgg != null) {
        _onPublicStopTap(hovAgg);
        return;
      }
      _publicMapTapNotifier.value = latLng;
      return;
    }

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // Si on est à l'étape de confirmation de destination, permettre d'ajuster le point de dépose
    if (tripProvider.currentStep == CustomTripType.confirmDestination) {
      _adjustDropLocation(latLng, tripProvider);
      return;
    }

    // (Le choix d'un point précis passe désormais par le pin central +
    // bouton carte du champ — plus de mode « cliquez sur la carte ».)
  }

  // ─────────────────────── Mode public (Transport en commun) ───────────────────────

  /// Pont mode Transport → mode Course : remplace un leg marche par une
  /// course Misy. Pré-remplit pickup/dropoff avec les coords du leg,
  /// bascule en mode Course et déclenche le flow de vehicle picker.
  ///
  /// Si les labels sont fournis (nom de l'arrêt taxi-be), on les utilise
  /// tels quels ; sinon on tombe sur "Position de départ" / "Destination"
  /// — le reverse-geocode coûteux n'est pas nécessaire à V1 (les coords
  /// sont déjà passées au TripProvider).
  void _onRequestRideForWalk({
    required LatLng start,
    required LatLng end,
    String? startLabel,
    String? endLabel,
  }) {
    final pickupAddress = (startLabel?.trim().isNotEmpty == true)
        ? startLabel!.trim()
        : 'Position de départ';
    final destAddress = (endLabel?.trim().isNotEmpty == true)
        ? endLabel!.trim()
        : 'Destination';

    setState(() {
      _pickupLocation = {
        'lat': start.latitude,
        'lng': start.longitude,
        'address': pickupAddress,
      };
      _destinationLocation = {
        'lat': end.latitude,
        'lng': end.longitude,
        'address': destAddress,
      };
      _pickupController.text = pickupAddress;
      _destinationController.text = destAddress;
    });

    _setHomeMode(HomeMode.course);

    // Déclenche le flow de recherche après le switch pour aller direct
    // au vehicle picker, comme un deep-link complet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onSearch();
    });
  }

  void _setHomeMode(HomeMode mode) {
    if (_homeMode == mode) return;
    setState(() {
      _homeMode = mode;
      if (mode != HomeMode.publicTransport) {
        // Sortie du TC : on consomme le pré-remplissage (sinon une prochaine
        // ouverture manuelle du mode relancerait la même recherche).
        _transitInitialOrigin = null;
        _transitInitialDestination = null;
        _transitFromCourse = false;
      }
      _exitPinSelection(); // sortie du mode sélection au pin (+ vue plan)
      _pinGrabbed = false;
      _publicSelectedLine = null;
      _publicSelectedStop = null;
      _publicSelectedStopScreenPos = null;
      _publicHoveredStop = null;
      _publicRoutePolylines = {};
      _publicRouteMarkers = {};
      _publicPreviewPolyline = {};
      _publicPreviewMarkers = {};
      _publicPreviewDest = null;
    });
    if (mode == HomeMode.publicTransport && !_publicTransportLoaded) {
      _loadPublicTransportLayers();
    }
    // Filet de sécurité : si la position caméra a été modifiée par un
    // recentrage automatique au mount du nouveau panel, on la rétablit.
    final last = _lastKnownCamera;
    if (last != null && _mapController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController?.move(last.center, last.zoom);
      });
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

  /// Affiche un itinéraire calculé sur la carte avec rendu multi-leg :
  /// chaque leg de transport a sa couleur de ligne, les marches sont en
  /// gris, un badge avec le numéro de ligne marque chaque embarquement,
  /// et la destination utilise le marker carré blanc-bordure-noire de
  /// l'onglet Course (cf. `_createSquareMarker`).
  ///
  /// Spec UX user : "n'affiche pas les autres lignes" — quand un
  /// itinéraire est actif, le réseau public est masqué, seul le tracé
  /// choisi est visible. Cf. `_buildMap` qui exclut les couches network
  /// quand `_publicRoutePolylines` est non vide.
  ///
  /// Callback du calculateur d'itinéraire : appelé dès que l'utilisateur
  /// pose ou retire un origin/destination dans les champs.
  ///
  /// - 1 point seul : pan vers ce point (zoom 15).
  /// - 2 points : fit la caméra sur les 2 + trace une polyline pointillée
  ///   grise entre les deux pour preview avant calcul.
  /// - Aucun point : efface le preview.
  ///
  /// Le preview disparaît automatiquement dès qu'un itinéraire est calculé
  /// (cf. `_buildMap` qui priorise `_publicRoutePolylines`).
  void _onPublicPointsChanged(LatLng? origin, LatLng? destination) {
    final polylines = <Polyline>{};
    final markers = <Marker>{};
    if (origin != null && destination != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('public_preview'),
        points: [origin, destination],
        color: const Color(0xFF6B7280),
        width: 3,
        patterns: [PatternItem.dash(10), PatternItem.gap(8)],
        zIndex: 150,
        consumeTapEvents: false,
      ));
    }
    if (origin != null) {
      // Pin sur la position GPS du lieu de DÉPART (icône verte, comme Course).
      markers.add(Marker(
        markerId: const MarkerId('public_preview_origin'),
        position: origin,
        icon: _pickupMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 0.5),
        zIndex: 251,
        consumeTapEvents: false,
      ));
    }
    if (destination != null) {
      markers.add(Marker(
        markerId: const MarkerId('public_preview_dest'),
        position: destination,
        icon: _destinationMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 0.5),
        zIndex: 251,
        consumeTapEvents: false,
      ));
    }
    setState(() {
      _publicPreviewPolyline = polylines;
      _publicPreviewMarkers = markers;
      _publicPreviewDest = destination;
    });

    // Animation caméra.
    final controller = _mapController;
    if (controller == null) return;
    if (origin != null && destination != null) {
      var minLat = origin.latitude < destination.latitude
          ? origin.latitude
          : destination.latitude;
      var maxLat = origin.latitude > destination.latitude
          ? origin.latitude
          : destination.latitude;
      var minLng = origin.longitude < destination.longitude
          ? origin.longitude
          : destination.longitude;
      var maxLng = origin.longitude > destination.longitude
          ? origin.longitude
          : destination.longitude;
      // Si les 2 points sont quasi confondus, fallback newLatLngZoom.
      if ((maxLat - minLat).abs() < 0.0005 &&
          (maxLng - minLng).abs() < 0.0005) {
        controller.move(gma.toLL(origin), 17);
        return;
      }
      controller.fitCamera(fm.CameraFit.bounds(
        bounds: fm.LatLngBounds(
          ll.LatLng(maxLat, maxLng),
          ll.LatLng(minLat, minLng),
        ),
        padding: _routeFitPadding(),
      ));
    } else if (origin != null) {
      controller.move(gma.toLL(origin), 17);
    } else if (destination != null) {
      controller.move(gma.toLL(destination), 17);
    }
  }

  /// `null` efface l'itinéraire et restaure le réseau.
  Future<void> _onPublicRouteSelected(TransportRoute? route) async {
    if (route == null) {
      setState(() {
        _publicRoutePolylines = {};
        _publicRouteMarkers = {};
        // Trajet effacé → on restaure le réseau complet.
        _publicPreviewDest = null;
      });
      // Re-render le réseau au cas où on était en mode iso.
      _rebuildPublicTransportLayers();
      return;
    }
    // L'itinéraire prend le relais du preview O→D.
    _publicPreviewPolyline = {};
    _publicPreviewMarkers = {};
    final polylines = <Polyline>{};
    final markers = <Marker>{};
    final allPts = <LatLng>[];
    final svc = PublicTransportService.instance;
    final dpr =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;

    for (var i = 0; i < route.steps.length; i++) {
      final step = route.steps[i];
      final List<LatLng> pts;
      final Color color;

      if (step.isWalking) {
        // Walk : gris doux. On utilise pathCoordinates si dispo, sinon
        // simple ligne droite walkStart→walkEnd (ou stop→stop).
        if (step.pathCoordinates.length >= 2) {
          pts = step.pathCoordinates;
        } else {
          pts = <LatLng>[
            if (step.walkStartPosition != null) step.walkStartPosition!,
            if (step.startStop != null) step.startStop!.position,
            if (step.endStop != null) step.endStop!.position,
            if (step.walkEndPosition != null) step.walkEndPosition!,
          ];
        }
        color = const Color(0xFF6B7280);
      } else {
        // Transport : couleur de la ligne. Path = startStop + intermédiaires
        // + endStop (= sequence d'arrêts dans la direction du voyage).
        final lineNum = step.lineNumber;
        final meta = lineNum != null ? svc.metadataFor(lineNum) : null;
        color = meta != null
            ? Color(meta.colorValue)
            : const Color(0xFF1565C0);
        if (step.pathCoordinates.length >= 2) {
          pts = step.pathCoordinates;
        } else {
          pts = <LatLng>[
            if (step.startStop != null) step.startStop!.position,
            for (final s in step.intermediateStops) s.position,
            if (step.endStop != null) step.endStop!.position,
          ];
        }
      }

      if (pts.length >= 2) {
        // Outline noir uniquement pour les segments transport (les marches
        // sont en pointillé gris, l'outline les rendrait illisibles).
        if (!step.isWalking) {
          polylines.add(Polyline(
            polylineId: PolylineId('route_leg_${i}_outline'),
            points: pts,
            color: Colors.black.withOpacity(0.85),
            width: 9,
            zIndex: 199 + i,
            consumeTapEvents: false,
          ));
        }
        polylines.add(Polyline(
          polylineId: PolylineId('route_leg_$i'),
          points: pts,
          color: color,
          width: step.isWalking ? 5 : 7,
          patterns: step.isWalking
              ? [PatternItem.dash(12), PatternItem.gap(8)]
              : const [],
          zIndex: 200 + i,
          consumeTapEvents: false,
        ));
        allPts.addAll(pts);
      }
    }

    // Badges : 1 par leg de transport, posé sur le startStop (= où le
    // voyageur monte). Le tout 1er badge marque le départ effectif du
    // voyage en transport, les suivants marquent les correspondances.
    var transportLegIdx = 0;
    for (var i = 0; i < route.steps.length; i++) {
      final step = route.steps[i];
      if (step.type != RouteStepType.transport) continue;
      final lineNum = step.lineNumber;
      if (lineNum == null || step.startStop == null) continue;
      final meta = svc.metadataFor(lineNum);
      final color = meta != null
          ? Color(meta.colorValue)
          : const Color(0xFF1565C0);
      final boardPts = step.pathCoordinates.length >= 2
          ? step.pathCoordinates
          : <LatLng>[
              step.startStop!.position,
              for (final s in step.intermediateStops) s.position,
              if (step.endStop != null) step.endStop!.position,
            ];
      final boardBearing =
          _bearingAtPointOnPolyline(step.startStop!.position, boardPts);
      // Tuile flottée à côté du tracé ; le point d'arrêt est déjà dessiné par
      // les dots blancs de l'itinéraire (withDot: false évite le doublon).
      final pin = await StopMarkerFactory.createPinnedLabel(
        label: lineNum,
        color: color,
        devicePixelRatio: dpr,
        bearingDeg: boardBearing,
        style: StopMarkerStyle.largeLabel,
        withDot: false,
      );
      markers.add(Marker(
        markerId: MarkerId('route_board_$transportLegIdx'),
        position: step.startStop!.position,
        icon: pin.descriptor,
        anchor: pin.anchor,
        zIndex: 300,
        consumeTapEvents: false,
      ));
      transportLegIdx++;
    }

    // Petits dots blancs (bord noir fin) à chaque arrêt traversé par les
    // legs transport — startStop + intermediateStops + endStop. Effet plan
    // métro : les arrêts ressortent visuellement sur la polyline isolée.
    final stopDot = await StopMarkerFactory.create(
      label: '',
      color: Colors.white,
      devicePixelRatio: dpr,
      style: StopMarkerStyle.dot,
    );
    final seenStops = <String>{};
    var stopDotIdx = 0;
    String dotKey(LatLng p) =>
        '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';
    for (final step in route.steps) {
      if (step.type != RouteStepType.transport) continue;
      final stops = <TransportNode>[
        if (step.startStop != null) step.startStop!,
        ...step.intermediateStops,
        if (step.endStop != null) step.endStop!,
      ];
      for (final s in stops) {
        final key = dotKey(s.position);
        if (!seenStops.add(key)) continue;
        markers.add(Marker(
          markerId: MarkerId('route_stop_${stopDotIdx++}'),
          position: s.position,
          icon: stopDot,
          anchor: const Offset(0.5, 0.5),
          zIndex: 280,
          consumeTapEvents: false,
        ));
      }
    }

    // Destination : carré blanc-bordure-noire-point-noir (style Course).
    // Réutilise _destinationMarkerIcon préchargé au montage.
    if (_destinationMarkerIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('route_dest'),
        position: route.destination,
        icon: _destinationMarkerIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 320,
        consumeTapEvents: false,
      ));
    }

    setState(() {
      _publicRoutePolylines = polylines;
      _publicRouteMarkers = markers;
    });

    // Fit camera sur l'itinéraire.
    if (_mapController != null && allPts.length >= 2) {
      var minLat = allPts.first.latitude, maxLat = allPts.first.latitude;
      var minLng = allPts.first.longitude, maxLng = allPts.first.longitude;
      for (final p in allPts) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      _mapController?.fitCamera(
        fm.CameraFit.bounds(
          bounds: fm.LatLngBounds(
            ll.LatLng(maxLat, maxLng),
            ll.LatLng(minLat, minLng),
          ),
          padding: _routeFitPadding(),
        ),
      );
    }
  }

  /// Charge le bundle public si pas déjà fait, puis calcule les Set de
  /// polylines + markers pour l'affichage du réseau sur la carte.
  Future<void> _loadPublicTransportLayers() async {
    try {
      final svc = PublicTransportService.instance;
      // ── FAST PATH (flag LOOM) : manifest (~46 Ko) + faisceaux
      // pré-calculés (network_strands.json) suffisent à dessiner TOUS les
      // rubans — la carte est visible en ~1-2 s au lieu d'attendre les
      // 91×2 GeoJSON et les précalculs. L'ordre/squelette provisoires du
      // manifest sont remplacés par les vrais au chargement complet.
      var loomReady = false;
      if (LoomNetworkService.flagEnabled) {
        final r = await Future.wait<dynamic>([
          svc.ensureManifest(),
          LoomNetworkService.instance.ensureLoaded(),
        ]);
        loomReady = r[1] as bool;
        if (loomReady && mounted) {
          _populateStrandRunsFromLoom(); // sans antennes retour (pas encore
          //                                de geojson) — re-passe plus bas
          await _rebuildPublicTransportLayers();
          setState(() => _publicTransportLoaded = true);
        }
      }

      // ── CHARGEMENT COMPLET : GeoJSON, importance/squelette réels,
      // antennes retour, clusters d'arrêts, index de recherche.
      await svc.ensureLoaded();
      if (!mounted) return;
      // Fusion aller/retour par ligne (vue réseau) : tronc partagé + branches.
      _precomputeMergedLines();
      // Faisceaux : derrière --dart-define=LOOM_NETWORK=true, ordonnancement
      // PRO pré-calculé au build par LOOM (tools/network, corridors complets
      // ordonnés, croisements minimisés) ; sinon — ou si le JSON est absent —
      // heuristique runtime historique : co-localisation (≥2 lignes même axe)
      // → profils de slot -1/0/+1, ≤ 3 brins côte à côte, aucun trou.
      if (loomReady || await LoomNetworkService.instance.ensureLoaded()) {
        _populateStrandRunsFromLoom(); // avec retourSolo cette fois
      } else {
        _precomputeStrandRuns();
      }
      _precomputeBaseClusters();
      await _rebuildPublicTransportLayers();
      setState(() => _publicTransportLoaded = true);
    } catch (e) {
      myCustomPrintStatement('PublicTransportLayers: erreur chargement $e');
    }
  }

  // ───────── Faisceaux de lignes co-localisées (vue réseau) ─────────
  /// Budget de largeur ÉCRAN d'une bande de corridor LOOM (rubans + jours)
  /// quel que soit son k — pitch par brin = budget / k, plafonné au pas
  /// normal (cf. addStrand dans _rebuildPublicTransportLayers).
  static const double _loomBandBudgetPx = 40.0;

  /// Zoom minimal d'affichage des billes d'arrêts en vue réseau LOOM
  /// (hors ligne sélectionnée, qui les montre à tout zoom).
  static const double _loomStopsMinZoom = 16.0;

  static const double _corridorSampleStepM = 10.0;
  static const double _corridorMergeRadiusM = 25.0; // englobe un terre-plein
  static const double _corridorBearingTolDeg = 25.0;

  /// Densifie un tracé à pas ~constant en gardant le cap local.
  List<_TrunkSample> _densifyTrunk(List<LatLng> pts) {
    final out = <_TrunkSample>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final segLen = _metersBetween(a, b);
      if (segLen <= 0) continue;
      final brg =
          _bearingBetween(a.latitude, a.longitude, b.latitude, b.longitude);
      final steps = (segLen / _corridorSampleStepM).ceil().clamp(1, 100000);
      for (var s = 0; s < steps; s++) {
        final t = s / steps;
        out.add(_TrunkSample(
          LatLng(a.latitude + (b.latitude - a.latitude) * t,
              a.longitude + (b.longitude - a.longitude) * t),
          brg,
        ));
      }
    }
    if (pts.length >= 2) {
      final last = pts.last, prev = pts[pts.length - 2];
      out.add(_TrunkSample(
          last,
          _bearingBetween(
              prev.latitude, prev.longitude, last.latitude, last.longitude)));
    }
    return out;
  }

  double _bearingDiffMod180Trunk(double a, double b) {
    var d = (a - b).abs() % 360.0;
    if (d > 180.0) d = 360.0 - d;
    if (d > 90.0) d = 180.0 - d;
    return d;
  }

  /// Pré-calcule (UNE fois) les tracés "faisceau-ready" de la vue réseau.
  /// Détection par échantillonnage (~10 m) des zones où ≥ 2 lignes partagent
  /// le même axe (rayon 25 m, caps ±25° mod 180°) ; chaque ligne y reçoit un
  /// SLOT (-1 / 0 / +1 : prioritaire au centre — squelette d'abord, puis
  /// importance — suivantes de part et d'autre, au-delà de 3 → centre,
  /// dessous). Facteurs lissés (fenêtre ±6 ≈ 60 m) puis convertis en
  /// vecteurs latéraux unitaires (perpendiculaire CANONIQUE mod 180° → deux
  /// lignes antiparallèles s'écartent du même côté), eux-mêmes lissés
  /// (fenêtre ±3, amortit le flip de cap à 0/180°). Enfin chaque pièce de
  /// [_mergedRuns] est densifiée (~20 m) et annotée du vecteur du plus
  /// proche échantillon. Résultat : des polylignes CONTINUES (aucun trou)
  /// qui s'écartent en brins côte à côte dans les zones partagées et se
  /// croisent franchement ailleurs — l'offset réel est appliqué au rebuild
  /// ∝ largeur de brin au zoom courant (cf. [_applyStrandOffset]).
  void _precomputeStrandRuns() {
    final svc = PublicTransportService.instance;
    final byImportance = svc.linesByImportance;
    final backbone = svc.backboneLines;
    final rank = <String, int>{
      for (var i = 0; i < byImportance.length; i++) byImportance[i]: i,
    };
    // Priorité de slot : squelette (lignes toujours affichées) d'abord →
    // au centre, puis importance (longueur).
    int prio(String l) =>
        (backbone.contains(l) ? 0 : 1 << 20) + (rank[l] ?? (1 << 19));

    final samples = <String, List<_TrunkSample>>{};
    for (final ln in byImportance) {
      // Tier 1 (téléphérique, train urbain) = HORS faisceau : jamais décalé
      // ni compté ; tracé en ligne pleine par-dessus.
      if (svc.tierFor(ln) == 1) continue;
      final g = svc.getLineGroup(ln);
      if (g == null) continue;
      final a = g.aller, r = g.retour;
      if (a != null && a.coordinates.length >= 2) {
        samples['${ln}_aller'] = _densifyTrunk(a.coordinates);
      }
      if (r != null && r.coordinates.length >= 2) {
        samples['${ln}_retour'] = _densifyTrunk(r.coordinates);
      }
    }
    if (samples.isEmpty) {
      _strandRuns = const {};
      return;
    }

    const cell = _corridorMergeRadiusM;
    final grid = <String, List<_TrunkGridEntry>>{};
    List<int> cellOf(LatLng p) => [
          (p.longitude * 111320.0 * cos(p.latitude * pi / 180) / cell).floor(),
          (p.latitude * 111320.0 / cell).floor(),
        ];
    samples.forEach((key, list) {
      for (final s in list) {
        final c = cellOf(s.pos);
        grid
            .putIfAbsent('${c[0]}_${c[1]}', () => [])
            .add(_TrunkGridEntry(key, s.bearing, s.pos));
      }
    });

    String lineOf(String key) => key.endsWith('_aller')
        ? key.substring(0, key.length - 6)
        : key.substring(0, key.length - 7);

    // Par échantillon de chaque (ligne, sens) : facteur de slot (médiane +
    // lissage) puis vecteur latéral via la TANGENTE CONTINUE du tracé.
    final vecAt = <String, List<({LatLng pos, double vLat, double vLng})>>{};
    samples.forEach((key, list) {
      final selfLine = lineOf(key);
      final n = list.length;

      // Perpendiculaire CONTINUE le long du parcours : tangente lissée par
      // différence centrale (fenêtre ±4 ≈ ±40 m, espace mètres) tournée de
      // +90°. L'ancienne formule « cap mod 180° + 90 » avait une
      // discontinuité pile sur les axes ~N-S (178° vs 2° → perpendiculaires
      // OPPOSÉES d'un échantillon à l'autre) → brins qui sautaient de côté
      // = TRESSAGE vu en prod le 05/06/2026.
      final perpN = List<double>.filled(n, 0); // composante nord (m)
      final perpE = List<double>.filled(n, 0); // composante est (m)
      for (var i = 0; i < n; i++) {
        final a = list[(i - 4).clamp(0, n - 1)].pos;
        final b = list[(i + 4).clamp(0, n - 1)].pos;
        var tE = (b.longitude - a.longitude) *
            111320.0 *
            cos(a.latitude * pi / 180);
        var tN = (b.latitude - a.latitude) * 111320.0;
        final len = sqrt(tE * tE + tN * tN);
        if (len < 1e-6) {
          if (i > 0) {
            perpN[i] = perpN[i - 1];
            perpE[i] = perpE[i - 1];
          }
          continue;
        }
        tE /= len;
        tN /= len;
        // Rotation +90° boussole : (N, E) → (−E, N).
        perpN[i] = -tE;
        perpE[i] = tN;
      }

      final raw = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        final s = list[i];
        final c = cellOf(s.pos);
        final set = <String>{selfLine};
        final near = <_TrunkGridEntry>[];
        for (var dx = -1; dx <= 1; dx++) {
          for (var dy = -1; dy <= 1; dy++) {
            final bucket = grid['${c[0] + dx}_${c[1] + dy}'];
            if (bucket == null) continue;
            for (final e in bucket) {
              if (_metersBetween(s.pos, e.pos) > _corridorMergeRadiusM) {
                continue;
              }
              if (_bearingDiffMod180Trunk(s.bearing, e.bearing) >
                  _corridorBearingTolDeg) {
                continue;
              }
              set.add(lineOf(e.key));
              near.add(e);
            }
          }
        }
        if (set.length < 2) continue; // seul sur l'axe → centre (0)
        final ordered = set.toList()
          ..sort((a, b) => prio(a).compareTo(prio(b)));
        final idx = ordered.indexOf(selfLine);
        var f = idx == 1 ? 1.0 : (idx == 2 ? -1.0 : 0.0);
        if (f != 0) {
          // Cohérence de CÔTÉ avec la ligne de référence du corridor
          // (slot 0) : si on la longe à CONTRESENS, notre « droite » est sa
          // « gauche » — sans ce flip, deux lignes saisies en sens inverse
          // finissaient sur le même flanc (chevauchement/tressage).
          final ref = ordered[0];
          _TrunkGridEntry? best;
          var bestD = double.infinity;
          for (final e in near) {
            if (lineOf(e.key) != ref) continue;
            final d = _metersBetween(s.pos, e.pos);
            if (d < bestD) {
              bestD = d;
              best = e;
            }
          }
          if (best != null) {
            final diff =
                (((s.bearing - best.bearing) % 360) + 540) % 360 - 180;
            if (diff.abs() > 90) f = -f; // antiparallèle à la référence
          }
        }
        raw[i] = f;
      }

      // Hystérésis : médiane glissante (±4 ≈ 90 m) — une ligne qui ne longe
      // l'axe que sur 2-3 échantillons ne fait plus zigzaguer le slot (les
      // S permanents quand la composition du faisceau change sans arrêt).
      final med = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        final w = <double>[];
        for (var j = i - 4; j <= i + 4; j++) {
          if (j < 0 || j >= n) continue;
          w.add(raw[j]);
        }
        w.sort();
        med[i] = w[w.length ~/ 2];
      }
      // Lissage du facteur → transitions en biais douces (pas de marche).
      final smooth = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        var sum = 0.0;
        var c = 0;
        for (var j = i - 6; j <= i + 6; j++) {
          if (j < 0 || j >= n) continue;
          sum += med[j];
          c++;
        }
        smooth[i] = sum / c;
      }
      // Vecteur latéral = facteur × perpendiculaire continue, puis lissage
      // vectoriel (fenêtre ±3).
      final vec = List<({LatLng pos, double vLat, double vLng})>.generate(
        n,
        (i) => (
          pos: list[i].pos,
          vLat: smooth[i] * perpN[i],
          vLng: smooth[i] * perpE[i],
        ),
      );
      final out = <({LatLng pos, double vLat, double vLng})>[];
      for (var i = 0; i < vec.length; i++) {
        var sLat = 0.0, sLng = 0.0;
        var c = 0;
        for (var j = i - 3; j <= i + 3; j++) {
          if (j < 0 || j >= vec.length) continue;
          sLat += vec[j].vLat;
          sLng += vec[j].vLng;
          c++;
        }
        out.add((pos: vec[i].pos, vLat: sLat / c, vLng: sLng / c));
      }
      vecAt[key] = out;
    });

    // Index spatial des vecteurs par (ligne, sens) pour annoter les pièces.
    final vecGrid = <String, Map<String, List<int>>>{};
    vecAt.forEach((key, list) {
      final g = <String, List<int>>{};
      for (var i = 0; i < list.length; i++) {
        final c = cellOf(list[i].pos);
        g.putIfAbsent('${c[0]}_${c[1]}', () => []).add(i);
      }
      vecGrid[key] = g;
    });

    ({double vLat, double vLng, int idx}) lookupVec(
        String key, LatLng p, int lastIdx) {
      final list = vecAt[key];
      final g = vecGrid[key];
      if (list == null || g == null) return (vLat: 0.0, vLng: 0.0, idx: -1);
      final c = cellOf(p);
      var best = -1;
      var bestD = 30.0; // au-delà : hors tracé échantillonné → centre
      // Continuité de parcours : on préfère un échantillon proche en INDEX
      // du précédent (±80 ≈ 800 m). Sans ce filtre, dans les lacets de Tana
      // (la même rue repasse à < 30 m), le plus-proche absolu attrapait le
      // vecteur d'un AUTRE passage → pics/zigzags isolés.
      for (var pass = 0; pass < 2; pass++) {
        final constrain = pass == 0 && lastIdx >= 0;
        for (var dx = -1; dx <= 1; dx++) {
          for (var dy = -1; dy <= 1; dy++) {
            final bucket = g['${c[0] + dx}_${c[1] + dy}'];
            if (bucket == null) continue;
            for (final i in bucket) {
              if (constrain && (i - lastIdx).abs() > 80) continue;
              final d = _metersBetween(p, list[i].pos);
              if (d < bestD) {
                bestD = d;
                best = i;
              }
            }
          }
        }
        if (best >= 0) break; // pass contraint suffisant
      }
      if (best < 0) return (vLat: 0.0, vLng: 0.0, idx: lastIdx);
      return (vLat: list[best].vLat, vLng: list[best].vLng, idx: best);
    }

    // Densifie chaque pièce de _mergedRuns (~20 m) et annote chaque point.
    List<_StrandPt> annotate(String key, List<LatLng> pts) {
      final out = <_StrandPt>[];
      var last = -1;
      void add(LatLng p) {
        final v = lookupVec(key, p, last);
        last = v.idx;
        out.add(_StrandPt(p, v.vLat, v.vLng));
      }

      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i], b = pts[i + 1];
        final segLen = _metersBetween(a, b);
        final steps = (segLen / 20.0).ceil().clamp(1, 100000);
        for (var s = 0; s < steps; s++) {
          final t = s / steps;
          add(LatLng(a.latitude + (b.latitude - a.latitude) * t,
              a.longitude + (b.longitude - a.longitude) * t));
        }
      }
      if (pts.isNotEmpty) add(pts.last);
      return out;
    }

    final result = <String,
        ({
          List<({int k, List<_StrandPt> pts})> trunk,
          List<({int k, List<_StrandPt> pts})> allerSolo,
          List<({int k, List<_StrandPt> pts})> retourSolo
        })>{};
    _mergedRuns.forEach((ln, runs) {
      if (svc.tierFor(ln) == 1) return; // tier 1 : tracé pur, pas de faisceau
      // Le tronc reprend la géométrie de l'aller ; fallback retour si la
      // ligne n'a qu'un sens. k: 0 = pièce heuristique (largeur/écart legacy).
      final ak =
          vecAt.containsKey('${ln}_aller') ? '${ln}_aller' : '${ln}_retour';
      final rk =
          vecAt.containsKey('${ln}_retour') ? '${ln}_retour' : ak;
      result[ln] = (
        trunk: [for (final p in runs.trunk) (k: 0, pts: annotate(ak, p))],
        allerSolo: [
          for (final p in runs.allerSolo) (k: 0, pts: annotate(ak, p))
        ],
        retourSolo: [
          for (final p in runs.retourSolo) (k: 0, pts: annotate(rk, p))
        ],
      );
    });
    _strandRuns = result;
    _strandsFromLoom = false;
  }

  /// Peuple [_strandRuns] depuis les faisceaux LOOM pré-calculés au build
  /// (flag LOOM_NETWORK, cf. [LoomNetworkService]) :
  /// - `trunk` = runs LOOM (l'ALLER complet, géométrie `topo` partagée,
  ///   vecteurs slot×perpendiculaire déjà "baked" — sémantique [_StrandPt]),
  ///   `k` = densité max du corridor sur la pièce (amincissement au rendu) ;
  /// - `retourSolo` = antennes du retour à sens unique reprises de
  ///   [_mergedRuns] SANS offset (k: 0, vecteur nul) : LOOM ne connaît que
  ///   l'aller, ces tronçons divergents resteraient invisibles sinon ;
  /// - `allerSolo` = vide : l'aller est déjà couvert en entier par les runs
  ///   LOOM (le dessiner en plus dédoublerait le trait).
  /// Ligne absente du JSON → pas d'entrée → fallback tracé brut/mergé au
  /// rendu (branche `strands == null`).
  void _populateStrandRunsFromLoom() {
    final svc = PublicTransportService.instance;
    final loom = LoomNetworkService.instance;
    final result = <String,
        ({
          List<({int k, List<_StrandPt> pts})> trunk,
          List<({int k, List<_StrandPt> pts})> allerSolo,
          List<({int k, List<_StrandPt> pts})> retourSolo
        })>{};
    for (final ln in svc.linesByImportance) {
      if (svc.tierFor(ln) == 1) continue; // tier 1 : tracé pur au-dessus
      if (loom.isRepresented(ln)) continue; // variante → tronc fusionné
      final runs = loom.runsFor(ln);
      if (runs == null || runs.isEmpty) continue;
      final merged = _mergedRuns[ln];
      result[ln] = (
        trunk: [
          for (final r in runs)
            (
              k: r.k,
              pts: [
                for (final p in r.pts)
                  _StrandPt(LatLng(p[0], p[1]), p[2], p[3]),
              ],
            ),
        ],
        allerSolo: const [],
        retourSolo: [
          for (final pts in merged?.retourSolo ?? const <List<LatLng>>[])
            (k: 0, pts: [for (final p in pts) _StrandPt(p, 0, 0)]),
        ],
      );
    }
    _strandRuns = result;
    _strandsFromLoom = true;
    myCustomPrintStatement(
        'LOOM network: ${result.length} lignes en faisceaux pré-calculés');
  }

  /// Applique l'offset latéral de faisceau à une pièce annotée :
  /// out = pos + (vLat, vLng) × [slotWM]. Vecteur nul → point inchangé.
  static List<LatLng> _applyStrandOffset(List<_StrandPt> pts, double slotWM) {
    return [
      for (final p in pts)
        (p.vLat == 0 && p.vLng == 0)
            ? p.pos
            : LatLng(
                p.pos.latitude + (slotWM * p.vLat) / 111320.0,
                p.pos.longitude +
                    (slotWM * p.vLng) /
                        (111320.0 * cos(p.pos.latitude * pi / 180)),
              ),
    ];
  }

  /// Pré-calcule (UNE fois, statique) pour chaque ligne le découpage
  /// aller/retour utilisé par la vue réseau : tronc partagé (double sens même
  /// chaussée) vs branches à sens unique. Cf. champ [_mergedRuns].
  void _precomputeMergedLines() {
    final svc = PublicTransportService.instance;
    final result = <String,
        ({
          List<List<LatLng>> trunk,
          List<List<LatLng>> allerSolo,
          List<List<LatLng>> retourSolo
        })>{};
    for (final ln in svc.linesByImportance) {
      final g = svc.getLineGroup(ln);
      if (g == null) continue;
      result[ln] = _segmentAllerRetour(
        g.aller?.coordinates ?? const <LatLng>[],
        g.retour?.coordinates ?? const <LatLng>[],
      );
    }
    _mergedRuns = result;
  }

  /// Découpe l'aller et le retour d'UNE même ligne en :
  /// - `trunk` : portions où le retour longe l'aller (≤ [_corridorMergeRadiusM],
  ///   caps quasi-parallèles mod 180°) = même chaussée double sens → tracées
  ///   UNE fois depuis la géométrie de l'aller ;
  /// - `allerSolo` / `retourSolo` : portions à sens unique propres à chaque sens.
  /// Aucun offset, aucune ligne médiane fabriquée (géométrie inchangée).
  ({
    List<List<LatLng>> trunk,
    List<List<LatLng>> allerSolo,
    List<List<LatLng>> retourSolo
  }) _segmentAllerRetour(List<LatLng> aller, List<LatLng> retour) {
    // Une seule direction présente → pas de fusion possible : c'est le tronc.
    if (aller.length < 2 || retour.length < 2) {
      final lone = aller.length >= 2 ? aller : retour;
      return (
        trunk: lone.length >= 2 ? [List<LatLng>.from(lone)] : <List<LatLng>>[],
        allerSolo: const <List<LatLng>>[],
        retourSolo: const <List<LatLng>>[],
      );
    }

    final a = _densifyTrunk(aller);
    final r = _densifyTrunk(retour);

    const cell = _corridorMergeRadiusM;
    List<int> cellOf(LatLng p) => [
          (p.longitude * 111320.0 * cos(p.latitude * pi / 180) / cell).floor(),
          (p.latitude * 111320.0 / cell).floor(),
        ];
    Map<String, List<_TrunkSample>> buildGrid(List<_TrunkSample> s) {
      final g = <String, List<_TrunkSample>>{};
      for (final e in s) {
        final c = cellOf(e.pos);
        g.putIfAbsent('${c[0]}_${c[1]}', () => []).add(e);
      }
      return g;
    }

    // Un échantillon « coïncide » s'il existe, dans l'autre sens, un point à
    // ≤ rayon ET de cap quasi-parallèle (mod 180° → sens opposé accepté).
    bool coincides(Map<String, List<_TrunkSample>> grid, _TrunkSample s) {
      final c = cellOf(s.pos);
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final bucket = grid['${c[0] + dx}_${c[1] + dy}'];
          if (bucket == null) continue;
          for (final e in bucket) {
            if (_metersBetween(s.pos, e.pos) > _corridorMergeRadiusM) continue;
            if (_bearingDiffMod180Trunk(s.bearing, e.bearing) >
                _corridorBearingTolDeg) {
              continue;
            }
            return true;
          }
        }
      }
      return false;
    }

    final gridA = buildGrid(a);
    final gridR = buildGrid(r);
    final sharedA = [for (final s in a) coincides(gridR, s)];
    final sharedR = [for (final s in r) coincides(gridA, s)];

    // Regroupe en runs contigus selon [want].
    // - [stitchTo] null (aller) : on prolonge d'un point au raccord → les runs
    //   tronc/branche se chevauchent d'un segment sur la MÊME géométrie (aller),
    //   donc continuité parfaite.
    // - [stitchTo] = aller (retour) : aux bords qui touchent une zone partagée,
    //   on raccorde l'extrémité de la branche retour sur le TRONC (projection
    //   sur l'aller) → plus de trait « coupé » flottant à ~25 m du tronc.
    List<List<LatLng>> runsOf(List<_TrunkSample> s, List<bool> flag, bool want,
        {List<LatLng>? stitchTo}) {
      final runs = <List<LatLng>>[];
      var i = 0;
      while (i < s.length) {
        if (flag[i] != want) {
          i++;
          continue;
        }
        var j = i;
        while (j + 1 < s.length && flag[j + 1] == want) {
          j++;
        }
        final pts = <LatLng>[];
        if (stitchTo != null && i > 0 && flag[i - 1] != want) {
          pts.add(_snapToPolyline(s[i].pos, stitchTo)); // raccord au tronc
        }
        for (var k = i; k <= j; k++) {
          pts.add(s[k].pos);
        }
        if (stitchTo != null) {
          if (j + 1 < s.length && flag[j + 1] != want) {
            pts.add(_snapToPolyline(s[j + 1].pos, stitchTo)); // raccord au tronc
          }
        } else if (j + 1 < s.length) {
          pts.add(s[j + 1].pos); // raccord continuité (même géométrie)
        }
        if (pts.length >= 2) runs.add(pts);
        i = j + 1;
      }
      return runs;
    }

    return (
      trunk: runsOf(a, sharedA, true), // aller partagé = tronc (chaussée pleine)
      allerSolo: runsOf(a, sharedA, false), // aller seul = branche fine
      retourSolo: runsOf(r, sharedR, false, stitchTo: aller), // raccordée au tronc
      // (retour partagé non tracé : déjà couvert par le tronc de l'aller)
    );
  }

  /// Mètres par pixel au [zoom] Google (lat Antananarivo ≈ -18.9°). Sert à
  /// rendre les traits/billes en géométrie statique : largeur définie en
  /// MÈTRES puis convertie en px → le trait épaissit en zoomant (≠ px fixe
  /// ridiculement fin en zoom serré) et reste fin/visible en vue réseau.
  double _metersPerPixel(double zoom) =>
      156543.03392 * cos(-18.9 * pi / 180) / pow(2, zoom).toDouble();

  /// Épaisseur ÉCRAN (px) du trait d'une ligne selon son tier — constante au
  /// zoom (style plan de réseau pro, remplace les largeurs géographiques qui
  /// « débordaient » des rues en zoom serré). La bille d'arrêt et les
  /// terminus en dérivent pour rester proportionnels au trait.
  double _lineStrokePx(int tier, bool isTele) {
    if (tier == 1) return isTele ? 6.0 : 7.0; // téléphérique / train
    if (tier == 2) return 5.0; // bus numéroté
    return 3.5; // variantes locales
  }

  /// Libellé court d'un arrêt en vue « ligne sélectionnée » : numéro sur
  /// 3 chiffres sans suffixe (« 9 » → « 009 », « 146 Rouge » → « 146 »,
  /// « 147BIS » → « 147 ») ; lignes nommées sans chiffre → initiale
  /// (« MAHITSY » → « M », « D » → « D »).
  static String _shortLineLabel(String lineNumber) {
    final digits = RegExp(r'\d+').firstMatch(lineNumber)?.group(0);
    if (digits != null) return digits.padLeft(3, '0');
    final trimmed = lineNumber.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  /// Badge circulaire d'arrêt : disque couleur de la ligne, bordure blanche,
  /// libellé court centré. Widget pur — enregistré dans
  /// [_publicMarkerWidgets] (l'adaptateur flutter_map ne lit pas les bitmaps).
  static Widget _circleStopBadge(String label, Color color,
      {required bool big}) {
    final d = big ? 28.0 : 22.0;
    final textColor = color.computeLuminance() > 0.6
        ? const Color(0xFF1D3557)
        : Colors.white;
    return Center(
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: big ? 2.6 : 2.2),
          boxShadow: const [
            BoxShadow(color: Color(0x44000000), blurRadius: 3),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: big ? 9.5 : 8.0,
              height: 1.0,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
    );
  }

  /// Rectangle de CORRESPONDANCE (vue réseau) : blanc, bords arrondis,
  /// bordure sombre, orienté PERPENDICULAIREMENT au tracé pour recouvrir les
  /// brins côte à côte ; longueur ∝ nb de lignes connectées (≤ 3 brins
  /// affichés). Style plan de métro. Widget pur.
  static Widget _interchangeRectBadge(int lineCount,
      {required double bearingDeg, required bool big}) {
    final strands = lineCount.clamp(2, 3);
    final scale = big ? 1.2 : 1.0;
    // Largeur = EXACTEMENT celle du faisceau : n brins × (trait 5 px +
    // bordure noire 2 px), + la bordure du rect. Hauteur ≈ un trait + marge.
    final w = (strands * 7.0 + 2.0) * scale;
    final h = 8.0 * scale;
    // Rect horizontal (axe long = est) tourné de [bearingDeg] : son axe long
    // pointe alors vers (cap + 90°) = en travers du faisceau.
    final angle = bearingDeg * pi / 180.0;
    return Center(
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(h / 2),
            border: Border.all(color: const Color(0xFF1A1A1A), width: 1.6),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 2),
            ],
          ),
        ),
      ),
    );
  }

  /// Capsule de pastilles n° de ligne (terminus / correspondances, zoom
  /// élevé) : jusqu'à 3 pastilles + « +N ». Widget pur, flotté au-dessus de
  /// la bille par l'appelant (Transform.translate).
  Widget _lineCapsuleBadge(List<String> lines, {required bool big}) {
    final svc = PublicTransportService.instance;
    final shown = lines.take(3).toList();
    final extra = lines.length - shown.length;
    final fs = big ? 9.0 : 7.5;

    Widget chip(String ln) {
      final meta = svc.metadataFor(ln);
      final color =
          meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
      final tc = color.computeLuminance() > 0.6
          ? const Color(0xFF1D3557)
          : Colors.white;
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: big ? 4 : 3, vertical: big ? 2 : 1.5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1.1),
        ),
        child: Text(
          _shortLineLabel(ln),
          style: TextStyle(
            color: tc,
            fontWeight: FontWeight.w800,
            fontSize: fs,
            height: 1.0,
          ),
        ),
      );
    }

    return Center(
      child: Wrap(
        spacing: 2,
        children: [
          for (final ln in shown) chip(ln),
          if (extra > 0)
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: big ? 4 : 3, vertical: big ? 2 : 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2F7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1.1),
              ),
              child: Text(
                '+$extra',
                style: TextStyle(
                  color: const Color(0xFF53606E),
                  fontWeight: FontWeight.w800,
                  fontSize: fs,
                  height: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Pré-calcule UNE FOIS la liste des clusters d'arrêts (dédup name +
  /// proximité) avec snap à la polyline de leur ligne la plus importante.
  /// Cette opération est O(N²) mais ne dépend ni du zoom ni de la
  /// sélection : on la fait une seule fois et on filtre/recolore au
  /// rebuild ensuite.
  void _precomputeBaseClusters() {
    final svc = PublicTransportService.instance;
    final byImportance = svc.linesByImportance;
    final importanceRank = <String, int>{
      for (var i = 0; i < byImportance.length; i++) byImportance[i]: i,
    };
    final orderedGroups = <TransportLineGroup>[
      for (var i = byImportance.length - 1; i >= 0; i--)
        if (svc.getLineGroup(byImportance[i]) != null)
          svc.getLineGroup(byImportance[i])!,
    ];

    // 1. Collecte de tous les raw stops avec snap-to-polyline.
    final rawStops = <_RawStop>[];
    for (final group in orderedGroups) {
      final meta = svc.metadataFor(group.lineNumber);
      final color =
          meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
      void collect(TransportLine? line, String dir) {
        if (line == null) return;
        final n = line.stops.length;
        for (var i = 0; i < n; i++) {
          final stop = line.stops[i];
          final snapped = _snapToPolyline(stop.position, line.coordinates);
          rawStops.add(_RawStop(
            position: snapped,
            name: stop.name,
            lineNumber: group.lineNumber,
            color: color,
            isTerminus: i == 0 || i == n - 1,
            direction: dir,
          ));
        }
      }
      collect(group.aller, 'aller');
      collect(group.retour, 'retour');
    }

    // 2. Clustering (O(N²) mais une seule fois).
    final clusters = <_PublicStopAggregate>[];
    for (final raw in rawStops) {
      final rawNameNorm = _normalizeStopName(raw.name);
      _PublicStopAggregate? match;
      for (final c in clusters) {
        final dist = _metersBetween(c.position, raw.position);
        final cNameNorm = _normalizeStopName(c.name);
        final sameName = rawNameNorm.isNotEmpty &&
            cNameNorm.isNotEmpty &&
            rawNameNorm == cNameNorm;
        if (sameName && dist <= 250.0) {
          match = c;
          break;
        }
        if (dist <= 35.0) {
          match = c;
          break;
        }
      }
      if (match != null) {
        match.lines.add(raw.lineNumber);
        if (raw.isTerminus) match.isTerminus = true;
        if (raw.direction == 'retour') {
          match.sawRetour = true;
        } else {
          match.sawAller = true;
        }
        if (raw.name.length > match.name.length) match.name = raw.name;
      } else {
        final agg = _PublicStopAggregate(
          key: _stopKey(raw.position),
          position: raw.position,
          name: raw.name,
          primaryLine: raw.lineNumber,
          primaryColor: raw.color,
        );
        agg.lines.add(raw.lineNumber);
        agg.isTerminus = raw.isTerminus;
        if (raw.direction == 'retour') {
          agg.sawRetour = true;
        } else {
          agg.sawAller = true;
        }
        clusters.add(agg);
      }
    }

    // 3. Pour chaque cluster, choix de la ligne primaire (la plus
    //    importante qui le dessert) et snap final sur sa polyline.
    for (final c in clusters) {
      String? best;
      var bestRank = 1 << 30;
      for (final ln in c.lines) {
        final rank = importanceRank[ln] ?? (1 << 30);
        if (rank < bestRank) {
          bestRank = rank;
          best = ln;
        }
      }
      if (best != null) {
        final meta = svc.metadataFor(best);
        c.primaryLine = best;
        c.primaryColor = meta != null
            ? Color(meta.colorValue)
            : const Color(0xFF1565C0);
        c.basePrimaryLine = c.primaryLine;
        c.basePrimaryColor = c.primaryColor;
        final group = svc.getLineGroup(best);
        if (group != null) {
          final aller = group.aller?.coordinates ?? const <LatLng>[];
          final retour = group.retour?.coordinates ?? const <LatLng>[];
          var bestPos = c.position;
          var bestDist = double.infinity;
          if (aller.length >= 2) {
            final s = _snapToPolyline(c.position, aller);
            final d = _planarDistSq(c.position, s);
            if (d < bestDist) {
              bestDist = d;
              bestPos = s;
            }
          }
          if (retour.length >= 2) {
            final s = _snapToPolyline(c.position, retour);
            final d = _planarDistSq(c.position, s);
            if (d < bestDist) {
              bestDist = d;
              bestPos = s;
            }
          }
          c.position = bestPos;
        }
      }
    }
    _baseClusters = clusters;
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
    // m/px au zoom courant : sert à convertir les tailles ÉCRAN (traits,
    // billes, terminus, écarts de slot) en rayons/offsets géographiques.
    final mpp = _metersPerPixel(_publicMapZoom);
    // Couleur de la ligne sélectionnée (badges circulaires des arrêts en vue
    // ligne — corrige les points bleus génériques).
    final selectedColor = selected != null
        ? Color(svc.metadataFor(selected)?.colorValue ?? 0xFF1565C0)
        : null;

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
    // Stops révélés progressivement, type IDF Mobilités :
    //   zoom < 13   : aucun stop
    //   13-14.5     : points blancs avec anneau couleur ligne (= dot)
    //   14.5-15.5   : petit carré coloré avec numéro (= label)
    //   >= 15.5     : carré agrandi (= bigLabel)
    //   sélectionné/survolé : toujours largeLabel (le plus grand) en
    //                          surbrillance, quel que soit le zoom.
    // Dots blancs sur la polyline visibles dès qu'on commence à zoomer.
    // Les labels (numéro de ligne) n'apparaissent que plus haut pour ne
    // pas saturer.
    // En mode LOOM (vue réseau toutes-lignes), les billes d'arrêts sur les
    // faisceaux surchargent la carte : on ne les montre que pour la ligne
    // SÉLECTIONNÉE ou en zoom très proche (≥ [_loomStopsMinZoom], réglable
    // QA). Fallback heuristique : seuil historique 11 inchangé.
    final showStops = _strandsFromLoom
        ? (selected != null || _publicMapZoom >= _loomStopsMinZoom)
        : _publicMapZoom >= 11;
    // Pastilles n° de ligne + capsules de correspondance : cachées par défaut,
    // affichées seulement TRÈS PROCHE (≥ 16) — ou, à tout zoom, sur l'arrêt
    // cliqué/survolé (géré par la branche isActive plus bas). Les billes rondes
    // restent visibles dès showStops.
    final useLabels = _publicMapZoom >= 16;
    final useBigLabels = _publicMapZoom >= 16.5;

    // Polylines visibles : on parcourt UNIQUEMENT les groupes filtrés.
    // Le clustering des stops, lui, est pré-calculé une fois (cf.
    // _precomputeBaseClusters) et on filtre juste par lignes visibles.
    //
    // ⚠️ L'ordre d'INSERTION = l'ordre de rendu flutter_map (le zIndex des
    // Polyline n'est pas interprété par l'adaptateur). On insère donc du
    // moins prioritaire au plus prioritaire : variantes → bus par importance
    // croissante → SQUELETTE (lignes toujours affichées) en dernier. Aux
    // croisements, le prioritaire passe AU-DESSUS ; chevauchement assumé.
    final byImportance = svc.linesByImportance;
    final backboneSet = svc.backboneLines;
    final rankOf = <String, int>{
      for (var i = 0; i < byImportance.length; i++) byImportance[i]: i,
    };
    final renderOrder = byImportance.toList()
      ..sort((a, b) {
        final ba = backboneSet.contains(a), bb = backboneSet.contains(b);
        if (ba != bb) return ba ? 1 : -1; // squelette inséré en dernier
        return (rankOf[b] ?? 0).compareTo(rankOf[a] ?? 0); // moins important d'abord
      });
    // Bouts de tracé (terminus) à "fermer" par un gros point = dernier arrêt,
    // à la couleur de la ligne (dédup par position = 1ʳᵉ couleur rencontrée).
    final termCaps = <({LatLng pos, Color color, double radiusM})>[];
    final loom = LoomNetworkService.instance;
    for (final lineNumber in renderOrder) {
      // FUSION LATÉRALE des variantes (vue réseau LOOM, demande 05/06) :
      // une variante représentée par un tronc fusionné (133A → 133) ne se
      // dessine PAS elle-même ; le tronc (primaire) se dessine si AU MOINS
      // UNE variante du groupe est visible au zoom. La vue ligne
      // SÉLECTIONNÉE reste par variante (tracé brut complet, inchangé).
      if (_strandsFromLoom && selected == null) {
        if (loom.isRepresented(lineNumber)) continue; // tronc la représente
        final variants = loom.variantsOf(lineNumber);
        if (variants.length > 1
            ? !variants.any(visible.contains)
            : !visible.contains(lineNumber)) {
          continue;
        }
      } else if (!visible.contains(lineNumber)) {
        continue;
      }
      // FAST PATH : avant le chargement des GeoJSON, `group` est null mais
      // les faisceaux LOOM suffisent à dessiner les rubans (les terminus
      // et les fallbacks tracé brut attendent le chargement complet).
      final group = svc.getLineGroup(lineNumber);
      if (group == null && _strandRuns[lineNumber] == null) continue;
      final meta = svc.metadataFor(lineNumber);
      final color =
          meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
      final isSelected = selected != null;
      final tier = meta?.importanceTier ?? 2;
      final type = (meta?.transportType ?? 'bus').toLowerCase();
      final isTele = type == 'telepherique' || type == 'tele';
      final isTier1 = tier == 1;
      // Largeurs ÉCRAN CONSTANTES, style plan de réseau pro (IDFM) : le trait
      // garde la même épaisseur en pixels à tous les zooms — fini les rubans
      // géographiques qui « débordent » des rues en zoom serré. Le
      // structurant (tier 1) reste un peu plus épais que les bus.
      final double strokePx = _lineStrokePx(tier, isTele);
      final double width = isSelected ? strokePx + 2 : strokePx;
      // z-order : le SQUELETTE (lignes toujours affichées : tier 1, lettres,
      // grands axes — cf. PublicTransportService.backboneLines) passe TOUJOURS
      // au-dessus des autres lignes (5). Puis bus (2), variantes locales (1).
      // La ligne sélectionnée passe au premier plan (6). NB : le vrai rendu
      // suit l'ORDRE D'INSERTION (cf. renderOrder), le zIndex est indicatif.
      final bool isBackbone = svc.backboneLines.contains(lineNumber);
      final int baseZ = isSelected ? 6 : (isBackbone ? 5 : (tier == 2 ? 2 : 1));

      void addColored(String id, List<LatLng> pts, double w) {
        if (pts.length < 2) return;
        // Bordure NOIRE FINE sous chaque trait (~1 px de chaque côté) :
        // détoure proprement les brins côte à côte et les croisements,
        // façon plan de métro.
        polylines.add(Polyline(
          polylineId: PolylineId('pt_${lineNumber}_${id}_casing'),
          points: pts,
          color: const Color(0xFF1A1A1A),
          width: (w + 2).round(),
          zIndex: baseZ - 1,
          consumeTapEvents: false,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
        polylines.add(Polyline(
          polylineId: PolylineId('pt_${lineNumber}_$id'),
          points: pts,
          color: color,
          width: w.round(),
          zIndex: baseZ,
          consumeTapEvents: false,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
      }

      if (isSelected) {
        // Vue ligne sélectionnée : tracé brut plein, aller + retour, INCHANGÉ.
        // (group null seulement pendant le fast path, où rien n'est encore
        // sélectionné — garde de complétude.)
        if (group?.aller != null) {
          addColored('aller', group!.aller!.coordinates, width);
        }
        if (group?.retour != null) {
          addColored('retour', group!.retour!.coordinates, width);
        }
      } else {
        // VUE RÉSEAU : aller et retour fusionnés (tronc + branches, cf.
        // _precomputeMergedLines), pièces annotées d'un vecteur d'offset
        // latéral (cf. _precomputeStrandRuns) : dans les zones où ≥ 2 lignes
        // partagent l'axe, chaque ligne glisse sur SON slot (-1/0/+1) → ≤ 3
        // brins côte à côte, polylignes CONTINUES (aucun trou), croisements
        // francs (prioritaire au-dessus par ordre d'insertion).
        // Au DÉZOOM squelette (< 15), les slots LOOM (jusqu'à ±12,5 ≈ 90 px)
        // écarteraient une ligne de sa rue alors que ses voisines de corridor
        // sont masquées → tracé mergé sans offset (strands == null). Pas de
        // gate pour l'heuristique : son squelette est prioritaire au centre
        // (slot 0), aucun artefact.
        final strands = (_strandsFromLoom && _publicMapZoom < 15)
            ? null
            : _strandRuns[lineNumber];
        final trunkPx = strokePx;
        final branchPx = (strokePx * 0.7).clamp(2.5, strokePx);
        if (strands == null) {
          // Fallback (precompute pas encore prêt / tier 1 hors faisceau) :
          // tracé brut plein.
          final merged = _mergedRuns[lineNumber];
          if (merged == null) {
            if (group?.aller != null) {
              addColored('aller', group!.aller!.coordinates, width);
            }
            if (group?.retour != null) {
              addColored('retour', group!.retour!.coordinates, width);
            }
          } else {
            for (var i = 0; i < merged.trunk.length; i++) {
              addColored('trunk_$i', merged.trunk[i], trunkPx);
            }
            for (var i = 0; i < merged.allerSolo.length; i++) {
              addColored('aSolo_$i', merged.allerSolo[i], branchPx);
            }
            for (var i = 0; i < merged.retourSolo.length; i++) {
              addColored('rSolo_$i', merged.retourSolo[i], branchPx);
            }
          }
        } else {
          // Pièces (k, pts). k ≥ 2 = corridor LOOM partagé : BUDGET DE
          // LARGEUR CONTINU (remplace l'amincissement binaire 64/k) — la
          // bande totale d'un corridor est bornée à ~[_loomBandBudgetPx]
          // quel que soit k :
          //   pitch = budget/k (part de bande par brin, cœur + jour),
          //   plafonné au pas normal (cœur 5 px + jour 2) pour que k=2-5
          //   garde le rendu standard ;
          //   cœur = clamp(pitch − jour, 3, 5).
          // L'écart de slot (slotWM) suit CE pitch : tous les brins du
          // corridor partagent k → alignement bord à bord garanti.
          // k=12-15 → brins fins, bande ~40 px (au lieu de ~100).
          // k = 0 (heuristique / antennes) : largeurs et écart historiques
          // de la ligne — strictement inchangés (fallback non régressé).
          void addStrand(
              String id, ({int k, List<_StrandPt> pts}) piece, double legacyPx) {
            final bool shared = piece.k >= 2;
            if (shared) {
              const jourPx = 2.0; // bordure noire ~1 px de chaque côté
              const basePx = 5.0; // cœur d'un brin bus standard
              final double pitch =
                  (_loomBandBudgetPx / piece.k).clamp(0.0, basePx + jourPx);
              final double coeur = (pitch - jourPx).clamp(3.0, basePx);
              addColored(
                  id, _applyStrandOffset(piece.pts, pitch * mpp), coeur);
            } else {
              final double wm = (trunkPx + 2) * mpp;
              addColored(id, _applyStrandOffset(piece.pts, wm), legacyPx);
            }
          }

          for (var i = 0; i < strands.trunk.length; i++) {
            addStrand('trunk_$i', strands.trunk[i], trunkPx);
          }
          for (var i = 0; i < strands.allerSolo.length; i++) {
            addStrand('aSolo_$i', strands.allerSolo[i], branchPx);
          }
          for (var i = 0; i < strands.retourSolo.length; i++) {
            addStrand('rSolo_$i', strands.retourSolo[i], branchPx);
          }
        }
      }

      // Bouts du tracé (= les 2 terminus) à fermer par un gros point.
      // (group null pendant le fast path → caps au chargement complet.)
      final capLine = group?.aller ?? group?.retour;
      if (capLine != null && capLine.coordinates.length >= 2) {
        // Terminus un peu plus gros que le trait, en px → m au zoom courant.
        final capR = strokePx * 0.95 * mpp;
        termCaps.add((pos: capLine.coordinates.first, color: color, radiusM: capR));
        termCaps.add((pos: capLine.coordinates.last, color: color, radiusM: capR));
      }
    }

    // Stops : itère les clusters pré-calculés, garde uniquement ceux dont
    // au moins une ligne desservant est visible. Si une ligne est
    // sélectionnée, c'est elle qui devient primaire pour le rendu (couleur
    // du badge), sinon on garde la primaire pré-calculée.
    final stopsByKey = <String, _PublicStopAggregate>{};
    if (showStops) {
      for (final c in _baseClusters) {
        final hasVisibleLine = c.lines.any(visible.contains);
        if (!hasVisibleLine) continue;
        // Restaure le primaire pré-calculé puis override si une ligne est
        // actuellement sélectionnée et passe par ce cluster.
        if (c.basePrimaryLine != null) {
          c.primaryLine = c.basePrimaryLine!;
          c.primaryColor = c.basePrimaryColor!;
        }
        if (selected != null && c.lines.contains(selected)) {
          final selectedMeta = svc.metadataFor(selected);
          c.primaryLine = selected;
          c.primaryColor = selectedMeta != null
              ? Color(selectedMeta.colorValue)
              : const Color(0xFF1565C0);
        }
        stopsByKey[c.key] = c;
      }
    }

    // Génération des markers — WIDGETS purs enregistrés dans
    // _publicMarkerWidgets (l'adaptateur flutter_map ne peut pas lire les
    // BitmapDescriptor : sans widget/iconUrl, un marker tombe dans le
    // fallback POINT BLEU de gma.toFmMarkers).
    final markers = <Marker>{};
    final circles = <Circle>{};
    final hovered = _publicHoveredStop;
    _publicMarkerWidgets.clear();
    for (final agg in stopsByKey.values) {
      final isStopSelected = selectedStop == agg.key;
      final isStopHovered = !isStopSelected && hovered == agg.key;
      final isActive = isStopSelected || isStopHovered;
      // Correspondance = ≥ 2 lignes VISIBLES AU ZOOM COURANT (vue réseau).
      // Compter les lignes filtrées gonflerait le rect au dézoom alors que
      // les brins masqués n'existent plus à l'écran.
      final visibleAtStop =
          selected == null ? agg.lines.where(visible.contains).length : 0;
      final isInterchange = selected == null && visibleAtStop >= 2;

      // Le point d'arrêt doit tomber EXACTEMENT au milieu du trait : la coord.
      // brute de l'arrêt est souvent au bord de la chaussée, on la snappe donc
      // sur la polyligne réellement dessinée (ligne primaire).
      final primaryCoords = _coordsForLine(agg.primaryLine);
      final stopPos = primaryCoords.length >= 2
          ? _snapToPolyline(agg.position, primaryCoords)
          : agg.position;

      void addWidgetMarker(Widget icon,
          {required double z, double dy = 0, String idSuffix = ''}) {
        final id = 'stop_${agg.key}$idSuffix';
        _publicMarkerWidgets[id] = dy == 0
            ? icon
            : Transform.translate(offset: Offset(0, dy), child: icon);
        markers.add(Marker(
          markerId: MarkerId(id),
          position: stopPos,
          anchor: const Offset(0.5, 0.5),
          zIndex: z,
          consumeTapEvents: true,
          onTap: () => _onPublicStopTap(agg),
        ));
      }

      // VUE LIGNE SÉLECTIONNÉE : chaque arrêt = badge CIRCULAIRE couleur de
      // la ligne + bordure blanche + numéro court centré (3 chiffres sans
      // suffixe, initiale pour les lignes nommées : MAHITSY → M). Remplace
      // billes/badges génériques.
      if (selected != null) {
        addWidgetMarker(
          _circleStopBadge(
            _shortLineLabel(selected),
            selectedColor ?? agg.primaryColor,
            big: isActive,
          ),
          z: isActive ? 100 : 20,
        );
        continue;
      }

      // CORRESPONDANCE (vue réseau) : rectangle blanc bords arrondis posé en
      // travers du faisceau, dimensionné par le nb de brins connectés —
      // remplace la bille. La capsule des numéros flotte au-dessus au zoom
      // élevé. Survol : rect agrandi + mini-carte ; clic : fiche complète.
      if (isInterchange) {
        final bearing = _bearingAtPointOnPolyline(stopPos, primaryCoords);
        addWidgetMarker(
          _interchangeRectBadge(visibleAtStop,
              bearingDeg: bearing, big: isActive),
          z: isActive ? 90 : 15,
        );
        if (!isActive && useLabels) {
          addWidgetMarker(
            _lineCapsuleBadge(agg.lines.toList()..sort(), big: useBigLabels),
            z: 30,
            dy: -16,
            idSuffix: '_cap',
          );
        }
        continue;
      }

      final dotMeta = svc.metadataFor(agg.primaryLine);
      final dotType = (dotMeta?.transportType ?? 'bus').toLowerCase();
      final dotTele = dotType == 'telepherique' || dotType == 'tele';
      // Bille proportionnelle au trait (px constants → m au zoom courant).
      final beadRadiusM =
          _lineStrokePx(dotMeta?.importanceTier ?? 2, dotTele) * 0.62 * mpp;
      // Survol/sélection : la bille grossit (feedback immédiat sous le
      // curseur, style IDFM) et passe au-dessus de ses voisines.
      circles.add(Circle(
        circleId: CircleId('dot_${agg.key}'),
        center: stopPos,
        radius: isActive ? beadRadiusM * 1.7 : beadRadiusM,
        fillColor: Colors.white,
        strokeColor: agg.primaryColor,
        strokeWidth: isActive ? 3 : 2,
        zIndex: isActive ? 9 : 8,
        consumeTapEvents: true,
        onTap: () => _onPublicStopTap(agg),
      ));

      // Arrêt survolé (non cliqué) : pas de badge flotté — la bille grossie
      // + la mini-carte overlay (cf. StopMiniCard dans le Stack du build)
      // suffisent. La fiche complète (StopCard) ne s'ouvre qu'au clic.
      if (isStopHovered) continue;

      // Arrêt sélectionné (clic) : badge circulaire agrandi de la ligne
      // primaire, posé sur le point.
      if (isStopSelected) {
        addWidgetMarker(
          _circleStopBadge(
            _shortLineLabel(agg.primaryLine),
            agg.primaryColor,
            big: true,
          ),
          z: 100,
        );
        continue;
      }

      // Terminus : badge numéro flotté au-dessus du point (le rond reste).
      if (useLabels && agg.isTerminus) {
        addWidgetMarker(
          _lineCapsuleBadge([agg.primaryLine], big: useBigLabels),
          z: 10,
          dy: -12,
        );
      }
    }

    // Caps de terminus : un gros point au bout de chaque tracé pour le fermer
    // (= dernier arrêt). Dédupliqués par position (terminus partagés).
    if (showStops && termCaps.isNotEmpty) {
      final seenCaps = <String>{};
      for (final cap in termCaps) {
        final pos = cap.pos;
        final ck =
            '${pos.latitude.toStringAsFixed(5)}_${pos.longitude.toStringAsFixed(5)}';
        if (!seenCaps.add(ck)) continue;
        // Terminus = grosse bille géographique PLEINE couleur de la ligne +
        // cœur blanc (2 Circle concentriques, mètres → scalent avec le zoom).
        circles.add(Circle(
          circleId: CircleId('termcap_${ck}_outer'),
          center: pos,
          radius: cap.radiusM,
          fillColor: cap.color,
          strokeColor: Colors.white,
          strokeWidth: 2,
          zIndex: 12,
          consumeTapEvents: false,
        ));
        circles.add(Circle(
          circleId: CircleId('termcap_${ck}_core'),
          center: pos,
          radius: cap.radiusM * 0.42,
          fillColor: Colors.white,
          strokeColor: Colors.white,
          strokeWidth: 0,
          zIndex: 13,
          consumeTapEvents: false,
        ));
      }
    }

    // Flèches de sens : uniquement pour la ligne sélectionnée (révèle ses
    // boucles / tronçons à sens unique sans saturer la vue réseau).
    if (selected != null) {
      final group = svc.getLineGroup(selected);
      if (group != null) {
        final selMeta = svc.metadataFor(selected);
        final arrowColor = selMeta != null
            ? Color(selMeta.colorValue)
            : const Color(0xFF1565C0);
        markers.addAll(_buildDirectionArrows(group, arrowColor));
      }
    }

    if (!mounted) return;
    setState(() {
      _publicTransportPolylines = polylines;
      _publicTransportMarkers = markers;
      _publicTransportCircles = circles;
      _publicStopsByKey = stopsByKey;
    });
    // Refresh le cache écran après le rebuild — sinon le hover réagirait
    // sur des stops qui n'existent plus (filtre zoom changé, sélection).
    _refreshPublicStopScreenCache();
  }

  /// Cap (bearing nord-horaire) du segment de polyligne le plus proche du
  /// point — utilisé pour orienter le tiret d'arrêt perpendiculairement au
  /// tracé.
  double _bearingAtPointOnPolyline(LatLng p, List<LatLng> poly) {
    if (poly.length < 2) return 0;
    var bestD = double.infinity;
    var bi = 0;
    for (var i = 0; i < poly.length - 1; i++) {
      final s = _closestPointOnSegment(p, poly[i], poly[i + 1]);
      final d = _planarDistSq(p, s);
      if (d < bestD) {
        bestD = d;
        bi = i;
      }
    }
    return _bearingBetween(
        poly[bi].latitude, poly[bi].longitude,
        poly[bi + 1].latitude, poly[bi + 1].longitude);
  }

  /// Coordonnées du tracé d'une ligne (aller si dispo, sinon retour) — sert à
  /// calculer le cap local d'un arrêt et à snapper le point sur le trait.
  List<LatLng> _coordsForLine(String line) {
    final g = PublicTransportService.instance.getLineGroup(line);
    if (g?.aller?.coordinates.isNotEmpty ?? false) return g!.aller!.coordinates;
    return g?.retour?.coordinates ?? const <LatLng>[];
  }

  /// Flèches de sens pour la ligne SÉLECTIONNÉE : on pose des chevrons le long
  /// des tronçons parcourus dans un seul sens (= portions de l'aller éloignées
  /// du retour, et inversement). Sur les tronçons à double sens (aller/retour
  /// superposés) on n'en met pas, pour éviter des flèches opposées illisibles.
  /// Révèle les boucles et sens uniques, style M réso.
  List<Marker> _buildDirectionArrows(TransportLineGroup group, Color color) {
    final markers = <Marker>[];
    const divergeThreshM = 25.0; // au-delà : tronçon à sens unique
    const stepM = 170.0; // espacement entre 2 flèches

    void addFor(List<LatLng> path, List<LatLng> other, String dir) {
      if (path.length < 2) return;
      var sinceLast = stepM; // pose une flèche dès le 1er point éligible
      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        sinceLast += _metersBetween(a, b);
        final isOneWay = other.length < 2 ||
            _metersBetween(a, _snapToPolyline(a, other)) > divergeThreshM;
        if (isOneWay && sinceLast >= stepM) {
          final bearing =
              _bearingBetween(a.latitude, a.longitude, b.latitude, b.longitude);
          // WIDGET pur + Marker.rotation : l'adaptateur flutter_map ne lit
          // pas les BitmapDescriptor (ex-createArrow → fallback POINT BLEU,
          // vécu 05/06/2026) mais applique Transform.rotate depuis
          // `rotation` sur les iconWidgets enregistrés.
          final id = 'arrow_${group.lineNumber}_${dir}_$i';
          _publicMarkerWidgets[id] = Center(
            child: SizedBox(
              width: 15,
              height: 15,
              child: CustomPaint(painter: _ArrowGlyphPainter(color)),
            ),
          );
          markers.add(Marker(
            markerId: MarkerId(id),
            position: a,
            rotation: bearing,
            anchor: const Offset(0.5, 0.5),
            zIndex: 7,
            consumeTapEvents: false,
          ));
          sinceLast = 0;
        }
      }
    }

    addFor(group.aller?.coordinates ?? const [],
        group.retour?.coordinates ?? const [], 'aller');
    addFor(group.retour?.coordinates ?? const [],
        group.aller?.coordinates ?? const [], 'retour');
    return markers;
  }

  /// Construit le marker "pôle de correspondance" : une capsule listant
  /// toutes les lignes passant par le cluster (triées par importance), style
  /// M réso. Au tap, ouvre la même card que les arrêts simples.
  Future<Marker> _buildPublicPoleMarker(
      _PublicStopAggregate agg, double dpr, bool big) async {
    final svc = PublicTransportService.instance;
    final byImportance = svc.linesByImportance;
    final rank = <String, int>{
      for (var i = 0; i < byImportance.length; i++) byImportance[i]: i,
    };
    final ordered = agg.lines.toList()
      ..sort((a, b) =>
          (rank[a] ?? 1 << 30).compareTo(rank[b] ?? 1 << 30));
    final entries = [
      for (final ln in ordered)
        (
          label: ln,
          color: Color(svc.metadataFor(ln)?.colorValue ?? 0xFF1565C0),
        ),
    ];
    final icon = await StopMarkerFactory.createPole(
      lines: entries,
      devicePixelRatio: dpr,
      big: big,
    );
    return Marker(
      markerId: MarkerId('pole_${agg.key}'),
      position: agg.position,
      icon: icon,
      // Capsule de badges flottée AU-DESSUS du nœud (anchor bas), pour ne pas
      // masquer le point d'arrêt ni les lignes.
      anchor: const Offset(0.5, 1.25),
      zIndex: 30,
      consumeTapEvents: true,
      onTap: () => _onPublicStopTap(agg),
    );
  }

  /// Tap sur un stop : on l'agrandit + on affiche la card flottante ancrée
  /// juste au-dessus du marker.
  void _onPublicStopTap(_PublicStopAggregate agg) {
    setState(() => _publicSelectedStop = agg.key);
    _rebuildPublicTransportLayers();
    _updateSelectedStopScreenPos();
  }

  void _dismissPublicStopCard() {
    setState(() {
      _publicSelectedStop = null;
      _publicSelectedStopScreenPos = null;
    });
    _rebuildPublicTransportLayers();
  }

  /// Convertit la LatLng du stop sélectionné en pixel-écran via le controller
  /// de carte. Utilisé pour ancrer la card style IDFM au-dessus du marker.
  /// Asynchrone (le canal Flutter↔JS du plugin) — on schedule un setState
  /// quand le résultat arrive.
  Future<void> _updateSelectedStopScreenPos() async {
    final key = _publicSelectedStop;
    if (key == null || _mapController == null) return;
    final agg = _publicStopsByKey[key];
    if (agg == null) return;
    try {
      // flutter_map : projection synchrone en pixels LOGIQUES (pas de /dpr).
      final pt =
          _mapController!.camera.latLngToScreenPoint(gma.toLL(agg.position));
      if (!mounted || _publicSelectedStop != key) return;
      setState(() {
        _publicSelectedStopScreenPos = Offset(pt.x, pt.y);
      });
    } catch (_) {
      // Si le controller n'est pas prêt ou que la carte n'a pas été rendue,
      // on laisse la card masquée — _publicSelectedStopScreenPos reste null.
    }
  }

  /// Recalcule la position écran de chaque stop visible. Utilisé par la
  /// détection de hover pour trouver le marker le plus proche du curseur
  /// sans payer un getScreenCoordinate par stop (300 appels async).
  ///
  /// Approche : 1 appel async pour récupérer les bounds de la carte, puis
  /// interpolation linéaire en lat/lng → pixels. Imprécise sur projection
  /// Mercator à grande échelle, mais largement suffisante pour détecter le
  /// stop sous le curseur (zone de 14px autour).
  Future<void> _refreshPublicStopScreenCache() async {
    if (_homeMode != HomeMode.publicTransport ||
        _mapController == null ||
        _publicMapAreaSize == Size.zero ||
        _publicStopsByKey.isEmpty) {
      return;
    }
    try {
      final bounds = _mapController!.camera.visibleBounds;
      if (!mounted) return;
      final south = bounds.southWest.latitude;
      final north = bounds.northEast.latitude;
      final west = bounds.southWest.longitude;
      final east = bounds.northEast.longitude;
      final dLat = north - south;
      final dLng = east - west;
      if (dLat == 0 || dLng == 0) return;
      final w = _publicMapAreaSize.width;
      final h = _publicMapAreaSize.height;

      _publicStopScreenPositions.clear();
      for (final entry in _publicStopsByKey.entries) {
        final p = entry.value.position;
        final x = (p.longitude - west) / dLng * w;
        final y = (north - p.latitude) / dLat * h;
        _publicStopScreenPositions[entry.key] = Offset(x, y);
      }
    } catch (_) {}
  }

  /// Curseur survole la zone carte. On cherche le stop le plus proche dans
  /// le cache écran. Si on a basculé d'aucun → 1 stop ou inversement, on
  /// reconstruit les markers pour appliquer le style hover (largeLabel).
  void _handlePublicMapHover(Offset position) {
    if (_publicStopScreenPositions.isEmpty) return;
    const hoverRadius = 14.0;
    String? closest;
    var bestDist = hoverRadius;
    for (final entry in _publicStopScreenPositions.entries) {
      final dx = entry.value.dx - position.dx;
      final dy = entry.value.dy - position.dy;
      final d = sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        closest = entry.key;
      }
    }
    if (closest != _publicHoveredStop) {
      setState(() => _publicHoveredStop = closest);
      _rebuildPublicTransportLayers();
    }
  }

  void _clearPublicMapHover() {
    if (_publicHoveredStop == null) return;
    setState(() => _publicHoveredStop = null);
    _rebuildPublicTransportLayers();
  }

  static String _stopKey(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

  /// Normalise un nom d'arrêt pour comparaison de clustering : trim,
  /// lowercase, suppression des accents et de la ponctuation/espaces
  /// multiples. Permet de détecter "Ankadifotsy" / "ankadifotsy " /
  /// "Ankadifotsy " comme le même arrêt conceptuel.
  static String _normalizeStopName(String name) {
    var s = name.trim().toLowerCase();
    if (s.isEmpty) return s;
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final buf = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Projette [p] sur la polyline la plus proche et renvoie le point
  /// résultant. Utilisé pour aligner visuellement le marker d'arrêt sur le
  /// trait de la ligne (les coords GeoJSON peuvent flotter d'un mètre ou
  /// deux par rapport au tracé routier OSRM).
  static LatLng _snapToPolyline(LatLng p, List<LatLng> polyline) {
    if (polyline.length < 2) return p;
    var best = polyline.first;
    var bestDistSq = _planarDistSq(p, polyline.first);
    for (var i = 0; i < polyline.length - 1; i++) {
      final c = _closestPointOnSegment(p, polyline[i], polyline[i + 1]);
      final d = _planarDistSq(p, c);
      if (d < bestDistSq) {
        bestDistSq = d;
        best = c;
      }
    }
    return best;
  }

  /// Approximation plane (degrés² × cos(lat)) — suffisante pour comparer
  /// des distances entre points à la même latitude. Évite Haversine dans
  /// la boucle hot du snap.
  static double _planarDistSq(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = (a.longitude - b.longitude) *
        cos(a.latitude * pi / 180.0);
    return dLat * dLat + dLng * dLng;
  }

  static LatLng _closestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return a;
    var t = ((p.longitude - a.longitude) * dx +
            (p.latitude - a.latitude) * dy) /
        lenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    return LatLng(a.latitude + t * dy, a.longitude + t * dx);
  }

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

  /// Reagit au déplacement de caméra : tracking de zoom pour le filtrage +
  /// reposition de la card de stop si elle est visible. Recompute les
  /// couches uniquement quand on franchit un seuil entier (évite les
  /// rebuilds frame-rate pendant le pinch).
  void _onPublicCameraMove(fm.MapCamera pos) {
    // Mémorise la position connue dans les 2 modes pour pouvoir la
    // restaurer au switch (cf. _setHomeMode).
    _lastKnownCamera = pos;
    if (_homeMode != HomeMode.publicTransport) return;
    final newZoom = pos.zoom;
    // Pas de 0,5 niveau : assez fin pour que la largeur des traits (en mètres
    // → px) suive le zoom de façon fluide, sans rebuild à chaque micro-mouvement.
    final crossedZoomThreshold =
        (newZoom * 2).floor() != (_publicMapZoom * 2).floor() ||
            (newZoom >= 16) != (_publicMapZoom >= 16) ||
            (newZoom >= 16.5) != (_publicMapZoom >= 16.5);
    _publicMapZoom = newZoom;
    if (crossedZoomThreshold) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _homeMode == HomeMode.publicTransport) {
          _rebuildPublicTransportLayers();
        }
      });
    }
    // Si l'utilisateur a une card de stop ouverte, on la fait suivre le
    // marker pendant le pan/zoom.
    if (_publicSelectedStop != null) {
      _updateSelectedStopScreenPos();
    }
  }

  /// Zoom la caméra sur les bounds d'une ligne donnée (aller + retour),
  /// dans la ZONE VISIBLE de la carte : le panel TC (Positioned left:16,
  /// largeur 320) masque la gauche de l'écran — sans padding asymétrique,
  /// l'extrémité ouest des lignes Est-Ouest finissait sous le panel.
  /// Sur écran étroit (panel quasi pleine largeur), fallback symétrique.
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
    const panelRightEdge = 16.0 + 320.0; // left inset + largeur du panel
    final screenW = MediaQuery.of(context).size.width;
    final wideEnough = screenW - panelRightEdge > 360;
    final padding = wideEnough
        ? const EdgeInsets.fromLTRB(panelRightEdge + 32, 72, 48, 56)
        : const EdgeInsets.all(48);
    _mapController?.fitCamera(
      fm.CameraFit.bounds(
        bounds: fm.LatLngBounds(
          ll.LatLng(maxLat, maxLng),
          ll.LatLng(minLat, minLng),
        ),
        padding: padding,
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

  Widget _buildSearchCard() {
    final locale = context.watch<LocaleProvider>().locale;
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

                // Toggle Course / Transport en commun, intégré dans la
                // sidebar (plus d'overlay flottant).
                HomeModeToggle(
                  current: _homeMode,
                  onChanged: _setHomeMode,
                ),

                const SizedBox(height: 16),

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
                                        : Text(
                                            TransitStrings.t('web.order', locale),
                                            style: const TextStyle(
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
    return Container(
      decoration: BoxDecoration(
        // Style Apple - fond léger
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
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
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  letterSpacing: -0.2,
                  color: Color(0xFF86868B),
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

          // Bouton « choisir au pin » : entre en mode sélection (la carte se
          // déplace librement sous le bonhomme, validation par le CTA
          // « Confirmer le lieu… »). Rouge quand la sélection est active.
          Tooltip(
            message: 'Choisir le point sous le pin',
            child: Material(
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
                    color: _pinSelectingPickup == isPickup
                        ? const Color(0xFFFF5357)
                        : const Color(0xFF86868B),
                  ),
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

  /// Entre en mode « sélection au pin » pour le champ demandé : l'utilisateur
  /// déplace la carte librement sous le bonhomme, puis valide via le bouton
  /// flottant « Confirmer le lieu… ». Re-cliquer le même bouton annule.
  void _startMapSelection(bool isPickup) {
    setState(() {
      if (_pinSelectingPickup == isPickup) {
        _exitPinSelection(); // re-clic = annule (et revient en vue plan)
      } else {
        _pinSelectingPickup = isPickup;
      }
    });
    // Aperçu immédiat de l'adresse du point courant (sans attendre un
    // premier déplacement) — le seuil 5 m est neutralisé pour ce settle.
    if (_pinSelectingPickup != null) {
      _lastPinSettle = null;
      _schedulePinSettle();
    }
  }

  /// CTA flottant du mode sélection au pin : « Confirmer le lieu de prise en
  /// charge / de dépose » + croix d'annulation. Désactivé hors zone couverte
  /// (« Zone non desservie » déjà affichée sous le pin).
  Widget _buildPinConfirmBar() {
    final isPickup = _pinSelectingPickup ?? true;
    final enabled = _pinZoneCovered;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 18),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bascule plan ↔ satellite : placement précis du pin (toits,
              // portails… mieux lisibles en imagerie Esri).
              Tooltip(
                message: _currentMapType == MapType.satellite
                    ? 'Vue plan'
                    : 'Vue satellite',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() {
                      _currentMapType = _currentMapType == MapType.satellite
                          ? MapType.normal
                          : MapType.satellite;
                    }),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Icon(
                        _currentMapType == MapType.satellite
                            ? Icons.map_outlined
                            : Icons.satellite_alt_outlined,
                        size: 18,
                        color: const Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: enabled
                    ? const Color(0xFFFF5357)
                    : const Color(0xFFC7C7CC),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: enabled ? _confirmPinSelection : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    child: Text(
                      isPickup
                          ? 'Confirmer le lieu de prise en charge'
                          : 'Confirmer le lieu de dépose',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(_exitPinSelection),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child:
                        Icon(Icons.close, size: 18, color: Color(0xFF86868B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sort du mode sélection au pin : annule la sélection en cours et
  /// revient en vue plan (le satellite ne sert qu'au placement précis).
  /// À appeler DANS un setState.
  void _exitPinSelection() {
    _pinSelectingPickup = null;
    _currentMapType = MapType.normal;
  }

  /// Valide le point GPS situé sous le pin central (centre de la carte)
  /// comme adresse du champ en cours de sélection. Inactif hors zone
  /// couverte (le bouton est déjà désactivé, ceinture-bretelles).
  void _confirmPinSelection() {
    final isPickup = _pinSelectingPickup;
    if (isPickup == null || !_pinZoneCovered || _mapController == null) return;
    final center = _mapController!.camera.center;
    setState(_exitPinSelection);
    _setLocationFromLatLng(
        LatLng(center.latitude, center.longitude), isPickup);
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
      });

      // Centrer la carte sur le point
      _mapController?.move(gma.toLL(latLng), 15);
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
      });
    }
  }

  /// Reverse geocoding configurable Google/Nominatim (Levier F audit GCP).
  /// Cascade par étape configurée dans Firestore `setting/geocoding_config`
  /// (step `web.mapClick`). Modifiable depuis le dashboard /admin/settings.
  Future<String> _reverseGeocode(LatLng latLng) async {
    try {
      return await ReverseGeocoder.instance.reverseGeocode(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        step: 'web.mapClick',
      );
    } catch (e) {
      debugPrint('Erreur reverse geocoding (web.mapClick): $e');
      return '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
    }
  }

  /// Liste de suggestions étendue style Apple Maps (prend tout l'espace disponible)
  /// En-tête de section style Apple
  Widget _buildScheduleOptions() {
    final locale = context.watch<LocaleProvider>().locale;
    final isScheduled = _scheduledDateTime != null;
    final displayText = isScheduled
        ? _formatScheduledDateTime(_scheduledDateTime!)
        // Hors Antananarivo (book.misy.app) : pas de « Maintenant », invite à
        // choisir un créneau de réservation à l'avance.
        : (_forceScheduledOnly
            ? TransitStrings.t('web.chooseSlot', locale)
            : 'Maintenant');

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
                  // Le « X » (retour à Maintenant) est masqué en zone planifié-only.
                  if (isScheduled && !_forceScheduledOnly)
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
        // Bandeau d'explication hors Antananarivo : réservation à l'avance.
        if (_forceScheduledOnly)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Color(0xFF86868B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    TransitStrings.t('web.scheduledOnlyNotice', locale),
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: Color(0xFF86868B),
                    ),
                  ),
                ),
              ],
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
        allowImmediate: !_forceScheduledOnly,
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

      // Passer à l'étape de sélection de véhicule (+ geozone du pickup :
      // filtre catégories + tarifs de zone, comme la riderapp)
      _refreshZoneVehicles(tripProvider);
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
        _mapController?.fitCamera(
          fm.CameraFit.bounds(
              bounds: gma.toLLBounds(bounds),
              padding: _routeFitPadding()),
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
  // false hors Antananarivo (book.misy.app) : masque l'option « Maintenant ».
  final bool allowImmediate;

  const _SchedulePickerDialog({
    this.initialDateTime,
    required this.onConfirm,
    required this.onImmediate,
    this.allowImmediate = true,
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
    final locale = context.watch<LocaleProvider>().locale;
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

            // Option immédiate (masquée hors Antananarivo : instant interdit)
            if (widget.allowImmediate) ...[
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
            ],

            // Sélecteur de date
            Text(TransitStrings.t('web.date', locale),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildDateSelector(),

            const SizedBox(height: 16),

            // Sélecteur d'heure
            Text(TransitStrings.t('web.time', locale),
                style: const TextStyle(fontWeight: FontWeight.w500)),
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
                child: Text(TransitStrings.t('web.scheduleRide', locale)),
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

/// Point densifié d'un tracé + cap local (consolidation tronc commun).
class _TrunkSample {
  final LatLng pos;
  final double bearing;
  const _TrunkSample(this.pos, this.bearing);
}

/// Entrée de l'index grille pour la détection des tronçons partagés.
class _TrunkGridEntry {
  final String key; // '${lineNumber}_${dir}'
  final double bearing;
  final LatLng pos;
  const _TrunkGridEntry(this.key, this.bearing, this.pos);
}

/// Point d'une pièce de tracé "faisceau-ready" : position de base + vecteur
/// latéral unitaire×slot (espace mètres, lissé — cf. _precomputeStrandRuns).
/// Offset réel au rebuild : pos + (vLat, vLng) × largeur de brin au zoom.
class _StrandPt {
  final LatLng pos;
  final double vLat;
  final double vLng;
  const _StrandPt(this.pos, this.vLat, this.vLng);
}

/// Stop "brut" en sortie d'un GeoJSON, avant clustering par proximité.
class _RawStop {
  final LatLng position;
  final String name;
  final String lineNumber;
  final Color color;

  /// Vrai si c'est le 1er ou le dernier arrêt de la ligne (terminus).
  final bool isTerminus;

  /// 'aller' | 'retour' — sert à savoir si le cluster est desservi dans un
  /// seul sens (demi-tiret) ou les deux (tiret plein).
  final String direction;

  const _RawStop({
    required this.position,
    required this.name,
    required this.lineNumber,
    required this.color,
    required this.direction,
    this.isTerminus = false,
  });
}

/// Aggregate utilisé pour dédupliquer les arrêts du réseau public sur la carte.
/// Plusieurs lignes peuvent desservir le même point — et l'aller / le retour
/// d'une même ligne sont souvent à 15-30m l'un de l'autre. On clusterise dans
/// un rayon de 35m (cf. `_metersBetween`) → 1 seul marker.
class _PublicStopAggregate {
  final String key;
  /// Position du marker. Initialement = position du 1er stop matché lors du
  /// clustering. Ensuite re-snappée sur la polyline de la [primaryLine] pour
  /// que le marker tombe pile au centre du trait coloré rendu.
  LatLng position;
  String name;
  /// Ligne primaire et couleur ACTUELLES (peuvent être overridées au rebuild
  /// si une ligne est sélectionnée).
  String primaryLine;
  Color primaryColor;
  /// Snapshot fixé au pré-calcul, restauré à chaque rebuild si plus rien
  /// n'est sélectionné. Évite que la sélection précédente "colle".
  String? basePrimaryLine;
  Color? basePrimaryColor;
  final Set<String> lines = <String>{};

  /// Vrai si ce cluster est le terminus (1er/dernier arrêt) d'au moins une
  /// ligne. Sert au déclutter : seuls terminus + correspondances portent un
  /// numéro en vue réseau (style M réso).
  bool isTerminus = false;

  /// Sens observés sur ce cluster. `sawAller && sawRetour` → arrêt 2 sens
  /// (tiret plein) ; un seul → arrêt 1 sens (demi-tiret).
  bool sawAller = false;
  bool sawRetour = false;
  bool get twoWay => sawAller && sawRetour;

  _PublicStopAggregate({
    required this.key,
    required this.position,
    required this.name,
    required this.primaryLine,
    required this.primaryColor,
  });
}

/// Chevron de sens (15×15, pointe vers le haut) — même géométrie que
/// l'ex-`StopMarkerFactory.createArrow`, mais en widget pur : la rotation
/// vers le cap est appliquée par l'adaptateur via `Marker.rotation`.
class _ArrowGlyphPainter extends CustomPainter {
  final Color color;
  const _ArrowGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final r = size.width * 0.36;
    final path = Path()
      ..moveTo(0, -r)
      ..lineTo(r * 0.95, r * 0.55)
      ..lineTo(0, r * 0.16)
      ..lineTo(-r * 0.95, r * 0.55)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
