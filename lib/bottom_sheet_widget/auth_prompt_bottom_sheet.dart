import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/signup_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';

/// Bottom sheet pour inviter les utilisateurs invités à se connecter ou créer un compte
/// Affiché quand un utilisateur invité essaie de confirmer une course
class AuthPromptBottomSheet extends StatelessWidget {
  /// Callback appelé après une connexion/inscription réussie
  final VoidCallback? onAuthSuccess;

  const AuthPromptBottomSheet({
    Key? key,
    this.onAuthSuccess,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: MyColors.whiteThemeColor(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicateur de tiroir
          Container(
            height: 5,
            width: 50,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: MyColors.colorD9D9D9Theme(),
            ),
          ),

          // Icône
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MyColors.primaryColor.withOpacity(0.1),
            ),
            child: Icon(
              Icons.login_rounded,
              size: 48,
              color: MyColors.primaryColor,
            ),
          ),

          vSizedBox2,

          // Titre
          SubHeadingText(
            translate("Connectez-vous pour réserver"),
            fontWeight: FontWeight.w600,
            fontSize: 20,
            textAlign: TextAlign.center,
          ),

          vSizedBox,

          // Description avec bénéfices
          SubHeadingText(
            translate("Créez un compte gratuit pour :"),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: MyColors.blackThemeColor(),
          ),

          vSizedBox05,

          // Liste des bénéfices
          _buildBenefitItem(
            icon: Icons.check_circle_outline,
            text: translate("Réserver vos courses"),
          ),
          _buildBenefitItem(
            icon: Icons.history,
            text: translate("Accéder à l'historique de vos trajets"),
          ),
          _buildBenefitItem(
            icon: Icons.card_giftcard,
            text: translate("Profiter des promotions exclusives"),
          ),
          _buildBenefitItem(
            icon: Icons.account_balance_wallet,
            text: translate("Gérer vos moyens de paiement"),
          ),

          vSizedBox2,

          // Bouton "Créer un compte"
          RoundEdgedButton(
            text: translate("Créer un compte"),
            width: double.infinity,
            height: 50,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            onTap: () async {
              Navigator.pop(context);
              await push(context: context, screen: const SignUpScreen());
              // Vérifier si l'auth a réussi et appeler le callback
              final authProvider =
                  Provider.of<CustomAuthProvider>(context, listen: false);
              if (!authProvider.isGuestMode && onAuthSuccess != null) {
                onAuthSuccess!();
              }
            },
          ),

          vSizedBox,

          // Bouton "Se connecter"
          RoundEdgedButton(
            text: translate("Se connecter"),
            width: double.infinity,
            height: 50,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MyColors.whiteColor,
            textColor: MyColors.primaryColor,
            borderColor: MyColors.primaryColor,
            isBorder: true,
            onTap: () async {
              Navigator.pop(context);
              await push(context: context, screen: const LoginPage());
              // Vérifier si l'auth a réussi et appeler le callback
              final authProvider =
                  Provider.of<CustomAuthProvider>(context, listen: false);
              if (!authProvider.isGuestMode && onAuthSuccess != null) {
                onAuthSuccess!();
              }
            },
          ),

          vSizedBox05,

          // Bouton "Retour"
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: SubHeadingText(
              translate("Continuer sans compte"),
              fontSize: 14,
              color: MyColors.greyColor,
              fontWeight: FontWeight.w400,
            ),
          ),

          // Padding adaptatif pour la barre de navigation système Android
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: MyColors.primaryColor,
          ),
          hSizedBox05,
          Expanded(
            child: SubHeadingText(
              text,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: MyColors.blackThemeColor(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fonction helper pour afficher facilement le bottom sheet
Future<void> showAuthPromptBottomSheet(
  BuildContext context, {
  VoidCallback? onAuthSuccess,
}) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => AuthPromptBottomSheet(
      onAuthSuccess: onAuthSuccess,
    ),
  );
}
