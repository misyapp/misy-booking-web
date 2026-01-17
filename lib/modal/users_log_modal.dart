class UsersLogModal {
  String userId;
  String date;
  String logString;

  UsersLogModal({
    required this.userId,
    required this.date,
    required this.logString,
  });

  factory UsersLogModal.fromJson(Map json) {
    return UsersLogModal(
        userId: json['user_id'],
        date: json['date'],
        logString: json['log_string']);
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['user_id'] = userId;
    data['date'] = date;
    data['log_string'] = logString;
    return data;
  }
}
