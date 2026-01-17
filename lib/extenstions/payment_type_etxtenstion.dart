enum PaymentMethodType {
  cash,
  airtelMoney,
  orangeMoney,
  telmaMvola,
  creditCard,
  wallet,
}

extension PaymentMethodTypeExtension on PaymentMethodType {
  String get value {
    switch (this) {
      case PaymentMethodType.cash:
        return "Cash";
      case PaymentMethodType.airtelMoney:
        return "Airtel Money";
      case PaymentMethodType.telmaMvola:
        return "MVola";
      case PaymentMethodType.orangeMoney:
        return "Orange Money";
      case PaymentMethodType.creditCard:
        return "Credit Card";
      case PaymentMethodType.wallet:
        return "Portefeuille Misy";
      default:
        return "Cash";
    }
  }

  /// Masque un numéro selon le type de paiement et les spécifications Misy 2.0
  /// Mobile: 03•• ••• 445 (format malgache)
  /// Cartes: ••• 4045 (derniers 4 chiffres)
  static String maskPaymentNumber(String number, PaymentMethodType type) {
    if (number.isEmpty) return '';
    
    // Supprimer tous les espaces et caractères non numériques pour traitement
    String cleanNumber = number.replaceAll(RegExp(r'[^\d]'), '');
    
    switch (type) {
      case PaymentMethodType.airtelMoney:
      case PaymentMethodType.orangeMoney:
      case PaymentMethodType.telmaMvola:
        // Format mobile malgache: 03•• ••• 445
        if (cleanNumber.length >= 10) {
          String prefix = cleanNumber.substring(0, 2); // 03
          String suffix = cleanNumber.substring(cleanNumber.length - 3); // 445
          return "$prefix•• ••• $suffix";
        } else if (cleanNumber.length >= 6) {
          String prefix = cleanNumber.substring(0, 2);
          String suffix = cleanNumber.substring(cleanNumber.length - 3);
          return "$prefix•• ••• $suffix";
        }
        return "••• •••";
        
      case PaymentMethodType.creditCard:
        // Format carte bancaire: ••• 4045 (derniers 4 chiffres)
        if (cleanNumber.length >= 4) {
          String suffix = cleanNumber.substring(cleanNumber.length - 4);
          return "••• $suffix";
        }
        return "••• ••••";
        
      case PaymentMethodType.cash:
      case PaymentMethodType.wallet:
      default:
        return number; // Pas de masquage pour cash et wallet
    }
  }

  static PaymentMethodType fromValue(String value) {
    switch (value) {
      case "Cash":
        return PaymentMethodType.cash;
      case "Airtel Money":
        return PaymentMethodType.airtelMoney;
      case "MVola":
        return PaymentMethodType.telmaMvola;
      case "Telma MVola":
        return PaymentMethodType.telmaMvola;
      case "Orange Money":
        return PaymentMethodType.orangeMoney;
      case "Credit Card":
        return PaymentMethodType.creditCard;
      case "Portefeuille Misy":
        return PaymentMethodType.wallet;
      default:
        return PaymentMethodType.cash;
    }
  }
}
