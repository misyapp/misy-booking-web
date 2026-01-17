import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../contants/my_colors.dart';

// 🔒 Système simplifié de gestion du loader
// Le compteur était source de bugs - on utilise maintenant un système plus simple
bool _isLoadingVisible = false;
DateTime? _lastShowTime;

Future showLoading() async {
  debugPrint('🔄 showLoading() appelé');

  // Protection contre les appels trop rapprochés (debounce 100ms)
  final now = DateTime.now();
  if (_lastShowTime != null && now.difference(_lastShowTime!).inMilliseconds < 100) {
    debugPrint('⚠️ showLoading() ignoré - appel trop rapproché');
    return;
  }
  _lastShowTime = now;

  if (!EasyLoading.isShow) {
    _isLoadingVisible = true;
    try {
      await EasyLoading.show(
        status: null,
        maskType: EasyLoadingMaskType.none,
        indicator: LoadingAnimationWidget.twistingDots(
          leftDotColor: MyColors.coralPink,
          rightDotColor: MyColors.horizonBlue,
          size: 45.0,
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur showLoading: $e');
      _isLoadingVisible = false;
    }
  } else {
    debugPrint('⚠️ EasyLoading déjà affiché');
  }
}

Future hideLoading() async {
  debugPrint('🔄 hideLoading() appelé');

  if (EasyLoading.isShow) {
    try {
      await EasyLoading.dismiss();
      _isLoadingVisible = false;
    } catch (e) {
      debugPrint('❌ Erreur hideLoading: $e');
    }
  } else {
    _isLoadingVisible = false;
  }
}

/// Force le masquage du loader
Future forceHideLoading() async {
  debugPrint('🔒 forceHideLoading() appelé');
  _isLoadingVisible = false;
  _lastShowTime = null;
  if (EasyLoading.isShow) {
    try {
      await EasyLoading.dismiss();
    } catch (e) {
      debugPrint('❌ Erreur forceHideLoading: $e');
    }
  }
}
