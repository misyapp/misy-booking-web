import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  bool _isNavigationBarVisible = true;

  bool get isNavigationBarVisible => _isNavigationBarVisible;

  void setNavigationBarVisibility(bool isVisible) {
    if (_isNavigationBarVisible != isVisible) {
      _isNavigationBarVisible = isVisible;
      notifyListeners();
    }
  }
}
