
class DefaultAppSettingModal {
  int appVersionIos;
  int appVersionAndroid;
  int hardUpdateVersionAndroid;
  int hardUpdateVersionIos;
  bool updatePopup;
  bool hideAndroidSocialLogin;
  bool hideIOSSocialLogin;
  bool digitalWalletEnabled;
  bool creditCardPaymentEnabled;
  bool loyaltySystemEnabled;
  String? googleApiKey;
  String updateUrlAndroid;
  String updateUrlIos;
  String updateMessage;

  DefaultAppSettingModal({
    required this.appVersionIos,
    required this.appVersionAndroid,
    required this.hardUpdateVersionAndroid,
    required this.hardUpdateVersionIos,
    required this.updatePopup,
    required this.googleApiKey,
    required this.updateUrlAndroid,
    required this.updateUrlIos,
    required this.updateMessage,
    required this.hideAndroidSocialLogin,
    required this.hideIOSSocialLogin,
    required this.digitalWalletEnabled,
    required this.creditCardPaymentEnabled,
    required this.loyaltySystemEnabled,
  });

  factory DefaultAppSettingModal.fromJson(Map json) {
    return DefaultAppSettingModal(
      appVersionIos: json['appVersionIos'],
      appVersionAndroid: json['appVersionAndroid'],
      hardUpdateVersionAndroid: json['hardUpdateVersionAndroid'],
      hardUpdateVersionIos: json['hardUpdateVersionIos'],
      updatePopup: json['updatePopup'],
      googleApiKey: json['googleApiKey'],
      hideAndroidSocialLogin: json['hideAndroidSocialLogin'] ?? false,
      hideIOSSocialLogin: json['hideIOSSocialLogin'] ?? false,
      digitalWalletEnabled: json['digitalWalletEnabled'] ?? false,
      creditCardPaymentEnabled: json['creditCardPaymentEnabled'] ?? false,
      loyaltySystemEnabled: json['loyaltySystemEnabled'] ?? false,
      updateUrlAndroid: json['updateUrlAndroid'],
      updateUrlIos: json['updateUrlIos'],
      updateMessage: json['updateMessage'],
    );
  }
}
