import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';

class MainHeadingText extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final TextAlign? textAlign;
  final double? height;

  const MainHeadingText(this.text,
      {Key? key,
      this.color,
      this.fontSize,
      this.fontWeight,
      this.fontFamily = 'AzoSans',
      this.textAlign,
      this.height})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
          color: color ?? MyColors.blackThemeColor(),
          fontWeight: fontWeight ?? FontWeight.w500,
          fontSize: fontSize ?? 28,
          fontFamily: fontFamily,
          height: height),
    );
  }
}

class AppBarHeadingText extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final TextAlign? textAlign;
  const AppBarHeadingText({
    Key? key,
    required this.text,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.fontFamily = 'AzoSans',
    this.textAlign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
          overflow: TextOverflow.ellipsis,
          color: color ?? MyColors.blackThemeColor(),
          fontWeight: fontWeight ?? FontWeight.w500,
          fontSize: fontSize ?? 22,
          fontFamily: fontFamily),
    );
  }
}

class SubHeadingText extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final TextDecoration? decoration;
  final TextAlign textAlign;
  final bool underlined;
  final int? maxLines;

  const SubHeadingText(
    this.text, {
    Key? key,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.decoration,
    this.maxLines,
    this.fontFamily = 'AzoSans',
    this.textAlign = TextAlign.start,
    this.underlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? MyColors.blackThemeColor();
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      style: TextStyle(
          color: textColor,
          fontWeight: fontWeight ?? FontWeight.w500,
          fontSize: fontSize ?? 18,
          overflow: TextOverflow.ellipsis,
          fontFamily: fontFamily,
          decoration: underlined ? TextDecoration.underline : decoration,
          decorationColor: underlined ? textColor : null),
    );
  }
}

class ParagraphText extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool underlined;
  final double? lineHeight;
  final FontStyle? fontStyle;
  final TextOverflow? textOverflow;
  const ParagraphText(this.text,
      {Key? key,
      this.color,
      this.fontSize,
      this.maxLines,
      this.fontWeight,
      this.fontFamily,
      this.textOverflow,
      this.textAlign,
      this.underlined = false,
      this.lineHeight,
      this.fontStyle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? MyColors.blackThemeColor();
    return Text(
      text,
      textAlign: textAlign ?? TextAlign.start,
      style: TextStyle(
          color: textColor,
          fontWeight: fontWeight ?? FontWeight.w300,
          fontSize: fontSize ?? 14,
          height: lineHeight,
          fontFamily: fontFamily ?? 'AzoSans',
          fontStyle: fontStyle,
          decoration: underlined ? TextDecoration.underline : null,
          decorationColor: underlined ? textColor : null),
      overflow: textOverflow,
      maxLines: maxLines,
    );
  }
}
