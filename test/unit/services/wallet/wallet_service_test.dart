import 'package:flutter_test/flutter_test.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/services/wallet_service.dart';

// Note: En production, nous aurions besoin de mocks pour Firebase
// Pour cette démonstration, nous testons la logique métier
void main() {
  group('WalletService Tests', () {
    // Note: Ces tests supposent un environnement de test Firebase configuré
    // En production, nous utiliserions des mocks ou un émulateur Firebase

    test('should validate transaction amounts correctly', () {
      // Test que les contraintes de montant sont respectées
      expect(WalletConstraints.isValidTransactionAmount(100.0), isTrue);
      expect(WalletConstraints.isValidTransactionAmount(50.0), isFalse);
      expect(WalletConstraints.isValidTransactionAmount(1500000.0), isFalse);
    });

    test('should create wallet transaction correctly', () {
      // Test de création d'une transaction de crédit
      final transaction = WalletTransactionHelper.createCreditTransaction(
        userId: 'test_user',
        amount: 1000.0,
        source: PaymentSource.airtelMoney,
        referenceId: 'ref_123',
        description: 'Test credit',
      );

      expect(transaction.userId, equals('test_user'));
      expect(transaction.amount, equals(1000.0));
      expect(transaction.type, equals(TransactionType.credit));
      expect(transaction.source, equals(PaymentSource.airtelMoney));
      expect(transaction.status, equals(TransactionStatus.pending));
      expect(transaction.referenceId, equals('ref_123'));
    });

    test('should create trip payment transaction correctly', () {
      // Test de création d'une transaction de paiement de trajet
      final transaction = WalletTransactionHelper.createTripPaymentTransaction(
        userId: 'test_user',
        amount: 500.0,
        tripId: 'trip_123',
        description: 'Trip payment',
      );

      expect(transaction.userId, equals('test_user'));
      expect(transaction.amount, equals(500.0));
      expect(transaction.type, equals(TransactionType.debit));
      expect(transaction.source, equals(PaymentSource.tripPayment));
      expect(transaction.status, equals(TransactionStatus.pending));
      expect(transaction.tripId, equals('trip_123'));
    });

    test('should validate wallet creation', () {
      // Test de création d'un portefeuille
      const userId = 'test_user_123';
      final wallet = Wallet.createNew(userId);

      expect(wallet.userId, equals(userId));
      expect(wallet.balance, equals(0.0));
      expect(wallet.isActive, isTrue);
      expect(wallet.currency, equals('MGA'));
      expect(wallet.totalTransactions, equals(0));
    });

    test('should apply credit transaction to wallet correctly', () {
      // Test d'application d'une transaction de crédit
      final wallet = Wallet.createNew('test_user');
      final transaction = WalletTransaction(
        id: 'trans_123',
        userId: 'test_user',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Credit test',
      );

      final updatedWallet = wallet.applyTransaction(transaction);

      expect(updatedWallet.balance, equals(1000.0));
      expect(updatedWallet.totalCredits, equals(1000.0));
      expect(updatedWallet.totalTransactions, equals(1));
      expect(updatedWallet.recentTransactionIds, contains('trans_123'));
    });

    test('should apply debit transaction to wallet correctly', () {
      // Test d'application d'une transaction de débit
      final wallet = Wallet(
        userId: 'test_user',
        balance: 1500.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final transaction = WalletTransaction(
        id: 'trans_456',
        userId: 'test_user',
        amount: 500.0,
        type: TransactionType.debit,
        source: PaymentSource.tripPayment,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Trip payment',
      );

      final updatedWallet = wallet.applyTransaction(transaction);

      expect(updatedWallet.balance, equals(1000.0));
      expect(updatedWallet.totalDebits, equals(500.0));
      expect(updatedWallet.totalTransactions, equals(1));
    });

    test('should reject transaction with insufficient balance', () {
      // Test de rejet d'une transaction avec solde insuffisant
      final wallet = Wallet(
        userId: 'test_user',
        balance: 100.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final transaction = WalletTransaction(
        id: 'trans_789',
        userId: 'test_user',
        amount: 500.0,
        type: TransactionType.debit,
        source: PaymentSource.tripPayment,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        description: 'Trip payment',
      );

      expect(() => wallet.applyTransaction(transaction), throwsArgumentError);
    });

    test('should reject credit transaction exceeding max balance', () {
      // Test de rejet d'un crédit dépassant la limite maximale
      final wallet = Wallet(
        userId: 'test_user',
        balance: 4900000.0, // Proche du maximum
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      final transaction = WalletTransaction(
        id: 'trans_999',
        userId: 'test_user',
        amount: 200000.0, // Dépasserait la limite
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        description: 'Credit test',
      );

      expect(() => wallet.applyTransaction(transaction), throwsArgumentError);
    });

    test('should validate balance checking methods', () {
      // Test des méthodes de vérification de solde
      final wallet = Wallet(
        userId: 'test_user',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        minBalance: 100.0,
        maxBalance: 5000000.0,
      );

      // Tests de solde suffisant
      expect(wallet.hasSufficientBalance(500.0), isTrue);
      expect(wallet.hasSufficientBalance(1000.0), isTrue);
      expect(wallet.hasSufficientBalance(1500.0), isFalse);

      // Tests de capacité de crédit
      expect(wallet.canCredit(1000000.0), isTrue);
      expect(wallet.canCredit(5000000.0), isFalse); // Dépasserait le maximum

      // Tests de capacité de débit
      expect(wallet.canDebit(500.0), isTrue);
      expect(wallet.canDebit(900.0), isTrue); // Reste au minimum
      expect(wallet.canDebit(950.0), isFalse); // En dessous du minimum
    });

    test('should handle transaction metadata correctly', () {
      // Test de gestion des métadonnées de transaction
      final metadata = {
        'payment_method': 'airtel_money',
        'phone_number': '0340123456',
        'operator_reference': 'AM_REF_123',
      };

      final transaction = WalletTransaction(
        id: 'trans_meta',
        userId: 'test_user',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Credit with metadata',
        metadata: metadata,
      );

      expect(transaction.metadata, isNotNull);
      expect(transaction.metadata!['payment_method'], equals('airtel_money'));
      expect(transaction.metadata!['phone_number'], equals('0340123456'));
      expect(transaction.metadata!['operator_reference'], equals('AM_REF_123'));
    });

    test('should track recent transactions correctly', () {
      // Test du suivi des transactions récentes
      var wallet = Wallet.createNew('test_user');

      // Ajouter plusieurs transactions
      for (int i = 1; i <= 12; i++) {
        final transaction = WalletTransaction(
          id: 'trans_$i',
          userId: 'test_user',
          amount: 100.0,
          type: TransactionType.credit,
          source: PaymentSource.airtelMoney,
          status: TransactionStatus.completed,
          timestamp: DateTime.now(),
          description: 'Transaction $i',
        );

        wallet = wallet.applyTransaction(transaction);
      }

      // Vérifier que seules les 10 dernières sont conservées
      expect(wallet.recentTransactionIds.length, equals(10));
      expect(wallet.recentTransactionIds.first, equals('trans_12')); // Plus récent
      expect(wallet.recentTransactionIds.last, equals('trans_3')); // Plus ancien conservé
      expect(wallet.recentTransactionIds.contains('trans_1'), isFalse); // Supprimé
    });

    test('should calculate wallet statistics correctly', () {
      // Test du calcul des statistiques
      final wallet = Wallet(
        userId: 'test_user',
        balance: 2500000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
        totalTransactions: 15,
        totalCredits: 3000000.0,
        totalDebits: 500000.0,
      );

      final stats = WalletHelper.calculateStats(wallet);

      expect(stats['balancePercentage'], equals(0.5)); // 50% du maximum
      expect(stats['availableCredit'], equals(2500000.0)); // Espace restant
      expect(stats['availableDebit'], equals(2500000.0)); // Montant disponible
      expect(stats['totalTransactions'], equals(15));
      expect(stats['netAmount'], equals(2500000.0)); // Crédits - débits
    });

    test('should suggest appropriate credit amounts', () {
      // Test des suggestions de crédit
      
      // Portefeuille avec solde faible
      final lowBalanceWallet = Wallet(
        userId: 'test_user',
        balance: 5000.0, // Solde faible
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      final suggestedLow = WalletHelper.suggestCreditAmount(lowBalanceWallet);
      expect(suggestedLow, equals(45000.0)); // 50,000 - 5,000

      // Portefeuille avec solde suffisant
      final sufficientBalanceWallet = Wallet(
        userId: 'test_user',
        balance: 100000.0, // Solde suffisant
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      final suggestedSufficient = WalletHelper.suggestCreditAmount(sufficientBalanceWallet);
      expect(suggestedSufficient, equals(0.0)); // Pas de suggestion
    });

    test('should format currency amounts correctly', () {
      // Test du formatage des montants
      expect(WalletHelper.formatAmount(500.0), equals('500 MGA'));
      expect(WalletHelper.formatAmount(1234.0), equals('1.2K MGA'));
      expect(WalletHelper.formatAmount(1500000.0), equals('1.5M MGA'));
      expect(WalletHelper.formatAmount(2500000.0), equals('2.5M MGA'));
    });

    test('should handle transaction status transitions', () {
      // Test des transitions de statut de transaction
      final pendingTransaction = WalletTransaction(
        id: 'trans_pending',
        userId: 'test_user',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        description: 'Pending transaction',
      );

      final completedTransaction = pendingTransaction.copyWith(
        status: TransactionStatus.completed,
        processedAt: DateTime.now(),
      );

      expect(pendingTransaction.isPending, isTrue);
      expect(pendingTransaction.isFinalized, isFalse);
      expect(pendingTransaction.isSuccessful, isFalse);

      expect(completedTransaction.isPending, isFalse);
      expect(completedTransaction.isFinalized, isTrue);
      expect(completedTransaction.isSuccessful, isTrue);
    });

    test('should validate transaction reference IDs', () {
      // Test de validation des IDs de référence
      final transaction = WalletTransaction(
        id: 'trans_ref',
        userId: 'test_user',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Transaction with reference',
        referenceId: 'AIRTEL_REF_123456',
      );

      expect(transaction.referenceId, isNotNull);
      expect(transaction.referenceId, equals('AIRTEL_REF_123456'));

      // Test de sérialisation avec référence
      final json = transaction.toJson();
      final recreated = WalletTransaction.fromJson(json);
      expect(recreated.referenceId, equals('AIRTEL_REF_123456'));
    });

    test('should handle error cases in transaction creation', () {
      // Test de gestion d'erreurs lors de la création de transactions
      
      // Montant invalide
      expect(
        () => WalletTransactionHelper.createCreditTransaction(
          userId: 'test_user',
          amount: -100.0, // Montant négatif
          source: PaymentSource.airtelMoney,
          referenceId: 'ref_123',
        ),
        isNot(throwsException), // La validation se fait au niveau du service
      );

      // User ID vide
      final invalidTransaction = WalletTransactionHelper.createCreditTransaction(
        userId: '', // User ID vide
        amount: 1000.0,
        source: PaymentSource.airtelMoney,
        referenceId: 'ref_123',
      );

      expect(WalletTransactionHelper.isValidTransaction(invalidTransaction), isFalse);
    });
  });

  group('WalletService Integration Tests', () {
    // Ces tests nécessiteraient un émulateur Firebase ou des mocks
    // Pour l'instant, nous testons la logique sans dépendances externes

    test('should validate service operations', () {
      // Test que le service peut être instancié et que ses méthodes existent
      // En production, nous testerions avec un émulateur Firebase

      // Vérifier que les méthodes publiques sont disponibles
      expect(WalletService.getWallet, isA<Function>());
      expect(WalletService.createWallet, isA<Function>());
      expect(WalletService.creditWallet, isA<Function>());
      expect(WalletService.debitWallet, isA<Function>());
      expect(WalletService.getTransactionHistory, isA<Function>());
      expect(WalletService.hasSufficientBalance, isA<Function>());
    });

    test('should validate cache operations', () {
      // Test des opérations de cache (structure)
      expect(WalletService.clearAllCache, isA<Function>());
      expect(WalletService.syncCache, isA<Function>());
    });

    test('should validate real-time operations', () {
      // Test des opérations temps réel (structure)
      expect(WalletService.watchWallet, isA<Function>());
      expect(WalletService.watchTransactions, isA<Function>());
    });
  });

  group('Edge Cases and Error Handling', () {
    test('should handle concurrent transaction attempts', () {
      // Test de gestion des tentatives de transaction concurrentes
      // En production, ceci serait géré par les transactions atomiques Firestore
      
      final wallet = Wallet(
        userId: 'test_user',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Deux transactions de débit simultanées qui dépasseraient le solde
      final transaction1 = WalletTransaction(
        id: 'trans_1',
        userId: 'test_user',
        amount: 600.0,
        type: TransactionType.debit,
        source: PaymentSource.tripPayment,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        description: 'First transaction',
      );

      final transaction2 = WalletTransaction(
        id: 'trans_2',
        userId: 'test_user',
        amount: 600.0,
        type: TransactionType.debit,
        source: PaymentSource.tripPayment,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        description: 'Second transaction',
      );

      // La première transaction devrait réussir
      final walletAfterFirst = wallet.applyTransaction(transaction1);
      expect(walletAfterFirst.balance, equals(400.0));

      // La deuxième transaction devrait échouer (solde insuffisant)
      expect(() => walletAfterFirst.applyTransaction(transaction2), throwsArgumentError);
    });

    test('should handle wallet state consistency', () {
      // Test de cohérence de l'état du portefeuille
      var wallet = Wallet.createNew('test_user');

      // Série de transactions
      final transactions = [
        WalletTransaction(
          id: 'credit_1',
          userId: 'test_user',
          amount: 1000.0,
          type: TransactionType.credit,
          source: PaymentSource.airtelMoney,
          status: TransactionStatus.completed,
          timestamp: DateTime.now(),
          description: 'Initial credit',
        ),
        WalletTransaction(
          id: 'debit_1',
          userId: 'test_user',
          amount: 300.0,
          type: TransactionType.debit,
          source: PaymentSource.tripPayment,
          status: TransactionStatus.completed,
          timestamp: DateTime.now(),
          description: 'Trip payment',
        ),
        WalletTransaction(
          id: 'credit_2',
          userId: 'test_user',
          amount: 500.0,
          type: TransactionType.credit,
          source: PaymentSource.orangeMoney,
          status: TransactionStatus.completed,
          timestamp: DateTime.now(),
          description: 'Second credit',
        ),
      ];

      // Appliquer toutes les transactions
      for (final transaction in transactions) {
        wallet = wallet.applyTransaction(transaction);
      }

      // Vérifier la cohérence
      expect(wallet.balance, equals(1200.0)); // 1000 - 300 + 500
      expect(wallet.totalCredits, equals(1500.0)); // 1000 + 500
      expect(wallet.totalDebits, equals(300.0));
      expect(wallet.totalTransactions, equals(3));
      expect(wallet.recentTransactionIds.length, equals(3));
    });

    test('should handle invalid transaction data', () {
      // Test de gestion des données de transaction invalides
      
      // Transaction avec user ID différent
      final wallet = Wallet.createNew('user_1');
      final wrongUserTransaction = WalletTransaction(
        id: 'wrong_user',
        userId: 'user_2', // Différent de celui du portefeuille
        amount: 500.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Wrong user transaction',
      );

      expect(() => wallet.applyTransaction(wrongUserTransaction), throwsArgumentError);
    });

    test('should handle boundary conditions', () {
      // Test des conditions limites
      
      // Portefeuille à la limite maximale
      final maxWallet = Wallet(
        userId: 'test_user',
        balance: 5000000.0, // Maximum
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      expect(maxWallet.canCredit(1.0), isFalse); // Aucun crédit possible
      expect(maxWallet.creditCapacity, equals(0.0));

      // Portefeuille à la limite minimale
      final minWallet = Wallet(
        userId: 'test_user',
        balance: 100.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        minBalance: 100.0,
      );

      expect(minWallet.canDebit(1.0), isFalse); // Aucun débit possible
      expect(minWallet.availableBalance, equals(0.0));
    });
  });
}