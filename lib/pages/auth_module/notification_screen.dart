import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/provider/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../contants/my_colors.dart';
import '../../../contants/my_image_url.dart';
import '../../../contants/sized_box.dart';
import '../../../widget/custom_appbar.dart';
import '../../../widget/custom_circular_image.dart';
import '../../../widget/custom_text.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await Provider.of<NotificationProvider>(context, listen: false)
          .getAllNotiifcationOfUser();
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: translate('notifications'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notiInstant, child) =>
                notiInstant.notificationList.isEmpty
                    ? Container()
                    : TextButton(
                        onPressed: () async {
                          notiInstant.clearAllNotification(context);
                        },
                        child: ParagraphText(
                          translate('clearAll'),
                          fontSize: 14,
                          color: MyColors.primaryColor,
                          underlined: true,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<NotificationProvider>(
            builder: (context, notiInstant, child) => Expanded(
              child: notiInstant.notificationList.isEmpty
                  ? Center(
                      child: SubHeadingText(translate("noDataFound")),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: globalHorizontalPadding, vertical: 10),
                      itemCount: notiInstant.notificationList.length,
                      itemBuilder: (context, index) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: MyColors.textFillThemeColor(),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: ParagraphText(
                                notiInstant.notificationList[index].createdAt ??
                                    '',
                                fontSize: 10,
                                color: MyColors.blackThemeColorWithOpacity(0.5),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CustomCircularImage(
                                  height: 50,
                                  width: 50,
                                  imageUrl: MyImagesUrl.splashLogo,
                                  borderRadius: 0,
                                  fileType: CustomFileType.asset,
                                ),
                                hSizedBox,
                                Expanded(
                                  child: ParagraphText(
                                    notiInstant
                                            .notificationList[index].message ??
                                        '',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
