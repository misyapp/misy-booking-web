import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

import '../contants/global_data.dart';
import '../contants/global_keys.dart';
import '../contants/my_colors.dart';
import '../contants/my_image_url.dart';
import '../contants/sized_box.dart';
import '../provider/trip_provider.dart';
import '../services/analytics/analytics_service.dart';
import '../services/airport_detection_service.dart';
import '../services/location.dart';
import '../services/share_prefrence_service.dart';
import '../widget/custom_text.dart';
import '../widget/flight_number_input.dart';
import '../widget/input_text_field_widget.dart';
import '../widget/round_edged_button.dart';
import '../widget/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'price_update_confirmation_sheet.dart';
import 'dart:math' as math;

class ConfirmDestination extends StatefulWidget {
  final PaymentMethodType paymentMethod;
  ConfirmDestination({Key? key, required this.paymentMethod}) : super(key: key);

  @override
  State<ConfirmDestination> createState() => _ConfirmDestinationState();
}

class _ConfirmDestinationState extends State<ConfirmDestination> with WidgetsBindingObserver {
  final TextEditingController pickupLocationController = TextEditingController();

  // Abandonment tracking
  DateTime? _screenOpenedAt;
  Timer? _inactivityTimer;
  bool _hasLoggedAbandonment = false;

  // Booking creation lock to prevent race condition
  bool _isCreatingBooking = false;

