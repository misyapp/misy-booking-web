import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/provider/internet_connectivity_provider.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import '../contants/my_colors.dart';
import '../contants/sized_box.dart';
import 'custom_loader.dart';

class RoundEdgedButton extends StatelessWidget {
  final double? height;
  final Color color;
  final Color borderColor;
  final String text;
  final String? fontfamily;
  final Function()? onTap;
  final double horizontalMargin;
  final double iconHeight;
  final double iconWidth;
  final double verticalPadding;
  final double horizontlyPadding;
  final double verticalMargin;
  // final Gradient? gradient;
  final bool isSolid;
  final bool isWhite;
  final bool isBorder;
  final bool isStartAlignment;
  final Color? textColor;
  final double? borderRadius;
  final bool isBold;
  final TextAlign textAlign;
  final bool isIconStart;
  final double? fontSize;
  final double? width;
  final String? icon;
  final bool showGradient;
  final FontWeight? fontWeight;
  final bool load;
  final bool ignoreInternetConnectivity;
  final Widget? iconLeft;
  final double? elevation;


  const RoundEdgedButton(
      {Key? key,
      this.color = MyColors.oldPrimaryColor,
      this.borderColor = MyColors.oldPrimaryColor,
      required this.text,
      this.isWhite = false,
      this.ignoreInternetConnectivity = false,
      this.fontfamily,
      this.onTap,
      this.textAlign = TextAlign.center,
      this.horizontlyPadding = 8,
      this.horizontalMargin = 0,
      this.iconHeight = 18,
      this.iconWidth = 12,
      this.textColor,
      this.borderRadius = 15,
      this.isBold = false,
      this.isIconStart = true,
      this.isBorder = false,
      this.isStartAlignment = false,
      this.verticalMargin = 12,
      this.verticalPadding = 0,
      this.width,
      this.fontSize = 15,
      this.icon,
      this.showGradient = false,
      this.height = 50,
      this.fontWeight = FontWeight.w600,
      this.load = false,
      this.iconLeft,
      this.elevation,
      // required this.hasGradient,
      this.isSolid = true})
      : super(key: key);

  // Factory constructors pour les boutons Misy V2
  factory RoundEdgedButton.primary({
    required String text,
    required VoidCallback onPressed,
    double? width,
    double? height,
    Widget? iconLeft,
  }) {
    return RoundEdgedButton(
      text: text,
      onTap: onPressed,
      color: MyColors.coralPink,
      borderRadius: 12,
      width: width,
      height: height,
      iconLeft: iconLeft,
      elevation: 2,
    );
  }

  factory RoundEdgedButton.secondary({
    required String text,
    required VoidCallback onPressed,
    double? width,
    double? height,
    Widget? iconLeft,
  }) {
    return RoundEdgedButton(
      text: text,
      onTap: onPressed,
      color: MyColors.horizonBlue,
      borderRadius: 12,
      width: width,
      height: height,
      iconLeft: iconLeft,
      elevation: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: load
          ? null
          : () {
              if (onTap != null) {
                bool isConnected = Provider.of<InternetConnectivityProvider>(
                        context,
                        listen: false)
                    .isConnected;
                // Toujours exécuter l'action - la vérification réseau cause des faux positifs
                onTap!();
              }
            },
      child: Container(
          height: height,
          margin: EdgeInsets.symmetric(
              horizontal: horizontalMargin, vertical: verticalMargin),
          width: width,
          padding: EdgeInsets.symmetric(
              horizontal: horizontlyPadding, vertical: verticalPadding),
          decoration: BoxDecoration(
              color: isWhite
                  ? Colors.white
                  : isSolid
                      ? color
                      : Colors.transparent,
              // gradient: hasGradient?gradient ??
              //     LinearGradient(
              //       colors: <Color>[
              //         Color(0xFF064964),
              //         Color(0xFF73E4D9),
              //       ],
              //     ):null,
              gradient: showGradient
                  ? const LinearGradient(
                      // begin: FractionalOffset.topRight,
                      // end: FractionalOffset.bottomCenter,
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xfff02321),
                        Color(0xff781211),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(borderRadius!),
              border: isBorder
                  ? Border.all(color: borderColor)
                  : isSolid
                      ? null
                      : Border.all(color: borderColor),
              boxShadow: elevation != null && elevation! > 0
                  ? [
                      BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                          blurRadius: elevation!,
                          offset: Offset(0, elevation! / 2))
                    ]
                  : [
                      BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                          blurRadius: 2)
                    ]),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isStartAlignment
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (iconLeft != null)
                Padding(
                  padding: EdgeInsets.only(
                      left: textAlign == TextAlign.center ? 10.0 : 0),
                  child: iconLeft!,
                ),
              if (iconLeft != null) hSizedBox,
              if (icon != null && isIconStart && iconLeft == null)
                Padding(
                  padding: EdgeInsets.only(
                      left: textAlign == TextAlign.center ? 10.0 : 0),
                  child: Image.asset(
                    icon!,
                    height: iconHeight,
                    width: iconWidth,
                  ),
                ),
              if (icon != null && isIconStart && iconLeft == null) hSizedBox,
              Flexible(
                child: Text(
                  text,
                  textAlign: textAlign,
                  style: TextStyle(
                      color: textColor ??
                          (isWhite
                              ? MyColors.primaryColor
                              : isSolid
                                  ? Colors.white
                                  : color),
                      fontSize: fontSize ?? 24,
                      fontWeight: fontWeight ?? FontWeight.w600,
                      fontFamily: fontfamily

                      // letterSpacing: 2,
                      ),
                ),
              ),
              if (icon != null && isIconStart == false)
                Padding(
                  padding: EdgeInsets.only(
                    right: textAlign == TextAlign.center ? 5.0 : 0,
                    left: textAlign == TextAlign.center ? 5.0 : 0,
                  ),
                  child: Image.asset(
                    icon!,
                    height: iconHeight,
                    width: iconWidth,
                  ),
                ),
              if (load)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: CustomLoader(
                    color: textColor ??
                        (isWhite
                            ? MyColors.primaryColor
                            : isSolid
                                ? Colors.white
                                : color),
                  ),
                )
            ],
          )),
    );
  }
}
