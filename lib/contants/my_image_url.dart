import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';

class MyImagesUrl {
  static const String baseImageUrl = 'assets/images/';
  static const String baseIconsUrl = 'assets/icons/';

// Nouvelles images pour le bottom sheet
  static const String trajetsAllonsY = "${baseImageUrl}Bouton_home_screen_Trajets_allons-y.png";
  static const String trajetsPlanifies = "${baseImageUrl}Bouton_home_screen_Trajets_planifiés.png";
  static const String reserveBanner = "${baseImageUrl}reserve_banner.png";

// icon urls
  static const String walletHomeIcon = "${baseIconsUrl}wallet_home_icon.png";
  static const String tutoHomeIcon = "${baseIconsUrl}tuto_home_icon.png";
  static const String carHomeIcon = "${baseIconsUrl}car_home_icon.png";
  static const String calendarHomeIcon = "${baseIconsUrl}calendar_home_icon.png";
  static const String mapsHomeIcon = "${baseIconsUrl}maps_home_icon.png";
  ///
  static const String manPerson = "${baseIconsUrl}man_person.png";
  static const String search = "${baseIconsUrl}search.png";
  static const String success = "${baseIconsUrl}success.png";
  static const String introImage = "${baseIconsUrl}intro_image.png";
  static const String rateUs = "${baseIconsUrl}rate_us.png";
  static const String addCircle = "${baseIconsUrl}add_circle.png";
  static const String dobIcon = "${baseIconsUrl}dob_icon.png";
  static const String backIcon = "${baseIconsUrl}back_icon.png";
  static const String orangeMoneyIcon = "${baseIconsUrl}orange_money_icon.png";
  static const String bankCardIcon = "${baseIconsUrl}bank_card_icon.png";
  static const String telmaMvolaIcon = "${baseIconsUrl}telma_mvola_icon.png";
  static const String airtelMoneyIcon = "${baseIconsUrl}airtel_money_icon.png";
  // Logos blancs pour headers de paiement (sur fond coloré)
  static const String mvolaWhiteIcon = "${baseIconsUrl}mvola_white_icon.png";
  static const String airtelMoneyWhiteIcon = "${baseIconsUrl}airtel_money_white_icon.png";
  static const String tutorialIcon = "${baseIconsUrl}tutorial_icon.png";

  static const String helpIcon = "${baseIconsUrl}help_icon.png";
  static const String helpEmailIcon = "${baseIconsUrl}help_email_icon.png";
  static const String helpSupportIcon = "${baseIconsUrl}help_support_icon.png";
  static const String vehicleManagementIcon = "${baseIconsUrl}vehicle_management_icon.png";

  static const String airtelMoneyBannerImage =
      "${baseImageUrl}airtel_money_banner_image.png";
  static const String airtelMoneyLogoWhite =
      "${baseImageUrl}new_airtel_money_logo.png";
  static const String telmaMoneyBannerImage =
      "${baseImageUrl}MVola_brand_new_vert-04.png";
  static const String cashIcon = "${baseIconsUrl}cash_icon.png";
  static const String card = "${baseIconsUrl}card.png";
  static const String chat = "${baseIconsUrl}chat.png";
  static const String home = "${baseIconsUrl}home.png";
  static const String wallet = "${baseIconsUrl}wallet.png";
  static const String language = "${baseIconsUrl}language.png";
  static const String location = "${baseIconsUrl}location.png";
  static const String lock = "${baseIconsUrl}lock.png";
  static const String logout = "${baseIconsUrl}logout.png";
 static const String platinumIcon = "${baseIconsUrl}platinum_icon.png";
  static const String bronzeIcon = "${baseIconsUrl}bronze_icon.png";
  static const String goldIcon = "${baseIconsUrl}gold_icon.png";
  static const String silverIcon = "${baseIconsUrl}silver_icon.png";
    static const String verifiedStatusIcon = "${baseIconsUrl}verified_status_icon.png";

