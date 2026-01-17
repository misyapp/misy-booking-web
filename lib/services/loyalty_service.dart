import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/loyalty_config_modal.dart';
import 'package:rider_ride_hailing_app/modal/user_modal.dart';
import 'package:rider_ride_hailing_app/models/loyalty_transaction.dart';
import 'package:rider_ride_hailing_app/provider/admin_settings_provider.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'dart:math' as math;
import 'dart:async';

class LoyaltyService {
  static final LoyaltyService _instance = LoyaltyService._internal();
  factory LoyaltyService() => _instance;
  LoyaltyService._internal();

  static LoyaltyService get instance => _instance;

  /// Vérifie si le système de fidélité est activé globalement
  bool isEnabled() {
    try {
      if (MyGlobalKeys.navigatorKey.currentContext == null) return false;
      
      final adminSettingsProvider = Provider.of<AdminSettingsProvider>(
        MyGlobalKeys.navigatorKey.currentContext!,
        listen: false,
      );
      
      return adminSettingsProvider.defaultAppSettingModal.loyaltySystemEnabled;
    } catch (e) {
      myCustomPrintStatement('LoyaltyService: Erreur vérification statut système - $e');
      return false;
    }
  }

  /// Initialise les champs de fidélité pour un utilisateur si ils n'existent pas
  Future<bool> initializeLoyaltyForUser(String userId) async {
    try {
      if (!isEnabled()) {
        myCustomPrintStatement('LoyaltyService: Système désactivé, initialisation ignorée');
        return false;
      }

      myCustomPrintStatement('LoyaltyService: Initialisation des champs de fidélité pour user $userId');

      // 🚀 FIX CRITIQUE: Ajouter un timeout pour éviter le blocage de l'app
      // Si Firestore ne répond pas en 5 secondes, on abandonne gracieusement
      final userDoc = await FirestoreServices.users.doc(userId).get()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            myCustomPrintStatement('⚠️ LoyaltyService: Timeout lors de la récupération user $userId');
            throw TimeoutException('Timeout getting user document');
          },
        );

      if (!userDoc.exists) {
        myCustomPrintStatement('LoyaltyService: Utilisateur $userId non trouvé');
        return false;
      }

      final userDocData = userDoc.data() as Map<String, dynamic>;
      bool needsUpdate = false;
      Map<String, dynamic> updateData = {};

      // Vérifier et initialiser les champs manquants
      if (!userDocData.containsKey('loyaltyPoints') || userDocData['loyaltyPoints'] == null) {
        updateData['loyaltyPoints'] = 0.0;
        needsUpdate = true;
      }
      
      if (!userDocData.containsKey('totalLoyaltyPointsEarned') || userDocData['totalLoyaltyPointsEarned'] == null) {
        updateData['totalLoyaltyPointsEarned'] = 0.0;
        needsUpdate = true;
      }
      
      if (!userDocData.containsKey('totalLoyaltyPointsSpent') || userDocData['totalLoyaltyPointsSpent'] == null) {
        updateData['totalLoyaltyPointsSpent'] = 0.0;
        needsUpdate = true;
      }

      // Initialiser les nouveaux champs pour les coffres
      if (!userDocData.containsKey('luckyUser') || userDocData['luckyUser'] == null) {
        updateData['luckyUser'] = false; // Désactivé par défaut
        needsUpdate = true;
      }
      
      if (!userDocData.containsKey('newUserChestFlag') || userDocData['newUserChestFlag'] == null) {
        updateData['newUserChestFlag'] = true; // Activé pour nouveaux utilisateurs
        needsUpdate = true;
        myCustomPrintStatement('LoyaltyService: Flag new_user activé pour nouvel utilisateur $userId');
      }

