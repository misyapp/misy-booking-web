import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/provider/internet_connectivity_provider.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

class CustomGestureDetector extends StatelessWidget {
  final Widget? child;
  // final BorderRadius? borderRadiusEdge;
  final Function(TapDownDetails)? onTapDown;
  final Function(TapUpDetails)? onTapUp;
  final Function()? onTap;
  final Function()? onTapCancel;
  final Function()? onSecondaryTap;
  final Function(TapDownDetails)? onSecondaryTapDown;
  final Function(TapUpDetails)? onSecondaryTapUp;
  final Function()? onSecondaryTapCancel;
  final Function(TapDownDetails)? onTertiaryTapDown;
  final Function(TapUpDetails)? onTertiaryTapUp;
  final Function()? onTertiaryTapCancel;
  final Function(TapDownDetails)? onDoubleTapDown;
  final Function()? onDoubleTap;
  final Function()? onDoubleTapCancel;
  // final Function(TapDownDetails)? onLongPressDown;
  // final Function()? onLongPressCancel;
  final Function()? onLongPress;
  // final Function()? onLongPressStart;
  // final Function()? onLongPressMoveUpdate;
  // final Function()? onLongPressUp;
  // final Function()? onLongPressEnd;
  // final Function()? onSecondaryLongPressDown;
  final Color? focusColor;
  final double? borderRadiusDouble;
  final BorderRadius? borderRadius;
  final Color? hoverColor;
  final MaterialStateProperty<Color>? overlayColor;
  final Color? splashColor;
  final bool ignoreInternetConnectivity;

  const CustomGestureDetector({
    super.key,
    this.child,
    this.onTapDown,
    this.onTapUp,
    this.ignoreInternetConnectivity = false,
    this.onTap,
    this.onTapCancel,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onSecondaryTapCancel,
    this.onTertiaryTapDown,
    this.borderRadius,
    this.onTertiaryTapUp,
    this.onTertiaryTapCancel,
    this.onDoubleTapDown,
    this.onDoubleTap,
    this.onDoubleTapCancel,
    // this.onLongPressDown,
    // this.onLongPressCancel,
    this.onLongPress,
    this.hoverColor,
    this.splashColor,
    this.overlayColor,
    this.focusColor,
    this.borderRadiusDouble,
    // this.borderRadiusEdge,
    // this.onLongPressStart,
    // this.onLongPressMoveUpdate,
    // this.onLongPressUp,
    // this.onLongPressEnd,
    // this.onSecondaryLongPressDown,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius:
          borderRadius ?? BorderRadius.circular(borderRadiusDouble ?? 0),
      child: child,
      onTap: () {
        // Toujours exécuter l'action - la vérification réseau cause des faux positifs
        onTap!();
      },
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onSecondaryTapCancel: onSecondaryTapCancel,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      focusColor: focusColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      overlayColor: overlayColor,
    );
  }
}
