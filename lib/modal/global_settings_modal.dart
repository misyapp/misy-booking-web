import 'package:rider_ride_hailing_app/functions/print_function.dart';

class GlobalSettingsModal {
  double adminCommission;
  String currency;
  String agencyPhysicalAddress;
  double distanceLimitNow;
  double distanceLimitScheduled;
  bool locationLive;
  bool enableTaxiExtraDiscount;
  bool enableOTPVerification;
  double minRadius;
  double minWithdrawal;
  double extraDiscount;
  double scheduleRideServiceFee;
  int numberOfUser;
  int maxWaitingTimeInMin;
  int receiveRideRequest;
  int scheduleReceiveRideRequest;
  bool enableBookingOTPVerification;
  bool enableScheduledBooking;
  bool enableSequentialNotification;
  int sequentialNotificationTimeout;
  bool sequentialFallbackToLegacy;

  GlobalSettingsModal(
      {required this.adminCommission,
      required this.currency,
      required this.agencyPhysicalAddress,
      required this.enableBookingOTPVerification,
      required this.enableScheduledBooking,
      required this.distanceLimitNow,
      required this.distanceLimitScheduled,
      required this.locationLive,
      required this.enableTaxiExtraDiscount,
      required this.enableOTPVerification,
      required this.extraDiscount,
      required this.scheduleRideServiceFee,
      required this.numberOfUser,
      required this.minRadius,
      required this.scheduleReceiveRideRequest,
      required this.receiveRideRequest,
      required this.minWithdrawal,
      required this.maxWaitingTimeInMin,
      required this.enableSequentialNotification,
      required this.sequentialNotificationTimeout,
      required this.sequentialFallbackToLegacy});
  factory GlobalSettingsModal.fromJson(Map json) {
    myCustomPrintStatement("json modal global setting is that $json");
    return GlobalSettingsModal(
        adminCommission: json['admin_commission'],
        currency: json['currency'] ?? "Ar",
        distanceLimitNow: double.parse(json['distance_limit_now'].toString()),
        distanceLimitScheduled:
            double.parse(json['distance_limit_scheduled'].toString()),
        locationLive: json['location_live'] ?? true,
        enableTaxiExtraDiscount: json['enableTaxiExtraDiscount'] ?? false,
        enableOTPVerification: json['enableOTPVerification'] ?? true,
        agencyPhysicalAddress: json['agencyPhysicalAddress'] ??
            "Navlakha Indore, Madhya Pradesh 452001",
        enableBookingOTPVerification:
            json['enableBookingOTPVerification'] ?? true,
        enableScheduledBooking: json['enableScheduledBooking'] ?? true,
        minRadius: double.parse((json['min_radius'] ?? 0).toString()),
        minWithdrawal: double.parse((json['min_withdrawal'] ?? 0).toString()),
        maxWaitingTimeInMin:
            int.parse((json['maxWaitingTimeInMin'] ?? 0).toString()),
        numberOfUser:
            int.parse((json['no_users'] ?? 0).toString().split(".").first),
        extraDiscount:
            double.parse((json['special_discount_amount'] ?? 0).toString()),
        scheduleRideServiceFee:
            double.parse((json['schedule_ride_service_fee'] ?? 0).toString()),
        receiveRideRequest: int.parse(
            (json['receiveRideRequest'] ?? 0).toString().split(".").first),
        scheduleReceiveRideRequest: int.parse(
            (json['scheduleReceiveRideRequest'] ?? 0)
                .toString()
                .split(".")
                .first),
        enableSequentialNotification: json['enableSequentialNotification'] ?? false,
        sequentialNotificationTimeout: json['sequentialNotificationTimeout'] ?? 30,
        sequentialFallbackToLegacy: json['sequentialFallbackToLegacy'] ?? true);
  }
}
