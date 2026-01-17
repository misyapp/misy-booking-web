import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de message pour le chat rider-driver pendant une course
class ChatMessage {
  final String id;
  final String senderId;
  final String senderType; // "rider" ou "driver"
  final String message;
  final bool isQuickMessage;
  final String? quickMessageKey; // Clé i18n pour messages prédéfinis
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.message,
    this.isQuickMessage = false,
    this.quickMessageKey,
    required this.timestamp,
    this.read = false,
  });

  /// Crée un ChatMessage depuis un document Firestore
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'rider',
      message: data['message'] ?? '',
      isQuickMessage: data['isQuickMessage'] ?? false,
      quickMessageKey: data['quickMessageKey'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderType': senderType,
      'message': message,
      'isQuickMessage': isQuickMessage,
      'quickMessageKey': quickMessageKey,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
    };
  }

  /// Vérifie si ce message a été envoyé par le rider
  bool get isFromRider => senderType == 'rider';

  /// Vérifie si ce message a été envoyé par le driver
  bool get isFromDriver => senderType == 'driver';

  /// Crée une copie avec certains champs modifiés
  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderType,
    String? message,
    bool? isQuickMessage,
    String? quickMessageKey,
    DateTime? timestamp,
    bool? read,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      message: message ?? this.message,
      isQuickMessage: isQuickMessage ?? this.isQuickMessage,
      quickMessageKey: quickMessageKey ?? this.quickMessageKey,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, senderType: $senderType, message: $message, timestamp: $timestamp)';
  }
}

/// Messages prédéfinis pour le rider
class RiderQuickMessages {
  static const String onMyWay = 'msg_on_my_way';
  static const String okUnderstood = 'msg_ok_understood';
  static const String waitPlease = 'msg_wait_please';
  static const String imHere = 'msg_im_here';
  static const String comingDown = 'msg_coming_down';

  static List<String> get all => [onMyWay, okUnderstood, waitPlease, imHere, comingDown];
}

/// Messages prédéfinis pour le driver
class DriverQuickMessages {
  static const String arrived = 'msg_arrived';
  static const String okUnderstood = 'msg_ok_understood';
  static const String waiting = 'msg_waiting';
  static const String traffic = 'msg_traffic';
  static const String almostThere = 'msg_almost_there';

  static List<String> get all => [arrived, okUnderstood, waiting, traffic, almostThere];
}
