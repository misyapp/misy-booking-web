// Widgets adaptatifs iOS/Android
//
// Utilise automatiquement :
// - Liquid Glass sur iOS (style iOS 26)
// - Material Design sur Android
//
// Usage :
// ```dart
// import 'package:rider_ride_hailing_app/widget/adaptive/adaptive.dart';
//
// // Widget adaptatif
// AdaptiveBottomSheet(
//   child: YourContent(),
// )
//
// // Ou avec 3 etats pour iOS
// AdaptiveBottomSheet(
//   iosCollapsedBuilder: (ctx) => SmallView(),
//   iosIntermediateBuilder: (ctx) => MediumView(),
//   iosExpandedBuilder: (ctx) => FullView(),
//   androidBuilder: (ctx) => AndroidView(),
// )
// ```

export 'platform_utils.dart';
export 'liquid_glass_colors.dart';
export 'liquid_glass_container.dart';
export 'adaptive_bottom_sheet.dart';
export 'adaptive_home_bottom_sheet.dart';
