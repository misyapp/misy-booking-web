import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';

/// Service de gestion du portefeuille numérique
/// Responsable de toutes les opérations liées au wallet
/// Suit les conventions de l'architecture Misy existante
class WalletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collections Firestore
  static CollectionReference get _walletsCollection => 
      _firestore.collection('wallets');
  
  static CollectionReference get _transactionsCollection => 
      _firestore.collection('wallet_transactions');
  
  // Clés pour le cache local
  static const String _walletCacheKey = 'cached_wallet_';
  static const String _transactionsCacheKey = 'cached_transactions_';
  static const String _lastSyncKey = 'last_wallet_sync_';
  
  // Durée de validité du cache (15 minutes)
  static const Duration _cacheValidityDuration = Duration(minutes: 15);

  /// Récupère le portefeuille d'un utilisateur
  /// Utilise le cache local si disponible et valide
  static Future<Wallet?> getWallet(String userId) async {
    try {
      myCustomPrintStatement('WalletService.getWallet: $userId');
      
      // Vérifier le cache d'abord
      Wallet? cachedWallet = await _getCachedWallet(userId);
      if (cachedWallet != null && await _isCacheValid(userId)) {
        myCustomPrintStatement('Wallet loaded from cache');
        return cachedWallet;
      }

      // Charger depuis Firestore
      DocumentSnapshot doc = await _walletsCollection.doc(userId).get();
      
      if (!doc.exists) {
        myCustomPrintStatement('Wallet not found for user: $userId');
        return null;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Wallet wallet = Wallet.fromFirestore(data, userId);
      
      // Mettre en cache
      await _cacheWallet(wallet);
      
      return wallet;
    } catch (e) {
      myCustomPrintStatement('Error getting wallet: $e');
      return null;
    }
  }

  /// Crée un nouveau portefeuille pour un utilisateur
  static Future<Wallet?> createWallet(String userId) async {
    try {
      myCustomPrintStatement('WalletService.createWallet: $userId');
      
      // Vérifier si le portefeuille existe déjà
      Wallet? existingWallet = await getWallet(userId);
      if (existingWallet != null) {
        myCustomPrintStatement('Wallet already exists for user: $userId');
        return existingWallet;
      }

      // Créer un nouveau portefeuille
      Wallet newWallet = Wallet.createNew(userId);
      
      // Sauvegarder dans Firestore
      await _walletsCollection.doc(userId).set(newWallet.toFirestore());
      
      // Mettre en cache
      await _cacheWallet(newWallet);
      
      myCustomPrintStatement('New wallet created for user: $userId');
      return newWallet;
    } catch (e) {
      myCustomPrintStatement('Error creating wallet: $e');
      return null;
    }
  }

  /// Met à jour le solde du portefeuille de façon atomique
  static Future<bool> updateWalletBalance({
    required String userId,
    required double newBalance,
    String? lastTransactionId,
  }) async {
    try {
      myCustomPrintStatement('WalletService.updateWalletBalance: $userId, $newBalance');
      
      // Transaction atomique Firestore
      return await _firestore.runTransaction((transaction) async {
        DocumentReference walletRef = _walletsCollection.doc(userId);
        DocumentSnapshot walletSnapshot = await transaction.get(walletRef);
        
        if (!walletSnapshot.exists) {
          throw Exception('Wallet not found');
        }
        
        Map<String, dynamic> walletData = walletSnapshot.data() as Map<String, dynamic>;
        Wallet currentWallet = Wallet.fromFirestore(walletData, userId);
        
        // Créer le portefeuille mis à jour
        Wallet updatedWallet = currentWallet.copyWith(
          balance: newBalance,
          lastUpdated: DateTime.now(),
          lastTransactionId: lastTransactionId ?? currentWallet.lastTransactionId,
          lastTransactionDate: DateTime.now(),
        );
        
        // Mettre à jour dans Firestore
        transaction.update(walletRef, updatedWallet.toFirestore());
        
        // Mettre en cache
        await _cacheWallet(updatedWallet);
        
        return true;
      });
    } catch (e) {
      myCustomPrintStatement('Error updating wallet balance: $e');
      return false;
    }
  }

  /// Effectue une transaction de crédit
  static Future<WalletTransaction?> creditWallet({
    required String userId,
    required double amount,
    required PaymentSource source,
    required String referenceId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      myCustomPrintStatement('WalletService.creditWallet: $userId, $amount, $source');
      
      // Valider le montant
      if (!WalletConstraints.isValidTransactionAmount(amount)) {
        throw Exception('Invalid transaction amount: $amount');
      }

      // Créer la transaction
      WalletTransaction transaction = WalletTransactionHelper.createCreditTransaction(
        userId: userId,
        amount: amount,
        source: source,
        referenceId: referenceId,
        description: description,
        metadata: metadata,
      );

      return await _processTransaction(transaction);
    } catch (e) {
      myCustomPrintStatement('Error crediting wallet: $e');
      return null;
    }
  }

  /// Effectue une transaction de débit
  static Future<WalletTransaction?> debitWallet({
    required String userId,
    required double amount,
    String? tripId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      myCustomPrintStatement('🔶 WALLET_DEBUG: WalletService.debitWallet called - userId: $userId, amount: $amount, tripId: $tripId');
      
      // Valider le montant
      if (!WalletConstraints.isValidTransactionAmount(amount)) {
        throw Exception('Invalid transaction amount: $amount');
      }

      // Vérifier le solde suffisant
      myCustomPrintStatement('🔶 WALLET_DEBUG: Getting wallet for user: $userId');
      Wallet? wallet = await getWallet(userId);
      if (wallet == null) {
        myCustomPrintStatement('🔶 WALLET_DEBUG: Wallet not found for user: $userId');
        throw Exception('Wallet not found');
      }
      
      myCustomPrintStatement('🔶 WALLET_DEBUG: Wallet found - balance: ${wallet.balance}, required: $amount');
      if (!wallet.canDebit(amount)) {
        myCustomPrintStatement('🔶 WALLET_DEBUG: Insufficient balance - cannot debit');
        throw Exception('Insufficient balance');
      }
      
      myCustomPrintStatement('🔶 WALLET_DEBUG: Balance check passed - proceeding with transaction');

      // Créer la transaction
      myCustomPrintStatement('🔶 WALLET_DEBUG: Creating transaction object...');
      WalletTransaction transaction = WalletTransactionHelper.createTripPaymentTransaction(
        userId: userId,
        amount: amount,
        tripId: tripId ?? '',
        description: description,
        metadata: metadata,
      );
      
      myCustomPrintStatement('🔶 WALLET_DEBUG: Transaction created - calling _processTransaction...');
      WalletTransaction? result = await _processTransaction(transaction);
      myCustomPrintStatement('🔶 WALLET_DEBUG: _processTransaction returned: ${result != null ? result.id : 'NULL'}');
      return result;
    } catch (e) {
      myCustomPrintStatement('🔶 WALLET_DEBUG: EXCEPTION in WalletService.debitWallet: $e');
      return null;
    }
  }

  /// Traite une transaction de façon atomique
  static Future<WalletTransaction?> _processTransaction(WalletTransaction transaction) async {
    try {
      myCustomPrintStatement('🔶 WALLET_DEBUG: _processTransaction started for user: ${transaction.userId}');
      WalletTransaction? result = await _firestore.runTransaction((firestoreTransaction) async {
        // Références Firestore
        DocumentReference walletRef = _walletsCollection.doc(transaction.userId);
        DocumentReference transactionRef = _transactionsCollection.doc();
        
        // Récupérer le portefeuille actuel
        myCustomPrintStatement('🔶 WALLET_DEBUG: Getting wallet snapshot from Firestore...');
        DocumentSnapshot walletSnapshot = await firestoreTransaction.get(walletRef);
        if (!walletSnapshot.exists) {
          myCustomPrintStatement('🔶 WALLET_DEBUG: Wallet document not found in Firestore');
          throw Exception('Wallet not found');
        }
        myCustomPrintStatement('🔶 WALLET_DEBUG: Wallet snapshot retrieved successfully');
        
        Map<String, dynamic> walletData = walletSnapshot.data() as Map<String, dynamic>;
        Wallet currentWallet = Wallet.fromFirestore(walletData, transaction.userId);
        
        // Appliquer la transaction au portefeuille
        Wallet updatedWallet = currentWallet.applyTransaction(
          transaction.copyWith(id: transactionRef.id)
        );
        
        // Créer la transaction finale avec l'ID généré
        WalletTransaction finalTransaction = transaction.copyWith(
          id: transactionRef.id,
          status: TransactionStatus.completed,
          processedAt: DateTime.now(),
        );
        
        // Effectuer les mises à jour atomiques
        myCustomPrintStatement('🔶 WALLET_DEBUG: Performing atomic Firestore updates...');
        firestoreTransaction.update(walletRef, updatedWallet.toFirestore());
        firestoreTransaction.set(transactionRef, finalTransaction.toFirestore());
        
        myCustomPrintStatement('🔶 WALLET_DEBUG: Atomic transaction completed - returning finalTransaction');
        return finalTransaction;
      });
      
      myCustomPrintStatement('🔶 WALLET_DEBUG: Firestore transaction completed - result: ${result != null ? result!.id : 'NULL'}');
      
      // Mettre en cache APRÈS la transaction (ne doit pas faire échouer la transaction)
      if (result != null) {
        try {
          // Récupérer le wallet mis à jour pour le cache
          Wallet? updatedWallet = await getWallet(transaction.userId);
          if (updatedWallet != null) {
            await _cacheWallet(updatedWallet);
          }
        } catch (cacheError) {
          myCustomPrintStatement('🔶 WALLET_DEBUG: Warning - Cache update failed but transaction succeeded: $cacheError');
          // Ne pas faire échouer toute l'opération pour un problème de cache
        }
      }
      
      myCustomPrintStatement('🔶 WALLET_DEBUG: _processTransaction returning result: ${result != null ? result!.id : 'NULL'}');
      return result;
    } catch (e) {
      myCustomPrintStatement('🔶 WALLET_DEBUG: EXCEPTION in _processTransaction: $e');
      return null;
    }
  }

  /// Récupère l'historique des transactions d'un utilisateur
  static Future<List<WalletTransaction>> getTransactionHistory({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      myCustomPrintStatement('WalletService.getTransactionHistory: $userId');
      
      Query query = _transactionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      List<WalletTransaction> transactions = snapshot.docs.map((doc) {
        return WalletTransaction.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
      
      return transactions;
    } catch (e) {
      myCustomPrintStatement('Error getting transaction history: $e');
      return [];
    }
  }

  /// Récupère les transactions récentes (avec cache)
  static Future<List<WalletTransaction>> getRecentTransactions(String userId, {int limit = 10}) async {
    try {
      // Vérifier le cache
      List<WalletTransaction>? cachedTransactions = await _getCachedTransactions(userId);
      if (cachedTransactions != null && await _isCacheValid(userId)) {
        return cachedTransactions.take(limit).toList();
      }

      // Charger depuis Firestore
      List<WalletTransaction> transactions = await getTransactionHistory(
        userId: userId,
        limit: limit,
      );
      
      // Mettre en cache
      await _cacheTransactions(userId, transactions);
      
      return transactions;
    } catch (e) {
      myCustomPrintStatement('Error getting recent transactions: $e');
      return [];
    }
  }

  /// Récupère une transaction spécifique
  static Future<WalletTransaction?> getTransaction(String transactionId) async {
    try {
      DocumentSnapshot doc = await _transactionsCollection.doc(transactionId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      return WalletTransaction.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      myCustomPrintStatement('Error getting transaction: $e');
      return null;
    }
  }

  /// Vérifie si un utilisateur a un solde suffisant
  static Future<bool> hasSufficientBalance(String userId, double amount) async {
    try {
      Wallet? wallet = await getWallet(userId);
      return wallet?.hasSufficientBalance(amount) ?? false;
    } catch (e) {
      myCustomPrintStatement('Error checking balance: $e');
      return false;
    }
  }

  /// Active ou désactive un portefeuille
  static Future<bool> setWalletStatus(String userId, bool isActive) async {
    try {
      await _walletsCollection.doc(userId).update({
        'isActive': isActive,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
      
      // Invalider le cache
      await _invalidateCache(userId);
      
      return true;
    } catch (e) {
      myCustomPrintStatement('Error setting wallet status: $e');
      return false;
    }
  }

  /// Écoute les changements en temps réel du portefeuille
  static Stream<Wallet?> watchWallet(String userId) {
    return _walletsCollection.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Wallet wallet = Wallet.fromFirestore(data, userId);
      
      // Mettre en cache de façon asynchrone
      _cacheWallet(wallet);
      
      return wallet;
    });
  }

  /// Écoute les changements en temps réel des transactions
  static Stream<List<WalletTransaction>> watchTransactions(String userId, {int limit = 10}) {
    return _transactionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      List<WalletTransaction> transactions = snapshot.docs.map((doc) {
        return WalletTransaction.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
      
      // Mettre en cache de façon asynchrone
      _cacheTransactions(userId, transactions);
      
      return transactions;
    });
  }

  // === MÉTHODES DE CACHE PRIVÉES ===

  /// Met en cache un portefeuille
  static Future<void> _cacheWallet(Wallet wallet) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_walletCacheKey}${wallet.userId}',
        jsonEncode(wallet.toJson()),
      );
      
      await prefs.setString(
        '${_lastSyncKey}${wallet.userId}',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      myCustomPrintStatement('Error caching wallet: $e');
    }
  }

  /// Récupère un portefeuille du cache
  static Future<Wallet?> _getCachedWallet(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('${_walletCacheKey}$userId');
      if (cachedData != null && cachedData.isNotEmpty) {
        // Note: ici on aurait besoin d'une méthode pour parser le JSON
        // Pour l'instant, on retourne null pour forcer le chargement depuis Firestore
        return null;
      }
      return null;
    } catch (e) {
      myCustomPrintStatement('Error getting cached wallet: $e');
      return null;
    }
  }

  /// Met en cache les transactions
  static Future<void> _cacheTransactions(String userId, List<WalletTransaction> transactions) async {
    try {
      List<Map<String, dynamic>> jsonList = transactions.map((t) => t.toJson()).toList();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_transactionsCacheKey}$userId',
        jsonEncode(jsonList),
      );
    } catch (e) {
      myCustomPrintStatement('Error caching transactions: $e');
    }
  }

  /// Récupère les transactions du cache
  static Future<List<WalletTransaction>?> _getCachedTransactions(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('${_transactionsCacheKey}$userId');
      if (cachedData != null && cachedData.isNotEmpty) {
        // Note: ici on aurait besoin d'une méthode pour parser le JSON
        // Pour l'instant, on retourne null pour forcer le chargement depuis Firestore
        return null;
      }
      return null;
    } catch (e) {
      myCustomPrintStatement('Error getting cached transactions: $e');
      return null;
    }
  }

  /// Vérifie si le cache est valide
  static Future<bool> _isCacheValid(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastSyncStr = prefs.getString('${_lastSyncKey}$userId');
      if (lastSyncStr == null) return false;
      
      DateTime lastSync = DateTime.parse(lastSyncStr);
      return DateTime.now().difference(lastSync) < _cacheValidityDuration;
    } catch (e) {
      return false;
    }
  }

  /// Invalide le cache d'un utilisateur
  static Future<void> _invalidateCache(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_walletCacheKey}$userId');
      await prefs.remove('${_transactionsCacheKey}$userId');
      await prefs.remove('${_lastSyncKey}$userId');
    } catch (e) {
      myCustomPrintStatement('Error invalidating cache: $e');
    }
  }

  /// Nettoie tous les caches
  static Future<void> clearAllCache() async {
    try {
      // Cette méthode devrait être implémentée selon les besoins
      myCustomPrintStatement('Clearing all wallet cache');
    } catch (e) {
      myCustomPrintStatement('Error clearing cache: $e');
    }
  }

  /// Synchronise le cache avec Firestore
  static Future<void> syncCache(String userId) async {
    try {
      await _invalidateCache(userId);
      await getWallet(userId);
      await getRecentTransactions(userId);
    } catch (e) {
      myCustomPrintStatement('Error syncing cache: $e');
    }
  }
}