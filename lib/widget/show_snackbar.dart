import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';

showSnackbar(String text) {
  Fluttertoast.showToast(
      msg: translate(text),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 4,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0);
}

// showSnackbarCustom(
//   String text, {
//   int seconds = 4,
// }) {
//   ScaffoldMessenger.of(MyGlobalKeys.navigatorKey.currentContext!)
//       .showSnackBar(SnackBar(
//     content: Text(text),
//     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//     behavior: SnackBarBehavior.floating,
//     duration: Duration(seconds: seconds),
//   ));
// }
