import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeModal {
  String id;
  String code;
  int discountPercent;
  int usageLimit;
  String description;
  Timestamp expiryDate;
  List<String> availableForUsers;
  List<String> usedBy;
  List<String> vehicleCategory;
  
  int status;
  double minRideAmount;
  double maxRideAmount;

  PromoCodeModal({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.usageLimit,
    required this.description,
    required this.expiryDate,
    required this.availableForUsers,
    required this.usedBy,
    required this.vehicleCategory,
    required this.status,
    required this.maxRideAmount,
    required this.minRideAmount,
  });

  // Convert Firestore document to PromoCodeModal model
  factory PromoCodeModal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return PromoCodeModal(
      id: data['id'] ?? '',
      code: data['code'] ?? '',
      discountPercent: data['discountPercent'] ?? 0,
      usageLimit: data['usageLimit'] ?? 0,
      description: data['description'] ?? '',
      expiryDate: data['expiryDate'] ?? Timestamp.now(),
      availableForUsers: List<String>.from(data['availableForUsers'] ?? []),
      usedBy: List<String>.from(data['usedBy'] ?? []),
      vehicleCategory: List<String>.from(data['vehicleCategory'] ?? []),
      status: data['status'] ?? 0,
      minRideAmount: double.parse("${data['minRideAmount'] ?? 0.0}"),
      maxRideAmount: double.parse("${data['maxRideAmount'] ?? 0.0}"),
    );
  }

  // Convert PromoCodeModal model to Map (for Firestore)
  Map<String, dynamic> toFirestore() {
    return {
      "id": id,
      "code": code,
      "discountPercent": discountPercent,
      "usageLimit": usageLimit,
      "description": description,
      "expiryDate": expiryDate,
      "availableForUsers": availableForUsers,
      "usedBy": usedBy,
      "vehicleCategory": vehicleCategory,
      "status": status,
      "minRideAmount": minRideAmount,
      "maxRideAmount": maxRideAmount,
    };
  }
  // Convert PromoCodeModal model to Map (for insert on booking request)
  Map<String, dynamic> toBookingStore() {
    return {
      "id": id,
      "code": code,
      "discountPercent": discountPercent,
      "usageLimit": usageLimit,
      "description": description,
      "expiryDate": expiryDate,
      "vehicleCategory": vehicleCategory,
      "status": status,
      "minRideAmount": minRideAmount,
      "maxRideAmount": maxRideAmount,
    };
  }

 
}
