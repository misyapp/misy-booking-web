// ignore_for_file: deprecated_member_use, invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/types/badge_types.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/open_whatapp.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/modal/notification_modal.dart';
import 'package:rider_ride_hailing_app/pages/view_module/main_navigation_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/rate_us_screen.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../contants/global_data.dart';
import '../../../contants/my_colors.dart';
import '../../../contants/my_image_url.dart';
import '../../../contants/sized_box.dart';
import '../../../widget/custom_appbar.dart';
import '../../../widget/custom_text.dart';
import '../../../widget/round_edged_button.dart';

class BookingDetails extends StatefulWidget {
  final Map booking;
  const BookingDetails({required this.booking, Key? key}) : super(key: key);

  @override
  State<BookingDetails> createState() => _BookingDetailsState();
}

class _BookingDetailsState extends State<BookingDetails> {
  late Map booking;
  Map? rating;
  DriverModal? driver;
  ValueNotifier<Map<String, Marker>> bookingDetailMarker = ValueNotifier({});
  ValueNotifier<GoogleMapController>? mapController;

  @override
  void initState() {
    booking = widget.booking;
    getdata();
    super.initState();
  }

  // Détermine si cette course peut être annulée
  bool get canBeCancelled {
    // Une course peut être annulée si :
    // 1. Elle est programmée (isSchedule == true) OU c'est une réservation courante
    // 2. Son statut est inférieur à RIDE_STARTED (course pas encore commencée)
    // 3. Elle n'est pas terminée ou annulée
    
    final status = booking['status'] ?? BookingStatusType.PENDING_REQUEST.value;
    
    return (booking['isSchedule'] == true || booking['acceptedBy'] != null) && 
           status < BookingStatusType.RIDE_STARTED.value &&
           status != BookingStatusType.RIDE_COMPLETE.value;
  }

  getdata() async {
    if (booking['status'] != BookingStatusType.RIDE_COMPLETE.value) {
      var b = await FirestoreServices.bookingRequest.doc(booking['id']).get();
      if (b.exists) {
        booking = b.data() as Map;
      }
    } else {
      var b = await FirestoreServices.bookingHistory.doc(booking['id']).get();
      if (b.exists) {
        booking = b.data() as Map;
      }
    }

    // 🔒 Debug limité - ne pas exposer les données sensibles (téléphone, etc.)
    if (kDebugMode) {
      myCustomPrintStatement('📋 Booking ${booking['id']} - status: ${booking['status']}, isSchedule: ${booking['isSchedule']}');
    }

    // Charger les détails du chauffeur seulement s'il y en a un
    if (booking['acceptedBy'] != null) {
      var d = await FirestoreServices.users.doc(booking['acceptedBy']).get();
      if (d.exists) {
        driver = DriverModal.fromJson(d.data() as Map);
        if (kDebugMode) {
          myCustomPrintStatement('👤 Driver loaded: ${driver?.firstName ?? "N/A"}');
        }
      }
    }
    
    setState(() {});
  }

