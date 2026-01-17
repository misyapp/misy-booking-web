// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/global_settings_modal.dart';
import 'package:rider_ride_hailing_app/modal/user_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DevFestPreferences {
  static const THEME_STATUS = "THEMESTATUS";
  static const LANGUAGE_CODE = "LANGUAGECODE";
  static const VERIFICATION_CODE = "VERIFICATIONCODE";
  static const VERIFICATION_REQUEST = "VERIFICATIONREQUEST";
  static const DARKMODE_SETTING = "DARKMODESETTING";
  static const LAST_SEARCH_SUGESTION = "LASTSEARCHSUGESTION";
  static const LAST_PAYMENT_METHOD_SELECTED = "LASTPAYMENTMETHODSELECTED";
  static const USER_DETAILS = "USER_DETAILS";
  static const LATITUDE = "LATITUDE";
  static const LONGITUDE = "LONGITUDE";
  static const DEFAULT_APP_SETTINGS = "DEFAULT_APP_SETTINGS";
  static const ACTIVE_BOOKING_DATA = "ACTIVE_BOOKING_DATA";
  static const ACTIVE_BOOKING_ID = "ACTIVE_BOOKING_ID";

  static updateLocation(LatLng latLng) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble(LATITUDE, latLng.latitude);
    prefs.setDouble(LONGITUDE, latLng.longitude);

    myCustomLogStatements("set location is Called $latLng");
  }

  static Future<LatLng> getLocation() async {
    SharedPreferences sharedPreference = await SharedPreferences.getInstance();
    var latLng = LatLng(sharedPreference.getDouble(LATITUDE) ?? 0,
        sharedPreference.getDouble(LONGITUDE) ?? 0);
    myCustomLogStatements("get location is Called $latLng");
    return latLng;
  }

  setDefaultAppSettingRequest(Map<String, dynamic> value) async {
    myCustomLogStatements("set default app setting ✅✅");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(DEFAULT_APP_SETTINGS, jsonEncode(value));
  }

  Future<GlobalSettingsModal> getDefaultAppSettingRequest() async {
    myCustomLogStatements("get default app setting ✅✅");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map respose = jsonDecode(prefs.getString(DEFAULT_APP_SETTINGS) ?? "{}");
    return respose.isEmpty
        ? globalSettings
        : GlobalSettingsModal.fromJson(respose);
  }

  setDarkTheme(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(THEME_STATUS, value);
    myCustomPrintStatement("dark theme seted $value");
  }

  Future<bool> getTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(THEME_STATUS) ?? false;
  }

  setLanguageCode(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(LANGUAGE_CODE, value);
  }

  Future<String> getLanguageCode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(LANGUAGE_CODE) ?? "";
  }

  setUserDetails(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(USER_DETAILS, value);
  }

  Future<UserModal?> getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var userDetailsString = prefs.getString(USER_DETAILS) ?? "";
    if (userDetailsString.isNotEmpty) {
      var jsonValue = jsonDecode(userDetailsString);
      return UserModal.fromJson(jsonValue);
    }

    return null;
  }

  setVerificationCode(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(VERIFICATION_CODE, value);
  }

  Future<String> getVerificationCode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(VERIFICATION_CODE) ?? "";
  }

  setLastPaymentMethodSelected(String value) async {
    myCustomPrintStatement("Payemnt Metnod save to $value");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(LAST_PAYMENT_METHOD_SELECTED, value);
  }

  Future<String> getLastPaymentMethodSelected() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(LAST_PAYMENT_METHOD_SELECTED) ?? "";
  }

  setUserVerificationRequest(Map<String, dynamic> value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(VERIFICATION_REQUEST, jsonEncode(value));
  }

  Future<Map<String, dynamic>> getUserVerificationRequest() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString(VERIFICATION_REQUEST) ?? "{}");
  }

  setDarkModeSetting(int value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt(DARKMODE_SETTING, value);
  }

  Future<int> getDarkModeSetting() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(DARKMODE_SETTING) ?? 4;
  }

  setSearchSuggestion(Map value) async {
    List getList = [value];
    // await getSearchSuggestion();
    // if (getList.isEmpty) {
    //   getList = [value];
    // } else {
    //   getList = [value];
    //   // + [getList[0]];
    // }
    lastSearchSuggestion.value = getList;
    String jsonList = json.encode(getList);
    myCustomPrintStatement("suggestion list is $jsonList");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(LAST_SEARCH_SUGESTION, jsonList);
  }

  Future<List> getSearchSuggestion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return json.decode(prefs.getString(LAST_SEARCH_SUGESTION) ?? "[]");
  }

  // Méthodes pour la persistance de la course active
  Future<void> saveActiveBooking(Map<String, dynamic> bookingData) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      // Convertir les Timestamps Firestore en valeurs sérialisables
      Map<String, dynamic> serializableData = _convertTimestampsToSerializable(bookingData);
      await prefs.setString(ACTIVE_BOOKING_DATA, jsonEncode(serializableData));
      await prefs.setString(ACTIVE_BOOKING_ID, bookingData['id'] ?? '');
      myCustomPrintStatement("💾 Course active sauvegardée localement: ${bookingData['id']}");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur sauvegarde course: $e");
    }
  }

  /// Convertit récursivement les Timestamps Firestore en millisecondes (int)
  Map<String, dynamic> _convertTimestampsToSerializable(Map<String, dynamic> data) {
    Map<String, dynamic> result = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        // Convertir Timestamp en millisecondes depuis epoch
        result[key] = value.millisecondsSinceEpoch;
      } else if (value is DateTime) {
        // Convertir DateTime en millisecondes depuis epoch
        result[key] = value.millisecondsSinceEpoch;
      } else if (value is Map<String, dynamic>) {
        // Récursion pour les maps imbriquées
        result[key] = _convertTimestampsToSerializable(value);
      } else if (value is List) {
        // Gérer les listes
        result[key] = value.map((item) {
          if (item is Timestamp) {
            return item.millisecondsSinceEpoch;
          } else if (item is DateTime) {
            return item.millisecondsSinceEpoch;
          } else if (item is Map<String, dynamic>) {
            return _convertTimestampsToSerializable(item);
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  Future<Map<String, dynamic>?> getActiveBooking() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? bookingJson = prefs.getString(ACTIVE_BOOKING_DATA);
      if (bookingJson != null && bookingJson.isNotEmpty) {
        var booking = jsonDecode(bookingJson);
        myCustomPrintStatement("📱 Course active restaurée depuis cache local: ${booking['id']}");
        return booking;
      }
    } catch (e) {
      myCustomPrintStatement("❌ Erreur lecture course locale: $e");
    }
    return null;
  }

  Future<void> clearActiveBooking() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(ACTIVE_BOOKING_DATA);
      await prefs.remove(ACTIVE_BOOKING_ID);
      myCustomPrintStatement("🗑️ Course active supprimée du cache local");
    } catch (e) {
      myCustomPrintStatement("❌ Erreur suppression course locale: $e");
    }
  }

  Future<String?> getActiveBookingId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(ACTIVE_BOOKING_ID);
  }
}
