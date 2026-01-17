import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_drawer.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/pickup_and_drop_location_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/schedule_ride_with_custom_time.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/confirm_destination.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/choose_vehicle_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/select_payment_method_sheet.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/request_for_ride.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/payment_mobile_number_confirmation.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/select_available_promocode.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/widget/popular_destinations_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  late GoogleMapController _mapController;
  bool _isMapReady = false;
  late AnimationController _bottomSheetController;

  // Quatre états glissants selon les spécifications
  static const double _stateMinimal = 0.20; // 1/5 de l'écran - barre de recherche seule
  static const double _stateLow = 0.33; // 1/3 de l'écran - tuiles + barre de recherche
  static const double _stateMedium = 0.67; // 2/3 de l'écran - état par défaut + destinations populaires
  static const double _stateFull = 1.0; // 100% de l'écran - contenu complet

  double _currentBottomSheetHeight = _stateMedium; // État par défaut au lancement
  double _dragStartHeight = 0.0;
  bool _isDragging = false;
  LatLng? _mapReferencePosition;
  PaymentMethodType? selectedPaymentMethod;
  CameraPosition? cameraLastPosition;
  bool loaded = false;
  double _mapBottomPadding = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bottomSheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialiser avec l'état moyen (2/3) par défaut
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripProvider>(context, listen: false)
          .setScreen(CustomTripType.setYourDestination);
      _initializeMapReference();
      getLocation();
      _applyMapPadding();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bottomSheetController.dispose();
    super.dispose();
  }

  void _applyMapPadding() {
    if (!mounted) return;
    try {
      final h = MediaQuery.of(context).size.height;
      final bottomPadding = (h * _currentBottomSheetHeight).clamp(0.0, h).toDouble();
      setState(() {
        _mapBottomPadding = bottomPadding + 8.0;
      });
    } catch (_) {}
  }

  void _initializeMapReference() {
    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    _mapReferencePosition = mapProvider.currentPosition ?? mapProvider.initialPosition;

    if (_mapReferencePosition == null) {
      _mapReferencePosition = const LatLng(48.8566, 2.3522); // Paris par défaut

      Future.delayed(const Duration(seconds: 2), () {
        final updatedPosition = mapProvider.currentPosition ?? mapProvider.initialPosition;
        if (updatedPosition != null) {
          _mapReferencePosition = updatedPosition;
        }
      });
    }
  }

  /// Gestion du glissement pour les 4 états
  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartHeight = _currentBottomSheetHeight;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final deltaY = -details.delta.dy; // Inverser pour glissement naturel
    final deltaHeight = deltaY / screenHeight;

    setState(() {
      _currentBottomSheetHeight = (_dragStartHeight + deltaHeight)
          .clamp(_stateMinimal, _stateFull);
    });

    _applyMapPadding();
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    // Déterminer l'état cible le plus proche
    double targetHeight;
    final distances = [
      (_currentBottomSheetHeight - _stateMinimal).abs(),
      (_currentBottomSheetHeight - _stateLow).abs(),
      (_currentBottomSheetHeight - _stateMedium).abs(),
      (_currentBottomSheetHeight - _stateFull).abs(),
    ];

    final minDistanceIndex = distances.indexOf(distances.reduce((a, b) => a < b ? a : b));

    switch (minDistanceIndex) {
      case 0: targetHeight = _stateMinimal; break;
      case 1: targetHeight = _stateLow; break;
      case 2: targetHeight = _stateMedium; break;
      case 3: targetHeight = _stateFull; break;
      default: targetHeight = _stateMedium;
    }

    _animateToHeight(targetHeight);
  }

  void _animateToHeight(double targetHeight) {
    final animation = Tween<double>(
      begin: _currentBottomSheetHeight,
      end: targetHeight,
    ).animate(CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeOutCubic,
    ));

    animation.addListener(() {
      setState(() {
        _currentBottomSheetHeight = animation.value;
      });
      _applyMapPadding();
    });

    _bottomSheetController.reset();
    _bottomSheetController.forward();
  }

  /// Calcule l'opacité des éléments selon l'état
  double _getElementOpacity(double minHeight, double maxHeight) {
    if (_currentBottomSheetHeight < minHeight) return 0.0;
    if (_currentBottomSheetHeight > maxHeight) return 1.0;

    return ((_currentBottomSheetHeight - minHeight) / (maxHeight - minHeight))
        .clamp(0.0, 1.0);
  }

  /// Détermine si un élément doit être interactif
  bool _isElementInteractive(double minHeight) {
    return _currentBottomSheetHeight >= minHeight;
  }

  getLocation() async {
    var tripProvider = Provider.of<TripProvider>(context, listen: false);
    if (positionStream == null) {
      startLocationListner(() async {
        if (loaded == false) {
          loaded = true;
        }
        tripProvider.locationChange();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && locationPopUpOpend) {
      PermissionStatus m1;
      if (Platform.isAndroid) {
        m1 = await Permission.locationWhenInUse.status;
      } else {
        m1 = await Permission.locationWhenInUse.request();
      }
      if (Platform.isAndroid &&
          (m1 == PermissionStatus.denied) &&
          locationPopUpOpend) {
        showPermissionNeedPopup();
      } else if (Platform.isIOS &&
          (m1 == PermissionStatus.denied ||
              m1 == PermissionStatus.permanentlyDenied) &&
          locationPopUpOpend) {
        ask();
      }
    }
  }

  void updateBottomSheetHeight({int milliseconds = 300}) {
    Future.delayed(Duration(milliseconds: milliseconds), () {
      _animateToHeight(_stateMedium);
    });
  }

  void removeOtherDriverMarkers() {
    // Méthode pour la compatibilité
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(builder: (context, tripProvider, child) {
      return WillPopScope(
        onWillPop: () async {
          final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
          if (tripProvider.currentStep != null &&
              tripProvider.currentStep != CustomTripType.setYourDestination) {
            // Logique de navigation arrière existante
            navigationProvider.setNavigationBarVisibility(true);
            tripProvider.setScreen(CustomTripType.setYourDestination);
            updateBottomSheetHeight();
            return false;
          } else {
            navigationProvider.setNavigationBarVisibility(true);
            return true;
          }
        },
        child: Consumer3<DarkThemeProvider, GoogleMapProvider, TripProvider>(
          builder: (context, darkThemeProvider, mapProvider, tripProvider, child) {
            final screenHeight = MediaQuery.of(context).size.height;

            // Gérer les autres états avec l'ancien système (étapes avancées du trip)
            if (tripProvider.currentStep != null &&
                tripProvider.currentStep != CustomTripType.setYourDestination &&
                tripProvider.currentStep != CustomTripType.choosePickupDropLocation &&
                tripProvider.currentStep != CustomTripType.selectScheduleTime) {

              return Scaffold(
                key: _scaffoldKey,
                drawer: const CustomDrawer(),
                body: Stack(
                  children: [
                    _buildGoogleMap(mapProvider),
                    if (tripProvider.currentStep != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: darkThemeProvider.darkTheme
                                ? MyColors.blackColor
                                : MyColors.whiteColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: _buildClassicBottomSheetContent(tripProvider),
                          ),
                        ),
                      ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 16,
                      child: _buildBackButton(darkThemeProvider, tripProvider),
                    ),
                  ],
                ),
              );
            }

            // Interface pour les widgets autonomes
            if (tripProvider.currentStep == CustomTripType.choosePickupDropLocation ||
                tripProvider.currentStep == CustomTripType.selectScheduleTime) {
              return Scaffold(
                key: _scaffoldKey,
                body: Stack(
                  children: [
                    _buildGoogleMap(mapProvider),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: tripProvider.currentStep == CustomTripType.choosePickupDropLocation
                          ? PickupAndDropLocation(
                              key: MyGlobalKeys.chooseDropAndPickAddPageKey,
                              onTap: (pickup, drop) async {
                                try {
                                  showLoading();
                                  tripProvider.pickLocation = pickup;
                                  tripProvider.dropLocation = drop;
                                  await tripProvider.createPath(topPaddingPercentage: 0.8);
                                  tripProvider.setScreen(CustomTripType.chooseVehicle);
                                  updateBottomSheetHeight();
                                  hideLoading();
                                } catch (e) {
                                  hideLoading();
                                }
                              },
                            )
                          : const SceduleRideWithCustomeTime(),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 16,
                      child: _buildMenuButton(darkThemeProvider),
                    ),
                    if (tripProvider.currentStep == CustomTripType.selectScheduleTime)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        right: 16,
                        child: _buildBackButton(darkThemeProvider, tripProvider),
                      ),
                  ],
                ),
              );
            }

            // Interface moderne pour setYourDestination avec 4 états glissants
            return Scaffold(
              key: _scaffoldKey,
              drawer: const CustomDrawer(),
              body: Stack(
                children: [
                  // Carte Google Maps
                  _buildGoogleMap(mapProvider),

                  // Bottom Sheet avec gestion des 4 états
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onPanStart: _handlePanStart,
                      onPanUpdate: _handlePanUpdate,
                      onPanEnd: _handlePanEnd,
                      child: AnimatedContainer(
                        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        height: screenHeight * _currentBottomSheetHeight,
                        decoration: BoxDecoration(
                          color: darkThemeProvider.darkTheme
                              ? MyColors.blackColor
                              : MyColors.whiteColor,
                          borderRadius: _currentBottomSheetHeight >= _stateFull
                              ? null
                              : const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                          boxShadow: _currentBottomSheetHeight >= _stateFull
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                        ),
                        child: _buildSlidingBottomSheetContent(darkThemeProvider, tripProvider),
                      ),
                    ),
                  ),

                  // Bouton menu
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 16,
                    child: _buildMenuButton(darkThemeProvider),
                  ),

                  // Bouton géolocalisation
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    bottom: screenHeight * _currentBottomSheetHeight + 20,
                    right: 16,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _currentBottomSheetHeight < _stateFull ? 1.0 : 0.0,
                      child: _buildLocationButton(darkThemeProvider),
                    ),
                  ),

                  // Curseurs de sélection pour les emplacements
                  ValueListenableBuilder(
                    valueListenable: dropLocationPickerHideNoti,
                    builder: (context, hidePicker, child) =>
                        hidePicker == false
                            ? Container()
                            : Center(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 30),
                                  child: Image.asset(
                                    MyImagesUrl.locationSelectFromMap(),
                                    height: 40,
                                    width: 40,
                                  ),
                                ),
                              ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: pickupLocationPickerHideNoti,
                    builder: (context, hidePicker, child) =>
                        hidePicker == false
                            ? Container()
                            : Center(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 30),
                                  child: Image.asset(
                                    MyImagesUrl.locationSelectFromMap(),
                                    height: 40,
                                    width: 40,
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  /// Construit le contenu du bottom sheet avec les 4 états
  Widget _buildSlidingBottomSheetContent(DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    return SafeArea(
      child: Column(
        children: [
          // Poignée de glissement
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  // État 1/3 et plus : Tuiles "Trajets" et "Trajets planifiés"
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _getElementOpacity(_stateLow, _stateLow + 0.05),
                    child: IgnorePointer(
                      ignoring: !_isElementInteractive(_stateLow),
                      child: _buildTiles(darkThemeProvider, tripProvider),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tous les états : Barre de recherche "Où allez-vous ?"
                  _buildSearchBar(darkThemeProvider, tripProvider),

                  const SizedBox(height: 20),

                  // État 2/3 et plus : Destinations populaires
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _getElementOpacity(_stateMedium, _stateMedium + 0.05),
                    child: IgnorePointer(
                      ignoring: !_isElementInteractive(_stateMedium),
                      child: _buildPopularDestinations(darkThemeProvider),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // État 100% : Contenu complet supplémentaire
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _getElementOpacity(_stateFull - 0.05, _stateFull),
                    child: IgnorePointer(
                      ignoring: !_isElementInteractive(_stateFull - 0.05),
                      child: _buildFullContent(darkThemeProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit les tuiles "Trajets" et "Trajets planifiés"
  Widget _buildTiles(DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildTile(
              icon: Icons.route,
              title: "Trajets",
              onTap: () {
                tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
              },
              darkThemeProvider: darkThemeProvider,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTile(
              icon: Icons.schedule,
              title: "Trajets planifiés",
              onTap: () {
                tripProvider.setScreen(CustomTripType.selectScheduleTime);
              },
              darkThemeProvider: darkThemeProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required DarkThemeProvider darkThemeProvider,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: darkThemeProvider.darkTheme
              ? MyColors.greyColor.withOpacity(0.1)
              : MyColors.greyColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: darkThemeProvider.darkTheme
                ? MyColors.greyColor.withOpacity(0.2)
                : MyColors.greyColor.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: MyColors.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: darkThemeProvider.darkTheme
                      ? MyColors.whiteColor
                      : MyColors.blackColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit la barre de recherche
  Widget _buildSearchBar(DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: darkThemeProvider.darkTheme
                ? MyColors.greyColor.withOpacity(0.1)
                : MyColors.greyColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: darkThemeProvider.darkTheme
                  ? MyColors.greyColor.withOpacity(0.3)
                  : MyColors.greyColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: MyColors.greyColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "Où allez-vous ?",
                style: TextStyle(
                  fontSize: 16,
                  color: MyColors.greyColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit les destinations populaires
  Widget _buildPopularDestinations(DarkThemeProvider darkThemeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Destinations populaires",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: darkThemeProvider.darkTheme
                  ? MyColors.whiteColor
                  : MyColors.blackColor,
            ),
          ),
          const SizedBox(height: 12),
          const PopularDestinationsWidget(),
        ],
      ),
    );
  }

  /// Construit le contenu complet (état 100%)
  Widget _buildFullContent(DarkThemeProvider darkThemeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Options supplémentaires",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: darkThemeProvider.darkTheme
                  ? MyColors.whiteColor
                  : MyColors.blackColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: darkThemeProvider.darkTheme
                  ? MyColors.greyColor.withOpacity(0.1)
                  : MyColors.greyColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                "Contenu complet\n(historique, favoris, etc.)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MyColors.greyColor,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildGoogleMap(GoogleMapProvider mapProvider) {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _isMapReady = true;
        mapProvider.setController(controller);
        mapProvider.setMapStyle(context);
        Future.delayed(const Duration(milliseconds: 100), _applyMapPadding);
      },
      initialCameraPosition: CameraPosition(
        target: mapProvider.initialPosition ?? const LatLng(48.8566, 2.3522),
        zoom: 15.0,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      padding: EdgeInsets.only(bottom: _mapBottomPadding),
      markers: Set<Marker>.from(mapProvider.markers.values),
      polylines: mapProvider.polyLines,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(
          () => EagerGestureRecognizer(),
        ),
      },
      onCameraMove: (CameraPosition position) {
        cameraLastPosition = position;
      },
      onCameraIdle: () {
        if (cameraLastPosition != null && dropLocationPickerHideNoti.value) {
          MyGlobalKeys.chooseDropAndPickAddPageKey.currentState!
              .pickedLocationLatLong(
            latitude: cameraLastPosition!.target.latitude,
            longitude: cameraLastPosition!.target.longitude,
          );
        }
        if (cameraLastPosition != null && pickupLocationPickerHideNoti.value) {
          MyGlobalKeys.chooseDropAndPickAddPageKey.currentState!
              .pickUpLocationMapLatLong(
            latitude: cameraLastPosition!.target.latitude,
            longitude: cameraLastPosition!.target.longitude,
          );
        }
      },
    );
  }

  Widget _buildMenuButton(DarkThemeProvider darkThemeProvider) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.blackColor.withOpacity(0.8)
            : MyColors.whiteColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Icon(
            Icons.menu,
            color: darkThemeProvider.darkTheme
                ? MyColors.whiteColor
                : MyColors.blackColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationButton(DarkThemeProvider darkThemeProvider) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.blackColor.withOpacity(0.8)
            : MyColors.whiteColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
            final currentPos = mapProvider.currentPosition;

            if (currentPos != null) {
              mapProvider.animateToNewTarget(
                currentPos.latitude,
                currentPos.longitude,
                zoom: 15.0,
                bearing: 0.0,
              );
              _mapReferencePosition = currentPos;
            }
          },
          child: Icon(
            Icons.my_location,
            color: darkThemeProvider.darkTheme
                ? MyColors.whiteColor
                : MyColors.blackColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.blackColor.withOpacity(0.8)
            : MyColors.whiteColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
            navigationProvider.setNavigationBarVisibility(true);
            tripProvider.setScreen(CustomTripType.setYourDestination);
            updateBottomSheetHeight();
          },
          child: Icon(
            Icons.arrow_back,
            color: darkThemeProvider.darkTheme
                ? MyColors.whiteColor
                : MyColors.blackColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildClassicBottomSheetContent(TripProvider tripProvider) {
    // Contenu des bottom sheets pour les autres étapes du trip
    switch (tripProvider.currentStep) {
      case CustomTripType.chooseVehicle:
        return const ChooseVehicleSheet();
      case CustomTripType.payment:
        return const SelectPaymentMethodSheet();
      case CustomTripType.confirmDestination:
        return const ConfirmDestination();
      case CustomTripType.requestForRide:
        return const RequestForRide();
      case CustomTripType.selectAvailablePromocode:
        return const SelectAvailablePromocode();
      case CustomTripType.paymentMobileConfirm:
        return const PaymentMobileNumberConfirmation();
      default:
        return Container();
    }
  }
}
