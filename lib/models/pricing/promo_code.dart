/// Modèle représentant un code promotionnel pour les courses
/// 
/// Supporte deux types de réductions :
/// - Pourcentage : réduction en % du prix total
/// - Montant fixe : réduction d'un montant fixe en MGA
/// 
/// Inclut des règles de validation :
/// - Date d'expiration
/// - Montant minimum requis
/// - Catégories de véhicules autorisées
/// 
/// Exemple d'usage :
/// ```dart
/// final promoCode = PromoCode(
///   code: "WELCOME10",
///   type: PromoType.percentage,
///   value: 10.0, // 10%
///   validUntil: DateTime(2025, 12, 31),
///   minAmount: 5000.0,
/// );
/// 
/// final discount = promoCode.calculateDiscount(25000, 'classic');
/// print(discount); // 2500.0 (10% de 25000)
/// ```
class PromoCode {
  /// Code promo saisi par l'utilisateur (ex: "WELCOME10", "SAVE5000")
  final String code;
  
  /// Type de réduction : pourcentage ou montant fixe
  final PromoType type;
  
  /// Valeur de la réduction
  /// - Si type = percentage : valeur en % (ex: 10.0 pour 10%)
  /// - Si type = fixedAmount : valeur en MGA (ex: 5000.0 pour 5000 MGA)
  final double value;
  
  /// Date limite de validité (optionnel)
  /// Si null, le code n'expire jamais
  final DateTime? validUntil;
  
  /// Montant minimum requis pour appliquer le code (MGA)
  /// Si null, aucun minimum requis
  final double? minAmount;
  
  /// Liste des catégories de véhicules autorisées
  /// Si null, autorisé pour toutes les catégories
  final List<String>? validCategories;
  
  /// Nombre maximum d'utilisations (optionnel)
  /// Si null, utilisations illimitées
  final int? maxUses;
  
  /// Nombre d'utilisations actuelles
  final int currentUses;
  
  const PromoCode({
    required this.code,
    required this.type,
    required this.value,
    this.validUntil,
    this.minAmount,
    this.validCategories,
    this.maxUses,
    this.currentUses = 0,
  });
  
  /// Calcule la réduction à appliquer pour un prix et une catégorie donnés
  /// 
  /// [basePrice] Prix avant application du code promo
  /// [vehicleCategory] Catégorie du véhicule
  /// 
  /// Retourne le montant de la réduction en MGA, ou 0 si le code n'est pas applicable
  double calculateDiscount(double basePrice, String vehicleCategory) {
    // Vérifier la validité du code
    if (!isValid(basePrice, vehicleCategory)) {
      return 0.0;
    }
    
    double discount = 0.0;
    
    switch (type) {
      case PromoType.percentage:
        discount = basePrice * (value / 100);
        break;
      case PromoType.fixedAmount:
        discount = value;
        break;
    }
    
    // La réduction ne peut pas être supérieure au prix de base
    return discount > basePrice ? basePrice : discount;
  }
  
  /// Vérifie si le code promo peut être appliqué
  /// 
  /// [basePrice] Prix avant application du code promo
  /// [vehicleCategory] Catégorie du véhicule
  /// 
  /// Retourne true si le code peut être appliqué
  bool isValid(double basePrice, String vehicleCategory) {
    // Vérifier l'expiration
    if (validUntil != null && DateTime.now().isAfter(validUntil!)) {
      return false;
    }
    
    // Vérifier le montant minimum
    if (minAmount != null && basePrice < minAmount!) {
      return false;
    }
    
    // Vérifier la catégorie autorisée
    if (validCategories != null && !validCategories!.contains(vehicleCategory)) {
      return false;
    }
    
    // Vérifier le nombre maximum d'utilisations
    if (maxUses != null && currentUses >= maxUses!) {
      return false;
    }
    
    // Vérifier que la valeur est positive
    if (value <= 0) {
      return false;
    }
    
    return true;
  }
  
  /// Vérifie si le code a expiré
  bool get isExpired {
    return validUntil != null && DateTime.now().isAfter(validUntil!);
  }
  
  /// Vérifie si le code a atteint sa limite d'utilisation
  bool get isMaxUsesReached {
    return maxUses != null && currentUses >= maxUses!;
  }
  
