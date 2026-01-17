import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

Future<Map?> getGPS({required BuildContext context}) async {
  Position? currentPosition;
  bool enable = await CurrentLocation.checkPermissionEnable();
  if (enable) {
    currentPosition = await CurrentLocation.getCurrentPosition();
    String lat = currentPosition.latitude.toString();
    String lng = currentPosition.longitude.toString();

    Map data = {
      'lat': lat,
      'lng': lng,
    };
    return data;
  }
  return null;
}

class CurrentLocation {
  static Future<bool> checkPermissionEnable() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      } else if (permission == LocationPermission.deniedForever) {
        myCustomPrintStatement("'Location permissions are permanently denied");
        return false;
      } else {
        myCustomPrintStatement("GPS Location service is granted");
        return true;
      }
    } else {
      myCustomPrintStatement("GPS Location permission granted.");
      return true;
    }
  }

  static Future<Position> getCurrentPosition() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return position;
  }
}
