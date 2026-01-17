import 'package:flutter/material.dart';
import 'dart:io' show File;

/// For mobile/desktop, use the real FileImage
ImageProvider getFileImageProvider(File file) {
  return FileImage(file);
}
