import 'package:flutter/material.dart';

class Styles {
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    // Définition du TextTheme avec AzoSans
    // AzoSans-Medium (weight 500) pour les titres et éléments importants
    // AzoSans-Light (weight 300) pour les textes normaux
    final TextTheme textTheme = const TextTheme(
      // Titres principaux - AzoSans-Medium
      displayLarge: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      displayMedium: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      displaySmall: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      
      // Headlines - AzoSans-Medium
      headlineLarge: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      headlineMedium: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      headlineSmall: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      
      // Titres - AzoSans-Medium
      titleLarge: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500),
      
      // Corps de texte - AzoSans-Light
      bodyLarge: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w300),
      bodyMedium: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w300),
      bodySmall: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w300),
      
      // Labels - AzoSans-Light pour les petits, Medium pour le large
      labelLarge: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w500), // Boutons
      labelMedium: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w300),
      labelSmall: TextStyle(fontFamily: 'AzoSans', fontWeight: FontWeight.w300),
    );

    return ThemeData(

      primaryColor: isDarkTheme ? Colors.white : Colors.black,
      scaffoldBackgroundColor: isDarkTheme ? const Color(0xFF1E1E1E) : Colors.white,
      indicatorColor:
          isDarkTheme ? const Color(0xff0E1D36) : const Color(0xffCBDCF8),
      hintColor:
          isDarkTheme ? Colors.white : const Color(0xFF575757).withOpacity(0.6),
      highlightColor: Colors.transparent,
      // hoverColor: isDarkTheme ? const Color(0xff3A3A3B) : const Color(0xff4285F4),
      // focusColor: isDarkTheme ? const Color(0xff0B2512) : const Color(0xffA8DAB5),
      disabledColor: Colors.grey,
      fontFamily: "AzoSans",
      textTheme: textTheme,
      // cardColor: isDarkTheme ? const Color(0xFF151515) : Colors.white,
      // canvasColor: isDarkTheme ? Colors.black : Colors.grey[50],
      brightness: isDarkTheme ? Brightness.dark : Brightness.light,
      bottomSheetTheme: BottomSheetThemeData(
          surfaceTintColor: isDarkTheme ? const Color(0xFF252525) : Colors.white,
          backgroundColor: isDarkTheme ? const Color(0xFF252525) : Colors.white),
      buttonTheme: Theme.of(context).buttonTheme.copyWith(
          colorScheme: isDarkTheme
              ? const ColorScheme.dark()
              : const ColorScheme.light()),
              scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: MaterialStateProperty.all(true), // Always visible
          thumbColor: MaterialStateProperty.all(!isDarkTheme ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3),),
          minThumbLength: 30, // Minimum thumb height
        ),
    );
  }
}
