/// Modèle représentant le résultat détaillé d'un calcul de prix de course
/// 
/// Ce modèle contient tous les composants du calcul (prix de base, majorations,
/// réductions) ainsi que les métadonnées permettant la traçabilité et l'affichage.
/// 
/// Supporte les versions V1 (système legacy) et V2 (nouveau système).
/// 
/// Exemple d'usage :
/// ```dart
/// final result = PriceCalculation.v2(
///   vehicleCategory: 'classic',
///   distance: 10.0,
///   isScheduled: true,
///   basePrice: 27500,
///   trafficSurcharge: 11000,
///   reservationSurcharge: 5000,
///   promoDiscount: 0,
///   finalPrice: 43500,
/// );
/// 
/// print(result.formattedFinalPrice); // "43500 MGA"
/// print(result.formattedBreakdown);  // Détail du calcul
/// ```
class PriceCalculation {
  /// Prix de base calculé selon la distance et la catégorie
  final double basePrice;
  
  /// Majoration pour embouteillages (0 si pas applicable)
  final double trafficSurcharge;

  /// Surcoût de réservation (0 si course immédiate)
  final double reservationSurcharge;

  /// Réduction appliquée par code promo (0 si aucun code)
  final double promoDiscount;
  
  /// Prix final après arrondis
  final double finalPrice;
  
  /// Détails techniques du calcul pour debug et traçabilité
  final Map<String, dynamic> breakdown;
  
  /// Version du système de tarification utilisé ("v1.0" ou "v2.0")
  final String pricingVersion;
  
  /// Timestamp du calcul
  final DateTime calculatedAt;
  
  /// Catégorie de véhicule utilisée pour le calcul
  final String vehicleCategory;
  
  /// Distance en kilomètres
  final double distance;
  
  /// True si c'est une course programmée, false si immédiate
  final bool isScheduled;
  
  const PriceCalculation({
    required this.basePrice,
    required this.trafficSurcharge,
    required this.reservationSurcharge,
    required this.promoDiscount,
    required this.finalPrice,
    required this.breakdown,
    required this.pricingVersion,
    required this.calculatedAt,
    required this.vehicleCategory,
    required this.distance,
    required this.isScheduled,
  });
  
  /// Factory pour créer un calcul avec le nouveau système V2
  /// 
  /// Génère automatiquement le breakdown détaillé et les métadonnées.
  /// 
  /// [vehicleCategory] Catégorie du véhicule (taxi_moto, classic, etc.)
  /// [distance] Distance en kilomètres
  /// [isScheduled] True si course programmée
  /// [basePrice] Prix de base calculé
  /// [trafficSurcharge] Majoration embouteillages
  /// [reservationSurcharge] Surcoût réservation
  /// [promoDiscount] Réduction promo appliquée
  /// [finalPrice] Prix final après arrondis
  /// [additionalBreakdown] Informations supplémentaires pour le breakdown
  factory PriceCalculation.v2({
    required String vehicleCategory,
    required double distance,
    required bool isScheduled,
    required double basePrice,
    required double trafficSurcharge,
    required double reservationSurcharge,
    required double promoDiscount,
    required double finalPrice,
    Map<String, dynamic>? additionalBreakdown,
  }) {
    // Déterminer la formule utilisée selon la distance
    String formula;
    if (distance < 3) {
      formula = 'floor_price';
    } else if (distance < 15) {
      formula = 'linear';
    } else {
      formula = 'long_trip';
    }
    
    final breakdown = {
      'formula': formula,
      'baseCalculation': {
        'distance': distance,
        'basePrice': basePrice,
      },
      'surcharges': {
        'traffic': trafficSurcharge,
        'reservation': reservationSurcharge,
      },
      'discounts': {
        'promo': promoDiscount,
      },
      'rounding': {
        'beforeRounding': basePrice + trafficSurcharge + reservationSurcharge - promoDiscount,
        'afterRounding': finalPrice,
      },
      ...?additionalBreakdown,
    };

    return PriceCalculation(
      basePrice: basePrice,
      trafficSurcharge: trafficSurcharge,
      reservationSurcharge: reservationSurcharge,
      promoDiscount: promoDiscount,
      finalPrice: finalPrice,
      breakdown: breakdown,
      pricingVersion: "v2.0",
      calculatedAt: DateTime.now(),
      vehicleCategory: vehicleCategory,
      distance: distance,
      isScheduled: isScheduled,
    );
  }
  
