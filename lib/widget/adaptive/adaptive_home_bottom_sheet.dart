import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'platform_utils.dart';
import 'liquid_glass_container.dart';
import 'liquid_glass_colors.dart';

/// Bottom sheet adaptative pour la page d'accueil
/// - iOS: Style Liquid Glass avec 3 états (bulle flottante)
/// - Android: Style Material classique
class AdaptiveHomeBottomSheet extends StatefulWidget {
  /// Callback quand l'utilisateur tape sur "Trajets" (course immédiate)
  final VoidCallback onInstantTripTap;

  /// Callback quand l'utilisateur tape sur "Trajets planifiés"
  final VoidCallback onScheduledTripTap;

  /// Callback quand l'utilisateur tape sur le champ de recherche
  final VoidCallback onSearchTap;

  /// Callback quand l'utilisateur tape sur "Choisir sur la carte"
  final VoidCallback onMapPickerTap;

  /// Builder pour le contenu des véhicules (trajets + planifiés)
  final Widget Function(BuildContext context) vehicleOptionsBuilder;

  /// Builder pour le champ de recherche
  final Widget Function(BuildContext context) searchFieldBuilder;

  /// Builder pour les actions rapides (carte + dernière adresse)
  final Widget Function(BuildContext context) quickActionsBuilder;

  /// Builder pour le contenu additionnel (destinations populaires)
  final Widget Function(BuildContext context) additionalContentBuilder;

  /// Hauteur actuelle du bottom sheet Android (0.0 à 1.0)
  final double currentHeight;

  /// Callback pour mettre à jour la hauteur Android
  final ValueChanged<double>? onHeightChanged;

  /// Hauteurs de référence pour Android
  final double lowestHeight;
  final double minHeight;
  final double midHeight;
  final double maxHeight;

  const AdaptiveHomeBottomSheet({
    super.key,
    required this.onInstantTripTap,
    required this.onScheduledTripTap,
    required this.onSearchTap,
    required this.onMapPickerTap,
    required this.vehicleOptionsBuilder,
    required this.searchFieldBuilder,
    required this.quickActionsBuilder,
    required this.additionalContentBuilder,
    required this.currentHeight,
    this.onHeightChanged,
    this.lowestHeight = 0.10,
    this.minHeight = 0.30,
    this.midHeight = 0.55,
    this.maxHeight = 0.78,
  });

  @override
  State<AdaptiveHomeBottomSheet> createState() => _AdaptiveHomeBottomSheetState();
}

class _AdaptiveHomeBottomSheetState extends State<AdaptiveHomeBottomSheet> {
  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return _buildIOSLiquidGlass(context);
    } else {
      return _buildAndroidMaterial(context);
    }
  }

  /// Version iOS avec Liquid Glass (3 états)
  Widget _buildIOSLiquidGlass(BuildContext context) {
    final darkThemeProvider = Provider.of<DarkThemeProvider>(context);
    final isDarkMode = darkThemeProvider.darkTheme;

    return LiquidGlassContainer(
      initialState: LiquidGlassState.intermediate,
      backgroundColor: isDarkMode
          ? LiquidGlassColors.sheetBackgroundDark
          : LiquidGlassColors.sheetBackground,
      collapsedBuilder: (ctx) => _buildCollapsedContent(ctx, isDarkMode),
      intermediateBuilder: (ctx) => _buildIntermediateContent(ctx, isDarkMode),
      expandedBuilder: (ctx) => _buildExpandedContent(ctx, isDarkMode),
    );
  }

  /// État collapsed (80px) - Juste "Où allez-vous ?"
  Widget _buildCollapsedContent(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: widget.onSearchTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : MyColors.horizonBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.search,
                color: MyColors.horizonBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                translate('Whereto'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : MyColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.5)
                  : MyColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// État intermediate (38%) - Titre + Boutons + Recherche
  Widget _buildIntermediateContent(BuildContext context, bool isDarkMode) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Text(
              translate('chooseYourTrip'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : MyColors.blackColor,
              ),
            ),
            const SizedBox(height: 12),
            // Options véhicules
            widget.vehicleOptionsBuilder(context),
            const SizedBox(height: 8),
            // Champ de recherche
            widget.searchFieldBuilder(context),
          ],
        ),
      ),
    );
  }

  /// État expanded (90%) - Contenu complet avec scroll
  Widget _buildExpandedContent(BuildContext context, bool isDarkMode) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Text(
              translate('chooseYourTrip'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : MyColors.blackColor,
              ),
            ),
            const SizedBox(height: 12),
            // Options véhicules
            widget.vehicleOptionsBuilder(context),
            const SizedBox(height: 8),
            // Champ de recherche
            widget.searchFieldBuilder(context),
            // Actions rapides
            widget.quickActionsBuilder(context),
            // Contenu additionnel (destinations populaires)
            widget.additionalContentBuilder(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Version Android avec Material Design (comportement existant)
  Widget _buildAndroidMaterial(BuildContext context) {
    final darkThemeProvider = Provider.of<DarkThemeProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;

    // Calcul des opacités (logique existante)
    double vehicleOptionsOpacity = 0.0;
    if (widget.currentHeight > widget.lowestHeight) {
      if (widget.currentHeight >= widget.minHeight) {
        vehicleOptionsOpacity = 1.0;
      } else {
        final range = widget.minHeight - widget.lowestHeight;
        final progress = (widget.currentHeight - widget.lowestHeight) / range;
        vehicleOptionsOpacity = progress.clamp(0.0, 1.0);
      }
    }

    double popularDestinationsOpacity = 0.0;
    if (widget.currentHeight > widget.minHeight) {
      if (widget.currentHeight >= widget.midHeight) {
        popularDestinationsOpacity = 1.0;
      } else {
        final range = widget.midHeight - widget.minHeight;
        final progress = (widget.currentHeight - widget.minHeight) / range;
        popularDestinationsOpacity = progress.clamp(0.0, 1.0);
      }
    }

    final bool isFullyExpanded = widget.currentHeight >= widget.maxHeight - 0.02;

    return Container(
      height: screenHeight * widget.currentHeight,
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme
            ? MyColors.blackColor
            : MyColors.whiteColor,
        borderRadius: widget.currentHeight >= widget.maxHeight
            ? BorderRadius.zero
            : const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
        boxShadow: widget.currentHeight < widget.maxHeight
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: double.infinity,
            height: 24,
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: darkThemeProvider.darkTheme
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Contenu
          Expanded(
            child: SingleChildScrollView(
              physics: isFullyExpanded
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre avec opacité
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 100),
                      opacity: vehicleOptionsOpacity,
                      child: vehicleOptionsOpacity > 0
                          ? Column(
                              children: [
                                Text(
                                  translate('chooseYourTrip'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: darkThemeProvider.darkTheme
                                        ? Colors.white
                                        : MyColors.blackColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Véhicules avec opacité
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: vehicleOptionsOpacity,
                      child: vehicleOptionsOpacity > 0
                          ? Column(
                              children: [
                                widget.vehicleOptionsBuilder(context),
                                const SizedBox(height: 8),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Recherche toujours visible
                    widget.searchFieldBuilder(context),
                    // Actions rapides avec opacité
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: popularDestinationsOpacity,
                      child: IgnorePointer(
                        ignoring: popularDestinationsOpacity == 0,
                        child: widget.quickActionsBuilder(context),
                      ),
                    ),
                    // Destinations populaires avec opacité
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: popularDestinationsOpacity,
                      child: IgnorePointer(
                        ignoring: popularDestinationsOpacity == 0,
                        child: widget.additionalContentBuilder(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