  // Affiche le dialog de confirmation d'annulation
  void _showCancelBookingDialog(BuildContext context) {
    final bool hasAcceptedDriver = booking['acceptedBy'] != null;
    final String message = hasAcceptedDriver
        ? translate("driverAcceptedCancelWarning")
        : translate("cancelBookingQuestion");

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            translate("confirmCancellation"),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
              if (hasAcceptedDriver) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          translate("cancellationFeesMayApply"),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                translate("no"),
                style: TextStyle(color: MyColors.greyColor),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Si un chauffeur a accepté, demander la raison d'annulation
                if (hasAcceptedDriver) {
                  _showCancelReasonDialog();
                } else {
                  _cancelBooking(null);
                }
              },
              child: Text(
                translate("yesCancel"),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // Affiche le dialog pour saisir la raison d'annulation
  void _showCancelReasonDialog() {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            translate("cancellationReason"),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translate("provideCancellationReason"),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: translate("cancellationReasonPlaceholder"),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: MyColors.backgroundThemeColor(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                translate("back"),
                style: TextStyle(color: MyColors.greyColor),
              ),
            ),
            TextButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(translate("pleaseProvideReason")),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _cancelBooking(reason);
              },
              child: Text(
                translate("confirmCancellation"),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // Annule la réservation
  Future<void> _cancelBooking(String? cancelReason) async {
    try {
      // Afficher le loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final bool hasAcceptedDriver = booking['acceptedBy'] != null;

      if (hasAcceptedDriver) {
        // Si un chauffeur a accepté, mettre à jour avec le statut CANCELLED_BY_RIDER
        await FirestoreServices.bookingRequest.doc(booking['id']).update({
          'status': BookingStatusType.CANCELLED_BY_RIDER.value,
          'cancelledBy': 'customer',
          'cancelledByUserId': userData.value!.id,
          'cancelReason': cancelReason ?? 'No reason provided',
          'ride_status': 'Cancelled by Rider',
          'endTime': FieldValue.serverTimestamp(),
        });

        // Copier vers l'historique avec le statut d'annulation
        Map<String, dynamic> historyData = Map.from(booking);
        historyData['status'] = BookingStatusType.CANCELLED_BY_RIDER.value;
        historyData['cancelledBy'] = 'customer';
        historyData['cancelledByUserId'] = userData.value!.id;
        historyData['cancelReason'] = cancelReason ?? 'No reason provided';
        historyData['ride_status'] = 'Cancelled by Rider';
        historyData['endTime'] = FieldValue.serverTimestamp();

        await FirestoreServices.bookingHistory.doc(booking['id']).set(historyData);
        await FirestoreServices.bookingRequest.doc(booking['id']).delete();
      } else {
        // Si aucun chauffeur n'a accepté, supprimer directement
        await FirestoreServices.bookingRequest.doc(booking['id']).delete();
      }

      // Masquer le loading
      Navigator.of(context).pop();

      // 🔧 FIX: Nettoyer l'état du TripProvider pour éviter la restauration du booking annulé
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      // Si le booking annulé est le booking actuel, nettoyer complètement
      if (tripProvider.booking != null && tripProvider.booking!['id'] == booking['id']) {
        await tripProvider.clearAllTripData();
        tripProvider.setScreen(CustomTripType.setYourDestination);
      }

      // Nettoyer aussi le cache local au cas où
      DevFestPreferences prefs = DevFestPreferences();
      var cachedBooking = await prefs.getActiveBooking();
      if (cachedBooking != null && cachedBooking['id'] == booking['id']) {
        await prefs.clearActiveBooking();
      }

      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate("bookingCancelledSuccess")),
          backgroundColor: Colors.green,
        ),
      );

