import 'dart:math';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/chest_reward.dart';
import 'package:rider_ride_hailing_app/models/loyalty_chest.dart';
import 'package:rider_ride_hailing_app/models/wallet_transaction.dart';
import 'package:rider_ride_hailing_app/services/wallet_service.dart';
import 'package:rider_ride_hailing_app/services/loyalty_service.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';

/// Modes de récompense pour les utilisateurs
enum RewardMode {
  newUser,    // Mode 50/50 pour nouveaux utilisateurs
  lucky,      // Mode avec probabilités boostées
  standard,   // Mode normal avec probabilités standard
}

class ChestRewardService {
  static final ChestRewardService _instance = ChestRewardService._internal();
  factory ChestRewardService() => _instance;
  ChestRewardService._internal();

  static ChestRewardService get instance => _instance;

  final Random _random = Random();

  /// Ouvre un coffre et retourne la récompense obtenue
  Future<ChestRewardResult> openChest({
    required String userId,
    required LoyaltyChest chest,
  }) async {
    try {
      myCustomPrintStatement('ChestRewardService: Ouverture coffre ${chest.tier} pour user $userId');

      // 1. Déterminer le mode de récompense pour cet utilisateur
      final rewardMode = await _getUserRewardMode(userId);
      myCustomPrintStatement('ChestRewardService: Mode de récompense détecté - ${rewardMode.name}');

      // 2. Tirer une récompense selon le mode (avant de dépenser les points)
      final ChestRewardDrawResult drawResult = _drawRewardByMode(chest, rewardMode);
      if (drawResult.reward == null) {
        myCustomPrintStatement('ChestRewardService: Aucune récompense disponible pour ${chest.tier}');
        return ChestRewardResult.failure('Aucune récompense disponible');
      }

      final reward = drawResult.reward!;
      myCustomPrintStatement('ChestRewardService: Récompense tirée - ${reward.amount} MGA (mode: ${rewardMode.name}, probabilité: ${drawResult.usedProbability}%)');

      // 3. Dépenser les points de fidélité avec informations du coffre
      final spendSuccess = await LoyaltyService.instance.spendPoints(
        userId: userId,
        pointsToSpend: chest.price,
        reason: 'Ouverture ${chest.displayName}',
        itemId: 'chest_${chest.tier}',
        // Informations de la récompense pour l'historique
        chestRewardAmount: reward.amount,
        chestTier: chest.tier,
        rewardMode: rewardMode.name,
      );

      if (!spendSuccess) {
        return ChestRewardResult.failure('Impossible de dépenser les points de fidélité');
      }

      // 4. Gérer le flag new user si nécessaire
      if (rewardMode == RewardMode.newUser && drawResult.isTargetReward) {
        await _disableNewUserFlag(userId);
        myCustomPrintStatement('ChestRewardService: Flag new_user désactivé pour userId $userId (gain cible atteint)');
      }

      // 4. Créditer le portefeuille numérique
      final transaction = await WalletService.creditWallet(
        userId: userId,
        amount: reward.amount,
        source: PaymentSource.bonus,
        referenceId: 'chest_${chest.tier}_${DateTime.now().millisecondsSinceEpoch}',
        description: 'Récompense ${chest.displayName}',
        metadata: {
          'chest_tier': chest.tier,
          'chest_name': chest.displayName,
          'chest_price': chest.price,
          'reward_probability': reward.probability,
          'reward_mode': rewardMode.name,
          'used_probability': drawResult.usedProbability,
          'is_target_reward': drawResult.isTargetReward,
        },
      );

      if (transaction == null) {
        myCustomPrintStatement('ChestRewardService: Erreur credit portefeuille pour ${reward.amount} MGA');
        return ChestRewardResult.failure('Erreur lors du crédit du portefeuille');
      }

      myCustomPrintStatement('ChestRewardService: ✅ Coffre ${chest.tier} ouvert avec succès - Gain: ${reward.amount} MGA');
      
      return ChestRewardResult.success(
        reward: reward,
        chestName: chest.displayName,
      );
    } catch (e) {
      myCustomPrintStatement('ChestRewardService: ❌ Erreur ouverture coffre ${chest.tier} - $e');
      return ChestRewardResult.failure('Erreur lors de l\'ouverture du coffre: $e');
    }
  }

