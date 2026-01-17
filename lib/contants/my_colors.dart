import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';

import '../provider/dark_theme_provider.dart';

DarkThemeProvider themeChangeProvider = DarkThemeProvider();

class MyColors {
  static const Color transparent = Colors.transparent;

  // Nouvelles couleurs Misy V2
  static const Color coralPink = Color(0xFFFF5357);
  static const Color horizonBlue = Color(0xFF286EF0);
  static const Color textPrimary = Color(0xFF3C4858);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundContrast = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color borderLight = Color(0xFFE5E7EB);

  static Color whiteColor = Colors.white;
  static Color whiteColordedede = const Color(0xffdedede);
  static Color redColor = Colors.red;
  static Color colorD9D9D9 = const Color(0xFFD9D9D9);
  static const Color blueLinerColor = Color(0xff3B6CE8);
  static const Color colorLightGrey727272 = Color(0xff727272);
  static const Color colorDarkGrey4b4b4b = Color(0xff4b4b4b);
  static const Color colorLightGreye8e8e8 = Color(0xffe8e8e8);
  static const Color platinumColor = Color(0xff3b3b3b);
  static const Color goldColor = Color(0xffefbf04);
  static const Color silverColor = Color(0xffc4c4c4);
  static const Color bronzeColor = Color(0xff82572c);
  /// Couleur de fond principale (blanc en mode jour, gris foncé en mode nuit)
  static const Color _darkModeBackground = Color(0xff1E1E1E); // Gris foncé doux

  static Color whiteThemeColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? _darkModeBackground
        : Colors.white;
  }

  static Color mapBgColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xff283d6a)
        : Colors.white.withOpacity(0.9);
  }

  static Color blackThemeColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? Colors.white
        : Colors.black;
  }

  static Color blackThemeColorOnlyBlackOpacity() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? Colors.black.withOpacity(0.8)
        : Colors.white;
  }

  static Color blackThemewithC3C3C3Color() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xffC3C3C3)
        : Colors.black;
  }

  static Color greyWhiteThemeColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? Colors.white
        : Colors.black.withOpacity(0.1);
  }

  static Color blackThemeColor06() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.6);
  }

  static Color blackThemeColorWithOpacity(double opacity) {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? Colors.white.withOpacity(opacity)
        : Colors.black.withOpacity(opacity);
  }

  static Color textFillThemeColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xFFEEEEEE).withOpacity(0.4)
        : const Color(0xFFEEEEEE);
  }

  static Color colorD9D9D9Theme() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xFFD9D9D9).withOpacity(0.5)
        : const Color(0xFFD9D9D9);
  }

  static Color colorStartColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? Colors.orange
        : const Color(0xffFD6D6A);
  }

  static Color colorPolylineBlueColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? Colors.blue
        : Colors.black;
  }

  static const Color textFeildFillColor = Color(0xffF4F4F5);
  static const Color scheduleButtonColor6E77C5 = Color(0xff6E77C5);

  /// Couleur de fond du drawer (gris foncé en mode nuit)
  static Color drawerBackgroundColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xff1C1C1E) // Gris très foncé (style iOS dark)
        : textFeildFillColor;
  }

  /// Couleur des cartes/sections du drawer et bottom sheets (gris foncé en mode nuit)
  static Color drawerCardColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xff2C2C2E) // Gris foncé (style iOS dark)
        : whiteColor;
  }

  /// Couleur de fond des bottom sheets en mode nuit
  static Color bottomSheetBackgroundColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xff252525) // Gris foncé légèrement plus clair que le fond
        : whiteColor;
  }

  /// Couleur de fond d'écran (gris très clair en jour, gris foncé en nuit)
  static Color backgroundThemeColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? _darkModeBackground // #1E1E1E
        : backgroundLight; // #F9FAFB
  }

  /// Couleur de fond des cartes (blanc en jour, gris foncé en nuit)
  static Color cardThemeColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xff2D2D2D) // Gris légèrement plus clair que le fond
        : Colors.white;
  }

  /// Couleur de texte secondaire adaptative
  static Color textSecondaryTheme() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xffA0A0A0) // Gris clair en mode nuit
        : textSecondary; // #6B7280
  }

  /// Couleur de bordure adaptative
  static Color borderThemeColor() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? const Color(0xff404040) // Bordure sombre
        : borderLight; // #E5E7EB
  }

  static const Color blackColor = Colors.black;
  static Color blackColor50 = Colors.black.withOpacity(0.5);
  static const Color oldPrimaryColor = Color(0xffFD6D6A); // Renommé pour éviter le conflit
  static const Color textFilledBorderColor = Color(0xffD7D7D7);
  static Color hintColor = const Color(0xff575757).withOpacity(0.6);
  static const Color greyColor = Colors.grey;
  static const Color blueColor = Colors.blue;
  static const Color greenColor = Colors.green;
  static const Color yellowColor = Colors.yellow;

  // Mise à jour des getters pour utiliser les nouvelles couleurs Misy V2
  static Color get primaryColor => coralPink;
  static Color get secondaryColor => horizonBlue;
}