  static const String solarCalendarBoldIcon =
      "${baseIconsUrl}solar_calendar_bold_icon.png";
  static const String menu = "${baseIconsUrl}menu.png";
  static const String questionMarkIcon = "${baseIconsUrl}question_mark_icon.png";
  static const String newMenu = "${baseIconsUrl}new_home_icon.png";
  static const String myLocation = "${baseIconsUrl}my_location.png";
  static const String location01 = "${baseIconsUrl}location01.png";
  static const String paypal = "${baseIconsUrl}paypal.png";
  static const String phone = "${baseIconsUrl}phone.png";
  static const String phoneOutline = "${baseIconsUrl}phone_outline.png";
  static const String phoneOutline01 = "${baseIconsUrl}phone_outline01.png";
  static const String privacyTip = "${baseIconsUrl}privacy_tip.png";
  static const String promoCodeIcon = "${baseIconsUrl}promo_code_icon.png";
  static const String loyaltyProgramIcon = "${baseIconsUrl}loyalty_program_icon.png";
  static const String send = "${baseIconsUrl}send.png";
  static const String settingIcon = "${baseIconsUrl}setting_icon.png";
  static const String splashLogo = "${baseIconsUrl}splash_logo.png";
  static const String calendarIcon = "${baseIconsUrl}calendar.png";
  static const String star = "${baseIconsUrl}star.png";
  static const String ticket = "${baseIconsUrl}ticket.png";
  static const String user = "${baseIconsUrl}user.png";
  static const String editIcon = "${baseIconsUrl}edit_icon.png";
  static const String trash = "${baseIconsUrl}trash.png";
  static const String facebook = "${baseIconsUrl}Facebook_Logo_Primary.png";
  static const String google = "${baseIconsUrl}Google_Favicon_2025.svg";
  static const String notification = "${baseIconsUrl}notification.png";

  static const String picupLocationIcon =
      "${baseIconsUrl}picup_location_icon.png";

  static const String picupLocationCircleIcon =
      "${baseIconsUrl}picup_location_icon_circle.png";
  static const String picupDarkLocationIcon =
      "${baseIconsUrl}picup_dark_location_icon.png";
  static const String dropLocationIcon =
      "${baseIconsUrl}drop_location_icon.png";
  static const String dropDarkLocationIcon =
      "${baseIconsUrl}drop_dark_location_icon.png";
  static const String dropLocationPickerIcon =
      "${baseIconsUrl}drop_location_pick_icon.png";
  static const String dropLocationNightPickerIcon =
      "${baseIconsUrl}drop_location_night_pick_icon.png";
  static const String whatsAppIcon =
      "${baseIconsUrl}whatsapp_icon.png";

  // Drawer SVG icons
  static const String drawerWalletSvg = "${baseIconsUrl}drawer_wallet.svg";
  static const String drawerPromoSvg = "${baseIconsUrl}drawer_promo.svg";
  static const String drawerCalendarSvg = "${baseIconsUrl}drawer_calendar.svg";
  static const String drawerGuideSvg = "${baseIconsUrl}drawer_guide.svg";
  static const String drawerHelpSvg = "${baseIconsUrl}drawer_help.svg";
  static const String drawerSettingsSvg = "${baseIconsUrl}drawer_settings.svg";
  static const String drawerPrivacySvg = "${baseIconsUrl}drawer_privacy.svg";

//image Urls
  static const String bgImage = "${baseImageUrl}bg_image.png";
  static const String image01 = "${baseImageUrl}image01.png";
  static const String image02 = "${baseImageUrl}image02.png";
  static const String image03 = "${baseImageUrl}image03.png";
  static const String drivingCarImage = "${baseImageUrl}driving_car_image.png";
  static const String profileImage = "${baseImageUrl}profile_image.png";

  static String pickupCircleIconTheme() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? picupDarkLocationIcon
        : picupLocationCircleIcon;
  }

  static String dropLocationCircleIconTheme() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? dropDarkLocationIcon
        : dropLocationIcon;
  }

  static String locationSelectFromMap() {
    return Provider.of<DarkThemeProvider>(
                    MyGlobalKeys.navigatorKey.currentContext!,
                    listen: false)
                .darkTheme ==
            true
        ? dropLocationNightPickerIcon
        : dropLocationPickerIcon;
  }
}
