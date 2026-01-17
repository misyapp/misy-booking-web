import 'package:flutter/material.dart';
import 'liquid_glass_colors.dart';

/// État du Liquid Glass Bottom Sheet
enum LiquidGlassState {
  collapsed, // État 0 - Petite bulle (80px)
  intermediate, // État 1 - Bulle moyenne (~38% écran)
  expanded, // État 2 - Plein écran (90%)
}

/// Container Liquid Glass style iOS avec 3 états et animation fluide
///
/// Utilisation :
/// ```dart
/// LiquidGlassContainer(
///   initialState: LiquidGlassState.intermediate,
///   collapsedBuilder: (context) => CollapsedContent(),
///   intermediateBuilder: (context) => IntermediateContent(),
///   expandedBuilder: (context) => ExpandedContent(),
///   onStateChanged: (state) => print('State: $state'),
/// )
/// ```
class LiquidGlassContainer extends StatefulWidget {
  /// État initial de la sheet
  final LiquidGlassState initialState;

  /// Builder pour le contenu en état collapsed
  final WidgetBuilder collapsedBuilder;

  /// Builder pour le contenu en état intermediate
  final WidgetBuilder intermediateBuilder;

  /// Builder pour le contenu en état expanded
  final WidgetBuilder expandedBuilder;

  /// Callback quand l'état change
  final ValueChanged<LiquidGlassState>? onStateChanged;

  /// Callback avec l'extent actuel (0.0 à 1.0) pendant le drag
  final ValueChanged<double>? onExtentChanged;

  /// Si true, affiche le handle bar en haut
  final bool showHandleBar;

  /// Couleur de fond custom (optionnel)
  final Color? backgroundColor;

  /// Durée de l'animation de snap
  final Duration animationDuration;

  /// Courbe de l'animation
  final Curve animationCurve;

  const LiquidGlassContainer({
    super.key,
    this.initialState = LiquidGlassState.intermediate,
    required this.collapsedBuilder,
    required this.intermediateBuilder,
    required this.expandedBuilder,
    this.onStateChanged,
    this.onExtentChanged,
    this.showHandleBar = true,
    this.backgroundColor,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeOutCubic,
  });

  @override
  State<LiquidGlassContainer> createState() => LiquidGlassContainerState();
}

class LiquidGlassContainerState extends State<LiquidGlassContainer> {
  late LiquidGlassState _state;
  late double _extent;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _extent = _stateToExtent(widget.initialState);
  }

  /// Convertit un état en extent
  double _stateToExtent(LiquidGlassState state) {
    switch (state) {
      case LiquidGlassState.collapsed:
        return 0.0;
      case LiquidGlassState.intermediate:
        return 0.5;
      case LiquidGlassState.expanded:
        return 1.0;
    }
  }

  /// Convertit un extent en état
  LiquidGlassState _extentToState(double extent) {
    final stateIndex = LiquidGlassColors.getState(extent);
    switch (stateIndex) {
      case 0:
        return LiquidGlassState.collapsed;
      case 2:
        return LiquidGlassState.expanded;
      default:
        return LiquidGlassState.intermediate;
    }
  }

  /// Expose l'état actuel
  LiquidGlassState get currentState => _state;

  /// Expose l'extent actuel
  double get currentExtent => _extent;

  /// Change l'état programmatiquement
  void setState2(LiquidGlassState newState) {
    setState(() {
      _state = newState;
      _extent = _stateToExtent(newState);
    });
    widget.onStateChanged?.call(newState);
  }

  /// Expand la sheet à l'état suivant
  void expand() {
    if (_state == LiquidGlassState.collapsed) {
      setState2(LiquidGlassState.intermediate);
    } else if (_state == LiquidGlassState.intermediate) {
      setState2(LiquidGlassState.expanded);
    }
  }

  /// Collapse la sheet à l'état précédent
  void collapse() {
    if (_state == LiquidGlassState.expanded) {
      setState2(LiquidGlassState.intermediate);
    } else if (_state == LiquidGlassState.intermediate) {
      setState2(LiquidGlassState.collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculer les propriétés basées sur l'extent
    final currentHeight = LiquidGlassColors.getSheetHeight(_extent, screenHeight);
    final currentMargin = LiquidGlassColors.getHorizontalMargin(_extent);
    final currentBottomMargin = LiquidGlassColors.getBottomMargin(_extent);
    final currentOpacity = LiquidGlassColors.getOpacity(_extent);
    final borderRadius = LiquidGlassColors.getBorderRadius(_extent);

    final backgroundColor = widget.backgroundColor ??
        LiquidGlassColors.getBackgroundColor(isDarkMode);

    return Positioned(
      left: currentMargin,
      right: currentMargin,
      bottom: currentBottomMargin,
      height: currentHeight,
      child: GestureDetector(
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        onTap: _onTap,
        child: AnimatedContainer(
          duration: widget.animationDuration,
          curve: widget.animationCurve,
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: currentOpacity),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: LiquidGlassColors.shadowColor,
                blurRadius: LiquidGlassColors.shadowBlurRadius,
                spreadRadius: 0,
                offset: LiquidGlassColors.shadowOffset,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Column(
              children: [
                if (widget.showHandleBar) _buildHandleBar(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandleBar() {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: LiquidGlassColors.handleBarWidth,
          height: LiquidGlassColors.handleBarHeight,
          decoration: BoxDecoration(
            color: LiquidGlassColors.handleBarColor,
            borderRadius: BorderRadius.circular(
              LiquidGlassColors.handleBarHeight / 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case LiquidGlassState.collapsed:
        return widget.collapsedBuilder(context);
      case LiquidGlassState.intermediate:
        return widget.intermediateBuilder(context);
      case LiquidGlassState.expanded:
        return widget.expandedBuilder(context);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;

    setState(() {
      // Le sheet suit le doigt
      _extent -= details.primaryDelta! / (screenHeight * 0.5);
      _extent = _extent.clamp(0.0, 1.0);

      // Mettre à jour l'état pour le contenu
      _state = _extentToState(_extent);
    });

    widget.onExtentChanged?.call(_extent);
  }

  void _onDragEnd(DragEndDetails details) {
    // Snap vers l'état le plus proche
    final snapExtent = LiquidGlassColors.getSnapExtent(_extent);
    final newState = _extentToState(snapExtent);

    setState(() {
      _extent = snapExtent;
      _state = newState;
    });

    widget.onStateChanged?.call(newState);
  }

  void _onTap() {
    // Cycle vers l'état suivant au tap (sauf si déjà expanded)
    if (_state != LiquidGlassState.expanded) {
      expand();
    }
  }
}
