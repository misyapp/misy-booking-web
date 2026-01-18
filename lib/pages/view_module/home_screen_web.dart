import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart' show LoginPage;

/// Page d'accueil Web style Uber - version allégée
/// Affiche une carte pleine page avec:
/// - Header avec logo + onglets + boutons connexion
/// - Carte Google Maps en fond
/// - Formulaire de recherche flottant à gauche
class HomeScreenWeb extends StatefulWidget {
  const HomeScreenWeb({super.key});

  @override
  State<HomeScreenWeb> createState() => _HomeScreenWebState();
}

class _HomeScreenWebState extends State<HomeScreenWeb> {
  GoogleMapController? _mapController;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Position par défaut: Antananarivo, Madagascar
  static const LatLng _defaultPosition = LatLng(-18.8792, 47.5079);
  LatLng _currentPosition = _defaultPosition;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      await getCurrentLocation();
      if (currentPosition != null) {
        setState(() {
          _currentPosition = LatLng(
            currentPosition!.latitude,
            currentPosition!.longitude,
          );
          _isLoadingLocation = false;
        });

        // Mettre à jour l'adresse pickup si disponible
        if (currentFullAddress != null) {
          _pickupController.text = currentFullAddress!;
        }

        // Animer vers la position actuelle
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition, 14),
        );
      } else {
        setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
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

          // Formulaire de recherche flottant
          _buildSearchCard(),
        ],
      ),
    );
  }

  /// Carte Google Maps pleine page
  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentPosition,
        zoom: 13,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        // Si on a déjà la position, animer vers elle
        if (!_isLoadingLocation && _currentPosition != _defaultPosition) {
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition, 14),
          );
        }
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: false,
      // Style de carte plus léger pour le web
      mapType: MapType.normal,
      gestureRecognizers: const {},
    );
  }

  /// Header avec logo Misy + onglets + boutons connexion
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

              // Onglets de navigation
              _buildNavTab('Course', Icons.directions_car, true),
              // _buildNavTab('Réservations', Icons.calendar_today, false),

              const Spacer(),

              // Boutons connexion/inscription ou profil
              if (!isLoggedIn) ...[
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
                  onPressed: () => _navigateToLogin(),
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
                // Utilisateur connecté - afficher le profil
                PopupMenuButton<String>(
                  offset: const Offset(0, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: MyColors.primaryColor,
                        child: Text(
                          (user?.firstName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user?.fullName ?? 'Utilisateur',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                  onSelected: (value) {
                    if (value == 'logout') {
                      final authProvider = Provider.of<CustomAuthProvider>(context, listen: false);
                      authProvider.logout(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline),
                          SizedBox(width: 8),
                          Text('Mon profil'),
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

  /// Formulaire de recherche flottant (style Uber)
  Widget _buildSearchCard() {
    return Positioned(
      top: 100,
      left: 24,
      child: Container(
        width: 360,
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

            // Champs de saisie avec icônes
            _buildLocationInputs(),

            const SizedBox(height: 16),

            // Options de prise en charge
            _buildScheduleOptions(),

            const SizedBox(height: 16),

            // Bouton Rechercher
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Rechercher',
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
    );
  }

  /// Champs de saisie Pickup et Destination avec ligne verticale
  Widget _buildLocationInputs() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icônes avec ligne verticale (couleurs Misy)
        Column(
          children: [
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
              height: 40,
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
                decoration: InputDecoration(
                  hintText: 'Lieu de prise en charge',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
              ),

              Divider(color: Colors.grey.shade300, height: 1),

              // Destination
              TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: 'Destination',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ],
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

  void _onSearch() {
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

    // TODO: Lancer la recherche de véhicules
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    tripProvider.setScreen(CustomTripType.choosePickupDropLocation);
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}
