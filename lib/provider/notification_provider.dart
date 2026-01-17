import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/modal/notification_modal.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:rider_ride_hailing_app/widget/common_alert_dailog.dart';
import 'package:flutter/material.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModal> notificationList = [];
  getAllNotiifcationOfUser() async {
    await showLoading();
    var querySnapshot = await FirestoreServices.notifications
        .orderBy('createdAt', descending: false)
        .get();
    List<NotificationModal> notificationListTemp = [];
    if (querySnapshot.docs.isNotEmpty) {
      for (int i = 0; i < querySnapshot.docs.length; i++) {
        // Access the data of each document
        Map<String, dynamic> data =
            querySnapshot.docs[i].data() as Map<String, dynamic>;
        if ((querySnapshot.docs[i].data() as Map)['read'] == false) {
          FirestoreServices.notifications
              .doc(querySnapshot.docs[i].id)
              .update({"read": true});
        }
        notificationListTemp.add(NotificationModal.fromJson(data));
      }
    }
    await hideLoading();

    notificationList = notificationListTemp.reversed.toList();
    notifyListeners();
    return notificationListTemp;
  }

  clearAllNotification(context) async {
    bool confirm = await showCommonAlertDailog(context,
        headingText: translate("areYouSure"),
        buttonAlignMent: MainAxisAlignment.center,
        successIcon: false,
        confirmButtonText: translate("yes"),
        cancelButtonText: translate("no"),
        message: translate("deleteAllNotiAlert"));
    if (confirm) {
      await FirestoreServices.clearAllDataFromCollection(
          FirestoreServices.notifications);
      notificationList = [];
      notifyListeners();
    }
  }
}
