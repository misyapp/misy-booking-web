import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';

class LoyaltyScreenSimple extends StatefulWidget {
  const LoyaltyScreenSimple({super.key});

  @override
  State<LoyaltyScreenSimple> createState() => _LoyaltyScreenSimpleState();
}

class _LoyaltyScreenSimpleState extends State<LoyaltyScreenSimple> {
  @override
  Widget build(BuildContext context) {
    return Consumer<DarkThemeProvider>(
      builder: (context, darkThemeProvider, child) {
        return Scaffold(
          backgroundColor: darkThemeProvider.darkTheme 
              ? MyColors.blackColor 
              : MyColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: darkThemeProvider.darkTheme 
                ? MyColors.blackColor 
                : MyColors.whiteColor,
            elevation: 0,
            title: const Text(
              'Programme de fidélité',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
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
          ),
          body: Center(
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
                    Icons.stars,
                    size: 64,
                    color: MyColors.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Points de fidélité',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: darkThemeProvider.darkTheme 
                          ? MyColors.whiteColor 
                          : MyColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${userData.value?.loyaltyPoints?.toInt() ?? 0} points',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: MyColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Coffres bientôt disponibles !',
                    style: TextStyle(
                      fontSize: 16,
                      color: darkThemeProvider.darkTheme 
                          ? MyColors.whiteColor.withOpacity(0.7) 
                          : MyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}