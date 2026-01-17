import 'package:cloud_firestore/cloud_firestore.dart';
import 'wallet_transaction.dart';

/// Modèle représentant le portefeuille numérique d'un utilisateur
/// Suit les conventions de l'architecture Misy existante
class Wallet {
  final String userId;
  final double balance;
  final DateTime lastUpdated;
  final bool isActive;
  final String currency;
  final double minBalance;
  final double maxBalance;
  final DateTime createdAt;
  final List<String> recentTransactionIds;
  final int totalTransactions;
  final double totalCredits;
  final double totalDebits;
  final String? lastTransactionId;
  final DateTime? lastTransactionDate;

  const Wallet({
    required this.userId,
    required this.balance,
    required this.lastUpdated,
    this.isActive = true,
    this.currency = 'MGA', // Ariary Malgache
    this.minBalance = 0.0,
    this.maxBalance = 5000000.0, // 5M Ariary par défaut
    required this.createdAt,
    this.recentTransactionIds = const [],
    this.totalTransactions = 0,
    this.totalCredits = 0.0,
    this.totalDebits = 0.0,
    this.lastTransactionId,
    this.lastTransactionDate,
  });

  /// Création depuis les données Firestore
  factory Wallet.fromFirestore(Map<String, dynamic> data, String userId) {
    return Wallet(
      userId: userId,
      balance: (data['balance'] ?? 0.0).toDouble(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
      currency: data['currency'] ?? 'MGA',
      minBalance: (data['minBalance'] ?? 0.0).toDouble(),
      maxBalance: (data['maxBalance'] ?? 5000000.0).toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      recentTransactionIds: data['recentTransactionIds'] != null
          ? List<String>.from(data['recentTransactionIds'])
          : [],
      totalTransactions: data['totalTransactions'] ?? 0,
      totalCredits: (data['totalCredits'] ?? 0.0).toDouble(),
      totalDebits: (data['totalDebits'] ?? 0.0).toDouble(),
      lastTransactionId: data['lastTransactionId'],
      lastTransactionDate: data['lastTransactionDate'] != null
          ? (data['lastTransactionDate'] as Timestamp).toDate()
          : null,
    );
  }

  /// Création depuis JSON (pour cache local)
  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      userId: json['userId'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
      currency: json['currency'] ?? 'MGA',
      minBalance: (json['minBalance'] ?? 0.0).toDouble(),
      maxBalance: (json['maxBalance'] ?? 5000000.0).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      recentTransactionIds: json['recentTransactionIds'] != null
          ? List<String>.from(json['recentTransactionIds'])
          : [],
      totalTransactions: json['totalTransactions'] ?? 0,
      totalCredits: (json['totalCredits'] ?? 0.0).toDouble(),
      totalDebits: (json['totalDebits'] ?? 0.0).toDouble(),
      lastTransactionId: json['lastTransactionId'],
      lastTransactionDate: json['lastTransactionDate'] != null
          ? DateTime.parse(json['lastTransactionDate'])
          : null,
    );
  }

