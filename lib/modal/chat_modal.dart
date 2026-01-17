





class ChatModal {
  int from;
  int to;
  String message;
  String messageType;
  String createdAt;

  ChatModal({
    required this.from,
    required this.to,
    required this.message,
    required this.messageType,
    required this.createdAt,
  });

  factory ChatModal.fromJson(Map data) {
    return ChatModal(
      from: data['from'],
      to: data['to'],
      message: data['message'],
      messageType: data['messageType'],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "from": from,
      "to": to,
      "message": message,
      "messageType": messageType,
      "createdAt": createdAt,
    };
  }
}