  /// Factory pour créer un calcul avec l'ancien système V1 (legacy)
  /// 
  /// Utilisé pour encapsuler les résultats de l'ancien système dans
  /// le nouveau format pour maintenir la compatibilité.
  /// 
  /// [vehicleCategory] Catégorie du véhicule
  /// [distance] Distance en kilomètres
  /// [isScheduled] True si course programmée
  /// [finalPrice] Prix calculé par l'ancien système
  factory PriceCalculation.v1({
    required String vehicleCategory,
    required double distance,
    required bool isScheduled,
    required double finalPrice,
  }) {
    return PriceCalculation(
      basePrice: finalPrice,
      trafficSurcharge: 0,
      reservationSurcharge: 0,
      promoDiscount: 0,
      finalPrice: finalPrice,
      breakdown: {
        'legacyCalculation': true,
        'note': 'Calculation performed by legacy pricing system',
      },
      pricingVersion: "v1.0",
      calculatedAt: DateTime.now(),
      vehicleCategory: vehicleCategory,
      distance: distance,
      isScheduled: isScheduled,
    );
  }

  /// Total des majorations appliquées
  double get totalSurcharges => trafficSurcharge + reservationSurcharge;
  
  /// Prix net avant arrondis (base + majorations - réductions)
  double get netPrice => basePrice + totalSurcharges - promoDiscount;
  
  /// True si une majoration embouteillages a été appliquée
  bool get hasTrafficSurcharge => trafficSurcharge > 0;
  
  /// True si un surcoût de réservation a été appliqué
  bool get hasReservationSurcharge => reservationSurcharge > 0;

  /// True si une réduction promo a été appliquée
  bool get hasPromoDiscount => promoDiscount > 0;
  
  /// True si le calcul a été effectué avec le nouveau système V2
  bool get isV2Calculation => pricingVersion == "v2.0";
  
  /// Prix final formaté pour affichage
  /// 
  /// Format : "43500 MGA"
  String get formattedFinalPrice => '${finalPrice.toStringAsFixed(0)} MGA';
  
  /// Breakdown formaté pour affichage utilisateur
  /// 
  /// Génère une chaîne multi-lignes détaillant le calcul :
  /// - Prix de base
  /// - Majorations (si applicables)
  /// - Réductions (si applicables)  
  /// - Prix final
  String get formattedBreakdown {
    if (!isV2Calculation) {
      return 'Prix calculé : $formattedFinalPrice';
    }
    
    var result = 'Prix de base : ${basePrice.toStringAsFixed(0)} MGA';
    
    if (hasTrafficSurcharge) {
      result += '\nMajoration embouteillages : +${trafficSurcharge.toStringAsFixed(0)} MGA';
    }
    
    if (hasReservationSurcharge) {
      result += '\nSurcoût réservation : +${reservationSurcharge.toStringAsFixed(0)} MGA';
    }
    
    if (hasPromoDiscount) {
      result += '\nRéduction promo : -${promoDiscount.toStringAsFixed(0)} MGA';
    }
    
    result += '\nPrix final : $formattedFinalPrice';
    
    return result;
  }
  
