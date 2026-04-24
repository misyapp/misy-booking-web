import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Client HTTP pour les 5 Cloud Functions callable v2 IAM transport.
///
/// Les callable v2 exposent un endpoint HTTPS qui accepte :
///   POST  body : {"data": {...}}
///         headers : Authorization: Bearer <ID_TOKEN>, Content-Type: application/json
///   Response : {"result": {...}} ou {"error": {...}}
class TransportIamService {
  TransportIamService._();
  static final TransportIamService instance = TransportIamService._();

  static const String _baseUrl =
      'https://us-central1-misy-95336.cloudfunctions.net';

  Future<Map<String, dynamic>> _call(
      String functionName, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw IamException('Non authentifié.');
    }
    final token = await user.getIdToken();

    final uri = Uri.parse('$_baseUrl/$functionName');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'data': data}),
    );

    final Map<String, dynamic> body = resp.body.isNotEmpty
        ? (jsonDecode(resp.body) as Map<String, dynamic>)
        : <String, dynamic>{};

    if (resp.statusCode >= 400) {
      final err = body['error'];
      String message = 'Erreur serveur (${resp.statusCode}).';
      if (err is Map && err['message'] is String) {
        message = err['message'] as String;
      }
      throw IamException(message);
    }

    final result = body['result'];
    if (result is Map<String, dynamic>) return result;
    return <String, dynamic>{};
  }

  Future<List<TransportIamUser>> listUsers() async {
    final result = await _call('iamListTransportUsers', {});
    final list = (result['users'] as List<dynamic>? ?? []);
    return list
        .map((e) => TransportIamUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CreatedUser> createUser({
    required String email,
    required bool transportEditor,
    required bool transportAdmin,
    String? password,
  }) async {
    final result = await _call('iamCreateTransportUser', {
      'email': email,
      'transport_editor': transportEditor,
      'transport_admin': transportAdmin,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return CreatedUser.fromJson(result);
  }

  Future<void> setClaims({
    required String uid,
    required bool transportEditor,
    required bool transportAdmin,
  }) async {
    await _call('iamSetTransportClaims', {
      'uid': uid,
      'transport_editor': transportEditor,
      'transport_admin': transportAdmin,
    });
  }

  Future<String> resetPassword({required String uid}) async {
    final result = await _call('iamResetTransportPassword', {'uid': uid});
    return result['password'] as String;
  }

  Future<void> deleteUser({required String uid}) async {
    await _call('iamDeleteTransportUser', {'uid': uid});
  }
}

class IamException implements Exception {
  IamException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TransportIamUser {
  TransportIamUser({
    required this.uid,
    required this.email,
    required this.transportEditor,
    required this.transportAdmin,
    required this.disabled,
    this.createdAt,
    this.lastSignInAt,
  });

  final String uid;
  final String? email;
  final bool transportEditor;
  final bool transportAdmin;
  final bool disabled;
  final String? createdAt;
  final String? lastSignInAt;

  factory TransportIamUser.fromJson(Map<String, dynamic> json) {
    return TransportIamUser(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      transportEditor: json['transport_editor'] == true,
      transportAdmin: json['transport_admin'] == true,
      disabled: json['disabled'] == true,
      createdAt: json['created_at'] as String?,
      lastSignInAt: json['last_sign_in_at'] as String?,
    );
  }
}

class CreatedUser {
  CreatedUser({
    required this.uid,
    required this.email,
    required this.password,
    required this.transportEditor,
    required this.transportAdmin,
  });

  final String uid;
  final String email;
  final String password;
  final bool transportEditor;
  final bool transportAdmin;

  factory CreatedUser.fromJson(Map<String, dynamic> json) {
    return CreatedUser(
      uid: json['uid'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      transportEditor: json['transport_editor'] == true,
      transportAdmin: json['transport_admin'] == true,
    );
  }
}
