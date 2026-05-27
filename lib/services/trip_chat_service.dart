import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/chat_message.dart';
import 'package:rider_ride_hailing_app/services/firebase_push_notifications.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';

/// Service de messagerie pour le chat rider-driver pendant une course
class TripChatService {
  static final TripChatService _instance = TripChatService._internal();
  factory TripChatService() => _instance;
  TripChatService._internal();

  /// Référence à la sous-collection messages d'un booking
  CollectionReference _messagesCollection(String bookingId) {
    return FirestoreServices.bookingRequest.doc(bookingId).collection('messages');
  }

  /// Stream des messages pour un booking (temps réel)
  Stream<List<ChatMessage>> getMessagesStream(String bookingId) {
    myCustomPrintStatement('💬 getMessagesStream appelé pour bookingId: $bookingId');
    myCustomPrintStatement('💬 Collection path: ${_messagesCollection(bookingId).path}');

    return _messagesCollection(bookingId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      myCustomPrintStatement('💬 Snapshot reçu: ${snapshot.docs.length} documents');
      final messages = snapshot.docs.map((doc) {
        myCustomPrintStatement('💬 Document: ${doc.id} - ${doc.data()}');
        return ChatMessage.fromFirestore(doc);
      }).toList();
      return messages;
    });
  }

  /// Envoyer un message
  /// [bookingId] - ID du booking/course
  /// [senderId] - ID de l'expéditeur (rider ou driver)
  /// [senderType] - "rider" ou "driver"
  /// [message] - Contenu du message
  /// [isQuickMessage] - Si c'est un message prédéfini
  /// [quickMessageKey] - Clé i18n du message prédéfini
  Future<void> sendMessage({
    required String bookingId,
    required String senderId,
    required String senderType,
    required String message,
    bool isQuickMessage = false,
    String? quickMessageKey,
    String? mediaUrl,
    String? mediaType,
    int? mediaDurationMs,
  }) async {
    try {
      final messageData = <String, dynamic>{
        'senderId': senderId,
        'senderType': senderType,
        'message': message,
        'isQuickMessage': isQuickMessage,
        'quickMessageKey': quickMessageKey,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      if (mediaUrl != null) messageData['mediaUrl'] = mediaUrl;
      if (mediaType != null) messageData['mediaType'] = mediaType;
      if (mediaDurationMs != null) messageData['mediaDurationMs'] = mediaDurationMs;

      await _messagesCollection(bookingId).add(messageData);
      myCustomPrintStatement('💬 Message envoyé: $message');
    } catch (e) {
      myCustomPrintStatement('❌ Erreur envoi message: $e');
      rethrow;
    }
  }

  /// Envoyer un message et notifier le destinataire via push
  Future<void> sendMessageWithNotification({
    required String bookingId,
    required String senderId,
    required String senderType,
    required String message,
    required List<String> recipientDeviceIds,
    required String recipientId,
    required String senderName,
    bool isQuickMessage = false,
    String? quickMessageKey,
    bool isRecipientOnline = true,
    String? mediaUrl,
    String? mediaType,
    int? mediaDurationMs,
  }) async {
    // Envoyer le message dans Firestore
    await sendMessage(
      bookingId: bookingId,
      senderId: senderId,
      senderType: senderType,
      message: message,
      isQuickMessage: isQuickMessage,
      quickMessageKey: quickMessageKey,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      mediaDurationMs: mediaDurationMs,
    );

    // Envoyer la notification push
    if (recipientDeviceIds.isNotEmpty) {
      try {
        myCustomPrintStatement('📱 Envoi notification à ${recipientDeviceIds.length} device(s)');
        await FirebasePushNotifications.sendPushNotifications(
          deviceIds: recipientDeviceIds,
          title: senderName,
          body: message,
          data: {
            'screen': 'chat_message',
            'bookingId': bookingId,
            'senderId': senderId,
            'senderType': senderType,
            'senderName': senderName,
          },
          userId: recipientId,
          isOnline: isRecipientOnline,
        );
        myCustomPrintStatement('📤 Push notification envoyée pour message');
      } catch (e) {
        myCustomPrintStatement('⚠️ Erreur push notification message: $e');
        // Ne pas faire rethrow - le message est déjà envoyé
      }
    } else {
      myCustomPrintStatement('⚠️ Pas de deviceId pour le destinataire - notification non envoyée');
    }
  }

  /// Marquer tous les messages comme lus pour un utilisateur
  Future<void> markAllAsRead({
    required String bookingId,
    required String readerId,
    required String readerType,
  }) async {
    try {
      // Récupérer les messages non lus envoyés par l'autre partie
      final otherSenderType = readerType == 'rider' ? 'driver' : 'rider';
      final unreadMessages = await _messagesCollection(bookingId)
          .where('senderType', isEqualTo: otherSenderType)
          .where('read', isEqualTo: false)
          .get();

      // Marquer chaque message comme lu
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      myCustomPrintStatement('✅ ${unreadMessages.docs.length} messages marqués comme lus');
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur marquage messages lus: $e');
    }
  }

  /// Stream du nombre de messages non lus
  Stream<int> getUnreadCountStream({
    required String bookingId,
    required String readerType,
  }) {
    // Compter les messages de l'autre partie qui ne sont pas lus
    final otherSenderType = readerType == 'rider' ? 'driver' : 'rider';
    return _messagesCollection(bookingId)
        .where('senderType', isEqualTo: otherSenderType)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Obtenir le nombre de messages non lus (one-shot)
  Future<int> getUnreadCount({
    required String bookingId,
    required String readerType,
  }) async {
    final otherSenderType = readerType == 'rider' ? 'driver' : 'rider';
    final snapshot = await _messagesCollection(bookingId)
        .where('senderType', isEqualTo: otherSenderType)
        .where('read', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  /// Supprimer tous les messages d'un booking (pour nettoyage)
  Future<void> deleteAllMessages(String bookingId) async {
    try {
      final messages = await _messagesCollection(bookingId).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      myCustomPrintStatement('🗑️ Messages supprimés pour booking $bookingId');
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur suppression messages: $e');
    }
  }
}
