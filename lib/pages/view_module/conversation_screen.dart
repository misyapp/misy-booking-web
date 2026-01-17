import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';

import '../../contants/my_colors.dart';
import '../../contants/my_image_url.dart';
import '../../contants/sized_box.dart';
import '../../contants/static_json.dart';
import '../../widget/conversation_message.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/custom_text.dart';
import '../../widget/input_text_field_widget.dart';


class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  TextEditingController messageController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: CustomAppBar(
          isBackIcon: true,
          bottomCurve: false,
          titleWidget: const SizedBox(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: AssetImage( MyImagesUrl.profileImage,),

                ),
                hSizedBox,
                ParagraphText(
                  "John Smith",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                )
              ],
            ),
          ),
          actions: [
            IconButton(onPressed: (){}, icon:Image.asset(MyImagesUrl.phone,width: 30,color: MyColors.blackThemeColor(),)),
            IconButton(onPressed: (){}, icon:Icon(Icons.more_vert,size: 22,color: MyColors.blackThemeColor(),))
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: globalHorizontalPadding),
                child: ListView.builder(
                  reverse: true,
                  itemCount: chatDeatilJson.length,
                  itemBuilder: (context, index) => ConversationMessageCard(
                      messageAlignment: chatDeatilJson[index].from != 2
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      chatMessage: chatDeatilJson[index],
                      messagesBgColor: chatDeatilJson[index].from != 1
                          ? MyColors.blackThemeColor()
                          : MyColors.primaryColor,
                      messagesTextStyle:TextStyle(
                        color:chatDeatilJson[index].from != 1 ? MyColors.whiteThemeColor()
                            : MyColors.whiteColor,
                        fontSize: 12,
                      )),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child:  InputTextFieldWidget(
                    horizontalPadding: true,
                    verticalPadding: 10,
                    borderColor: Colors.transparent,
                    fillColor: MyColors.textFillThemeColor(),
                    controller: messageController,
                    obscureText: false,
                    hintText: "Type a message...",
                    suffix:Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor:MyColors.blackThemeColorWithOpacity(0.4),
                            child: Icon(Icons.add,size: 19,color: MyColors.whiteThemeColor(),),
                          ),
                          hSizedBox,
                          Image.asset(MyImagesUrl.send,color: MyColors.blackThemeColor(),width: 23,),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