  /// Conversion vers JSON (pour cache local)
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'balance': balance,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isActive': isActive,
      'currency': currency,
      'minBalance': minBalance,
      'maxBalance': maxBalance,
      'createdAt': createdAt.toIso8601String(),
      'recentTransactionIds': recentTransactionIds,
      'totalTransactions': totalTransactions,
      'totalCredits': totalCredits,
      'totalDebits': totalDebits,
      'lastTransactionId': lastTransactionId,
      'lastTransactionDate': lastTransactionDate?.toIso8601String(),
    };
  }

  /// Conversion vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'balance': balance,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'isActive': isActive,
      'currency': currency,
      'minBalance': minBalance,
      'maxBalance': maxBalance,
      'createdAt': Timestamp.fromDate(createdAt),
      'recentTransactionIds': recentTransactionIds,
      'totalTransactions': totalTransactions,
      'totalCredits': totalCredits,
      'totalDebits': totalDebits,
      'lastTransactionId': lastTransactionId,
      'lastTransactionDate': lastTransactionDate != null
          ? Timestamp.fromDate(lastTransactionDate!)
          : null,
    };
  }

  /// Crée un nouveau portefeuille pour un utilisateur
  factory Wallet.createNew(String userId) {
    final now = DateTime.now();
    return Wallet(
      userId: userId,
      balance: 0.0,
      lastUpdated: now,
      createdAt: now,
      isActive: true,
      currency: 'MGA',
      minBalance: 0.0,
      maxBalance: 5000000.0, // 5M Ariary
      recentTransactionIds: [],
      totalTransactions: 0,
      totalCredits: 0.0,
      totalDebits: 0.0,
    );
  }

  /// Vérifie si le solde est suffisant pour une transaction
  bool hasSufficientBalance(double amount) {
    return balance >= amount && amount > 0;
  }

  /// Vérifie si un crédit est possible
  bool canCredit(double amount) {
    if (amount <= 0) return false;
    if (!isActive) return false;
    return (balance + amount) <= maxBalance;
  }

  /// Vérifie si un débit est possible
  bool canDebit(double amount) {
    if (amount <= 0) return false;
    if (!isActive) return false;
    return hasSufficientBalance(amount) && (balance - amount) >= minBalance;
  }

  /// Simule l'application d'une transaction
  Wallet applyTransaction(WalletTransaction transaction) {
    if (transaction.userId != userId) {
      throw ArgumentError('Transaction userId does not match wallet userId');
    }

    double newBalance = balance;
    double newTotalCredits = totalCredits;
    double newTotalDebits = totalDebits;
    List<String> newRecentIds = List.from(recentTransactionIds);

    // Applique le changement de solde selon le type
    switch (transaction.type) {
      case TransactionType.credit:
        if (!canCredit(transaction.amount)) {
          throw ArgumentError('Cannot credit wallet: insufficient capacity or inactive wallet');
        }
        newBalance += transaction.amount;
        newTotalCredits += transaction.amount;
        break;
      case TransactionType.debit:
        if (!canDebit(transaction.amount)) {
          throw ArgumentError('Cannot debit wallet: insufficient balance');
        }
        newBalance -= transaction.amount;
        newTotalDebits += transaction.amount;
        break;
    }

    // Met à jour les transactions récentes (garde les 10 dernières)
    if (transaction.id.isNotEmpty) {
      newRecentIds.insert(0, transaction.id);
      if (newRecentIds.length > 10) {
        newRecentIds = newRecentIds.take(10).toList();
      }
    }

    return copyWith(
      balance: newBalance,
      lastUpdated: DateTime.now(),
      totalTransactions: totalTransactions + 1,
      totalCredits: newTotalCredits,
      totalDebits: newTotalDebits,
      recentTransactionIds: newRecentIds,
      lastTransactionId: transaction.id.isNotEmpty ? transaction.id : lastTransactionId,
      lastTransactionDate: DateTime.now(),
    );
  }

  /// Vérifie si le portefeuille a un solde faible
  bool get hasLowBalance {
    const lowBalanceThreshold = 10000.0; // 10,000 MGA
    return balance < lowBalanceThreshold;
  }

  /// Retourne le pourcentage d'utilisation du solde maximum
  double get balanceUsagePercentage {
    if (maxBalance <= 0) return 0.0;
    return (balance / maxBalance).clamp(0.0, 1.0);
  }

  /// Vérifie si le portefeuille est proche de la limite maximale
  bool get isNearMaxBalance {
    return balanceUsagePercentage >= 0.9; // 90% de la limite
  }

  /// Retourne le solde formaté avec la devise et séparation des milliers
  String get formattedBalance {
    return WalletHelper.formatAmountWithSeparators(balance, currency: currency);
  }

  /// Retourne le montant disponible pour débiter
  double get availableBalance {
    return balance - minBalance;
  }

  /// Retourne l'espace disponible pour créditer
  double get creditCapacity {
    return maxBalance - balance;
  }

  /// Copie avec modifications
  Wallet copyWith({
    String? userId,
    double? balance,
    DateTime? lastUpdated,
    bool? isActive,
    String? currency,
    double? minBalance,
    double? maxBalance,
    DateTime? createdAt,
    List<String>? recentTransactionIds,
    int? totalTransactions,
    double? totalCredits,
    double? totalDebits,
    String? lastTransactionId,
    DateTime? lastTransactionDate,
  }) {
    return Wallet(
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
      currency: currency ?? this.currency,
      minBalance: minBalance ?? this.minBalance,
      maxBalance: maxBalance ?? this.maxBalance,
      createdAt: createdAt ?? this.createdAt,
      recentTransactionIds: recentTransactionIds ?? this.recentTransactionIds,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalCredits: totalCredits ?? this.totalCredits,
      totalDebits: totalDebits ?? this.totalDebits,
      lastTransactionId: lastTransactionId ?? this.lastTransactionId,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }

  @override
  String toString() {
    return 'Wallet(userId: $userId, balance: $balance, isActive: $isActive, '
           'currency: $currency, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Wallet &&
        other.userId == userId &&
        other.balance == balance &&
        other.isActive == isActive &&
        other.currency == currency;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
        balance.hashCode ^
        isActive.hashCode ^
        currency.hashCode;
  }
}

