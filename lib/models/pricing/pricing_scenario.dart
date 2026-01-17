import 'promo_code.dart';

/// Modèle représentant les paramètres d'entrée pour le calcul de prix d'une course
/// 
/// Encapsule toutes les informations nécessaires au calcul :
/// - Catégorie de véhicule
/// - Distance du trajet
/// - Moment de la demande (pour détecter les embouteillages)
/// - Type de course (immédiate ou programmée)
/// - Code promo éventuel
/// 
/// Exemple d'usage :
/// ```dart
/// final scenario = PricingScenario(
///   vehicleCategory: 'classic',
///   distance: 8.5,
///   requestTime: DateTime(2025, 1, 6, 17, 30), // Lundi 17h30
///   isScheduled: false,
/// );
/// 
/// print(scenario.isWeekday); // true
/// print(scenario.isValid()); // true
/// ```
class PricingScenario {
  /// Catégorie de véhicule demandée
  /// Valeurs possibles : taxi_moto, classic, confort, 4x4, van
  final String vehicleCategory;
  
  /// Distance du trajet en kilomètres
  final double distance;
  
  /// Moment de la demande de course
  /// Utilisé pour détecter les créneaux d'embouteillages
  final DateTime requestTime;
  
  /// True si la course est programmée à l'avance, false si immédiate
  final bool isScheduled;
  
  /// Code promotionnel éventuel à appliquer
  final PromoCode? promoCode;
  
  const PricingScenario({
    required this.vehicleCategory,
    required this.distance,
    required this.requestTime,
    required this.isScheduled,
    this.promoCode,
  });
  
  /// Factory pour créer un scénario de course immédiate
  /// 
  /// [vehicleCategory] Catégorie du véhicule
  /// [distance] Distance en kilomètres
  /// [promoCode] Code promo optionnel
  factory PricingScenario.immediate({
    required String vehicleCategory,
    required double distance,
    PromoCode? promoCode,
  }) {
    return PricingScenario(
      vehicleCategory: vehicleCategory,
      distance: distance,
      requestTime: DateTime.now(),
      isScheduled: false,
      promoCode: promoCode,
    );
  }
  
  /// Factory pour créer un scénario de course programmée
  /// 
  /// [vehicleCategory] Catégorie du véhicule
  /// [distance] Distance en kilomètres
  /// [scheduledTime] Heure programmée de la course
  /// [promoCode] Code promo optionnel
  factory PricingScenario.scheduled({
    required String vehicleCategory,
    required double distance,
    required DateTime scheduledTime,
    PromoCode? promoCode,
  }) {
    return PricingScenario(
      vehicleCategory: vehicleCategory,
      distance: distance,
      requestTime: scheduledTime,
      isScheduled: true,
      promoCode: promoCode,
    );
  }
  
  /// True si la demande est effectuée en semaine (Lundi-Vendredi)
  bool get isWeekday => requestTime.weekday <= 5;
  
  /// True si la demande est effectuée le weekend (Samedi-Dimanche)
  bool get isWeekend => !isWeekday;
  
  /// Heure de la demande (0-23)
  int get hourOfDay => requestTime.hour;
  
  /// True si la demande est effectuée la nuit (avant 6h ou après 22h)
  bool get isNightTime => hourOfDay < 6 || hourOfDay > 22;
  
  /// True si la demande est effectuée en journée (6h-22h)
  bool get isDayTime => !isNightTime;
  
  /// Jour de la semaine (1=Lundi, 7=Dimanche)
  int get dayOfWeek => requestTime.weekday;
  
  /// Nom du jour de la semaine
  String get dayName {
    const days = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return days[dayOfWeek];
  }
  
  /// True si un code promo est présent et valide pour ce scénario
  bool get hasValidPromoCode {
    if (promoCode == null) return false;
    // Note: On ne peut pas calculer le prix de base ici, donc on assume 1.0
    // La validation complète se fera dans le service de calcul
    return promoCode!.isValid(1.0, vehicleCategory);
  }
  
  /// Validation complète du scénario
  /// 
  /// Vérifie que tous les paramètres sont cohérents :
  /// - Catégorie de véhicule valide
  /// - Distance positive et raisonnable
  /// - Date de demande cohérente
  bool isValid() {
    // Vérifier la catégorie de véhicule
    final validCategories = ['taxi_moto', 'classic', 'confort', '4x4', 'van'];
    if (!validCategories.contains(vehicleCategory)) {
      return false;
    }
    
    // Vérifier la distance
    if (distance <= 0 || distance > 200) { // Limite raisonnable à 200km
      return false;
    }
    
    // Vérifier que la date n'est pas trop ancienne ou future
    final now = DateTime.now();
    final maxPastDays = 1; // Maximum 1 jour dans le passé
    final maxFutureDays = 30; // Maximum 30 jours dans le futur
    
    if (requestTime.isBefore(now.subtract(Duration(days: maxPastDays))) ||
        requestTime.isAfter(now.add(Duration(days: maxFutureDays)))) {
      return false;
    }
    
    // Pour les courses programmées, vérifier qu'elles sont dans le futur
    if (isScheduled && requestTime.isBefore(now.add(Duration(minutes: 5)))) {
      return false;
    }
    
    return true;
  }
  
