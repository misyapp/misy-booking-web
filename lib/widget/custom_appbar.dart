import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:url_launcher/url_launcher.dart';
import '../contants/my_colors.dart';
import '../contants/my_image_url.dart';
import '../contants/sized_box.dart';
import 'custom_text.dart';
import 'circular_back_button.dart';

// ignore: must_be_immutable
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  Color? bgcolor;
  Color? titleColor;
  String? title;
  String? imgUrl;
  Widget? titleWidget;
  double? toolbarHeight;
  Widget? subTitleWidget;
  double? titleFontSize;
  bool centerTitle;
  bool isBackIcon;
  bool isNotificationIcon;
  bool isAppIcon;
  bool bottomCurve;
  bool showBottomBorder;
  String leadingIcon;
  FontWeight titleFontWeight;
  double leadingWidth;
  PreferredSizeWidget? bottom;
  Function()? onPressed;
  List<Widget>? actions;
  CustomAppBar({
    Key? key,
    this.bgcolor,
    this.titleColor,
    this.title,
    this.imgUrl,
    this.showBottomBorder = true,
    this.subTitleWidget,
    this.centerTitle = false,
    this.bottomCurve = false,
    this.actions,
    this.bottom,
    this.titleWidget,
    this.titleFontWeight = FontWeight.w600,
    this.onPressed,
    this.leadingWidth = 0,
    this.titleFontSize = 18.0,
    this.isBackIcon = true,
    this.isNotificationIcon = false,
    this.isAppIcon = false,
    this.toolbarHeight = 65.0,
    this.leadingIcon = MyImagesUrl.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: MyColors.blackThemeColor().withOpacity(0.2),
        statusBarIconBrightness:
            Theme.of(MyGlobalKeys.navigatorKey.currentContext!).brightness ==
                    Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      elevation: 0,
      shape: bottomCurve
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            )
          : null,
      title: titleWidget ??
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SubHeadingText(
                title ?? '',
                fontSize: titleFontSize,
                color: titleColor,
                fontWeight: titleFontWeight,
              ),
              subTitleWidget != null ? vSizedBox02 : Container(),
              subTitleWidget ?? Container()
            ],
          ),
      backgroundColor: bgcolor ?? MyColors.transparent,
      centerTitle: centerTitle,
      automaticallyImplyLeading: isBackIcon,
      titleSpacing: 5,
      leadingWidth: isBackIcon ? 56 : leadingWidth,
      leading: isBackIcon
          ? Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: CircularBackButton(
                  onTap: onPressed ??
                      () {
                        Navigator.pop(context);
                      },
                ),
              ),
            )
          : imgUrl != null
              ? Center(
                  child: Image.asset(
                    imgUrl!,
                    height: 40,
                    width: 40,
                  ),
                )
              : Container(),
      actions: actions ??
          [
            isAppIcon
                ? IconButton(
                    onPressed: () async {
                      await launchUrl(Uri.parse("https://pilgrimpaths.com"));
                    },
                    icon: Image.asset(
                      MyImagesUrl.user,
                      fit: BoxFit.fill,
                      width: 40,
                    ),
                  )
                : Container(),
            isNotificationIcon
                ? IconButton(
                    onPressed: () {
                      // push(
                      //   context: context,
                      //   screen: const NotificationScreen(),
                      // );
                    },
                    icon: Image.asset(
                      MyImagesUrl.user,
                      height: 25,
                      width: 25,
                    ),
                  )
                : Container(),
          ],
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight!);
}
