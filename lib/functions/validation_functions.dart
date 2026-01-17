import 'package:rider_ride_hailing_app/contants/language_strings.dart';

class ValidationFunction {
  static requiredValidation(String val, {String? msg}) {
    if (val.isEmpty) {
      return msg ?? translate("required");
    } else {
      return null;
    }
  }

  static mobileNumberValidation(val) {
    if (val.length == 0) {
      return translate("required");
    } else if (val.length < 10) {
      return translate("enter10DigitMobileNumber");
    } else {
      return null;
    }
    // return null;
  }

  static passwordValidation(String? val) {
    if (val!.isEmpty) {
      return translate("required");
    } else if (val.length < 6) {
      return translate("passwordValidation");
    } else {
      return null;
    }
    // return null;
  }

  static confirmPasswordValidation(
      String? confirmNewPassword, String password) {
    if (confirmNewPassword!.isEmpty) {
      return translate("required");
    } else if (confirmNewPassword.length < 6) {
      return translate("passwordValidation");
    } else if (confirmNewPassword != password) {
      return translate("passwordConfirmPassValidation");
    } else {
      return null;
    }
    // return null;
  }

  static nameValidation(String val) {
    RegExp nameRegex =
        RegExp(r"^\s*([A-Za-z]{1,}([\.,] |[-']| ))+[A-Za-z]+\.?\s*$");
    if (val.isEmpty) {
      return translate("required");
    } else if (!nameRegex.hasMatch(val)) {
      return translate("enterCorrectName");
    } else {
      return null;
    }
  }
static emailValidation(val) {
  RegExp emailAddress = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
  if (val.length == 0) {
    return translate("emailRequiredValidation");
  } else if (!emailAddress.hasMatch(val)) {
    return translate("enterCorrectEmailAddress");
  } else {
    return null;
  }
}
  // static emailValidation(val) {
  //   RegExp emailAddress = RegExp(
  //       r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
  //   if (val.length == 0) {
  //     return translate("emailRequiredValidation");
  //   } else if (!emailAddress.hasMatch(val)) {
  //     return translate("enterCorrectEmailAddress");
  //   } else {
  //     return null;
  //   }
  // }
}
