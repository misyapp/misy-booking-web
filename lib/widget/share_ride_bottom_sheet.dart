import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';

/// Bottom sheet pour sélectionner le mode de partage de la course
class ShareRideBottomSheet extends StatelessWidget {
  const ShareRideBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de poignée
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          vSizedBox2,
          // Titre
          const SubHeadingText(
            "Partager ma course",
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          vSizedBox,
          const ParagraphText(
            "Envoyez le lien de suivi à un proche",
            textAlign: TextAlign.center,
            color: Colors.grey,
          ),
          vSizedBox2,
          // Options de partage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareButton(
                icon: Icons.message_rounded,
                label: 'SMS',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Provider.of<TripProvider>(context, listen: false)
                      .shareLiveBySms();
                },
              ),
              _ShareButton(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () {
                  Navigator.pop(context);
                  Provider.of<TripProvider>(context, listen: false)
                      .shareByWhatsApp();
                },
              ),
              _ShareButton(
                icon: Icons.share_rounded,
                label: 'Autre',
                color: MyColors.primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  Provider.of<TripProvider>(context, listen: false)
                      .shareGeneric();
                },
              ),
            ],
          ),
          vSizedBox2,
          // Note de sécurité
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  color: MyColors.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Le lien permet de suivre votre position en temps réel jusqu'à la fin de la course",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          vSizedBox,
        ],
      ),
    );
  }
}

/// Bouton de partage individuel
class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fonction helper pour afficher le bottom sheet de partage
void showShareRideBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const ShareRideBottomSheet(),
  );
}