      // Retourner au menu principal
      _returnToMainMenu();

    } catch (e) {
      // Masquer le loading en cas d'erreur
      Navigator.of(context).pop();

      // Afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate("bookingCancellationError")),
          backgroundColor: Colors.red,
        ),
      );

      myCustomPrintStatement('Error cancelling booking: $e');
    }
  }

  // Retourne vers le menu principal ou la page précédente
  void _returnToMainMenu() {
    // Vérifier si on peut faire un pop normal (si on vient d'une autre page de l'app)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Sinon, aller au menu principal
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _returnToMainMenu();
        return false; // Empêche la navigation par défaut
      },
      child: Scaffold(
        appBar: CustomAppBar(
          isBackIcon: true,
          title: translate("BookingDetails"),
          titleFontSize: 18,
          titleFontWeight: FontWeight.w600,
          onPressed: _returnToMainMenu,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              if (booking['requestTime'] != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                      color: MyColors.whiteThemeColor(),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            blurRadius: 6,
                            color: MyColors.blackThemeColorWithOpacity(0.09)),
                      ]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (booking['isSchedule'] == false &&
                          booking['status'] !=
                              BookingStatusType.RIDE_COMPLETE.value)
                        Row(
                          children: [
                            // GlowingOverscrollIndicator(axisDirection: AxisDirection.right, color: Colors.green),
                            Text(
                              translate("Running"),
                              style: const TextStyle(color: Colors.blue),
                            ),
                            hSizedBox,
                            Expanded(
                                child: LoadingAnimationWidget.twistingDots(
                              leftDotColor: MyColors.coralPink,
                              rightDotColor: MyColors.horizonBlue,
                              size: 20.0,
                            )),
                          ],
                        ),
                      if (booking['isSchedule'] == true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.watch_later_outlined),
                              hSizedBox,
                              Text(
                                "${translate("Scheduledon")}: ",
                                style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic),
                              ),
                              Text(formatTimestamp(booking['scheduleTime']),
                                  style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12))
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ParagraphText(
                            "${translate("id")}:${booking['id']}",
                            fontSize: 11,
                            color: MyColors.blackThemeColor(),
                          ),
                          ParagraphText(
                            formatTimestamp(booking['requestTime']),
                            fontSize: 11,
                            color: MyColors.blackThemeColor(),
                          ),
                        ],
                      ),
                      vSizedBox,
                      vSizedBox05,
                      Row(
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor:
                                    MyColors.blackThemeColorWithOpacity(0.1),
                                child: Icon(
                                  Icons.circle,
                                  color: MyColors.primaryColor,
                                  size: 14,
                                ),
                              ),
                              Container(
                                margin:
                                    const EdgeInsets.only(top: 2.5, bottom: 1),
                                width: 3,
                                height: 34,
                                color: MyColors.blackThemeColorWithOpacity(0.4),
                              ),
                              Image.asset(
                                MyImagesUrl.location,
                                scale: 4,
                                color:
                                    Theme.of(context).scaffoldBackgroundColor ==
                                            Colors.white
                                        ? null
                                        : MyColors.primaryColor,
                              )
                            ],
                          ),
                          hSizedBox,
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ParagraphText(
                                  booking['pickAddress'],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: MyColors.blackThemeColor(),
                                ),
                                // Masquer le 2ème itinéraire (destination) uniquement pour les courses terminées
                                if (booking['status'] != BookingStatusType.RIDE_COMPLETE.value) ...[
                                  Divider(
                                    height: 38,
                                    color:
                                        MyColors.blackThemeColorWithOpacity(0.09),
                                  ),
                                  ParagraphText(
                                    booking['dropAddress'],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: MyColors.blackThemeColor(),
                                  ),
                                ],
                              ],
                            ),
                          )
                        ],
                      ),
                      vSizedBox2,
                      // Carte avec itinéraire pour les courses planifiées à venir uniquement
                      if (booking['isSchedule'] == true && 
                          booking['status'] != BookingStatusType.RIDE_COMPLETE.value &&
                          _hasValidCoordinates())
                        Container(
                          height: 250,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FutureBuilder<Set<Marker>>(
                              future: _createCustomMarkers(),
                              builder: (context, snapshot) {
                                return GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      (_getPickupLatitude() + _getDropLatitude()) / 2,
                                      (_getPickupLongitude() + _getDropLongitude()) / 2,
                                    ),
                                    zoom: 12,
                                  ),
                                  mapType: MapType.normal,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                  myLocationButtonEnabled: false,
                                  myLocationEnabled: false,
                                  compassEnabled: false,
                                  scrollGesturesEnabled: false,
                                  zoomGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  markers: snapshot.data ?? {},
                                  polylines: _createPolylines(),
                                  onMapCreated: (GoogleMapController controller) {
                                    // Ajuster la caméra pour afficher les deux marqueurs
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      controller.animateCamera(
                                        CameraUpdate.newLatLngBounds(
                                          LatLngBounds(
                                            southwest: LatLng(
                                              _getPickupLatitude() < _getDropLatitude() 
                                                ? _getPickupLatitude() 
                                                : _getDropLatitude(),
                                              _getPickupLongitude() < _getDropLongitude() 
                                                ? _getPickupLongitude() 
                                                : _getDropLongitude(),
                                            ),
                                            northeast: LatLng(
                                              _getPickupLatitude() > _getDropLatitude() 
                                                ? _getPickupLatitude() 
                                                : _getDropLatitude(),
                                              _getPickupLongitude() > _getDropLongitude() 
                                                ? _getPickupLongitude() 
                                                : _getDropLongitude(),
                                            ),
                                          ),
                                          50, // padding réduit pour un meilleur zoom sur l'itinéraire
                                        ),
                                      );
                                    });
                                  },
                                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{},
                                );
                              },
                            ),
                          ),
                        ),
                      if (driver != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ParagraphText(
                              " ${translate("YourDriver")}:",
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: MyColors.blackThemeColor(),
                            ),
                            if (booking['status'] !=
                                BookingStatusType.RIDE_COMPLETE.value)
                              Column(
                                children: [
                                  Text(
                                    translate('Approx'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  ParagraphText(
                                    "${formatAriary(double.parse(booking['ride_price_to_pay'].toString()))} ${globalSettings.currency}",
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: MyColors.blackThemeColor(),
                                  ),
                                ],
                              ),
                            if (booking['status'] ==
                                BookingStatusType.RIDE_COMPLETE.value)
                              ParagraphText(
                                "${formatAriary(double.parse(booking['ride_price_to_pay'].toString()))} ${globalSettings.currency}",
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MyColors.blackThemeColor(),
                              ),
                          ],
                        ),
                      vSizedBox,
                      if (driver != null)
                        Row(
                          children: [
                            Container(
                              alignment: Alignment.bottomCenter,
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: BadgeTypes.getColor(
                                        driver!.batchStatus),
                                    width: 3.8),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    driver!.profileImage,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            hSizedBox,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          ParagraphText(
                                            booking['isSchedule']
                                                ? driver!.firstName
                                                : driver!.fullName,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: MyColors.blackThemeColor(),
                                          ),
                                          if (driver!.batchStatus !=
                                              BadgeTypes.noBadge)hSizedBox05,
                                          if (driver!.batchStatus !=
                                              BadgeTypes.noBadge)
                                            Image.asset(
                                              MyImagesUrl.verifiedStatusIcon,
                                              height: 20,
                                              width: 20,
                                              color: BadgeTypes.getColor(
                                                driver!.batchStatus,
                                              ),
                                            )
                                        ],
                                      ),
                                      ParagraphText(
                                        driver!.vehicleData!.vehicleBrandName,
                                        fontSize: 13,
                                        color: MyColors.blackThemeColor(),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          RatingBar(
                                            initialRating:
                                                driver!.averageRating,
                                            itemSize: 12,
                                            direction: Axis.horizontal,
                                            allowHalfRating: true,
                                            itemCount: 5,
                                            ignoreGestures: true,
                                            ratingWidget: RatingWidget(
                                              full: Image.asset(
                                                MyImagesUrl.star,
                                                color:
                                                    MyColors.colorStartColor(),
                                              ),
                                              half: Image.asset(
                                                MyImagesUrl.star,
                                                color:
                                                    MyColors.colorStartColor(),
                                              ),
                                              empty: Image.asset(
                                                MyImagesUrl.star,
                                                color: MyColors.blackThemeColor()
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            itemPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 1.0),
                                            onRatingUpdate: (rating) {},
                                          ),
                                          ParagraphText(
                                            " (${driver!.totalReveiwCount} ${translate("Reviews")})",
                                            fontSize: 11,
                                            color: MyColors
                                                .blackThemeColorWithOpacity(
                                                    0.4),
                                          ),
                                        ],
                                      ),
                                      ParagraphText(
                                        booking['paymentMethod'],
                                        fontSize: 13,
                                        color: MyColors.blackThemeColor(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      vSizedBox,
                      // 🔒 Masquer les boutons de contact pour les courses terminées OU annulées
                      // (status >= RIDE_COMPLETE inclut RIDE_COMPLETE, CANCELLED, CANCELLED_BY_RIDER)
                      if (driver != null &&
                          booking['status'] < BookingStatusType.RIDE_COMPLETE.value &&
                          booking['isSchedule'] == true)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (driver != null &&
                                booking['status'] < BookingStatusType.RIDE_COMPLETE.value &&
                                booking['isSchedule'] == true &&
                                (booking['scheduleTime'] as Timestamp)
                                        .toDate()
                                        .difference(Timestamp.now().toDate())
                                        .inMinutes <
                                    5)
                            InkWell(
                              onTap: () async {
                               await openWhatsApp("${driver!.countryCode}${driver!.phone.startsWith("0") ? driver!.phone.substring(1) : driver!.phone}");
                              },
                              child: CircleAvatar(
                                radius: 23,
                                backgroundColor: MyColors.textFillThemeColor(),
                                child: Image.asset(
                                  MyImagesUrl.whatsAppIcon,
                                  width: 28,
                                  color: MyColors.blackThemeColor(),
                                ),
                              ),
                            ),
                            if (driver != null &&
                                booking['status'] < BookingStatusType.RIDE_COMPLETE.value &&
                                booking['isSchedule'] == true &&
                                (booking['scheduleTime'] as Timestamp)
                                        .toDate()
                                        .difference(Timestamp.now().toDate())
                                        .inMinutes <
                                    5)
                            hSizedBox,
                            if (driver != null &&
                                booking['status'] < BookingStatusType.RIDE_COMPLETE.value &&
                                booking['isSchedule'] == true &&
                                (booking['scheduleTime'] as Timestamp)
                                        .toDate()
                                        .difference(Timestamp.now().toDate())
                                        .inMinutes <
                                    5)
                              RoundEdgedButton(
                                  text: translate("Call"),
                                  height: 40,
                                  width: 90,
                                  onTap: () async {
                                    var url =
                                        "tel:${driver!.countryCode}${driver!.phone.startsWith("0") ? driver!.phone.substring(1) : driver!.phone}";
                                    if (await canLaunch(url)) {
                                      await launch(url);
                                    }
                                  }),
                          ],
                        ),
                      // if (index == 0)
                      if (booking['rating_by_customer'] == null &&
                          booking['status'] ==
                              BookingStatusType.RIDE_COMPLETE.value)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: RoundEdgedButton(
                              text: translate("Rate"),
                              height: 40,
                              width: 90,
                              verticalMargin: 5,
                              onTap: () async {
                                Map b = {
                                  "booking_id": booking['id'],
                                  "userId": driver!.id,
                                  "profile": driver!.profileImage,
                                  "name": driver!.fullName,
                                  "review_count": driver!.totalReveiwCount,
                                  "rating": driver!.averageRating,
                                  "deviceId": driver!.deviceIdList,
                                  "preferedLanguage": driver!.preferedLanguage
                                };
                                await push(
                                    context: context,
                                    screen: RateUsScreen(booking: b));
                                getdata();
                              }),
                        ),
                      // if (index == 1)
                      if (booking['rating_by_customer'] != null)
                        Container(
                          width: MediaQuery.of(context).size.width,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: MyColors.blackThemeColorWithOpacity(0.09),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RatingBar(
                                initialRating: booking['rating_by_customer']
                                    ['rating'],
                                ignoreGestures: false,
                                itemSize: 16,
                                direction: Axis.horizontal,
                                allowHalfRating: false,
                                itemCount: 5,
                                ratingWidget: RatingWidget(
                                  full: Image.asset(
                                    MyImagesUrl.star,
                                    color: MyColors.colorStartColor(),
                                  ),
                                  half: Image.asset(
                                    MyImagesUrl.star,
                                    color: MyColors.colorStartColor(),
                                  ),
                                  empty: Image.asset(
                                    MyImagesUrl.star,
                                    color: MyColors.blackThemeColor()
                                        .withOpacity(0.3),
                                  ),
                                ),
                                itemPadding:
                                    const EdgeInsets.symmetric(horizontal: 1.0),
                                onRatingUpdate: (rating) {},
                              ),
                              vSizedBox05,
                              ParagraphText(
                                booking['rating_by_customer']['review'],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: MyColors.blackThemeColor(),
                              ),
                            ],
                          ),
                        ),
                      if (booking['rating_by_customer'] != null) vSizedBox,
                      if (booking['rating_by_driver'] != null)
                        ParagraphText(
                          "${translate("RatingFromDriver")}:",
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: MyColors.blackThemeColor(),
                        ),
                      if (booking['rating_by_driver'] != null) vSizedBox05,
                      if (booking['rating_by_driver'] != null)
                        Container(
                          width: MediaQuery.of(context).size.width,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: MyColors.blackThemeColorWithOpacity(0.09),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RatingBar(
                                initialRating: booking['rating_by_driver']
                                    ['rating'],
                                ignoreGestures: false,
                                itemSize: 16,
                                direction: Axis.horizontal,
                                allowHalfRating: false,
                                itemCount: 5,
                                ratingWidget: RatingWidget(
                                  full: Image.asset(
                                    MyImagesUrl.star,
                                    color: MyColors.colorStartColor(),
                                  ),
                                  half: Image.asset(
                                    MyImagesUrl.star,
                                    color: MyColors.colorStartColor(),
                                  ),
                                  empty: Image.asset(
                                    MyImagesUrl.star,
                                    color: MyColors.blackThemeColor()
                                        .withOpacity(0.3),
                                  ),
                                ),
                                itemPadding:
                                    const EdgeInsets.symmetric(horizontal: 1.0),
                                onRatingUpdate: (rating) {},
                              ),
                              vSizedBox05,
                              ParagraphText(
                                booking['rating_by_driver']['review'],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: MyColors.blackThemeColor(),
                              ),
                            ],
                          ),
                        ),
                      if (booking['rating_by_driver'] != null) vSizedBox,
                      if (booking['status'] ==
                          BookingStatusType.RIDE_COMPLETE.value)
                        SizedBox(
                          height: 250,
                          width: double.infinity,
                          child: Consumer<GoogleMapProvider>(
                            builder: (context, mapProvider, child) =>
                                ValueListenableBuilder(
                              valueListenable: bookingDetailMarker,
                              builder:
                                  (context, bookingDetailMarkerValue, child) =>
                                      GoogleMap(
                                myLocationButtonEnabled: false,
                                myLocationEnabled: false,
                                compassEnabled: false,
                                zoomControlsEnabled: false,
                                zoomGesturesEnabled: false,
                                mapToolbarEnabled: false,
                                rotateGesturesEnabled: false,
                                scrollGesturesEnabled: false,
                                initialCameraPosition: CameraPosition(
                                    target: LatLng(currentPosition!.latitude,
                                        currentPosition!.longitude),
                                    zoom: 12.80),
                                gestureRecognizers: Set()
                                  ..add(Factory<PanGestureRecognizer>(
                                      () => PanGestureRecognizer()))
                                  ..add(Factory<ScaleGestureRecognizer>(
                                      () => ScaleGestureRecognizer())),
                                markers:
                                    bookingDetailMarkerValue.values.toSet(),
                                onMapCreated: (controller) async {
                                  mapController = ValueNotifier(controller);
                                  mapController!.notifyListeners();
                                  bookingDetailMarker.value['dropingPoint'] =
                                      Marker(
                                          markerId:
                                              const MarkerId("dropingPoint"),
                                          icon: await mapProvider
                                              .createMarkerImageFromAssets(
                                            MyImagesUrl
                                                .dropLocationCircleIconTheme(),
                                          ),
                                          position: LatLng(
                                            booking['suggestPath'][
                                                booking['suggestPath'].length -
                                                    1]['latitude'],
                                            booking['suggestPath'][
                                                booking['suggestPath'].length -
                                                    1]['longitude'],
                                          ));
                                  bookingDetailMarker.value['pickupPoint'] =
                                      Marker(
                                          markerId:
                                              const MarkerId("pickupPoint"),
                                          icon: await mapProvider
                                              .createMarkerImageFromAssets(
                                            MyImagesUrl.pickupCircleIconTheme(),
                                          ),
                                          position: LatLng(
                                            booking['suggestPath'][0]
                                                ['latitude'],
                                            booking['suggestPath'][0]
                                                ['longitude'],
                                          ));
                                  var a = await mapProvider.getLatLongBounds(
                                      List.generate(
                                    booking['suggestPath'].length,
                                    (index) => [
                                      booking['suggestPath'][index]['latitude'],
                                      booking['suggestPath'][index]['longitude']
                                    ],
                                  )
                                      // [
                                      //   [
                                      //     booking['suggestPath'][0]['latitude'],
                                      //     booking['suggestPath'][0]['longitude']
                                      //   ],
                                      //   [
                                      //     booking['suggestPath'][
                                      //         booking['suggestPath'].length -
                                      //             1]['latitude'],
                                      //     booking['suggestPath'][
                                      //         booking['suggestPath'].length -
                                      //             1]['longitude']
                                      //   ],
                                      // ],
                                      );
                                  myCustomPrintStatement(
                                      "lat lang bound is that $a");
                                  {
                                    const int steps = 6;
                                    const Duration total = Duration(milliseconds: 1500);
                                    final int stepMs = (total.inMilliseconds / steps).round();
                                    const double finalPadding = 50.0;
                                    const double startPadding = 250.0; // commence très zoomé puis dézoom vers 50
                                    for (int i = 1; i <= steps; i++) {
                                      final double t = i / steps;
                                      final double pad = startPadding + (finalPadding - startPadding) * t;
                                      await mapController!.value.animateCamera(
                                        CameraUpdate.newLatLngBounds(a, pad),
                                      );
                                      await Future.delayed(Duration(milliseconds: stepMs));
                                    }
                                  }
                                  mapController!.notifyListeners();
                                },
                                polylines: {
                                  Polyline(
                                      polylineId: const PolylineId('path'),
                                      color: MyColors.blackColor,
                                      width: 5,
                                      geodesic: true,
                                      visible: true,
                                      points: List.generate(
                                          booking['suggestPath'].length,
                                          (index) => LatLng(
                                              booking['suggestPath'][index]
                                                  ['latitude'],
                                              booking['suggestPath'][index]
                                                  ['longitude']))),
                                  Polyline(
                                      polylineId: const PolylineId('path1'),
                                      color: MyColors.primaryColor,
                                      width: 5,
                                      geodesic: true,
                                      visible: true,
                                      points: List.generate(
                                          booking['coveredPath'].length,
                                          (index) => LatLng(
                                              booking['coveredPath'][index]
                                                  ['lat'],
                                              booking['coveredPath'][index]
                                                  ['lng']))),
                                },
                                // cameraTargetBounds: CameraTargetBounds(
                                //   mapProvider.getLatLongBounds([
                                //     [
                                //       booking['suggestPath'][0]['latitude'],
                                //       booking['suggestPath'][0]['longitude']
                                //     ],
                                //     [
                                //       booking['suggestPath'][
                                //               booking['suggestPath'].length - 1]
                                //           ['latitude'],
                                //       booking['suggestPath'][
                                //               booking['suggestPath'].length - 1]
                                //           ['longitude']
                                //     ],
                                //   ]),
                                // ),
                              ),
                            ),
                          ),
                        ),

                      if (booking['status'] ==
                          BookingStatusType.RIDE_COMPLETE.value)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            vSizedBox4,
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ParagraphText(
                                    "${translate("RideAmount")}(${booking['total_distance']}km):",
                                    fontSize: 15,
                                    // fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: ParagraphText(
                                    "${formatAriary((double.parse(booking['ride_price_to_pay'].toString()) + double.parse(booking['ride_bonus_price'].toString()) - double.parse(booking['vehicle_base_price'].toString()) - (booking['isSchedule'] == true ? booking['rideScheduledServiceFee'] : 0)).abs())} ${globalSettings.currency}",
                                    textAlign: TextAlign.right,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ParagraphText(
                                    "${translate("BasePrice")}:",
                                    fontSize: 15,
                                    // fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: ParagraphText(
                                    '${formatAriary(double.parse(booking['vehicle_base_price'].toString()))} ${globalSettings.currency}',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            if (booking['isSchedule'] == true)
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: ParagraphText(
                                      "${translate("Schedule fee")}:",
                                      fontSize: 15,
                                    ),
                                  ),
                                  Expanded(
                                    child: ParagraphText(
                                      '${formatAriary(booking['rideScheduledServiceFee'])} ${globalSettings.currency}',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ParagraphText(
                                    "${translate("Discount")}:",
                                    fontSize: 15,
                                    // fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: ParagraphText(
                                    '-${formatAriary(double.parse(booking['ride_bonus_price'].toString()))} ${globalSettings.currency}',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ParagraphText(
                                    "${translate("TotalAmount")}:",
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: ParagraphText(
                                    '${formatAriary(double.parse(booking['ride_price_to_pay'].toString()))}  ${globalSettings.currency}',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                          ],
                        )
                    ],
                  ),
                ),

                // NOUVELLE SECTION : Bouton d'annulation (uniquement pour les courses réservées)
                if (canBeCancelled)
                  Container(
                    margin: const EdgeInsets.fromLTRB(0, 15, 0, 40), // Marge supplémentaire en bas
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: RoundEdgedButton(
                      text: translate("cancelBooking"),
                      color: Colors.red,
                      textColor: Colors.white,
                      borderRadius: 10,
                      onTap: () => _showCancelBookingDialog(context),
                      width: double.infinity,
                    ),
                  ),

              // IconButton(
              //     onPressed: () async {
              //       // Uint8List uint8list = await generateCustomerInvoice(
              //       //     bookingDetails: booking, customerDetails: customer!);
              //       // final dir = await getApplicationDocumentsDirectory();
              //       // // var file = File(
              //       // //     "${dir.path.split("app_flutter").first}1${(booking['endTime'] as Timestamp).toDate().microsecondsSinceEpoch}.pdf");
              //       // var file = File(
              //       //     "${dir.path.split("app_flutter").first}${userData.value!.id.substring(0, 4)}2${(booking['endTime'] as Timestamp).toDate().microsecondsSinceEpoch}.pdf");

              //       // file.writeAsBytesSync(uint8list);
              //       // FirestoreServices.uploadFile(
              //       //   file,
              //       //   'invoice',
              //       //   showloader: false,
              //       // );
              //       Uint8List uint8listDriver = await generateDriverInvoice(
              //           bookingDetails: booking,
              //           // customerDetails: userData.value!,
              //           driverData: driver!);
              //       final dirDriver = await getApplicationDocumentsDirectory();
              //       var fileDriver = File(
              //           "${dirDriver.path.split("app_flutter").first}${userData.value!.id.substring(0, 4)}1${(booking['endTime'] as Timestamp).toDate().microsecondsSinceEpoch}.pdf");

              //       fileDriver.writeAsBytesSync(uint8listDriver);

              //       // FirestoreServices.uploadFile(
              //       //   fileDriver,
              //       //   'invoice',
              //       //   showloader: false,
              //       // );
              //       push(
              //           context: context,
              //           screen: CustomPdfViewWidget(file: fileDriver));
              //     },
              //     icon: Icon(Icons.picture_as_pdf)),
            ],
          ),
        ),
      ),
    );
  }

  // Vérifie si les coordonnées sont valides
  bool _hasValidCoordinates() {
    return (_getPickupLatitude() != 0 && 
            _getPickupLongitude() != 0 &&
            _getDropLatitude() != 0 && 
            _getDropLongitude() != 0);
  }

  // Obtient la latitude de pickup en essayant différents noms de champs
  double _getPickupLatitude() {
    return (booking['pickupLatitude']?.toDouble() ?? 
            booking['pickup_latitude']?.toDouble() ??
            booking['pickLat']?.toDouble() ??
            0.0);
  }

  // Obtient la longitude de pickup en essayant différents noms de champs
  double _getPickupLongitude() {
    return (booking['pickupLongitude']?.toDouble() ?? 
            booking['pickup_longitude']?.toDouble() ??
            booking['pickLng']?.toDouble() ??
            0.0);
  }

  // Obtient la latitude de drop en essayant différents noms de champs
  double _getDropLatitude() {
    return (booking['dropLatitude']?.toDouble() ?? 
            booking['drop_latitude']?.toDouble() ??
            booking['dropLat']?.toDouble() ??
            0.0);
  }

  // Obtient la longitude de drop en essayant différents noms de champs
  double _getDropLongitude() {
    return (booking['dropLongitude']?.toDouble() ?? 
            booking['drop_longitude']?.toDouble() ??
            booking['dropLng']?.toDouble() ??
            0.0);
  }

  // Crée les marqueurs personnalisés (carré pour pickup, rond pour drop)
  Future<Set<Marker>> _createCustomMarkers() async {
    if (!_hasValidCoordinates()) {
      return {};
    }

    // Créer les icônes personnalisées
    final pickupIcon = await _createSquareIcon();
    final dropIcon = await _createCircleIcon();

    return {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
          _getPickupLatitude(),
          _getPickupLongitude(),
        ),
        icon: pickupIcon,
        infoWindow: InfoWindow(
          title: translate('PickupLocation'),
          snippet: booking['pickAddress'] ?? '',
        ),
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: LatLng(
          _getDropLatitude(),
          _getDropLongitude(),
        ),
        icon: dropIcon,
        infoWindow: InfoWindow(
          title: translate('DropLocation'),
          snippet: booking['dropAddress'] ?? '',
        ),
      ),
    };
  }

  // Crée une icône carrée personnalisée
  Future<BitmapDescriptor> _createSquareIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0;
    
    // Dessiner un carré rouge
    final paint = Paint()
      ..color = const Color(0xFFFF5357)
      ..style = PaintingStyle.fill;
    
    // Carré avec bordure blanche
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, size - 8, size - 8),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 6, size - 12, size - 12),
        const Radius.circular(2),
      ),
      paint,
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // Crée une icône ronde personnalisée
  Future<BitmapDescriptor> _createCircleIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0;
    
    // Dessiner un cercle rouge
    final paint = Paint()
      ..color = const Color(0xFFFF5357)
      ..style = PaintingStyle.fill;
    
    // Cercle avec bordure blanche
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      (size - 8) / 2,
      Paint()..color = Colors.white,
    );
    
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      (size - 12) / 2,
      paint,
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // Crée une polyline simple entre le point de départ et d'arrivée
  Set<Polyline> _createPolylines() {
    if (!_hasValidCoordinates()) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(_getPickupLatitude(), _getPickupLongitude()),
          LatLng(_getDropLatitude(), _getDropLongitude()),
        ],
        color: MyColors.coralPink,
        width: 4,
        patterns: [], // Ligne solide
        geodesic: true, // Suit la courbure de la terre
      ),
    };
  }
}
