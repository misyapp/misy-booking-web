import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/chat_message.dart';
import 'package:rider_ride_hailing_app/services/trip_chat_service.dart';

/// Provider pour gérer le chat rider-driver pendant une course
class TripChatProvider extends ChangeNotifier {
  final TripChatService _chatService = TripChatService();

  // État du chat
  List<ChatMessage> _messages = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _currentBookingId;
  String? _error;

  // Streams
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _unreadSubscription;

  // Getters
  List<ChatMessage> get messages => _messages;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get currentBookingId => _currentBookingId;
  String? get error => _error;
  bool get hasMessages => _messages.isNotEmpty;

  /// Initialise le chat pour un booking spécifique
  void initChat(String bookingId) {
    myCustomPrintStatement('💬 initChat appelé avec bookingId: $bookingId');
    myCustomPrintStatement('💬 _currentBookingId actuel: $_currentBookingId');

    if (_currentBookingId == bookingId && _messagesSubscription != null) {
      myCustomPrintStatement('💬 Chat déjà initialisé pour booking $bookingId');
      return;
    }

    // Nettoyer l'ancien chat
    disposeChat();

    _currentBookingId = bookingId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    myCustomPrintStatement('💬 Initialisation chat pour booking $bookingId');

    // Écouter les messages en temps réel
    _messagesSubscription = _chatService.getMessagesStream(bookingId).listen(
      (messages) {
        _messages = messages;
        _isLoading = false;
        _error = null;
        notifyListeners();
        myCustomPrintStatement('💬 ${messages.length} messages reçus du stream');
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
        myCustomPrintStatement('❌ Erreur stream messages: $e');
      },
    );

    myCustomPrintStatement('💬 Stream messages configuré');

    // Écouter le compteur de non-lus
    _unreadSubscription = _chatService
        .getUnreadCountStream(bookingId: bookingId, readerType: 'rider')
        .listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (e) {
        myCustomPrintStatement('⚠️ Erreur stream unread: $e');
      },
    );
  }

  /// Envoie un message texte libre
  Future<void> sendMessage({
    required String message,
    required List<String> driverDeviceIds,
    required String driverId,
    required String driverName,
    bool isDriverOnline = true,
  }) async {
    if (_currentBookingId == null) {
      myCustomPrintStatement('❌ Pas de booking actif pour envoyer un message');
      return;
    }

    if (message.trim().isEmpty) {
      return;
    }

    final riderId = userData.value?.id ?? '';
    final riderName = userData.value?.firstName ?? 'Passager';

    try {
      await _chatService.sendMessageWithNotification(
        bookingId: _currentBookingId!,
        senderId: riderId,
        senderType: 'rider',
        message: message.trim(),
        recipientDeviceIds: driverDeviceIds,
        recipientId: driverId,
        senderName: riderName,
        isRecipientOnline: isDriverOnline,
      );
    } catch (e) {
      myCustomPrintStatement('❌ Erreur envoi message: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Envoie un message prédéfini rapide
  Future<void> sendQuickMessage({
    required String quickMessageKey,
    required List<String> driverDeviceIds,
    required String driverId,
    required String driverName,
    bool isDriverOnline = true,
  }) async {
    if (_currentBookingId == null) {
      myCustomPrintStatement('❌ Pas de booking actif pour envoyer un message rapide');
      return;
    }

    final riderId = userData.value?.id ?? '';
    final riderName = userData.value?.firstName ?? 'Passager';
    final translatedMessage = translate(quickMessageKey);

    try {
      await _chatService.sendMessageWithNotification(
        bookingId: _currentBookingId!,
        senderId: riderId,
        senderType: 'rider',
        message: translatedMessage,
        isQuickMessage: true,
        quickMessageKey: quickMessageKey,
        recipientDeviceIds: driverDeviceIds,
        recipientId: driverId,
        senderName: riderName,
        isRecipientOnline: isDriverOnline,
      );
    } catch (e) {
      myCustomPrintStatement('❌ Erreur envoi message rapide: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Marque tous les messages comme lus
  Future<void> markAllAsRead() async {
    if (_currentBookingId == null) return;

    final riderId = userData.value?.id ?? '';

    try {
      await _chatService.markAllAsRead(
        bookingId: _currentBookingId!,
        readerId: riderId,
        readerType: 'rider',
      );
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur marquage lu: $e');
    }
  }

  /// Nettoie les ressources du chat
  void disposeChat() {
    _messagesSubscription?.cancel();
    _unreadSubscription?.cancel();
    _messagesSubscription = null;
    _unreadSubscription = null;
    _messages = [];
    _unreadCount = 0;
    _currentBookingId = null;
    _error = null;
    _isLoading = false;
    myCustomPrintStatement('🧹 Chat nettoyé');
  }

  /// Initialise le compteur de non-lus sans ouvrir le chat complet
  /// Utile pour afficher le badge sur le bouton chat
  void initUnreadCounter(String bookingId) {
    if (_currentBookingId == bookingId && _unreadSubscription != null) {
      return; // Déjà initialisé
    }

    _currentBookingId = bookingId;
    _unreadSubscription?.cancel();
    _unreadSubscription = _chatService
        .getUnreadCountStream(bookingId: bookingId, readerType: 'rider')
        .listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (e) {
        myCustomPrintStatement('⚠️ Erreur stream unread counter: $e');
      },
    );
  }

  @override
  void dispose() {
    disposeChat();
    super.dispose();
  }

  /// Liste des messages rapides disponibles pour le rider
  List<Map<String, String>> get quickMessagesForRider {
    return RiderQuickMessages.all.map((key) {
      return {
        'key': key,
        'label': translate(key),
      };
    }).toList();
  }
}
