import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';

class CircularBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  
  const CircularBackButton({
    Key? key,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.size = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).pop(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back,
          color: iconColor ?? Colors.black,
          size: size * 0.6,
        ),
      ),
    );
  }
}