class ChestReward {
  double amount; // Montant en MGA
  double probability; // Probabilité en pourcentage (0-100)
  double? boostedProbability; // Probabilité boostée pour lucky users (optionnel)

  ChestReward({
    required this.amount,
    required this.probability,
    this.boostedProbability,
  });

  factory ChestReward.fromJson(Map<String, dynamic> json) {
    return ChestReward(
      amount: double.parse((json['amount'] ?? 0.0).toString()),
      probability: double.parse((json['probability'] ?? 0.0).toString()),
      boostedProbability: json['boostedProbability'] != null 
          ? double.parse(json['boostedProbability'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'amount': amount,
      'probability': probability,
    };
    
    if (boostedProbability != null) {
      json['boostedProbability'] = boostedProbability!;
    }
    
    return json;
  }

  @override
  String toString() {
    final boosted = boostedProbability != null ? ', boosted: $boostedProbability%' : '';
    return 'ChestReward(amount: $amount MGA, probability: $probability%$boosted)';
  }
}