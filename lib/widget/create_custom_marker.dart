import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<Uint8List> createMarkerImageFromText(String text) async {
  final PictureRecorder pictureRecorder = PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);

  final Paint paint = Paint()..color = Colors.red;
  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontSize: 40, color: Colors.white),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  const double radius = 50;
  canvas.drawCircle(const Offset(radius, radius), radius, paint);
  textPainter.paint(canvas,
      Offset(radius - textPainter.width / 2, radius - textPainter.height / 2));

  final img = await pictureRecorder.endRecording().toImage(100, 100);
  final data = await img.toByteData(format: ImageByteFormat.png);

  return data!.buffer.asUint8List();
}

Future<BitmapDescriptor> bitmapDescriptorFromImageWithText(
    String imagePath, String text) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  const Size imageSize = Size(60, 120); // Adjust as needed

  // Load marker icon image
  final ByteData markerImageData = await rootBundle.load(imagePath);
  final Codec codec =
      await ui.instantiateImageCodec(markerImageData.buffer.asUint8List());
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final Paint paint = Paint()..color = Colors.red; // Marker icon color

  // Draw marker icon
  canvas.drawImageRect(
    frameInfo.image,
    Rect.fromLTRB(0, 0, frameInfo.image.width.toDouble(),
        frameInfo.image.height.toDouble()),
    Rect.fromLTRB(0, 0, imageSize.width, imageSize.height),
    paint,
  );

  // Draw text below the marker icon
  final TextPainter textPainter2 = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold), // Adjust font size and color
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter2.layout(maxWidth: imageSize.width);

  // Calculate text position dynamically
  final double textX2 = (imageSize.width - textPainter2.width) / 2;
  final double textY2 = (imageSize.height - textPainter2.height) / 7;

  // Paint text on canvas
  textPainter2.paint(canvas, Offset(textX2, textY2));
  // Draw text below the marker icon
  final TextPainter textPainter = TextPainter(
    text: const TextSpan(
      text: "Min",
      style: TextStyle(
          color: Colors.white, fontSize: 16), // Adjust font size and color
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout(maxWidth: imageSize.width);

  // Calculate text position dynamically
  final double textX = (imageSize.width - textPainter.width) / 2;
  final double textY = (imageSize.height - textPainter.height) / 3;

  // Paint text on canvas
  textPainter.paint(canvas, Offset(textX, textY));

  // Convert canvas to image
  final ui.Image markerImage = await pictureRecorder
      .endRecording()
      .toImage(imageSize.width.toInt(), imageSize.height.toInt());
  final ByteData? byteData =
      await markerImage.toByteData(format: ui.ImageByteFormat.png);

  // Return BitmapDescriptor from image data
  return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
}
// Future<BitmapDescriptor> bitmapDescriptorFromImageWithText(
//     String imagePath, String text) async {
//   final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
//   final Canvas canvas = Canvas(pictureRecorder);
//   final Size imageSize = Size(110, 249); // Adjust as needed

//   // Load marker icon image
//   final ByteData markerImageData = await rootBundle.load(imagePath);
//   final Codec codec =
//       await ui.instantiateImageCodec(markerImageData.buffer.asUint8List());
//   final ui.FrameInfo frameInfo = await codec.getNextFrame();
//   final Paint paint = Paint()..color = Colors.red; // Marker icon color

//   // Draw marker icon
//   canvas.drawImageRect(
//     frameInfo.image,
//     Rect.fromLTRB(0, 0, frameInfo.image.width.toDouble(),
//         frameInfo.image.height.toDouble()),
//     Rect.fromLTRB(0, 0, imageSize.width, imageSize.height),
//     paint,
//   );

//   // Draw text below the marker icon
//   final TextPainter textPainter = TextPainter(
//     text: TextSpan(
//       text: text,
//       style: TextStyle(
//           color: MyColors.whiteThemeColor(), fontSize: 30), // Adjust font size
//     ),
//     textDirection: TextDirection.ltr,
//   );
//   textPainter.layout(maxWidth: imageSize.width);
//   final double textX = (imageSize.width - textPainter.width) / 2;
//   final double textY =
//       imageSize.height - textPainter.height; // Center vertically
//   textPainter.paint(canvas, Offset(35, 15));
//   textPainter.textAlign = TextAlign.center;

//   // Convert canvas to image
//   final ui.Image markerImage = await pictureRecorder
//       .endRecording()
//       .toImage(imageSize.width.toInt(), imageSize.height.toInt());
//   final ByteData? byteData =
//       await markerImage.toByteData(format: ui.ImageByteFormat.png);

//   // Return BitmapDescriptor from image data
//   return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
// }
