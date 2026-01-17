import 'package:rider_ride_hailing_app/contants/types/badge_types.dart';

class DriverModal {
  String id;
  String email;
  String phone;
  String countryName;
  String preferedLanguage;
  String countryCode;
  String taxiLicenceNumber;
  String nifNumber;
  String statisticNumber;
  bool verified;
  bool isBlocked;
  bool isCustomer;
  bool isOnline;
  VehicleDetailModal? vehicleData;
  List<DriverDocumentModal> driverDocumentList;
  String profileImage;
  String dob;
  String? vehicleType;
  String fullName;
  String firstName;
  String lastName;
  String companyAddress;

  double? currentLat;
  double? currentLng;
  double? oldLat;
  double? oldLng;
  double averageRating;
  double cashCommission;
  int totalReveiwCount;
  int batchStatus;
  List deviceIdList;
  double balance;

  DriverModal({
    required this.id,
    required this.isCustomer,
    required this.balance,
    required this.email,
    required this.driverDocumentList,
    required this.countryName,
    required this.preferedLanguage,
    required this.countryCode,
    required this.nifNumber,
    required this.companyAddress,
    required this.statisticNumber,
    required this.taxiLicenceNumber,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.verified,
    required this.isBlocked,
    required this.totalReveiwCount,
    required this.averageRating,
    required this.cashCommission,
    required this.profileImage,
    required this.fullName,
    required this.isOnline,
    required this.vehicleData,
    this.vehicleType,
    this.currentLat,
    this.currentLng,
    this.oldLat,
    this.oldLng,
    required this.batchStatus,
    required this.deviceIdList,
    required this.dob,
  });
  factory DriverModal.fromJson(Map json) {
    return DriverModal(
      id: json['id'],
      balance: double.parse(
          json['balance'] == null ? "0" : json['balance'].toString()),
      isCustomer: json['isCustomer'],
      isOnline: json['isOnline'],
      fullName: json['name'],
      companyAddress: json['companyAddress'] ?? '',
      email: json['email'],
      cashCommission: double.parse((json['cash_commission'] ?? 0.0).toString()),
      deviceIdList: json['deviceId'] ?? [],
      driverDocumentList: json['driverDocuments'] == null
          ? []
          : List.generate(
              json['driverDocuments'].length,
              (index) => DriverDocumentModal.fromJson(
                json['driverDocuments'][index],
              ),
            ),
      preferedLanguage: json['preferedLanguage'] ?? 'en',
      countryName: json['countryName'] ?? 'Madagasikara',
      countryCode: json['countryCode'] ?? '+261',
      phone: json['phoneNo'] ?? '',
      batchStatus: int.parse(((json['average_rating'] ?? 0.0) < 4
              ? BadgeTypes.noBadge
              : (json['batch_status'] ?? "${BadgeTypes.noBadge}"))
          .toString()),
      nifNumber: json['nifNumber'] ?? '',
      totalReveiwCount: json['total_review'] ?? 0,
      averageRating: json['average_rating'] ?? 0.0,
      currentLng: json['currentLng'] != null ? double.parse(json['currentLng'].toString()) : null,
      currentLat: json['currentLat'] != null ? double.parse(json['currentLat'].toString()) : null,
      oldLng: json['oldLng'] != null && json['oldLng'] != 0 ? double.parse(json['oldLng'].toString()) : null,
      oldLat: json['oldLat'] != null && json['oldLat'] != 0 ? double.parse(json['oldLat'].toString()) : null,
      statisticNumber: json['statisticNumber'] ?? '',
      taxiLicenceNumber: json['taxiLicenceNumber'] ?? '',
      verified: json['verified'],
      isBlocked: json['isBlocked'],
      lastName: json['lastName'] ?? '',
      firstName: json['firstName'] ?? '',
      vehicleData: json['vehicleDetails'] == null
          ? null
          : VehicleDetailModal.fromJson(json['vehicleDetails']),
      vehicleType: json['vehicleType'] ?? '',
      profileImage: json['profileImage'],
      dob: json['dob'] ?? '',
    );
  }
}

class DriverDocumentModal {
  String type;
  String frontImage;
  String backImage;
  DriverDocumentModal(
      {required this.type, required this.backImage, required this.frontImage});

  factory DriverDocumentModal.fromJson(json) {
    return DriverDocumentModal(
        type: json['type'] ?? '',
        backImage: json['backImage'] ?? '',
        frontImage: json['frontImage'] ?? '');
  }
  toJson() {
    return {
      "type": type,
      "backImage": backImage,
      "frontImage": frontImage,
    };
  }
}

class VehicleDetailModal {
  String vehicleModal;
  String vehicleBrandName;
  String licenseNumber;
  List vehicleImages;
  DriverDocumentModal? vehicleRegistrationImage;
  Map vehicleType;

  VehicleDetailModal(
      {required this.vehicleModal,
      required this.vehicleBrandName,
      required this.licenseNumber,
      required this.vehicleType,
      required this.vehicleImages,
      this.vehicleRegistrationImage});

  factory VehicleDetailModal.fromJson(Map<String, dynamic> json) {
    return VehicleDetailModal(
      vehicleModal: json['vehicleModal'],
      vehicleBrandName: json['vehicleBrandName'],
      licenseNumber: json['licenseNumber'],
      vehicleType: json['vehicleType'],
      vehicleImages: json['vehicleImages'],
      vehicleRegistrationImage: json['vehicleRegistrationImage'] == null
          ? null
          : DriverDocumentModal.fromJson(json['vehicleRegistrationImage']),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['vehicleModal'] = vehicleModal;
    data['vehicleBrandName'] = vehicleBrandName;
    data['licenseNumber'] = licenseNumber;
    data['vehicleImages'] = vehicleImages;
    if (vehicleRegistrationImage != null) {
      data['vehicleRegistrationImage'] = vehicleRegistrationImage!.toJson();
    }
    data['vehicleType'] = vehicleType;
    return data;
  }
}
