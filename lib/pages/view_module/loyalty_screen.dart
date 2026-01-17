import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/models/loyalty_chest.dart';
import 'package:rider_ride_hailing_app/models/chest_reward.dart';
import 'package:rider_ride_hailing_app/pages/view_module/loyalty_history_screen.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/loyalty_chest_provider.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/services/loyalty_service.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/video_preload_service.dart';
import 'package:rider_ride_hailing_app/modal/user_modal.dart';
import 'package:rider_ride_hailing_app/widgets/chest_video_player.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  int _selectedTabIndex = 0; // 0: Comment gagner, 1: Utiliser mes points

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chestProvider = Provider.of<LoyaltyChestProvider>(context, listen: false);
      chestProvider.loadChestConfigurations();
      
      // Précharger les vidéos en arrière-plan
      VideoPreloadService.instance.preloadAllVideos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<DarkThemeProvider, LoyaltyChestProvider, AdminSettingsProvider>(
      builder: (context, darkThemeProvider, chestProvider, adminProvider, child) {
        final isLoyaltyEnabled = LoyaltyService.instance.isEnabled();
        
        return Scaffold(
          backgroundColor: darkThemeProvider.darkTheme 
              ? MyColors.blackColor 
              : MyColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: darkThemeProvider.darkTheme 
                ? MyColors.blackColor 
                : MyColors.backgroundLight,
            elevation: 0,
            title: Image.asset(
              'assets/icons/misy_logo_couleur.png',
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Si l'image ne charge pas, essayer le logo alternatif
                return Image.asset(
                  'assets/images/logo_+_white.png',
                  height: 32,
                  fit: BoxFit.contain,
                  color: darkThemeProvider.darkTheme 
                      ? MyColors.whiteColor 
                      : MyColors.primaryColor,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      translate("loyaltyProgram"),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    );
                  },
                );
              },
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: darkThemeProvider.darkTheme 
                    ? MyColors.whiteColor 
                    : MyColors.blackColor,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            // Debug button disabled for production
            // actions: [
            //   IconButton(
            //     icon: Icon(
            //       Icons.add_circle_outline,
            //       color: MyColors.primaryColor,
            //     ),
            //     onPressed: _addDebugPoints,
            //     tooltip: 'Ajouter 50 points (debug)',
            //   ),
            // ],
          ),
          body: !isLoyaltyEnabled 
            ? _buildDisabledState(darkThemeProvider)
            : RefreshIndicator(
                onRefresh: () async {
                  await chestProvider.refresh();
                  // Recharger aussi les points utilisateur
                  if (userData.value?.id != null) {
                    final updatedUser = await FirestoreServices.users.doc(userData.value!.id).get();
                    if (updatedUser.exists) {
                      userData.value = UserModal.fromJson(updatedUser.data() as Map<String, dynamic>);
                    }
                  }
                  setState(() {}); // Actualiser l'interface
                },
                color: MyColors.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildPointsHeader(darkThemeProvider),
                      const SizedBox(height: 24),
                      _buildTabSection(chestProvider, darkThemeProvider),
                      const SizedBox(height: 24),
                      _buildHistoryButton(darkThemeProvider),
                      const SizedBox(height: 24),
                      // _buildInfoSection(darkThemeProvider), // Masqué temporairement
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  Widget _buildDisabledState(DarkThemeProvider darkThemeProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: darkThemeProvider.darkTheme 
              ? MyColors.blackColor.withOpacity(0.5)
              : MyColors.whiteColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.card_giftcard_outlined,
              size: 64,
              color: MyColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              translate("loyaltyProgram"),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: darkThemeProvider.darkTheme 
                    ? MyColors.whiteColor 
                    : MyColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Le programme de fidélité n\'est pas encore disponible. Revenez bientôt !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: darkThemeProvider.darkTheme 
                    ? MyColors.whiteColor.withOpacity(0.7) 
                    : MyColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsHeader(DarkThemeProvider darkThemeProvider) {
    final userPoints = userData.value?.loyaltyPoints ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme 
            ? MyColors.blackColor.withOpacity(0.5)
            : MyColors.backgroundContrast,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo Misy+
          Image.asset(
            'assets/images/logo_+_white.png',
            height: 40,
            fit: BoxFit.contain,
            color: darkThemeProvider.darkTheme 
                ? MyColors.whiteColor 
                : MyColors.primaryColor,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 12),
          
          // Salutation
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bonjour,',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: darkThemeProvider.darkTheme 
                    ? MyColors.whiteColor 
                    : MyColors.textPrimary,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Points avec dégradé progressif sur la même ligne
          Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Vous avez ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: darkThemeProvider.darkTheme 
                          ? MyColors.whiteColor 
                          : MyColors.textPrimary,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF4A90E2), // Bleu - début du nombre
                          Color(0xFF7B7AE6), // Violet intermédiaire
                          Color(0xFFFF5357), // Rouge - fin du texte
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ).createShader(bounds),
                      child: Text(
                        '${NumberFormat('#,###', 'fr').format(userPoints.toInt())} points.',
                        style: const TextStyle(
                          fontSize: 20, // Même taille que "Vous avez" pour alignement
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          
          // Barre de progression horizontale
          Consumer<LoyaltyChestProvider>(
            builder: (context, chestProvider, child) {
              return _buildHorizontalProgressBar(userPoints, chestProvider, darkThemeProvider);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalProgressBar(double userPoints, LoyaltyChestProvider chestProvider, DarkThemeProvider darkThemeProvider) {
    if (chestProvider.chests.isEmpty) return const SizedBox.shrink();
    
    // Récupération dynamique des prix des coffres
    final chests = chestProvider.chests;
    final maxPrice = chests.last.price; // Le dernier coffre (supposé être le plus cher)
    
    return Column(
      children: [
        // Barre de progression avec textes et indicateurs liés
        SizedBox(
          height: 64, // Hauteur augmentée pour éviter la troncature des indicateurs
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              
              // Calcul linéaire simple de la progression
              final progressWidth = userPoints >= maxPrice 
                  ? width 
                  : (userPoints / maxPrice) * width;
              
              return Stack(
                children: [
                  // Ligne de base
                  Positioned(
                    top: 40, // Position abaissée pour centrer sur les indicateurs
                    left: 0,
                    right: 0,
                    child: Container(
                      width: (constraints.maxWidth-5).clamp(0.0, double.infinity),
                      height: 8,
                      decoration: BoxDecoration(
                        color: darkThemeProvider.darkTheme 
                            ? MyColors.textSecondary.withOpacity(0.3)
                            : MyColors.borderLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  
                  // Progression colorée avec dégradé bleu-rouge
                  Positioned(
                    top: 40,
                    left: 0,
                    child: Container(
                      width: (progressWidth-5).clamp(0.0, double.infinity),
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF4A90E2), // Bleu
                            Color(0xFF7B7AE6), // Violet intermédiaire
                            Color(0xFFFF5357), // Rouge #ff5357
                          ],
                          stops: [0.0, 0.6, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5357).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Widgets combinés texte + indicateur
                  ...chests.map((chest) {
                    final proportion = chest.price / maxPrice;
                    final isUnlocked = userPoints >= chest.price;
                    final centerPosition = proportion * width;
                    
                    return Positioned(
                      left: (centerPosition - 25).clamp(0.0, width - 44).toDouble(), // Centrer le widget combiné
                      child: _buildTextAndIndicator(chest, isUnlocked, darkThemeProvider),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildTextAndIndicator(LoyaltyChest chest, bool isUnlocked, DarkThemeProvider darkThemeProvider) {
    return SizedBox(
      width: 50,
      child: Column(
        children: [
          // Texte du prix avec dégradé si déverrouillé
          isUnlocked
              ? ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4A90E2), // Bleu
                      Color(0xFFFF5357), // Rouge #ff5357
                    ],
                  ).createShader(bounds),
                  child: Text(
                    chest.price.toInt().toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(
                  chest.price.toInt().toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: darkThemeProvider.darkTheme ? MyColors.textSecondary : MyColors.textSecondary,
                  ),
                ),
          
          const SizedBox(height: 4), // Petit espacement
          
          // Indicateur centré avec dégradé si déverrouillé
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isUnlocked 
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4A90E2), // Bleu
                          Color(0xFFFF5357), // Rouge #ff5357
                        ],
                      )
                    : null,
                color: isUnlocked 
                    ? null 
                    : (darkThemeProvider.darkTheme 
                        ? MyColors.textSecondary.withOpacity(0.3)
                        : MyColors.borderLight),
              ),
              child: Icon(
                isUnlocked ? Icons.star : Icons.lock,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection(LoyaltyChestProvider chestProvider, DarkThemeProvider darkThemeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Barre d'onglets
          Container(
            decoration: BoxDecoration(
              color: darkThemeProvider.darkTheme 
                  ? MyColors.blackColor.withOpacity(0.5)
                  : MyColors.backgroundContrast,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Premier onglet - Comment gagner
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: _selectedTabIndex == 0 
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4A90E2), // Bleu
                                  Color(0xFFFF5357), // Rouge #ff5357
                                ],
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                              decoration: BoxDecoration(
                                color: darkThemeProvider.darkTheme 
                                    ? MyColors.blackColor.withOpacity(0.5)
                                    : MyColors.backgroundContrast,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 20,
                                    color: darkThemeProvider.darkTheme ? MyColors.whiteColor : MyColors.textPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Comment gagner',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: darkThemeProvider.darkTheme ? MyColors.whiteColor : MyColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 20,
                                  color: darkThemeProvider.darkTheme ? MyColors.whiteColor : MyColors.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Comment gagner',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: darkThemeProvider.darkTheme ? MyColors.whiteColor : MyColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // Deuxième onglet - Utiliser mes points  
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: _selectedTabIndex == 1 
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4A90E2), // Bleu
                                  Color(0xFFFF5357), // Rouge #ff5357
                                ],
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                              decoration: BoxDecoration(
                                color: darkThemeProvider.darkTheme 
                                    ? MyColors.blackColor.withOpacity(0.5)
                                    : MyColors.backgroundContrast,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.card_giftcard,
                                    size: 20,
                                    color: darkThemeProvider.darkTheme ? MyColors.whiteColor : MyColors.textPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      translate("useMyPoints"),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: darkThemeProvider.darkTheme ? MyColors.whiteColor : MyColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.card_giftcard,
                                  size: 20,
                                  color: darkThemeProvider.darkTheme ? MyColors.whiteColor : MyColors.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    translate("useMyPoints"),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: darkThemeProvider.darkTheme ? MyColors.whiteColor : MyColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Contenu des onglets
          if (_selectedTabIndex == 0)
            _buildCompactHowToEarnContent(darkThemeProvider)
          else
            _buildChestsContent(chestProvider, darkThemeProvider),
        ],
      ),
    );
  }

  Widget _buildCompactHowToEarnContent(DarkThemeProvider darkThemeProvider) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚗 Cumulez des points à chaque course
          _buildHowToEarnSection(
            title: '🚗 Cumulez des points à chaque course',
            description: 'Avec Misy, chaque trajet vous rapporte des points automatiquement :',
            points: [
              '1 000 Ar dépensés = 10 points',
              'Plus vous utilisez Misy, plus vous cumulez de points !',
              'Aucun code à entrer : vos points sont crédités instantanément après chaque course.',
            ],
            darkThemeProvider: darkThemeProvider,
            useGradient: true,
          ),
          
          const SizedBox(height: 16),
          
          // Séparateur
          _buildSeparator(darkThemeProvider),
          
          const SizedBox(height: 16),
          
          // 📊 Suivez vos points en temps réel
          _buildHowToEarnSection(
            title: '📊 Suivez vos points en temps réel',
            points: [
              'Consultez votre solde dans votre profil.',
              'Une barre de progression dynamique vous indique votre niveau actuel et les récompenses disponibles.',
            ],
            darkThemeProvider: darkThemeProvider,
          ),
          
          const SizedBox(height: 16),
          
          // Séparateur
          _buildSeparator(darkThemeProvider),
          
          const SizedBox(height: 16),
          
          // 🔐 Ouvrez votre coffre Misy
          _buildHowToEarnSection(
            title: '🔐 Ouvrez votre coffre Misy',
            description: 'À chaque nouveau palier atteint, deux possibilités s\'offrent à vous :',
            points: [
              'Ouvrir votre coffre cadeau pour récupérer immédiatement vos récompenses.',
              'Continuer à cumuler pour déverrouiller des coffres Argent ou Or et obtenir des gains encore plus importants.',
            ],
            darkThemeProvider: darkThemeProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildHowToEarnSection({
    required String title,
    String? description,
    required List<String> points,
    required DarkThemeProvider darkThemeProvider,
    bool useGradient = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: useGradient ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A90E2), // Bleu
            Color(0xFFFF5357), // Rouge #ff5357
          ],
        ) : null,
        color: useGradient ? null : (darkThemeProvider.darkTheme 
            ? MyColors.blackColor.withOpacity(0.5)
            : MyColors.backgroundContrast),
        borderRadius: BorderRadius.circular(16),
        boxShadow: useGradient ? [
          BoxShadow(
            color: const Color(0xFFFF5357).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: useGradient 
                  ? Colors.white
                  : (darkThemeProvider.darkTheme 
                      ? MyColors.whiteColor 
                      : MyColors.textPrimary),
              shadows: useGradient ? const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ] : null,
            ),
          ),
          
          // Description optionnelle
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: useGradient 
                    ? Colors.white.withOpacity(0.9)
                    : (darkThemeProvider.darkTheme 
                        ? MyColors.whiteColor.withOpacity(0.8) 
                        : MyColors.textSecondary),
                shadows: useGradient ? const [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ] : null,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Points
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: useGradient 
                        ? Colors.white
                        : (darkThemeProvider.darkTheme 
                            ? MyColors.whiteColor 
                            : MyColors.textPrimary),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontSize: 14,
                      color: useGradient 
                          ? Colors.white.withOpacity(0.95)
                          : (darkThemeProvider.darkTheme 
                              ? MyColors.whiteColor.withOpacity(0.9) 
                              : MyColors.textPrimary),
                      height: 1.4,
                      shadows: useGradient ? const [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ] : null,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildSeparator(DarkThemeProvider darkThemeProvider) {
    return Center(
      child: Container(
        width: 60,
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              (darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor 
                  : MyColors.textPrimary).withOpacity(0.3),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildChestsContent(LoyaltyChestProvider chestProvider, DarkThemeProvider darkThemeProvider) {
    if (chestProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (chestProvider.hasError) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MyColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: MyColors.error, size: 32),
            const SizedBox(height: 8),
            Text(
              translate('loadingError'),
              style: TextStyle(
                color: MyColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              chestProvider.errorMessage ?? 'Une erreur est survenue',
              style: TextStyle(
                color: MyColors.error.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => chestProvider.refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text(translate('retry')),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...chestProvider.chests.map((chest) => 
          _buildNewChestCard(chest, darkThemeProvider, chestProvider)),
      ],
    );
  }


  Widget _buildChestsSection(LoyaltyChestProvider chestProvider, DarkThemeProvider darkThemeProvider) {
    if (chestProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (chestProvider.hasError) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MyColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: MyColors.error, size: 32),
            const SizedBox(height: 8),
            Text(
              translate('loadingError'),
              style: TextStyle(
                color: MyColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              chestProvider.errorMessage ?? 'Une erreur est survenue',
              style: TextStyle(
                color: MyColors.error.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => chestProvider.refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text(translate('retry')),
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate("useMyPoints"),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor 
                  : MyColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...chestProvider.chests.map((chest) => 
            _buildNewChestCard(chest, darkThemeProvider, chestProvider)),
        ],
      ),
    );
  }

  Widget _buildNewChestCard(LoyaltyChest chest, DarkThemeProvider darkThemeProvider, LoyaltyChestProvider chestProvider) {
    final userPoints = userData.value?.loyaltyPoints ?? 0.0;
    final canUnlock = chestProvider.canUnlockChest(chest.tier, userPoints);
    
    // Définir les couleurs du dégradé selon le tier
    List<Color> gradientColors;
    switch (chest.tier) {
      case 'tier1': // Bronze
        gradientColors = [
          const Color(0xFFb39a69), // Brun doré
          const Color(0xFFfeb8a2), // Rose saumon
        ];
        break;
      case 'tier2': // Argent
        gradientColors = [
          const Color(0xFFb0b2c8), // Bleu gris
          const Color(0xFFb8d9f2), // Bleu clair
        ];
        break;
      case 'tier3': // Or
        gradientColors = [
          const Color(0xFFeebf59), // Jaune doré
          const Color(0xFFf2e0b8), // Beige doré
        ];
        break;
      default:
        gradientColors = [Colors.grey, Colors.grey.shade300];
    }
    
    return Container(
      width: double.infinity,
      height: 130,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: canUnlock ? gradientColors : [Colors.grey.shade300, Colors.grey.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), // Ajusté pour éviter le débordement
        child: Row(
          children: [
            // Colonne gauche : Image + Prix
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image du coffre (plus grande)
                Image.asset(
                  chest.imagePath,
                  width: 90,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.card_giftcard,
                      color: Colors.white.withOpacity(0.8),
                      size: 60,
                    );
                  },
                ),
                
                const SizedBox(height: 2),
                
                // Prix en points sous l'image
                Text(
                  '${chest.price.toInt()} pts',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 12),
            
            // Contenu principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    chest.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  Text(
                    chest.rewardRangeText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                      shadows: const [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Zone fixe pour le bouton d'action
            SizedBox(
              width: 85, // Largeur fixe pour le bouton ajustée
              child: Align(
                alignment: Alignment.center,
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: canUnlock ? MyColors.coralPink : Colors.grey.shade600,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: canUnlock ? () => _showChestDialog(chest, chestProvider) : null,
                child: canUnlock 
                  ? Text(
                      translate("openChest"),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 18,
                    ),
              ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryButton(DarkThemeProvider darkThemeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _navigateToHistory(),
        style: ElevatedButton.styleFrom(
          backgroundColor: darkThemeProvider.darkTheme 
              ? MyColors.blackColor.withOpacity(0.5)
              : MyColors.whiteColor,
          foregroundColor: darkThemeProvider.darkTheme 
              ? MyColors.whiteColor 
              : MyColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor 
                  : MyColors.blackColor).withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              color: darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor 
                  : MyColors.blackColor,
            ),
            const SizedBox(width: 12),
            Text(
              translate('viewPointsHistory'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(DarkThemeProvider darkThemeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkThemeProvider.darkTheme 
            ? MyColors.blackColor.withOpacity(0.5)
            : MyColors.backgroundContrast,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MyColors.primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: MyColors.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                translate("howToEarnPoints"),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkThemeProvider.darkTheme 
                      ? MyColors.whiteColor 
                      : MyColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem(
            icon: Icons.directions_car,
            title: translate("completeRides"),
            description: translate("completeRidesDesc"),
            darkThemeProvider: darkThemeProvider,
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            icon: Icons.star,
            title: translate("leaveReviews"),
            description: translate("leaveReviewsDesc"),
            darkThemeProvider: darkThemeProvider,
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            icon: Icons.share,
            title: translate("referFriends"),
            description: translate("referFriendsDesc"),
            darkThemeProvider: darkThemeProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
    required DarkThemeProvider darkThemeProvider,
  }) {
    return Row(
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkThemeProvider.darkTheme 
                      ? MyColors.whiteColor 
                      : MyColors.textPrimary,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: darkThemeProvider.darkTheme 
                      ? MyColors.whiteColor.withOpacity(0.7) 
                      : MyColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showChestDialog(LoyaltyChest chest, LoyaltyChestProvider chestProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.card_giftcard,
                    color: MyColors.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    chest.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate("confirmOpenChest").replaceAll('%s', chest.price.toInt().toString()),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MyColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: MyColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            translate("pointsWillBeDeducted"),
                            style: TextStyle(
                              fontSize: 12,
                              color: MyColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    translate('cancel'),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _unlockChest(chest, chestProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    translate('openChest'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _unlockChest(LoyaltyChest chest, LoyaltyChestProvider chestProvider) async {
    if (userData.value?.id == null) {
      Navigator.of(context).pop();
      _showMessage('Utilisateur non connecté', isError: true);
      return;
    }

    Navigator.of(context).pop(); // Fermer le dialog

    // Vérifier si la vidéo est disponible
    final videoController = VideoPreloadService.instance.getController(chest.tier);
    
    if (videoController != null && VideoPreloadService.instance.isVideoReady(chest.tier)) {
      // Utiliser la vidéo préchargée
      _showVideoAndProcessChest(chest, chestProvider, videoController);
    } else {
      // Fallback : affichage classique avec CircularProgressIndicator
      _processChestWithFallback(chest, chestProvider);
    }
  }

  /// Affiche la vidéo et traite l'ouverture du coffre en parallèle
  Future<void> _showVideoAndProcessChest(LoyaltyChest chest, LoyaltyChestProvider chestProvider, videoController) async {
    // Variable pour stocker le résultat de l'API
    dynamic apiResult;
    Exception? apiError;
    
    // Lancer l'API en parallèle
    final apiCall = chestProvider.unlockChest(chest.tier, userData.value!.id).then((result) {
      apiResult = result;
    }).catchError((error) {
      apiError = error;
    });

    // Afficher la vidéo en plein écran
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChestVideoPlayer(
          controller: videoController,
          chestTier: chest.tier,
          onVideoEnd: () async {
            // Attendre que l'API soit terminée avant de fermer
            await apiCall;
            if (mounted) {
              Navigator.of(context).pop(); // Fermer la vidéo
            }
          },
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    // Traiter le résultat
    if (apiError != null) {
      _showMessage('Erreur: ${apiError.toString()}', isError: true);
    } else if (apiResult != null && apiResult.isSuccess && apiResult.reward != null) {
      // Afficher le dialog de récompense
      _showRewardDialog(apiResult.reward!, apiResult.chestName!);
      setState(() {}); // Rafraîchir l'interface
    } else {
      _showMessage(apiResult?.errorMessage ?? 'Erreur lors de l\'ouverture du coffre', isError: true);
    }

    // Remettre la vidéo à zéro pour la prochaine fois
    await VideoPreloadService.instance.resetVideo(chest.tier);
  }

  /// Traitement classique en cas de vidéo non disponible
  Future<void> _processChestWithFallback(LoyaltyChest chest, LoyaltyChestProvider chestProvider) async {
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Utiliser le provider pour ouvrir le coffre
      final result = await chestProvider.unlockChest(chest.tier, userData.value!.id);

      Navigator.of(context).pop(); // Fermer le loading

      if (result.isSuccess && result.reward != null) {
        // Afficher le dialog de récompense
        _showRewardDialog(result.reward!, result.chestName!);
        setState(() {}); // Rafraîchir l'interface
      } else {
        _showMessage(result.errorMessage ?? 'Erreur lors de l\'ouverture du coffre', isError: true);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Fermer le loading
      _showMessage('Erreur: ${e.toString()}', isError: true);
    }
  }

  void _showRewardDialog(ChestReward reward, String chestName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.celebration,
                color: MyColors.coralPink,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                translate('congratulations'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MyColors.coralPink.withOpacity(0.1),
                      MyColors.coralPink.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 48,
                      color: MyColors.coralPink,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      translate('youWon'),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${reward.amount.toInt()} Ar',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: MyColors.coralPink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${translate('from')} $chestName',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        translate('addedToWallet'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.coralPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                translate('fantastic'),
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

  // Debug method disabled for production
  // Future<void> _addDebugPoints() async {
  //   if (userData.value?.id == null) return;
  //   
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => const Center(
  //       child: CircularProgressIndicator(),
  //     ),
  //   );
  //
  //   try {
  //     await LoyaltyService.instance.addDebugPoints(userData.value!.id, 50);
  //     Navigator.of(context).pop();
  //     _showMessage('50 points ajoutés !');
  //     setState(() {});
  //   } catch (e) {
  //     Navigator.of(context).pop();
  //     _showMessage('Erreur: $e', isError: true);
  //   }
  // }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoyaltyHistoryScreen(),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? MyColors.error : MyColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  List<TextSpan> _buildPointsTextSpans(double userPoints, DarkThemeProvider darkThemeProvider) {
    final pointsText = translate("yourPoints");
    final formattedPoints = NumberFormat('#,###', 'fr').format(userPoints.toInt());
    
    // Séparer le texte en parties : avant %s et après %s
    final parts = pointsText.split('%s');
    final beforeText = parts.length > 0 ? parts[0] : '';
    final afterText = parts.length > 1 ? parts[1] : '';
    
    return [
      // Texte avant le nombre
      if (beforeText.isNotEmpty)
        TextSpan(
          text: beforeText,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: darkThemeProvider.darkTheme 
                ? MyColors.whiteColor 
                : MyColors.textPrimary,
          ),
        ),
      // Le nombre en rouge corail
      TextSpan(
        text: formattedPoints,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: MyColors.coralPink,
        ),
      ),
      // Texte après le nombre
      if (afterText.isNotEmpty)
        TextSpan(
          text: afterText,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: darkThemeProvider.darkTheme 
                ? MyColors.whiteColor 
                : MyColors.textPrimary,
          ),
        ),
    ];
  }
}
