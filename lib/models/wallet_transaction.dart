import 'package:cloud_firestore/cloud_firestore.dart';

/// Types de transactions possibles dans le portefeuille
enum TransactionType {
  credit, // Crédit (ajout d'argent)
  debit,  // Débit (retrait d'argent)
}

/// Sources de paiement pour les transactions
enum PaymentSource {
  airtelMoney,    // Airtel Money
  orangeMoney,    // Orange Money
  telmaMoney,     // Telma MVola
  creditCard,     // Carte bancaire
  tripPayment,    // Paiement de trajet
  refund,         // Remboursement
  bonus,          // Bonus promotionnel
  cashback,       // Cashback
  transfer,       // Transfert entre utilisateurs
  adjustment,     // Ajustement manuel
}

/// Statut d'une transaction
enum TransactionStatus {
  pending,    // En attente
  processing, // En cours de traitement
  completed,  // Terminée avec succès
  failed,     // Échec
  cancelled,  // Annulée
  refunded,   // Remboursée
}

/// Modèle représentant une transaction du portefeuille numérique
/// Suit les conventions de l'architecture Misy (voir PopularDestination)
class WalletTransaction {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final PaymentSource source;
  final TransactionStatus status;
  final DateTime timestamp;
  final String description;
  final String? referenceId; // ID de transaction externe (Airtel, Orange, etc.)
  final String? tripId; // ID du trajet si applicable
  final Map<String, dynamic>? metadata; // Données supplémentaires
  final DateTime? processedAt; // Date de traitement
  final String? errorMessage; // Message d'erreur si échec

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.source,
    required this.status,
    required this.timestamp,
    required this.description,
    this.referenceId,
    this.tripId,
    this.metadata,
    this.processedAt,
    this.errorMessage,
  });

  /// Création depuis les données Firestore
  factory WalletTransaction.fromFirestore(Map<String, dynamic> data, String id) {
    return WalletTransaction(
      id: id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: _parseTransactionType(data['type']),
      source: _parsePaymentSource(data['source']),
      status: _parseTransactionStatus(data['status']),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      description: data['description'] ?? '',
      referenceId: data['referenceId'],
      tripId: data['tripId'],
      metadata: data['metadata'] != null 
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      errorMessage: data['errorMessage'],
    );
  }

  /// Création depuis JSON (pour cache local)
  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      type: _parseTransactionType(json['type']),
      source: _parsePaymentSource(json['source']),
      status: _parseTransactionStatus(json['status']),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      description: json['description'] ?? '',
      referenceId: json['referenceId'],
      tripId: json['tripId'],
      metadata: json['metadata'] != null 
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'])
          : null,
      errorMessage: json['errorMessage'],
    );
  }

  /// Conversion vers JSON (pour cache local)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'source': source.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'referenceId': referenceId,
      'tripId': tripId,
      'metadata': metadata,
      'processedAt': processedAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  /// Conversion vers Firestore (exclut l'ID qui est géré par Firestore)
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'source': source.name,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
      'referenceId': referenceId,
      'tripId': tripId,
      'metadata': metadata,
      'processedAt': processedAt != null 
          ? Timestamp.fromDate(processedAt!)
          : null,
      'errorMessage': errorMessage,
    };
  }

  /// Parse le type de transaction depuis une string
  static TransactionType _parseTransactionType(dynamic value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'credit':
          return TransactionType.credit;
        case 'debit':
          return TransactionType.debit;
        default:
          return TransactionType.credit; // Par défaut
      }
    }
    return TransactionType.credit;
  }

  /// Parse la source de paiement depuis une string
  static PaymentSource _parsePaymentSource(dynamic value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'airtelmoney':
          return PaymentSource.airtelMoney;
        case 'orangemoney':
          return PaymentSource.orangeMoney;
        case 'telmamoney':
          return PaymentSource.telmaMoney;
        case 'creditcard':
          return PaymentSource.creditCard;
        case 'trippayment':
          return PaymentSource.tripPayment;
        case 'refund':
          return PaymentSource.refund;
        case 'bonus':
          return PaymentSource.bonus;
        case 'cashback':
          return PaymentSource.cashback;
        case 'transfer':
          return PaymentSource.transfer;
        case 'adjustment':
          return PaymentSource.adjustment;
        default:
          return PaymentSource.airtelMoney; // Par défaut
      }
    }
    return PaymentSource.airtelMoney;
  }

  /// Parse le statut de transaction depuis une string
  static TransactionStatus _parseTransactionStatus(dynamic value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'pending':
          return TransactionStatus.pending;
        case 'processing':
          return TransactionStatus.processing;
        case 'completed':
          return TransactionStatus.completed;
        case 'failed':
          return TransactionStatus.failed;
        case 'cancelled':
          return TransactionStatus.cancelled;
        case 'refunded':
          return TransactionStatus.refunded;
        default:
          return TransactionStatus.pending; // Par défaut
      }
    }
    return TransactionStatus.pending;
  }

  /// Vérifie si la transaction est terminée (complétée ou échouée)
  bool get isFinalized => 
      status == TransactionStatus.completed ||
      status == TransactionStatus.failed ||
      status == TransactionStatus.cancelled ||
      status == TransactionStatus.refunded;

  /// Vérifie si la transaction est en cours
  bool get isPending =>
      status == TransactionStatus.pending ||
      status == TransactionStatus.processing;

  /// Vérifie si la transaction a réussi
  bool get isSuccessful => status == TransactionStatus.completed;

  /// Retourne le montant avec le signe approprié
  double get signedAmount {
    switch (type) {
      case TransactionType.credit:
        return amount;
      case TransactionType.debit:
        return -amount;
    }
  }

  /// Retourne une description formatée selon la source
  String get formattedDescription {
    switch (source) {
      case PaymentSource.airtelMoney:
        return 'Crédit via Airtel Money';
      case PaymentSource.orangeMoney:
        return 'Crédit via Orange Money';
      case PaymentSource.telmaMoney:
        return 'Crédit via Telma MVola';
      case PaymentSource.creditCard:
        return 'Crédit via Carte bancaire';
      case PaymentSource.tripPayment:
        return 'Paiement de trajet';
      case PaymentSource.refund:
        return 'Remboursement';
      case PaymentSource.bonus:
        return 'Bonus promotionnel';
      case PaymentSource.cashback:
        return 'Cashback';
      case PaymentSource.transfer:
        return 'Transfert';
      case PaymentSource.adjustment:
        return 'Ajustement';
    }
  }

  /// Copie avec modifications
  WalletTransaction copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionType? type,
    PaymentSource? source,
    TransactionStatus? status,
    DateTime? timestamp,
    String? description,
    String? referenceId,
    String? tripId,
    Map<String, dynamic>? metadata,
    DateTime? processedAt,
    String? errorMessage,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      source: source ?? this.source,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      tripId: tripId ?? this.tripId,
      metadata: metadata ?? this.metadata,
      processedAt: processedAt ?? this.processedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'WalletTransaction(id: $id, userId: $userId, amount: $amount, '
           'type: $type, source: $source, status: $status, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletTransaction &&
        other.id == id &&
        other.userId == userId &&
        other.amount == amount &&
        other.type == type &&
        other.source == source &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        amount.hashCode ^
        type.hashCode ^
        source.hashCode ^
        status.hashCode;
  }
}

