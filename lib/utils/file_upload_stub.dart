import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rider_ride_hailing_app/utils/platform.dart';

/// Upload file for web (uses putData with bytes)
Future<TaskSnapshot> uploadFileToFirebase(File file, Reference ref) async {
  final bytes = await file.readAsBytes();
  return await ref.putData(bytes);
}