  /// Breakdown technique détaillé pour debug
  /// 
  /// Affiche toutes les informations techniques du calcul
  /// incluant les métadonnées et les calculs intermédiaires.
  String get technicalBreakdown {
    final buffer = StringBuffer();
    buffer.writeln('=== CALCUL DE PRIX ===');
    buffer.writeln('Version: $pricingVersion');
    buffer.writeln('Véhicule: $vehicleCategory');
    buffer.writeln('Distance: ${distance}km');
    buffer.writeln('Programmé: ${isScheduled ? "Oui" : "Non"}');
    buffer.writeln('Calculé le: ${calculatedAt.toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('COMPOSANTS:');
    buffer.writeln('- Prix de base: ${basePrice.toStringAsFixed(0)} MGA');
    buffer.writeln('- Majoration embouteillages: ${trafficSurcharge.toStringAsFixed(0)} MGA');
    buffer.writeln('- Surcoût réservation: ${reservationSurcharge.toStringAsFixed(0)} MGA');
    buffer.writeln('- Réduction promo: ${promoDiscount.toStringAsFixed(0)} MGA');
    buffer.writeln('- Prix net: ${netPrice.toStringAsFixed(0)} MGA');
    buffer.writeln('- Prix final (arrondi): ${finalPrice.toStringAsFixed(0)} MGA');
    
    if (breakdown.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('BREAKDOWN TECHNIQUE:');
      breakdown.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
    }
    
    return buffer.toString();
  }
  
  /// Sérialisation vers JSON
  Map<String, dynamic> toJson() {
    return {
      'basePrice': basePrice,
      'trafficSurcharge': trafficSurcharge,
      'reservationSurcharge': reservationSurcharge,
      'promoDiscount': promoDiscount,
      'finalPrice': finalPrice,
      'breakdown': breakdown,
      'pricingVersion': pricingVersion,
      'calculatedAt': calculatedAt.toIso8601String(),
      'vehicleCategory': vehicleCategory,
      'distance': distance,
      'isScheduled': isScheduled,
    };
  }
  
  /// Désérialisation depuis JSON
  factory PriceCalculation.fromJson(Map<String, dynamic> json) {
    return PriceCalculation(
      basePrice: (json['basePrice'] ?? 0.0).toDouble(),
      trafficSurcharge: (json['trafficSurcharge'] ?? 0.0).toDouble(),
      reservationSurcharge: (json['reservationSurcharge'] ?? 0.0).toDouble(),
      promoDiscount: (json['promoDiscount'] ?? 0.0).toDouble(),
      finalPrice: (json['finalPrice'] ?? 0.0).toDouble(),
      breakdown: Map<String, dynamic>.from(json['breakdown'] ?? {}),
      pricingVersion: json['pricingVersion'] ?? "unknown",
      calculatedAt: DateTime.parse(json['calculatedAt']),
      vehicleCategory: json['vehicleCategory'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      isScheduled: json['isScheduled'] ?? false,
    );
  }
  
  /// Validation des données
  /// 
  /// Vérifie la cohérence du calcul et la validité des données
  bool isValid() {
    // Prix et composants doivent être positifs ou nuls
    if (basePrice < 0 || trafficSurcharge < 0 || 
        reservationSurcharge < 0 || promoDiscount < 0 || finalPrice < 0) {
      return false;
    }
    
    // Distance doit être positive
    if (distance <= 0) {
      return false;
    }
    
    // Catégorie de véhicule doit être valide
    final validCategories = ['taxi_moto', 'classic', 'confort', '4x4', 'van'];
    if (!validCategories.contains(vehicleCategory)) {
      return false;
    }
    
    // Pour les calculs V2, vérifier la cohérence des prix
    if (isV2Calculation) {
      final expectedNet = basePrice + totalSurcharges - promoDiscount;
      // Tolérance de 250 MGA due aux arrondis
      if ((finalPrice - expectedNet).abs() > 250) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Création d'une copie avec modifications
  PriceCalculation copyWith({
    double? basePrice,
    double? trafficSurcharge,
    double? reservationSurcharge,
    double? promoDiscount,
    double? finalPrice,
    Map<String, dynamic>? breakdown,
    String? pricingVersion,
    DateTime? calculatedAt,
    String? vehicleCategory,
    double? distance,
    bool? isScheduled,
  }) {
    return PriceCalculation(
      basePrice: basePrice ?? this.basePrice,
      trafficSurcharge: trafficSurcharge ?? this.trafficSurcharge,
      reservationSurcharge: reservationSurcharge ?? this.reservationSurcharge,
      promoDiscount: promoDiscount ?? this.promoDiscount,
      finalPrice: finalPrice ?? this.finalPrice,
      breakdown: breakdown ?? this.breakdown,
      pricingVersion: pricingVersion ?? this.pricingVersion,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      distance: distance ?? this.distance,
      isScheduled: isScheduled ?? this.isScheduled,
    );
  }
  
  @override
  String toString() {
    return 'PriceCalculation(${pricingVersion}, ${vehicleCategory}, ${distance}km, ${finalPrice.toStringAsFixed(0)} MGA)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is PriceCalculation &&
           other.basePrice == basePrice &&
           other.trafficSurcharge == trafficSurcharge &&
           other.reservationSurcharge == reservationSurcharge &&
           other.promoDiscount == promoDiscount &&
           other.finalPrice == finalPrice &&
           other.pricingVersion == pricingVersion &&
           other.vehicleCategory == vehicleCategory &&
           other.distance == distance &&
           other.isScheduled == isScheduled;
  }
  
  @override
  int get hashCode {
    return basePrice.hashCode ^
           trafficSurcharge.hashCode ^
           reservationSurcharge.hashCode ^
           promoDiscount.hashCode ^
           finalPrice.hashCode ^
           pricingVersion.hashCode ^
           vehicleCategory.hashCode ^
           distance.hashCode ^
           isScheduled.hashCode;
  }
}