// ignore_for_file: deprecated_member_use, invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:rider_ride_hailing_app/widgets/booking_map.dart';
import 'package:rider_ride_hailing_app/utils/gmap_flutter_adapter.dart' as gma;
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
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../contants/global_data.dart';
import '../../../contants/my_colors.dart';
import '../../../contants/my_image_url.dart';
import '../../../widget/custom_appbar.dart';
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
  // Contrôleurs flutter_map (1 par carte : récap statique / suivi de trajet).
  final fm.MapController _summaryMapController = fm.MapController();
  final fm.MapController _trackMapController = fm.MapController();

  @override
  void initState() {
    booking = widget.booking;
    getdata();
    super.initState();
  }

  // ---------------------------------------------------------------------------
  // Helpers d'état (statut numérique de la course)
  // ---------------------------------------------------------------------------
  int get _statusValue {
    final s = booking['status'];
    if (s is int) return s;
    if (s is num) return s.toInt();
    return BookingStatusType.PENDING_REQUEST.value;
  }

  bool get _isCompleted => _statusValue == BookingStatusType.RIDE_COMPLETE.value;

  bool get _isCancelled =>
      _statusValue == BookingStatusType.CANCELLED.value ||
      _statusValue == BookingStatusType.CANCELLED_BY_RIDER.value;

  bool get _isScheduled => booking['isSchedule'] == true;

  // Détermine si cette course peut être annulée
  bool get canBeCancelled {
    final status = booking['status'] ?? BookingStatusType.PENDING_REQUEST.value;

    // Jamais annulable si terminée, annulée, ou en cours/après démarrage
    if (status >= BookingStatusType.RIDE_STARTED.value) return false;

    // Doit être soit programmée, soit acceptée par un chauffeur
    return booking['isSchedule'] == true || booking['acceptedBy'] != null;
  }

  getdata() async {
    try {
      if (booking['status'] != BookingStatusType.RIDE_COMPLETE.value) {
        var b = await FirestoreServices.bookingRequest.doc(booking['id']).get();
        if (b.exists) {
          booking = b.data() as Map;
        }
      } else {
        // Pour les courses terminées, les données sont déjà dans le booking
        // passé à l'écran. On tente de rafraîchir depuis Firestore mais
        // on ne bloque pas l'affichage si ça échoue.
        try {
          var b =
              await FirestoreServices.bookingHistory.doc(booking['id']).get();
          if (b.exists) {
            booking = b.data() as Map;
          }
        } catch (e) {
          myCustomPrintStatement(
              'Erreur rafraichissement booking history, utilisation des donnees locales: $e');
        }
      }
    } catch (e) {
      myCustomPrintStatement('Erreur getdata booking: $e');
    }

    // Debug limité - ne pas exposer les données sensibles (téléphone, etc.)
    if (kDebugMode) {
      myCustomPrintStatement(
          'Booking ${booking['id']} - status: ${booking['status']}, isSchedule: ${booking['isSchedule']}');
    }

    // Charger les détails du chauffeur seulement s'il y en a un
    if (booking['acceptedBy'] != null) {
      try {
        var d = await FirestoreServices.users.doc(booking['acceptedBy']).get();
        if (d.exists) {
          driver = DriverModal.fromJson(d.data() as Map);
          if (kDebugMode) {
            myCustomPrintStatement(
                'Driver loaded: ${driver?.firstName ?? "N/A"}');
          }
        }
      } catch (e) {
        myCustomPrintStatement('Erreur chargement chauffeur: $e');
      }
    }

    if (mounted) {
      setState(() {});
    }
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
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600),
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
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600),
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
          'cancelledBy': 'rider',
          'cancelledByUserId': userData.value!.id,
          'cancelReason': cancelReason ?? 'No reason provided',
          'ride_status': 'Cancelled by Rider',
          'endTime': FieldValue.serverTimestamp(),
        });

        // Copier vers l'historique avec le statut d'annulation
        Map<String, dynamic> historyData = Map.from(booking);
        historyData['status'] = BookingStatusType.CANCELLED_BY_RIDER.value;
        historyData['cancelledBy'] = 'rider';
        historyData['cancelledByUserId'] = userData.value!.id;
        historyData['cancelReason'] = cancelReason ?? 'No reason provided';
        historyData['ride_status'] = 'Cancelled by Rider';
        historyData['endTime'] = FieldValue.serverTimestamp();

        await FirestoreServices.bookingHistory
            .doc(booking['id'])
            .set(historyData);
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
      if (tripProvider.booking != null &&
          tripProvider.booking!['id'] == booking['id']) {
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

  // ===========================================================================
  // BUILD — détail de course, mise en page web compacte (2 colonnes ≥ 720px)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _returnToMainMenu();
        return false; // Empêche la navigation par défaut
      },
      child: Scaffold(
        backgroundColor: MyColors.whiteThemeColor(),
        appBar: CustomAppBar(
          isBackIcon: true,
          title: translate("BookingDetails"),
          titleFontSize: 18,
          titleFontWeight: FontWeight.w600,
          onPressed: _returnToMainMenu,
        ),
        body: booking['requestTime'] == null
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      child: _buildContent(context),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final Widget header = _buildHeader();
    final Widget? map = _buildMap();
    final Widget? rating = _buildRatingSection();
    final Widget? details = _buildRideDetails();
    final Widget? itinerary = _buildItinerary();
    final Widget? driverCard = _buildDriverCard();
    final Widget? price = _buildPriceBreakdown();
    final Widget? cancel = _buildCancelButton();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 720;

        if (wide && map != null) {
          // Web : carte + itinéraire à gauche, infos à droite.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _stack([map, itinerary], dividers: false),
                  ),
                  const SizedBox(width: 34),
                  Expanded(
                    flex: 5,
                    child: _stack([rating, details, driverCard, price]),
                  ),
                ],
              ),
              if (cancel != null) ...[const SizedBox(height: 26), cancel],
            ],
          );
        }

        // Mobile / écran étroit : pile unique.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 6),
            _stack([map, rating, details, itinerary, driverCard, price]),
            if (cancel != null) ...[const SizedBox(height: 26), cancel],
          ],
        );
      },
    );
  }

  // Empile des sections (en ignorant les nulles), séparées par un filet fin.
  Widget _stack(List<Widget?> sections, {bool dividers = true}) {
    final visible = sections.whereType<Widget>().toList();
    final children = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      if (i > 0) {
        children.add(dividers ? _sectionDivider() : const SizedBox(height: 20));
      }
      children.add(visible[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // ---------------------------------------------------------------------------
  // Sections (retournent null quand vides → ignorées par _stack)
  // ---------------------------------------------------------------------------

  // En-tête : titre, sous-titre date (+ chauffeur), pastille de statut.
  Widget _buildHeader() {
    final Timestamp? ts = (_isScheduled && booking['scheduleTime'] != null)
        ? booking['scheduleTime'] as Timestamp
        : booking['requestTime'] as Timestamp?;
    final String dateLabel = ts != null
        ? formatTimestamp(ts, formateString: 'EEEE d MMMM yyyy, HH:mm')
        : '';
    final String driverName = driver != null
        ? (_isScheduled ? driver!.firstName : driver!.fullName)
        : '';
    final String subtitle = driverName.isNotEmpty
        ? (dateLabel.isNotEmpty ? "$dateLabel · $driverName" : driverName)
        : dateLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate("YourRide"),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MyColors.blackThemeColor(),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13.5,
              color: MyColors.blackThemeColorWithOpacity(0.6),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _statusChip(),
      ],
    );
  }

  // Pastille de statut colorée (annulée / terminée / planifiée / en cours).
  Widget _statusChip() {
    String label;
    Color color;
    if (_isCancelled) {
      label = translate("RideCancelled");
      color = Colors.red;
    } else if (_isCompleted) {
      label = translate("rideCompleted");
      color = const Color(0xFF1FA463);
    } else if (_isScheduled) {
      final when = booking['scheduleTime'] != null
          ? formatTimestamp(booking['scheduleTime'])
          : '';
      label = "${translate("Scheduledon")} $when".trim();
      color = Colors.deepOrange;
    } else {
      label = translate("Running");
      color = MyColors.horizonBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // Carte arrondie : trajet réel (terminée) ou pickup→drop (coords valides).
  Widget? _buildMap() {
    Widget? map;
    if (_isCompleted &&
        booking['suggestPath'] != null &&
        (booking['suggestPath'] as List).isNotEmpty) {
      map = _completedTripMap();
    } else if (_hasValidCoordinates()) {
      map = _plannedTripMap();
    }
    if (map == null) return null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(height: 240, width: double.infinity, child: map),
    );
  }

  // Section « Note du trajet » (uniquement pour les courses terminées).
  Widget? _buildRatingSection() {
    if (!_isCompleted) return null;
    final hasRating = booking['rating_by_customer'] != null;
    final hasDriverRating = booking['rating_by_driver'] != null;
    if (!hasRating && !hasDriverRating && driver == null) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(translate("TripRating")),
        if (hasRating) ...[
          _stars(
              (booking['rating_by_customer']['rating'] as num).toDouble(),
              size: 22),
          if ((booking['rating_by_customer']['review'] ?? '')
              .toString()
              .isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              booking['rating_by_customer']['review'],
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: MyColors.blackThemeColorWithOpacity(0.7),
              ),
            ),
          ],
        ] else if (driver != null)
          RoundEdgedButton(
            text: translate("Rate"),
            height: 40,
            width: 130,
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
              await push(context: context, screen: RateUsScreen(booking: b));
              getdata();
            },
          ),
        if (hasDriverRating) ...[
          const SizedBox(height: 16),
          Text(
            "${translate("RatingFromDriver")}:",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: MyColors.blackThemeColorWithOpacity(0.7),
            ),
          ),
          const SizedBox(height: 6),
          _stars((booking['rating_by_driver']['rating'] as num).toDouble(),
              size: 18),
          if ((booking['rating_by_driver']['review'] ?? '')
              .toString()
              .isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              booking['rating_by_driver']['review'],
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: MyColors.blackThemeColorWithOpacity(0.7),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // Section « Détails de la course » : distance, paiement, prix indicatif.
  Widget? _buildRideDetails() {
    final bool hasDistance = booking['total_distance'] != null;
    final bool hasPayment =
        (booking['paymentMethod'] ?? '').toString().isNotEmpty;
    String? approxPrice;
    if (!_isCompleted && booking['ride_price_to_pay'] != null) {
      approxPrice =
          "${formatAriary(double.parse(booking['ride_price_to_pay'].toString()))} ${globalSettings.currency}";
    }

    if (!hasDistance && !hasPayment && approxPrice == null) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(translate("RideDetailsTitle")),
        if (hasDistance)
          _detailRow(Icons.straighten, translate("Distance"),
              "${booking['total_distance']} km"),
        if (hasPayment)
          _detailRow(Icons.payments_outlined, translate("PaymentMethod"),
              booking['paymentMethod']),
        if (approxPrice != null)
          _detailRow(Icons.account_balance_wallet_outlined,
              translate("Approx"), approxPrice,
              highlight: true),
      ],
    );
  }

  // Section « Itinéraire » : timeline départ → arrivée.
  Widget? _buildItinerary() {
    final String pick = (booking['pickAddress'] ?? '').toString();
    final String drop = (booking['dropAddress'] ?? '').toString();
    if (pick.isEmpty && drop.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(translate("TripRoute")),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: MyColors.blackThemeColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: MyColors.blackThemeColorWithOpacity(0.2),
                    ),
                  ),
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: MyColors.coralPink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _itineraryStop(pick),
                    const SizedBox(height: 22),
                    _itineraryStop(drop),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Carte chauffeur (photo, nom, badge, note, véhicule) + contact si imminent.
  Widget? _buildDriverCard() {
    if (driver == null) return null;

    final bool showContact = _statusValue <
            BookingStatusType.RIDE_COMPLETE.value &&
        _isScheduled &&
        booking['scheduleTime'] != null &&
        (booking['scheduleTime'] as Timestamp)
                .toDate()
                .difference(Timestamp.now().toDate())
                .inMinutes <
            5;
    final String brand = driver!.vehicleData?.vehicleBrandName ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(translate("YourDriver")),
        Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: BadgeTypes.getColor(driver!.batchStatus), width: 3),
                image: DecorationImage(
                  image: NetworkImage(driver!.profileImage),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _isScheduled ? driver!.firstName : driver!.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MyColors.blackThemeColor(),
                          ),
                        ),
                      ),
                      if (driver!.batchStatus != BadgeTypes.noBadge) ...[
                        const SizedBox(width: 5),
                        Image.asset(
                          MyImagesUrl.verifiedStatusIcon,
                          height: 17,
                          width: 17,
                          color: BadgeTypes.getColor(driver!.batchStatus),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _stars(driver!.averageRating, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        "(${driver!.totalReveiwCount} ${translate("Reviews")})",
                        style: TextStyle(
                          fontSize: 11,
                          color: MyColors.blackThemeColorWithOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (brand.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                brand,
                style: TextStyle(
                  fontSize: 12.5,
                  color: MyColors.blackThemeColorWithOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
        if (showContact) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              InkWell(
                onTap: () async {
                  await openWhatsApp(
                      "${driver!.countryCode}${driver!.phone.startsWith("0") ? driver!.phone.substring(1) : driver!.phone}");
                },
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: MyColors.textFillThemeColor(),
                  child: Image.asset(
                    MyImagesUrl.whatsAppIcon,
                    width: 25,
                    color: MyColors.blackThemeColor(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              RoundEdgedButton(
                text: translate("Call"),
                height: 40,
                width: 100,
                onTap: () async {
                  var url =
                      "tel:${driver!.countryCode}${driver!.phone.startsWith("0") ? driver!.phone.substring(1) : driver!.phone}";
                  if (await canLaunch(url)) {
                    await launch(url);
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Ventilation tarifaire (uniquement pour les courses terminées).
  Widget? _buildPriceBreakdown() {
    if (!_isCompleted) return null;
    final String currency = globalSettings.currency;
    double d(dynamic v) => double.parse((v ?? 0).toString());
    final double rideAmount = (d(booking['ride_price_to_pay']) +
            d(booking['ride_bonus_price']) -
            d(booking['vehicle_base_price']) -
            (_isScheduled ? d(booking['rideScheduledServiceFee']) : 0))
        .abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(translate("Payment")),
        _priceRow(
          "${translate("RideAmount")} (${booking['total_distance']} km)",
          "${formatAriary(rideAmount)} $currency",
        ),
        _priceRow(
          translate("BasePrice"),
          "${formatAriary(d(booking['vehicle_base_price']))} $currency",
        ),
        if (_isScheduled)
          _priceRow(
            translate("Schedule fee"),
            "${formatAriary(booking['rideScheduledServiceFee'])} $currency",
          ),
        _priceRow(
          translate("Discount"),
          "-${formatAriary(d(booking['ride_bonus_price']))} $currency",
        ),
        Divider(height: 22, color: MyColors.blackThemeColorWithOpacity(0.1)),
        _priceRow(
          translate("TotalAmount"),
          "${formatAriary(d(booking['ride_price_to_pay']))} $currency",
          bold: true,
        ),
      ],
    );
  }

  // Bouton d'annulation (uniquement pour les courses annulables).
  Widget? _buildCancelButton() {
    if (!canBeCancelled) return null;
    return RoundEdgedButton(
      text: translate("cancelBooking"),
      color: Colors.red,
      textColor: Colors.white,
      borderRadius: 10,
      onTap: () => _showCancelBookingDialog(context),
      width: double.infinity,
    );
  }

  // ---------------------------------------------------------------------------
  // Petits widgets réutilisables
  // ---------------------------------------------------------------------------
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: MyColors.blackThemeColor(),
          ),
        ),
      );

  Widget _sectionDivider() => Divider(
        height: 28,
        thickness: 1,
        color: MyColors.blackThemeColorWithOpacity(0.08),
      );

  Widget _detailRow(IconData icon, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, size: 19, color: MyColors.blackThemeColorWithOpacity(0.55)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: MyColors.blackThemeColorWithOpacity(0.7),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
              color: MyColors.blackThemeColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: MyColors.blackThemeColor(),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MyColors.blackThemeColor(),
              ),
            ),
          ],
        ),
      );

  Widget _itineraryStop(String address) => Text(
        address.isEmpty ? '—' : address,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MyColors.blackThemeColor(),
        ),
      );

  // Étoiles en lecture seule (note client / chauffeur).
  Widget _stars(double rating, {double size = 18}) => RatingBar(
        initialRating: rating,
        itemSize: size,
        direction: Axis.horizontal,
        allowHalfRating: true,
        itemCount: 5,
        ignoreGestures: true,
        ratingWidget: RatingWidget(
          full: Image.asset(MyImagesUrl.star, color: MyColors.colorStartColor()),
          half: Image.asset(MyImagesUrl.star, color: MyColors.colorStartColor()),
          empty: Image.asset(MyImagesUrl.star,
              color: MyColors.blackThemeColorWithOpacity(0.25)),
        ),
        itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
        onRatingUpdate: (r) {},
      );

  // ---------------------------------------------------------------------------
  // Cartes
  // ---------------------------------------------------------------------------

  // Carte d'une course planifiée/en cours : marqueurs pickup/drop + ligne directe.
  Widget _plannedTripMap() {
    return FutureBuilder<Set<Marker>>(
      future: _createCustomMarkers(),
      builder: (context, snapshot) {
        return BookingMap(
          controller: _summaryMapController,
          initialCenter: ll.LatLng(
            (_getPickupLatitude() + _getDropLatitude()) / 2,
            (_getPickupLongitude() + _getDropLongitude()) / 2,
          ),
          initialZoom: 12,
          // Cadre pickup→drop dès l'affichage (ex-fit onMapCreated).
          initialCameraFit: fm.CameraFit.bounds(
            bounds: fm.LatLngBounds(
              ll.LatLng(_getPickupLatitude(), _getPickupLongitude()),
              ll.LatLng(_getDropLatitude(), _getDropLongitude()),
            ),
            padding: const EdgeInsets.all(50),
          ),
          interactive: false, // mini-carte récap figée
          showZoomControls: false,
          children: [
            fm.PolylineLayer(
                polylines: gma.toFmPolylines(_createPolylines())),
            if (snapshot.data != null)
              fm.MarkerLayer(markers: gma.toFmMarkers(snapshot.data!)),
          ],
        );
      },
    );
  }

  // Carte d'une course terminée : trajet réel (noir) + portion couverte (corail).
  Widget _completedTripMap() {
    final List path = booking['suggestPath'] as List;

    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('path'),
        color: MyColors.blackColor,
        width: 5,
        points: List.generate(
          path.length,
          (index) =>
              LatLng(path[index]['latitude'], path[index]['longitude']),
        ),
      ),
    };
    if (booking['coveredPath'] != null) {
      final List covered = booking['coveredPath'] as List;
      polylines.add(Polyline(
        polylineId: const PolylineId('path1'),
        color: MyColors.primaryColor,
        width: 5,
        points: List.generate(
          covered.length,
          (index) => LatLng(covered[index]['lat'], covered[index]['lng']),
        ),
      ));
    }

    return Consumer<GoogleMapProvider>(
      builder: (context, mapProvider, child) => ValueListenableBuilder(
        valueListenable: bookingDetailMarker,
        builder: (context, bookingDetailMarkerValue, child) => BookingMap(
          controller: _trackMapController,
          initialCenter:
              ll.LatLng(path[0]['latitude'], path[0]['longitude']),
          initialZoom: 12.80,
          showZoomControls: false,
          interactive: false,
          // Cadre tout le trajet dès l'affichage.
          initialCameraFit: fm.CameraFit.bounds(
            bounds: fm.LatLngBounds.fromPoints(
              List.generate(
                path.length,
                (index) => ll.LatLng(
                    path[index]['latitude'], path[index]['longitude']),
              ),
            ),
            padding: const EdgeInsets.all(50),
          ),
          children: [
            fm.PolylineLayer(polylines: gma.toFmPolylines(polylines)),
            fm.MarkerLayer(markers: gma.toFmMarkers({
              Marker(
                markerId: const MarkerId('pickupPoint'),
                position:
                    LatLng(path[0]['latitude'], path[0]['longitude']),
              ),
              Marker(
                markerId: const MarkerId('dropingPoint'),
                position: LatLng(path[path.length - 1]['latitude'],
                    path[path.length - 1]['longitude']),
              ),
            })),
          ],
        ),
      ),
    );
  }

  // Conversion robuste num | String → double (Google Places renvoie parfois
  // les coordonnées en chaîne).
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // Première coordonnée non nulle parmi plusieurs noms de champs possibles.
  double _coord(List<String> keys) {
    for (final k in keys) {
      if (booking[k] != null) {
        final d = _toDouble(booking[k]);
        if (d != 0.0) return d;
      }
    }
    return 0.0;
  }

  // Vérifie si les coordonnées sont valides
  bool _hasValidCoordinates() {
    return (_getPickupLatitude() != 0 &&
        _getPickupLongitude() != 0 &&
        _getDropLatitude() != 0 &&
        _getDropLongitude() != 0);
  }

  double _getPickupLatitude() =>
      _coord(['pickupLatitude', 'pickup_latitude', 'pickLat']);

  double _getPickupLongitude() =>
      _coord(['pickupLongitude', 'pickup_longitude', 'pickLng']);

  double _getDropLatitude() =>
      _coord(['dropLatitude', 'drop_latitude', 'dropLat']);

  double _getDropLongitude() =>
      _coord(['dropLongitude', 'drop_longitude', 'dropLng']);

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
