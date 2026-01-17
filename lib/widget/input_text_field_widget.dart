// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../contants/global_data.dart';
import '../contants/my_colors.dart';
import '../contants/sized_box.dart';
import 'custom_text.dart';

class InputTextFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final double? width;
  final String hintText;
  final Color? textColor;
  final Color? fillColor;
  final Color? focusedBorderColor;
  final BoxBorder? border;
  final bool horizontalPadding;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final Color? bgColor;
  final Color? borderColor;
  final Color? hintcolor;
  final double verticalPadding;
  final double? fontsize;
  final double? hintTextFontsize;
  final double borderRadius;
  final double? contentPaddingVertical;
  final double? contentPaddinghorizonatly;
  final Function(String)? onChanged;
  final Function(String?)? onSaved;
  final String? Function(String?)? validator;
  final String? headingText;
  final double? headingfontSize;
  final Function()? onTap;
  final Widget? suffix;
  final Widget? preffix;
  final String? prefixText;
  TextInputType? keyboardType;
  final bool enabled;
  final bool readOnly;
  final String? suffixText;
  final bool enableInteractiveSelection;
  final bool textalign;
  final bool? autofocus;
  final FontWeight? headingfontWeight;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  bool filled;
  InputTextFieldWidget({
    Key? key,
    required this.controller,
    required this.hintText,
    this.border,
    this.inputFormatters,
    this.contentPaddinghorizonatly,
    this.borderColor,
    this.maxLines,
    this.validator,
    this.fillColor,
    this.maxLength,
    this.onSaved,
    this.headingfontWeight,
    this.autofocus = false,
    this.preffix,
    this.filled = true,
    this.headingfontSize = 15,
    this.headingText,
    this.contentPaddingVertical,
    this.horizontalPadding = false,
    this.obscureText = false,
    this.bgColor,
    this.hintcolor,
    this.verticalPadding = 0,
    this.fontsize,
    this.hintTextFontsize,
    this.borderRadius = 10,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.suffix,
    this.suffixText,
    this.textColor,
    this.focusedBorderColor,
    this.prefixText,
    this.focusNode,
    this.enableInteractiveSelection = true,
    this.onTap,
    this.textalign = false,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: bgColor,
        border: border,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding ? globalHorizontalPadding : 0,
          vertical: verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (headingText != null)
            SubHeadingText(
              headingText!,
              fontSize: headingfontSize,
              fontWeight: headingfontWeight,
            ),
          if (headingText != null) vSizedBox05,
          TextFormField(
              readOnly: readOnly,
              cursorColor: Theme.of(context).primaryColor,
              maxLines: maxLines ?? 1,
              maxLength: maxLength,
              focusNode: focusNode,
              textAlign: textalign ? TextAlign.center : TextAlign.left,
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: TextStyle(
                  color: textColor ?? MyColors.blackThemeColor(),
                  fontSize: fontsize ?? 15),
              autofocus: autofocus!,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.done,
              // enableInteractiveSelection: true,
              inputFormatters: inputFormatters,
              enabled: enabled,
              decoration: InputDecoration(
                // labelText: hintText,
                counterText: '',
                alignLabelWithHint: true,
                fillColor:
                    fillColor ?? Theme.of(context).scaffoldBackgroundColor,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                filled: filled,
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: borderColor ?? MyColors.textFilledBorderColor),
                  borderRadius: BorderRadius.circular(
                      borderRadius), // Set the border radius here
                ),

                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: borderColor ??
                          (Theme.of(context).scaffoldBackgroundColor ==
                                  Colors.white
                              ? MyColors.textFilledBorderColor
                              : Colors.white.withOpacity(0.6))),
                  borderRadius: BorderRadius.circular(
                      borderRadius), // Set the border radius here
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: borderColor ??
                          (Theme.of(context).scaffoldBackgroundColor ==
                                  Colors.white
                              ? MyColors.textFilledBorderColor
                              : Colors.white.withOpacity(0.6))),
                  borderRadius: BorderRadius.circular(
                      borderRadius), // Set the border radius here
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: focusedBorderColor ?? MyColors.primaryColor,
                      width: 2),
                  borderRadius: BorderRadius.circular(
                      borderRadius), // Set the border radius here
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: focusedBorderColor ?? Colors.blue),
                  borderRadius: BorderRadius.circular(
                      borderRadius), // Set the border radius here
                ),
                suffixIcon: suffix,

                contentPadding: EdgeInsets.symmetric(
                    vertical: contentPaddingVertical ?? 16,
                    horizontal: contentPaddinghorizonatly ?? 18),
                suffixStyle: const TextStyle(fontSize: 15, color: Colors.black),
                prefixIcon: preffix,
                hintText: hintText,
                suffixText: suffixText,
                prefixText: prefixText,
                prefixStyle: const TextStyle(fontSize: 16, color: Colors.black),
                hintStyle: TextStyle(
                  color: hintcolor ?? Theme.of(context).hintColor,
                  fontSize: hintTextFontsize ?? 13,
                  overflow: TextOverflow.ellipsis,
                ),
                labelStyle: TextStyle(
                  color: hintcolor ?? Theme.of(context).hintColor,
                  fontSize: hintTextFontsize ?? 13,
                ),
                // border: headingText != null ? null : InputBorder.none,
              ),
              obscuringCharacter: '*',
              onChanged: onChanged,
              onSaved: onSaved,
              onTap: onTap,
              validator: validator),
        ],
      ),
    );
  }
}
