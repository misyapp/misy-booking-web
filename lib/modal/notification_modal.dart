import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';

class NotificationModal {
  String? createdAt;
  Other? other;
  int? behalfOf;
  int? isRead;
  String? id;
  String? message;
  String? userId;

  NotificationModal({
    this.createdAt,
    this.other,
    this.behalfOf,
    this.isRead,
    this.id,
    this.message,
    this.userId,
  });

  NotificationModal.fromJson(Map<String, dynamic> json) {
    createdAt = formatTimestamp(json['createdAt']);
    other = json['other'] != null ? Other.fromJson(json['other']) : null;
    behalfOf = json['behalfOf'] ?? 0;
    isRead = json['isRead'];
    id = "${json['id'] ?? ''}";
    message = json['message'];
    userId = json['userId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['createdAt'] = createdAt;
    if (other != null) {
      data['other'] = other!.toJson();
    }
    data['behalfOf'] = behalfOf;
    data['isRead'] = isRead;
    data['id'] = id;
    data['message'] = message;
    data['userId'] = userId;
    return data;
  }
}

class Other {
  String? receiver;
  int? sender;
  String? screen;

  Other({this.receiver, this.sender, this.screen});

  Other.fromJson(Map<String, dynamic> json) {
    receiver = json['receiver'];
    sender = json['sender'];
    screen = json['screen'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['receiver'] = receiver;
    data['sender'] = sender;
    data['screen'] = screen;
    return data;
  }
}

String formatTimestamp(Timestamp timestamp,
    {String formateString = 'dd-MM-yyyy HH:mm'}) {
  // Convert Firestore Timestamp to DateTime
  DateTime dateTime = timestamp.toDate();

  // Format DateTime to desired format
  String formattedTime = DateFormat(formateString,
          selectedLanguageNotifier.value["key"] == "en" ? "en_US" : "fr_FR")
      .format(dateTime);

  return formattedTime;
}