  /// Détermine le mode de récompense pour un utilisateur
  Future<RewardMode> _getUserRewardMode(String userId) async {
    try {
      // Récupérer les données utilisateur depuis userData global ou Firestore
      if (userData.value?.id == userId) {
        // Utiliser les données en mémoire
        final user = userData.value!;
        if (user.newUserChestFlag) {
          return RewardMode.newUser;
        } else if (user.luckyUser) {
          return RewardMode.lucky;
        } else {
          return RewardMode.standard;
        }
      } else {
        // Récupérer depuis Firestore pour d'autres utilisateurs
        final userDoc = await FirestoreServices.users.doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final newUserFlag = data['newUserChestFlag'] ?? true;
          final luckyUser = data['luckyUser'] ?? false;
          
          if (newUserFlag) {
            return RewardMode.newUser;
          } else if (luckyUser) {
            return RewardMode.lucky;
          } else {
            return RewardMode.standard;
          }
        }
      }
      
      // Fallback : mode standard
      return RewardMode.standard;
    } catch (e) {
      myCustomPrintStatement('ChestRewardService: Erreur récupération mode utilisateur - $e');
      return RewardMode.standard;
    }
  }

  /// Tire une récompense selon le mode spécifié
  ChestRewardDrawResult _drawRewardByMode(LoyaltyChest chest, RewardMode mode) {
    switch (mode) {
      case RewardMode.newUser:
        return _drawNewUserReward(chest);
      case RewardMode.lucky:
        return _drawLuckyReward(chest);
      case RewardMode.standard:
        return _drawStandardReward(chest);
    }
  }

  /// Tire une récompense en mode nouveau utilisateur (50/50)
  ChestRewardDrawResult _drawNewUserReward(LoyaltyChest chest) {
    final rewards = chest.chestRewards;
    if (rewards == null || rewards.isEmpty) {
      return ChestRewardDrawResult.failure('Pas de récompenses configurées');
    }
    
    if (rewards.length < 2) {
      myCustomPrintStatement('ChestRewardService: ⚠️ Mode new_user nécessite au moins 2 récompenses, utilisation du mode standard');
      return _drawStandardReward(chest);
    }

    // Tirage 50/50 entre rewards[0] (minimum) et rewards[1] (cible)
    final isTargetReward = _random.nextBool(); // 50% de chance
    final selectedReward = isTargetReward ? rewards[1] : rewards[0];
    
    myCustomPrintStatement('ChestRewardService: Mode new_user - ${isTargetReward ? "Gain cible" : "Gain minimum"} sélectionné');
    
    return ChestRewardDrawResult(
      reward: selectedReward,
      usedProbability: 50.0, // 50% dans les deux cas
      isTargetReward: isTargetReward,
    );
  }

  /// Tire une récompense en mode lucky (probabilités boostées)
  ChestRewardDrawResult _drawLuckyReward(LoyaltyChest chest) {
    final rewards = chest.chestRewards;
    if (rewards == null || rewards.isEmpty) {
      return ChestRewardDrawResult.failure('Pas de récompenses configurées');
    }

    // Vérifier si des probabilités boostées sont disponibles
    final hasBoostData = rewards.any((r) => r.boostedProbability != null);
    if (!hasBoostData) {
      myCustomPrintStatement('ChestRewardService: ⚠️ Pas de boostedProbability configurées, utilisation du mode standard');
      return _drawStandardReward(chest);
    }

    // Calculer le total des probabilités boostées
    double totalBoostedProbability = 0.0;
    for (final reward in rewards) {
      totalBoostedProbability += reward.boostedProbability ?? reward.probability;
    }

    if (totalBoostedProbability != 100.0) {
      myCustomPrintStatement('ChestRewardService: ⚠️ Probabilités boostées invalides: $totalBoostedProbability%');
    }

    // Génération et sélection avec probabilités boostées
    final randomValue = _random.nextDouble() * 100;
    double cumulativeProbability = 0.0;
    
    for (final reward in rewards) {
      final probToUse = reward.boostedProbability ?? reward.probability;
      cumulativeProbability += probToUse;
      if (randomValue <= cumulativeProbability) {
        return ChestRewardDrawResult(
          reward: reward,
          usedProbability: probToUse,
          isTargetReward: false,
        );
      }
    }

    // Fallback
    return ChestRewardDrawResult(
      reward: rewards.first,
      usedProbability: rewards.first.boostedProbability ?? rewards.first.probability,
      isTargetReward: false,
    );
  }

  /// Tire une récompense en mode standard (probabilités normales)
  ChestRewardDrawResult _drawStandardReward(LoyaltyChest chest) {
    final rewards = chest.chestRewards;
    if (rewards == null || rewards.isEmpty) {
      return ChestRewardDrawResult.failure('Pas de récompenses configurées');
    }

    // Utiliser l'ancienne logique
    final totalProbability = rewards.fold(0.0, (sum, reward) => sum + reward.probability);
    if (totalProbability != 100.0) {
      myCustomPrintStatement('ChestRewardService: ⚠️ Probabilités invalides pour ${chest.tier}: $totalProbability%');
    }

    final randomValue = _random.nextDouble() * 100;
    double cumulativeProbability = 0.0;
    
    for (final reward in rewards) {
      cumulativeProbability += reward.probability;
      if (randomValue <= cumulativeProbability) {
        return ChestRewardDrawResult(
          reward: reward,
          usedProbability: reward.probability,
          isTargetReward: false,
        );
      }
    }

    // Fallback
    return ChestRewardDrawResult(
      reward: rewards.first,
      usedProbability: rewards.first.probability,
      isTargetReward: false,
    );
  }

  /// Désactive le flag new_user pour un utilisateur
  Future<void> _disableNewUserFlag(String userId) async {
    try {
      await FirestoreServices.users.doc(userId).update({
        'newUserChestFlag': false,
      });
      
      // Mettre à jour les données globales si c'est l'utilisateur actuel
      if (userData.value?.id == userId && userData.value != null) {
        // Créer une nouvelle instance avec le flag mis à jour
        // Note: UserModal n'a pas de copyWith, on utilise une affectation directe
        userData.value!.newUserChestFlag = false;
      }
    } catch (e) {
      myCustomPrintStatement('ChestRewardService: ❌ Erreur désactivation flag new_user - $e');
    }
  }

  /// Valide les probabilités d'un coffre
  bool validateChestProbabilities(LoyaltyChest chest) {
    final rewards = chest.chestRewards;
    if (rewards == null || rewards.isEmpty) return false;

    final totalProbability = rewards.fold(0.0, (sum, reward) => sum + reward.probability);
    return totalProbability == 100.0;
  }

  /// Calcule les statistiques de gain pour un coffre
  ChestStats calculateChestStats(LoyaltyChest chest) {
    final rewards = chest.chestRewards;
    if (rewards == null || rewards.isEmpty) {
      return ChestStats(
        averageReward: 0.0,
        minReward: 0.0,
        maxReward: 0.0,
        totalProbability: 0.0,
      );
    }

    double averageReward = 0.0;
    double minReward = double.infinity;
    double maxReward = 0.0;
    double totalProbability = 0.0;

    for (final reward in rewards) {
      // Calcul moyenne pondérée
      averageReward += (reward.amount * reward.probability) / 100;
      
      // Min/Max
      if (reward.amount < minReward) minReward = reward.amount;
      if (reward.amount > maxReward) maxReward = reward.amount;
      
      // Total probabilités
      totalProbability += reward.probability;
    }

    return ChestStats(
      averageReward: averageReward,
      minReward: minReward,
      maxReward: maxReward,
      totalProbability: totalProbability,
    );
  }
}