  // 💰 Anti-fraude : prix et position initiaux
  double? _initialTripPrice;
  LatLng? _initialPickupPosition;

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 60), () {
      if (!_hasLoggedAbandonment) {
        logConfirmationAbandonment('timeout');
      }
    });
  }

  int _getTimeSpentSeconds() {
    if (_screenOpenedAt == null) return 0;
    return DateTime.now().difference(_screenOpenedAt!).inSeconds;
  }

  Future<void> logConfirmationAbandonment(String reason) async {
    if (_hasLoggedAbandonment) return;
    _hasLoggedAbandonment = true;
    
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final userDetails = await DevFestPreferences().getUserDetails();
    
    // 🔧 FIX: Vérifier que selectedVehicle n'est pas null avant de calculer le prix
    final selectedVehicle = tripProvider.selectedVehicle;
    if (selectedVehicle == null) {
      myCustomPrintStatement('⚠️ logConfirmationAbandonment: selectedVehicle est null');
      return;
    }

    final tripPrice = tripProvider.selectedPromoCode != null
        ? tripProvider.calculatePriceAfterCouponApply()
        : tripProvider.calculatePrice(selectedVehicle);
    
    await AnalyticsService.logConfirmationAbandoned(
      timeSpentSeconds: _getTimeSpentSeconds(),
      reason: reason,
      tripPrice: tripPrice,
      paymentMethod: widget.paymentMethod.value,
      vehicleType: tripProvider.selectedVehicle?.id ?? 'unknown',
      userId: userDetails?.id,
    );
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _screenOpenedAt = DateTime.now();
    _startInactivityTimer();

    // 💰 Anti-fraude : sauvegarder le prix et la position initiaux
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeInitialPriceAndPosition();
      // 📍 Initialiser l'adresse de pickup dans le controller
      _initializePickupAddress();
    });

    super.initState();
  }

  /// Initialise l'adresse de pickup dans le controller
  void _initializePickupAddress() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final address = tripProvider.pickLocation?['address'] ?? '';
    myCustomPrintStatement('📍 _initializePickupAddress: $address');
    if (address.isNotEmpty) {
      pickupLocationController.text = address;
    }
  }

  /// Initialise le prix et la position de référence pour la détection de fraude
  void _initializeInitialPriceAndPosition() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // Sauvegarder le prix initial
    if (tripProvider.selectedVehicle != null) {
      _initialTripPrice = tripProvider.selectedPromoCode != null
          ? tripProvider.calculatePriceAfterCouponApply()
          : tripProvider.calculatePrice(tripProvider.selectedVehicle!);
      myCustomPrintStatement('💰 Prix initial sauvegardé: $_initialTripPrice Ar');
    }

    // Sauvegarder la position initiale
    if (tripProvider.pickLocation != null) {
      _initialPickupPosition = LatLng(
        tripProvider.pickLocation!['lat'],
        tripProvider.pickLocation!['lng'],
      );
      myCustomPrintStatement('📍 Position initiale sauvegardée: $_initialPickupPosition');
    }
  }

  /// 💰 Vérifie si le prix a changé et demande confirmation à l'utilisateur
  /// Retourne true si on peut continuer, false si l'utilisateur a refusé
  Future<bool> _checkPriceChangeAndConfirm(TripProvider tripProvider) async {
    // Si pas de prix initial ou pas de position initiale, continuer
    if (_initialTripPrice == null || _initialPickupPosition == null) {
      myCustomPrintStatement('💰 Pas de référence initiale, continuation...');
      return true;
    }

    // Vérifier si la position a changé significativement (> 100m)
    if (tripProvider.pickLocation == null) return true;

    final currentPosition = LatLng(
      tripProvider.pickLocation!['lat'],
      tripProvider.pickLocation!['lng'],
    );

    final distanceFromInitial = _calculateDistance(_initialPickupPosition!, currentPosition);
    myCustomPrintStatement('📍 Distance depuis position initiale: ${(distanceFromInitial * 1000).toStringAsFixed(0)}m');

    // Si déplacement < 100m, pas besoin de vérifier le prix
    if (distanceFromInitial < 0.1) {
      myCustomPrintStatement('💰 Déplacement mineur (<100m), continuation...');
      return true;
    }

    // Recalculer le prix avec la nouvelle position
    if (tripProvider.dropLocation != null && tripProvider.selectedVehicle != null) {
      // Recalculer la distance/temps pour le nouveau trajet
      final newTotalWilltake = await getTotalTimeCalculate(
        '${currentPosition.latitude},${currentPosition.longitude}',
        '${tripProvider.dropLocation!['lat']},${tripProvider.dropLocation!['lng']}',
      );

      // Vérifier si le calcul a échoué (distance = -1)
      if (newTotalWilltake.distance < 0) {
        myCustomPrintStatement('❌ Échec recalcul distance, utilisation valeur précédente');
        return true; // Continuer avec l'ancienne valeur
      }

      // Mettre à jour totalWilltake
      totalWilltake.value = newTotalWilltake;

      // Calculer le nouveau prix
      final newPrice = tripProvider.selectedPromoCode != null
          ? tripProvider.calculatePriceAfterCouponApply()
          : tripProvider.calculatePrice(tripProvider.selectedVehicle!);

      myCustomPrintStatement('💰 Prix initial: $_initialTripPrice Ar, Nouveau prix: $newPrice Ar');

      // Si le prix a changé significativement (> 100 Ar), demander confirmation
      final priceDifference = (newPrice - _initialTripPrice!).abs();
      if (priceDifference > 100) {
        myCustomPrintStatement('💰 Changement de prix significatif (+/- ${priceDifference.toStringAsFixed(0)} Ar), demande de confirmation...');

        // Afficher la bottom sheet de confirmation
        final accepted = await PriceUpdateConfirmationSheet.show(
          context,
          newPrice: newPrice,
          oldPrice: _initialTripPrice!,
        );

        if (accepted) {
          myCustomPrintStatement('💰 Nouveau prix accepté par l\'utilisateur');
          _initialTripPrice = newPrice;
          _initialPickupPosition = currentPosition;
          return true;
        } else {
          myCustomPrintStatement('💰 Nouveau prix refusé par l\'utilisateur');
          // Restaurer totalWilltake avec les valeurs initiales
          final originalTotalWilltake = await getTotalTimeCalculate(
            '${_initialPickupPosition!.latitude},${_initialPickupPosition!.longitude}',
            '${tripProvider.dropLocation!['lat']},${tripProvider.dropLocation!['lng']}',
          );
          // Seulement mettre à jour si le calcul a réussi
          if (originalTotalWilltake.distance > 0) {
            totalWilltake.value = originalTotalWilltake;
          }
          return false;
        }
      }
    }

    return true;
  }

  /// Calcule la distance en km entre deux points (formule Haversine)
  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(to.latitude - from.latitude);
    final double dLng = _toRadians(to.longitude - from.longitude);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(from.latitude)) *
            math.cos(_toRadians(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      logConfirmationAbandonment('app_backgrounded');
    }
  }

  @override
  Widget build(BuildContext context) {
    var tripProvider = Provider.of<TripProvider>(context);
    final pickupAddress = tripProvider.pickLocation?["address"] ?? '';
    myCustomPrintStatement('📍 ConfirmDestination - pickLocation: ${tripProvider.pickLocation}');
    myCustomPrintStatement('📍 ConfirmDestination - address: $pickupAddress');
    pickupLocationController.text = pickupAddress;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Log abandonment via bouton système
          await logConfirmationAbandonment('system_back_button');
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        // 📍 Hauteur fixe, pas de scroll, pas de drag - contenu statique
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicateur visuel (décoratif uniquement - pas de drag)
            Center(
              child: Container(
                height: 6,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: MyColors.colorD9D9D9Theme(),
                ),
              ),
            ),
              const SizedBox(height: 4),
              // Titre centré (bouton retour supprimé - déjà présent en haut à droite)
              Center(
                child: SubHeadingText(
                  translate("Pleasecheckyourpickuplocation"),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              // Trait de séparation gris
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 0),
                color: MyColors.colorD9D9D9Theme(),
              ),
              const SizedBox(height: 6),
              // Contenu toujours visible (pas de collapse)
              const SizedBox(height: 8),
              InputTextFieldWidget(
                      borderColor: Colors.transparent,
                      fillColor: MyColors.textFillThemeColor(),
                      controller: pickupLocationController,
                      obscureText: false,
                      readOnly: true,
                      hintcolor: MyColors.blackThemeColor(),
                      hintText: translate("pickuplocation"),
                      preffix: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Image.asset(
                          MyImagesUrl.location,
                          color: MyColors.blackThemeColor(),
                          width: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Affichage des numéros de vol si aéroport
                    if (tripProvider.pickLocation?['isAirport'] == true &&
                        tripProvider.pickLocation?['flightNumber'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FlightNumberDisplay(
                          flightNumber: tripProvider.pickLocation!['flightNumber'],
                          isPickup: true,
                          onTap: () async {
                            final url = AirportDetectionService.getFlightInfoUrl(
                              tripProvider.pickLocation!['flightNumber'],
                            );
                            if (await canLaunchUrl(Uri.parse(url))) {
                              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                    if (tripProvider.dropLocation?['isAirport'] == true &&
                        tripProvider.dropLocation?['flightNumber'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FlightNumberDisplay(
                          flightNumber: tripProvider.dropLocation!['flightNumber'],
                          isPickup: false,
                          onTap: () async {
                            final url = AirportDetectionService.getFlightInfoUrl(
                              tripProvider.dropLocation!['flightNumber'],
                            );
                            if (await canLaunchUrl(Uri.parse(url))) {
                              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
              RoundEdgedButton(
                verticalMargin: 16,
                width: double.infinity,
                text: translate("Confirm"),
                load: _isCreatingBooking,
                onTap: _isCreatingBooking ? null : () {
                  // 🔒 PROTECTION: Empêcher les clics multiples (race condition)
                  if (_isCreatingBooking) {
                    myCustomPrintStatement("⚠️ Création déjà en cours, clic ignoré");
                    return;
                  }

                  // 1. Verrouiller l'état IMMÉDIATEMENT pour feedback visuel du bouton
                  setState(() {
                    _isCreatingBooking = true;
                  });

                  // 2. Exécuter la logique async dans un Future pour ne pas bloquer le setState
                  Future.microtask(() async {
                    try {
                      // 💰 Anti-fraude : vérifier si le prix a changé
                      final priceCheckPassed = await _checkPriceChangeAndConfirm(tripProvider);
                      if (!priceCheckPassed) {
                        // L'utilisateur a refusé le nouveau prix
                        if (mounted) {
                          setState(() {
                            _isCreatingBooking = false;
                          });
                        }
                        return;
                      }

                      // 📍 Le loader est déjà affiché par le bouton (load: _isCreatingBooking)
                      // Pas besoin de showLoading() ici - évite le double loader

                      // 🔧 FIX: Sauvegarder rideScheduledTime AVANT createRequest
                      // Car resetAllExceptScheduled() dans createBooking() met rideScheduledTime = null
                      // pour les courses planifiées, ce qui causerait une race condition
                      final bool isScheduledRide = tripProvider.rideScheduledTime != null;

                      myCustomPrintStatement(
                          "🔐 Début création booking (verrouillé) - pickup: ${tripProvider.pickLocation} drop: ${tripProvider.dropLocation} time: ${tripProvider.rideScheduledTime} isScheduled: $isScheduledRide");

                      bool success = await tripProvider.createRequest(
                        vehicleDetails: tripProvider.selectedVehicle!,
                        paymentMethod: widget.paymentMethod.value,
                        pickupLocation: tripProvider.pickLocation!,
                        dropLocation: tripProvider.dropLocation!,
                        scheduleTime: tripProvider.rideScheduledTime,
                        isScheduled: isScheduledRide,
                        promocodeDetails: tripProvider.selectedPromoCode
                      );

                      // 🔧 FIX: Utiliser isScheduledRide sauvegardé au lieu de tripProvider.rideScheduledTime
                      // Car pour les courses planifiées, resetAllExceptScheduled() a déjà mis rideScheduledTime = null
                      if (success && !isScheduledRide) {
                        myCustomPrintStatement("✅ Création réussie (course immédiate), navigation vers requestForRide");
                        tripProvider.setScreen(CustomTripType.requestForRide);
                        // 🔧 FIX: Mettre à jour la hauteur du bottom sheet pour requestForRide (58%)
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (MyGlobalKeys.homePageKey.currentState != null) {
                            MyGlobalKeys.homePageKey.currentState!
                                .updateBottomSheetHeight(milliseconds: 200);
                          }
                        });
                      } else if (success) {
                        myCustomPrintStatement("✅ Course planifiée créée avec succès - retour à l'accueil (isScheduledRide=$isScheduledRide)");
                        // resetAllExceptScheduled() a déjà été appelé, pas besoin de naviguer
                      } else {
                        myCustomPrintStatement("❌ Création échouée (conflit ou erreur)");
                      }
                      // Sinon, createRequest() a déjà géré la navigation (ex: retour à selectScheduleTime)
                    } catch (e) {
                      myCustomPrintStatement("❌ Erreur lors de la création de la demande: $e");
                      showSnackbar(translate("Une erreur s'est produite. Veuillez réessayer."));
                    } finally {
                      // Déverrouiller dans tous les cas
                      if (mounted) {
                        setState(() {
                          _isCreatingBooking = false;
                        });
                        myCustomPrintStatement("🔓 Création terminée (déverrouillé)");
                      }
                    }
                  });
                },
              ),
              vSizedBox
            ],
          ),
        ),
    );
  }
}
