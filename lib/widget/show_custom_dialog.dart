import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';

Future<T?> showCustomDialog<T>(
    {required Widget child,
    double? height,
    double horizontalInsetPadding = 32,
    double verticalInsetPadding = 20,
    double horizontalPadding = 24,
    double verticalPadding = 32,
    bool barrierDismissible = false
    }) async {
  return await showDialog<T>(
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.6), // Overlay moderne plus marqué
      context: MyGlobalKeys.navigatorKey.currentContext!,
      builder: (context) {
        return Dialog(
          elevation: 0, // Supprime l'ombre par défaut
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
              horizontal: horizontalInsetPadding,
              vertical: verticalInsetPadding),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: verticalPadding),
            height: height,
            constraints: BoxConstraints(
              minHeight: height ?? 200,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24), // Coins plus arrondis
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        );
      });
}
