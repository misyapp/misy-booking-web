import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/modal/notification_modal.dart';
import 'package:rider_ride_hailing_app/pages/view_module/booking_detail_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/provider/navigation_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/analytics/analytics_service.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_rich_text.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/ride_tile.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/circular_back_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../extenstions/booking_type_extenstion.dart';

class PendingScheduledBookingRequested extends StatefulWidget {
  const PendingScheduledBookingRequested({super.key});

  @override
  State<PendingScheduledBookingRequested> createState() =>
      _PendingScheduledBookingRequestedState();
}

class _PendingScheduledBookingRequestedState
    extends State<PendingScheduledBookingRequested> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) {
        Provider.of<TripProvider>(context, listen: false)
            .scheduledBookingListener();
        // S'assurer que la barre de navigation est visible
        Provider.of<NavigationProvider>(context, listen: false)
            .setNavigationBarVisibility(true);
      },
    );
    super.initState();
  }

  @override
  void dispose() {
    Provider.of<TripProvider>(MyGlobalKeys.navigatorKey.currentContext!,
            listen: false)
        .disposeScheduledBookingListener();
    super.dispose();
  }

  void _goToSchedule() async {
    // Log Analytics event pour clic bouton course planifiée
    final userDetails = await DevFestPreferences().getUserDetails();
    final userId = userDetails?.id;

    await AnalyticsService.logScheduledRideButtonClicked(
      userId: userId,
    );

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // Retourner à l'écran principal (comme le fait "Mes trajets")
    _goBackToHome();

    // Attendre que la navigation soit terminée, puis déclencher le flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tripProvider.setScreen(CustomTripType.selectScheduleTime);
    });
  }

  // Méthode pour retourner à la page précédente ou à l'accueil
  void _goBackToHome() {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    // Rétablir la barre de navigation
    navigationProvider.setNavigationBarVisibility(true);
    
    // Vérifier si on peut faire un pop normal
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Sinon, retour au menu principal avec réinitialisation
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      tripProvider.setScreen(CustomTripType.setYourDestination);
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight / 4;

    return Scaffold(
      body: Stack(
        children: [
          // Image header qui s'étend jusqu'en haut
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              height: imageHeight,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(MyImagesUrl.reserveBanner),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Contenu principal avec défilement
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: imageHeight), // Espace pour l'image header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    translate('Scheduled Booking'),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer<TripProvider>(
                    builder: (context, bookingProvider, child) => bookingProvider
                        .scheduledBookingsList.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Premier élément avec icône calendrier
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  size: 28,
                                  color: Color(0xFFFF5357),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Choisissez l'heure précise de votre prise en charge, entre 1 heure et 30 jours à l'avance.",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Deuxième élément avec icône sablier
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.hourglass_empty,
                                  size: 28,
                                  color: Color(0xFFFF5357),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Votre chauffeur vous attendra à l'heure choisie. Au-delà, des frais d'annulation pourront être facturés.",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      itemCount: bookingProvider.scheduledBookingsList.length,
                      padding: const EdgeInsets.symmetric(
                          horizontal: globalHorizontalPadding, vertical: 20),
                      itemBuilder: (context, index) {
                        var booking =
                        bookingProvider.scheduledBookingsList[index];
                        return RideTile(booking: booking, isPast: false);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bouton retour personnalisé
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: CircularBackButton(
              onTap: _goBackToHome, // Utiliser la méthode unifiée
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(const Color(0xFFFF5357)),
                foregroundColor: WidgetStateProperty.all(Colors.white),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                elevation: WidgetStateProperty.all(2),
              ),
              onPressed: _goToSchedule,
              child: const Text(
                'Planifier une course',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  showCancelReasonBottomSheet(Map booking) {
    List<String> cancelReasonList = [
      translate("Driver asked me to cancel"),
      translate("Driver not getting closer"),
      translate("Waiting time was too long"),
      translate("Driver arrived early"),
      translate("Could not find driver"),
      translate("Other"),
    ];
    List<String> cancelReasonBeforeAcceptList = [
      translate("Requested wrong vehicle"),
      translate("Waiting time was too long"),
      translate("Requested by accident"),
      translate("Selected wrong dropoff"),
      translate("Selected wrong pickup"),
      translate("Other")
    ];
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    CircularBackButton(
                      onTap: () {
                        popPage(context: context);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SubHeadingText(
                        translate("Cancel Ride?"),
                        fontSize: 20,
                        textAlign: TextAlign.center,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  ],
                ),
                const Divider(),
                ParagraphText(
                  translate("Why do you want to cancel?"),
                  fontSize: 18,
                  textAlign: TextAlign.start,
                  fontWeight: FontWeight.w500,
                ),
                vSizedBox,
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: booking['status'] == 0
                      ? cancelReasonBeforeAcceptList.length
                      : cancelReasonList.length,
                  itemBuilder: (context, index) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () async {
                          var bookingProvider =
                              Provider.of<TripProvider>(context, listen: false);
                          bookingProvider.cancelRideWithBooking(
                              cancelAnotherRide: booking,
                              reason: booking['status'] == 0
                                  ? cancelReasonBeforeAcceptList[index]
                                  : cancelReasonList[index]);
                          popPage(
                              context:
                                  MyGlobalKeys.navigatorKey.currentContext!);
                        },
                        child: SubHeadingText(
                          booking['status'] == 0
                              ? cancelReasonBeforeAcceptList[index]
                              : cancelReasonList[index],
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