/// Résultat de l'ouverture d'un coffre
class ChestRewardResult {
  final bool isSuccess;
  final ChestReward? reward;
  final String? chestName;
  final String? errorMessage;

  ChestRewardResult._({
    required this.isSuccess,
    this.reward,
    this.chestName,
    this.errorMessage,
  });

  factory ChestRewardResult.success({
    required ChestReward reward,
    required String chestName,
  }) {
    return ChestRewardResult._(
      isSuccess: true,
      reward: reward,
      chestName: chestName,
    );
  }

  factory ChestRewardResult.failure(String errorMessage) {
    return ChestRewardResult._(
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }
}

/// Statistiques d'un coffre
class ChestStats {
  final double averageReward;
  final double minReward;
  final double maxReward;
  final double totalProbability;

  ChestStats({
    required this.averageReward,
    required this.minReward,
    required this.maxReward,
    required this.totalProbability,
  });

  @override
  String toString() {
    return 'ChestStats(avg: ${averageReward.toInt()}, min: ${minReward.toInt()}, max: ${maxReward.toInt()}, total: $totalProbability%)';
  }
}

/// Résultat du tirage de récompense avec métadonnées
class ChestRewardDrawResult {
  final ChestReward? reward;
  final double usedProbability;
  final bool isTargetReward;
  final String? errorMessage;

  ChestRewardDrawResult({
    this.reward,
    required this.usedProbability,
    required this.isTargetReward,
    this.errorMessage,
  });

  factory ChestRewardDrawResult.failure(String errorMessage) {
    return ChestRewardDrawResult(
      reward: null,
      usedProbability: 0.0,
      isTargetReward: false,
      errorMessage: errorMessage,
    );
  }

  bool get isSuccess => reward != null;
}