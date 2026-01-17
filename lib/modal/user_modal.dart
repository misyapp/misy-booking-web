class UserModal {
  String id;
  String email;
  String phone;
  String preferedLanguage;
  String countryName;
  String countryCode;
  double extraDiscount;
  bool verified;
  bool isBlocked;
  bool isShadowBanned;  // Silent ban - user can create bookings but drivers won't see them
  bool isCustomer;
  String profileImage;
  String dob;
  String fullName;
  String firstName;
  double averageRating;
  int totalReveiwCount;
  String lastName;
  List deviceIdList;
  
  // Propriétés du portefeuille numérique
  double walletBalance;
  bool walletStatus;
  String? lastWalletTransaction;
  
  // Programme de fidélité - Propriétés du système de fidélité
  double loyaltyPoints;
  double totalLoyaltyPointsEarned;
  double totalLoyaltyPointsSpent;
  
  // Propriétés spéciales des coffres (cachées à l'utilisateur)
  bool luckyUser;                // Active les probabilités boostées
  bool newUserChestFlag;         // Active le mode 50/50 pour nouveaux utilisateurs

  // Getter pour accéder facilement au numéro de téléphone avec le nom Firestore
  String? get phoneNo => phone.isEmpty ? null : phone;

  UserModal({
    required this.id,
    required this.isCustomer,
    required this.email,
    required this.extraDiscount,
    required this.countryName,
    required this.preferedLanguage,
    required this.deviceIdList,
    required this.countryCode,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.verified,
    required this.totalReveiwCount,
    required this.averageRating,
    required this.isBlocked,
    this.isShadowBanned = false,
    required this.profileImage,
    required this.fullName,
    required this.dob,
    // Propriétés du portefeuille avec valeurs par défaut
    this.walletBalance = 0.0,
    this.walletStatus = true,
    this.lastWalletTransaction,
    // Propriétés du système de fidélité avec valeurs par défaut
    this.loyaltyPoints = 0.0,
    this.totalLoyaltyPointsEarned = 0.0,
    this.totalLoyaltyPointsSpent = 0.0,
    // Propriétés spéciales des coffres avec valeurs par défaut
    this.luckyUser = false,          // Désactivé par défaut
    this.newUserChestFlag = true,    // Activé pour nouveaux utilisateurs
  });
  factory UserModal.fromJson(Map json) {
    return UserModal(
      id: json['id'] ?? '',
      isCustomer: json['isCustomer'] ?? true,
      extraDiscount: double.parse((json['extraDiscount'] ?? 0.0).toString()),
      fullName: json['name'] ?? '',
      email: json['email'] ?? '',
      preferedLanguage: json['preferedLanguage'] ?? 'en',
      countryName: json['countryName'] ?? 'Madagasikara',
      countryCode: json['countryCode'] ?? '+261',
      phone: json['phoneNo'] ?? '',
      verified: json['verified'] ?? false,
      deviceIdList: json['deviceId'] ?? [],
      isBlocked: json['isBlocked'] ?? false,
      isShadowBanned: json['isShadowBanned'] ?? false,
      lastName: json['lastName'] ?? '',
      firstName: json['firstName'] ?? '',
      totalReveiwCount: json['total_review'] ?? 0,
      averageRating: double.parse((json['average_rating'] ?? 0.0).toString()),
      profileImage: json['profileImage'] ?? '',
      dob: json['dob'] ?? '',
      // Propriétés du portefeuille
      walletBalance: double.parse((json['walletBalance'] ?? 0.0).toString()),
      walletStatus: json['walletStatus'] ?? true,
      lastWalletTransaction: json['lastWalletTransaction'],
      // Propriétés du système de fidélité
      loyaltyPoints: double.parse((json['loyaltyPoints'] ?? 0.0).toString()),
      totalLoyaltyPointsEarned: double.parse((json['totalLoyaltyPointsEarned'] ?? 0.0).toString()),
      totalLoyaltyPointsSpent: double.parse((json['totalLoyaltyPointsSpent'] ?? 0.0).toString()),
      // Propriétés spéciales des coffres (cachées à l'utilisateur)
      luckyUser: json['luckyUser'] ?? false,
      newUserChestFlag: json['newUserChestFlag'] ?? true, // true par défaut pour nouveaux utilisateurs
    );
  }
}
