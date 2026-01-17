import 'dart:ui';
import 'package:flutter/material.dart';

/// Couleurs et constantes pour le style iOS Liquid Glass
/// Basé sur les guidelines Apple iOS 26
///
/// Refs: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
class LiquidGlassColors {
  // Couleurs de fond (semi-transparentes pour effet verre)
  static const Color sheetBackground = Color(0xFFFFFFFF); // Blanc pur
  static const Color sheetBackgroundDark = Color(0xFF1C1C1E); // Mode sombre iOS

  // Opacités Apple Liquid Glass (70% collapsed → 90% expanded)
  static const double collapsedOpacity = 0.70; // Semi-transparent pour voir le contenu
  static const double expandedOpacity = 0.92; // Plus opaque en full height

  // Blur (backdrop filter)
  static const double blurSigma = 10.0; // 10px blur comme Apple

  // Ombres (plus subtiles selon Apple: 5% opacity)
  static Color shadowColor = Colors.black.withValues(alpha: 0.08);
  static const double shadowBlurRadius = 16.0;
  static const Offset shadowOffset = Offset(0, -2);

  // Handle bar
  static Color handleBarColor = Colors.grey[300]!;
  static const double handleBarWidth = 40.0;
  static const double handleBarHeight = 4.0;

  // Dimensions
  static const double collapsedHeight = 80.0;
  static const double expandedHeightRatio = 0.90; // 90% de l'écran
  static const double intermediateHeightRatio = 0.60; // 60% de l'écran (affiche tout le contenu)

  // Border radius
  static const double topBorderRadius = 40.0;
  static const double bottomBorderRadiusFloating = 40.0;
  static const double bottomBorderRadiusExpanded = 0.0;

  // Marges (bulle flottante)
  static const double floatingMargin = 12.0;

  // Seuils pour snap
  static const double snapToCollapsedThreshold = 0.25;
  static const double snapToExpandedThreshold = 0.75;

  /// Retourne la couleur de fond adaptée au thème
  static Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode ? sheetBackgroundDark : sheetBackground;
  }

  /// Calcule l'opacité en fonction de l'extent (0.0 à 1.0)
  /// Apple: "When a half sheet expands to full height, it transitions to a more opaque appearance"
  static double getOpacity(double extent) {
    // Interpolation linéaire de 70% (collapsed) à 92% (expanded)
    return collapsedOpacity + (expandedOpacity - collapsedOpacity) * extent;
  }

  /// Calcule le blur sigma en fonction de l'extent
  /// Plus de blur en collapsed pour l'effet verre, moins en expanded
  static double getBlurSigma(double extent) {
    // Blur constant pour l'effet Liquid Glass
    return blurSigma;
  }

  /// Crée un ImageFilter pour le backdrop blur
  static ImageFilter getBlurFilter(double extent) {
    final sigma = getBlurSigma(extent);
    return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  }

  /// Calcule la marge latérale en fonction de l'extent
  static double getHorizontalMargin(double extent) {
    if (extent <= 0.5) {
      return floatingMargin;
    } else {
      final t = (extent - 0.5) / 0.5;
      return floatingMargin * (1 - t);
    }
  }

  /// Calcule la marge du bas en fonction de l'extent
  static double getBottomMargin(double extent) {
    if (extent <= 0.5) {
      return floatingMargin;
    } else {
      final t = (extent - 0.5) / 0.5;
      return floatingMargin * (1 - t);
    }
  }

  /// Calcule le border radius du bas en fonction de l'extent
  static double getBottomBorderRadius(double extent) {
    if (extent <= 0.5) {
      return bottomBorderRadiusFloating;
    } else {
      final t = (extent - 0.5) / 0.5;
      return bottomBorderRadiusFloating * (1 - t);
    }
  }

  /// Retourne le BorderRadius complet
  static BorderRadius getBorderRadius(double extent) {
    return BorderRadius.only(
      topLeft: const Radius.circular(topBorderRadius),
      topRight: const Radius.circular(topBorderRadius),
      bottomLeft: Radius.circular(getBottomBorderRadius(extent)),
      bottomRight: Radius.circular(getBottomBorderRadius(extent)),
    );
  }

  /// Calcule la hauteur de la sheet en fonction de l'extent et de la taille d'écran
  static double getSheetHeight(double extent, double screenHeight) {
    final expandedHeight = screenHeight * expandedHeightRatio;
    final intermediateHeight = screenHeight * intermediateHeightRatio;

    if (extent <= 0.5) {
      final t = extent / 0.5;
      return collapsedHeight + (intermediateHeight - collapsedHeight) * t;
    } else {
      final t = (extent - 0.5) / 0.5;
      return intermediateHeight + (expandedHeight - intermediateHeight) * t;
    }
  }

  /// Détermine l'état (0, 1, 2) en fonction de l'extent
  static int getState(double extent) {
    if (extent < snapToCollapsedThreshold) {
      return 0; // Collapsed
    } else if (extent < snapToExpandedThreshold) {
      return 1; // Intermediate
    } else {
      return 2; // Expanded
    }
  }

  /// Retourne l'extent cible pour le snap
  static double getSnapExtent(double extent) {
    if (extent < snapToCollapsedThreshold) {
      return 0.0;
    } else if (extent < snapToExpandedThreshold) {
      return 0.5;
    } else {
      return 1.0;
    }
  }
}