/// Contraintes et validations pour le portefeuille
class WalletConstraints {
  static const double defaultMinBalance = 0.0;
  static const double defaultMaxBalance = 5000000.0; // 5M MGA
  static const double minimumTransactionAmount = 100.0; // 100 MGA minimum
  static const double maximumTransactionAmount = 1000000.0; // 1M MGA par transaction
  static const String defaultCurrency = 'MGA';
  static const int maxRecentTransactions = 10;

  /// Valide un montant de transaction
  static bool isValidTransactionAmount(double amount) {
    return amount >= minimumTransactionAmount && 
           amount <= maximumTransactionAmount;
  }

  /// Valide les limites d'un portefeuille
  static bool isValidWalletLimits(double minBalance, double maxBalance) {
    return minBalance >= 0 && 
           maxBalance > minBalance && 
           maxBalance <= defaultMaxBalance;
  }

  /// Valide un portefeuille complet
  static List<String> validateWallet(Wallet wallet) {
    List<String> errors = [];

    if (wallet.userId.isEmpty) {
      errors.add('User ID is required');
    }

    if (wallet.balance < 0) {
      errors.add('Balance cannot be negative');
    }

    if (wallet.balance < wallet.minBalance) {
      errors.add('Balance is below minimum allowed');
    }

    if (wallet.balance > wallet.maxBalance) {
      errors.add('Balance exceeds maximum allowed');
    }

    if (!isValidWalletLimits(wallet.minBalance, wallet.maxBalance)) {
      errors.add('Invalid wallet limits');
    }

    if (wallet.currency != defaultCurrency) {
      errors.add('Invalid currency');
    }

    return errors;
  }
}

/// Utilitaires pour les portefeuilles
class WalletHelper {
  /// Calcule les statistiques d'un portefeuille
  static Map<String, dynamic> calculateStats(Wallet wallet) {
    return {
      'balancePercentage': wallet.balanceUsagePercentage,
      'isLowBalance': wallet.hasLowBalance,
      'isNearMaxBalance': wallet.isNearMaxBalance,
      'availableCredit': wallet.creditCapacity,
      'availableDebit': wallet.availableBalance,
      'totalTransactions': wallet.totalTransactions,
      'netAmount': wallet.totalCredits - wallet.totalDebits,
    };
  }

  /// Suggère un montant de crédit optimal
  static double suggestCreditAmount(Wallet wallet) {
    if (wallet.hasLowBalance) {
      // Suggère de ramener le solde à 50,000 MGA
      double targetBalance = 50000.0;
      double suggestedAmount = targetBalance - wallet.balance;
      
      // S'assure que cela ne dépasse pas la capacité
      return [suggestedAmount, wallet.creditCapacity]
          .where((amount) => amount > 0)
          .reduce((a, b) => a < b ? a : b);
    }
    
    return 0.0;
  }

  /// Formate un montant avec la devise locale (version abrégée K/M)
  static String formatAmount(double amount, {String currency = 'MGA'}) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M $currency';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K $currency';
    } else {
      return '${amount.toStringAsFixed(0)} $currency';
    }
  }

  /// Formate un montant avec séparation des milliers pour une meilleure lisibilité
  static String formatAmountWithSeparators(double amount, {String currency = 'MGA'}) {
    // Convertir en entier et formater avec des séparateurs d'espace
    final intAmount = amount.toInt();
    final formattedNumber = intAmount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]} ',
    );
    return '$formattedNumber $currency';
  }
}