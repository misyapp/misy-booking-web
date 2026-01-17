// lib/firebase_stub.dart

// This is a stub implementation for Firebase Firestore used for conditional imports
// when the target platform does not support the full Firebase SDK (e.g., web without dart:html).

class FirebaseFirestore {
  static FirebaseFirestore get instance => FirebaseFirestore();

  CollectionReference collection(String path) {
    return CollectionReference();
  }
}

class CollectionReference {
  DocumentReference doc(String? path) {
    return DocumentReference();
  }
}

class DocumentReference {
  Future<DocumentSnapshot> get() async {
    return DocumentSnapshot();
  }

  Future<void> set(Map<String, dynamic> data) async {
    // No-op
  }

  Future<void> update(Map<String, dynamic> data) async {
    // No-op
  }
}

class DocumentSnapshot {
  bool get exists => false;
  Map<String, dynamic>? data() => null;
}

class Timestamp {
  final int seconds;
  final int nanoseconds;

  Timestamp({required this.seconds, required this.nanoseconds});

  static Timestamp now() {
    final now = DateTime.now();
    return Timestamp(
      seconds: now.millisecondsSinceEpoch ~/ 1000,
      nanoseconds: (now.millisecondsSinceEpoch % 1000) * 1000000,
    );
  }

  DateTime toDate() {
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000 + nanoseconds ~/ 1000000,
    );
  }

  static Timestamp fromDate(DateTime date) {
    return Timestamp(
      seconds: date.millisecondsSinceEpoch ~/ 1000,
      nanoseconds: (date.millisecondsSinceEpoch % 1000) * 1000000,
    );
  }
}
