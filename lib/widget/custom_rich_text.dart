import 'package:flutter/material.dart';

// ignore: must_be_immutable
class RichTextCustomWidget extends StatelessWidget {
  String firstText;
  String secondText;
  double? firstTextFontSize;
  double? secondTextFontSize;
  Color? firstTextColor;
  Color? secondTextColor;
  FontWeight? firstTextFontweight;
  String? firstTextFontFamily;
  String? secondTextFontFamily;
  FontWeight? secondTextFontweight;
  TextDecoration? secondTextDecoration;

  RichTextCustomWidget({
    super.key,
    required this.firstText,
    required this.secondText,
    this.firstTextFontFamily,
    this.secondTextFontFamily,
    this.firstTextFontSize = 16.0,
    this.secondTextFontSize = 16.0,
    this.firstTextColor,
    this.secondTextColor,
    this.firstTextFontweight,
    this.secondTextFontweight = FontWeight.w500,
    this.secondTextDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: firstText,
        style: TextStyle(
            fontFamily: firstTextFontFamily ?? 'AzoSans',
            fontSize: firstTextFontSize,
            color: firstTextColor,
            fontWeight: firstTextFontweight),
        children: <TextSpan>[
          TextSpan(
            text: secondText,
            style: TextStyle(
                fontFamily: secondTextFontFamily ?? 'AzoSans',
                fontSize: secondTextFontSize,
                color: secondTextColor,
                fontWeight: secondTextFontweight,
                decoration: secondTextDecoration),
          ),
        ],
      ),
    );
  }
}
