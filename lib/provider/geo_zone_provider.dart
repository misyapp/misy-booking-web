import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/geo_zone.dart';
import 'package:rider_ride_hailing_app/services/geo_zone_service.dart';
import 'package:rider_ride_hailing_app/modal/vehicle_modal.dart';

/// Provider pour gérer les zones géographiques et leurs configurations
class GeoZoneProvider extends ChangeNotifier {
  List<GeoZone> _zones = [];
  GeoZone? _currentZone; // Zone actuelle basée sur la position de départ
  bool _isLoading = false;
  String? _error;

  // Getters
  List<GeoZone> get zones => _zones;
  GeoZone? get currentZone => _currentZone;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCurrentZone => _currentZone != null;

  /// Initialise le provider et charge les zones
  Future<void> initialize() async {
    if (_zones.isNotEmpty) return; // Déjà initialisé

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _zones = await GeoZoneService.getZones();
      myCustomPrintStatement("GeoZoneProvider: ${_zones.length} zones chargées");
    } catch (e) {
      _error = "Erreur de chargement des zones: $e";
      myCustomPrintStatement(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Met à jour la zone actuelle basée sur les coordonnées de départ
  /// [forceRefresh] permet de forcer le rechargement depuis Firestore
  Future<void> updateCurrentZone(double latitude, double longitude, {bool forceRefresh = false}) async {
    try {
      myCustomPrintStatement('🗺️ GeoZoneProvider.updateCurrentZone($latitude, $longitude, forceRefresh: $forceRefresh)');

      // S'assurer que les zones sont chargées ou forcer le rafraîchissement
      if (_zones.isEmpty || forceRefresh) {
        myCustomPrintStatement('   → Chargement des zones depuis Firestore (zones vides: ${_zones.isEmpty}, forceRefresh: $forceRefresh)');
        if (forceRefresh) {
          await refreshZones();
        } else {
          await initialize();
        }
      }

      myCustomPrintStatement('   → ${_zones.length} zones disponibles après chargement');

      _currentZone = await GeoZoneService.getZoneForLocation(latitude, longitude);

      // Synchroniser avec le service pour accès statique dans TripProvider
      GeoZoneService.currentZone = _currentZone;

      if (_currentZone != null) {
        myCustomPrintStatement(
            "✅ Zone actuelle: ${_currentZone!.name} (priorité: ${_currentZone!.priority})");
        myCustomPrintStatement(
            "   → Pricing config: ${_currentZone!.pricing != null ? 'Oui' : 'Non'}");
        myCustomPrintStatement(
            "   → Category config: ${_currentZone!.categoryConfig != null ? 'Oui' : 'Non'}");
        myCustomPrintStatement(
            "   → Commission config: ${_currentZone!.commissionConfig != null ? 'Oui' : 'Non'}");
        if (_currentZone!.commissionConfig != null) {
          myCustomPrintStatement(
              "   → Commission défaut zone: ${_currentZone!.commissionConfig!.defaultCommission ?? 'Non définie'}%");
          if (_currentZone!.commissionConfig!.categoryOverrides != null) {
            myCustomPrintStatement(
                "   → Overrides catégories: ${_currentZone!.commissionConfig!.categoryOverrides!.keys.toList()}");
          }
        }
        if (_currentZone!.categoryConfig?.disabledCategories != null) {
          myCustomPrintStatement(
              "   → Catégories désactivées: ${_currentZone!.categoryConfig!.disabledCategories}");
        }
      } else {
        myCustomPrintStatement("⚠️ Aucune zone spécifique - utilisation des tarifs par défaut");
      }

      notifyListeners();
    } catch (e, stack) {
      myCustomPrintStatement("❌ Erreur lors de la mise à jour de la zone: $e");
      myCustomPrintStatement("   Stack: $stack");
    }
  }

  /// Réinitialise la zone actuelle (ex: quand l'utilisateur annule un trajet)
  void clearCurrentZone() {
    _currentZone = null;
    GeoZoneService.currentZone = null; // Synchroniser avec le service
    notifyListeners();
  }

  /// Force le rafraîchissement des zones depuis Firestore
  Future<void> refreshZones() async {
    _isLoading = true;
    notifyListeners();

    try {
      _zones = await GeoZoneService.refreshZones();
      myCustomPrintStatement("GeoZoneProvider: Zones rafraîchies (${_zones.length})");
    } catch (e) {
      _error = "Erreur de rafraîchissement: $e";
      myCustomPrintStatement(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // TARIFICATION
  // ============================================

  /// Applique les tarifs de zone à un véhicule
  /// Retourne un nouveau VehicleModal avec les prix ajustés
  VehicleModal applyZonePricing(VehicleModal vehicle) {
    if (_currentZone?.pricing == null) {
      return vehicle; // Pas de zone ou pas de pricing spécifique
    }

    final pricing = _currentZone!.pricing!;

    // Vérifier s'il y a un override spécifique pour ce véhicule
    final vehicleOverride = pricing.vehicleOverrides?[vehicle.id];

    double newBasePrice = vehicle.basePrice;
    double newPerKmCharge = vehicle.price;
    double newPerMinCharge = vehicle.perMinCharge;
    double newWaitingTimeFee = vehicle.waitingTimeFee;

    if (vehicleOverride != null) {
      // Appliquer les overrides spécifiques au véhicule
      newBasePrice = vehicleOverride.basePrice ??
          (vehicle.basePrice * (vehicleOverride.basePriceMultiplier ?? 1.0));
      newPerKmCharge = vehicleOverride.perKmCharge ??
          (vehicle.price * (vehicleOverride.perKmMultiplier ?? 1.0));
      newPerMinCharge = vehicleOverride.perMinCharge ??
          (vehicle.perMinCharge * (vehicleOverride.perMinMultiplier ?? 1.0));
    } else {
      // Appliquer les multiplicateurs globaux de la zone
      newBasePrice = pricing.applyToBasePrice(vehicle.basePrice);
      newPerKmCharge = pricing.applyToPerKm(vehicle.price);
      newPerMinCharge = pricing.applyToPerMin(vehicle.perMinCharge);
      newWaitingTimeFee = pricing.applyToWaitingTime(vehicle.waitingTimeFee);
    }

    // Créer une nouvelle instance avec les prix ajustés
    return VehicleModal(
      image: vehicle.image,
      name: vehicle.name,
      otherCategory: vehicle.otherCategory,
      price: newPerKmCharge,
      basePrice: newBasePrice,
      marker: vehicle.marker,
      id: vehicle.id,
      shortNote: vehicle.shortNote,
      sequence: vehicle.sequence,
      perMinCharge: newPerMinCharge,
      active: vehicle.active,
      discount: vehicle.discount,
      selected: vehicle.selected,
      persons: vehicle.persons,
      waitingTimeFee: newWaitingTimeFee,
      isFeatured: vehicle.isFeatured,
    );
  }

  /// Applique les tarifs de zone à une liste de véhicules
  List<VehicleModal> applyZonePricingToList(List<VehicleModal> vehicles) {
    if (_currentZone?.pricing == null) {
      return vehicles;
    }
    return vehicles.map((v) => applyZonePricing(v)).toList();
  }

  /// Calcule le prix total ajusté pour un trajet
  /// [atTime] permet de spécifier l'heure pour le calcul du multiplicateur de trafic (défaut: maintenant)
  double calculateAdjustedPrice({
    required double basePrice,
    required double distance, // en km
    required double duration, // en minutes
    required double perKmCharge,
    required double perMinCharge,
    String? vehicleId,
    DateTime? atTime,
  }) {
    if (_currentZone?.pricing == null) {
      // Calcul standard sans ajustement de zone
      return basePrice + (distance * perKmCharge) + (duration * perMinCharge);
    }

    final pricing = _currentZone!.pricing!;
    VehiclePricingOverride? vehicleOverride;
    if (vehicleId != null && pricing.vehicleOverrides != null) {
      vehicleOverride = pricing.vehicleOverrides![vehicleId];
    }

    double adjustedBasePrice;
    double adjustedPerKm;
    double adjustedPerMin;

    if (vehicleOverride != null) {
      adjustedBasePrice = vehicleOverride.basePrice ??
          (basePrice * (vehicleOverride.basePriceMultiplier ?? 1.0));
      adjustedPerKm = vehicleOverride.perKmCharge ??
          (perKmCharge * (vehicleOverride.perKmMultiplier ?? 1.0));
      adjustedPerMin = vehicleOverride.perMinCharge ??
          (perMinCharge * (vehicleOverride.perMinMultiplier ?? 1.0));
    } else {
      adjustedBasePrice = pricing.applyToBasePrice(basePrice);
      adjustedPerKm = pricing.applyToPerKm(perKmCharge);
      adjustedPerMin = pricing.applyToPerMin(perMinCharge);
    }

    double total = adjustedBasePrice + (distance * adjustedPerKm) + (duration * adjustedPerMin);

    // Appliquer le multiplicateur de trafic de la zone si applicable
    final trafficMultiplier = pricing.getCurrentTrafficMultiplier(atTime: atTime);
    if (trafficMultiplier != 1.0) {
      myCustomPrintStatement('🚦 Application multiplicateur trafic zone: x$trafficMultiplier');
      total *= trafficMultiplier;
    }

    // Appliquer le minimum si défini
    if (pricing.minimumFare != null && total < pricing.minimumFare!) {
      total = pricing.minimumFare!;
    }

    return total;
  }

  /// Obtient le multiplicateur de trafic actuel pour la zone courante
  /// Retourne 1.0 si aucune zone ou aucun multiplicateur défini
  double getCurrentTrafficMultiplier({DateTime? atTime}) {
    if (_currentZone?.pricing == null) return 1.0;
    return _currentZone!.pricing!.getCurrentTrafficMultiplier(atTime: atTime);
  }

  /// Obtient la période de trafic active pour la zone courante
  TrafficPeriod? getActiveTrafficPeriod({DateTime? atTime}) {
    if (_currentZone?.pricing == null) return null;
    return _currentZone!.pricing!.getActiveTrafficPeriod(atTime: atTime);
  }

  // ============================================
  // CATÉGORIES DE VÉHICULES
  // ============================================

  /// Filtre et trie les véhicules selon la configuration de zone
  List<VehicleModal> applyCategoryConfig(List<VehicleModal> vehicles) {
    myCustomPrintStatement('🚗 applyCategoryConfig - Zone actuelle: ${_currentZone?.name ?? "aucune"}');

    if (_currentZone?.categoryConfig == null) {
      myCustomPrintStatement('   → Pas de config de catégories, retour des véhicules non filtrés');
      return vehicles;
    }

    final config = _currentZone!.categoryConfig!;
    List<VehicleModal> result = List.from(vehicles);

    myCustomPrintStatement('   → Config trouvée:');
    myCustomPrintStatement('      disabledCategories: ${config.disabledCategories}');
    myCustomPrintStatement('      featuredCategories: ${config.featuredCategories}');
    myCustomPrintStatement('      categoryOrder: ${config.categoryOrder}');
    myCustomPrintStatement('      defaultCategory: ${config.defaultCategory}');

    // 1. Filtrer les catégories désactivées
    if (config.disabledCategories != null && config.disabledCategories!.isNotEmpty) {
      myCustomPrintStatement('   → Filtrage des catégories désactivées...');
      for (var v in vehicles) {
        final isAvailable = config.isCategoryAvailable(v.id);
        myCustomPrintStatement('      ${v.name} (id: "${v.id}"): ${isAvailable ? "✅ disponible" : "❌ désactivé"}');
      }
      result = result.where((v) => config.isCategoryAvailable(v.id)).toList();
      myCustomPrintStatement('   → ${result.length} véhicules après filtrage (${vehicles.length - result.length} exclus)');
    }

    // 2. Mettre à jour le flag isFeatured selon la zone
    if (config.featuredCategories != null && config.featuredCategories!.isNotEmpty) {
      result = result.map((v) {
        if (config.isCategoryFeatured(v.id)) {
          return VehicleModal(
            image: v.image,
            name: v.name,
            otherCategory: v.otherCategory,
            price: v.price,
            basePrice: v.basePrice,
            marker: v.marker,
            id: v.id,
            shortNote: v.shortNote,
            sequence: v.sequence,
            perMinCharge: v.perMinCharge,
            active: v.active,
            discount: v.discount,
            selected: v.selected,
            persons: v.persons,
            waitingTimeFee: v.waitingTimeFee,
            isFeatured: true,
          );
        }
        return v;
      }).toList();
    }

    // 3. Trier selon l'ordre personnalisé si défini
    if (config.categoryOrder != null && config.categoryOrder!.isNotEmpty) {
      result.sort((a, b) {
        int indexA = config.categoryOrder!.indexOf(a.id);
        int indexB = config.categoryOrder!.indexOf(b.id);

        // Si pas dans la liste, mettre à la fin avec l'ordre par défaut (sequence)
        if (indexA == -1 && indexB == -1) {
          return a.sequence.compareTo(b.sequence);
        }
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;

        return indexA.compareTo(indexB);
      });
    }

    return result;
  }

  /// Retourne l'ID de la catégorie par défaut pour la zone actuelle
  String? getDefaultCategoryId() {
    return _currentZone?.categoryConfig?.defaultCategory;
  }

  /// Vérifie si une catégorie est disponible dans la zone actuelle
  bool isCategoryAvailable(String categoryId) {
    if (_currentZone?.categoryConfig == null) return true;
    return _currentZone!.categoryConfig!.isCategoryAvailable(categoryId);
  }

  /// Vérifie si une catégorie est mise en avant dans la zone actuelle
  bool isCategoryFeatured(String categoryId) {
    if (_currentZone?.categoryConfig == null) return false;
    return _currentZone!.categoryConfig!.isCategoryFeatured(categoryId);
  }

  // ============================================
  // COMMISSION
  // ============================================

  /// Obtient le taux de commission effectif pour une catégorie de véhicule
  /// Fallback: categoryOverride -> zoneDefault -> globalSettings.adminCommission
  ///
  /// [vehicleId] - ID Firestore du véhicule
  /// [categoryName] - Nom normalisé de la catégorie (ex: "classic", "confort")
  /// [globalDefault] - Taux de commission global par défaut (généralement 15.0)
  ///
  /// Retourne un record avec le taux et la source pour l'audit trail
  ({double rate, String source, String? zoneId, String? zoneName})
      getEffectiveCommissionRate({
    required String vehicleId,
    String? categoryName,
    required double globalDefault,
  }) {
    // Si pas de zone courante ou pas de config commission, utiliser le global
    if (_currentZone?.commissionConfig == null) {
      return (
        rate: globalDefault,
        source: 'global_default',
        zoneId: null,
        zoneName: null,
      );
    }

    final config = _currentZone!.commissionConfig!;

    // Chercher par ID puis par nom de catégorie
    final zoneRate = config.getCommissionForCategory(
      vehicleId,
      categoryName: categoryName,
    );

    if (zoneRate != null) {
      // Déterminer si c'est un override de catégorie ou le défaut de zone
      final isOverride =
          config.categoryOverrides?.containsKey(vehicleId) == true ||
              (categoryName != null &&
                  config.categoryOverrides?.containsKey(categoryName) == true);

      myCustomPrintStatement(
          '💰 Commission zone "${_currentZone!.name}": $zoneRate% (${isOverride ? "override catégorie" : "défaut zone"})');

      return (
        rate: zoneRate,
        source: isOverride ? 'zone_category_override' : 'zone_default',
        zoneId: _currentZone!.id,
        zoneName: _currentZone!.name,
      );
    }

    // Fallback sur le global
    myCustomPrintStatement(
        '💰 Commission: utilisation du taux global $globalDefault%');
    return (
      rate: globalDefault,
      source: 'global_default',
      zoneId: null,
      zoneName: null,
    );
  }

  /// Version simple retournant uniquement le taux
  double getCommissionRate({
    required String vehicleId,
    String? categoryName,
    required double globalDefault,
  }) {
    return getEffectiveCommissionRate(
      vehicleId: vehicleId,
      categoryName: categoryName,
      globalDefault: globalDefault,
    ).rate;
  }

  /// Vérifie si la zone actuelle a une configuration de commission
  bool get hasCommissionConfig => _currentZone?.commissionConfig != null;

  // ============================================
  // UTILITAIRES
  // ============================================

  /// Retourne un résumé des ajustements de la zone actuelle
  Map<String, dynamic> getCurrentZoneSummary({DateTime? atTime}) {
    if (_currentZone == null) {
      return {'hasZone': false, 'message': 'Tarifs standard'};
    }

    final pricing = _currentZone!.pricing;
    final activeTrafficPeriod = pricing?.getActiveTrafficPeriod(atTime: atTime);
    final currentTrafficMultiplier = pricing?.getCurrentTrafficMultiplier(atTime: atTime) ?? 1.0;

    return {
      'hasZone': true,
      'zoneName': _currentZone!.name,
      'zoneDescription': _currentZone!.description,
      'hasPricingAdjustments': pricing != null,
      'hasCategoryConfig': _currentZone!.categoryConfig != null,
      'basePriceMultiplier': pricing?.basePriceMultiplier ?? 1.0,
      'perKmMultiplier': pricing?.perKmMultiplier ?? 1.0,
      'minimumFare': pricing?.minimumFare,
      'trafficMultiplier': pricing?.trafficMultiplier,
      'currentTrafficMultiplier': currentTrafficMultiplier,
      'hasActiveTrafficPeriod': activeTrafficPeriod != null,
      'activeTrafficPeriodName': activeTrafficPeriod?.name,
      'trafficPeriodsCount': pricing?.trafficPeriods?.length ?? 0,
    };
  }
}
