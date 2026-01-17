import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/models/popular_destination.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/popular_destinations_service.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';

class PopularDestinationsWidget extends StatefulWidget {
  final Function(PopularDestination)? onDestinationTap;

  const PopularDestinationsWidget({
    super.key,
    this.onDestinationTap,
  });

  @override
  State<PopularDestinationsWidget> createState() => _PopularDestinationsWidgetState();
}

class _PopularDestinationsWidgetState extends State<PopularDestinationsWidget> {
  Future<List<PopularDestination>>? _destinationsFuture;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  void _loadDestinations() {
    _destinationsFuture = PopularDestinationsService.getDestinations(
      userLatitude: currentPosition?.latitude,
      userLongitude: currentPosition?.longitude,
    );
  }

  void _refreshDestinations() {
    setState(() {
      _destinationsFuture = PopularDestinationsService.refreshDestinations(
        userLatitude: currentPosition?.latitude,
        userLongitude: currentPosition?.longitude,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkThemeProvider = Provider.of<DarkThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Texte "Destination populaire" supprimé
        // IconButton de refresh conservé si besoin
        SizedBox(
          height: 180, // réduit
          child: FutureBuilder<List<PopularDestination>>(
            future: _destinationsFuture,
            builder: (context, snapshot) {
              final tripProvider = Provider.of<TripProvider>(context);
              // Suppression du loading si le bottom sheet est en mi-hauteur
              final isHalfHeight = tripProvider.currentStep == CustomTripType.setYourDestination;
              if (snapshot.connectionState == ConnectionState.waiting && !isHalfHeight) {
                return _buildLoadingState(darkThemeProvider);
              }
              if (snapshot.hasError) {
                return _buildErrorState(darkThemeProvider, snapshot.error.toString());
              }
              final destinations = snapshot.data ?? [];
              // Masquer l'état vide si en mi-hauteur et en attente
              if (destinations.isEmpty && (!isHalfHeight || snapshot.connectionState != ConnectionState.waiting)) {
                return _buildEmptyState(darkThemeProvider);
              }
              if (destinations.isEmpty) {
                return SizedBox.shrink(); // Ne rien afficher
              }
              // Animation de fondu sur l'apparition des destinations
              if (destinations.isNotEmpty) {
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeIn,
                  child: SingleChildScrollView(
                    child: Column(
                      children: destinations.map((destination) =>
                        _buildDestinationItem(destination, darkThemeProvider, context)
                      ).toList(),
                    ),
                  ),
                );
              }
              return SizedBox.shrink(); // Ne rien afficher par défaut
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(DarkThemeProvider darkThemeProvider) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: MyColors.horizonBlue,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            translate('Loading destinations...'),
            style: TextStyle(
              color: darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor.withValues(alpha: 0.7)
                  : MyColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(DarkThemeProvider darkThemeProvider, String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            translate('Unable to load destinations'),
            style: TextStyle(
              color: darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor
                  : MyColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            translate('Using cached destinations'),
            style: TextStyle(
              color: darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor.withValues(alpha: 0.7)
                  : MyColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _refreshDestinations,
            child: Text(
              translate('Retry'),
              style: TextStyle(
                color: MyColors.horizonBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(DarkThemeProvider darkThemeProvider) {
    // Ne rien afficher si aucune destination disponible
    return const SizedBox.shrink();
  }

  Widget _buildDestinationItem(
    PopularDestination destination, 
    DarkThemeProvider darkThemeProvider,
    BuildContext context,
  ) {
    // Extraction du nom de la ville (suppose que c'est le dernier mot de l'adresse)
    String city = _extractCity(destination.address);
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // réduit
      child: InkWell(
        onTap: () {
          if (widget.onDestinationTap != null) {
            widget.onDestinationTap!(destination);
          } else {
            _handleDestinationTap(destination, context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6), // réduit
              decoration: BoxDecoration(
                color: Color(0xFFF9F5F5), // nouvelle couleur de fond pour l'icône
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                destination.icon,
                color: MyColors.horizonBlue,
                size: 20, // réduit
              ),
            ),
            hSizedBox,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name, // Titre
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkThemeProvider.darkTheme
                          ? MyColors.whiteColor
                          : MyColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Extraction du nom de la ville uniquement (sans code Google Plus)
                  Text(
                    _extractCity(destination.address),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: darkThemeProvider.darkTheme
                          ? MyColors.whiteColor.withValues(alpha: 0.7)
                          : MyColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: darkThemeProvider.darkTheme
                  ? MyColors.whiteColor.withValues(alpha: 0.5)
                  : MyColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _handleDestinationTap(PopularDestination destination, BuildContext context) async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);

    // Cacher la barre de navigation
    navigationProvider.setNavigationBarVisibility(false);
    
    try {
      showLoading();
      
      // Définir pickup comme position actuelle
      final pickupLocationData = {
        "lat": currentPosition?.latitude ?? -18.8792,
        "lng": currentPosition?.longitude ?? 47.5079,
        "address": currentFullAddress ?? "Ma position",
      };
      
      // Définir la destination choisie
      final dropLocationData = {
        "lat": destination.latitude,
        "lng": destination.longitude,
        "address": destination.address,
      };

      // Assigner les locations au TripProvider
      tripProvider.pickLocation = pickupLocationData;
      tripProvider.dropLocation = dropLocationData;
      
      // Créer le chemin sur la carte
      await tripProvider.createPath(topPaddingPercentage: 0.8);
      
      // Passer directement à la sélection de véhicule
      tripProvider.setScreen(CustomTripType.chooseVehicle);
      
      hideLoading();
    } catch (e) {
      hideLoading();
      // Gérer l'erreur si nécessaire
    }
  }

  // Correction de la méthode utilitaire pour extraire la ville
  String _extractCity(String address) {
    var parts = address.split(',');
    for (var part in parts) {
      part = part.trim();
      // Un code Google Plus est souvent sous forme "XXXX+XX"
      if (!RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]{2,}\$').hasMatch(part) && part.isNotEmpty) {
        return part;
      }
    }
    // Si rien trouvé, on retourne le dernier élément
    return parts.isNotEmpty ? parts.last.trim() : '';
  }
}