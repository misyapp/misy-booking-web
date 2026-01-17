import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:rider_ride_hailing_app/utils/platform.dart';

/// For web, we can't use FileImage, so return a transparent image
ImageProvider getFileImageProvider(File file) {
  // On web, File operations don't work properly, return a memory image with empty data
  return MemoryImage(Uint8List(0));
}
