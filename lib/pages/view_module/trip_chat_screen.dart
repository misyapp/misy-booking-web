import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/open_whatapp.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/driver_modal.dart';
import 'package:rider_ride_hailing_app/models/chat_message.dart';
import 'package:rider_ride_hailing_app/provider/trip_chat_provider.dart';
import 'package:rider_ride_hailing_app/provider/trip_provider.dart';
import 'package:rider_ride_hailing_app/services/translation_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_circular_image.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran de chat entre le rider et le driver pendant une course
class TripChatScreen extends StatefulWidget {
  final String bookingId;
  final DriverModal driver;

  const TripChatScreen({
    Key? key,
    required this.bookingId,
    required this.driver,
  }) : super(key: key);

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TranslationService _translationService = TranslationService.instance;

  /// Cache des traductions pour éviter les appels répétés
  final Map<String, String> _translationCache = {};

  /// Flag pour éviter de fermer l'écran plusieurs fois
  bool _isClosing = false;

  /// Flag pour activer/désactiver la traduction automatique
  bool _autoTranslateEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadTranslationPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<TripChatProvider>(context, listen: false);
      chatProvider.initChat(widget.bookingId);
      chatProvider.markAllAsRead();

      // Écouter les changements du TripProvider pour détecter l'annulation
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      tripProvider.addListener(_onTripProviderChanged);
    });
  }

  /// Charge la préférence de traduction automatique
  Future<void> _loadTranslationPreference() async {
    final enabled = await _translationService.isAutoTranslateEnabled();
    if (mounted) {
      setState(() {
        _autoTranslateEnabled = enabled;
      });
    }
  }

  /// Traduit un message du driver vers la langue de l'utilisateur
  Future<String> _translateMessage(String message, String messageId) async {
    // Vérifier le cache local
    if (_translationCache.containsKey(messageId)) {
      myCustomPrintStatement('🌐 Translation cache hit for: $messageId');
      return _translationCache[messageId]!;
    }

    // Détecter la langue source et traduire
    final userLanguage = selectedLanguageNotifier.value['key'] as String? ?? 'en';
    myCustomPrintStatement('🌐 User language: $userLanguage');
    myCustomPrintStatement('🌐 Message to translate: "$message"');

    final detectedLang = await _translationService.detectLanguage(message);
    myCustomPrintStatement('🌐 Detected language: $detectedLang');

    // Si même langue, pas de traduction
    if (detectedLang == userLanguage) {
      myCustomPrintStatement('🌐 Same language detected ($detectedLang == $userLanguage), no translation needed');
      _translationCache[messageId] = message;
      return message;
    }

    // Si détection échoue mais message semble être dans la même langue (heuristique)
    // On force quand même la traduction si on ne peut pas détecter
    final sourceLang = detectedLang ?? 'auto';
    myCustomPrintStatement('🌐 Translating from "$sourceLang" to "$userLanguage"');

    final translated = await _translationService.translateText(
      text: message,
      sourceLanguage: sourceLang,
      targetLanguage: userLanguage,
    );

    myCustomPrintStatement('🌐 Translation result: "$translated"');
    _translationCache[messageId] = translated;
    return translated;
  }

  @override
  void dispose() {
    // Retirer le listener du TripProvider
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      tripProvider.removeListener(_onTripProviderChanged);
    } catch (e) {
      myCustomPrintStatement('⚠️ Could not remove TripProvider listener: $e');
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Callback appelé quand le TripProvider change
  void _onTripProviderChanged() {
    if (_isClosing || !mounted) return;

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    // Vérifier si la course a été annulée ou si le booking n'existe plus
    final booking = tripProvider.booking;
    final currentStep = tripProvider.currentStep;

    // Si le booking est null ou si on est revenu à l'étape de sélection de destination
    // cela signifie que la course a été annulée
    if (booking == null || currentStep == CustomTripType.setYourDestination) {
      myCustomPrintStatement('💬 Chat: Course annulée détectée - fermeture de l\'écran de chat');
      _closeWithCancellationMessage();
    }
  }

  /// Ferme l'écran de chat et affiche un message d'annulation
  void _closeWithCancellationMessage() {
    if (_isClosing || !mounted) return;
    _isClosing = true;

    // Fermer l'écran de chat
    Navigator.of(context).pop();

    // Afficher le snackbar d'annulation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translate('Trip was cancelled by driver')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final chatProvider = Provider.of<TripChatProvider>(context, listen: false);
    chatProvider.sendMessage(
      message: message,
      driverDeviceIds: List<String>.from(widget.driver.deviceIdList),
      driverId: widget.driver.id,
      driverName: widget.driver.fullName,
      isDriverOnline: widget.driver.isOnline,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _sendQuickMessage(String quickMessageKey) {
    final chatProvider = Provider.of<TripChatProvider>(context, listen: false);
    chatProvider.sendQuickMessage(
      quickMessageKey: quickMessageKey,
      driverDeviceIds: List<String>.from(widget.driver.deviceIdList),
      driverId: widget.driver.id,
      driverName: widget.driver.fullName,
      isDriverOnline: widget.driver.isOnline,
    );

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.backgroundLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildQuickMessagesBar(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: MyColors.whiteThemeColor(),
      elevation: 1,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: MyColors.blackThemeColor()),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CustomCircularImage(
            imageUrl: widget.driver.profileImage,
            height: 40,
            width: 40,
          ),
          hSizedBox,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SubHeadingText(
                  widget.driver.firstName,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MyColors.textPrimary,
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.driver.isOnline
                            ? MyColors.success
                            : MyColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    hSizedBox05,
                    ParagraphText(
                      widget.driver.isOnline
                          ? translate('online')
                          : translate('offline'),
                      fontSize: 12,
                      color: MyColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Bouton téléphone
        IconButton(
          icon: Image.asset(
            MyImagesUrl.phoneOutline,
            width: 22,
            color: MyColors.blackThemeColor(),
          ),
          onPressed: () async {
            final url = "tel:${widget.driver.countryCode}${widget.driver.phone.startsWith("0") ? widget.driver.phone.substring(1) : widget.driver.phone}";
            if (await canLaunch(url)) {
              await launch(url);
            }
          },
        ),
        // Bouton WhatsApp
        IconButton(
          icon: Image.asset(
            MyImagesUrl.whatsAppIcon,
            width: 24,
            color: MyColors.blackThemeColor(),
          ),
          onPressed: () async {
            await openWhatsApp(
              "${widget.driver.countryCode}${widget.driver.phone.startsWith("0") ? widget.driver.phone.substring(1) : widget.driver.phone}",
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessagesList() {
    return Consumer<TripChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (chatProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: MyColors.error,
                ),
                vSizedBox,
                ParagraphText(
                  translate('chatError'),
                  color: MyColors.textSecondary,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!chatProvider.hasMessages) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: MyColors.textSecondary.withOpacity(0.5),
                ),
                vSizedBox,
                ParagraphText(
                  translate('noMessages'),
                  color: MyColors.textSecondary,
                  textAlign: TextAlign.center,
                ),
                vSizedBox05,
                ParagraphText(
                  translate('startConversation'),
                  fontSize: 12,
                  color: MyColors.textSecondary.withOpacity(0.7),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: chatProvider.messages.length,
          itemBuilder: (context, index) {
            final message = chatProvider.messages[index];
            final isMyMessage = message.isFromRider;
            final showTimestamp = _shouldShowTimestamp(
              chatProvider.messages,
              index,
            );

            return _buildMessageBubble(
              message,
              isMyMessage,
              showTimestamp,
            );
          },
        );
      },
    );
  }

  bool _shouldShowTimestamp(List<ChatMessage> messages, int index) {
    if (index == 0) return true;
    final currentTime = messages[index].timestamp;
    final previousTime = messages[index - 1].timestamp;
    return currentTime.difference(previousTime).inMinutes > 5;
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isMyMessage,
    bool showTimestamp,
  ) {
    return Column(
      crossAxisAlignment:
          isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showTimestamp)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: MyColors.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ParagraphText(
                  _formatTimestamp(message.timestamp),
                  fontSize: 11,
                  color: MyColors.textSecondary,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment:
                isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMyMessage
                      ? MyColors.primaryColor
                      : MyColors.whiteColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMyMessage ? 16 : 4),
                    bottomRight: Radius.circular(isMyMessage ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Message original ou quick message traduit
                    if (message.isQuickMessage && message.quickMessageKey != null)
                      ParagraphText(
                        translate(message.quickMessageKey!),
                        color: isMyMessage
                            ? MyColors.whiteColor
                            : MyColors.textPrimary,
                        fontSize: 14,
                      )
                    else if (isMyMessage)
                      // Mes messages : pas de traduction
                      ParagraphText(
                        message.message,
                        color: MyColors.whiteColor,
                        fontSize: 14,
                      )
                    else
                      // Messages du driver : traduction automatique
                      _buildTranslatedMessage(message),
                    vSizedBox05,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ParagraphText(
                          _formatTime(message.timestamp),
                          fontSize: 10,
                          color: isMyMessage
                              ? MyColors.whiteColor.withOpacity(0.7)
                              : MyColors.textSecondary,
                        ),
                        if (isMyMessage) ...[
                          hSizedBox05,
                          Icon(
                            message.read ? Icons.done_all : Icons.done,
                            size: 14,
                            color: message.read
                                ? Colors.lightBlueAccent
                                : MyColors.whiteColor.withOpacity(0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return translate('today');
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return translate('yesterday');
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Widget qui affiche le message du driver avec traduction automatique
  Widget _buildTranslatedMessage(ChatMessage message) {
    // Si la traduction est désactivée, afficher juste le message
    if (!_autoTranslateEnabled) {
      return ParagraphText(
        message.message,
        color: MyColors.textPrimary,
        fontSize: 14,
      );
    }

    return FutureBuilder<String>(
      future: _translateMessage(message.message, message.id),
      builder: (context, snapshot) {
        final originalMessage = message.message;

        // Pendant le chargement ou en cas d'erreur, afficher le message original
        if (!snapshot.hasData || snapshot.data == originalMessage) {
          return ParagraphText(
            originalMessage,
            color: MyColors.textPrimary,
            fontSize: 14,
          );
        }

        final translatedMessage = snapshot.data!;

        // Afficher le message original et la traduction
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message traduit (principal)
            ParagraphText(
              translatedMessage,
              color: MyColors.textPrimary,
              fontSize: 14,
            ),
            const SizedBox(height: 4),
            // Message original (secondaire, plus petit)
            Container(
              padding: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: MyColors.textSecondary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.translate,
                    size: 12,
                    color: MyColors.textSecondary.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: ParagraphText(
                      originalMessage,
                      color: MyColors.textSecondary.withOpacity(0.7),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickMessagesBar() {
    return Consumer<TripChatProvider>(
      builder: (context, chatProvider, child) {
        final quickMessages = chatProvider.quickMessagesForRider;

        return Container(
          height: 50,
          color: MyColors.whiteColor,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: quickMessages.length,
            itemBuilder: (context, index) {
              final quickMessage = quickMessages[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _sendQuickMessage(quickMessage['key']!),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MyColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: MyColors.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: ParagraphText(
                        quickMessage['label']!,
                        fontSize: 13,
                        color: MyColors.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: MyColors.whiteColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: translate('typeMessage'),
                hintStyle: TextStyle(
                  color: MyColors.textSecondary,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: MyColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          hSizedBox,
          Material(
            color: MyColors.primaryColor,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _sendMessage,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.send,
                  color: MyColors.whiteColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
