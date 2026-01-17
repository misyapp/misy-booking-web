import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:flutter/material.dart';

class BadgeTypes {
  static const int platinum = 0;
  static const int gold = 1;
  static const int silver = 2;
  static const int bronze = 3;
  static const int noBadge = 4;

  static String getBadgeUrl(int status) {
    switch (status) {
      case BadgeTypes.platinum:
        return MyImagesUrl.platinumIcon;
      case BadgeTypes.gold:
        return MyImagesUrl.goldIcon;
      case BadgeTypes.bronze:
        return MyImagesUrl.bronzeIcon;
      case BadgeTypes.silver:
        return MyImagesUrl.silverIcon;
      default:
        return MyImagesUrl.platinumIcon;
    }
  }

  static int getBadgeStatusPercentBase(double status) {
    if (status >= 90) {
      return BadgeTypes.platinum;
    } else if (status < 90 && status >= 80) {
      return BadgeTypes.gold;
    } else if (status < 80 && status >= 65) {
      return BadgeTypes.silver;
    } else if (status < 65 && status >= 50) {
      return BadgeTypes.bronze;
    } else {
      return BadgeTypes.noBadge;
    }
  }

  static String getName(int status, {int? secsLeft}) {
    switch (status) {
      case BadgeTypes.platinum:
        return 'Platinum';
      case BadgeTypes.gold:
        return 'Gold';
      case BadgeTypes.silver:
        return 'Silver';
      case BadgeTypes.bronze:
        return 'Bronze';
      case BadgeTypes.noBadge:
        return 'No Badge';
      default:
        return 'Platinum';
    }
  }

  static Color getColor(
    int status,
  ) {
    switch (status) {
      case BadgeTypes.platinum:
        return MyColors.platinumColor;
      case BadgeTypes.bronze:
        return MyColors.bronzeColor;
      case BadgeTypes.gold:
        return MyColors.goldColor;
      case BadgeTypes.silver:
        return MyColors.silverColor;
      case BadgeTypes.noBadge:
        return MyColors.transparent;
      default:
        return MyColors.platinumColor;
    }
  }
}
