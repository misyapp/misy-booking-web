import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/pages/view_module/tutorial_page_webview.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import '../modal/chat_modal.dart';

List homePageMenuList = [
  {
    "id": 1,
    "name": "Ride",
    "imageHeight": 70,
    "imagewidth": 110,
    "onTap": () {
      Provider.of<TripProvider>(MyGlobalKeys.navigatorKey.currentContext!,
              listen: false)
          .setScreen(CustomTripType.choosePickupDropLocation);
    },
    "image": MyImagesUrl.carHomeIcon,
    "ignoreInternetConnectivity":false,
  },
  {
    "id": 2,
    "name": "Reserve",
    "imageHeight": 75,
    "imagewidth": 100,
     "ignoreInternetConnectivity":true,
    "onTap": () {
      Provider.of<TripProvider>(MyGlobalKeys.navigatorKey.currentContext!,
              listen: false)
          .setScreen(CustomTripType.selectScheduleTime);
    },
    "image": MyImagesUrl.calendarHomeIcon,
  },
  {
    "id": 3,
    "name": "Show map",
    "imageHeight": 75,
    "imagewidth": 110,
     "ignoreInternetConnectivity":true,
    "onTap": () {
      showHomePageMenuNoti.value = false;
    },
    "image": MyImagesUrl.mapsHomeIcon,
  },
  {
    "id": 4,
    "name": "Tutorial",
    "imageHeight": 75,
    "imagewidth": 110,
     "ignoreInternetConnectivity":false,
    "onTap": () {
      push(
          // ignore: use_build_context_synchronously
          context: MyGlobalKeys.navigatorKey.currentContext!,
          screen: const TutorialPageWebview(
              webViewUrl: "https://www.misyapp.com/passengers/tuto"));
    },
    "image": MyImagesUrl.tutoHomeIcon,
  }
];
List serviceList = [
  const LatLng(22.6980, 75.8683),
  const LatLng(22.6963, 75.8875),
  const LatLng(22.6845, 75.8645),
  const LatLng(22.7082, 75.8757),
];
List<ChatModal> chatDeatilJson = [
  ChatModal(
    from: 1,
    to: 2,
    message: "Hi, It's nice to meet you!",
    messageType: "0",
    createdAt: "3:06 PM",
  ),
  ChatModal(
    from: 2,
    to: 1,
    message:
        "Nice to meet you too! Looks like we both enjoy going to comedy ows! ",
    messageType: "0",
    createdAt: "3:06 PM",
  ),
  ChatModal(
    from: 1,
    to: 2,
    message: "Hi, It's nice to meet you!",
    messageType: "0",
    createdAt: "3:06 PM",
  ),
  ChatModal(
    from: 2,
    to: 1,
    message:
        "Nice to meet you too! Looks like we both enjoy going to comedy ows! ",
    messageType: "0",
    createdAt: "3:06 PM",
  ),
];
