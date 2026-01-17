import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/edit_profile_form_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/help_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/my_booking_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/my_wallet_management.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/loyalty_screen.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/bottom_sheet_widget/auth_prompt_bottom_sheet.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../contants/global_data.dart';
import '../../contants/language_strings.dart';
import '../../contants/my_colors.dart';
import '../../contants/my_image_url.dart';
import '../../contants/sized_box.dart';
import '../../functions/navigation_functions.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/custom_circular_image.dart';
import '../../widget/custom_text.dart';
import '../../widget/round_edged_button.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        isBackIcon: true,
        title: "Profil",
        onPressed: () {
          // 🔧 FIX: Vérifier d'abord si on peut pop (écran pushé depuis le drawer)
          // avant de tenter goToHome() pour éviter de bloquer l'UI
          if (Navigator.of(context).canPop()) {
            // On est sur une page pushée depuis le drawer - retour normal sans recharger
            Navigator.of(context).pop();
          } else {
            // Fallback: si on ne peut pas pop, utiliser goToHome()
            final mainNavState = MainNavigationScreenState.instance;
            if (mainNavState != null) {
              mainNavState.goToHome();
            } else {
              // Dernier recours: recréer MainNavigationScreen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                (route) => false,
              );
            }
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileBanner(context),
            vSizedBox,
            _buildGuestLoginPrompt(context),
            _buildActionTiles(context),
            Consumer2<AdminSettingsProvider, CustomAuthProvider>(
              builder: (context, adminSettings, authProvider, child) {
                // Masquer en mode invité ou si le système de fidélité est désactivé
                if (authProvider.isGuestMode || !adminSettings.defaultAppSettingModal.loyaltySystemEnabled) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    _buildLoyaltyCard(context),
                    vSizedBox,
                  ],
                );
              },
            ),
            _buildDriverAppLink(context),
            vSizedBox,
            _buildSettingsButton(context),
            vSizedBox,
            _buildLogoutButton(context),
            // Espacement pour éviter la barre de navigation Android
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestLoginPrompt(BuildContext context) {
    return Consumer<CustomAuthProvider>(
      builder: (context, authProvider, child) {
        // N'afficher que si l'utilisateur est en mode invité
        if (!authProvider.isGuestMode) return const SizedBox.shrink();

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MyColors.primaryColor.withOpacity(0.1),
                    MyColors.primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MyColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    // Navigation directe vers l'écran de connexion
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MyColors.primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.login_rounded,
                            color: MyColors.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SubHeadingText(
                                translate("Pour une meilleure expérience"),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: MyColors.blackThemeColor(),
                              ),
                              const SizedBox(height: 4),
                              ParagraphText(
                                translate("Connectez-vous pour accéder à toutes les fonctionnalités"),
                                fontSize: 13,
                                color: MyColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: MyColors.primaryColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileBanner(BuildContext context) {
    return Consumer<CustomAuthProvider>(
      builder: (context, authProvider, child) {
        // En mode invité, afficher un profil par défaut
        if (authProvider.isGuestMode) {
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubHeadingText(
                      translate("Utilisateur invité"),
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                    vSizedBox05,
                    ParagraphText(
                      translate("Mode exploration"),
                      fontSize: 14,
                      color: MyColors.textSecondary,
                    ),
                  ],
                ),
              ),
              hSizedBox2,
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: MyColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: MyColors.primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 40,
                  color: MyColors.primaryColor,
                ),
              ),
            ],
          );
        }

        // Pour les utilisateurs connectés, afficher le profil normal
        return ValueListenableBuilder(
          valueListenable: userData,
          builder: (context, user, child) {
            if (user == null) return const SizedBox.shrink();
            return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SubHeadingText(
                    user.fullName,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                  vSizedBox05,
                  Row(
                    children: [
                      RatingBar.builder(
                        initialRating: user.averageRating,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 18,
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        onRatingUpdate: (rating) {},
                        ignoreGestures: true,
                      ),
                      hSizedBox,
                      ParagraphText(
                        '(${user.averageRating.toStringAsFixed(1)})',
                        fontSize: 14,
                        color: MyColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            hSizedBox2,
            GestureDetector(
              onTap: () {
                push(context: context, screen: const EditProfileFormScreen());
              },
              child: CustomCircularImage(
                height: 70,
                width: 70,
                imageUrl: user.profileImage,
                borderRadius: 100,
                fileType: CustomFileType.network,
                fit: BoxFit.cover,
              ),
            ),
          ],
        );
          },
        );
      },
    );
  }

  Widget _buildActionTiles(BuildContext context) {
    return Consumer<CustomAuthProvider>(
      builder: (context, authProvider, child) {
        // Masquer les action tiles en mode invité
        if (authProvider.isGuestMode) return const SizedBox.shrink();

        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoTile(
                    context,
                    icon: Icons.help_outline,
                    label: translate('Help'),
                    onTap: () => push(context: context, screen: const HelpScreen()),
                  ),
                  _buildInfoTile(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: translate('Portefeuille'),
                    onTap: () => push(context: context, screen: const MyWalletManagement()),
                  ),
                  _buildInfoTile(
                    context,
                    icon: Icons.map_outlined,
                    label: translate('myBooking'),
                    onTap: () {
                      var tripProvider = Provider.of<TripProvider>(context, listen: false);
                      tripProvider.getMyBookingList();
                      tripProvider.getMyCurrentList();
                      push(context: context, screen: const MyBookingScreen());
                    },
                  ),
                ],
              ),
            ),
            vSizedBox,
          ],
        );
      },
    );
  }

  Widget _buildInfoTile(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: MyColors.textFeildFillColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: MyColors.primaryColor, size: 30),
              vSizedBox,
              ParagraphText(
                label,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: userData,
      builder: (context, user, child) {
        return GestureDetector(
          onTap: () => _navigateToLoyaltyScreen(context),
          child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF286EF0), // Bleu
            const Color(0xFFFF5357), // Rouge
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF286EF0).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Pattern décoratif
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Contenu principal
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icône avec effet de brillance
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/logo_+_white.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback sur l'ancien logo si le nouveau n'est pas trouvé
                      return Image.asset(
                        MyImagesUrl.loyaltyProgramIcon,
                        width: 32,
                        height: 32,
                        color: Colors.white,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Stack(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              // Effet de brillance
                              Positioned(
                                top: 2,
                                left: 2,
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 16,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${translate("loyaltyProgram")}\nMisy +',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gagnez des points à chaque trajet et débloquez des récompenses exclusives',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          fontFamily: 'Poppins',
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Badge des points
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.monetization_on,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${user?.loyaltyPoints?.toInt() ?? 0} points',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Flèche avec animation suggérée
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
      },
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return Consumer<CustomAuthProvider>(
      builder: (context, authProvider, child) {
        // Masquer en mode invité
        if (authProvider.isGuestMode) return const SizedBox.shrink();

        return RoundEdgedButton(
          text: translate('Modifier mes paramètres'),
          onTap: () {
            push(context: context, screen: const EditProfileFormScreen());
          },
          color: MyColors.textFeildFillColor,
          textColor: MyColors.blackThemeColor(),
          fontWeight: FontWeight.w600,
          height: 50,
          borderRadius: 12,
        );
      },
    );
  }

  Widget _buildDriverAppLink(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MyColors.primaryColor,
            MyColors.primaryColor.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MyColors.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            const driverAppUrl = 'misy-driver://';
            const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.misy.driver';
            const appStoreUrl = 'https://apps.apple.com/app/id<your_app_id>';

            try {
              if (await canLaunchUrl(Uri.parse(driverAppUrl))) {
                await launchUrl(Uri.parse(driverAppUrl));
              } else {
                if (Theme.of(context).platform == TargetPlatform.android) {
                  await launchUrl(Uri.parse(playStoreUrl));
                } else if (Theme.of(context).platform == TargetPlatform.iOS) {
                  await launchUrl(Uri.parse(appStoreUrl));
                }
              }
            } catch (e) {
              // Handle error
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'NOUVEAU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      vSizedBox,
                      const Text(
                        'Vous avez un taxi ou\nune voiture ?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      vSizedBox05,
                      Text(
                        'Devenez chauffeur Misy Driver\ndès aujourd\'hui.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      vSizedBox2,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Gagner de l\'argent',
                              style: TextStyle(
                                color: MyColors.primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              color: MyColors.primaryColor,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      Image.asset(
                        'assets/images/driving_car_image.png', // TODO: Remplacer par driverman.png quand disponible
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate vers la page de fidélité
  void _navigateToLoyaltyScreen(BuildContext context) {
    print('DEBUG: Bouton fidélité appuyé depuis edit_profile !');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoyaltyScreen(),
        ),
      );
      print('DEBUG: Navigation vers LoyaltyScreen lancée avec succès');
    } catch (e) {
      print('DEBUG: Erreur navigation - $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'ouverture du programme de fidélité'),
        ),
      );
    }
  }

  /// Bouton de déconnexion (masqué en mode invité)
  Widget _buildLogoutButton(BuildContext context) {
    return Consumer<CustomAuthProvider>(
      builder: (context, authProvider, child) {
        // Masquer en mode invité
        if (authProvider.isGuestMode) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                MyColors.coralPink,
                MyColors.coralPink.withOpacity(0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: MyColors.coralPink.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                authProvider.logout(context);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Se déconnecter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}