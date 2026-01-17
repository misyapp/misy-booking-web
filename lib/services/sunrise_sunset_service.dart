import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

/// Service pour récupérer les heures de lever/coucher du soleil
/// Utilise l'API sunrise-sunset.org (gratuite, sans clé API)
class SunriseSunsetService {
  static const String _apiBaseUrl = 'https://api.sunrise-sunset.org/json';
  static const String _prefsSunrise = 'cached_sunrise_time';
  static const String _prefsSunset = 'cached_sunset_time';
  static const String _prefsCacheDate = 'cached_sun_times_date';
  static const String _prefsCacheLat = 'cached_sun_times_lat';
  static const String _prefsCacheLng = 'cached_sun_times_lng';

  /// Récupère les heures de lever/coucher du soleil pour une position donnée
  /// Retourne un Map avec 'sunrise' et 'sunset' en DateTime (heure locale)
  /// En cas d'erreur, retourne des valeurs par défaut (6h et 18h)
  static Future<Map<String, DateTime>> getSunTimes({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Vérifier le cache d'abord
      final cachedTimes = await _getCachedTimes(latitude, longitude);
      if (cachedTimes != null) {
        myCustomPrintStatement('☀️ Utilisation du cache sunrise/sunset');
        return cachedTimes;
      }

      // Appeler l'API
      final url = '$_apiBaseUrl?lat=$latitude&lng=$longitude&formatted=0';
      myCustomPrintStatement('☀️ Appel API sunrise-sunset: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'];

          // L'API retourne les heures en UTC ISO 8601
          final sunriseUtc = DateTime.parse(results['sunrise']);
          final sunsetUtc = DateTime.parse(results['sunset']);

          // Convertir en heure locale
          final sunrise = sunriseUtc.toLocal();
          final sunset = sunsetUtc.toLocal();

          myCustomPrintStatement(
              '☀️ Sunrise: ${sunrise.hour}:${sunrise.minute.toString().padLeft(2, '0')} | '
              'Sunset: ${sunset.hour}:${sunset.minute.toString().padLeft(2, '0')}');

          // Mettre en cache
          await _cacheTimes(sunrise, sunset, latitude, longitude);

          return {
            'sunrise': sunrise,
            'sunset': sunset,
          };
        }
      }

      myCustomPrintStatement('⚠️ API sunrise-sunset: réponse invalide, utilisation valeurs par défaut');
      return _getDefaultTimes();
    } catch (e) {
      myCustomPrintStatement('❌ Erreur API sunrise-sunset: $e - utilisation valeurs par défaut');
      return _getDefaultTimes();
    }
  }

  /// Vérifie si c'est actuellement la nuit basé sur les heures de lever/coucher
  static Future<bool> isNightTime({
    required double latitude,
    required double longitude,
  }) async {
    final sunTimes = await getSunTimes(latitude: latitude, longitude: longitude);
    final now = DateTime.now();

    final sunrise = sunTimes['sunrise']!;
    final sunset = sunTimes['sunset']!;

    // Créer des DateTime pour aujourd'hui avec les heures de lever/coucher
    final todaySunrise = DateTime(now.year, now.month, now.day, sunrise.hour, sunrise.minute);
    final todaySunset = DateTime(now.year, now.month, now.day, sunset.hour, sunset.minute);

    // C'est la nuit si on est avant le lever ou après le coucher
    final isNight = now.isBefore(todaySunrise) || now.isAfter(todaySunset);

    myCustomPrintStatement(
        '🌙 isNightTime: $isNight (now: ${now.hour}:${now.minute}, '
        'sunrise: ${sunrise.hour}:${sunrise.minute}, sunset: ${sunset.hour}:${sunset.minute})');

    return isNight;
  }

  /// Valeurs par défaut si l'API échoue (6h - 18h)
  static Map<String, DateTime> _getDefaultTimes() {
    final now = DateTime.now();
    return {
      'sunrise': DateTime(now.year, now.month, now.day, 6, 0),
      'sunset': DateTime(now.year, now.month, now.day, 18, 0),
    };
  }

  /// Récupère les heures depuis le cache si valides (même jour et même position ~10km)
  static Future<Map<String, DateTime>?> _getCachedTimes(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_prefsCacheDate);
      final cachedLat = prefs.getDouble(_prefsCacheLat);
      final cachedLng = prefs.getDouble(_prefsCacheLng);

      if (cachedDate == null || cachedLat == null || cachedLng == null) {
        return null;
      }

      // Vérifier si c'est le même jour
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';
      if (cachedDate != todayStr) {
        myCustomPrintStatement('☀️ Cache expiré (nouveau jour)');
        return null;
      }

      // Vérifier si la position est proche (~10km)
      final distance = _calculateDistance(lat, lng, cachedLat, cachedLng);
      if (distance > 10) {
        myCustomPrintStatement('☀️ Cache invalide (position trop éloignée: ${distance.toStringAsFixed(1)}km)');
        return null;
      }

      final sunriseMs = prefs.getInt(_prefsSunrise);
      final sunsetMs = prefs.getInt(_prefsSunset);

      if (sunriseMs == null || sunsetMs == null) {
        return null;
      }

      return {
        'sunrise': DateTime.fromMillisecondsSinceEpoch(sunriseMs),
        'sunset': DateTime.fromMillisecondsSinceEpoch(sunsetMs),
      };
    } catch (e) {
      return null;
    }
  }

  /// Met en cache les heures de lever/coucher
  static Future<void> _cacheTimes(
    DateTime sunrise,
    DateTime sunset,
    double lat,
    double lng,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';

      await prefs.setString(_prefsCacheDate, todayStr);
      await prefs.setDouble(_prefsCacheLat, lat);
      await prefs.setDouble(_prefsCacheLng, lng);
      await prefs.setInt(_prefsSunrise, sunrise.millisecondsSinceEpoch);
      await prefs.setInt(_prefsSunset, sunset.millisecondsSinceEpoch);

      myCustomPrintStatement('☀️ Heures sunrise/sunset mises en cache');
    } catch (e) {
      myCustomPrintStatement('⚠️ Erreur cache sunrise/sunset: $e');
    }
  }

  /// Calcule la distance approximative entre deux points en km (formule Haversine)
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLng / 2) * math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}
