import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de traduction utilisant LibreTranslate
///
/// LibreTranslate est un moteur de traduction open-source gratuit.
/// Hébergé sur : osrm2.misy.app:5000
///
/// Pour changer l'URL, modifiez [_baseUrl]
class TranslationService {
  static TranslationService? _instance;
  static TranslationService get instance => _instance ??= TranslationService._();

  TranslationService._();

  /// URL de l'API LibreTranslate
  /// Votre serveur auto-hébergé sur OVH (port 5050 car 5000 est utilisé par OSRM)
  static const String _baseUrl = 'http://osrm2.misy.app:5050';

  /// Cache local pour éviter les requêtes répétées
  final Map<String, String> _translationCache = {};
  static const int _maxCacheSize = 500;

  /// Codes de langue supportés
  static const Map<String, String> _appToLibreTranslateCode = {
    'en': 'en',  // English
    'fr': 'fr',  // French
    'mg': 'mg',  // Malagasy (fallback vers anglais si non supporté)
    'it': 'it',  // Italian
    'pl': 'pl',  // Polish
  };

  /// Traduit un texte d'une langue source vers une langue cible
  ///
  /// [text] : Texte à traduire
  /// [sourceLanguage] : Code langue source (ex: 'fr', 'en')
  /// [targetLanguage] : Code langue cible (ex: 'it', 'pl')
  ///
  /// Retourne le texte traduit ou le texte original en cas d'erreur
  Future<String> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // Si même langue, pas de traduction
    if (sourceLanguage == targetLanguage) {
      return text;
    }

    // Si texte vide ou trop court
    if (text.trim().isEmpty || text.trim().length < 2) {
      return text;
    }

    // Vérifier le cache
    final cacheKey = '${sourceLanguage}_${targetLanguage}_$text';
    if (_translationCache.containsKey(cacheKey)) {
      myCustomPrintStatement('📦 Translation from cache');
      return _translationCache[cacheKey]!;
    }

    try {
      final sourceLang = _appToLibreTranslateCode[sourceLanguage] ?? 'auto';
      final targetLang = _appToLibreTranslateCode[targetLanguage] ?? 'en';

      final response = await http.post(
        Uri.parse('$_baseUrl/translate'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'q': text,
          'source': sourceLang,
          'target': targetLang,
          'format': 'text',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['translatedText'] as String? ?? text;

        // Mettre en cache
        _addToCache(cacheKey, translatedText);

        myCustomPrintStatement('✅ Translated: "$text" -> "$translatedText"');
        return translatedText;
      } else {
        myCustomPrintStatement('❌ Translation error: ${response.statusCode}');
        return text;
      }
    } catch (e) {
      myCustomPrintStatement('❌ Translation exception: $e');
      return text;
    }
  }

  /// Traduit un texte vers la langue de l'utilisateur actuel
  Future<String> translateToUserLanguage(String text, String sourceLanguage) async {
    final userLanguage = selectedLanguageNotifier.value['key'] as String? ?? 'en';
    return translateText(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: userLanguage,
    );
  }

  /// Détecte automatiquement la langue d'un texte
  Future<String?> detectLanguage(String text) async {
    if (text.trim().isEmpty) {
      myCustomPrintStatement('🔍 detectLanguage: texte vide');
      return null;
    }

    try {
      myCustomPrintStatement('🔍 detectLanguage: Envoi requête pour "$text"');
      final response = await http.post(
        Uri.parse('$_baseUrl/detect'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'q': text,
        }),
      ).timeout(const Duration(seconds: 5));

      myCustomPrintStatement('🔍 detectLanguage: Response status=${response.statusCode}');
      myCustomPrintStatement('🔍 detectLanguage: Response body=${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final detectedLang = data[0]['language'] as String?;
          final confidence = data[0]['confidence'] as num?;
          myCustomPrintStatement('🔍 detectLanguage: Langue détectée=$detectedLang (confidence: $confidence)');
          return detectedLang;
        }
      }
    } catch (e) {
      myCustomPrintStatement('❌ Language detection error: $e');
    }
    myCustomPrintStatement('🔍 detectLanguage: Aucune langue détectée, retourne null');
    return null;
  }

  /// Vérifie si LibreTranslate est disponible
  Future<bool> isServiceAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/languages'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _addToCache(String key, String value) {
    if (_translationCache.length >= _maxCacheSize) {
      final keysToRemove = _translationCache.keys.take(100).toList();
      for (var k in keysToRemove) {
        _translationCache.remove(k);
      }
    }
    _translationCache[key] = value;
  }

  /// Vide le cache de traduction
  void clearCache() {
    _translationCache.clear();
  }

  /// Sauvegarde la préférence de traduction automatique
  Future<void> setAutoTranslateEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_translate_chat', enabled);
  }

  /// Récupère la préférence de traduction automatique
  Future<bool> isAutoTranslateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_translate_chat') ?? true; // Activé par défaut
  }
}
