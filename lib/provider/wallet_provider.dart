import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/services/wallet_service.dart';
import 'package:rider_ride_hailing_app/services/feature_toggle_service.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

/// États possibles du portefeuille
enum WalletState {
  initial,
  loading,
  loaded,
  error,
  processing,
}

/// Types d'actions du portefeuille
enum WalletAction {
  none,
  crediting,
  debiting,
  loadingHistory,
  refreshing,
}

/// Provider pour la gestion d'état du portefeuille numérique
/// Suit les conventions de l'architecture Misy (voir TripProvider)
class WalletProvider extends ChangeNotifier {
  // === ÉTAT DU PORTEFEUILLE ===
  WalletState _state = WalletState.initial;
  WalletAction _currentAction = WalletAction.none;
  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  String? _errorMessage;
  bool _hasMoreTransactions = true;

  // === STREAMS ET SUBSCRIPTIONS ===
  StreamSubscription<Wallet?>? _walletSubscription;
  StreamSubscription<List<WalletTransaction>>? _transactionsSubscription;

  // === GETTERS PUBLICS ===
  WalletState get state => _state;
  WalletAction get currentAction => _currentAction;
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);
  String? get errorMessage => _errorMessage;
  bool get hasMoreTransactions => _hasMoreTransactions;
  
  // Getters de commodité
  bool get isLoading => _state == WalletState.loading;
  bool get isLoaded => _state == WalletState.loaded;
  bool get hasError => _state == WalletState.error;
  bool get isProcessing => _state == WalletState.processing;
  bool get isCrediting => _currentAction == WalletAction.crediting;
  bool get isDebiting => _currentAction == WalletAction.debiting;
  
  double get balance => _wallet?.balance ?? 0.0;
  String get formattedBalance => _wallet?.formattedBalance ?? '0 MGA';
  bool get hasLowBalance => _wallet?.hasLowBalance ?? false;
  bool get isWalletActive => _wallet?.isActive ?? false;

  /// Initialise le provider pour un utilisateur
  Future<void> initializeWallet(String userId) async {
    // Garde de sécurité : vérifier si la fonctionnalité est activée
    if (!FeatureToggleService.instance.isDigitalWalletEnabled()) {
      myCustomPrintStatement('WalletProvider.initializeWallet: Digital wallet is disabled, skipping initialization');
      _setError('Le portefeuille numérique n\'est pas disponible');
      return;
    }
    
    try {
      myCustomPrintStatement('WalletProvider.initializeWallet: $userId');
      
      _setState(WalletState.loading);
      _clearError();
      
      // Charger le portefeuille depuis le service
      Wallet? wallet = await WalletService.getWallet(userId);
      
      if (wallet == null) {
        // Créer un nouveau portefeuille si il n'existe pas
        wallet = await WalletService.createWallet(userId);
      }
      
      if (wallet != null) {
        _wallet = wallet;
        _setState(WalletState.loaded);
        
        // Charger les transactions récentes
        await loadRecentTransactions(userId);
        
        // Démarrer l'écoute en temps réel
        _startRealtimeListeners(userId);
      } else {
        _setError('Impossible de charger le portefeuille');
      }
    } catch (e) {
      myCustomPrintStatement('Error initializing wallet: $e');
      _setError('Erreur lors de l\'initialisation: $e');
    }
  }

  /// Crédite le portefeuille via mobile money
  Future<bool> creditWallet({
    required String userId,
    required double amount,
    required PaymentSource source,
    required String referenceId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    // Garde de sécurité : vérifier si la fonctionnalité est activée
    if (!FeatureToggleService.instance.isDigitalWalletEnabled()) {
      myCustomPrintStatement('WalletProvider.creditWallet: Digital wallet is disabled');
      _setError('Le portefeuille numérique n\'est pas disponible');
      return false;
    }
    
    try {
      myCustomPrintStatement('WalletProvider.creditWallet: $amount via $source');
      
      _setAction(WalletAction.crediting);
      _clearError();
      
      // Valider le montant
      if (!WalletConstraints.isValidTransactionAmount(amount)) {
        _setError('Montant invalide: ${WalletConstraints.minimumTransactionAmount} - ${WalletConstraints.maximumTransactionAmount} MGA');
        return false;
      }
      
      // Vérifier la capacité du portefeuille
      if (_wallet != null && !_wallet!.canCredit(amount)) {
        _setError('Impossible de créditer: limite maximale atteinte');
        return false;
      }
      
      // Effectuer la transaction
      WalletTransaction? transaction = await WalletService.creditWallet(
        userId: userId,
        amount: amount,
        source: source,
        referenceId: referenceId,
        description: description ?? 'Crédit de portefeuille',
        metadata: metadata,
      );
      
      if (transaction != null) {
        _showSuccessMessage('Portefeuille crédité avec succès: ${WalletHelper.formatAmount(amount)}');
        _setAction(WalletAction.none);
        return true;
      } else {
        _setError('Échec du crédit du portefeuille');
        return false;
      }
    } catch (e) {
      myCustomPrintStatement('Error crediting wallet: $e');
      _setError('Erreur lors du crédit: $e');
      return false;
    }
  }

  /// Débite le portefeuille pour un paiement
  Future<bool> debitWallet({
    required String userId,
    required double amount,
    String? tripId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    // Garde de sécurité : vérifier si la fonctionnalité est activée
    if (!FeatureToggleService.instance.isDigitalWalletEnabled()) {
      myCustomPrintStatement('WalletProvider.debitWallet: Digital wallet is disabled');
      _setError('Le portefeuille numérique n\'est pas disponible');
      return false;
    }
    
    try {
      myCustomPrintStatement('🔶 WALLET_DEBUG: WalletProvider.debitWallet called with amount: $amount, tripId: $tripId');
      
      _setAction(WalletAction.debiting);
      _clearError();
      
      // Valider le montant
      if (!WalletConstraints.isValidTransactionAmount(amount)) {
        myCustomPrintStatement('🔶 WALLET_DEBUG: Invalid amount: $amount');
        _setError('Montant invalide');
        return false;
      }
      myCustomPrintStatement('🔶 WALLET_DEBUG: Amount validation passed');
      
      // Vérifier le solde suffisant
      if (_wallet == null || !_wallet!.canDebit(amount)) {
        myCustomPrintStatement('🔶 WALLET_DEBUG: Insufficient balance - current: ${_wallet?.balance ?? 0}, required: $amount');
        _setError('Solde insuffisant');
        return false;
      }
      myCustomPrintStatement('🔶 WALLET_DEBUG: Balance check passed - current: ${_wallet!.balance}');
      
      // Effectuer la transaction
      myCustomPrintStatement('🔶 WALLET_DEBUG: Calling WalletService.debitWallet...');
      WalletTransaction? transaction = await WalletService.debitWallet(
        userId: userId,
        amount: amount,
        tripId: tripId,
        description: description ?? 'Paiement de trajet',
        metadata: metadata,
      );
      
      myCustomPrintStatement('🔶 WALLET_DEBUG: WalletService.debitWallet returned transaction: ${transaction != null ? transaction!.id : 'NULL'}');
      
      if (transaction != null) {
        myCustomPrintStatement('🔶 WALLET_DEBUG: Transaction SUCCESS - returning true');
        _showSuccessMessage('Paiement effectué: ${WalletHelper.formatAmount(amount)}');
        _setAction(WalletAction.none);
        return true;
      } else {
        myCustomPrintStatement('🔶 WALLET_DEBUG: Transaction FAILED - WalletService returned null - returning false');
        _setError('Échec du paiement');
        return false;
      }
    } catch (e) {
      myCustomPrintStatement('🔶 WALLET_DEBUG: EXCEPTION in WalletProvider.debitWallet: $e');
      _setError('Erreur lors du débit: $e');
      return false;
    }
  }

  /// Vérifie si le solde est suffisant pour un montant
  bool hasSufficientBalance(double amount) {
    return _wallet?.hasSufficientBalance(amount) ?? false;
  }

  /// Charge les transactions récentes
  Future<void> loadRecentTransactions(String userId, {bool refresh = false}) async {
    try {
      if (refresh) {
        _setAction(WalletAction.refreshing);
      } else {
        _setAction(WalletAction.loadingHistory);
      }
      
      List<WalletTransaction> newTransactions = await WalletService.getRecentTransactions(
        userId,
        limit: 20,
      );
      
      if (refresh) {
        _transactions = newTransactions;
      } else {
        _transactions.addAll(newTransactions);
      }
      
      _hasMoreTransactions = newTransactions.length >= 20;
      _setAction(WalletAction.none);
      
      notifyListeners();
    } catch (e) {
      myCustomPrintStatement('Error loading transactions: $e');
      _setError('Erreur lors du chargement de l\'historique');
    }
  }

  /// Charge plus de transactions (pagination)
  Future<void> loadMoreTransactions(String userId) async {
    if (!_hasMoreTransactions || _currentAction == WalletAction.loadingHistory) {
      return;
    }
    
    try {
      _setAction(WalletAction.loadingHistory);
      
      List<WalletTransaction> moreTransactions = await WalletService.getTransactionHistory(
        userId: userId,
        limit: 20,
        // startAfter: _transactions.isNotEmpty ? lastTransaction : null,
      );
      
      _transactions.addAll(moreTransactions);
      _hasMoreTransactions = moreTransactions.length >= 20;
      _setAction(WalletAction.none);
      
      notifyListeners();
    } catch (e) {
      myCustomPrintStatement('Error loading more transactions: $e');
      _setError('Erreur lors du chargement');
    }
  }

  /// Actualise le portefeuille et les transactions
  Future<void> refreshWallet(String userId) async {
    try {
      _setAction(WalletAction.refreshing);
      
      // Synchroniser le cache
      await WalletService.syncCache(userId);
      
      // Recharger les données
      await loadRecentTransactions(userId, refresh: true);
      
      _setAction(WalletAction.none);
    } catch (e) {
      myCustomPrintStatement('Error refreshing wallet: $e');
      _setError('Erreur lors de l\'actualisation');
    }
  }

  /// Démarre l'écoute en temps réel des changements
  void _startRealtimeListeners(String userId) {
    try {
      // Écouter les changements du portefeuille
      _walletSubscription?.cancel();
      _walletSubscription = WalletService.watchWallet(userId).listen(
        (wallet) {
          if (wallet != null) {
            _wallet = wallet;
            notifyListeners();
          }
        },
        onError: (error) {
          myCustomPrintStatement('Wallet stream error: $error');
        },
      );
      
      // Écouter les nouvelles transactions
      _transactionsSubscription?.cancel();
      _transactionsSubscription = WalletService.watchTransactions(userId, limit: 10).listen(
        (transactions) {
          // Mettre à jour seulement les 10 premières transactions pour éviter la duplication
          if (transactions.isNotEmpty) {
            _transactions = transactions + _transactions.skip(10).toList();
            notifyListeners();
          }
        },
        onError: (error) {
          myCustomPrintStatement('Transactions stream error: $error');
        },
      );
    } catch (e) {
      myCustomPrintStatement('Error starting realtime listeners: $e');
    }
  }

  /// Arrête l'écoute en temps réel
  void stopRealtimeListeners() {
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _walletSubscription = null;
    _transactionsSubscription = null;
  }

  /// Calcule les statistiques du portefeuille
  Map<String, dynamic> getWalletStats() {
    if (_wallet == null) return {};
    return WalletHelper.calculateStats(_wallet!);
  }

  /// Suggère un montant de crédit optimal
  double getSuggestedCreditAmount() {
    if (_wallet == null) return 0.0;
    return WalletHelper.suggestCreditAmount(_wallet!);
  }

  /// Filtre les transactions par type
  List<WalletTransaction> getTransactionsByType(TransactionType type) {
    return _transactions.where((t) => t.type == type).toList();
  }

  /// Filtre les transactions par source
  List<WalletTransaction> getTransactionsBySource(PaymentSource source) {
    return _transactions.where((t) => t.source == source).toList();
  }

  /// Obtient les transactions du jour
  List<WalletTransaction> getTodayTransactions() {
    DateTime today = DateTime.now();
    return _transactions.where((t) {
      return t.timestamp.year == today.year &&
             t.timestamp.month == today.month &&
             t.timestamp.day == today.day;
    }).toList();
  }

  // === MÉTHODES PRIVÉES DE GESTION D'ÉTAT ===

  void _setState(WalletState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _setAction(WalletAction newAction) {
    if (_currentAction != newAction) {
      _currentAction = newAction;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    _setState(WalletState.error);
    _setAction(WalletAction.none);
    
    // Afficher le message d'erreur
    if (MyGlobalKeys.navigatorKey.currentContext != null) {
      showSnackbar(error);
    }
  }

  void _clearError() {
    _errorMessage = null;
    if (_state == WalletState.error) {
      _setState(WalletState.initial);
    }
  }

  void _showSuccessMessage(String message) {
    if (MyGlobalKeys.navigatorKey.currentContext != null) {
      showSnackbar(message);
    }
  }

  // === NETTOYAGE ===

  @override
  void dispose() {
    stopRealtimeListeners();
    super.dispose();
  }

  /// Réinitialise le provider
  void reset() {
    stopRealtimeListeners();
    _state = WalletState.initial;
    _currentAction = WalletAction.none;
    _wallet = null;
    _transactions.clear();
    _errorMessage = null;
    _hasMoreTransactions = true;
    notifyListeners();
  }

  /// Debug: affiche l'état actuel
  void debugPrintState() {
    myCustomPrintStatement('=== WALLET PROVIDER STATE ===');
    myCustomPrintStatement('State: $_state');
    myCustomPrintStatement('Action: $_currentAction');
    myCustomPrintStatement('Balance: ${_wallet?.balance ?? 'null'}');
    myCustomPrintStatement('Transactions: ${_transactions.length}');
    myCustomPrintStatement('Error: $_errorMessage');
    myCustomPrintStatement('=============================');
  }
}

/// Extension pour faciliter l'utilisation du provider
extension WalletProviderExtension on WalletProvider {
  /// Vérifie si une action spécifique est en cours
  bool isActionInProgress(WalletAction action) {
    return _currentAction == action;
  }
  
  /// Retourne les transactions en attente
  List<WalletTransaction> get pendingTransactions {
    return _transactions.where((t) => t.isPending).toList();
  }
  
  /// Retourne les transactions réussies
  List<WalletTransaction> get successfulTransactions {
    return _transactions.where((t) => t.isSuccessful).toList();
  }
  
  /// Retourne le montant total des crédits du jour
  double get todayCredits {
    return getTodayTransactions()
        .where((t) => t.type == TransactionType.credit && t.isSuccessful)
        .fold(0.0, (sum, t) => sum + t.amount);
  }
  
  /// Retourne le montant total des débits du jour
  double get todayDebits {
    return getTodayTransactions()
        .where((t) => t.type == TransactionType.debit && t.isSuccessful)
        .fold(0.0, (sum, t) => sum + t.amount);
  }
}