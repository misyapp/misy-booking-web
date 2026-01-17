import 'package:flutter_test/flutter_test.dart';
import 'package:rider_ride_hailing_app/models/wallet.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';

void main() {
  group('WalletTransaction Tests', () {
    test('should create a transaction with required fields', () {
      // Arrange
      final transaction = WalletTransaction(
        id: 'test_id',
        userId: 'user_123',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Test transaction',
      );

      // Assert
      expect(transaction.id, equals('test_id'));
      expect(transaction.userId, equals('user_123'));
      expect(transaction.amount, equals(1000.0));
      expect(transaction.type, equals(TransactionType.credit));
      expect(transaction.source, equals(PaymentSource.airtelMoney));
      expect(transaction.status, equals(TransactionStatus.completed));
      expect(transaction.description, equals('Test transaction'));
    });

    test('should correctly identify if transaction is finalized', () {
      // Arrange
      final completedTransaction = WalletTransaction(
        id: 'test_id',
        userId: 'user_123',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Test transaction',
      );

      final pendingTransaction = WalletTransaction(
        id: 'test_id_2',
        userId: 'user_123',
        amount: 500.0,
        type: TransactionType.debit,
        source: PaymentSource.tripPayment,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        description: 'Pending transaction',
      );

      // Assert
      expect(completedTransaction.isFinalized, isTrue);
      expect(completedTransaction.isSuccessful, isTrue);
      expect(completedTransaction.isPending, isFalse);

      expect(pendingTransaction.isFinalized, isFalse);
      expect(pendingTransaction.isSuccessful, isFalse);
      expect(pendingTransaction.isPending, isTrue);
    });

    test('should return correct signed amount', () {
      // Arrange
      final creditTransaction = WalletTransaction(
        id: 'credit_id',
        userId: 'user_123',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Credit transaction',
      );

      final debitTransaction = WalletTransaction(
        id: 'debit_id',
        userId: 'user_123',
        amount: 500.0,
        type: TransactionType.debit,
        source: PaymentSource.tripPayment,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Debit transaction',
      );

      // Assert
      expect(creditTransaction.signedAmount, equals(1000.0));
      expect(debitTransaction.signedAmount, equals(-500.0));
    });

    // Note: Tests for private methods removed - testing through public interface instead

    test('should convert to and from JSON correctly', () {
      // Arrange
      final transaction = WalletTransaction(
        id: 'test_id',
        userId: 'user_123',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        description: 'Test transaction',
        referenceId: 'ref_123',
        metadata: {'key': 'value'},
      );

      // Act
      final json = transaction.toJson();
      final recreatedTransaction = WalletTransaction.fromJson(json);

      // Assert
      expect(recreatedTransaction.id, equals(transaction.id));
      expect(recreatedTransaction.userId, equals(transaction.userId));
      expect(recreatedTransaction.amount, equals(transaction.amount));
      expect(recreatedTransaction.type, equals(transaction.type));
      expect(recreatedTransaction.source, equals(transaction.source));
      expect(recreatedTransaction.status, equals(transaction.status));
      expect(recreatedTransaction.description, equals(transaction.description));
      expect(recreatedTransaction.referenceId, equals(transaction.referenceId));
      expect(recreatedTransaction.metadata, equals(transaction.metadata));
    });

    test('should create credit transaction with helper method', () {
      // Act
      final transaction = WalletTransactionHelper.createCreditTransaction(
        userId: 'user_123',
        amount: 1000.0,
        source: PaymentSource.airtelMoney,
        referenceId: 'ref_123',
        description: 'Credit via Airtel Money',
      );

      // Assert
      expect(transaction.userId, equals('user_123'));
      expect(transaction.amount, equals(1000.0));
      expect(transaction.type, equals(TransactionType.credit));
      expect(transaction.source, equals(PaymentSource.airtelMoney));
      expect(transaction.status, equals(TransactionStatus.pending));
      expect(transaction.referenceId, equals('ref_123'));
      expect(transaction.description, equals('Credit via Airtel Money'));
    });

    test('should create trip payment transaction with helper method', () {
      // Act
      final transaction = WalletTransactionHelper.createTripPaymentTransaction(
        userId: 'user_123',
        amount: 500.0,
        tripId: 'trip_456',
        description: 'Payment for trip',
      );

      // Assert
      expect(transaction.userId, equals('user_123'));
      expect(transaction.amount, equals(500.0));
      expect(transaction.type, equals(TransactionType.debit));
      expect(transaction.source, equals(PaymentSource.tripPayment));
      expect(transaction.status, equals(TransactionStatus.pending));
      expect(transaction.tripId, equals('trip_456'));
      expect(transaction.description, equals('Payment for trip'));
    });

    test('should validate transaction correctly', () {
      // Arrange
      final validTransaction = WalletTransaction(
        id: 'valid_id',
        userId: 'user_123',
        amount: 1000.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        description: 'Valid transaction',
      );

      final invalidTransaction = WalletTransaction(
        id: 'invalid_id',
        userId: '', // Empty user ID
        amount: -100.0, // Negative amount
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        description: '', // Empty description
      );

      // Act & Assert
      expect(WalletTransactionHelper.isValidTransaction(validTransaction), isTrue);
      expect(WalletTransactionHelper.isValidTransaction(invalidTransaction), isFalse);
    });
  });

  group('Wallet Tests', () {
    test('should create a wallet with required fields', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Assert
      expect(wallet.userId, equals('user_123'));
      expect(wallet.balance, equals(1000.0));
      expect(wallet.isActive, isTrue); // Default value
      expect(wallet.currency, equals('MGA')); // Default value
      expect(wallet.minBalance, equals(0.0)); // Default value
      expect(wallet.maxBalance, equals(5000000.0)); // Default value
    });

    test('should create new wallet for user', () {
      // Act
      final wallet = Wallet.createNew('user_123');

      // Assert
      expect(wallet.userId, equals('user_123'));
      expect(wallet.balance, equals(0.0));
      expect(wallet.isActive, isTrue);
      expect(wallet.currency, equals('MGA'));
      expect(wallet.totalTransactions, equals(0));
      expect(wallet.totalCredits, equals(0.0));
      expect(wallet.totalDebits, equals(0.0));
    });

    test('should check sufficient balance correctly', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Assert
      expect(wallet.hasSufficientBalance(500.0), isTrue);
      expect(wallet.hasSufficientBalance(1000.0), isTrue);
      expect(wallet.hasSufficientBalance(1500.0), isFalse);
      expect(wallet.hasSufficientBalance(-100.0), isFalse);
    });

    test('should check credit capacity correctly', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 4500000.0, // Close to max
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      // Assert
      expect(wallet.canCredit(400000.0), isTrue); // Within capacity
      expect(wallet.canCredit(600000.0), isFalse); // Exceeds capacity
      expect(wallet.canCredit(-100.0), isFalse); // Negative amount
    });

    test('should check debit capacity correctly', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        minBalance: 100.0,
      );

      // Assert
      expect(wallet.canDebit(500.0), isTrue); // Within balance
      expect(wallet.canDebit(900.0), isTrue); // Exactly at min balance
      expect(wallet.canDebit(950.0), isFalse); // Below min balance
      expect(wallet.canDebit(1500.0), isFalse); // Exceeds balance
    });

    test('should apply credit transaction correctly', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        totalCredits: 1000.0,
        totalTransactions: 1,
      );

      final transaction = WalletTransaction(
        id: 'trans_123',
        userId: 'user_123',
        amount: 500.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Credit transaction',
      );

      // Act
      final updatedWallet = wallet.applyTransaction(transaction);

      // Assert
      expect(updatedWallet.balance, equals(1500.0));
      expect(updatedWallet.totalCredits, equals(1500.0));
      expect(updatedWallet.totalTransactions, equals(2));
      expect(updatedWallet.recentTransactionIds, contains('trans_123'));
    });

    test('should apply debit transaction correctly', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        totalDebits: 0.0,
        totalTransactions: 1,
      );

      final transaction = WalletTransaction(
        id: 'trans_456',
        userId: 'user_123',
        amount: 300.0,
        type: TransactionType.debit,
        source: PaymentSource.tripPayment,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Trip payment',
      );

      // Act
      final updatedWallet = wallet.applyTransaction(transaction);

      // Assert
      expect(updatedWallet.balance, equals(700.0));
      expect(updatedWallet.totalDebits, equals(300.0));
      expect(updatedWallet.totalTransactions, equals(2));
      expect(updatedWallet.recentTransactionIds, contains('trans_456'));
    });

    test('should throw error when applying transaction with wrong user ID', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final transaction = WalletTransaction(
        id: 'trans_123',
        userId: 'different_user', // Wrong user ID
        amount: 500.0,
        type: TransactionType.credit,
        source: PaymentSource.airtelMoney,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        description: 'Credit transaction',
      );

      // Act & Assert
      expect(
        () => wallet.applyTransaction(transaction),
        throwsArgumentError,
      );
    });

    test('should detect low balance correctly', () {
      // Arrange
      final lowBalanceWallet = Wallet(
        userId: 'user_123',
        balance: 5000.0, // Below 10,000 threshold
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final highBalanceWallet = Wallet(
        userId: 'user_456',
        balance: 50000.0, // Above 10,000 threshold
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Assert
      expect(lowBalanceWallet.hasLowBalance, isTrue);
      expect(highBalanceWallet.hasLowBalance, isFalse);
    });

    test('should detect near max balance correctly', () {
      // Arrange
      final nearMaxWallet = Wallet(
        userId: 'user_123',
        balance: 4600000.0, // 92% of 5M
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      final normalWallet = Wallet(
        userId: 'user_456',
        balance: 1000000.0, // 20% of 5M
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      // Assert
      expect(nearMaxWallet.isNearMaxBalance, isTrue); // 92% > 90%
      expect(normalWallet.isNearMaxBalance, isFalse); // 20% < 90%
    });

    test('should format balance correctly', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 1234567.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Assert
      expect(wallet.formattedBalance, equals('1234567 MGA'));
    });

    test('should convert to and from JSON correctly', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 1000.0,
        lastUpdated: DateTime(2024, 1, 1, 12, 0, 0),
        createdAt: DateTime(2024, 1, 1, 10, 0, 0),
        isActive: true,
        currency: 'MGA',
        minBalance: 0.0,
        maxBalance: 5000000.0,
        recentTransactionIds: ['trans_1', 'trans_2'],
        totalTransactions: 2,
        totalCredits: 1500.0,
        totalDebits: 500.0,
      );

      // Act
      final json = wallet.toJson();
      final recreatedWallet = Wallet.fromJson(json);

      // Assert
      expect(recreatedWallet.userId, equals(wallet.userId));
      expect(recreatedWallet.balance, equals(wallet.balance));
      expect(recreatedWallet.isActive, equals(wallet.isActive));
      expect(recreatedWallet.currency, equals(wallet.currency));
      expect(recreatedWallet.minBalance, equals(wallet.minBalance));
      expect(recreatedWallet.maxBalance, equals(wallet.maxBalance));
      expect(recreatedWallet.recentTransactionIds, equals(wallet.recentTransactionIds));
      expect(recreatedWallet.totalTransactions, equals(wallet.totalTransactions));
      expect(recreatedWallet.totalCredits, equals(wallet.totalCredits));
      expect(recreatedWallet.totalDebits, equals(wallet.totalDebits));
    });
  });

  group('WalletConstraints Tests', () {
    test('should validate transaction amounts correctly', () {
      // Assert
      expect(WalletConstraints.isValidTransactionAmount(100.0), isTrue); // Minimum
      expect(WalletConstraints.isValidTransactionAmount(1000000.0), isTrue); // Maximum
      expect(WalletConstraints.isValidTransactionAmount(500000.0), isTrue); // Middle
      expect(WalletConstraints.isValidTransactionAmount(50.0), isFalse); // Below minimum
      expect(WalletConstraints.isValidTransactionAmount(1500000.0), isFalse); // Above maximum
      expect(WalletConstraints.isValidTransactionAmount(-100.0), isFalse); // Negative
    });

    test('should validate wallet limits correctly', () {
      // Assert
      expect(WalletConstraints.isValidWalletLimits(0.0, 1000000.0), isTrue); // Valid
      expect(WalletConstraints.isValidWalletLimits(100.0, 5000000.0), isTrue); // Valid
      expect(WalletConstraints.isValidWalletLimits(-100.0, 1000000.0), isFalse); // Negative min
      expect(WalletConstraints.isValidWalletLimits(1000.0, 500.0), isFalse); // Min > Max
      expect(WalletConstraints.isValidWalletLimits(0.0, 10000000.0), isFalse); // Max too high
    });

    test('should validate complete wallet correctly', () {
      // Arrange
      final validWallet = Wallet(
        userId: 'user_123',
        balance: 1000.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        isActive: true,
        currency: 'MGA',
        minBalance: 0.0,
        maxBalance: 5000000.0,
      );

      final invalidWallet = Wallet(
        userId: '', // Empty user ID
        balance: -100.0, // Negative balance
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        isActive: true,
        currency: 'USD', // Wrong currency
        minBalance: 1000.0,
        maxBalance: 500.0, // Max < Min
      );

      // Act
      final validErrors = WalletConstraints.validateWallet(validWallet);
      final invalidErrors = WalletConstraints.validateWallet(invalidWallet);

      // Assert
      expect(validErrors, isEmpty);
      expect(invalidErrors, isNotEmpty);
      expect(invalidErrors, contains('User ID is required'));
      expect(invalidErrors, contains('Balance cannot be negative'));
      expect(invalidErrors, contains('Invalid currency'));
      expect(invalidErrors, contains('Invalid wallet limits'));
    });
  });

  group('WalletHelper Tests', () {
    test('should calculate wallet stats correctly', () {
      // Arrange
      final wallet = Wallet(
        userId: 'user_123',
        balance: 2500000.0, // 50% of max
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
        minBalance: 0.0,
        totalTransactions: 10,
        totalCredits: 3000000.0,
        totalDebits: 500000.0,
      );

      // Act
      final stats = WalletHelper.calculateStats(wallet);

      // Assert
      expect(stats['balancePercentage'], equals(0.5)); // 50%
      expect(stats['isLowBalance'], isFalse);
      expect(stats['isNearMaxBalance'], isFalse);
      expect(stats['availableCredit'], equals(2500000.0)); // 5M - 2.5M
      expect(stats['availableDebit'], equals(2500000.0)); // 2.5M - 0
      expect(stats['totalTransactions'], equals(10));
      expect(stats['netAmount'], equals(2500000.0)); // 3M - 0.5M
    });

    test('should suggest credit amount for low balance', () {
      // Arrange
      final lowBalanceWallet = Wallet(
        userId: 'user_123',
        balance: 5000.0, // Low balance
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      // Act
      final suggestedAmount = WalletHelper.suggestCreditAmount(lowBalanceWallet);

      // Assert
      expect(suggestedAmount, equals(45000.0)); // 50,000 - 5,000
    });

    test('should not suggest credit for sufficient balance', () {
      // Arrange
      final sufficientBalanceWallet = Wallet(
        userId: 'user_123',
        balance: 100000.0, // Sufficient balance
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        maxBalance: 5000000.0,
      );

      // Act
      final suggestedAmount = WalletHelper.suggestCreditAmount(sufficientBalanceWallet);

      // Assert
      expect(suggestedAmount, equals(0.0));
    });

    test('should format amounts correctly', () {
      // Assert
      expect(WalletHelper.formatAmount(500.0), equals('500 MGA'));
      expect(WalletHelper.formatAmount(1500.0), equals('1.5K MGA'));
      expect(WalletHelper.formatAmount(1500000.0), equals('1.5M MGA'));
      expect(WalletHelper.formatAmount(2500000.0), equals('2.5M MGA'));
    });
  });
}