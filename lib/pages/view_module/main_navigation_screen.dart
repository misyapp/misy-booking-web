import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/widget/adaptive/liquid_glass_colors.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen_web.dart';
import 'package:rider_ride_hailing_app/pages/view_module/my_booking_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/inbox_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/edit_profile_screen.dart';
import 'package:rider_ride_hailing_app/pages/share/live_share_viewer_screen.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';

import '../../contants/language_strings.dart';

class MainNavigationScreen extends StatefulWidget {
  final Widget? initialPage;
  const MainNavigationScreen({super.key, this.initialPage});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  // Variable statique pour accéder à l'instance active du MainNavigationScreen
  static MainNavigationScreenState? _instance;
  static MainNavigationScreenState? get instance => _instance;

  int _currentIndex = 0;

  /// Getter pour l'index actuel (utilisé par le Liquid Glass iOS)
  int get currentIndex => _currentIndex;

  late final List<Widget> _screens;

  // 🛡️ Animation pour le bouton bouclier
  late AnimationController _shieldPulseController;
  late Animation<double> _shieldPulseAnimation;

  // 🍎 Nav bar interactive: effet de pression et glissement
  bool _navBarPressed = false;
  int _navBarHoverIndex = -1; // Index du bouton sous le doigt (-1 = aucun)

