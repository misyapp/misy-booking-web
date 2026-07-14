import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bouton « Facture » d'une course terminée (espace compte web).
///
/// « Serveur fait foi » — synchro avec la riderapp mobile (`_openInvoice`) : on
/// n'émet plus la facture côté client (fini la génération on-device à 20 %). Le
/// bouton ouvre la page serveur `misy-app.com/r/invoice-link/{bookingId}?uid=…`
/// qui génère la facture correcte (TVA réglée au dashboard = 0 %, passager invité,
/// flotte/mandat) et l'envoie par email confirmée par code au 1er envoi. Le serveur
/// calcule le token HMAC depuis uid+bookingId — aucun secret embarqué côté web.
class InvoiceButton extends StatefulWidget {
  final Map booking;
  const InvoiceButton({super.key, required this.booking});

  @override
  State<InvoiceButton> createState() => _InvoiceButtonState();
}

class _InvoiceButtonState extends State<InvoiceButton> {
  Future<void> _onPressed() async {
    final uid = userData.value?.id ?? '';
    final bid = widget.booking['id']?.toString() ?? '';
    if (bid.isEmpty) {
      showSnackbar('Facture indisponible pour cette course.');
      return;
    }
    final url = Uri.parse('https://misy-app.com/r/invoice-link/$bid?uid=$uid');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, webOnlyWindowName: '_blank');
    } else {
      showSnackbar('Impossible d\'ouvrir la facture. Réessayez plus tard.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _onPressed,
      icon: const Icon(Icons.receipt_long_outlined, size: 16),
      label: const Text('Facture'),
      style: OutlinedButton.styleFrom(
        foregroundColor: kWebCoralDark,
        side: BorderSide(color: kWebCoral.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
