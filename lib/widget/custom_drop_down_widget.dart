import 'package:flutter/material.dart';
import '../contants/my_colors.dart';
import '../contants/sized_box.dart';
import 'custom_text.dart';

class CustomDropDownField extends StatelessWidget {
  final List itemsList;
  final Color? hintColor;
  final Color? headingTextColor;
  final String hintText;
  final bool enableShadow;
  final bool isDense;
  final bool textFieldUnderline;
  final String? headingText;
  final Map<String, dynamic>? selectedValue;
  final double? headingFontSize;
  final double borderRadius;
  final double? boxHeight;
  final double? horizontalPadding;
  final double? verticalPadding;
  final double headingfontSize;
  final Icon? icons;
  final Widget? prefix;
  final String popUpTextKey;
  final String? Function(dynamic)? validator;
  final Function(dynamic)? onChanged;

  const CustomDropDownField({
    super.key,
    required this.itemsList,
    this.headingFontSize = 15,
    this.enableShadow = false,
    this.isDense = false,
    this.textFieldUnderline = false,
    this.borderRadius = 5,
    this.icons,
    this.boxHeight,
    this.verticalPadding,
    this.horizontalPadding,
    this.headingText,
    required this.popUpTextKey,
    this.hintColor,
    this.prefix,
    this.headingTextColor,
    this.headingfontSize = 14,
    this.selectedValue,
    this.onChanged,
    this.validator,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (headingText != null)
          SubHeadingText(
            headingText!,
            fontSize: headingFontSize,
            color: headingTextColor,
          ),
        if (headingText != null) vSizedBox05,
        Material(
          shadowColor:
              enableShadow ? Colors.grey.withOpacity(0.5) : Colors.transparent,
          elevation: enableShadow ? 3.0 : 0,
          borderRadius: BorderRadius.circular(borderRadius),
          child: DropdownButtonFormField(
            alignment: Alignment.bottomCenter,
            value: selectedValue,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            isDense: true,
            decoration: InputDecoration(
              prefixIcon: prefix,
              alignLabelWithHint: true,
              isDense: isDense,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding ?? 10, vertical: 0),
              hintText: hintText,
              hintStyle: TextStyle(
                color: hintColor ?? MyColors.textFeildFillColor,
                fontSize: 14,
              ),
              labelStyle: TextStyle(
                color: hintColor ?? MyColors.blackColor50,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderSide:
                    const BorderSide(color: MyColors.textFeildFillColor),
                borderRadius: BorderRadius.circular(
                    borderRadius), // Set the border radius here
              ),
              enabledBorder: OutlineInputBorder(
                borderSide:
                    const BorderSide(color: MyColors.textFilledBorderColor),
                borderRadius: BorderRadius.circular(
                    borderRadius), // Set the border radius here
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(
                    borderRadius), // Set the border radius here
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(
                    borderRadius), // Set the border radius here
              ),
              filled: true,
              fillColor: MyColors.whiteThemeColor(),
            ),
            isExpanded: true,
            dropdownColor: MyColors.whiteThemeColor(),
            onChanged: onChanged,
            validator: validator,
            icon: icons ??
                Icon(
                  Icons.arrow_drop_down,
                  color: MyColors.primaryColor.withOpacity(0.7),
                  size: 29,
                ),
            items: itemsList.map((value) {
              return DropdownMenuItem(
                value: value,
                child: Text(
                  value[popUpTextKey],
                  style: TextStyle(
                    color: MyColors.blackThemeColor(),
                    fontSize: 15,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
