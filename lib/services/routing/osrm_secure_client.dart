import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../functions/print_function.dart';

/// Service sécurisé pour les appels OSRM2 avec authentification HMAC
///
/// Architecture:
/// - OSRM2 (osrm2.misy.app) avec HMAC en priorité
/// - Fallback OSRM1 (osrm1.misy-app.com) sans HMAC
/// - Logs uniquement en mode debug
class OsrmSecureClient {
  // URLs
  static const String _osrm2BaseUrl = 'https://osrm2.misy.app';
  static const String _osrm1BaseUrl = 'https://osrm1.misy-app.com';

  // Secret HMAC encodé en base64 pour ne pas l'exposer en clair dans le code
  // Secret original (hex): b4f3cbd812e3a12a63dbf21d1a8e7a9d3c5aab74f6e941b3e93e76d5a71f8ad1
  static const String _secretBase64 = 'tPPL2BLjoSpj2/IdGo56nTxaq3T26UGz6T521acfitE=';

  /// Génère la signature HMAC SHA256 pour une requête OSRM
  ///
  /// Message signé : timestamp + "\n" + path
  /// Retourne la signature en hex lowercase
  static String _generateHmacSignature(String path, int timestamp) {
    try {
      // Décoder le secret base64 vers bytes
      final secretBytes = base64.decode(_secretBase64);

      // Construire le message à signer: timestamp + "\n" + path
      final message = '$timestamp\n$path';
      final messageBytes = utf8.encode(message);

      // Générer HMAC SHA256
      final hmac = Hmac(sha256, secretBytes);
      final digest = hmac.convert(messageBytes);

      // Retourner en hex lowercase
      final signature = digest.toString();

      if (kDebugMode) {
        myCustomPrintStatement('🔐 HMAC signature generated for path: $path');
        myCustomPrintStatement('   Timestamp: $timestamp');
        myCustomPrintStatement('   Signature: ${signature.substring(0, 16)}...');
      }

      return signature;
    } catch (e) {
      if (kDebugMode) {
        myCustomPrintStatement('❌ Error generating HMAC signature: $e');
      }
      rethrow;
    }
  }

  /// Effectue une requête GET sécurisée vers OSRM2 avec fallback OSRM1
  ///
  /// [path] : Le chemin de l'API OSRM (ex: /route/v1/driving/48.1,-3.9;48.2,-4.0)
  /// [queryParams] : Les paramètres de requête (ex: overview=full&geometries=polyline)
  /// [timeout] : Timeout en secondes (défaut: 3s)
  ///
  /// Retourne la réponse HTTP ou throw une exception si les deux serveurs échouent
  static Future<http.Response> secureGet({
    required String path,
    String? queryParams,
    int timeoutSeconds = 3,
  }) async {
    // Construire l'URL complète pour OSRM2
    final osrm2Url = queryParams != null && queryParams.isNotEmpty
        ? '$_osrm2BaseUrl$path?$queryParams'
        : '$_osrm2BaseUrl$path';

    // Construire l'URL de fallback OSRM1
    final osrm1Url = queryParams != null && queryParams.isNotEmpty
        ? '$_osrm1BaseUrl$path?$queryParams'
        : '$_osrm1BaseUrl$path';

    if (kDebugMode) {
      myCustomPrintStatement('🌐 OSRM Secure Request:');
      myCustomPrintStatement('   Primary: $osrm2Url');
      myCustomPrintStatement('   Fallback: $osrm1Url');
    }

    // Tentative 1: OSRM2 avec HMAC
    try {
      // Générer timestamp UTC (epoch seconds)
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      // Générer signature HMAC
      final signature = _generateHmacSignature(path, timestamp);

      // Construire headers HMAC
      final headers = {
        'X-OSRM-Timestamp': timestamp.toString(),
        'X-OSRM-Signature': signature,
        'User-Agent': 'MisyApp/secure-osrm',
      };

      if (kDebugMode) {
        myCustomPrintStatement('📤 Sending OSRM2 request with HMAC headers');
      }

      // Effectuer la requête vers OSRM2
      final response = await http
          .get(
            Uri.parse(osrm2Url),
            headers: headers,
          )
          .timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        if (kDebugMode) {
          myCustomPrintStatement('✅ OSRM2 SUCCESS (${response.statusCode})');
        }
        return response;
      } else {
        if (kDebugMode) {
          myCustomPrintStatement('⚠️ OSRM2 returned status ${response.statusCode}');
        }
        throw Exception('OSRM2 returned status ${response.statusCode}');
      }
    } catch (osrm2Error) {
      if (kDebugMode) {
        myCustomPrintStatement('❌ OSRM2 failed: $osrm2Error');
        myCustomPrintStatement('🔄 Attempting fallback to OSRM1...');
      }

      // Tentative 2: Fallback OSRM1 (sans HMAC)
      try {
        final responseBackup = await http
            .get(Uri.parse(osrm1Url))
            .timeout(Duration(seconds: timeoutSeconds));

        if (responseBackup.statusCode == 200) {
          if (kDebugMode) {
            myCustomPrintStatement('✅ OSRM1 FALLBACK SUCCESS (${responseBackup.statusCode})');
          }
          return responseBackup;
        } else {
          if (kDebugMode) {
            myCustomPrintStatement('⚠️ OSRM1 returned status ${responseBackup.statusCode}');
          }
          throw Exception('OSRM1 returned status ${responseBackup.statusCode}');
        }
      } catch (osrm1Error) {
        if (kDebugMode) {
          myCustomPrintStatement('❌ OSRM1 fallback also failed: $osrm1Error');
          myCustomPrintStatement('💥 Both OSRM2 and OSRM1 failed');
        }

        // Les deux serveurs ont échoué
        throw Exception(
          'Both OSRM servers failed.\n'
          'OSRM2 error: $osrm2Error\n'
          'OSRM1 error: $osrm1Error'
        );
      }
    }
  }

  /// Teste la connectivité OSRM avec un trajet simple
  /// Utile pour debug et vérification
  static Future<bool> testConnection() async {
    try {
      // Test avec un trajet simple Antananarivo
      const testPath = '/route/v1/driving/47.5079,-18.8792;47.5208,-18.9094';
      const testParams = 'overview=full&geometries=polyline';

      if (kDebugMode) {
        myCustomPrintStatement('🧪 Testing OSRM connection...');
      }

      final response = await secureGet(
        path: testPath,
        queryParams: testParams,
        timeoutSeconds: 5,
      );

      if (kDebugMode) {
        myCustomPrintStatement('✅ OSRM connection test successful');
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        myCustomPrintStatement('❌ OSRM connection test failed: $e');
      }
      return false;
    }
  }
}
