import 'chest_reward.dart';
import 'package:intl/intl.dart';
import '../contants/language_strings.dart';

class LoyaltyChest {
  String tier;
  double price;
  String? name;
  String? description;
  String? icon;
  List<String>? rewards; // Deprecated: remplacé par chestRewards
  List<ChestReward>? chestRewards; // Nouvelles récompenses avec probabilités
  bool? availability;

  LoyaltyChest({
    required this.tier,
    required this.price,
    this.name,
    this.description,
    this.icon,
    this.rewards,
    this.chestRewards,
    this.availability,
  });

  factory LoyaltyChest.fromJson(Map<String, dynamic> json) {
    List<ChestReward>? parsedRewards;
    if (json['rewards'] != null && json['rewards'] is List) {
      try {
        parsedRewards = (json['rewards'] as List)
            .map((reward) => ChestReward.fromJson(reward as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Si le parsing échoue, utiliser null (valeurs par défaut)
        parsedRewards = null;
      }
    }

    return LoyaltyChest(
      tier: json['tier'] ?? '',
      price: double.parse((json['price'] ?? 0.0).toString()),
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      rewards: null, // Deprecated, toujours null
      chestRewards: parsedRewards,
      availability: json['availability'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'price': price,
      'name': name,
      'description': description,
      'icon': icon,
      'rewards': chestRewards?.map((reward) => reward.toJson()).toList(),
      'availability': availability,
    };
  }

  static List<LoyaltyChest> get defaultChests => [
    LoyaltyChest(
      tier: 'tier1',
      price: 100.0,
      name: 'Coffre Bronze',
      description: 'Récompenses de base',
      availability: true,
      chestRewards: [
        ChestReward(amount: 50, probability: 40, boostedProbability: 20),    // 40% → 20% (moins de chance de petit gain)
        ChestReward(amount: 100, probability: 30, boostedProbability: 35),   // 30% → 35% (légèrement plus)
        ChestReward(amount: 150, probability: 20, boostedProbability: 30),   // 20% → 30% (plus de chance)
        ChestReward(amount: 300, probability: 10, boostedProbability: 15),   // 10% → 15% (jackpot légèrement boosté)
      ],
    ),
    LoyaltyChest(
      tier: 'tier2',
      price: 250.0,
      name: 'Coffre Argent',
      description: 'Récompenses intermédiaires',
      availability: true,
      chestRewards: [
        ChestReward(amount: 200, probability: 40, boostedProbability: 25),   // 40% → 25% (moins de petit gain)
        ChestReward(amount: 500, probability: 35, boostedProbability: 40),   // 35% → 40% (gain moyen favorisé)
        ChestReward(amount: 1000, probability: 20, boostedProbability: 25),  // 20% → 25% (gros gain plus probable)
        ChestReward(amount: 2000, probability: 5, boostedProbability: 10),   // 5% → 10% (jackpot doublé)
      ],
    ),
    LoyaltyChest(
      tier: 'tier3',
      price: 500.0,
      name: 'Coffre Or',
      description: 'Récompenses premium',
      availability: true,
      chestRewards: [
        ChestReward(amount: 1000, probability: 45, boostedProbability: 25),  // 45% → 25% (moins de petit gain)
        ChestReward(amount: 2500, probability: 30, boostedProbability: 35),  // 30% → 35% (gain moyen favorisé)
        ChestReward(amount: 5000, probability: 20, boostedProbability: 30),  // 20% → 30% (gros gain plus probable)
        ChestReward(amount: 10000, probability: 5, boostedProbability: 10),  // 5% → 10% (jackpot premium doublé)
      ],
    ),
  ];

  String get displayName {
    switch (tier) {
      case 'tier1':
        return name ?? translate('chestBronze');
      case 'tier2':
        return name ?? translate('chestSilver');
      case 'tier3':
        return name ?? translate('chestGold');
      default:
        return name ?? translate('chestBronze');
    }
  }

  String get displayDescription {
    switch (tier) {
      case 'tier1':
        return description ?? 'Déverrouillez des récompenses de base';
      case 'tier2':
        return description ?? 'Déverrouillez des récompenses intermédiaires';
      case 'tier3':
        return description ?? 'Déverrouillez des récompenses premium';
      default:
        return description ?? 'Déverrouillez des récompenses';
    }
  }

  double get minReward {
    if (chestRewards == null || chestRewards!.isEmpty) {
      switch (tier) {
        case 'tier1': return 50.0;
        case 'tier2': return 200.0;
        case 'tier3': return 1000.0;
        default: return 50.0;
      }
    }
    return chestRewards!.map((r) => r.amount).reduce((a, b) => a < b ? a : b);
  }

  double get maxReward {
    if (chestRewards == null || chestRewards!.isEmpty) {
      switch (tier) {
        case 'tier1': return 300.0;
        case 'tier2': return 2000.0;
        case 'tier3': return 10000.0;
        default: return 300.0;
      }
    }
    return chestRewards!.map((r) => r.amount).reduce((a, b) => a > b ? a : b);
  }

  String get rewardRangeText {
    final min = minReward.toInt();
    final max = maxReward.toInt();
    final formatter = NumberFormat('#,###', 'fr');
    var text = translate('chestContains');
    text = text.replaceFirst('%s', '${formatter.format(min)}Ar');
    text = text.replaceFirst('%s', '${formatter.format(max)}Ar');
    return text;
  }

  String get imagePath {
    switch (tier) {
      case 'tier1':
        return 'assets/images/coffre_bronze.png';
      case 'tier2':
        return 'assets/images/coffre_argent.png';
      case 'tier3':
        return 'assets/images/coffre_or.png';
      default:
        return 'assets/images/coffre_bronze.png';
    }
  }
}