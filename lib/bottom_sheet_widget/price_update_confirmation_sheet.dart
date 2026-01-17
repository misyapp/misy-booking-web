import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../contants/my_colors.dart';
import '../contants/language_strings.dart' show translate;
import '../provider/dark_theme_provider.dart';

/// Bottom sheet affichée quand l'utilisateur change le lieu de prise en charge
/// et que le prix de la course change.
/// Mesure anti-fraude pour éviter que l'utilisateur modifie le trajet après calcul.
class PriceUpdateConfirmationSheet extends StatelessWidget {
  final double newPrice;
  final double oldPrice;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const PriceUpdateConfirmationSheet({
    Key? key,
    required this.newPrice,
    required this.oldPrice,
    required this.onAccept,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final darkThemeProvider = Provider.of<DarkThemeProvider>(context);
    final isDark = darkThemeProvider.darkTheme;
    final priceIncreased = newPrice > oldPrice;
    final priceDifference = (newPrice - oldPrice).abs();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barre de tirage
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Illustration : bonhomme avec smartphone et pin
              _buildIllustration(isDark),

              const SizedBox(height: 24),

              // Titre
              Text(
                translate('confirmNewPriceTitle'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : MyColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Nouveau prix
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xff2C2C2E)
                      : MyColors.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: priceIncreased
                        ? MyColors.warning.withOpacity(0.5)
                        : MyColors.success.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${newPrice.toStringAsFixed(0)} Ar',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: priceIncreased
                            ? MyColors.warning
                            : MyColors.success,
                      ),
                    ),
                    if (priceDifference > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            priceIncreased
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                            color: priceIncreased
                                ? MyColors.warning
                                : MyColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${priceDifference.toStringAsFixed(0)} Ar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: priceIncreased
                                  ? MyColors.warning
                                  : MyColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Message explicatif
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  translate('priceUpdateExplanation'),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : MyColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Bouton accepter
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    translate('acceptTripPrice'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bouton annuler
              TextButton(
                onPressed: onCancel,
                child: Text(
                  translate('cancelAndKeepPosition'),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : MyColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Illustration avec un bonhomme tenant un smartphone et un pin de localisation
  Widget _buildIllustration(bool isDark) {
    return SizedBox(
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cercle de fond
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MyColors.primaryColor.withOpacity(0.1),
            ),
          ),
          // Bonhomme (emoji style avec peau marron)
          Positioned(
            left: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xff2C2C2E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '🧑🏾‍💻',
                  style: TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
          // Pin de localisation
          Positioned(
            right: 20,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xff2C2C2E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.location_on,
                color: MyColors.primaryColor,
                size: 28,
              ),
            ),
          ),
          // Flèche entre les deux
          Positioned(
            child: Icon(
              Icons.sync_alt,
              color: MyColors.secondaryColor,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  /// Affiche la bottom sheet de confirmation de prix
  static Future<bool> show(
    BuildContext context, {
    required double newPrice,
    required double oldPrice,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => PriceUpdateConfirmationSheet(
        newPrice: newPrice,
        oldPrice: oldPrice,
        onAccept: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }
}
