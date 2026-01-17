import 'package:flutter/material.dart';
import '../contants/my_colors.dart';
import '../modal/chat_modal.dart';
import 'custom_text.dart';


class ConversationMessageCard extends StatelessWidget {
  final ChatModal chatMessage;
  final Alignment messageAlignment;
  final Color messagesBgColor;
  final TextStyle messagesTextStyle;
  const ConversationMessageCard({
    super.key,
    required this.messageAlignment,
    // required this.messages,
    required this.chatMessage,
    required this.messagesBgColor,
    required this.messagesTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        children: [
          Align(
            alignment: messageAlignment,
            child: Container(
              // height: 100,
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 245,
              decoration: BoxDecoration(
                color: messagesBgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  bottomRight: Radius.circular(
                      MyColors.primaryColor == messagesBgColor ? 15 : 0),
                  bottomLeft: Radius.circular(
                      MyColors.primaryColor != messagesBgColor ? 15 : 0),
                  topRight: const Radius.circular(15),
                ),
              ),
              child: Text(
                chatMessage.message,
                style: messagesTextStyle,
              ),
            ),
          ),
          Align(
            alignment: messagesBgColor == MyColors.primaryColor
                ? Alignment.topLeft
                : Alignment.topRight,
            child: SizedBox(
              // height: 100,
              // width: messagesBgColor == MyColors.primaryColor ? 150 : 50,
              child: ParagraphText(
                chatMessage.createdAt,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                // style: ThemeStyle.fontSize10LightGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
