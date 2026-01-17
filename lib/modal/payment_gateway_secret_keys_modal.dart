class PaymentGatewaySecretKeyModal {
  String airtelMoneyClientSecret;
  String airtelMoneyClientId;
  String orangeMoneyApiSecretKey;
  String orangeMoneyMerchantKey;
  String twillioBasicKey;
  String telmaConsumerSecretKey;
  String telmaConsumerKey;

  PaymentGatewaySecretKeyModal({
    required this.airtelMoneyClientSecret,
    required this.airtelMoneyClientId,
    required this.orangeMoneyApiSecretKey,
    required this.orangeMoneyMerchantKey,
    required this.twillioBasicKey,
    required this.telmaConsumerSecretKey,
    required this.telmaConsumerKey,
  });

  factory PaymentGatewaySecretKeyModal.fromJson(Map json) {
    return PaymentGatewaySecretKeyModal(
      airtelMoneyClientSecret: json['airtel_money_client_secret'],
      orangeMoneyMerchantKey: json['orange_money_merchnat_key'],
      airtelMoneyClientId: json['airtel_money_client_id'],
      orangeMoneyApiSecretKey: json['orange_money_api_secret_key'],
      telmaConsumerKey: json['telma_consumer_key'] ?? '',
      telmaConsumerSecretKey: json['telma_consumer_secret_key'] ?? '',
      twillioBasicKey: json['twillio_basic_key'] ??
          'QUNiYThhYmMxNDNhNzAxN2UyZGUwY2YzZWNhYjNmYWQ0Mjo3YTJiNWRmMDE0YjA2YTRkYzllMGIwYmRmZDgzNWM2Zg',
    );
  }
}
