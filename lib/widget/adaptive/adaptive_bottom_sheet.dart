import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'liquid_glass_container.dart';
import 'platform_utils.dart';

/// Bottom sheet adaptatif qui utilise :
/// - Liquid Glass sur iOS (style iOS 26)
/// - Material Design sur Android
///
/// Usage simple (contenu unique) :
/// ```dart
/// AdaptiveBottomSheet(
///   child: YourContent(),
/// )
/// ```
///
/// Usage avancé (3 états iOS) :
/// ```dart
/// AdaptiveBottomSheet(
///   // Contenu iOS par état
///   iosCollapsedBuilder: (ctx) => CollapsedView(),
///   iosIntermediateBuilder: (ctx) => IntermediateView(),
///   iosExpandedBuilder: (ctx) => ExpandedView(),
///   // Contenu Android (Material)
///   androidBuilder: (ctx) => AndroidContent(),
/// )
/// ```
class AdaptiveBottomSheet extends StatelessWidget {
  /// Contenu simple (utilisé sur Android et comme fallback iOS)
  final Widget? child;

  /// Builder iOS état collapsed (petite bulle)
  final WidgetBuilder? iosCollapsedBuilder;

  /// Builder iOS état intermediate (bulle moyenne)
  final WidgetBuilder? iosIntermediateBuilder;

  /// Builder iOS état expanded (plein écran)
  final WidgetBuilder? iosExpandedBuilder;

  /// Builder Android (Material)
  final WidgetBuilder? androidBuilder;

  /// État initial pour iOS
  final LiquidGlassState initialState;

  /// Callback quand l'état iOS change
  final ValueChanged<LiquidGlassState>? onStateChanged;

  /// Afficher le handle bar (iOS)
  final bool showHandleBar;

  /// Border radius pour Android
  final double androidBorderRadius;

  /// Padding pour le contenu Android
  final EdgeInsets androidPadding;

  const AdaptiveBottomSheet({
    super.key,
    this.child,
    this.iosCollapsedBuilder,
    this.iosIntermediateBuilder,
    this.iosExpandedBuilder,
    this.androidBuilder,
    this.initialState = LiquidGlassState.intermediate,
    this.onStateChanged,
    this.showHandleBar = true,
    this.androidBorderRadius = 20.0,
    this.androidPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.useLiquidGlass) {
      return _buildIOSSheet(context);
    } else {
      return _buildAndroidSheet(context);
    }
  }

  /// Construit la version iOS Liquid Glass
  Widget _buildIOSSheet(BuildContext context) {
    // Utiliser les builders spécifiques ou le child comme fallback
    final collapsedBuilder = iosCollapsedBuilder ??
        (child != null ? (_) => child! : (_) => const SizedBox());
    final intermediateBuilder = iosIntermediateBuilder ??
        (child != null ? (_) => child! : (_) => const SizedBox());
    final expandedBuilder = iosExpandedBuilder ??
        (child != null ? (_) => child! : (_) => const SizedBox());

    return LiquidGlassContainer(
      initialState: initialState,
      collapsedBuilder: collapsedBuilder,
      intermediateBuilder: intermediateBuilder,
      expandedBuilder: expandedBuilder,
      onStateChanged: onStateChanged,
      showHandleBar: showHandleBar,
    );
  }

  /// Construit la version Android Material
  Widget _buildAndroidSheet(BuildContext context) {
    final content = androidBuilder?.call(context) ?? child ?? const SizedBox();

    return Container(
      padding: androidPadding,
      decoration: BoxDecoration(
        color: MyColors.whiteThemeColor(),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(androidBorderRadius),
          topRight: Radius.circular(androidBorderRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandleBar) _buildAndroidHandleBar(),
          Flexible(child: content),
        ],
      ),
    );
  }

  Widget _buildAndroidHandleBar() {
    return Container(
      height: 5,
      width: 50,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: MyColors.colorD9D9D9Theme(),
      ),
    );
  }
}

/// Helper pour afficher une bottom sheet modale adaptative
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
}) {
  if (PlatformUtils.useLiquidGlass) {
    // Sur iOS, on utilise le showModalBottomSheet standard
    // car LiquidGlassContainer est conçu pour être intégré dans un écran
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F8FF),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        child: builder(context),
      ),
    );
  } else {
    // Android - Material style
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? MyColors.whiteThemeColor(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: builder,
    );
  }
}