  /// Nombre d'utilisations restantes
  int? get remainingUses {
    if (maxUses == null) return null;
    return maxUses! - currentUses;
  }
  
  /// Description du code promo pour affichage
  String get description {
    switch (type) {
      case PromoType.percentage:
        return '${value.toStringAsFixed(0)}% de réduction';
      case PromoType.fixedAmount:
        return '${value.toStringAsFixed(0)} MGA de réduction';
    }
  }
  
  /// Description complète incluant les conditions
  String get fullDescription {
    var desc = description;
    
    if (minAmount != null) {
      desc += ' (minimum ${minAmount!.toStringAsFixed(0)} MGA)';
    }
    
    if (validCategories != null && validCategories!.isNotEmpty) {
      desc += ' pour ${validCategories!.join(', ')}';
    }
    
    if (validUntil != null) {
      desc += ' jusqu\'au ${validUntil!.day}/${validUntil!.month}/${validUntil!.year}';
    }
    
    return desc;
  }
  
  /// Sérialisation vers JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'type': type.toString().split('.').last,
      'value': value,
      'validUntil': validUntil?.toIso8601String(),
      'minAmount': minAmount,
      'validCategories': validCategories,
      'maxUses': maxUses,
      'currentUses': currentUses,
    };
  }
  
  /// Désérialisation depuis JSON
  factory PromoCode.fromJson(Map<String, dynamic> json) {
    return PromoCode(
      code: json['code'] ?? '',
      type: PromoType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => PromoType.percentage,
      ),
      value: (json['value'] ?? 0.0).toDouble(),
      validUntil: json['validUntil'] != null 
          ? DateTime.parse(json['validUntil']) 
          : null,
      minAmount: json['minAmount']?.toDouble(),
      validCategories: json['validCategories'] != null 
          ? List<String>.from(json['validCategories']) 
          : null,
      maxUses: json['maxUses']?.toInt(),
      currentUses: json['currentUses'] ?? 0,
    );
  }
  
  /// Création d'une copie avec modifications
  PromoCode copyWith({
    String? code,
    PromoType? type,
    double? value,
    DateTime? validUntil,
    double? minAmount,
    List<String>? validCategories,
    int? maxUses,
    int? currentUses,
  }) {
    return PromoCode(
      code: code ?? this.code,
      type: type ?? this.type,
      value: value ?? this.value,
      validUntil: validUntil ?? this.validUntil,
      minAmount: minAmount ?? this.minAmount,
      validCategories: validCategories ?? this.validCategories,
      maxUses: maxUses ?? this.maxUses,
      currentUses: currentUses ?? this.currentUses,
    );
  }
  
  /// Incrémente le compteur d'utilisations
  PromoCode incrementUses() {
    return copyWith(currentUses: currentUses + 1);
  }
  
  @override
  String toString() {
    return 'PromoCode($code, $description)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is PromoCode &&
           other.code == code &&
           other.type == type &&
           other.value == value &&
           other.validUntil == validUntil &&
           other.minAmount == minAmount &&
           _listEquals(other.validCategories, validCategories) &&
           other.maxUses == maxUses &&
           other.currentUses == currentUses;
  }
  
  @override
  int get hashCode {
    return code.hashCode ^
           type.hashCode ^
           value.hashCode ^
           validUntil.hashCode ^
           minAmount.hashCode ^
           validCategories.hashCode ^
           maxUses.hashCode ^
           currentUses.hashCode;
  }
  
  /// Helper pour comparer des listes de chaînes
  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Types de codes promotionnels supportés
enum PromoType {
  /// Réduction en pourcentage du prix total
  percentage,
  
  /// Réduction d'un montant fixe en MGA
  fixedAmount,
}

/// Extension pour faciliter l'usage des PromoType
extension PromoTypeExtension on PromoType {
  /// Nom d'affichage du type de promo
  String get displayName {
    switch (this) {
      case PromoType.percentage:
        return 'Pourcentage';
      case PromoType.fixedAmount:
        return 'Montant fixe';
    }
  }
  
  /// Symbole associé au type
  String get symbol {
    switch (this) {
      case PromoType.percentage:
        return '%';
      case PromoType.fixedAmount:
        return 'MGA';
    }
  }
}