/// Utilitaires pour les transactions
class WalletTransactionHelper {
  /// Crée une transaction de crédit via mobile money
  static WalletTransaction createCreditTransaction({
    required String userId,
    required double amount,
    required PaymentSource source,
    required String referenceId,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransaction(
      id: '', // Sera généré par Firestore
      userId: userId,
      amount: amount,
      type: TransactionType.credit,
      source: source,
      status: TransactionStatus.pending,
      timestamp: DateTime.now(),
      description: description ?? 'Crédit de portefeuille',
      referenceId: referenceId,
      metadata: metadata,
    );
  }

  /// Crée une transaction de débit pour paiement de trajet
  static WalletTransaction createTripPaymentTransaction({
    required String userId,
    required double amount,
    required String tripId,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransaction(
      id: '', // Sera généré par Firestore
      userId: userId,
      amount: amount,
      type: TransactionType.debit,
      source: PaymentSource.tripPayment,
      status: TransactionStatus.pending,
      timestamp: DateTime.now(),
      description: description ?? 'Paiement de trajet',
      tripId: tripId,
      metadata: metadata,
    );
  }

  /// Valide les données d'une transaction
  static bool isValidTransaction(WalletTransaction transaction) {
    return transaction.userId.isNotEmpty &&
           transaction.amount > 0 &&
           transaction.description.isNotEmpty;
  }

  /// Retourne le nom affiché de la source de paiement
  static String getDisplayNameForSource(PaymentSource source) {
    switch (source) {
      case PaymentSource.airtelMoney:
        return 'Airtel Money';
      case PaymentSource.orangeMoney:
        return 'Orange Money';
      case PaymentSource.telmaMoney:
        return 'Telma MVola';
      case PaymentSource.creditCard:
        return 'Carte bancaire';
      case PaymentSource.tripPayment:
        return 'Paiement de trajet';
      case PaymentSource.refund:
        return 'Remboursement';
      case PaymentSource.bonus:
        return 'Bonus';
      case PaymentSource.cashback:
        return 'Cashback';
      case PaymentSource.transfer:
        return 'Transfert';
      case PaymentSource.adjustment:
        return 'Ajustement';
    }
  }
}