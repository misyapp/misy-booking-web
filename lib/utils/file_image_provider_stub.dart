import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:rider_ride_hailing_app/utils/platform.dart';

/// Sur web, pas de FileImage : on lit les bytes portés par le stub File
/// (alimentés par le picker web).
ImageProvider getFileImageProvider(File file) {
  return MemoryImage(file.bytes ?? Uint8List(0));
}
