// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/types/badge_types.dart';
import 'package:rider_ride_hailing_app/extenstions/booking_type_extenstion.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/open_whatapp.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/modal/file_upload_modal.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/provider/saved_payment_method_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_chat_provider.dart';
import 'package:rider_ride_hailing_app/pages/view_module/trip_chat_screen.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/widget/custom_circular_image.dart';
import 'package:rider_ride_hailing_app/widget/image_preview_widget.dart';
import 'package:rider_ride_hailing_app/widget/input_text_field_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import '../contants/my_image_url.dart';
import '../contants/sized_box.dart';
import '../widget/custom_text.dart';

class DriverOnWay extends StatefulWidget {
  final Function(String reason) onCancelTap;
  final Map booking;
  final DriverModal? driver;
  final VehicleModal? selectedVehicle;
  const DriverOnWay({
    Key? key,
    required this.onCancelTap,
    this.driver,
    required this.booking,
    this.selectedVehicle,
  }) : super(key: key);

  @override
  State<DriverOnWay> createState() => _DriverOnWayState();
}

class _DriverOnWayState extends State<DriverOnWay> {
  final TextEditingController sendMessController = TextEditingController();
  @override
  void initState() {
    super.initState();
    // Initialiser le compteur de messages non-lus pour le chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.booking['id'] != null) {
        final chatProvider = Provider.of<TripChatProvider>(context, listen: false);
        chatProvider.initUnreadCounter(widget.booking['id']);
      }
    });
  }

  /// Calcule la distance réelle parcourue basée sur le chemin GPS enregistré
  String _calculateActualDistance() {
    try {
      // Vérifier si des données de chemin GPS sont disponibles
      if (widget.booking['coveredPath'] != null && widget.booking['coveredPath'] is List) {
        List coveredPath = widget.booking['coveredPath'] as List;
        
        // Vérifier qu'il y a au moins 2 points pour calculer une distance
        if (coveredPath.length >= 2) {
          double distance = calculateDistanceByArray(coveredPath);
          return distance.toStringAsFixed(1);
        }
      }
      
      // Fallback 1: Essayer d'utiliser rideDistance si disponible
      if (widget.booking['rideDistance'] != null) {
        return widget.booking['rideDistance'].toString();
      }
      
      // Fallback 2: Essayer d'utiliser total_distance si disponible
      if (widget.booking['total_distance'] != null) {
        return widget.booking['total_distance'].toString();
      }
      
      // Fallback 3: Calculer approximativement basé sur pickup et dropoff
      if (widget.booking['pickup'] != null && widget.booking['dropoff'] != null) {
        var pickup = widget.booking['pickup'];
        var dropoff = widget.booking['dropoff'];
        
        if (pickup['lat'] != null && pickup['lng'] != null && 
            dropoff['lat'] != null && dropoff['lng'] != null) {
          double distance = getDistance(
            pickup['lat'], pickup['lng'], 
            dropoff['lat'], dropoff['lng']
          );
          return distance.toStringAsFixed(1);
        }
      }
      
      // Derniere option: retourner N/A
      return 'N/A';
    } catch (e) {
      myCustomPrintStatement('Erreur calcul distance réelle: $e');
      return 'N/A';
    }
  }

  /// Affiche un dialogue de confirmation avant d'autoriser le démarrage de la course
  void _confirmDriverArrival(TripProvider tripProvider) async {
    // Afficher dialogue de confirmation
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.help_outline,
                color: MyColors.primaryColor,
                size: 24,
              ),
              hSizedBox,
              Expanded(
                child: SubHeadingText(
                  translate("confirmDriverArrival"),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParagraphText(
                translate("confirmDriverArrivalMessage"),
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
              vSizedBox,
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MyColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MyColors.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: MyColors.primaryColor,
                      size: 20,
                    ),
                    hSizedBox,
                    Expanded(
                      child: ParagraphText(
                        translate("driverCanStartTripAfterConfirmation"),
                        fontSize: 13,
                        color: MyColors.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: SubHeadingText(
                translate("cancel"),
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _processDriverArrivalConfirmation(tripProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: SubHeadingText(
                translate("confirm"),
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Traite la confirmation d'arrivée du conducteur
  Future<void> _processDriverArrivalConfirmation(TripProvider tripProvider) async {
    try {
      String? bookingId = widget.booking['id'];
      if (bookingId != null && bookingId.isNotEmpty) {
        myCustomPrintStatement("🚀 Début confirmation d'arrivée du conducteur - ID: $bookingId");
        
        // Mettre à jour le statut vers DRIVER_REACHED et autoriser le démarrage côté chauffeur
        await FirestoreServices.bookingRequest.doc(bookingId).update({
          'status': BookingStatusType.DRIVER_REACHED.value,
          'customerArrivalConfirmed': true, // Flag pour autoriser le chauffeur à démarrer
        });
        
        myCustomPrintStatement("✅ Conducteur confirmé arrivé - Transition vers DRIVER_REACHED (status: ${BookingStatusType.DRIVER_REACHED.value})");
        myCustomPrintStatement("🎯 AUTORISATION DÉMARRAGE: Flag customerArrivalConfirmed défini à true pour le chauffeur");
        
        // Mettre à jour aussi les données locales du provider si elles existent
        if (tripProvider.booking != null && tripProvider.booking!['id'] == bookingId) {
          tripProvider.booking!['status'] = BookingStatusType.DRIVER_REACHED.value;
          tripProvider.booking!['customerArrivalConfirmed'] = true;
          myCustomPrintStatement("✅ Données locales du provider mises à jour avec autorisation démarrage");
        }
        
        // Déclencher la mise à jour de l'interface
        if (mounted) {
          setState(() {
            // L'interface se mettra à jour automatiquement
          });
        }
        
      } else {
        myCustomPrintStatement("❌ ID de réservation manquant pour confirmer l'arrivée");
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lors de la confirmation d'arrivée: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: globalHorizontalPadding,
          right: globalHorizontalPadding,
          top: 12, // 📍 Safe area padding pour éviter que le texte déborde
          bottom: 4),
      child: ValueListenableBuilder(
        valueListenable: sheetShowNoti,
        builder: (context, sheetValue, child) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            
            // Affichage prioritaire pour les courses terminées avec paiement cash
            // Cette interface s'affiche toujours, même si le sheet est réduit
            if (widget.booking['status'] == BookingStatusType.RIDE_COMPLETE.value &&
                PaymentMethodTypeExtension.fromValue(widget.booking['paymentMethod']) == PaymentMethodType.cash)
              _buildRideCompletedCashPaymentView()
            // Interface normale pour les autres cas (seulement si sheet étendu)
            else if (sheetValue)
              widget.driver != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // vSizedBox2,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SubHeadingText(
                                  widget.booking['status'] ==
                                          BookingStatusType.ACCEPTED.value
                                      ? translate("Driverisontheirway")
                                      : widget.booking['status'] ==
                                              BookingStatusType
                                                  .DRIVER_REACHED.value
                                          ? translate(
                                              'driverhasarrivedatyourlocation')
                                          : widget.booking['status'] ==
                                                  BookingStatusType
                                                      .RIDE_COMPLETE.value
                                              ? "${translate("rideCompleted")}"
                                              : "${translate("Arrival at")} ${DateFormat("HH:mm").format(DateTime.now().add(Duration(minutes: int.parse((getDistance(widget.driver!.currentLat!, widget.driver!.currentLng!, widget.booking['dropLat'], widget.booking['dropLng']) * (60 / 20)).toStringAsFixed(0)))))}" ,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                                if (widget.driver != null &&
                                    widget.booking['status'] ==
                                        BookingStatusType.ACCEPTED.value)
                                  SubHeadingText(
                                    '${widget.driver!.fullName} ${translate("arrivesIn")} ${(getDistance(widget.driver!.currentLat!, widget.driver!.currentLng!, widget.booking['pickLat'], widget.booking['pickLng']) * (60 / 20)).toStringAsFixed(0)} minutes',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                // Message spécial pour paiement en espèces
                                if (widget.booking['status'] == BookingStatusType.RIDE_COMPLETE.value &&
                                    PaymentMethodTypeExtension.fromValue(widget.booking['paymentMethod']) == PaymentMethodType.cash)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: MyColors.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: MyColors.primaryColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.payment,
                                                color: MyColors.primaryColor,
                                                size: 20,
                                              ),
                                              hSizedBox05,
                                              Expanded(
                                                child: SubHeadingText(
                                                  translate("pleasePayCashToDriver"),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: MyColors.primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          vSizedBox05,
                                          ParagraphText(
                                            translate("waitingForDriverPaymentConfirmation"),
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                if (widget.booking['status'] ==
                                        BookingStatusType.ACCEPTED.value &&
                                    widget.driver != null &&
                                    widget.driver!.currentLat != null &&
                                    widget.driver!.currentLng != null)
                                  Container(
                                    alignment: Alignment.center,
                                    height: 40,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      color: MyColors.primaryColor,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ParagraphText(
                                          '${(getDistance(widget.driver!.currentLat!, widget.driver!.currentLng!, widget.booking['pickLat'], widget.booking['pickLng']) * (60 / 20)).toStringAsFixed(0)} ',
                                          fontWeight: FontWeight.w500,
                                          color: MyColors.whiteColor,
                                          lineHeight: 1,
                                          fontSize: 16,
                                        ),
                                        ParagraphText(
                                          'Min',
                                          color: MyColors.whiteColor,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 9,
                                        ),
                                      ],
                                    ),
                                  ),
                                // Bouton « ? » pour autoriser le démarrage de la course - TEMPORAIREMENT MASQUÉ
                                // if (widget.booking['status'] == BookingStatusType.ACCEPTED.value) ...[
                                //   hSizedBox,
                                //   Consumer<TripProvider>(
                                //     builder: (context, tripProvider, child) => InkWell(
                                //       onTap: () {
                                //         // Autoriser le conducteur à commencer la course
                                //         _confirmDriverArrival(tripProvider);
                                //       },
                                //       child: Container(
                                //         height: 45,
                                //         width: 45,
                                //         decoration: BoxDecoration(
                                //           borderRadius: BorderRadius.circular(25),
                                //           color: MyColors.blackThemeColor(),
                                //           boxShadow: [
                                //             BoxShadow(
                                //               color: MyColors.blackThemeColorWithOpacity(0.2),
                                //               blurRadius: 0.5,
                                //               spreadRadius: 1,
                                //               offset: const Offset(0, 0),
                                //             )
                                //           ],
                                //         ),
                                //         child: Icon(
                                //           Icons.play_arrow,
                                //           color: MyColors.whiteThemeColor(),
                                //           size: 24,
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                // ],
                              ],
                            ),
                          ],
                        ),
                        if (widget.booking['status'] ==
                                BookingStatusType.DRIVER_REACHED.value &&
                            globalSettings.enableBookingOTPVerification)
                          const Divider(),
                        if (widget.booking['status'] ==
                                BookingStatusType.DRIVER_REACHED.value &&
                            globalSettings.enableBookingOTPVerification)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SubHeadingText("Your Otp :-"),
                              Row(
                                children: List.generate(
                                  widget.booking['bookingOTP'].length,
                                  (index) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 8),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                            color: MyColors.blackThemeColor())),
                                    child: ParagraphText(
                                      widget.booking['bookingOTP'][index],
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const Divider(),

                        // Résumé de la course pour paiement en espèces
                        if (widget.booking['status'] == BookingStatusType.RIDE_COMPLETE.value &&
                            PaymentMethodTypeExtension.fromValue(widget.booking['paymentMethod']) == PaymentMethodType.cash)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SubHeadingText(
                                translate("tripSummary"),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              vSizedBox05,
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: MyColors.textFillThemeColor(),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        ParagraphText(
                                          translate("totalDistance"),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        ParagraphText(
                                          "${_calculateActualDistance()} km",
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ],
                                    ),
                                    if (widget.booking['tripDurationInMinutes'] != null) ...[
                                      vSizedBox05,
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          ParagraphText(
                                            translate("tripDuration"),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          ParagraphText(
                                            "${widget.booking['tripDurationInMinutes']} min",
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ],
                                      ),
                                    ],
                                    const Divider(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: MyColors.coralPink.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: MyColors.coralPink,
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            translate("rideCompletedPaymentMessage"),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "${globalSettings.currency} ${formatAriary(double.parse(widget.booking['ride_price_to_pay'].toString()))}",
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: MyColors.coralPink,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            translate("toDriver"),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              vSizedBox,
                              const Divider(),
                            ],
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Consumer<AdminSettingsProvider>(
                                builder: (context, adminProvider, child) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Prix barré en haut
                                      _buildPriceBreakdown(adminProvider),
                                      const SizedBox(height: 1),
                                      // Logo au milieu
                                      Consumer<SavedPaymentMethodProvider>(
                                        builder: (context, paymentMethodProv, child) => Center(
                                          child: CustomCircularImage(
                                            imageUrl: paymentMethodProv
                                                .allPaymentMethods
                                                .where((element) =>
                                                    element['paymentGatewayType'] ==
                                                    PaymentMethodTypeExtension
                                                        .fromValue(widget
                                                            .booking['paymentMethod']))
                                                .first['image'],
                                            width: 100,
                                            height: 100,
                                            borderRadius: 0,
                                            fileType: CustomFileType.asset,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      // Prix final en bas
                                      _buildFinalPrice(),
                                    ],
                                  );
                                },
                              ),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SubHeadingText(
                                    widget.driver!.vehicleData!.licenseNumber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    textAlign: TextAlign.center,
                                  ),
                                  vSizedBox05,
                                  GestureDetector(
                                    onTap: () {
                                      push(
                                        context: context,
                                        screen: ImagePreviewWidget(
                                            image: List.generate(
                                              widget.driver!.vehicleData!
                                                  .vehicleImages.length,
                                              (index) => FileUploadModal(
                                                filePath: widget
                                                    .driver!
                                                    .vehicleData!
                                                    .vehicleImages[index],
                                                type: "1",
                                                thumbnail: "",
                                                id: 0,
                                                fileType: CustomFileType.network,
                                              ),
                                            ),
                                            imageIndex: 0),
                                      );
                                    },
                                    child: CustomCircularImage(
                                      imageUrl: widget
                                          .driver!.vehicleData!.vehicleImages[0],
                                      width: 120,
                                      height: 60,
                                      borderRadius: 30,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  vSizedBox05,
                                  SubHeadingText(
                                    widget.driver!.vehicleData!.vehicleBrandName,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    textAlign: TextAlign.center,
                                  ),
                                  SubHeadingText(
                                    widget.driver!.vehicleData!.vehicleModal,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SubHeadingText(
                                      widget.driver!.firstName,
                                      fontWeight: FontWeight.bold,
                                      textAlign: TextAlign.center,
                                      fontSize: 16,
                                    ),
                                    if (widget.driver!.batchStatus !=
                                        BadgeTypes.noBadge)
                                      hSizedBox05,
                                    if (widget.driver!.batchStatus !=
                                        BadgeTypes.noBadge)
                                      Image.asset(
                                        MyImagesUrl.verifiedStatusIcon,
                                        height: 25,
                                        width: 25,
                                        color: BadgeTypes.getColor(
                                          widget.driver!.batchStatus,
                                        ),
                                      )
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    push(
                                      context: context,
                                      screen: ImagePreviewWidget(image: [
                                        FileUploadModal(
                                            filePath:
                                                widget.driver!.profileImage,
                                            type: "1",
                                            thumbnail: "",
                                            id: 0,
                                            fileType: CustomFileType.network)
                                      ], imageIndex: 0),
                                    );
                                  },
                                  child: Container(
                                    alignment: Alignment.bottomCenter,
                                    height: 75,
                                    width: 75,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: BadgeTypes.getColor(
                                              widget.driver!.batchStatus),
                                          width: 3.8),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          
                                          widget.driver!.profileImage,
                                        ),
                                         fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                vSizedBox05,
                                RatingBar(
                                  initialRating: widget.driver!.averageRating,
                                  itemSize: 12,
                                  direction: Axis.horizontal,
                                  allowHalfRating: true,
                                  itemCount: 5,
                                  ignoreGestures: true,
                                  ratingWidget: RatingWidget(
                                    full: Image.asset(
                                      MyImagesUrl.star,
                                      color: Colors.orange,
                                    ),
                                    half: Image.asset(
                                      MyImagesUrl.star,
                                      color: Colors.orange,
                                    ),
                                    empty: Image.asset(
                                      MyImagesUrl.star,
                                      color: MyColors.blackThemeColor()
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  itemPadding: const EdgeInsets.symmetric(
                                      horizontal: 1.0),
                                  onRatingUpdate: (rating) {},
                                ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        vSizedBox05,
                        // Champ de message avec bouton d'envoi
                        Consumer<TripChatProvider>(
                          builder: (context, chatProvider, child) {
                            return Row(
                              children: [
                                // Icône message avec badge si messages non lus
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TripChatScreen(
                                          bookingId: widget.booking['id'],
                                          driver: widget.driver!,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 28,
                                          color: MyColors.blackThemeColor(),
                                        ),
                                        if (chatProvider.unreadCount > 0)
                                          Positioned(
                                            right: -6,
                                            top: -6,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: MyColors.primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 18,
                                                minHeight: 18,
                                              ),
                                              child: Text(
                                                chatProvider.unreadCount > 9
                                                    ? '9+'
                                                    : '${chatProvider.unreadCount}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TripChatScreen(
                                            bookingId: widget.booking['id'],
                                            driver: widget.driver!,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: MyColors.textFillThemeColor(),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              translate("sendMessageHere"),
                                              style: TextStyle(
                                                color: MyColors.blackThemeColor().withOpacity(0.5),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: MyColors.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.send,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        // Message de prévention contre la fraude - UNIQUEMENT pendant "Le chauffeur est en route"
                        // Cacher dès que la course commence (chauffeur a récupéré le passager)
                        if (widget.booking['status'] >= BookingStatusType.ACCEPTED.value && 
                            widget.booking['status'] < BookingStatusType.RIDE_STARTED.value) ...[
                          vSizedBox,
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.all(8), // Padding réduit de 12 à 8
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange.shade700,
                                      size: 20,
                                    ),
                                    hSizedBox05,
                                    Expanded(
                                      child: SubHeadingText(
                                        translate("fraudPreventionWarning"),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4), // Espacement réduit
                                ParagraphText(
                                  translate("fraudPreventionMessage"),
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                        ],

                        Consumer<TripProvider>(
                          builder: (context, tripProvider, child) => widget
                                          .booking['status'] <
                                      BookingStatusType.RIDE_COMPLETE.value &&
                                  tripProvider.showCancelButton
                              ? Align(
                                  alignment: Alignment.center,
                                  child: TextButton(
                                    onPressed: () async {
                                      showCancelReasonBottomSheet();
                                    },
                                    child: SubHeadingText(
                                      translate("CancelTrip"),
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                      underlined: true,
                                      fontSize: 15,
                                    ),
                                  ),
                                )
                              : Container(),
                        ),

                        vSizedBox
                      ],
                    )
                  : const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
              ],
            ),
      ),
    );
  }

  showCancelReasonBottomSheet() {
    List<String> cancelReasonList = [
      translate("Driver asked me to cancel"),
      translate("Driver not getting closer"),
      translate("Waiting time was too long"),
      translate("Driver arrived early"),
      translate("Could not find driver"),
      translate("Other")
    ];
    List<String> cancelReasonBeforeAcceptList = [
      translate("Requested wrong vehicle"),
      translate("Waiting time was too long"),
      translate("Requested by accident"),
      translate("Selected wrong dropoff"),
      translate("Selected wrong pickup"),
      translate("Other"),
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
                    IconButton(
                      onPressed: () {
                        popPage(context: context);
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
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
                Consumer<TripProvider>(
                  builder: (context, tripProvider, child) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: tripProvider.booking == null
                        ? 0
                        : tripProvider.booking!['status'] == 0
                            ? cancelReasonBeforeAcceptList.length
                            : cancelReasonList.length,
                    itemBuilder: (context, index) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            // Fermer la popup avant d'appeler la fonction de callback
                            Navigator.of(context).pop();
                            widget.onCancelTap(
                                tripProvider.booking!['status'] == 0
                                    ? cancelReasonBeforeAcceptList[index]
                                    : cancelReasonList[index]);
                          },
                          child: SubHeadingText(
                            tripProvider.booking!['status'] == 0
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceBreakdown(AdminSettingsProvider adminProvider) {
    // Prix à payer (final)
    double finalPrice = double.parse(widget.booking['ride_price_to_pay'].toString());
    
    // Vérifier s'il y a des promos appliquées
    bool hasPromoCode = widget.booking['ride_promocode_discount'] != null && 
                       widget.booking['ride_promocode_discount'] > 0;
    bool hasPaymentPromo = widget.booking['ride_payment_method_discount'] != null && 
                          widget.booking['ride_payment_method_discount'] > 0;
    
    // Affichage simple si aucune promo n'est appliquée
    if (!hasPromoCode && !hasPaymentPromo) {
      return SubHeadingText(
        '${globalSettings.currency} ${formatAriary(finalPrice)}',
        fontWeight: FontWeight.bold,
        fontSize: 16,
      );
    }
    
    // Calcul du prix de base
    double basePrice = finalPrice;
    if (hasPromoCode) {
      basePrice += widget.booking['ride_promocode_discount'];
    }
    if (hasPaymentPromo) {
      basePrice += widget.booking['ride_payment_method_discount'];
    }
    
    if (hasPromoCode || hasPaymentPromo) {
      // S'il y a une promo, afficher le prix barré
      return Text(
        '${globalSettings.currency} ${formatAriary(basePrice)}',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
          decoration: TextDecoration.lineThrough,
        ),
      );
    } else {
      // S'il n'y a pas de promo, afficher le prix final (non barré)
      return Text(
        '${globalSettings.currency} ${formatAriary(finalPrice)}',
        style: TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.bold, 
          color: MyColors.coralPink
        ),
      );
    };
  }

  /// Interface dédiée pour les courses terminées avec paiement en cash
  Widget _buildRideCompletedCashPaymentView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        vSizedBox,
        // Titre principal
        Center(
          child: SubHeadingText(
            translate("rideCompleted"),
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: MyColors.primaryColor,
          ),
        ),
        vSizedBox2,
        
        // Message de paiement cash avec montant proéminent
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MyColors.coralPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MyColors.coralPink,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.payment,
                color: MyColors.coralPink,
                size: 40,
              ),
              vSizedBox,
              Text(
                translate("rideCompletedPaymentMessage"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              vSizedBox2,
              Text(
                "${globalSettings.currency} ${formatAriary(double.parse(widget.booking['ride_price_to_pay'].toString()))}",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: MyColors.coralPink,
                ),
              ),
              vSizedBox05,
              Text(
                translate("toDriver"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        vSizedBox2,
        
        // Résumé de la course
        SubHeadingText(
          translate("tripSummary"),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        vSizedBox05,
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MyColors.textFillThemeColor(),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ParagraphText(
                    translate("totalDistance"),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  ParagraphText(
                    "${_calculateActualDistance()} km",
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
              if (widget.booking['tripDurationInMinutes'] != null) ...[
                vSizedBox05,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ParagraphText(
                      translate("tripDuration"),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    ParagraphText(
                      "${widget.booking['tripDurationInMinutes']} min",
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        vSizedBox,
        
        // Message d'attente de confirmation du conducteur
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MyColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: MyColors.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                color: MyColors.primaryColor,
                size: 20,
              ),
              hSizedBox,
              Expanded(
                child: ParagraphText(
                  translate("waitingForDriverPaymentConfirmation"),
                  fontSize: 13,
                  color: MyColors.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        vSizedBox2,
        
        // Informations du conducteur si disponible
        if (widget.driver != null) ...[
          const Divider(),
          vSizedBox,
          Row(
            children: [
              // Photo du conducteur
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MyColors.primaryColor,
                    width: 2,
                  ),
                  image: DecorationImage(
                    image: NetworkImage(widget.driver!.profileImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              hSizedBox2,
              // Informations conducteur
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubHeadingText(
                      widget.driver!.firstName,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    ParagraphText(
                      "${widget.driver!.vehicleData!.vehicleBrandName} ${widget.driver!.vehicleData!.vehicleModal}",
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    ParagraphText(
                      widget.driver!.vehicleData!.licenseNumber,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              // Actions de contact
              Column(
                children: [
                  InkWell(
                    onTap: () async {
                      var url = "tel: ${widget.driver!.countryCode}${widget.driver!.phone.startsWith("0") ? widget.driver!.phone.substring(1) : widget.driver!.phone}";
                      if (await canLaunch(url)) {
                        await launch(url);
                      }
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: MyColors.primaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.phone,
                        color: MyColors.primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                  vSizedBox05,
                  InkWell(
                    onTap: () async {
                      await openWhatsApp("${widget.driver!.countryCode}${widget.driver!.phone.startsWith("0") ? widget.driver!.phone.substring(1) : widget.driver!.phone}");
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.green.withOpacity(0.1),
                      child: Image.asset(
                        MyImagesUrl.whatsAppIcon,
                        width: 20,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        vSizedBox2,
      ],
    );
  }

  /// Construit le widget pour afficher le prix final (seulement s'il y a une promo)
  Widget _buildFinalPrice() {
    bool hasPromoCode = widget.booking['ride_promocode_discount'] != null && 
                       double.parse(widget.booking['ride_promocode_discount'].toString()) > 0;
    bool hasPaymentPromo = widget.booking['ride_payment_method_discount'] != null && 
                          double.parse(widget.booking['ride_payment_method_discount'].toString()) > 0;
    
    if (hasPromoCode || hasPaymentPromo) {
      // S'il y a une promo, afficher le prix final
      double finalPrice = double.parse(widget.booking['ride_price_to_pay'].toString());
      return Text(
        '${globalSettings.currency} ${formatAriary(finalPrice)}',
        style: TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.bold, 
          color: MyColors.coralPink
        ),
      );
    } else {
      // Pas de promo, ne rien afficher (le prix est déjà affiché en haut)
      return const SizedBox.shrink();
    }
  }
}
