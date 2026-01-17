import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
  
  Future<void> openWhatsApp(String phoneNumber) async {
    final url = "https://wa.me/$phoneNumber"; // WhatsApp API URL
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), );
    } else {
      showSnackbar("Impossible d'ouvrir WhatsApp");
      throw "Could not launch $url";
    }
  }