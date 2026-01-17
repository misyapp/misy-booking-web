import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/route_service.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:http/http.dart' as http;

class LiveShareViewerScreen extends StatefulWidget {
  final String rideId;
  final String token;

  const LiveShareViewerScreen({
    Key? key,
    required this.rideId,
    required this.token,
  }) : super(key: key);

  @override
  State<LiveShareViewerScreen> createState() => _LiveShareViewerScreenState();
}

class _LiveShareViewerScreenState extends State<LiveShareViewerScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _isLoading = true;
  bool _isConnected = false;
  String _errorMessage = '';
  Map<String, dynamic>? _rideData;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _riderData; // Données du passager (fallback si pas dans booking)
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _refreshTimer;

  // 🚗 Markers personnalisés
  BitmapDescriptor? _vehicleMarkerIcon;
  BitmapDescriptor? _pickupMarkerIcon;    // Rond vert pour départ
  BitmapDescriptor? _destinationMarkerIcon; // Carré rouge pour arrivée
  bool _routeLoaded = false;
  bool _isUpdatingMap = false; // Debounce flag
  bool _userHasMovedMap = false; // Track if user has manually moved the map
  bool _isProgrammaticCameraMove = false; // Pour distinguer les mouvements programmés vs utilisateur

  // 📍 Trajet parcouru par le chauffeur
  final List<LatLng> _driverPathPoints = [];
  LatLng? _lastDriverPosition;
  LatLng? _lastRouteCalculationPosition; // Pour recalcul de route sur déviation
  double _driverBearing = 0.0; // Orientation du véhicule en degrés

  // 💫 Animation pulsation pour la photo du passager
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  // 🫧 Liquid Glass bottom sheet state - 3 états
  // 0 = collapsed (petite bulle), 1 = intermediate (bulle flottante), 2 = expanded (full)
  int _sheetState = 1; // Commence en état intermédiaire
  double _sheetExtent = 0.5; // 0.0 = collapsed, 0.5 = intermediate, 1.0 = expanded
  final double _collapsedHeight = 80.0;
  final double _expandedHeightRatio = 0.90; // 90% de l'écran

  @override
  void initState() {
    super.initState();

    // Initialiser l'animation de pulsation
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadCustomMarkers();
    _initializeLiveShare();
  }

  /// Charge les icônes personnalisées pour départ et arrivée
  Future<void> _loadCustomMarkers() async {
    _pickupMarkerIcon = await _createCircleMarker(Colors.black);
    _destinationMarkerIcon = await _createSquareMarker(Colors.black);
    if (mounted) setState(() {});
  }

  /// Applique le style de carte (light/dark mode)
  Future<void> _setMapStyle() async {
    if (_mapController == null) return;

    try {
      // Vérifier le thème actuel
      bool isDarkMode = Provider.of<DarkThemeProvider>(context, listen: false).darkTheme;

      // Charger le style depuis les assets
      String mapStyle = await DefaultAssetBundle.of(context).loadString(
        isDarkMode
            ? 'assets/map_styles/dark_mode.json'
            : 'assets/map_styles/light_mode.json',
      );

      // Appliquer le style
      _mapController!.setMapStyle(mapStyle);
      myCustomPrintStatement('🗺️ Style de carte appliqué: ${isDarkMode ? "dark" : "light"}');
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur application style carte: $e');
    }
  }

  /// Crée un marker rond (pour le départ)
  Future<BitmapDescriptor> _createCircleMarker(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 40;

    // Cercle extérieur
    final Paint outerPaint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, outerPaint);

    // Cercle intérieur blanc
    final Paint innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 3, innerPaint);

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Crée un marker carré (pour la destination)
  Future<BitmapDescriptor> _createSquareMarker(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 36;
    const double cornerRadius = 4;

    // Carré avec coins arrondis
    final Paint squarePaint = Paint()..color = color;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size, size),
      const Radius.circular(cornerRadius),
    );
    canvas.drawRRect(rrect, squarePaint);

    // Carré intérieur blanc
    final Paint innerPaint = Paint()..color = Colors.white;
    final RRect innerRrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size * 0.25, size * 0.25, size * 0.5, size * 0.5),
      const Radius.circular(2),
    );
    canvas.drawRRect(innerRrect, innerPaint);

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Charge l'icône du véhicule depuis le marker de la catégorie
  Future<void> _loadVehicleMarkerIcon() async {
    if (_rideData == null) {
      myCustomPrintStatement("🚗 _loadVehicleMarkerIcon: rideData est null");
      return;
    }

    try {
      String? vehicleMarkerUrl;

      myCustomPrintStatement("🚗 _loadVehicleMarkerIcon: Recherche du marker...");
      myCustomPrintStatement("🚗 rideData keys: ${_rideData!.keys.toList()}");

      // Priorité 1: utiliser le marker depuis selectedVehicle de la course
      if (_rideData!['selectedVehicle'] != null) {
        final selectedVehicle = _rideData!['selectedVehicle'];
        myCustomPrintStatement("🚗 selectedVehicle trouvé: $selectedVehicle");
        if (selectedVehicle is Map) {
          // Utiliser le champ 'marker' (pas 'image') comme dans trip_provider
          vehicleMarkerUrl = selectedVehicle['marker'] as String?;
          myCustomPrintStatement("🚗 selectedVehicle['marker']: $vehicleMarkerUrl");

          // Fallback sur 'image' si 'marker' n'existe pas
          if (vehicleMarkerUrl == null || vehicleMarkerUrl.isEmpty) {
            vehicleMarkerUrl = selectedVehicle['image'] as String?;
            myCustomPrintStatement("🚗 Fallback selectedVehicle['image']: $vehicleMarkerUrl");
          }
        }
      }

      // Priorité 2: Chercher dans vehicleListModal (si disponible)
      if ((vehicleMarkerUrl == null || vehicleMarkerUrl.isEmpty) && vehicleListModal.isNotEmpty) {
        String? vehicleId = _rideData!['vehicleId'] ?? _rideData!['vehicle'];
        myCustomPrintStatement("🚗 Recherche par vehicleId=$vehicleId, vehicleListModal.length=${vehicleListModal.length}");
        if (vehicleId != null) {
          try {
            final vehicle = vehicleListModal.firstWhere(
              (v) => v.id == vehicleId || v.name == vehicleId,
              orElse: () => vehicleListModal.first,
            );
            vehicleMarkerUrl = vehicle.marker;
            myCustomPrintStatement("🚗 marker trouvé dans vehicleListModal: $vehicleMarkerUrl");
          } catch (e) {
            myCustomPrintStatement("⚠️ vehicleListModal.firstWhere error: $e");
          }
        }
      }

      // Priorité 3: Récupérer le marker depuis Firestore directement
      if ((vehicleMarkerUrl == null || vehicleMarkerUrl.isEmpty)) {
        String? vehicleId = _rideData!['vehicleId'] ?? _rideData!['vehicle'];
        if (vehicleId != null) {
          myCustomPrintStatement("🚗 Récupération marker depuis Firestore pour vehicleId=$vehicleId");
          try {
            final vehicleDoc = await FirebaseFirestore.instance
                .collection('vehicles')
                .doc(vehicleId)
                .get();
            if (vehicleDoc.exists) {
              final vehicleData = vehicleDoc.data()!;
              vehicleMarkerUrl = vehicleData['marker'] as String? ?? vehicleData['image'] as String?;
              myCustomPrintStatement("🚗 marker depuis Firestore: $vehicleMarkerUrl");
            }
          } catch (e) {
            myCustomPrintStatement("⚠️ Erreur récupération marker Firestore: $e");
          }
        }
      }

      myCustomPrintStatement("🚗 vehicleMarkerUrl final: $vehicleMarkerUrl");

      // Charger l'image du marker
      if (vehicleMarkerUrl != null && vehicleMarkerUrl.isNotEmpty) {
        _vehicleMarkerIcon = await _createMarkerFromNetworkImage(vehicleMarkerUrl);
        myCustomPrintStatement("✅ Icône marker véhicule chargée depuis URL");
      } else {
        myCustomPrintStatement("⚠️ Pas de marker URL, utilisation marker cyan par défaut");
        _vehicleMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      }

      if (mounted) setState(() {});
    } catch (e) {
      myCustomPrintStatement("❌ Erreur chargement icône véhicule: $e");
      _vehicleMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
  }

  /// Crée un marker depuis une image réseau (comme dans google_map_provider)
  Future<BitmapDescriptor> _createMarkerFromNetworkImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;

        // Redimensionner l'image pour le marker (seulement hauteur pour garder proportions)
        final ui.Codec codec = await ui.instantiateImageCodec(
          bytes,
          targetHeight: 120, // Seulement hauteur pour préserver les proportions
        );
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image image = frameInfo.image;

        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur création marker depuis URL: $e");
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _refreshTimer?.cancel();
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    tripProvider.detachReadOnlyLiveShare();
    super.dispose();
  }

  Future<void> _initializeLiveShare() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      bool success = await tripProvider.attachReadOnlyLiveShare(widget.rideId, widget.token);

      if (success) {
        setState(() {
          _isConnected = true;
          _isLoading = false;
        });
        _startPeriodicRefresh();
      } else {
        setState(() {
          _isConnected = false;
          _isLoading = false;
          _errorMessage = 'Impossible de se connecter au partage. Le lien peut être invalide ou expiré.';
        });
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isLoading = false;
        _errorMessage = 'Erreur de connexion: ${e.toString()}';
      });
      myCustomPrintStatement("❌ Erreur lors de l'initialisation du partage: $e");
    }
  }

  void _startPeriodicRefresh() {
    // Rafraîchir plus fréquemment (5 secondes) pour détecter les changements de statut
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Arrêter le timer si la course est terminée ou annulée
      if (_isRideEnded()) {
        timer.cancel();
        myCustomPrintStatement("⏹️ Timer arrêté - course terminée/annulée");
        return;
      }
      _refreshRideData();
    });
  }

  Future<void> _refreshRideData() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      if (tripProvider.currentLiveShareData != null) {
        final newData = tripProvider.currentLiveShareData!;
        final oldStatus = _rideData?['status'];
        final newStatus = newData['status'];

        _rideData = newData;

        // Détecter les changements de statut
        if (oldStatus != newStatus) {
          myCustomPrintStatement("📊 Changement de statut: $oldStatus → $newStatus");

          // Forcer le rebuild immédiatement pour les statuts de fin
          if (newStatus == 5 || newStatus == 6) {
            myCustomPrintStatement("🔴 Course terminée/annulée détectée (statut $newStatus)");
            if (mounted) {
              setState(() {});
            }
            return; // Ne pas continuer les updates
          }
        }

        await _updateDriverData();
        await _updateRiderData();
        await _updateMapView();
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors du rafraîchissement des données: $e");
    }
  }

  Future<void> _updateDriverData() async {
    try {
      if (_rideData != null && _rideData!['acceptedBy'] != null) {
        final tripProvider = Provider.of<TripProvider>(context, listen: false);
        final data = await tripProvider.fetchDriverPublicData(_rideData!['acceptedBy']);
        if (mounted) {
          setState(() {
            _driverData = data;
          });
        } else {
          _driverData = data;
        }
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de la récupération des données du chauffeur: $e");
    }
  }

  /// Récupère les données du passager depuis Firestore si pas dans le booking
  Future<void> _updateRiderData() async {
    try {
      // Si les infos sont déjà dans le booking, pas besoin de fetch
      if (_rideData != null &&
          _rideData!['riderFirstName'] != null &&
          _rideData!['riderFirstName'].toString().isNotEmpty) {
        myCustomPrintStatement("✅ Infos rider déjà dans booking: ${_rideData!['riderFirstName']}");
        return;
      }

      // Sinon, récupérer depuis la collection users
      if (_rideData != null && _rideData!['requestBy'] != null) {
        final riderId = _rideData!['requestBy'] as String;
        myCustomPrintStatement("🧑 Récupération infos rider depuis Firestore: $riderId");

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(riderId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          if (mounted) {
            setState(() {
              _riderData = {
                'firstName': userData['firstName'] ?? userData['name'],
                'profileImage': userData['profileImage'] ?? userData['image'],
              };
            });
          } else {
            _riderData = {
              'firstName': userData['firstName'] ?? userData['name'],
              'profileImage': userData['profileImage'] ?? userData['image'],
            };
          }
          myCustomPrintStatement("✅ Infos rider récupérées: ${_riderData!['firstName']}");
        }
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de la récupération des données du passager: $e");
    }
  }

  Future<void> _updateMapView() async {
    // Debounce: éviter les appels multiples simultanés
    if (_isUpdatingMap) {
      myCustomPrintStatement("⏳ _updateMapView: déjà en cours, ignoré");
      return;
    }

    if (_rideData == null || _mapController == null) {
      myCustomPrintStatement("⚠️ _updateMapView annulée: rideData=${_rideData != null}, mapController=${_mapController != null}");
      return;
    }

    _isUpdatingMap = true;
    myCustomPrintStatement("🗺️ _updateMapView START");

    try {
      Set<Marker> newMarkers = {};
      Set<Polyline> newPolylines = {};

      // Charger l'icône du véhicule si pas encore fait
      if (_vehicleMarkerIcon == null) {
        myCustomPrintStatement("🚗 Chargement de l'icône véhicule...");
        await _loadVehicleMarkerIcon();
        myCustomPrintStatement("🚗 Icône véhicule chargée: $_vehicleMarkerIcon");
      }

      final double? pickLat = _rideData!['pickLat'] != null
          ? (_rideData!['pickLat'] as num).toDouble()
          : null;
      final double? pickLng = _rideData!['pickLng'] != null
          ? (_rideData!['pickLng'] as num).toDouble()
          : null;
      final double? dropLat = _rideData!['dropLat'] != null
          ? (_rideData!['dropLat'] as num).toDouble()
          : null;
      final double? dropLng = _rideData!['dropLng'] != null
          ? (_rideData!['dropLng'] as num).toDouble()
          : null;

      myCustomPrintStatement("🗺️ LiveShare coords: pick=($pickLat, $pickLng), drop=($dropLat, $dropLng), routeLoaded=$_routeLoaded");

      // 🟢 Marqueur de départ (rond vert)
      if (pickLat != null && pickLng != null) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(pickLat, pickLng),
            anchor: const Offset(0.5, 0.5),
            icon: _pickupMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }

      // 🟥 Marqueur de destination (carré rouge)
      if (dropLat != null && dropLng != null) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(dropLat, dropLng),
            anchor: const Offset(0.5, 0.5),
            icon: _destinationMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }

      // 🚗 Marqueur du chauffeur (icône véhicule de la catégorie)
      // Priorité 1: position depuis le booking document (driverLatitude/driverLongitude)
      // Priorité 2: position depuis le driver document (currentLat/currentLng)
      // Priorité 3: position depuis le booking nested driver object
      double? driverLat;
      double? driverLng;

      // Source 1: booking document direct fields
      if (_rideData!['driverLatitude'] != null && _rideData!['driverLongitude'] != null) {
        driverLat = (_rideData!['driverLatitude'] as num).toDouble();
        driverLng = (_rideData!['driverLongitude'] as num).toDouble();
        myCustomPrintStatement("🚗 Position chauffeur depuis booking: ($driverLat, $driverLng)");
      }
      // Source 2: booking nested driver object
      else if (_rideData!['driver'] != null &&
          _rideData!['driver']['latitude'] != null &&
          _rideData!['driver']['longitude'] != null) {
        driverLat = (_rideData!['driver']['latitude'] as num).toDouble();
        driverLng = (_rideData!['driver']['longitude'] as num).toDouble();
        myCustomPrintStatement("🚗 Position chauffeur depuis booking.driver: ($driverLat, $driverLng)");
      }
      // Source 3: driver document
      else if (_driverData != null &&
          _driverData!['currentLat'] != null &&
          _driverData!['currentLng'] != null) {
        driverLat = (_driverData!['currentLat'] as num).toDouble();
        driverLng = (_driverData!['currentLng'] as num).toDouble();
        myCustomPrintStatement("🚗 Position chauffeur depuis driverData: ($driverLat, $driverLng)");
      } else {
        myCustomPrintStatement("⚠️ Pas de position chauffeur disponible - rideData keys: ${_rideData!.keys.toList()}, driverData=${_driverData != null}");
      }

      if (driverLat != null && driverLng != null) {
        final currentDriverPos = LatLng(driverLat, driverLng);

        // 📍 Ajouter la position au trajet parcouru (si différente de la dernière)
        if (_lastDriverPosition == null ||
            (_lastDriverPosition!.latitude != driverLat ||
             _lastDriverPosition!.longitude != driverLng)) {

          // Calculer le bearing (orientation) basé sur le mouvement
          if (_lastDriverPosition != null) {
            _driverBearing = _calculateBearing(_lastDriverPosition!, currentDriverPos);
            myCustomPrintStatement("🧭 Bearing calculé: $_driverBearing°");
          }

          _driverPathPoints.add(currentDriverPos);
          _lastDriverPosition = currentDriverPos;
          myCustomPrintStatement("📍 Nouvelle position ajoutée au trajet (${_driverPathPoints.length} points)");
        }

        myCustomPrintStatement("✅ Création marker chauffeur à ($driverLat, $driverLng), bearing=$_driverBearing°");
        newMarkers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: currentDriverPos,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            rotation: _driverBearing, // Orientation dans le sens de la course
            icon: _vehicleMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          ),
        );
      }

      // 🛤️ Charger/recalculer l'itinéraire depuis la position du chauffeur vers la destination
      // Recalcule si: pas encore chargé, ou si le chauffeur a bougé significativement
      bool shouldRecalculateRoute = false;
      if (!_routeLoaded) {
        shouldRecalculateRoute = true;
      } else if (driverLat != null && driverLng != null && dropLat != null && dropLng != null) {
        // Recalculer si le chauffeur s'est déplacé de plus de 100m depuis le dernier calcul
        shouldRecalculateRoute = _shouldRecalculateRoute(LatLng(driverLat, driverLng));
      }

      if (shouldRecalculateRoute && driverLat != null && driverLng != null && dropLat != null && dropLng != null) {
        _routeLoaded = true;
        myCustomPrintStatement("🛤️ LiveShare: Calcul de l'itinéraire depuis chauffeur vers destination...");
        try {
          final routeInfo = await RouteService.fetchRoute(
            origin: LatLng(driverLat, driverLng),
            destination: LatLng(dropLat, dropLng),
          );

          myCustomPrintStatement("✅ LiveShare: Itinéraire chargé avec ${routeInfo.coordinates.length} points");

          if (routeInfo.coordinates.isNotEmpty) {
            myCustomPrintStatement("✅ Création polyline avec ${routeInfo.coordinates.length} points");
            newPolylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: routeInfo.coordinates,
                color: Colors.black,
                width: 6,
              ),
            );
            _lastRouteCalculationPosition = LatLng(driverLat, driverLng);
          }
        } catch (e) {
          myCustomPrintStatement("❌ Erreur chargement itinéraire: $e");
          // Fallback: ligne directe
          newPolylines.add(
            Polyline(
              polylineId: const PolylineId('route_fallback'),
              points: [LatLng(driverLat, driverLng), LatLng(dropLat, dropLng)],
              color: Colors.black.withValues(alpha: 0.5),
              width: 3,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
        }
      } else if (_polylines.isNotEmpty) {
        // Conserver l'itinéraire déjà chargé (filtrer le trajet parcouru pour le recréer)
        for (final polyline in _polylines) {
          if (polyline.polylineId.value != 'driver_path') {
            newPolylines.add(polyline);
          }
        }
        myCustomPrintStatement("🔄 LiveShare: Réutilisation de l'itinéraire existant");
      } else {
        myCustomPrintStatement("⚠️ LiveShare: Pas d'itinéraire - routeLoaded=$_routeLoaded, coords manquantes");
      }

      // 🚙 Ajouter le trajet parcouru par le chauffeur (ligne rouge corail)
      if (_driverPathPoints.length >= 2) {
        newPolylines.add(
          Polyline(
            polylineId: const PolylineId('driver_path'),
            points: List.from(_driverPathPoints),
            color: const Color(0xFFFF7F50), // Coral
            width: 5,
          ),
        );
        myCustomPrintStatement("🛣️ Trajet parcouru: ${_driverPathPoints.length} points");
      }

      // Ne mettre à jour que si on a quelque chose à afficher
      if (mounted) {
        setState(() {
          _markers = newMarkers;
          // Conserver les polylines existantes si newPolylines est vide mais _polylines non
          if (newPolylines.isNotEmpty) {
            _polylines = newPolylines;
          }
        });
      }

      myCustomPrintStatement("🗺️ _updateMapView: ${newMarkers.length} markers, ${_polylines.length} polylines");

      // 🎯 Centrer sur le chauffeur (sauf si l'utilisateur a bougé la carte)
      if (!_userHasMovedMap && driverLat != null && driverLng != null) {
        _isProgrammaticCameraMove = true;
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(driverLat, driverLng), 16.0),
        ).then((_) {
          _isProgrammaticCameraMove = false;
        }).catchError((_) {
          _isProgrammaticCameraMove = false;
        });
      }

      myCustomPrintStatement("🗺️ _updateMapView END");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de la mise à jour de la carte: $e");
    } finally {
      _isUpdatingMap = false;
    }
  }

  /// Récupère la position actuelle du chauffeur
  LatLng? _getDriverPosition() {
    if (_rideData == null) return null;

    if (_rideData!['driverLatitude'] != null && _rideData!['driverLongitude'] != null) {
      return LatLng(
        (_rideData!['driverLatitude'] as num).toDouble(),
        (_rideData!['driverLongitude'] as num).toDouble(),
      );
    } else if (_rideData!['driver'] != null &&
        _rideData!['driver']['latitude'] != null &&
        _rideData!['driver']['longitude'] != null) {
      return LatLng(
        (_rideData!['driver']['latitude'] as num).toDouble(),
        (_rideData!['driver']['longitude'] as num).toDouble(),
      );
    } else if (_driverData != null &&
        _driverData!['currentLat'] != null &&
        _driverData!['currentLng'] != null) {
      return LatLng(
        (_driverData!['currentLat'] as num).toDouble(),
        (_driverData!['currentLng'] as num).toDouble(),
      );
    }
    return null;
  }

  /// Centre la carte sur la position du chauffeur
  void _centerOnDriver() {
    final driverPos = _getDriverPosition();
    if (driverPos != null && _mapController != null) {
      _isProgrammaticCameraMove = true;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(driverPos, 16.0),
      ).then((_) {
        _isProgrammaticCameraMove = false;
      }).catchError((_) {
        _isProgrammaticCameraMove = false;
      });
    }
  }

  /// Calcule le bearing (angle de direction) entre deux positions
  double _calculateBearing(LatLng from, LatLng to) {
    final double lat1 = from.latitude * math.pi / 180;
    final double lat2 = to.latitude * math.pi / 180;
    final double dLng = (to.longitude - from.longitude) * math.pi / 180;

    final double y = math.sin(dLng) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360; // Normaliser en 0-360
  }

  /// Vérifie si la route doit être recalculée (chauffeur dévié de plus de 100m)
  bool _shouldRecalculateRoute(LatLng currentDriverPos) {
    if (_lastRouteCalculationPosition == null) return true;

    // Calcul distance simple (approximation Haversine simplifiée)
    const double earthRadius = 6371000; // mètres
    final double lat1 = _lastRouteCalculationPosition!.latitude * math.pi / 180;
    final double lat2 = currentDriverPos.latitude * math.pi / 180;
    final double dLat = lat2 - lat1;
    final double dLng = (currentDriverPos.longitude - _lastRouteCalculationPosition!.longitude) * math.pi / 180;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c;

    // Recalculer si le chauffeur s'est déplacé de plus de 100m depuis le dernier calcul
    final shouldRecalculate = distance > 100;
    if (shouldRecalculate) {
      myCustomPrintStatement("🔄 Recalcul route nécessaire: déplacement de ${distance.toInt()}m");
    }
    return shouldRecalculate;
  }

  /// Construit un bouton de recentrage - Style Liquid Glass
  Widget _buildRecenterButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF), // Blanc bleuté 100%
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Tooltip(
            message: tooltip,
            child: Center(
              child: Icon(
                icon,
                color: Colors.black87,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getRideStatusText() {
    if (_rideData == null) return 'Course inconnue';

    int status = _rideData!['status'] ?? 0;

    switch (status) {
      case 0: // PENDING_REQUEST
        return 'Recherche d\'un chauffeur...';
      case 1: // ACCEPTED
        return 'Chauffeur en route vers le passager';
      case 2: // DRIVER_REACHED
        return 'Chauffeur arrivé au point de départ';
      case 3: // RIDE_STARTED
        return 'Course en cours';
      case 4: // DESTINATION_REACHED - Arrivé, en attente de paiement
        return 'Arrivé à destination';
      case 5: // RIDE_COMPLETE
        return 'Course terminée';
      case 6: // CANCELLED
        return 'Course annulée';
      default:
        return 'Statut: $status';
    }
  }

  /// Vérifie si la course est terminée (annulée ou complétée)
  bool _isRideEnded() {
    if (_rideData == null) return false;
    int status = _rideData!['status'] ?? 0;
    return status == 5 || status == 6; // RIDE_COMPLETE ou CANCELLED
  }

  /// Vérifie si on doit afficher l'overlay de fin (arrivé, payé ou annulé)
  bool _shouldShowEndOverlay() {
    if (_rideData == null) return false;
    int status = _rideData!['status'] ?? 0;
    return status == 4 || status == 5 || status == 6; // DESTINATION_REACHED, RIDE_COMPLETE ou CANCELLED
  }

  /// Vérifie si la course est arrivée à destination (en attente de paiement)
  bool _isRideArrived() {
    if (_rideData == null) return false;
    return (_rideData!['status'] ?? 0) == 4; // DESTINATION_REACHED
  }

  /// Vérifie si la course est annulée
  bool _isRideCancelled() {
    if (_rideData == null) return false;
    return (_rideData!['status'] ?? 0) == 6;
  }

  /// Vérifie si le lien de partage a expiré
  bool _isShareLinkExpired() {
    if (_rideData == null) return false;

    final shareExpiresAt = _rideData!['shareExpiresAt'];
    if (shareExpiresAt == null) return false;

    DateTime expiryDate;
    if (shareExpiresAt is Timestamp) {
      expiryDate = shareExpiresAt.toDate();
    } else {
      return false;
    }

    return DateTime.now().isAfter(expiryDate);
  }

  /// Construit l'overlay de lien expiré
  Widget _buildExpiredLinkOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Lien expiré',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ce lien de suivi n\'est plus valide.\nDemandez un nouveau lien au passager.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // 🛡️ Fermer définitivement la session (ne plus afficher le bouton bouclier)
                  final tripProvider = Provider.of<TripProvider>(context, listen: false);
                  tripProvider.dismissPendingLiveShare();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit l'overlay de fin de course
  Widget _buildRideEndedOverlay() {
    final isCancelled = _isRideCancelled();
    final isArrived = _isRideArrived();
    final cancelledBy = _rideData?['ride_cancelled_by'] as String? ?? '';

    String message;
    IconData icon;
    Color color;

    if (isCancelled) {
      icon = Icons.cancel_outlined;
      color = Colors.red;
      if (cancelledBy.toLowerCase().contains('driver')) {
        message = 'Course annulée par le chauffeur';
      } else if (cancelledBy.toLowerCase().contains('rider') ||
                 cancelledBy.toLowerCase().contains('customer')) {
        message = 'Course annulée par le passager';
      } else {
        message = 'Course annulée';
      }
    } else if (isArrived) {
      icon = Icons.location_on;
      color = Colors.blue;
      message = 'Arrivé à destination';
    } else {
      icon = Icons.check_circle_outline;
      color = Colors.green;
      message = 'Course terminée';
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // 🛡️ Fermer définitivement la session (ne plus afficher le bouton bouclier)
                  final tripProvider = Provider.of<TripProvider>(context, listen: false);
                  tripProvider.dismissPendingLiveShare();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi en direct'),
        backgroundColor: MyColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: MyColors.primaryColor),
            vSizedBox2,
            const Text('Connexion en cours...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi en direct'),
        backgroundColor: MyColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              vSizedBox2,
              Text(
                'Erreur de connexion',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              vSizedBox,
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              vSizedBox2,
              RoundEdgedButton(
                text: 'Réessayer',
                onTap: _initializeLiveShare,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Carte plein écran
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _setMapStyle(); // Appliquer le style de carte
              _refreshRideData();
            },
            onCameraMoveStarted: () {
              // Ignorer les mouvements programmés (notre propre animation)
              if (_isProgrammaticCameraMove) {
                return;
              }
              // Détecter quand l'utilisateur bouge la carte manuellement
              if (!_userHasMovedMap) {
                setState(() {
                  _userHasMovedMap = true;
                });
                myCustomPrintStatement("👆 Utilisateur a bougé la carte - suivi auto désactivé");
              }
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(-18.9, 47.5), // Vue initiale Madagascar (sera recentré sur chauffeur)
              zoom: 10.0, // Zoom raisonnable en attendant les positions
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false, // On utilise nos propres boutons
            // Activer tous les gestes pour navigation libre
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
          ),
          // 🫧 Bouton retour - Style Liquid Glass (masqué en position expanded)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _sheetExtent > 0.8 ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: _sheetExtent > 0.8,
                child: _buildRecenterButton(
                  icon: Icons.arrow_back_ios_new,
                  tooltip: 'Retour',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          // Bouton de recentrage sur le chauffeur (masqué en position expanded)
          Positioned(
            right: 24,
            bottom: _calculateSheetHeight() + 32,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _sheetExtent > 0.8 ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: _sheetExtent > 0.8,
                child: _buildRecenterButton(
                  icon: _userHasMovedMap ? Icons.gps_fixed : Icons.my_location,
                  tooltip: 'Recentrer sur le chauffeur',
                  onTap: () {
                    setState(() {
                      _userHasMovedMap = false;
                    });
                    _centerOnDriver();
                  },
                ),
              ),
            ),
          ),
          // 🫧 Liquid Glass Bottom Sheet avec animation morphing
          _buildLiquidGlassSheet(),
          // Overlay quand le lien de partage a expiré
          if (_isShareLinkExpired()) _buildExpiredLinkOverlay(),
          // Overlay quand la course est arrivée, terminée ou annulée
          if (_shouldShowEndOverlay()) _buildRideEndedOverlay(),
        ],
      ),
    );
  }

  /// Widget pour afficher départ et arrivée avec trait entre les icônes
  Widget _buildLocationSection() {
    // Récupérer les adresses (pickAddress est le bon champ dans le booking)
    final pickupAddress = _rideData?['pickAddress'] as String? ??
                          _rideData?['pickupAddress'] as String? ?? '';
    final dropAddress = _rideData?['dropAddress'] as String? ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne des icônes avec le trait
        Column(
          children: [
            // Icône rond (départ)
            Icon(Icons.circle, size: 14, color: Colors.black),
            // Trait vertical
            Container(
              width: 2,
              height: 24,
              color: Colors.grey[300],
            ),
            // Icône carré (arrivée)
            Icon(Icons.square, size: 14, color: Colors.black),
          ],
        ),
        const SizedBox(width: 10),
        // Colonne des adresses
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Adresse de départ
              Text(
                pickupAddress.isNotEmpty ? pickupAddress : 'Adresse de départ',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              // Adresse d'arrivée
              Text(
                dropAddress.isNotEmpty ? dropAddress : 'Adresse d\'arrivée',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Widget pour afficher le statut de la course
  Widget _buildStatusBadge() {
    final int status = _rideData?['status'] ?? 0;
    final bool isRideInProgress = status == 3; // RIDE_STARTED

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isRideInProgress
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isRideInProgress)
            // Point vert animé pour "Course en cours"
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.5 * _pulseAnimation.value),
                        blurRadius: 6 * _pulseAnimation.value,
                        spreadRadius: 2 * (_pulseAnimation.value - 1),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Icon(Icons.info_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _getRideStatusText(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isRideInProgress ? Colors.green[700] : Colors.blue,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Récupère le prénom du passager depuis les données de la course
  String _getRiderFirstName() {
    if (_rideData == null) return 'Passager';

    // Essayer plusieurs noms de champs possibles
    String? name;

    // 1. Champs directs pour le prénom (depuis le booking)
    name ??= _rideData!['riderFirstName'] as String?;
    name ??= _rideData!['userFirstName'] as String?;
    name ??= _rideData!['firstName'] as String?;

    // 2. Champs de nom complet (on prendra le prénom)
    name ??= _rideData!['riderName'] as String?;
    name ??= _rideData!['userName'] as String?;
    name ??= _rideData!['name'] as String?;
    name ??= _rideData!['fullName'] as String?;

    // 3. Objet rider imbriqué
    if (name == null && _rideData!['rider'] is Map) {
      final rider = _rideData!['rider'] as Map;
      name = rider['firstName'] as String? ?? rider['name'] as String?;
    }

    // 4. Objet user imbriqué
    if (name == null && _rideData!['user'] is Map) {
      final user = _rideData!['user'] as Map;
      name = user['firstName'] as String? ?? user['name'] as String?;
    }

    // 5. FALLBACK: Utiliser _riderData (récupéré depuis Firestore users)
    if (name == null && _riderData != null) {
      name = _riderData!['firstName'] as String?;
    }

    // Si c'est un nom complet, prendre juste le prénom
    if (name != null && name.contains(' ')) {
      name = name.split(' ').first;
    }

    return name ?? 'Passager';
  }

  /// Récupère l'image de profil du passager depuis les données de la course
  String? _getRiderImage() {
    if (_rideData == null) return null;

    // Essayer plusieurs noms de champs possibles
    String? image;

    // 1. Champs directs (depuis le booking)
    image ??= _rideData!['riderProfileImage'] as String?;
    image ??= _rideData!['riderImage'] as String?;
    image ??= _rideData!['userProfileImage'] as String?;
    image ??= _rideData!['userImage'] as String?;
    image ??= _rideData!['profileImage'] as String?;

    // 2. Objet rider imbriqué
    if (image == null && _rideData!['rider'] is Map) {
      final rider = _rideData!['rider'] as Map;
      image = rider['profileImage'] as String? ?? rider['image'] as String?;
    }

    // 3. Objet user imbriqué
    if (image == null && _rideData!['user'] is Map) {
      final user = _rideData!['user'] as Map;
      image = user['profileImage'] as String? ?? user['image'] as String?;
    }

    // 4. FALLBACK: Utiliser _riderData (récupéré depuis Firestore users)
    if (image == null && _riderData != null) {
      image = _riderData!['profileImage'] as String?;
    }

    return (image != null && image.isNotEmpty) ? image : null;
  }

  /// Calcule la hauteur actuelle de la bottom sheet basée sur _sheetExtent
  double _calculateSheetHeight() {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight * _expandedHeightRatio;
    final intermediateHeight = screenHeight * 0.38;

    if (_sheetExtent <= 0.5) {
      final t = _sheetExtent / 0.5;
      return _collapsedHeight + (intermediateHeight - _collapsedHeight) * t;
    } else {
      final t = (_sheetExtent - 0.5) / 0.5;
      return intermediateHeight + (expandedHeight - intermediateHeight) * t;
    }
  }

  /// 🫧 Liquid Glass Bottom Sheet avec 3 états et animation morphing
  Widget _buildLiquidGlassSheet() {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight * _expandedHeightRatio;
    final intermediateHeight = screenHeight * 0.38; // ~38% pour intermediate

    // Interpolation continue basée sur _sheetExtent (suit le doigt)
    // extent: 0.0 = collapsed, 0.5 = intermediate, 1.0 = expanded
    double currentHeight;
    double currentMargin;
    double currentBottomMargin;
    double currentOpacity;
    double currentTopBorderRadius;
    double currentBottomBorderRadius;

    if (_sheetExtent <= 0.5) {
      // Transition collapsed (0) → intermediate (0.5)
      final t = _sheetExtent / 0.5; // 0 à 1
      currentHeight = _collapsedHeight + (intermediateHeight - _collapsedHeight) * t;
      currentMargin = 12; // Marge égale sur les côtés
      currentBottomMargin = 12; // Marge égale en bas
      currentTopBorderRadius = 40; // Même arrondi que expanded
      currentBottomBorderRadius = 40; // Bulle flottante
      currentOpacity = 0.96; // 96% opacité en position basse/intermédiaire
    } else {
      // Transition intermediate (0.5) → expanded (1.0)
      final t = (_sheetExtent - 0.5) / 0.5; // 0 à 1
      currentHeight = intermediateHeight + (expandedHeight - intermediateHeight) * t;
      currentMargin = 12 * (1 - t); // 12 → 0
      currentBottomMargin = 12 * (1 - t); // 12 → 0
      // Le haut reste à 40, le bas devient carré
      currentTopBorderRadius = 40; // Constant
      currentBottomBorderRadius = 40 * (1 - t); // 40 → 0
      currentOpacity = 0.96 + (0.04 * t); // 0.96 → 1.0
    }

    // BorderRadius avec coins différents haut/bas
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(currentTopBorderRadius),
      topRight: Radius.circular(currentTopBorderRadius),
      bottomLeft: Radius.circular(currentBottomBorderRadius),
      bottomRight: Radius.circular(currentBottomBorderRadius),
    );

    return Positioned(
      left: currentMargin,
      right: currentMargin,
      bottom: currentBottomMargin,
      height: currentHeight,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            // Ajuster l'extent selon le drag (suit le doigt)
            _sheetExtent -= details.primaryDelta! / (screenHeight * 0.5);
            _sheetExtent = _sheetExtent.clamp(0.0, 1.0);

            // Mettre à jour l'état pour le contenu
            if (_sheetExtent < 0.25) {
              _sheetState = 0;
            } else if (_sheetExtent < 0.75) {
              _sheetState = 1;
            } else {
              _sheetState = 2;
            }
          });
        },
        onVerticalDragEnd: (details) {
          // Snap vers l'état le plus proche avec animation
          setState(() {
            if (_sheetExtent < 0.25) {
              _sheetState = 0;
              _sheetExtent = 0.0;
            } else if (_sheetExtent < 0.75) {
              _sheetState = 1;
              _sheetExtent = 0.5;
            } else {
              _sheetState = 2;
              _sheetExtent = 1.0;
            }
          });
        },
        onTap: () {
          // Cycle vers l'état suivant au tap
          setState(() {
            if (_sheetState == 0) {
              _sheetState = 1;
              _sheetExtent = 0.5;
            } else if (_sheetState == 1) {
              _sheetState = 2;
              _sheetExtent = 1.0;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            // Blanc légèrement bleuté
            color: const Color(0xFFF5F8FF).withValues(alpha: currentOpacity),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: _buildSheetContent(),
        ),
      ),
    );
  }

  /// Contenu de la bottom sheet selon l'état actuel
  Widget _buildSheetContent() {
    switch (_sheetState) {
      case 0:
        return _buildCollapsedContent();
      case 1:
        return _buildIntermediateContent();
      case 2:
        return _buildExpandedContent();
      default:
        return _buildIntermediateContent();
    }
  }

  /// Avatar animé (pulsation) du passager
  Widget _buildAnimatedRiderAvatar({double radius = 20}) {
    final riderImage = _getRiderImage();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              backgroundImage: riderImage != null ? NetworkImage(riderImage) : null,
              child: riderImage == null
                  ? Icon(Icons.person, color: Colors.blue, size: radius * 1.1)
                  : null,
            ),
          ),
        );
      },
    );
  }

  /// Récupère les infos du véhicule (marque + modèle)
  String _getVehicleBrandModel() {
    // 1. Depuis driverData.vehicleDetails (le plus fiable)
    // Les champs sont: vehicleBrandName et vehicleModal (pas brand/model)
    if (_driverData != null && _driverData!['vehicleDetails'] != null) {
      final vehicleDetails = _driverData!['vehicleDetails'];
      if (vehicleDetails is Map) {
        final brand = vehicleDetails['vehicleBrandName'] as String? ??
                      vehicleDetails['brand'] as String? ??
                      vehicleDetails['make'] as String? ?? '';
        final model = vehicleDetails['vehicleModal'] as String? ??
                      vehicleDetails['vehicleModel'] as String? ??
                      vehicleDetails['model'] as String? ?? '';
        if (brand.isNotEmpty || model.isNotEmpty) {
          return '$brand $model'.trim();
        }
      }
    }

    return '';
  }

  /// Récupère la plaque d'immatriculation
  String _getLicensePlate() {
    // 1. Depuis driverData.vehicleDetails (champ principal: licenseNumber)
    if (_driverData != null && _driverData!['vehicleDetails'] != null) {
      final vehicleDetails = _driverData!['vehicleDetails'];
      if (vehicleDetails is Map) {
        final plate = vehicleDetails['licenseNumber'] as String? ??
                      vehicleDetails['plateNumber'] as String? ??
                      vehicleDetails['licensePlate'] as String? ??
                      vehicleDetails['vehicleNumber'] as String?;
        if (plate != null && plate.isNotEmpty) {
          return plate;
        }
      }
    }

    // 2. Depuis driverData directement
    if (_driverData != null) {
      final plate = _driverData!['licenseNumber'] as String? ??
                    _driverData!['vehicleNumber'] as String? ??
                    _driverData!['licensePlate'] as String?;
      if (plate != null && plate.isNotEmpty) {
        return plate;
      }
    }

    // 3. Depuis rideData
    return _rideData?['licenseNumber'] as String? ??
           _rideData?['vehicleNumber'] as String? ??
           '';
  }

  /// Récupère le prénom du chauffeur
  String _getDriverFirstName() {
    if (_driverData == null) return 'Chauffeur';

    String? name = _driverData!['firstName'] as String? ??
                   _driverData!['name'] as String? ??
                   _driverData!['fullName'] as String?;

    // Si c'est un nom complet, prendre juste le prénom
    if (name != null && name.contains(' ')) {
      name = name.split(' ').first;
    }

    return name ?? 'Chauffeur';
  }

  /// Récupère l'image de profil du chauffeur
  String? _getDriverImage() {
    if (_driverData == null) return null;

    return _driverData!['profileImage'] as String? ??
           _driverData!['image'] as String? ??
           _driverData!['photoUrl'] as String?;
  }

  /// Widget pour afficher les infos du chauffeur sous l'ETA
  /// [isExpanded] : true = fond blanc pur, false = fond gris Apple Liquid Glass
  Widget _buildDriverInfoSection({bool isExpanded = false}) {
    final driverName = _getDriverFirstName();
    final driverImage = _getDriverImage();
    final vehicleBrandModel = _getVehicleBrandModel();
    final licensePlate = _getLicensePlate();

    // Debug simplifié
    myCustomPrintStatement("🚗 Driver: $driverName | Véhicule: $vehicleBrandModel | Plaque: $licensePlate");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        // Expanded = blanc pur, sinon gris Apple Liquid Glass
        color: isExpanded ? Colors.white : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Photo du chauffeur
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE5E5EA), // iOS systemGray5
            backgroundImage: driverImage != null ? NetworkImage(driverImage) : null,
            child: driverImage == null
                ? Icon(Icons.person, color: Colors.grey[600], size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          // Nom du chauffeur
          Expanded(
            child: Text(
              driverName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Infos véhicule à droite
          if (vehicleBrandModel.isNotEmpty || licensePlate.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vehicleBrandModel.isNotEmpty)
                  Text(
                    vehicleBrandModel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                if (licensePlate.isNotEmpty)
                  Text(
                    licensePlate,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// État 0 : Collapsed - Petite bulle avec avatar animé et statut
  Widget _buildCollapsedContent() {
    final statusText = _getRideStatusText();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar centré en haut
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Photo animée + Statut
          Row(
            children: [
              // Photo de profil du passager avec animation pulsation
              _buildAnimatedRiderAvatar(radius: 20),
              const SizedBox(width: 12),
              // Statut de la course
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// État 1 : Intermediate - Bulle flottante avec suivi en direct
  Widget _buildIntermediateContent() {
    final riderFirstName = _getRiderFirstName();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar pour drag
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Row principale: Photo passager + Texte (sans infos véhicule)
            Row(
              children: [
                // Photo animée du passager (même position que collapsed)
                _buildAnimatedRiderAvatar(radius: 20),
                const SizedBox(width: 12),
                // Texte "Vous suivez..."
                Expanded(
                  child: Text(
                    'Vous suivez la course en direct de $riderFirstName',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Locations avec trait entre les icônes
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7), // iOS systemGray6 - gris froid Apple
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildLocationSection(),
            ),
            const SizedBox(height: 10),
            // Statut de la course (en bleu)
            _buildStatusBadge(),
            const SizedBox(height: 10),
            // Infos chauffeur + véhicule
            _buildDriverInfoSection(),
          ],
        ),
      ),
    );
  }

  /// État 2 : Expanded - Bottom sheet classique pleine largeur
  Widget _buildExpandedContent() {
    final riderFirstName = _getRiderFirstName();

    return Column(
      children: [
        // Handle bar pour réduire
        GestureDetector(
          onTap: () {
            setState(() {
              _sheetState = 1;
              _sheetExtent = 0.5;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        // Contenu scrollable
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Header: Photo passager + Texte (sans infos véhicule)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      // Photo animée du passager (même position que collapsed)
                      _buildAnimatedRiderAvatar(radius: 22),
                      const SizedBox(width: 14),
                      // Texte "Vous suivez..."
                      Expanded(
                        child: Text(
                          'Vous suivez la course en direct de $riderFirstName',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Locations avec trait entre les icônes
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, // Blanc pur en mode expanded
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildLocationSection(),
                ),
                const SizedBox(height: 12),
                // Statut de la course (en bleu)
                _buildStatusBadge(),
                const SizedBox(height: 12),
                // Infos chauffeur + véhicule
                _buildDriverInfoSection(isExpanded: true),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        // Safe area bottom padding
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        // Mettre à jour les données depuis le provider
        if (tripProvider.isLiveShareActive && tripProvider.currentLiveShareData != null) {
          final newData = tripProvider.currentLiveShareData!;
          final oldStatus = _rideData?['status'];
          final newStatus = newData['status'];

          _rideData = newData;

          // Log si changement de statut détecté via le stream
          if (oldStatus != null && oldStatus != newStatus) {
            myCustomPrintStatement("📊 [Consumer] Changement de statut détecté: $oldStatus → $newStatus");
          }

          // Seulement mettre à jour la carte si la course n'est pas terminée
          if (!_isRideEnded()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateDriverData();
              _updateRiderData();
              _updateMapView();
            });
          }
        }

        if (_isLoading) {
          return _buildLoadingView();
        } else if (!_isConnected || _errorMessage.isNotEmpty) {
          return _buildErrorView();
        } else {
          return _buildMainView();
        }
      },
    );
  }
}
