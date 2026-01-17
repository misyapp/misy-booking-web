import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/services/driver_snap_service.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import '../provider/trip_provider.dart';

class RequestForRide extends StatefulWidget {
  const RequestForRide({super.key});

  @override
  State<RequestForRide> createState() => _RequestForRideState();
}

class _RequestForRideState extends State<RequestForRide>
    with TickerProviderStateMixin {
  // Animation de la barre de progression
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // Animation pulse pour l'avatar
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Liste des chauffeurs notifiés (pour l'affichage des photos empilées)
  final List<Map<String, dynamic>> _notifiedDrivers = [];

  // Compteur de chauffeurs notifiés (pour affichage séquentiel)
  int _notifiedDriversCount = 0;
  int _previousNotifiedCount = 0; // Pour détecter les nouveaux chauffeurs ajoutés
  StreamSubscription? _bookingStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    // Reporter l'ajustement de la caméra après le build pour éviter "setState during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // NOTE: On garde les 8 markers des chauffeurs proches déjà affichés sur la carte
      _fitCameraToRoute(); // Afficher l'itinéraire complet (pickup → drop)
    });
    _listenToNotifiedDrivers(); // Écoute showOnly et affiche uniquement les chauffeurs interrogés
  }

  /// Ajuste la caméra pour afficher l'itinéraire complet (pickup → drop)
  /// La carte reste fixe pendant toute la durée de la recherche
  Future<void> _fitCameraToRoute() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);

      // Récupérer les coordonnées pickup et drop
      final pickLat = tripProvider.pickLocation?['lat'] as double?;
      final pickLng = tripProvider.pickLocation?['lng'] as double?;
      final dropLat = tripProvider.dropLocation?['lat'] as double?;
      final dropLng = tripProvider.dropLocation?['lng'] as double?;

      if (pickLat == null || pickLng == null || dropLat == null || dropLng == null) {
        debugPrint('⚠️ _fitCameraToRoute: Coordonnées manquantes');
        return;
      }

      // Calculer les bounds pour inclure pickup et drop
      final minLat = math.min(pickLat, dropLat);
      final maxLat = math.max(pickLat, dropLat);
      final minLng = math.min(pickLng, dropLng);
      final maxLng = math.max(pickLng, dropLng);

      // Ajouter du padding pour que les markers ne soient pas collés aux bords
      final latPadding = (maxLat - minLat) * 0.15;
      final lngPadding = (maxLng - minLng) * 0.15;

      // Centre de l'itinéraire
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      // Décaler vers le haut pour compenser le bottom sheet (58% de l'écran)
      final latSpan = (maxLat - minLat) + (latPadding * 2);
      final adjustedCenterLat = centerLat + (latSpan * 0.20);

      // Calculer le zoom approprié
      final latDiff = (maxLat - minLat) + (latPadding * 2);
      final lngDiff = (maxLng - minLng) + (lngPadding * 2);
      final maxDiff = math.max(latDiff, lngDiff);

      double targetZoom;
      if (maxDiff < 0.002) {       // < 200m
        targetZoom = 17.0;
      } else if (maxDiff < 0.005) { // < 500m
        targetZoom = 16.0;
      } else if (maxDiff < 0.01) {  // < 1km
        targetZoom = 15.0;
      } else if (maxDiff < 0.02) {  // < 2km
        targetZoom = 14.0;
      } else if (maxDiff < 0.05) {  // < 5km
        targetZoom = 13.0;
      } else {                      // > 5km
        targetZoom = 12.0;
      }

      debugPrint('📍 _fitCameraToRoute: Affichage itinéraire complet - zoom=$targetZoom');

      // Animer la caméra vers la vue complète de l'itinéraire
      await mapProvider.controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(adjustedCenterLat, centerLng),
            zoom: targetZoom,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ _fitCameraToRoute: Erreur - $e');
    }
  }

  void _initAnimations() {
    // Barre de progression - 4 secondes par cycle, boucle infinie
    _progressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.repeat();

    // Animation pulse pour l'avatar - 1.5 secondes par cycle
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  /// Nettoie tous les markers de chauffeurs sur la carte (les 8 proches)
  void _clearAllDriverMarkers() {
    try {
      final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);

      // Collecter les IDs des markers à supprimer (tous sauf pickup et drop)
      List<String> markersToRemove = [];
      mapProvider.markers.forEach((key, value) {
        final markerId = value.markerId;
        if (markerId != const MarkerId('pickup') &&
            markerId != const MarkerId('drop') &&
            markerId != const MarkerId('driver_vehicle')) {
          markersToRemove.add(key);
        }
      });

      // Supprimer les markers
      for (String markerId in markersToRemove) {
        mapProvider.markers.remove(markerId);
      }

      if (markersToRemove.isNotEmpty) {
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        mapProvider.notifyListeners();
        debugPrint('🧹 RequestForRide: Nettoyé ${markersToRemove.length} markers chauffeurs');
      }
    } catch (e) {
      debugPrint('Erreur nettoyage markers: $e');
    }
  }

  /// Ajoute un marker de chauffeur sur la carte avec l'icône de son véhicule
  /// Utilise snap-to-road pour la position et une orientation alignée sur la route
  Future<void> _addDriverMarkerOnMap(
    String driverId,
    double lat,
    double lng,
    String? vehicleType,
    GoogleMapProvider mapProvider,
  ) async {
    try {
      BitmapDescriptor icon = BitmapDescriptor.defaultMarker;

      // Charger l'icône du type de véhicule
      if (vehicleType != null && vehicleMap.containsKey(vehicleType)) {
        final vehicleMarkerUrl = vehicleMap[vehicleType]?.marker;
        if (vehicleMarkerUrl != null && vehicleMarkerUrl.isNotEmpty) {
          try {
            icon = await mapProvider.createMarkerImageFromNetwork(vehicleMarkerUrl);
          } catch (e) {
            debugPrint('Erreur chargement icône véhicule: $e');
          }
        }
      }

      if (!mounted) return;

      // Snap-to-road : projeter la position sur la route
      final snapResult = await DriverSnapService.snapDriverPosition(
        driverId: driverId,
        currentPosition: LatLng(lat, lng),
      );

      // Position finale (snappée ou brute)
      final displayPosition = snapResult.snappedPosition;

      // Orientation : utiliser le bearing du snap ou générer aléatoirement aligné sur la route
      // Si pas de bearing disponible, générer 0° ou 180° aléatoirement (directions opposées sur la route)
      double rotation;
      if (snapResult.bearing != null) {
        rotation = snapResult.bearing!;
      } else {
        // Orientation aléatoire alignée sur la route (0° ou 180°)
        final random = math.Random();
        rotation = random.nextBool() ? 0.0 : 180.0;
      }

      if (!mounted) return;

      // Ajouter le marker avec rotation alignée sur la route
      mapProvider.markers[driverId] = Marker(
        markerId: MarkerId(driverId),
        position: displayPosition,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        rotation: rotation,
        flat: true, // Marker plat pour que la rotation fonctionne bien
        zIndex: _notifiedDrivers.length.toDouble(), // Dernier au-dessus
      );

      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      mapProvider.notifyListeners();

      debugPrint('🎯 Marker ajouté: $driverId (véhicule: $vehicleType, rotation: ${rotation.toStringAsFixed(0)}°, snapped: ${snapResult.isSnapped})');
    } catch (e) {
      debugPrint('Erreur ajout marker: $e');
    }
  }

  /// Écoute les mises à jour du booking pour afficher les chauffeurs notifiés empilés
  void _listenToNotifiedDrivers() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final booking = tripProvider.booking;

    if (booking == null || booking['id'] == null) return;

    _bookingStreamSubscription = FirebaseFirestore.instance
        .collection('bookingRequest')
        .doc(booking['id'])
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final showOnly = List<String>.from(data['showOnly'] ?? []);
          final newCount = showOnly.length;

          setState(() {
            _notifiedDriversCount = newCount;
          });

          // Nouveau chauffeur ajouté à showOnly
          if (newCount > _previousNotifiedCount && showOnly.isNotEmpty) {
            // Récupérer le dernier chauffeur ajouté et l'afficher
            // La caméra reste fixe sur ce chauffeur jusqu'au prochain
            final newDriverId = showOnly.last;
            await _fetchAndDisplayDriver(newDriverId);

            _previousNotifiedCount = newCount;
          }
          // Tous les chauffeurs ont été notifiés - on reste sur le dernier marker
          // (plus de boucle, la caméra reste fixe jusqu'au prochain chauffeur)
        }
      }
    });
  }

  /// Récupère les infos d'un chauffeur et l'affiche seul sur la carte avec zoom
  Future<void> _fetchAndDisplayDriver(String driverId) async {
    try {
      // Récupérer les données du chauffeur depuis Firestore
      final driverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();

      if (!mounted || !driverDoc.exists) return;

      final driverData = driverDoc.data();
      if (driverData == null) return;

      final lat = driverData['currentLat'] as double?;
      final lng = driverData['currentLng'] as double?;

      if (lat == null || lng == null) return;

      // Précharger l'image de profil AVANT d'ajouter le chauffeur à la liste
      final profileImage = driverData['profileImage'] as String?;
      ImageProvider? cachedImage;

      if (profileImage != null && profileImage.isNotEmpty) {
        try {
          // Précharger l'image
          final networkImage = NetworkImage(profileImage);
          await precacheImage(networkImage, context);
          cachedImage = networkImage;
        } catch (e) {
          debugPrint('Erreur préchargement image: $e');
        }
      }

      if (!mounted) return;

      // Ajouter aux chauffeurs notifiés avec l'image préchargée
      final driverInfo = {
        'id': driverId,
        'lat': lat,
        'lng': lng,
        'data': driverData,
        'cachedImage': cachedImage, // Image déjà chargée
      };

      // Éviter les doublons
      _notifiedDrivers.removeWhere((d) => d['id'] == driverId);
      _notifiedDrivers.add(driverInfo);

      // Mettre à jour l'UI maintenant que l'image est prête
      if (mounted) setState(() {});

      // Ajouter le marker du chauffeur sur la carte (avec icône véhicule)
      final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
      final vehicleType = driverData['vehicleType'] as String?;
      await _addDriverMarkerOnMap(driverId, lat, lng, vehicleType, mapProvider);

      // NOTE: Ne pas animer la caméra vers chaque chauffeur
      // La carte reste fixe sur l'itinéraire complet (pickup → drop)

    } catch (e) {
      debugPrint('Erreur récupération chauffeur $driverId: $e');
    }
  }
  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _bookingStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DarkThemeProvider>(
      builder: (context, themeProvider, child) => Container(
        decoration: BoxDecoration(
          color: MyColors.whiteThemeColor(),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: globalHorizontalPadding),
          child: ValueListenableBuilder(
            valueListenable: sheetShowNoti,
            builder: (context, sheetValue, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                _buildProgressBar(),
                if (sheetValue) ...[
                  const SizedBox(height: 16),
                  // Flexible + SingleChildScrollView pour éviter l'overflow
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Consumer<TripProvider>(
                        builder: (context, tripProvider, child) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Rangée principale: Animation + Annuler + Chauffeur
                            _buildMainActionRow(tripProvider),

                            const SizedBox(height: 16),

                            // Itinéraire compact
                            if (tripProvider.booking != null)
                              _buildCompactRoute(tripProvider),

                            // Info course planifiée
                            if (tripProvider.booking?['isPreviousSchedule'] == true)
                              _buildScheduleInfo(tripProvider),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return GestureDetector(
      onTap: () {
        sheetShowNoti.value = !sheetShowNoti.value;
        MyGlobalKeys.homePageKey.currentState?.updateBottomSheetHeight(milliseconds: 20);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: MyColors.colorD9D9D9Theme(),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: MyColors.coralPink.withOpacity(0.2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: MyColors.coralPink,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Rangée principale avec: Animation recherche | Bouton annuler | Compteur chauffeurs
  Widget _buildMainActionRow(TripProvider tripProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animation de recherche avec pulse
        _buildPulsingSearchIcon(),

        const SizedBox(width: 20),

        // Bouton annuler avec icône voiture barrée
        _buildCancelButton(tripProvider),

        const SizedBox(width: 20),

        // Compteur chauffeurs
        _buildDriverCountIcon(),
      ],
    );
  }

  /// Icône de recherche avec animation pulse
  Widget _buildPulsingSearchIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MyColors.coralPink.withOpacity(0.1),
                  border: Border.all(
                    color: MyColors.coralPink.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MyColors.coralPink.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.search,
                    size: 28,
                    color: MyColors.coralPink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 80,
              child: Text(
                translate('Searchingdrivernearbyyou'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: MyColors.blackThemeColor().withOpacity(0.6),
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Bouton annuler avec icône de voiture barrée
  Widget _buildCancelButton(TripProvider tripProvider) {
    return GestureDetector(
      onTap: () {
        if (tripProvider.booking != null) {
          _showCancelReasonBottomSheet();
        } else {
          tripProvider.setScreen(CustomTripType.confirmDestination);
        }
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MyColors.greyWhiteThemeColor(),
              border: Border.all(
                color: MyColors.borderLight,
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Icône de voiture
                Icon(
                  Icons.directions_car,
                  size: 30,
                  color: MyColors.blackThemeColor().withOpacity(0.7),
                ),
                // Barre d'annulation en diagonale
                Transform.rotate(
                  angle: -0.785, // -45 degrés
                  child: Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(
              translate('cancelRideText'),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: MyColors.blackThemeColor().withOpacity(0.6),
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Icône compteur de chauffeurs notifiés
  /// Affiche les photos de profil des chauffeurs notifiés empilées
  Widget _buildDriverCountIcon() {
    // Calculer la largeur nécessaire pour les photos empilées
    // Chaque photo fait 45px, décalées de 12px, + badge si >5
    final int visibleCount = _notifiedDrivers.length.clamp(0, 5);
    final bool hasBadge = _notifiedDrivers.length > 5;
    final double neededWidth = visibleCount > 0
        ? 45.0 + ((visibleCount - 1) * 12.0) + (hasBadge ? 12.0 : 0)
        : 70.0;

    return Column(
      children: [
        SizedBox(
          width: neededWidth.clamp(70.0, 120.0),
          height: 70,
          child: _notifiedDrivers.isEmpty
              // Aucun chauffeur notifié - afficher l'icône par défaut
              ? Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MyColors.greyWhiteThemeColor(),
                      border: Border.all(
                        color: MyColors.borderLight,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: MyColors.blackThemeColor().withOpacity(0.5),
                    ),
                  ),
                )
              // Chauffeurs notifiés - afficher les 5 derniers empilés
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    // Badge compteur des chauffeurs cachés (à gauche, derrière)
                    if (_notifiedDrivers.length > 5)
                      Positioned(
                        left: 0,
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: MyColors.coralPink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '+${_notifiedDrivers.length - 5}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Photos des 5 derniers chauffeurs (les plus récents)
                    for (int i = 0; i < 5 && i < _notifiedDrivers.length; i++)
                      Positioned(
                        // Décalage : badge +12, puis chaque photo +12
                        left: (_notifiedDrivers.length > 5 ? 12.0 : 0) + (i * 12.0),
                        child: _buildDriverAvatar(
                          // Prendre les 5 derniers (index depuis la fin)
                          _notifiedDrivers[_notifiedDrivers.length > 5
                              ? _notifiedDrivers.length - 5 + i
                              : i]['cachedImage'] as ImageProvider?,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 90,
          child: Text(
            _notifiedDriversCount > 0
                ? '$_notifiedDriversCount ${translate('driversNearby')}'
                : translate('driversNearby'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: MyColors.blackThemeColor().withOpacity(0.6),
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Construit un avatar circulaire pour un chauffeur avec image préchargée
  Widget _buildDriverAvatar(ImageProvider? cachedImage) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: cachedImage != null
            ? Image(
                image: cachedImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  /// Avatar par défaut quand pas de photo
  Widget _buildDefaultAvatar() {
    return Container(
      color: MyColors.coralPink.withOpacity(0.2),
      child: Icon(
        Icons.person,
        size: 25,
        color: MyColors.coralPink,
      ),
    );
  }

  /// Itinéraire avec titre et prix
  Widget _buildCompactRoute(TripProvider tripProvider) {
    final booking = tripProvider.booking!;
    final price = double.tryParse(booking['ride_price_to_pay'].toString()) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre "Mon itinéraire" + Prix
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              translate('myRoutes'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MyColors.blackThemeColor(),
                fontFamily: 'Poppins',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MyColors.coralPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${globalSettings.currency} ${formatAriary(price)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MyColors.coralPink,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Ligne pickup
        Row(
          children: [
            // Pin rose pour le pickup
            Icon(
              Icons.location_on,
              size: 22,
              color: MyColors.coralPink,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate("PickupLocation"),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: MyColors.blackThemeColor().withOpacity(0.5),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    booking['pickAddress'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MyColors.blackThemeColor(),
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Ligne de connexion
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Container(
            width: 2,
            height: 20,
            color: MyColors.borderLight,
          ),
        ),

        // Ligne dropoff
        Row(
          children: [
            // Carré noir avec carré blanc au centre
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: MyColors.blackThemeColor(),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('DropLocation'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: MyColors.blackThemeColor().withOpacity(0.5),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    booking['dropAddress'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MyColors.blackThemeColor(),
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleInfo(TripProvider tripProvider) {
    final booking = tripProvider.booking!;
    final scheduleTime = (booking['scheduleTime'] as Timestamp).toDate();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 16,
            color: MyColors.scheduleButtonColor6E77C5,
          ),
          const SizedBox(width: 8),
          Text(
            '${DateFormat("EEE, d MMM").format(scheduleTime)} à ${DateFormat("HH:mm").format(scheduleTime)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MyColors.scheduleButtonColor6E77C5,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelReasonBottomSheet() {
    List<String> cancelReasonList = [
      translate("Driver asked me to cancel"),
      translate("Driver not getting closer"),
      translate("Waiting time was too long"),
      translate("Driver arrived early"),
      translate("Could not find driver"),
      translate("Other"),
    ];
    List<String> cancelReasonBeforeAcceptList = [
      translate("Requested wrong vehicle"),
      translate("Waiting time was too long"),
      translate("Requested by accident"),
      translate("Selected wrong dropoff"),
      translate("Selected wrong pickup"),
      translate("Other")
    ];

    showModalBottomSheet(
      context: MyGlobalKeys.navigatorKey.currentContext!,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: MyColors.whiteThemeColor(),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: MyColors.colorD9D9D9Theme(),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  translate("Cancel Ride?"),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: MyColors.blackThemeColor(),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  translate("Why do you want to cancel?"),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: MyColors.blackThemeColor().withOpacity(0.6),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<TripProvider>(
                  builder: (context, tripProvider, child) {
                    final reasons = tripProvider.booking != null &&
                            tripProvider.booking?['status'] != 0
                        ? cancelReasonList
                        : cancelReasonBeforeAcceptList;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reasons.length,
                      itemBuilder: (context, index) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            if (tripProvider.booking != null) {
                              tripProvider.cancelRideWithBooking(
                                reason: reasons[index],
                                cancelAnotherRide: tripProvider.booking!,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: MyColors.greyWhiteThemeColor(),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: MyColors.borderLight),
                            ),
                            child: Text(
                              reasons[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: MyColors.blackThemeColor(),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