  @override
  void initState() {
    super.initState();

    // Initialiser l'animation de pulsation du bouclier
    _shieldPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _shieldPulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _shieldPulseController,
        curve: Curves.easeInOut,
      ),
    );

    // 🔧 FIX: Forcer la fermeture de tout loader orphelin au démarrage
    // Cela évite qu'un loader d'une session précédente reste affiché
    WidgetsBinding.instance.addPostFrameCallback((_) {
      forceHideLoading();
    });

    // Enregistrer cette instance comme l'instance active
    _instance = this;

    // 🔧 FIX: Ne plus utiliser GlobalKey pour HomeScreen car IndexedStack
    // préserve déjà l'état des widgets enfants. L'utilisation de GlobalKey
    // causait des erreurs "Duplicate GlobalKey" lors de la navigation.
    // HomeScreen utilise AutomaticKeepAliveClientMixin pour préserver son état.
    // 🌐 WEB: Utiliser HomeScreenWeb sur le web pour une interface style Uber
    _screens = [
      widget.initialPage ?? (kIsWeb ? const HomeScreenWeb() : const HomeScreen()),
      const MyBookingScreen(),
      const InboxScreen(),
      const EditProfileScreen(),
    ];

    _screens[1] = MyBookingScreen(onBack: () => _onItemTapped(0));
  }

  void _onItemTapped(int index) {
    // Si on revient à l'onglet Home (index 0), nettoyer la carte
    if (index == 0 && _currentIndex != 0) {
      final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      // Nettoyer les polylines seulement si on est sur l'écran principal (pas de course active)
      if (tripProvider.currentStep == CustomTripType.setYourDestination ||
          tripProvider.currentStep == null) {
        mapProvider.clearAllPolylines();
        mapProvider.markers.removeWhere((key, value) =>
            key == "pickup" || key == "drop");
      }
    }

    setState(() {
      _currentIndex = index;
    });

    // Si on navigue vers l'onglet "Mes Trajets" (index 1), charger les données
    if (index == 1) {
      var tripProvider = Provider.of<TripProvider>(context, listen: false);
      tripProvider.getMyBookingList(); // Charge les trajets terminés
      tripProvider.getMyCurrentList(); // Charge les trajets actuels
    }
  }

  /// Navigue vers l'onglet Accueil (index 0)
  /// Appelé depuis TripProvider quand le flow de course démarre
  void goToHome() {
    if (_currentIndex != 0) {
      _onItemTapped(0);
    }
  }

  /// Navigue vers un onglet spécifique
  /// Appelé depuis le Liquid Glass iOS sur HomeScreen
  void navigateToIndex(int index) {
    _onItemTapped(index);
  }

  @override
  void dispose() {
    _shieldPulseController.dispose();
    // Nettoyer l'instance statique si c'est cette instance
    if (_instance == this) {
      _instance = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<DarkThemeProvider, NavigationProvider, TripProvider>(
      builder: (context, darkThemeProvider, navigationProvider, tripProvider, child) {
        // La barre de navigation ne s'affiche que sur l'écran principal (setYourDestination)
        // et reste cachée pendant tout le workflow, y compris la notation du chauffeur
        bool shouldShowNavigationBar = navigationProvider.isNavigationBarVisible &&
            (tripProvider.currentStep == null || tripProvider.currentStep == CustomTripType.setYourDestination);

        // 🛡️ Vérifier si un partage en temps réel est en attente
        bool hasPendingShare = tripProvider.hasPendingLiveShare;

        return Scaffold(
          // 🔧 FIX: Utiliser IndexedStack au lieu de PageView pour préserver
          // l'état des écrans (notamment la GoogleMap du HomeScreen)
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
              // 🛡️ Bouton bouclier flottant pour retourner au suivi en direct
              if (hasPendingShare && shouldShowNavigationBar)
                Positioned(
                  right: 16,
                  bottom: 90, // Au-dessus de la bottom nav bar
                  child: AnimatedBuilder(
                    animation: _shieldPulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _shieldPulseAnimation.value,
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onTap: () {
                        // Naviguer vers le LiveShareViewerScreen
                        final rideId = tripProvider.pendingLiveShareRideId;
                        final token = tripProvider.pendingLiveShareToken;
                        if (rideId != null && token != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveShareViewerScreen(
                                rideId: rideId,
                                token: token,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: MyColors.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MyColors.primaryColor.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Bottom Navigation Bar
          // iOS: Nav bar cachée sur Home (expandable via Liquid Glass), visible sur autres onglets
          // Android: Nav bar Material standard
          bottomNavigationBar: shouldShowNavigationBar
              ? (Platform.isIOS
                  ? (_currentIndex == 0 ? null : _buildIOSNavBarWithSearch(darkThemeProvider, tripProvider))
                  : _buildAndroidNavBar(darkThemeProvider))
              : null,
        );
      },
    );
  }

  /// Nav bar Android - Material Design standard (4 onglets)
  Widget _buildAndroidNavBar(DarkThemeProvider darkThemeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.blackColor
            : MyColors.whiteColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: MyColors.whiteThemeColor(),
        selectedItemColor: MyColors.primaryColor,
        unselectedItemColor: darkThemeProvider.darkTheme
            ? MyColors.whiteColor.withOpacity(0.6)
            : MyColors.blackColor.withOpacity(0.6),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 11,
        ),
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: translate('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.directions_car_outlined),
            activeIcon: const Icon(Icons.directions_car),
            label: translate('myBooking'),
          ),
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<int>(
              valueListenable: unreadMessagesCount,
              builder: (context, count, child) {
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.mail_outlined),
                );
              },
            ),
            activeIcon: ValueListenableBuilder<int>(
              valueListenable: unreadMessagesCount,
              builder: (context, count, child) {
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.mail),
                );
              },
            ),
            label: translate('myMail'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: translate('myProfile'),
          ),
        ],
      ),
    );
  }

  /// Nav bar iOS - Style Liquid Glass (même couleur que la bottom sheet Home)
  /// Layout: [Capsule: Home | Trajets | Courrier | Profil] + [🔍 Loupe séparée]
  Widget _buildIOSNavBarWithSearch(
      DarkThemeProvider darkThemeProvider, TripProvider tripProvider) {
    final isDarkMode = darkThemeProvider.darkTheme;
    final backgroundColor = LiquidGlassColors.getBackgroundColor(isDarkMode);

    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LiquidGlassColors.blurSigma,
          sigmaY: LiquidGlassColors.blurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(LiquidGlassColors.collapsedOpacity),
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: LiquidGlassColors.shadowColor,
                blurRadius: LiquidGlassColors.shadowBlurRadius,
                offset: LiquidGlassColors.shadowOffset,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  // Capsule principale avec les 4 items
                  Expanded(
                    child: _buildNavCapsule(isDarkMode),
                  ),
                  const SizedBox(width: 12),
                  // Bouton loupe séparé (bulle circulaire)
                  _buildSearchBubble(isDarkMode, tripProvider),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Capsule principale contenant les 4 onglets avec animation interactive
  Widget _buildNavCapsule(bool isDarkMode) {
    // Couleurs adaptées au fond Liquid Glass (clair)
    final activeColor = isDarkMode ? MyColors.whiteColor : MyColors.blackColor;
    final inactiveColor = isDarkMode
        ? MyColors.whiteColor.withOpacity(0.6)
        : MyColors.blackColor.withOpacity(0.5);
    final activeBgColor = isDarkMode
        ? MyColors.whiteColor.withOpacity(0.2)
        : MyColors.blackColor.withOpacity(0.1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final capsuleWidth = constraints.maxWidth;
        final itemWidth = capsuleWidth / 4;

        // Calcule l'index sous le doigt pendant le drag
        int getIndexFromX(double x) {
          final index = (x / itemWidth).floor();
          return index.clamp(0, 3);
        }

        // Calcule la position X de l'indicateur
        double getIndicatorX() {
          if (_navBarPressed && _navBarHoverIndex >= 0) {
            // Pendant le drag, suit le doigt
            return _navBarHoverIndex * itemWidth;
          }
          // Sinon, position de l'onglet actif
          return _currentIndex * itemWidth;
        }

        return GestureDetector(
          onPanStart: (details) {
            final index = getIndexFromX(details.localPosition.dx);
            setState(() {
              _navBarPressed = true;
              _navBarHoverIndex = index;
            });
          },
          onPanUpdate: (details) {
            final index = getIndexFromX(details.localPosition.dx);
            setState(() {
              _navBarHoverIndex = index;
            });
          },
          onPanEnd: (details) {
            final targetIndex = _navBarHoverIndex;
            setState(() {
              _navBarPressed = false;
              _navBarHoverIndex = -1;
            });
            // Naviguer vers l'onglet sélectionné
            if (targetIndex >= 0 && targetIndex != _currentIndex) {
              _onItemTapped(targetIndex);
            }
          },
          child: AnimatedScale(
            scale: _navBarPressed ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Stack(
                children: [
                  // Indicateur glissant animé
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    left: getIndicatorX() + 4,
                    top: 4,
                    child: Container(
                      width: itemWidth - 8,
                      height: 48,
                      decoration: BoxDecoration(
                        color: activeBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  // Row des items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. Home
                      _buildAnimatedCapsuleItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        label: translate('home'),
                        index: 0,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        itemWidth: itemWidth,
                      ),
                      // 2. Mes Trajets
                      _buildAnimatedCapsuleItem(
                        icon: Icons.directions_car_outlined,
                        activeIcon: Icons.directions_car,
                        label: translate('myBooking'),
                        index: 1,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        itemWidth: itemWidth,
                      ),
                      // 3. Courrier avec badge
                      _buildAnimatedCapsuleItemWithBadge(
                        icon: Icons.mail_outlined,
                        activeIcon: Icons.mail,
                        label: translate('myMail'),
                        index: 2,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        itemWidth: itemWidth,
                      ),
                      // 4. Profil
                      _buildAnimatedCapsuleItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: translate('myProfile'),
                        index: 3,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        itemWidth: itemWidth,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Item animé dans la capsule - avec support hover pendant le drag
  Widget _buildAnimatedCapsuleItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required Color activeColor,
    required Color inactiveColor,
    required double itemWidth,
  }) {
    // L'item est actif si c'est l'index courant OU si c'est l'item sous le doigt pendant le drag
    final isActive = _currentIndex == index ||
        (_navBarPressed && _navBarHoverIndex == index);

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Item animé avec badge (pour courrier) - avec support hover pendant le drag
  Widget _buildAnimatedCapsuleItemWithBadge({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required Color activeColor,
    required Color inactiveColor,
    required double itemWidth,
  }) {
    final isActive = _currentIndex == index ||
        (_navBarPressed && _navBarHoverIndex == index);

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: unreadMessagesCount,
              builder: (context, count, child) {
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(fontSize: 9),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      color: isActive ? activeColor : inactiveColor,
                      size: 22,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton loupe séparé - Style Liquid Glass
  Widget _buildSearchBubble(bool isDarkMode, TripProvider tripProvider) {
    return GestureDetector(
      onTap: () {
        // S'assurer qu'on est sur l'onglet Home
        if (_currentIndex != 0) {
          _onItemTapped(0);
        }
        // Naviguer vers la sélection pickup/drop
        tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          // Transparent - utilise la couleur du parent Liquid Glass
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.search,
          color: isDarkMode
              ? MyColors.whiteColor.withOpacity(0.9)
              : MyColors.blackColor.withOpacity(0.7),
          size: 26,
        ),
      ),
    );
  }
}
