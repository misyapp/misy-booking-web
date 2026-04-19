import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// Helpers autour du package `showcaseview` : wrapper + persistance "déjà vu".
class TutorialHelper {
  TutorialHelper._();

  static const String _prefPrefix = 'editor_tuto_seen_';

  static Future<bool> hasSeen(String tourId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefPrefix$tourId') ?? false;
  }

  static Future<void> markSeen(String tourId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefPrefix$tourId', true);
  }

  /// Reset (pour le bouton "Revoir le tuto").
  static Future<void> reset(String tourId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefPrefix$tourId');
  }

  /// Lance un tour si non encore vu (après build complet).
  static void autoStartOnce({
    required BuildContext context,
    required String tourId,
    required List<GlobalKey> keys,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await hasSeen(tourId)) return;
      if (!context.mounted) return;
      ShowCaseWidget.of(context).startShowCase(keys);
      await markSeen(tourId);
    });
  }
}

/// Bulle tuto standardisée (style cohérent sur tous les écrans).
class TutoStep extends StatelessWidget {
  final GlobalKey stepKey;
  final String title;
  final String description;
  final Widget child;
  final ShapeBorder? targetShapeBorder;
  final EdgeInsets? targetPadding;

  const TutoStep({
    super.key,
    required this.stepKey,
    required this.title,
    required this.description,
    required this.child,
    this.targetShapeBorder,
    this.targetPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: stepKey,
      title: title,
      description: description,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      descTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      tooltipBackgroundColor: const Color(0xFF1565C0),
      overlayColor: Colors.black,
      overlayOpacity: 0.78,
      targetShapeBorder: targetShapeBorder ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
      targetPadding: targetPadding ?? const EdgeInsets.all(6),
      child: child,
    );
  }
}
