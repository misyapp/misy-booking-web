import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../contants/global_data.dart';
import '../../contants/language_strings.dart';
import '../../contants/my_colors.dart';

/// Ecran Boite de reception - Messages du dashboard pour les passagers
class InboxScreen extends StatefulWidget {
  /// Si true, affiche le bouton retour dans l'AppBar (mode standalone)
  /// Si false, n'affiche pas de bouton retour (mode navigation bar)
  final bool showBackButton;

  const InboxScreen({super.key, this.showBackButton = false});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String selectedFilter = 'all'; // 'all', 'unread' ou 'archived'
  bool isDefaultMessageRead = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultMessageReadState();
  }

  Future<void> _loadDefaultMessageReadState() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = userData.value?.id ?? '';
    final key = 'default_rider_message_read_$userId';
    setState(() {
      isDefaultMessageRead = prefs.getBool(key) ?? false;
    });
  }

  Future<void> _saveDefaultMessageReadState(bool isRead) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = userData.value?.id ?? '';
    final key = 'default_rider_message_read_$userId';
    await prefs.setBool(key, isRead);
    setState(() {
      isDefaultMessageRead = isRead;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.backgroundThemeColor(),
      appBar: AppBar(
        backgroundColor: MyColors.whiteThemeColor(),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios, color: MyColors.blackThemeColor()),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          translate('inbox'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: MyColors.blackThemeColor(),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Boutons filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: MyColors.whiteThemeColor(),
            child: _buildFilterButtons(),
          ),
          // Liste des messages
          Expanded(
            child: _buildMessagesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterButton(
            label: translate('allMessages'),
            value: 'all',
            isSelected: selectedFilter == 'all',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterButton(
            label: translate('unreadMessages'),
            value: 'unread',
            isSelected: selectedFilter == 'unread',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterButton(
            label: translate('archivedMessages'),
            value: 'archived',
            isSelected: selectedFilter == 'archived',
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? MyColors.primaryColor.withValues(alpha: 0.15)
              : MyColors.backgroundThemeColor(),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? MyColors.primaryColor
                : MyColors.borderThemeColor(),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? MyColors.primaryColor
                  : MyColors.textSecondaryTheme(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    // Si aucun utilisateur connecté, afficher uniquement le message de bienvenue
    if (userData.value == null) {
      if (_shouldShowDefaultMessage()) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [_buildDefaultMessageCard()],
        );
      }
      return _buildEmptyState(translate('noMessages'));
    }

    final userId = userData.value!.id;

    return StreamBuilder<QuerySnapshot>(
      stream: _getMessagesStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          if (_shouldShowDefaultMessage()) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [_buildDefaultMessageCard()],
            );
          }
          return _buildEmptyState(translate('noMessages'));
        }

        var messages = snapshot.data?.docs ?? [];

        // D'abord, exclure les messages supprimés par l'utilisateur
        messages = messages.where((doc) {
          final message = doc.data() as Map<String, dynamic>;
          return !_isMessageDeleted(message);
        }).toList();

        // Filtrer selon le filtre selectionne
        if (selectedFilter == 'unread') {
          messages = messages.where((doc) {
            final message = doc.data() as Map<String, dynamic>;
            return !_isMessageRead(message) && !_isMessageArchived(message);
          }).toList();
        } else if (selectedFilter == 'archived') {
          messages = messages.where((doc) {
            final message = doc.data() as Map<String, dynamic>;
            return _isMessageArchived(message);
          }).toList();
        } else {
          messages = messages.where((doc) {
            final message = doc.data() as Map<String, dynamic>;
            return !_isMessageArchived(message);
          }).toList();
        }

        final totalCount = messages.length + _getDefaultMessageCount();

        if (totalCount == 0) {
          return _buildEmptyState(translate('noMessages'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            if (index == 0 && _shouldShowDefaultMessage()) {
              return _buildDefaultMessageCard();
            }

            final messageIndex = _shouldShowDefaultMessage() ? index - 1 : index;
            final message = messages[messageIndex].data() as Map<String, dynamic>;
            final messageId = messages[messageIndex].id;
            return _buildMessageCard(message, messageId);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getMessagesStream(String userId) {
    return FirebaseFirestore.instance
        .collection('riderMessages')
        .where('recipientIds', arrayContains: userId)
        .orderBy('sentAt', descending: true)
        .snapshots();
  }

  Widget _buildMessageCard(Map<String, dynamic> message, String messageId) {
    final isRead = _isMessageRead(message);
    final isArchived = _isMessageArchived(message);
    final sentAt = (message['sentAt'] as Timestamp?)?.toDate();
    final subject = message['subject'] ?? 'Sans sujet';

    return Dismissible(
      key: Key(messageId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (isArchived) {
          _unarchiveMessage(messageId);
        } else {
          _archiveMessage(messageId);
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isArchived ? Colors.green : Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              isArchived ? translate('unarchive') : translate('archive'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () {
          _markAsRead(messageId);
          _showMessageDetail(message, messageId);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead
                ? MyColors.cardThemeColor()
                : MyColors.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead
                  ? MyColors.borderThemeColor()
                  : MyColors.primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: MyColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      subject,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                        color: MyColors.blackThemeColor(),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isArchived)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        translate('archived'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sentAt != null ? _formatDate(sentAt) : translate('unknownDate'),
                      style: TextStyle(
                        fontSize: 13,
                        color: MyColors.textSecondaryTheme(),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          if (isArchived) {
                            _unarchiveMessage(messageId);
                          } else {
                            _archiveMessage(messageId);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                            size: 20,
                            color: isArchived ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _deleteMessage(messageId),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.delete_rounded,
                            size: 20,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowDefaultMessage() {
    if (selectedFilter == 'archived') return false;
    if (selectedFilter == 'unread') return !isDefaultMessageRead;
    return true;
  }

  int _getDefaultMessageCount() {
    return _shouldShowDefaultMessage() ? 1 : 0;
  }

  Widget _buildDefaultMessageCard() {
    final isRead = isDefaultMessageRead;

    return GestureDetector(
      onTap: () => _showWelcomeMessage(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? MyColors.cardThemeColor()
              : MyColors.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead
                ? MyColors.borderThemeColor()
                : MyColors.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: MyColors.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    translate('welcomeMessageTitle'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                      color: MyColors.blackThemeColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              translate('welcomeMessageSubtitle'),
              style: TextStyle(
                fontSize: 13,
                color: MyColors.textSecondaryTheme(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWelcomeMessage() {
    _saveDefaultMessageReadState(true);

    // Récupérer le prénom de l'utilisateur (si connecté)
    final userName = userData.value?.fullName.split(' ').first ?? '';
    final greeting = userName.isNotEmpty ? 'Bonjour $userName !' : 'Bonjour !';

    final htmlContent = '''
      <div style="padding: 0 16px 16px 16px;">


        <!-- Étapes numérotées -->
        <div style="background: #f8f9fa; border-radius: 16px; padding: 20px; margin-bottom: 20px;">
          <h2 style="color: #333; font-size: 18px; margin-bottom: 16px; text-align: center;">
            Comment ça marche ?
          </h2>

          <p style="margin: 12px 0; font-size: 15px;">
            <span style="color: white; background: #FF5357; padding: 4px 10px; border-radius: 50%; margin-right: 10px;">1</span>
            <strong style="color: #333;">Entrez votre destination</strong><br/>
            <span style="color: #666; font-size: 13px; margin-left: 36px;">Saisissez où vous voulez aller</span>
          </p>

          <p style="margin: 12px 0; font-size: 15px;">
            <span style="color: white; background: #FF5357; padding: 4px 10px; border-radius: 50%; margin-right: 10px;">2</span>
            <strong style="color: #333;">Choisissez votre véhicule</strong><br/>
            <span style="color: #666; font-size: 13px; margin-left: 36px;">Moto, voiture ou van selon vos besoins</span>
          </p>

          <p style="margin: 12px 0; font-size: 15px;">
            <span style="color: white; background: #FF5357; padding: 4px 10px; border-radius: 50%; margin-right: 10px;">3</span>
            <strong style="color: #333;">Suivez votre chauffeur</strong><br/>
            <span style="color: #666; font-size: 13px; margin-left: 36px;">En temps réel sur la carte</span>
          </p>
        </div>

        <!-- Moyens de paiement -->
        <div style="background: #E8F5E9; border-radius: 16px; padding: 16px; margin-bottom: 20px; text-align: center;">
          <p style="color: #2E7D32; font-size: 15px; margin: 0;">
            💳 <strong>Payez comme vous voulez</strong>
          </p>
          <p style="color: #558B2F; font-size: 13px; margin-top: 6px;">
            Espèces • Airtel Money • Orange Money • MVola
          </p>
        </div>

        <!-- Footer -->
        <div style="text-align: center; padding-top: 8px;">
          <p style="color: #FF5357; font-size: 16px; margin-bottom: 8px;">
            🎯 <strong>Bonne route avec Misy !</strong>
          </p>
          <p style="color: #999; font-size: 12px;">
            L'équipe Misy
          </p>
        </div>

      </div>
    ''';

    _showWelcomeBottomSheet(greeting, htmlContent);
  }

  /// Bottom sheet personnalisée pour le message de bienvenue avec logo Flutter natif
  void _showWelcomeBottomSheet(String greeting, String htmlContent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: MyColors.whiteThemeColor(),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Titre
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      translate('welcomeMessageTitle'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: MyColors.blackThemeColor(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Divider(height: 1, color: MyColors.borderThemeColor()),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Logo Misy natif Flutter
                          Image.asset(
                            'assets/icons/misy_logo_rose.png',
                            width: 80,
                            height: 80,
                          ),
                          const SizedBox(height: 16),
                          // Salutation personnalisée
                          Text(
                            greeting,
                            style: const TextStyle(
                              color: Color(0xFFFF5357),
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bienvenue dans la famille Misy 🎉',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Icônes Taxi-moto et Taxi côte à côte (depuis Firebase)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Taxi-moto
                              if (vehicleListModal.any((v) => v.name.toLowerCase().contains('moto')))
                                Image.network(
                                  vehicleListModal.firstWhere((v) => v.name.toLowerCase().contains('moto')).image,
                                  width: 50,
                                  height: 50,
                                ),
                              const SizedBox(width: 16),
                              // Taxi
                              if (vehicleListModal.any((v) => v.name.toLowerCase() == 'taxi'))
                                Image.network(
                                  vehicleListModal.firstWhere((v) => v.name.toLowerCase() == 'taxi').image,
                                  width: 50,
                                  height: 50,
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Contenu HTML
                          HtmlWidget(
                            htmlContent,
                            textStyle: TextStyle(
                              color: MyColors.blackThemeColor(),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mail_outline_rounded,
              size: 64,
              color: MyColors.textSecondaryTheme().withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: MyColors.textSecondaryTheme(),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _isMessageRead(Map<String, dynamic> message) {
    if (userData.value == null) return false;
    final readBy = message['readBy'] as List<dynamic>?;
    return readBy?.contains(userData.value!.id) ?? false;
  }

  bool _isMessageArchived(Map<String, dynamic> message) {
    if (userData.value == null) return false;
    final archivedBy = message['archivedBy'] as List<dynamic>?;
    return archivedBy?.contains(userData.value!.id) ?? false;
  }

  void _markAsRead(String messageId) {
    if (userData.value == null) return;
    FirebaseFirestore.instance
        .collection('riderMessages')
        .doc(messageId)
        .update({
      'readBy': FieldValue.arrayUnion([userData.value!.id]),
    }).catchError((error) {});
  }

  void _archiveMessage(String messageId) {
    if (userData.value == null) return;
    FirebaseFirestore.instance
        .collection('riderMessages')
        .doc(messageId)
        .update({
      'archivedBy': FieldValue.arrayUnion([userData.value!.id]),
    }).catchError((error) {});
  }

  void _unarchiveMessage(String messageId) {
    if (userData.value == null) return;
    FirebaseFirestore.instance
        .collection('riderMessages')
        .doc(messageId)
        .update({
      'archivedBy': FieldValue.arrayRemove([userData.value!.id]),
    }).catchError((error) {});
  }

  void _deleteMessage(String messageId) {
    if (userData.value == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(translate('deleteMessage')),
        content: Text(translate('deleteMessageConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Soft delete: ajouter l'userId à deletedBy au lieu de modifier recipientIds
              // Ceci préserve les statistiques du dashboard admin
              FirebaseFirestore.instance
                  .collection('riderMessages')
                  .doc(messageId)
                  .update({
                'deletedBy': FieldValue.arrayUnion([userData.value!.id]),
              }).catchError((error) {});
            },
            child: Text(
              translate('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  bool _isMessageDeleted(Map<String, dynamic> message) {
    if (userData.value == null) return false;
    final deletedBy = message['deletedBy'] as List<dynamic>?;
    return deletedBy?.contains(userData.value!.id) ?? false;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${translate('today')} ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('d MMM yyyy', 'fr_FR').format(date);
    }
  }

  void _showMessageDetail(Map<String, dynamic> message, String messageId) {
    final content = message['content'] ?? '';
    final subject = message['subject'] ?? 'Sans sujet';

    _showHtmlBottomSheet(subject, content);
  }

  void _showHtmlBottomSheet(String title, String htmlContent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: MyColors.whiteThemeColor(),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: MyColors.blackThemeColor(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Divider(height: 1, color: MyColors.borderThemeColor()),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: HtmlWidget(
                        htmlContent,
                        textStyle: TextStyle(
                          color: MyColors.blackThemeColor(),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
