class LoyaltyConfigModal {
  double pointsPerThousandMGA;
  double minimumAmountForPoints;
  int historyCompactionThreshold;

  LoyaltyConfigModal({
    required this.pointsPerThousandMGA,
    required this.minimumAmountForPoints,
    required this.historyCompactionThreshold,
  });

  factory LoyaltyConfigModal.fromJson(Map json) {
    return LoyaltyConfigModal(
      pointsPerThousandMGA: double.parse((json['pointsPerThousandMGA'] ?? 10.0).toString()),
      minimumAmountForPoints: double.parse((json['minimumAmountForPoints'] ?? 100.0).toString()),
      historyCompactionThreshold: json['historyCompactionThreshold'] ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pointsPerThousandMGA': pointsPerThousandMGA,
      'minimumAmountForPoints': minimumAmountForPoints,
      'historyCompactionThreshold': historyCompactionThreshold,
    };
  }

  static LoyaltyConfigModal get defaultConfig => LoyaltyConfigModal(
    pointsPerThousandMGA: 10.0,
    minimumAmountForPoints: 100.0,
    historyCompactionThreshold: 100,
  );
}