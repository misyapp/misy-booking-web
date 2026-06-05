import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/generate_invoice_pdf_service.dart';
import 'package:rider_ride_hailing_app/services/invoice_download/invoice_download.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bouton « Facture » d'une course terminée (espace compte web).
///
/// 1. Si `rider_invoice` contient une URL Storage valide → ouverture dans un
///    nouvel onglet.
/// 2. Sinon (courses web historiques : la génération background échouait sur
///    web, champ resté `pending_…`) → génération **à la volée** via
///    [generateCustomerInvoice] (pur `Uint8List`, aucune I/O disque) +
///    téléchargement navigateur, puis persistance best-effort de l'URL pour
///    les prochains téléchargements.
class InvoiceButton extends StatefulWidget {
  final Map booking;
  const InvoiceButton({super.key, required this.booking});

  @override
  State<InvoiceButton> createState() => _InvoiceButtonState();
}

class _InvoiceButtonState extends State<InvoiceButton> {
  bool _busy = false;

  String? get _existingUrl {
    final url = widget.booking['rider_invoice'];
    if (url is String && url.startsWith('http')) return url;
    return null;
  }

  Future<void> _onPressed() async {
    final url = _existingUrl;
    if (url != null) {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      return;
    }
    await _generateAndDownload();
  }

  Future<void> _generateAndDownload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final driverId = widget.booking['acceptedBy'];
      if (driverId == null || userData.value == null) {
        showSnackbar('Facture indisponible pour cette course.');
        return;
      }
      final driverDoc =
          await FirestoreServices.users.doc(driverId.toString()).get();
      if (!driverDoc.exists) {
        showSnackbar('Facture indisponible (chauffeur introuvable).');
        return;
      }
      final driver = DriverModal.fromJson(driverDoc.data() as Map);
      final bookingDetails = Map<String, dynamic>.from(widget.booking);

      final bytes = await generateCustomerInvoice(
        bookingDetails: bookingDetails,
        customerDetails: userData.value!,
        driverData: driver,
      );

      final bookingId = widget.booking['id']?.toString() ?? 'course';
      await downloadPdfBytes(bytes, 'facture_misy_$bookingId.pdf');

      // Persistance best-effort : les prochains clics (et l'app mobile)
      // ouvriront directement l'URL au lieu de régénérer.
      try {
        final storedUrl = await FirestoreServices.uploadBytes(
            bytes, 'invoice', 'facture_misy_$bookingId.pdf');
        if (storedUrl.isNotEmpty) {
          await FirestoreServices.bookingHistory
              .doc(bookingId)
              .update({'rider_invoice': storedUrl});
          widget.booking['rider_invoice'] = storedUrl;
        }
      } catch (e) {
        myCustomPrintStatement('Invoice persistence skipped: $e');
      }
    } catch (e) {
      myCustomPrintStatement('Invoice generation error: $e');
      showSnackbar('Impossible de générer la facture. Réessayez plus tard.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _onPressed,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.receipt_long_outlined, size: 16),
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
