import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' show File;

/// Upload file for mobile/desktop (uses putFile with dart:io File)
Future<TaskSnapshot> uploadFileToFirebase(File file, Reference ref) async {
  return await ref.putFile(file);
}
