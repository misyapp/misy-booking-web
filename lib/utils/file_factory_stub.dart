import 'dart:typed_data';
import 'package:rider_ride_hailing_app/utils/platform.dart';

/// Wrap raw bytes in the stub File so the upload + preview pipelines work on web.
File createFileFromBytes(String name, Uint8List bytes) {
  return File(name, bytes: bytes);
}
