import 'package:rider_ride_hailing_app/utils/platform.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

class StoreReviewDialog {
  // Clés de préférences
  static const String _hasReviewedKey = 'has_reviewed_app';
  static const String _neverAskKey = 'never_ask_review';
  static const String _askLaterKey = 'ask_review_later';

  // URLs des stores
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.misyapp.rider';
  static const String _appStoreUrl =
      'https://apps.apple.com/app/misy-vtc-taxi-moto/id6504803498';

  /// Affiche le dialogue de demande d'avis après une course
  /// - Si jamais proposé : affiche
  /// - Si "Oui" cliqué précédemment : n'affiche plus
  /// - Si "Non" cliqué précédemment : n'affiche plus
  /// - Si "Plus tard" cliqué précédemment : affiche maintenant (à la course suivante)
  static Future<void> showAfterTrip(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final hasReviewed = prefs.getBool(_hasReviewedKey) ?? false;
    final neverAsk = prefs.getBool(_neverAskKey) ?? false;
    final askLater = prefs.getBool(_askLaterKey) ?? false;

    // Ne pas afficher si l'utilisateur a déjà donné un avis ou dit "Non"
    if (hasReviewed || neverAsk) return;

    // Vérifier si c'est la première fois ou si "Plus tard" a été cliqué
    final hasBeenAsked = prefs.containsKey(_hasReviewedKey) ||
                         prefs.containsKey(_neverAskKey) ||
                         prefs.containsKey(_askLaterKey);

    // Afficher si jamais proposé OU si "Plus tard" a été cliqué
    if (!hasBeenAsked || askLater) {
      // Réinitialiser le flag "Plus tard" car on affiche maintenant
      if (askLater) {
        await prefs.remove(_askLaterKey);
      }

      if (context.mounted) {
        await _showReviewDialog(context, prefs);
      }
    }
  }

  /// Alias pour compatibilité avec l'ancien code
  static Future<void> showIfFirstTrip(BuildContext context) async {
    await showAfterTrip(context);
  }

  static Future<void> _showReviewDialog(
      BuildContext context, SharedPreferences prefs) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (BuildContext dialogContext) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icone de star
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: MyColors.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    size: 40,
                    color: MyColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 20),

                // Titre
                SubHeadingText(
                  translate('storeReviewTitle'),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: MyColors.blackThemeColor(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                ParagraphText(
                  translate('storeReviewMessage'),
                  fontSize: 14,
                  color: MyColors.blackThemeColorWithOpacity(0.7),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Bouton "Oui" - Donner un avis
                RoundEdgedButton(
                  width: double.infinity,
                  onTap: () async {
                    await prefs.setBool(_hasReviewedKey, true);
                    Navigator.of(dialogContext).pop();
                    await _openStore();
                  },
                  text: translate('storeReviewYes'),
                ),
                const SizedBox(height: 12),

                // Bouton "Plus tard"
                RoundEdgedButton(
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  textColor: MyColors.blackThemeColor(),
                  onTap: () async {
                    await prefs.setBool(_askLaterKey, true);
                    Navigator.of(dialogContext).pop();
                  },
                  text: translate('storeReviewLater'),
                ),
                const SizedBox(height: 8),

                // Bouton "Non" - Ne plus demander
                TextButton(
                  onPressed: () async {
                    await prefs.setBool(_neverAskKey, true);
                    Navigator.of(dialogContext).pop();
                  },
                  child: ParagraphText(
                    translate('storeReviewNo'),
                    fontSize: 14,
                    color: MyColors.blackThemeColorWithOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _openStore() async {
    final String storeUrl = (!kIsWeb && Platform.isIOS) ? _appStoreUrl : _playStoreUrl;

    try {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        myCustomPrintStatement('Could not launch store URL: $storeUrl');
      }
    } catch (e) {
      myCustomPrintStatement('Error opening store: $e');
    }
  }
}
