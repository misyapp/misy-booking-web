// ignore_for_file: deprecated_member_use

import 'package:rider_ride_hailing_app/utils/platform.dart';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/edit_profile_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/help_screen.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/my_promocodes_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/my_wallet_management.dart';
import 'package:rider_ride_hailing_app/pages/view_module/privacy_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'package:rider_ride_hailing_app/pages/view_module/tutorial_page_webview.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/application_parameter.dart';
import 'package:rider_ride_hailing_app/services/user_log_store_service.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import '../contants/global_data.dart';
import '../contants/my_image_url.dart';
import '../contants/sized_box.dart';
import '../pages/view_module/pending_scheduled_booking_requested.dart';
import 'custom_circular_image.dart';
import 'custom_text.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool _showTopGradient = false;
  bool _showBottomGradient = true;

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<CustomAuthProvider>(context, listen: false);
    return Drawer(
      backgroundColor: MyColors.drawerBackgroundColor(),
      shape: CustomDrawerShape(),
      child: SafeArea(
        child: Column(
          children: [
            // Section 1: Profil utilisateur (fixe en haut)
            GestureDetector(
              onTap: () {
                push(
                  context: context,
                  screen: const EditProfileScreen(),
                );
              },
              child: Consumer<CustomAuthProvider>(
                builder: (context, authProvider, child) {
                  // En mode invité, afficher un profil par défaut
                  if (authProvider.isGuestMode) {
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: MyColors.drawerCardColor(),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      padding: const EdgeInsets.only(
                          top: 20, bottom: 20, left: 20, right: 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
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
                              hSizedBox,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SubHeadingText(
                                      translate("Utilisateur invité"),
                                      fontWeight: FontWeight.w500,
                                      color: MyColors.blackThemeColor(),
                                      fontSize: 16,
                                    ),
                                    vSizedBox05,
                                    ParagraphText(
                                      translate("Mode exploration"),
                                      fontSize: 12,
                                      color: MyColors.blackThemeColorWithOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  // Pour les utilisateurs connectés, afficher le profil normal
                  return ValueListenableBuilder(
                    valueListenable: userData,
                    builder: (context, value, child) {
                      if (value == null) return const SizedBox.shrink();

                      // Séparer prénom et nom pour affichage sur deux lignes si nécessaire
                      final nameParts = value.fullName.split(' ');
                      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
                      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: MyColors.drawerCardColor(),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        padding: const EdgeInsets.only(
                            top: 20, bottom: 20, left: 20, right: 20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CustomCircularImage(
                                  height: 70,
                                  width: 70,
                                  imageUrl: value.profileImage,
                                  borderRadius: 100,
                                  fileType: CustomFileType.network,
                                  fit: BoxFit.cover,
                                ),
                                hSizedBox,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        firstName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: MyColors.blackThemeColor(),
                                          fontSize: 16,
                                          fontFamily: 'Poppins-Regular',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (lastName.isNotEmpty)
                                        Text(
                                          lastName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: MyColors.blackThemeColor(),
                                            fontSize: 16,
                                            fontFamily: 'Poppins-Regular',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                RatingBar(
                                  initialRating: value.averageRating,
                                  itemSize: 12,
                                  direction: Axis.horizontal,
                                  allowHalfRating: false,
                                  itemCount: 5,
                                  ratingWidget: RatingWidget(
                                    full: Image.asset(
                                      MyImagesUrl.star,
                                      color: MyColors.primaryColor,
                                    ),
                                    half: Image.asset(
                                      MyImagesUrl.star,
                                      color: MyColors.primaryColor,
                                    ),
                                    empty: Image.asset(
                                      MyImagesUrl.star,
                                      color: MyColors.blackThemeColorWithOpacity(0.3),
                                    ),
                                  ),
                                  itemPadding:
                                      const EdgeInsets.symmetric(horizontal: 1.0),
                                  onRatingUpdate: (rating) {},
                                ),
                                ParagraphText(
                                  " (${value.totalReveiwCount} ${translate("Reviews")})",
                                  fontSize: 11,
                                  color: MyColors.blackThemeColorWithOpacity(0.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            vSizedBox,
            // Section 2: Liste des options (scrollable)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: MyColors.drawerCardColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo is ScrollUpdateNotification) {
                            setState(() {
                              _showTopGradient = scrollInfo.metrics.pixels > 10;
                              _showBottomGradient = scrollInfo.metrics.pixels <
                                  scrollInfo.metrics.maxScrollExtent - 10;
                            });
                          }
                          return true;
                        },
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Mon portefeuille - toujours accessible (contient aussi les moyens de paiement)
                              RowCard(
                                onTap: () {
                                  popPage(context: context);
                                  push(
                                      context: context,
                                      screen: const MyWalletManagement());
                                },
                                svgIcon: MyImagesUrl.drawerWalletSvg,
                                name: translate("myWallet"),
                              ),
                              // Promotions
                              RowCard(
                                onTap: () {
                                  popPage(context: context);
                                  push(context: context, screen: const MyPromoCodesScreen());
                                },
                                svgIcon: MyImagesUrl.drawerPromoSvg,
                                name: translate('My Promo code'),
                              ),
                              // Courses Réservées
                              if (globalSettings.enableScheduledBooking)
                                RowCard(
                                  onTap: () {
                                    popPage(context: context);
                                    push(
                                        context: context,
                                        screen: const PendingScheduledBookingRequested());
                                  },
                                  svgIcon: MyImagesUrl.drawerCalendarSvg,
                                  name: translate("Scheduled Booking"),
                                ),
                              // Guide
                              RowCard(
                                onTap: () async {
                                  popPage(context: context);
                                  push(
                                      context: context,
                                      screen: const TutorialPageWebview(
                                          webViewUrl:
                                              "https://www.misyapp.com/passengers/tuto"));
                                },
                                svgIcon: MyImagesUrl.drawerGuideSvg,
                                name: translate("Guide"),
                              ),
                              // Aide
                              RowCard(
                                onTap: () {
                                  popPage(context: context);
                                  push(context: context, screen: const HelpScreen());
                                },
                                svgIcon: MyImagesUrl.drawerHelpSvg,
                                name: translate("Help"),
                              ),
                              // Paramètres
                              RowCard(
                                onTap: () {
                                  popPage(context: context);
                                  push(
                                      context: context,
                                      screen: const ApplicationParameters());
                                },
                                svgIcon: MyImagesUrl.drawerSettingsSvg,
                                name: translate("settings"),
                              ),
                              // Politique de confidentialité
                              RowCard(
                                onTap: () {
                                  push(
                                      context: context,
                                      screen: const PrivacyPolicyScreen());
                                },
                                svgIcon: MyImagesUrl.drawerPrivacySvg,
                                name: translate('privacyPolicy'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Dégradés pour l'effet de scroll
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedOpacity(
                          opacity: _showTopGradient ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  MyColors.drawerCardColor(),
                                  MyColors.drawerCardColor().withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedOpacity(
                          opacity: _showBottomGradient ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  MyColors.drawerCardColor(),
                                  MyColors.drawerCardColor().withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            vSizedBox,
            // Section 3: Bouton de connexion pour invités (fixe en bas)
            // Note: Le bouton "Se déconnecter" est maintenant dans l'écran Mon profil
            Consumer<CustomAuthProvider>(
              builder: (context, authProvider, child) {
                // N'afficher que pour les invités
                if (!authProvider.isGuestMode) return const SizedBox.shrink();

                return Container(
                  decoration: BoxDecoration(
                    color: MyColors.drawerCardColor(),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  child: GestureDetector(
                    onTap: () {
                      // En mode invité, naviguer vers l'écran de connexion
                      Navigator.pop(context); // Fermer le drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: MyColors.primaryColor.withOpacity(0.1),
                          child: Icon(
                            Icons.login_rounded,
                            color: MyColors.primaryColor,
                            size: 23,
                          ),
                        ),
                        hSizedBox,
                        hSizedBox05,
                        SubHeadingText(
                          translate('Se connecter'),
                          fontWeight: FontWeight.w400,
                          color: MyColors.blackThemeColor(),
                          fontSize: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void showPopupMenu(BuildContext context) {
    showMenu(
      context: context,
      color: MyColors.whiteThemeColor(),
      shadowColor: MyColors.blackThemeColorWithOpacity(0.8),
      position: const RelativeRect.fromLTRB(50, 250, 50, 10),
      items: [
        const PopupMenuItem(
          value: 'French',
          child: SubHeadingText(
            'French',
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        const PopupMenuItem(
          value: 'Malagasy',
          child: SubHeadingText(
            'Malagasy',
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        const PopupMenuItem(
          value: 'English',
          child: SubHeadingText(
            'English',
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        myCustomPrintStatement('Selected: $value');
      }
    });
  }
}

class RowCard extends StatelessWidget {
  final String name;
  final String svgIcon;
  final Function()? onTap;

  const RowCard({
    super.key,
    required this.name,
    required this.svgIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SvgPicture.asset(
              svgIcon,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                MyColors.blackThemeColor(),
                BlendMode.srcIn,
              ),
            ),
            hSizedBox2,
            Expanded(
              child: ParagraphText(
                name,
                fontWeight: FontWeight.w400,
                color: MyColors.blackThemeColor(),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget de menu avec icône Material et badge de compteur
class RowCardWithBadge extends StatelessWidget {
  final String name;
  final IconData icon;
  final Function()? onTap;
  final int badgeCount;

  const RowCardWithBadge({
    super.key,
    required this.name,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            badges.Badge(
              showBadge: badgeCount > 0,
              badgeContent: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              badgeStyle: badges.BadgeStyle(
                badgeColor: MyColors.primaryColor,
                padding: const EdgeInsets.all(4),
              ),
              position: badges.BadgePosition.topEnd(top: -8, end: -8),
              child: Icon(
                icon,
                size: 24,
                color: MyColors.blackThemeColor(),
              ),
            ),
            hSizedBox2,
            Expanded(
              child: ParagraphText(
                name,
                fontWeight: FontWeight.w400,
                color: MyColors.blackThemeColor(),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomDrawerShape extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..moveTo(rect.left, rect.top) // Start from top left
      ..arcToPoint(
        Offset(rect.right, rect.top),
        // radius: Radius.circular(20),
        // clockwise: false,
      ) // Top right corner with radius
      ..lineTo(rect.right, rect.bottom) // Go to bottom right
      ..lineTo(rect.left, rect.bottom) // Go to bottom left
      ..close(); // Close the path to form a rectangle
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) {
    return this;
  }
}
