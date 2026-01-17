// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/extenstions/payment_type_etxtenstion.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';
import 'package:rider_ride_hailing_app/provider/promocodes_provider.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/services/location.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import '../contants/my_colors.dart';
import '../contants/sized_box.dart';
import '../provider/trip_provider.dart';
import '../provider/geo_zone_provider.dart';
import '../services/analytics/analytics_service.dart';
import '../widget/custom_text.dart';
import '../widget/round_edged_button.dart';

// ignore: must_be_immutable
class ChooseVehicle extends StatefulWidget {
  final Function(VehicleModal) onTap;
  final Map pickLocation;
  final Map drpLocation;
  final bool isCollapsed; // Position basse : afficher uniquement la catégorie sélectionnée
  final bool enableScroll; // Scroll activé uniquement en position maximale (85%)
  const ChooseVehicle(
      {Key? key,
      required this.onTap,
      required this.pickLocation,
      required this.drpLocation,
      this.isCollapsed = false,
      this.enableScroll = false})
      : super(key: key);

  @override
  State<ChooseVehicle> createState() => _ChooseVehicleState();
}

class _ChooseVehicleState extends State<ChooseVehicle> with WidgetsBindingObserver {
  final ValueNotifier<int> selectedVehicleIndexNoti = ValueNotifier(-1);
  final ValueNotifier<bool> showPrice = ValueNotifier(false);

  // 💳 Mode de paiement sélectionné (par défaut Espèces)
  PaymentMethodType _selectedPaymentMethod = PaymentMethodType.cash;

  bool selected = false;
  DateTime? _screenOpenedAt;
  Timer? _inactivityTimer;
  bool _hasLoggedAbandonment = false;

  // 🗺️ Liste des véhicules filtrée et triée selon la zone géographique
  List<VehicleModal> _zoneFilteredVehicles = [];

  /// 🗺️ Initialise la zone géographique et applique les configurations
  Future<void> _initializeGeoZone() async {
    try {
      final geoZoneProvider = Provider.of<GeoZoneProvider>(context, listen: false);

      final pickLat = double.parse(widget.pickLocation['lat'].toString());
      final pickLng = double.parse(widget.pickLocation['lng'].toString());

      myCustomPrintStatement('🗺️ ====== INITIALISATION GEO ZONE ======');
      myCustomPrintStatement('🗺️ Position pickup: ($pickLat, $pickLng)');

      // IMPORTANT: Forcer le rafraîchissement pour charger les nouvelles zones
      // Cela garantit que les zones nouvellement créées sont toujours disponibles
      await geoZoneProvider.updateCurrentZone(pickLat, pickLng, forceRefresh: true);

      myCustomPrintStatement('🗺️ Zones disponibles après refresh: ${geoZoneProvider.zones.length}');
      for (var zone in geoZoneProvider.zones) {
        myCustomPrintStatement('   📍 ${zone.name} (priority: ${zone.priority}, points: ${zone.polygon.length})');
        if (zone.polygon.isNotEmpty) {
          final latMin = zone.polygon.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
          final latMax = zone.polygon.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
          final lngMin = zone.polygon.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
          final lngMax = zone.polygon.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
          myCustomPrintStatement('      Bounds: lat[$latMin - $latMax], lng[$lngMin - $lngMax]');
        }
        if (zone.categoryConfig?.disabledCategories != null) {
          myCustomPrintStatement('      Catégories désactivées: ${zone.categoryConfig!.disabledCategories}');
        }
      }

      // Appliquer les configurations de zone aux véhicules
      myCustomPrintStatement('🗺️ Application des configurations de zone...');
      myCustomPrintStatement('   Véhicules avant filtrage: ${vehicleListModal.length}');
      for (var v in vehicleListModal) {
        myCustomPrintStatement('      - ${v.name} (id: ${v.id}, active: ${v.active})');
      }

      _zoneFilteredVehicles = geoZoneProvider.applyCategoryConfig(vehicleListModal);
      myCustomPrintStatement('   Après applyCategoryConfig: ${_zoneFilteredVehicles.length} véhicules');

      _zoneFilteredVehicles = geoZoneProvider.applyZonePricingToList(_zoneFilteredVehicles);
      myCustomPrintStatement('   Après applyZonePricing: ${_zoneFilteredVehicles.length} véhicules');

      if (geoZoneProvider.hasCurrentZone) {
        final zone = geoZoneProvider.currentZone!;
        myCustomPrintStatement('🗺️ ✅ Zone détectée: ${zone.name}');
        myCustomPrintStatement('   Pricing: baseMultiplier=${zone.pricing?.basePriceMultiplier}, kmMultiplier=${zone.pricing?.perKmMultiplier}');
        myCustomPrintStatement('   CategoryOrder: ${zone.categoryConfig?.categoryOrder}');
        myCustomPrintStatement('   DisabledCategories: ${zone.categoryConfig?.disabledCategories}');
        myCustomPrintStatement('   Véhicules après filtrage: ${_zoneFilteredVehicles.length}/${vehicleListModal.length}');

        // Log les prix ajustés
        myCustomPrintStatement('   Prix ajustés par zone:');
        for (var v in _zoneFilteredVehicles) {
          myCustomPrintStatement('      ${v.name}: basePrice=${v.basePrice}, perKm=${v.price}, active=${v.active}');
        }
      } else {
        myCustomPrintStatement('🗺️ ⚠️ Aucune zone spécifique - tarifs par défaut');
        _zoneFilteredVehicles = List.from(vehicleListModal);
      }

      myCustomPrintStatement('🗺️ ====== FIN INITIALISATION GEO ZONE ======');
      if (mounted) setState(() {});
    } catch (e, stack) {
      myCustomPrintStatement('❌ Erreur initialisation zone géographique: $e');
      myCustomPrintStatement('   Stack: $stack');
      _zoneFilteredVehicles = List.from(vehicleListModal);
    }
  }

