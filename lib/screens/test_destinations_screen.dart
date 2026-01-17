import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/widget/admin_destinations_test_widget.dart';
import 'package:rider_ride_hailing_app/widget/popular_destinations_widget.dart';

/// Écran de test temporaire pour tester la migration des destinations
/// À supprimer après la mise en production
class TestDestinationsScreen extends StatelessWidget {
  const TestDestinationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final darkThemeProvider = Provider.of<DarkThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: darkThemeProvider.darkTheme 
          ? MyColors.blackColor 
          : MyColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Test Destinations Firestore'),
        backgroundColor: darkThemeProvider.darkTheme 
            ? MyColors.blackColor 
            : Colors.white,
        foregroundColor: darkThemeProvider.darkTheme 
            ? MyColors.whiteColor 
            : MyColors.textPrimary,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Widget d'administration
            const AdminDestinationsTestWidget(),
            
            // Séparateur
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 1,
              color: darkThemeProvider.darkTheme 
                  ? MyColors.whiteColor.withValues(alpha: 0.1)
                  : MyColors.textSecondary.withValues(alpha: 0.1),
            ),
            
            // Widget des destinations (résultat final)
            Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.preview,
                            color: MyColors.horizonBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Aperçu du Widget Final',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkThemeProvider.darkTheme 
                                  ? MyColors.whiteColor 
                                  : MyColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Le widget final qui sera utilisé dans l'app
                      const PopularDestinationsWidget(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}