      if (needsUpdate) {
        // 🚀 FIX: Ajouter timeout sur l'update Firestore
        await FirestoreServices.users.doc(userId).update(updateData)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              myCustomPrintStatement('⚠️ LoyaltyService: Timeout lors de l\'update user $userId');
              throw TimeoutException('Timeout updating user document');
            },
          );
        myCustomPrintStatement('LoyaltyService: Champs initialisés pour user $userId');

        // Mettre à jour les données globales si c'est l'utilisateur actuel
        if (userData.value?.id == userId) {
          final updatedUser = await FirestoreServices.users.doc(userId).get()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                myCustomPrintStatement('⚠️ LoyaltyService: Timeout lors de la relecture user $userId');
                throw TimeoutException('Timeout re-reading user document');
              },
            );
          if (updatedUser.exists) {
            userData.value = UserModal.fromJson(updatedUser.data() as Map<String, dynamic>);
          }
        }
      }

      return true;
    } on TimeoutException catch (e) {
      // 🚀 FIX CRITIQUE: Ne pas bloquer l'app en cas de timeout
      // Retourner false silencieusement et laisser l'app continuer
      myCustomPrintStatement('⏱️ LoyaltyService: Timeout initialisation user $userId - l\'app continue normalement');
      return false;
    } catch (e) {
      myCustomPrintStatement('LoyaltyService: Erreur initialisation user $userId - $e');
      return false;
    }
  }

  /// Calcule le nombre de points à attribuer pour un montant donné
  double calculatePoints(double amount, LoyaltyConfigModal config) {
    if (amount < config.minimumAmountForPoints) {
      return 0.0;
    }

    // Calcul : (montant / 1000) * pointsPerThousandMGA
    double points = (amount / 1000.0) * config.pointsPerThousandMGA;
    
    // Arrondi au point inférieur mais minimum 1 point si montant > 0
    return amount > 0 ? math.max(1.0, points.floor().toDouble()) : 0.0;
  }

  /// Ajoute des points de fidélité pour un utilisateur
  Future<bool> addPoints({
    required String userId,
    required double amount,
    required String reason,
    String? bookingId,
  }) async {
    try {
      if (!isEnabled()) {
        myCustomPrintStatement('LoyaltyService: Système désactivé, ajout de points ignoré');
        return false;
      }

      // Charger la configuration si nécessaire
      if (loyaltyConfig == null) {
        await FirestoreServices.getLoyaltyConfig();
      }

      final config = loyaltyConfig ?? LoyaltyConfigModal.defaultConfig;
      final pointsToAdd = calculatePoints(amount, config);

      if (pointsToAdd <= 0) {
        myCustomPrintStatement('LoyaltyService: Aucun point à ajouter pour montant $amount (minimum: ${config.minimumAmountForPoints})');
        return true; // Ce n'est pas une erreur, juste aucun point à ajouter
      }

      myCustomPrintStatement('LoyaltyService: Ajout de $pointsToAdd points pour user $userId (montant: $amount MGA)');

      // Générer un ID unique pour cette transaction
      // Si c'est pour une course (bookingId fourni), utiliser un ID stable pour éviter les doublons
      final transactionId = bookingId != null 
        ? '${userId}_${bookingId}_ride_complete'
        : '${userId}_${DateTime.now().millisecondsSinceEpoch}_manual';

      // Vérifier si cette transaction existe déjà pour éviter les doublons
      if (await transactionExists(transactionId, userId)) {
        myCustomPrintStatement('LoyaltyService: Transaction déjà traitée - ID: $transactionId');
        return true; // Considérer comme succès car déjà traité
      }

      // Transaction atomique pour éviter les problèmes de concurrence
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirestoreServices.users.doc(userId);
        final userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception('Utilisateur $userId non trouvé');
        }

        final currentData = userSnapshot.data() as Map<String, dynamic>;
        final currentPoints = double.parse((currentData['loyaltyPoints'] ?? 0.0).toString());
        final currentTotalEarned = double.parse((currentData['totalLoyaltyPointsEarned'] ?? 0.0).toString());

        final newPoints = currentPoints + pointsToAdd;
        final newTotalEarned = currentTotalEarned + pointsToAdd;

        // Mettre à jour le document utilisateur
        transaction.update(userRef, {
          'loyaltyPoints': newPoints,
          'totalLoyaltyPointsEarned': newTotalEarned,
        });

        // Créer l'entrée d'historique
        final loyaltyTransaction = LoyaltyTransaction.createEarned(
          transactionId: transactionId,
          points: pointsToAdd,
          reason: reason,
          bookingId: bookingId,
          amount: amount,
          balance: newPoints,
        );

        final historyRef = FirestoreServices.users
            .doc(userId)
            .collection('loyalty_history')
            .doc(transactionId);
        
        transaction.set(historyRef, loyaltyTransaction.toJson());

        myCustomPrintStatement('LoyaltyService: Transaction complétée - User: $userId, Points ajoutés: $pointsToAdd, Nouveau solde: $newPoints');
      });

      // Vérifier si un compactage est nécessaire (en arrière-plan)
      _checkAndCompactHistory(userId, config);

      // Mettre à jour les données globales si c'est l'utilisateur actuel
      if (userData.value?.id == userId) {
        final updatedUser = await FirestoreServices.users.doc(userId).get();
        if (updatedUser.exists) {
          userData.value = UserModal.fromJson(updatedUser.data() as Map<String, dynamic>);
        }
      }

      return true;
    } catch (e) {
      myCustomPrintStatement('LoyaltyService: Erreur ajout points pour user $userId - $e');
      return false;
    }
  }

  /// Vérifie si un compactage de l'historique est nécessaire et l'effectue
  Future<void> _checkAndCompactHistory(String userId, LoyaltyConfigModal config) async {
    try {
      final historyQuery = await FirestoreServices.users
          .doc(userId)
          .collection('loyalty_history')
          .get();

      if (historyQuery.docs.length <= config.historyCompactionThreshold) {
        return; // Pas besoin de compactage
      }

      myCustomPrintStatement('LoyaltyService: Compactage nécessaire pour user $userId (${historyQuery.docs.length} entrées)');

      // Trier par timestamp (les plus anciennes en premier)
      final sortedDocs = historyQuery.docs;
      sortedDocs.sort((a, b) {
        final aTimestamp = a.data()['timestamp'] as Timestamp;
        final bTimestamp = b.data()['timestamp'] as Timestamp;
        return aTimestamp.compareTo(bTimestamp);
      });

      // Calculer combien d'entrées à archiver (garder les 50 plus récentes par exemple)
      final keepCount = (config.historyCompactionThreshold * 0.5).round();
      final docsToArchive = sortedDocs.take(sortedDocs.length - keepCount).toList();

      if (docsToArchive.isEmpty) return;

      // Créer un document de synthèse
      double totalEarned = 0;
      double totalSpent = 0;
      final oldestDate = (docsToArchive.first.data()['timestamp'] as Timestamp).toDate();
      final newestDate = (docsToArchive.last.data()['timestamp'] as Timestamp).toDate();

      for (final doc in docsToArchive) {
        final data = doc.data();
        final points = double.parse((data['points'] ?? 0.0).toString());
        final type = data['type'] as String;

        if (type == 'earned') {
          totalEarned += points;
        } else if (type == 'spent') {
          totalSpent += points;
        }
      }

      // Transaction pour le compactage
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Créer le document de synthèse
        final compactRef = FirestoreServices.users
            .doc(userId)
            .collection('loyalty_history')
            .doc('compact_${DateTime.now().millisecondsSinceEpoch}');

        transaction.set(compactRef, {
          'type': 'compact',
          'totalEarned': totalEarned,
          'totalSpent': totalSpent,
          'transactionCount': docsToArchive.length,
          'fromDate': Timestamp.fromDate(oldestDate),
          'toDate': Timestamp.fromDate(newestDate),
          'timestamp': FieldValue.serverTimestamp(),
          'reason': 'Archive automatique de ${docsToArchive.length} transactions',
        });

        // Supprimer les documents archivés
        for (final doc in docsToArchive) {
          transaction.delete(doc.reference);
        }
      });

      myCustomPrintStatement('LoyaltyService: Compactage terminé pour user $userId - ${docsToArchive.length} entrées archivées');
    } catch (e) {
      myCustomPrintStatement('LoyaltyService: Erreur compactage pour user $userId - $e');
    }
  }

  /// Récupère l'historique des transactions de fidélité pour un utilisateur
  Future<List<LoyaltyTransaction>> getHistory(String userId, {int limit = 50}) async {
    try {
      if (!isEnabled()) return [];

      final query = await FirestoreServices.users
          .doc(userId)
          .collection('loyalty_history')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .where((doc) => doc.data()['type'] != 'compact') // Exclure les entrées de synthèse
          .map((doc) => LoyaltyTransaction.fromJson(doc.data()))
          .toList();
    } catch (e) {
      myCustomPrintStatement('LoyaltyService: Erreur récupération historique pour user $userId - $e');
      return [];
    }
  }

  /// Dépense des points de fidélité pour un utilisateur
  Future<bool> spendPoints({
    required String userId,
    required double pointsToSpend,
    required String reason,
    String? itemId,
    // Paramètres optionnels pour les coffres
    double? chestRewardAmount,
    String? chestTier,
    String? rewardMode,
  }) async {
    try {
      if (!isEnabled()) {
        myCustomPrintStatement('LoyaltyService: Système désactivé, dépense de points ignorée');
        return false;
      }

      myCustomPrintStatement('LoyaltyService: Dépense de $pointsToSpend points pour user $userId - $reason');

      // Générer un ID unique pour cette transaction
      final transactionId = '${userId}_${DateTime.now().millisecondsSinceEpoch}_spend_${itemId ?? 'manual'}';

      // Transaction atomique pour éviter les problèmes de concurrence
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirestoreServices.users.doc(userId);
        final userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception('Utilisateur $userId non trouvé');
        }

        final currentData = userSnapshot.data() as Map<String, dynamic>;
        final currentPoints = double.parse((currentData['loyaltyPoints'] ?? 0.0).toString());
        final currentTotalSpent = double.parse((currentData['totalLoyaltyPointsSpent'] ?? 0.0).toString());

        // Vérifier si l'utilisateur a assez de points
        if (currentPoints < pointsToSpend) {
          throw Exception('Points insuffisants. Solde: $currentPoints, Requis: $pointsToSpend');
        }

        final newPoints = currentPoints - pointsToSpend;
        final newTotalSpent = currentTotalSpent + pointsToSpend;

        // Mettre à jour le document utilisateur
        transaction.update(userRef, {
          'loyaltyPoints': newPoints,
          'totalLoyaltyPointsSpent': newTotalSpent,
        });

        // Créer l'entrée d'historique (spécialisée pour les coffres si applicable)
        final loyaltyTransaction = (chestRewardAmount != null && chestTier != null && rewardMode != null) 
          ? LoyaltyTransaction.createChestSpent(
              transactionId: transactionId,
              points: pointsToSpend,
              reason: reason,
              balance: newPoints,
              chestRewardAmount: chestRewardAmount,
              chestTier: chestTier,
              rewardMode: rewardMode,
            )
          : LoyaltyTransaction.createSpent(
              transactionId: transactionId,
              points: pointsToSpend,
              reason: reason,
              bookingId: itemId?.startsWith('booking_') == true ? itemId : null, // Seuls les vrais bookingId commençant par 'booking_'
              balance: newPoints,
            );

        final historyRef = FirestoreServices.users
            .doc(userId)
            .collection('loyalty_history')
            .doc(transactionId);
        
        transaction.set(historyRef, loyaltyTransaction.toJson());

        myCustomPrintStatement('LoyaltyService: Transaction dépense complétée - User: $userId, Points dépensés: $pointsToSpend, Nouveau solde: $newPoints');
      });

      // Mettre à jour les données globales si c'est l'utilisateur actuel
      if (userData.value?.id == userId) {
        final updatedUser = await FirestoreServices.users.doc(userId).get();
        if (updatedUser.exists) {
          userData.value = UserModal.fromJson(updatedUser.data() as Map<String, dynamic>);
        }
      }

      return true;
    } catch (e) {
      myCustomPrintStatement('LoyaltyService: Erreur dépense points pour user $userId - $e');
      return false;
    }
  }

  /// Méthode de debug pour ajouter des points rapidement (à supprimer en production)
  Future<bool> addDebugPoints(String userId, double points) async {
    try {
      if (!isEnabled()) {
        myCustomPrintStatement('LoyaltyService: Système désactivé, ajout de points debug ignoré');
        return false;
      }

      myCustomPrintStatement('LoyaltyService: Ajout direct de $points points debug pour user $userId');

      // Générer un ID unique pour cette transaction
      final transactionId = '${userId}_${DateTime.now().millisecondsSinceEpoch}_debug';

      // Transaction atomique pour éviter les problèmes de concurrence
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirestoreServices.users.doc(userId);
        final userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception('Utilisateur $userId non trouvé');
        }

        final currentData = userSnapshot.data() as Map<String, dynamic>;
        final currentPoints = double.parse((currentData['loyaltyPoints'] ?? 0.0).toString());
        final currentTotalEarned = double.parse((currentData['totalLoyaltyPointsEarned'] ?? 0.0).toString());

        final newPoints = currentPoints + points;
        final newTotalEarned = currentTotalEarned + points;

        // Mettre à jour le document utilisateur
        transaction.update(userRef, {
          'loyaltyPoints': newPoints,
          'totalLoyaltyPointsEarned': newTotalEarned,
        });

        // Créer l'entrée d'historique
        final loyaltyTransaction = LoyaltyTransaction.createEarned(
          transactionId: transactionId,
          points: points,
          reason: 'Points de debug pour test',
          bookingId: null,
          amount: null, // Pas de montant associé pour le debug
          balance: newPoints,
        );

        final historyRef = FirestoreServices.users
            .doc(userId)
            .collection('loyalty_history')
            .doc(transactionId);
        
        transaction.set(historyRef, loyaltyTransaction.toJson());

        myCustomPrintStatement('LoyaltyService: Transaction debug complétée - User: $userId, Points ajoutés: $points, Nouveau solde: $newPoints');
      });

      // Mettre à jour les données globales si c'est l'utilisateur actuel
      if (userData.value?.id == userId) {
        final updatedUser = await FirestoreServices.users.doc(userId).get();
        if (updatedUser.exists) {
          userData.value = UserModal.fromJson(updatedUser.data() as Map<String, dynamic>);
        }
      }

      return true;
    } catch (e) {
      myCustomPrintStatement('LoyaltyService: Erreur ajout points debug pour user $userId - $e');
      return false;
    }
  }

  /// Méthode utilitaire pour vérifier si une transaction existe déjà (éviter les doublons)
  Future<bool> transactionExists(String transactionId, String userId) async {
    try {
      final doc = await FirestoreServices.users
          .doc(userId)
          .collection('loyalty_history')
          .doc(transactionId)
          .get();
      
      return doc.exists;
    } catch (e) {
      myCustomPrintStatement('LoyaltyService: Erreur vérification transaction $transactionId - $e');
      return false; // En cas d'erreur, on assume que la transaction n'existe pas
    }
  }
}