  /// 🗺️ Retourne la liste des véhicules (filtrée par zone si disponible)
  List<VehicleModal> get displayedVehicles =>
      _zoneFilteredVehicles.isNotEmpty ? _zoneFilteredVehicles : vehicleListModal;

  // Log Analytics pour l'affichage des prix
  void _logPricesDisplayed() {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    
    // Log pour chaque véhicule actif avec prix
    for (final vehicle in vehicleListModal) {
      if (vehicle.active) {
        final price = tripProvider.calculatePriceForVehicle(vehicle, 
            withReservation: tripProvider.rideScheduledTime != null);
        
        AnalyticsService.logPriceDisplayed(
          price: price,
          distanceKm: totalWilltake.value.distance,
          durationMin: totalWilltake.value.time.toDouble(),
        );
        
        // Log un seul event groupé pour éviter le spam
        break;
      }
    }
  }

  // Tracking abandonment
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 60), () {
      if (!_hasLoggedAbandonment) {
        logVehicleAbandonment('timeout');
      }
    });
  }

  void _resetInactivityTimer() {
    if (!_hasLoggedAbandonment) {
      _startInactivityTimer();
    }
  }

  int _getTimeSpentSeconds() {
    if (_screenOpenedAt == null) return 0;
    return DateTime.now().difference(_screenOpenedAt!).inSeconds;
  }

  Future<void> logVehicleAbandonment(String reason) async {
    if (_hasLoggedAbandonment) return;
    _hasLoggedAbandonment = true;
    
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final userDetails = await DevFestPreferences().getUserDetails();
    
    // Calculer prix min/max des véhicules disponibles
    double? cheapest;
    double? mostExpensive;
    int availableCount = 0;
    
    for (final vehicle in vehicleListModal) {
      if (vehicle.active) {
        availableCount++;
        final price = tripProvider.calculatePriceForVehicle(vehicle, 
            withReservation: tripProvider.rideScheduledTime != null);
        
        if (cheapest == null || price < cheapest) cheapest = price;
        if (mostExpensive == null || price > mostExpensive) mostExpensive = price;
      }
    }
    
    await AnalyticsService.logVehicleSelectionAbandoned(
      timeSpentSeconds: _getTimeSpentSeconds(),
      reason: reason,
      cheapestPriceViewed: cheapest,
      mostExpensivePriceViewed: mostExpensive,
      vehiclesAvailable: availableCount,
      userId: userDetails?.id,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      logVehicleAbandonment('app_backgrounded');
    }
  }

  /// 🚦 Indicateur visuel de majoration pendant les heures de pointe
  Widget _buildTrafficSurchargeIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MyColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MyColors.warning.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MyColors.warning.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.traffic_rounded,
              color: MyColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('trafficSurchargeActive'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MyColors.blackThemeColor(),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  translate('trafficSurchargeInfo'),
                  style: TextStyle(
                    fontSize: 11,
                    color: MyColors.blackThemeColorWithOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    // Setup abandonment tracking
    WidgetsBinding.instance.addObserver(this);
    _screenOpenedAt = DateTime.now();
    _startInactivityTimer();

    // 💳 Charger le dernier mode de paiement utilisé
    _loadLastPaymentMethod();

    // 🗺️ Initialiser la zone géographique (tarifs et catégories personnalisés)
    // Utiliser addPostFrameCallback pour éviter d'appeler notifyListeners pendant la construction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGeoZone().then((_) {
        // 🚗 Auto-sélectionner la catégorie mise en avant (featured) APRÈS le chargement de zone
        _autoSelectFeaturedVehicle();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      showPrice.value = false;
      showLoading();
      totalWilltake.value = await getTotalTimeCalculate(
          "${widget.pickLocation['lat']}, ${widget.pickLocation['lng']}",
          "${widget.drpLocation['lat']}, ${widget.drpLocation['lng']}");

      nearestVehicleLatLng.forEach((key, value) async {
        String driverPos = "${nearestVehicleLatLng[key]!.latitude}, ${nearestVehicleLatLng[key]!.longitude}";
        String pickupPos = "${widget.pickLocation['lat']}, ${widget.pickLocation['lng']}";
        myCustomPrintStatement('🚗 Calcul temps pour véhicule $key: Chauffeur($driverPos) → Pickup($pickupPos)');

        nearestDriverTime.value[key] = await getTotalTimeCalculate(driverPos, pickupPos);
        myCustomPrintStatement('⏰ Résultat véhicule $key: ${nearestDriverTime.value[key]?.time} minutes');
        nearestDriverTime.notifyListeners();
      });
      showPrice.value = true;
      hideLoading();
      myCustomPrintStatement(
          "Total estimated travel time :${totalWilltake.value.time}  --- distnace :${totalWilltake.value.distance}");

      // Log Analytics event quand les prix sont affichés
      _logPricesDisplayed();
    });

    super.initState();
  }

  /// 💳 Charge le dernier mode de paiement utilisé depuis les préférences
  Future<void> _loadLastPaymentMethod() async {
    final lastPaymentMethod = await DevFestPreferences().getLastPaymentMethodSelected();
    if (lastPaymentMethod.isNotEmpty) {
      setState(() {
        _selectedPaymentMethod = PaymentMethodTypeExtension.fromValue(lastPaymentMethod);
      });
    }
    // Mettre à jour le ValueNotifier global également
    selectPayMethod.value = _selectedPaymentMethod;
  }

  /// 🚗 Auto-sélectionne la catégorie mise en avant (featured) depuis Firebase ou zone
  void _autoSelectFeaturedVehicle() {
    final vehicles = displayedVehicles; // Utilise la liste filtrée par zone
    final geoZoneProvider = Provider.of<GeoZoneProvider>(context, listen: false);

    // 1. Vérifier si la zone a une catégorie par défaut
    final defaultCategoryId = geoZoneProvider.getDefaultCategoryId();
    if (defaultCategoryId != null) {
      for (int i = 0; i < vehicles.length; i++) {
        if (vehicles[i].id == defaultCategoryId && vehicles[i].active) {
          selectedVehicleIndexNoti.value = i;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final tripProvider = Provider.of<TripProvider>(context, listen: false);
            tripProvider.selectedVehicle = vehicles[i];
            Provider.of<PromocodesProvider>(context, listen: false)
                .filterPromocodes(vehicles[i], tripProvider.calculatePrice(vehicles[i]));
          });
          myCustomPrintStatement('🗺️ Auto-sélection catégorie par défaut de zone: ${vehicles[i].name}');
          return;
        }
      }
    }

    // 2. Chercher la catégorie "featured" parmi les véhicules actifs
    for (int i = 0; i < vehicles.length; i++) {
      if (vehicles[i].active && vehicles[i].isFeatured) {
        selectedVehicleIndexNoti.value = i;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final tripProvider = Provider.of<TripProvider>(context, listen: false);
          tripProvider.selectedVehicle = vehicles[i];
          Provider.of<PromocodesProvider>(context, listen: false)
              .filterPromocodes(vehicles[i], tripProvider.calculatePrice(vehicles[i]));
        });
        myCustomPrintStatement('🌟 Auto-sélection catégorie featured: ${vehicles[i].name}');
        return;
      }
    }

    // 3. Si aucune catégorie featured, sélectionner la première catégorie active
    for (int i = 0; i < vehicles.length; i++) {
      if (vehicles[i].active) {
        selectedVehicleIndexNoti.value = i;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final tripProvider = Provider.of<TripProvider>(context, listen: false);
          tripProvider.selectedVehicle = vehicles[i];
          Provider.of<PromocodesProvider>(context, listen: false)
              .filterPromocodes(vehicles[i], tripProvider.calculatePrice(vehicles[i]));
        });
        myCustomPrintStatement('🚗 Auto-sélection première catégorie active: ${vehicles[i].name}');
        return;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  /// 💳 Affiche le sélecteur de mode de paiement (agrandi)
  Widget _buildPaymentMethodSelector() {
    return GestureDetector(
      onTap: () {
        _showPaymentMethodBottomSheet();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MyColors.colorD9D9D9Theme().withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icône du mode de paiement (agrandi)
            Image.asset(
              _getPaymentMethodIcon(_selectedPaymentMethod),
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 14),
            // Texte du mode de paiement (agrandi)
            Expanded(
              child: SubHeadingText(
                _selectedPaymentMethod.value,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            // Flèche pour indiquer de cliquer
            Icon(
              Icons.chevron_right,
              color: MyColors.blackThemeColorWithOpacity(0.6),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  /// Retourne l'icône correspondant au mode de paiement
  String _getPaymentMethodIcon(PaymentMethodType paymentType) {
    switch (paymentType) {
      case PaymentMethodType.cash:
        return MyImagesUrl.cashIcon;
      case PaymentMethodType.wallet:
        return MyImagesUrl.wallet;
      case PaymentMethodType.airtelMoney:
        return MyImagesUrl.airtelMoneyIcon;
      case PaymentMethodType.orangeMoney:
        return MyImagesUrl.orangeMoneyIcon;
      case PaymentMethodType.telmaMvola:
        return MyImagesUrl.telmaMvolaIcon;
      case PaymentMethodType.creditCard:
        return MyImagesUrl.bankCardIcon;
    }
  }

  /// Affiche le bottom sheet de sélection du mode de paiement
  void _showPaymentMethodBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MyColors.whiteThemeColor(),
      isScrollControlled: true, // Permet une hauteur plus grande
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PaymentMethodSelectorSheet(
        selectedMethod: _selectedPaymentMethod,
        showPromoSection: selectedVehicleIndexNoti.value != -1,
        onSelect: (method) async {
          setState(() {
            _selectedPaymentMethod = method;
          });
          selectPayMethod.value = method;
          // Sauvegarder le choix de l'utilisateur
          await DevFestPreferences().setLastPaymentMethodSelected(method.value);
          if (ctx.mounted) {
            Navigator.pop(ctx);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Log abandonment via bouton système
          await logVehicleAbandonment('system_back_button');
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: ValueListenableBuilder(
        valueListenable: sheetShowNoti,
        builder: (context, sheetValue, child) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trait gris centré (indicateur drag)
            const SizedBox(height: 8),
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: MyColors.colorD9D9D9Theme(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Titre centré
            Center(
              child: SubHeadingText(
                translate('chooseYourRide'),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            // Trait de séparation gris
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: MyColors.colorD9D9D9Theme(),
            ),
            const SizedBox(height: 6),

            // 🚦 Indicateur de majoration désactivé - le prix affiché inclut déjà la majoration
            // if (pricingConfigV2 != null &&
            //     pricingConfigV2!.enableNewPricingSystem &&
            //     pricingConfigV2!.isTrafficTime(DateTime.now()))
            //   _buildTrafficSurchargeIndicator(),

            if (sheetValue)
              // Zone scrollable pour les catégories
              // Expanded pour que le footer reste en bas du bottom sheet
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: totalWilltake,
                  builder: (context, totalTime, child) =>
                      ValueListenableBuilder(
                    valueListenable: nearestDriverTime,
                    builder:
                        (context, nearestDriverTimeValue, child) =>
                            Scrollbar(
                              thumbVisibility: !widget.isCollapsed,
                              thickness: 4,
                              radius: const Radius.circular(2),
                              child: ValueListenableBuilder(
                                valueListenable: selectedVehicleIndexNoti,
                                builder: (context, selectedIdx, _) {
                                  // En mode collapsed, afficher seulement le véhicule sélectionné
                                  final itemsToShow = widget.isCollapsed && selectedIdx >= 0
                                      ? [selectedIdx]
                                      : List.generate(displayedVehicles.length, (i) => i);

                                  // Animation de transition entre liste complète et catégorie sélectionnée
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    switchInCurve: Curves.easeInOut,
                                    switchOutCurve: Curves.easeInOut,
                                    transitionBuilder: (Widget child, Animation<double> animation) {
                                      // Animation de slide vertical + fade
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0.0, -0.1),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: ListView.builder(
                                    // Clé unique pour déclencher l'animation UNIQUEMENT lors du changement collapsed/expanded
                                    // Ne pas inclure selectedIdx pour éviter le freeze lors du changement de catégorie
                                    key: ValueKey('vehicle_list_${widget.isCollapsed}'),
                                    // Scroll activé uniquement en position maximale (85%)
                                    physics: widget.enableScroll
                                        ? const AlwaysScrollableScrollPhysics()
                                        : const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: globalHorizontalPadding),
                                    itemCount: itemsToShow.length,
                                  itemBuilder: (context, listIdx) {
                                    final index = itemsToShow[listIdx];
                                    final vehicle = displayedVehicles[index];
                                    String availableCategotyTimeId =
                                        vehicle.id;
                                    if (nearestDriverTimeValue[
                                            availableCategotyTimeId] ==
                                        null) {
                                      for (int i = 0;
                                          i <
                                              vehicle
                                                  .otherCategory
                                                  .length;
                                          i++) {
                                        if (nearestDriverTimeValue
                                            .containsKey(
                                                vehicle
                                                    .otherCategory[i])) {
                                          availableCategotyTimeId =
                                              vehicle
                                                  .otherCategory[i];
                                          break;
                                        }
                                      }
                                    }
                                    return ValueListenableBuilder(
                                      valueListenable:
                                          selectedVehicleIndexNoti,
                                      builder: (context, value, child) {
                                        return vehicle
                                                    .active ==
                                                false
                                            ? Container()
                                            : GestureDetector(
                                                onTap: () {
                                                  // Reset timer d'inactivité lors d'interaction
                                                  _resetInactivityTimer();

                                                  selectedVehicleIndexNoti
                                                      .value = index;
                                                    var trip =  Provider.of<TripProvider>(
                                                              context,
                                                              listen: false);
                                                  Provider.of<PromocodesProvider>(
                                                          context,
                                                          listen: false)
                                                      .filterPromocodes(
                                                          vehicle
                                                          , trip.calculatePrice( vehicle) );
                                                  trip
                                                          .selectedVehicle =
                                                      vehicle;
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets
                                                      .only(bottom: 6),
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 8),
                                                  decoration:
                                                      BoxDecoration(
                                                    // Pas de fond - juste la bordure pour l'élément sélectionné
                                                    color: Colors.transparent,
                                                    // Bordure uniquement pour l'élément sélectionné (pas de bordure grise pour les autres)
                                                    border: value == index
                                                        ? Border.all(
                                                            color: const Color(0xffFF5357),
                                                            width: 2,
                                                          )
                                                        : null,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(10),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      CachedNetworkImage(
                                                        imageUrl: vehicle.image,
                                                        width:
                                                            index != value
                                                                ? 65
                                                                : 75,
                                                        height:
                                                            index != value
                                                                ? 65
                                                                : 75,
                                                        fit: BoxFit.fill,
                                                        placeholder: (context, url) => SizedBox(
                                                          width: index != value ? 65 : 75,
                                                          height: index != value ? 65 : 75,
                                                        ),
                                                        errorWidget: (context, url, error) => Icon(
                                                          Icons.directions_car,
                                                          size: index != value ? 40 : 50,
                                                          color: MyColors.colorD9D9D9Theme(),
                                                        ),
                                                      ),
                                                      hSizedBox,
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  child:
                                                                      Row(
                                                                    // Toujours aligné à gauche (pas de centrage)
                                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                                    children: [
                                                                      SubHeadingText(
                                                                        vehicle.name,
                                                                        fontWeight: value == index ? FontWeight.w600 : FontWeight.w500,
                                                                        color: value == index ? MyColors.blackThemeColor() : null,
                                                                        fontSize: value == index ? 15 : 13, // Plus gros quand sélectionné
                                                                      ),
                                                                      hSizedBox02,
                                                                      Icon(Icons.person,
                                                                          size: 16,
                                                                          color: value == index ? MyColors.blackThemeColor() : null),
                                                                      SubHeadingText(vehicle.persons.toString(),
                                                                          fontWeight: FontWeight.w500,
                                                                          fontSize: 13,
                                                                          color: value == index ? MyColors.blackThemeColor() : null),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Consumer<
                                                                    TripProvider>(
                                                                  builder: (context,
                                                                          tripProvider,
                                                                          child) =>
                                                                      ValueListenableBuilder(
                                                                    valueListenable:
                                                                        showPrice,
                                                                    builder: (context, showPriceValue, child) => !showPriceValue
                                                                        ? Container()
                                                                        : Column(
                                                                            children: [
                                                                              if (vehicle.discount > 0 || (vehicle.id == "02b2988097254a04859a" && (userData.value?.extraDiscount ?? 0) > 0 && globalSettings.enableTaxiExtraDiscount))
                                                                                SubHeadingText(
                                                                                    '${globalSettings.currency} ${formatAriary(
                                                                                      tripProvider.calculatePriceForVehicle(vehicle, withReservation: tripProvider.rideScheduledTime != null),
                                                                                    )}',
                                                                                    fontWeight: index != value ? FontWeight.w600 : FontWeight.bold,
                                                                                    fontSize: index != value ? 13 : 14,
                                                                                    color: value == index ? MyColors.blackThemeColor() : null),
                                                                              SubHeadingText('${globalSettings.currency} ${formatAriary(tripProvider.calculatePriceForVehicle(vehicle, withReservation: tripProvider.rideScheduledTime != null))}',
                                                                                  fontWeight: index != value ? FontWeight.w600 : FontWeight.bold,
                                                                                  decoration: vehicle.discount > 0 || (vehicle.id == "02b2988097254a04859a" && (userData.value?.extraDiscount ?? 0) > 0 && globalSettings.enableTaxiExtraDiscount) ? TextDecoration.lineThrough : null,
                                                                                  fontSize: vehicle.discount > 0 || (vehicle.id == "02b2988097254a04859a" && (userData.value?.extraDiscount ?? 0) > 0 && globalSettings.enableTaxiExtraDiscount)
                                                                                      ? 11
                                                                                      : index != value
                                                                                          ? 13
                                                                                          : 14,
                                                                                  color: value == index ? MyColors.blackThemeColor() : null),
                                                                            ],
                                                                          ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            if (minVehicleDistance[availableCategotyTimeId] == null)
                                                              SubHeadingText(
                                                                translate("Notavailableinyourlocation"),
                                                                fontWeight: FontWeight.w300,
                                                                color: MyColors.blackThemeColor(),
                                                                fontSize: 11,
                                                              ),
                                                            if (nearestDriverTimeValue[availableCategotyTimeId] != null)
                                                              SubHeadingText(
                                                                "${(nearestDriverTimeValue[availableCategotyTimeId]!.time)} ${translate("minutesaway")}",
                                                                fontWeight: FontWeight.w300,
                                                                color: MyColors.blackThemeColor(),
                                                                fontSize: 11,
                                                              ),
                                                            // Afficher la description (shortNote) si:
                                                            // - En position max (enableScroll=true) pour toutes les catégories
                                                            // - OU si la catégorie est sélectionnée
                                                            if (vehicle.shortNote.isNotEmpty && (widget.enableScroll || value == index))
                                                              ParagraphText(
                                                                vehicle.shortNote,
                                                                fontWeight: FontWeight.w300,
                                                                fontSize: 11,
                                                                maxLines: 2,
                                                                color: MyColors.blackThemeColor(),
                                                                textOverflow: TextOverflow.ellipsis,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                      },
                                    );
                                  }),
                                  );  // Fin AnimatedSwitcher
                                },
                              ),
                            ),
                  ),
                ),
              ),
            // Section toujours visible en bas avec divider et bouton
            Container(
              color: MyColors.bottomSheetBackgroundColor(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(
                    thickness: 0.4,
                    height: 1,
                  ),
                  vSizedBox05,
                  // Afficher l'heure de réservation si programmée
                  Consumer<TripProvider>(
                    builder: (context, tripProvider, child) {
                      if (tripProvider.rideScheduledTime == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.watch_later,
                              color: MyColors.primaryColor,
                              size: 20,
                            ),
                            hSizedBox05,
                            ParagraphText(
                              DateFormat("EEE, d MMM HH:mm").format(tripProvider.rideScheduledTime!),
                              fontSize: 12,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // 💳 Sélecteur de mode de paiement (agrandi)
                  _buildPaymentMethodSelector(),
                  vSizedBox05,
                  Consumer<TripProvider>(
                    builder: (context, tripProvider, child) => ValueListenableBuilder(
                      valueListenable: selectedVehicleIndexNoti,
                      builder: (context, selectedVehicle, child) => RoundEdgedButton(
                        horizontalMargin: 20,
                        width: double.infinity,
                        verticalMargin: 0,
                        text:
                            "${tripProvider.rideScheduledTime == null ? translate("Choose") : translate("Reserve")} ${selectedVehicle == -1 ? "" : displayedVehicles[selectedVehicle].name}",
                        onTap: () async {
                          if (selectedVehicleIndexNoti.value == -1) {
                            showSnackbar(translate("Selectvehicletype"));
                            return;
                          }
                          // Utiliser le mode de paiement sélectionné dans l'UI
                          selectPayMethod.value = _selectedPaymentMethod;
                          // Sauvegarder le choix de l'utilisateur
                          await DevFestPreferences()
                              .setLastPaymentMethodSelected(_selectedPaymentMethod.value);

                          widget.onTap(
                              displayedVehicles[selectedVehicleIndexNoti.value]);
                        },
                      ),
                    ),
                  ),
                  vSizedBox,
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// 💳 Bottom sheet de sélection du mode de paiement avec codes promo intégrés
class _PaymentMethodSelectorSheet extends StatefulWidget {
  final PaymentMethodType selectedMethod;
  final Function(PaymentMethodType) onSelect;
  final bool showPromoSection;

  const _PaymentMethodSelectorSheet({
    required this.selectedMethod,
    required this.onSelect,
    this.showPromoSection = true,
  });

  @override
  State<_PaymentMethodSelectorSheet> createState() => _PaymentMethodSelectorSheetState();
}

class _PaymentMethodSelectorSheetState extends State<_PaymentMethodSelectorSheet> {
  bool _showPromoCodeView = false;
  bool _showPromoCodeInput = false;
  final TextEditingController _promoCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Liste des modes de paiement disponibles avec Portefeuille
    final paymentMethods = [
      {'type': PaymentMethodType.cash, 'icon': MyImagesUrl.cashIcon, 'name': translate('cashPaymentName')},
      {'type': PaymentMethodType.wallet, 'icon': MyImagesUrl.wallet, 'name': translate('misyWalletPayment')},
      {'type': PaymentMethodType.telmaMvola, 'icon': MyImagesUrl.telmaMvolaIcon, 'name': translate('mvolaPayment')},
      {'type': PaymentMethodType.airtelMoney, 'icon': MyImagesUrl.airtelMoneyIcon, 'name': translate('airtelMoneyPayment')},
      {'type': PaymentMethodType.orangeMoney, 'icon': MyImagesUrl.orangeMoneyIcon, 'name': translate('orangeMoneyPayment')},
    ];

    return Consumer<AdminSettingsProvider>(
      builder: (context, adminProvider, child) {
        return Container(
          // Limiter la hauteur max à 70% de l'écran
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicateur de tiroir
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: MyColors.colorD9D9D9Theme(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Afficher soit la vue paiement, soit la vue promo
                if (_showPromoCodeView)
                  _buildPromoCodeView(context)
                else
                  _buildPaymentMethodsView(context, paymentMethods, adminProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Vue des modes de paiement
  Widget _buildPaymentMethodsView(BuildContext context, List<Map<String, dynamic>> paymentMethods, AdminSettingsProvider adminProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubHeadingText(
          translate('SelectPaymentMethod'),
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        const SizedBox(height: 16),
        // Liste des modes de paiement
        ...paymentMethods.map((method) {
          final paymentType = method['type'] as PaymentMethodType;
          final isSelected = widget.selectedMethod == paymentType;
          final discount = adminProvider.getPaymentPromoDiscount(paymentType);
          final hasPromo = discount > 0 && adminProvider.isPaymentPromoActive();

          return GestureDetector(
            onTap: () => widget.onSelect(paymentType),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? MyColors.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: MyColors.primaryColor, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Image.asset(
                    method['icon'] as String,
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SubHeadingText(
                              method['name'] as String,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 15,
                            ),
                            if (hasPromo) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MyColors.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '-${discount.toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (hasPromo)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              translate('discountOnPaymentMethod'),
                              style: TextStyle(
                                fontSize: 11,
                                color: MyColors.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: MyColors.primaryColor,
                      size: 24,
                    ),
                ],
              ),
            ),
          );
        }),
        // Bouton Ajouter un code promo
        if (widget.showPromoSection) ...[
          const Divider(height: 24),
          GestureDetector(
            onTap: () {
              setState(() {
                _showPromoCodeView = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: MyColors.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: MyColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    MyImagesUrl.promoCodeIcon,
                    height: 28,
                    width: 28,
                    color: MyColors.primaryColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SubHeadingText(
                      translate("Apply Promocode"),
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: MyColors.primaryColor,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: MyColors.primaryColor,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  /// Vue des codes promo
  Widget _buildPromoCodeView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header avec bouton retour
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showPromoCodeView = false;
                  _showPromoCodeInput = false;
                  _promoCodeController.clear();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MyColors.colorD9D9D9Theme(),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: MyColors.blackThemeColor(),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SubHeadingText(
                translate("Available Promo Codes"),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Liste des codes promo disponibles
        Consumer2<PromocodesProvider, TripProvider>(
          builder: (context, promocodesProvider, tripProvider, child) {
            final filteredPromocodes = promocodesProvider.filteredPromocodes;

            if (filteredPromocodes.isEmpty) {
              return Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 48,
                          color: MyColors.colorD9D9D9Theme(),
                        ),
                        const SizedBox(height: 12),
                        ParagraphText(
                          translate("No Promocodes available..."),
                          color: MyColors.textSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }

            return Column(
              children: [
                // Grille des codes promo
                ...filteredPromocodes.take(4).map((promo) {
                  final isSelected = tripProvider.selectedPromoCode?.id == promo.id;
                  return GestureDetector(
                    onTap: () {
                      tripProvider.selectedPromoCode = promo;
                      tripProvider.notifyListeners();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? MyColors.primaryColor.withOpacity(0.1)
                            : MyColors.textFillThemeColor(),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: MyColors.primaryColor, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: MyColors.redColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SubHeadingText(
                              "${promo.discountPercent}%",
                              color: MyColors.redColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ParagraphText(
                                  promo.description.isNotEmpty
                                      ? promo.description
                                      : "${promo.discountPercent}% ${translate("Off")}",
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  maxLines: 1,
                                ),
                                ParagraphText(
                                  "${translate("Max discount")} : ${formatAriary(promo.maxRideAmount)} ${globalSettings.currency}",
                                  fontSize: 11,
                                  color: MyColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: MyColors.primaryColor,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            );
          },
        ),

        // Section entrée de code promo
        if (_showPromoCodeInput) ...[
          const Divider(height: 24),
          SubHeadingText(
            translate("Enter promo code"),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          const SizedBox(height: 8),
          Form(
            key: _formKey,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: MyColors.textFillThemeColor(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _promoCodeController,
                      decoration: InputDecoration(
                        hintText: translate("Enter promo code"),
                        hintStyle: TextStyle(color: MyColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<PromocodesProvider>(
                  builder: (context, promocodes, child) => ElevatedButton(
                    onPressed: () {
                      if (_promoCodeController.text.isNotEmpty) {
                        promocodes.applyForPromocode(code: _promoCodeController.text);
                        _promoCodeController.clear();
                        setState(() {
                          _showPromoCodeInput = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(
                      translate('Ajouter'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Bouton pour afficher le champ de saisie
          const Divider(height: 24),
          GestureDetector(
            onTap: () {
              setState(() {
                _showPromoCodeInput = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: MyColors.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: MyColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: MyColors.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  SubHeadingText(
                    translate("Ajouter un code promo"),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: MyColors.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],

        // Bouton Appliquer
        const SizedBox(height: 16),
        Consumer<TripProvider>(
          builder: (context, tripProvider, child) {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Fermer et retourner à la vue paiement
                  setState(() {
                    _showPromoCodeView = false;
                    _showPromoCodeInput = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  tripProvider.selectedPromoCode != null
                      ? translate("Appliquer")
                      : translate("Continuer sans code"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
