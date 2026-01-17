import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyTransaction {
  String transactionId;
  String type; // 'earned' or 'spent'
  double points;
  String reason;
  String? bookingId;
  double? amount;
  Timestamp timestamp;
  double balance; // Solde après cette transaction
  
  // Nouvelles propriétés pour les coffres
  double? chestRewardAmount; // Montant gagné dans le portefeuille (MGA)
  String? chestTier;         // Tier du coffre ouvert (tier1, tier2, tier3)
  String? rewardMode;        // Mode de récompense utilisé (newUser, lucky, standard)

  LoyaltyTransaction({
    required this.transactionId,
    required this.type,
    required this.points,
    required this.reason,
    this.bookingId,
    this.amount,
    required this.timestamp,
    required this.balance,
    this.chestRewardAmount,
    this.chestTier,
    this.rewardMode,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      transactionId: json['transactionId'],
      type: json['type'],
      points: double.parse((json['points'] ?? 0.0).toString()),
      reason: json['reason'],
      bookingId: json['bookingId'],
      amount: json['amount'] != null ? double.parse(json['amount'].toString()) : null,
      timestamp: json['timestamp'] as Timestamp,
      balance: double.parse((json['balance'] ?? 0.0).toString()),
      chestRewardAmount: json['chestRewardAmount'] != null ? double.parse(json['chestRewardAmount'].toString()) : null,
      chestTier: json['chestTier'],
      rewardMode: json['rewardMode'],
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'transactionId': transactionId,
      'type': type,
      'points': points,
      'reason': reason,
      'bookingId': bookingId,
      'amount': amount,
      'timestamp': timestamp,
      'balance': balance,
    };
    
    // Ajouter les champs optionnels s'ils existent
    if (chestRewardAmount != null) json['chestRewardAmount'] = chestRewardAmount;
    if (chestTier != null) json['chestTier'] = chestTier;
    if (rewardMode != null) json['rewardMode'] = rewardMode;
    
    return json;
  }

  static LoyaltyTransaction createEarned({
    required String transactionId,
    required double points,
    required String reason,
    String? bookingId,
    double? amount,
    required double balance,
  }) {
    return LoyaltyTransaction(
      transactionId: transactionId,
      type: 'earned',
      points: points,
      reason: reason,
      bookingId: bookingId,
      amount: amount,
      timestamp: Timestamp.now(),
      balance: balance,
    );
  }

  static LoyaltyTransaction createSpent({
    required String transactionId,
    required double points,
    required String reason,
    String? bookingId,
    double? amount,
    required double balance,
  }) {
    return LoyaltyTransaction(
      transactionId: transactionId,
      type: 'spent',
      points: points,
      reason: reason,
      bookingId: bookingId,
      amount: amount,
      timestamp: Timestamp.now(),
      balance: balance,
    );
  }

  /// Crée une transaction de dépense spécialisée pour les coffres
  static LoyaltyTransaction createChestSpent({
    required String transactionId,
    required double points,
    required String reason,
    required double balance,
    required double chestRewardAmount,
    required String chestTier,
    required String rewardMode,
  }) {
    return LoyaltyTransaction(
      transactionId: transactionId,
      type: 'spent',
      points: points,
      reason: reason,
      timestamp: Timestamp.now(),
      balance: balance,
      chestRewardAmount: chestRewardAmount,
      chestTier: chestTier,
      rewardMode: rewardMode,
    );
  }
  
  /// Vérifie si cette transaction concerne un coffre
  bool get isChestTransaction => chestRewardAmount != null && chestTier != null;
  
  /// Récupère le nom du coffre formaté
  String get chestDisplayName {
    switch (chestTier) {
      case 'tier1': return 'Coffre Bronze';
      case 'tier2': return 'Coffre Argent';
      case 'tier3': return 'Coffre Or';
      default: return 'Coffre';
    }
  }
}