  /// Classification de la distance
  /// 
  /// Retourne une chaîne décrivant le type de course selon la distance
  String get distanceCategory {
    if (distance < 3) return 'Courte distance';
    if (distance < 10) return 'Distance moyenne';
    if (distance < 20) return 'Longue distance';
    return 'Très longue distance';
  }
  
  /// Classification temporelle
  /// 
  /// Retourne une chaîne décrivant le moment de la demande
  String get timeCategory {
    if (isNightTime) return 'Nuit';
    if (hourOfDay < 12) return 'Matin';
    if (hourOfDay < 18) return 'Après-midi';
    return 'Soirée';
  }
  
  /// Résumé du scénario pour affichage
  String get summary {
    var parts = <String>[
      vehicleCategory,
      '${distance.toStringAsFixed(1)}km',
      isScheduled ? 'programmée' : 'immédiate',
    ];
    
    if (promoCode != null) {
      parts.add('promo: ${promoCode!.code}');
    }
    
    return parts.join(', ');
  }
  
  /// Description détaillée du scénario
  String get detailedDescription {
    final buffer = StringBuffer();
    buffer.writeln('Scénario de course :');
    buffer.writeln('- Véhicule : $vehicleCategory');
    buffer.writeln('- Distance : ${distance.toStringAsFixed(1)}km ($distanceCategory)');
    buffer.writeln('- Moment : ${dayName} ${requestTime.hour}h${requestTime.minute.toString().padLeft(2, '0')} ($timeCategory)');
    buffer.writeln('- Type : ${isScheduled ? "Programmée" : "Immédiate"}');
    
    if (promoCode != null) {
      buffer.writeln('- Code promo : ${promoCode!.code} (${promoCode!.description})');
    }
    
    return buffer.toString();
  }
  
  /// Sérialisation vers JSON
  Map<String, dynamic> toJson() {
    return {
      'vehicleCategory': vehicleCategory,
      'distance': distance,
      'requestTime': requestTime.toIso8601String(),
      'isScheduled': isScheduled,
      'promoCode': promoCode?.toJson(),
    };
  }
  
  /// Désérialisation depuis JSON
  factory PricingScenario.fromJson(Map<String, dynamic> json) {
    return PricingScenario(
      vehicleCategory: json['vehicleCategory'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      requestTime: DateTime.parse(json['requestTime']),
      isScheduled: json['isScheduled'] ?? false,
      promoCode: json['promoCode'] != null 
          ? PromoCode.fromJson(json['promoCode']) 
          : null,
    );
  }
  
  /// Création d'une copie avec modifications
  PricingScenario copyWith({
    String? vehicleCategory,
    double? distance,
    DateTime? requestTime,
    bool? isScheduled,
    PromoCode? promoCode,
    bool clearPromoCode = false,
  }) {
    return PricingScenario(
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      distance: distance ?? this.distance,
      requestTime: requestTime ?? this.requestTime,
      isScheduled: isScheduled ?? this.isScheduled,
      promoCode: clearPromoCode ? null : (promoCode ?? this.promoCode),
    );
  }
  
  /// Supprime le code promo du scénario
  PricingScenario withoutPromoCode() {
    return copyWith(clearPromoCode: true);
  }
  
  /// Ajoute ou remplace le code promo
  PricingScenario withPromoCode(PromoCode promoCode) {
    return copyWith(promoCode: promoCode);
  }
  
  /// Convertit en course immédiate
  PricingScenario asImmediate() {
    return copyWith(
      requestTime: DateTime.now(),
      isScheduled: false,
    );
  }
  
  /// Convertit en course programmée
  PricingScenario asScheduled(DateTime scheduledTime) {
    return copyWith(
      requestTime: scheduledTime,
      isScheduled: true,
    );
  }
  
  @override
  String toString() {
    return 'PricingScenario($vehicleCategory, ${distance}km, ${requestTime.toString().substring(0, 16)}, scheduled: $isScheduled)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is PricingScenario &&
           other.vehicleCategory == vehicleCategory &&
           other.distance == distance &&
           other.requestTime == requestTime &&
           other.isScheduled == isScheduled &&
           other.promoCode == promoCode;
  }
  
  @override
  int get hashCode {
    return vehicleCategory.hashCode ^
           distance.hashCode ^
           requestTime.hashCode ^
           isScheduled.hashCode ^
           promoCode.hashCode;
  }
}