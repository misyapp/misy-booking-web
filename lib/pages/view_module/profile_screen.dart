import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/pages/view_module/loyalty_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rider_ride_hailing_app/utils/platform.dart';

// NOTE: Cette classe ProfileScreen n'est pas utilisée dans le flow de navigation actuel de l'app.
// L'écran de profil principal est EditProfileScreen dans main_navigation_screen.dart.
// Ce fichier pourrait être supprimé ou archivé.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<DarkThemeProvider, CustomAuthProvider>(
      builder: (context, darkThemeProvider, authProvider, child) {
        return Scaffold(
          backgroundColor: darkThemeProvider.darkTheme
              ? MyColors.whiteThemeColor()
              : MyColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: darkThemeProvider.darkTheme
                ? MyColors.whiteThemeColor()
                : MyColors.whiteColor,
            elevation: 0,
            title: Text(
              translate('myAccount'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  darkThemeProvider.darkTheme
                      ? MyColors.whiteThemeColor()
                      : const Color(0xFFF8FAFB),
                  darkThemeProvider.darkTheme
                      ? MyColors.whiteThemeColor()
                      : Colors.white,
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header avec design moderne
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          MyColors.primaryColor,
                          MyColors.primaryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: MyColors.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Pattern décoratif
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 20,
                          top: 40,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        // Contenu principal
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Avatar avec badge
                              Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 3,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 45,
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      child: authProvider.currentUser?.photoURL != null
                                          ? ClipOval(
                                              child: Image.network(
                                                authProvider.currentUser!.photoURL!,
                                                width: 90,
                                                height: 90,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Icon(
                                              Icons.person,
                                              size: 55,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                  // Badge vérifié
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Name avec style moderne
                              Text(
                                authProvider.currentUser?.displayName ?? translate('user'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Email avec icône
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    authProvider.currentUser?.email ?? 'email@example.com',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Stats row
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(translate('ratingLabel'), '4.8', Icons.star),
                                    _buildStatDivider(),
                                    _buildStatItem(translate('ridesLabel'), '127', Icons.directions_car),
                                    _buildStatDivider(),
                                    _buildStatItem(translate('savedLabel'), '2.4k Ar', Icons.savings),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Menu Items en grille
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate('myAccount'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: darkThemeProvider.darkTheme
                              ? MyColors.whiteColor
                              : MyColors.blackColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Première rangée
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernMenuItem(
                              icon: Icons.edit_outlined,
                              title: translate('editProfile'),
                              color: const Color(0xFF4F46E5),
                              onTap: () => _showFeatureNotImplemented(context),
                              darkThemeProvider: darkThemeProvider,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernMenuItem(
                              icon: Icons.account_balance_wallet_outlined,
                              title: translate('myWallet'),
                              color: const Color(0xFF059669),
                              onTap: () => _showFeatureNotImplemented(context),
                              darkThemeProvider: darkThemeProvider,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Deuxième rangée
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernMenuItem(
                              icon: Icons.local_offer_outlined,
                              title: translate('promoCodesShort'),
                              color: const Color(0xFFDC2626),
                              onTap: () => _showFeatureNotImplemented(context),
                              darkThemeProvider: darkThemeProvider,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernMenuItem(
                              icon: Icons.card_giftcard_outlined,
                              title: 'bouton',
                              color: const Color(0xFF9333EA),
                              onTap: () => _navigateToLoyaltyScreen(context),
                              darkThemeProvider: darkThemeProvider,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Troisième rangée
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernMenuItem(
                              icon: Icons.schedule_outlined,
                              title: translate('scheduledBookingsShort'),
                              color: const Color(0xFFEA580C),
                              onTap: () => _showFeatureNotImplemented(context),
                              darkThemeProvider: darkThemeProvider,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(), // Placeholder pour équilibrer la grille
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Section Aide et Support
                      Text(
                        translate('helpSupport'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: darkThemeProvider.darkTheme
                              ? MyColors.whiteColor
                              : MyColors.blackColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tuiles d'aide
                      _buildSupportMenuItem(
                        icon: Icons.school_outlined,
                        title: translate('tutorial'),
                        subtitle: translate('learnToUseApp'),
                        onTap: () => _showFeatureNotImplemented(context),
                        darkThemeProvider: darkThemeProvider,
                      ),
                      const SizedBox(height: 12),
                      _buildSupportMenuItem(
                        icon: Icons.settings_outlined,
                        title: translate('settings'),
                        subtitle: translate('customizeExperience'),
                        onTap: () => _showFeatureNotImplemented(context),
                        darkThemeProvider: darkThemeProvider,
                      ),
                      const SizedBox(height: 12),
                      _buildSupportMenuItem(
                        icon: Icons.help_outline,
                        title: translate('helpCenter'),
                        subtitle: translate('faqSupport'),
                        onTap: () => _showFeatureNotImplemented(context),
                        darkThemeProvider: darkThemeProvider,
                      ),
                      const SizedBox(height: 12),
                      _buildSupportMenuItem(
                        icon: Icons.privacy_tip_outlined,
                        title: translate('privacy'),
                        subtitle: translate('policyAndData'),
                        onTap: () => _showFeatureNotImplemented(context),
                        darkThemeProvider: darkThemeProvider,
                      ),
                    ],
                  ),
                ),
                
                // Section Devenir Chauffeur
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        MyColors.coralPink,
                        MyColors.horizonBlue,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: MyColors.coralPink.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translate('becomeDriverMsg'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _downloadDriverApp(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: MyColors.coralPink,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: Text(
                                translate('earnMoney'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/driving_car_image.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Logout Button modernisé
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade400,
                          Colors.red.shade600,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        _showLogoutDialog(context, authProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            translate('confirmLogout'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
              ],
            ),
          ), // Ferme le SingleChildScrollView
        ), // Ferme le Container du body
      ); // Ferme le Scaffold
      },
    );
  }

  // Widget pour les stats de profil
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  // Widget pour les tuiles modernes du compte
  Widget _buildModernMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required DarkThemeProvider darkThemeProvider,
  }) {
    return InkWell(
      onTap: () {
        print('DEBUG: Tap détecté sur $title');
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: darkThemeProvider.darkTheme 
              ? MyColors.blackColor.withOpacity(0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: darkThemeProvider.darkTheme 
                    ? MyColors.whiteColor 
                    : MyColors.blackColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour les tuiles de support
  Widget _buildSupportMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required DarkThemeProvider darkThemeProvider,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: darkThemeProvider.darkTheme 
              ? MyColors.blackColor.withOpacity(0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MyColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: MyColors.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: darkThemeProvider.darkTheme 
                          ? MyColors.whiteColor 
                          : MyColors.blackColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: darkThemeProvider.darkTheme 
                          ? MyColors.whiteColor.withOpacity(0.7)
                          : MyColors.blackColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor.withOpacity(0.5)
                  : MyColors.blackColor.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  // Méthodes utilitaires
  void _showFeatureNotImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(translate('featureComingSoon')),
        backgroundColor: MyColors.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, CustomAuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.logout,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                translate('confirmLogout'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            translate('confirmLogoutMsg'),
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                translate('Cancel'),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // authProvider.signOut(); // À implémenter
                _showFeatureNotImplemented(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                translate('disconnectBtn'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Navigate vers la page de fidélité
  void _navigateToLoyaltyScreen(BuildContext context) {
    print('DEBUG: Bouton fidélité appuyé !');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoyaltyScreen(),
        ),
      );
      print('DEBUG: Navigation lancée avec succès');
    } catch (e) {
      print('DEBUG: Erreur navigation - $e');
      _showFeatureNotImplemented(context);
    }
  }

  /// Télécharge l'app Misy Driver depuis les app stores
  Future<void> _downloadDriverApp() async {
    String url;
    
    if (Platform.isIOS) {
      // URL de l'App Store pour iOS
      url = 'https://apps.apple.com/app/misy-driver/id123456789'; // Remplacer par la vraie URL
    } else {
      // URL du Google Play Store pour Android
      url = 'https://play.google.com/store/apps/details?id=com.misy.driver'; // Remplacer par le vrai package
    }
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showFeatureNotImplemented(context);
      }
    } catch (e) {
      _showFeatureNotImplemented(context);
    }
  }
}