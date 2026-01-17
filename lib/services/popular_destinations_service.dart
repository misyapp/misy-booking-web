import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/popular_destination.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PopularDestinationsService {
  static const String _cacheKey = 'POPULAR_DESTINATIONS_CACHE';
  static const String _lastUpdateKey = 'POPULAR_DESTINATIONS_LAST_UPDATE';
  static const String _cacheVersionKey = 'POPULAR_DESTINATIONS_CACHE_VERSION';
  static const int _cacheValidityHours = 24;
  static const int _currentCacheVersion = 2; // Incrémenté pour forcer le refresh et supprimer Tana Waterfront

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'popular_destinations';

  /// Récupère les destinations depuis Firestore avec cache local
  /// Filtre optionnellement par distance si position utilisateur fournie
  static Future<List<PopularDestination>> getDestinations({
    double? userLatitude,
    double? userLongitude,
  }) async {
    try {
      // Vérifier le cache local d'abord
      final cachedDestinations = await _getCachedDestinations();
      if (cachedDestinations.isNotEmpty && await _isCacheValid()) {
        myCustomPrintStatement("Destinations chargées depuis le cache");
        // Filtrer par distance si position utilisateur fournie
        if (userLatitude != null && userLongitude != null) {
          final filteredDestinations = await _filterDestinationsByDistance(
            cachedDestinations, 
            userLatitude, 
            userLongitude,
          );
          myCustomPrintStatement("${filteredDestinations.length} destinations après filtrage du cache par distance");
          return filteredDestinations;
        }
        return cachedDestinations;
      }

      // Récupérer depuis Firestore
      myCustomPrintStatement("Récupération des destinations depuis Firestore");
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .limit(20)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      final destinations = querySnapshot.docs
          .map((doc) => PopularDestination.fromFirestore(doc.data(), doc.id))
          .toList();

      // Mettre en cache
      await _cacheDestinations(destinations);
      
      myCustomPrintStatement("${destinations.length} destinations récupérées depuis Firestore");
      
      // Filtrer par distance si position utilisateur fournie
      if (userLatitude != null && userLongitude != null) {
        final filteredDestinations = await _filterDestinationsByDistance(
          destinations, 
          userLatitude, 
          userLongitude,
        );
        myCustomPrintStatement("${filteredDestinations.length} destinations après filtrage par distance");
        return filteredDestinations;
      }
      
      return destinations;
      
    } catch (e) {
      myCustomPrintStatement("Erreur lors de la récupération des destinations: $e");
      
      // Fallback sur le cache même expiré
      final cachedDestinations = await _getCachedDestinations();
      if (cachedDestinations.isNotEmpty) {
        myCustomPrintStatement("Utilisation du cache expiré comme fallback");
        // Filtrer par distance si position utilisateur fournie
        if (userLatitude != null && userLongitude != null) {
          final filteredDestinations = await _filterDestinationsByDistance(
            cachedDestinations, 
            userLatitude, 
            userLongitude,
          );
          return filteredDestinations;
        }
        return cachedDestinations;
      }
      
      // Fallback ultime sur les destinations statiques
      myCustomPrintStatement("Utilisation des destinations statiques comme fallback");
      final staticDestinations = _getStaticDestinations();
      // Filtrer par distance si position utilisateur fournie
      if (userLatitude != null && userLongitude != null) {
        final filteredDestinations = await _filterDestinationsByDistance(
          staticDestinations, 
          userLatitude, 
          userLongitude,
        );
        return filteredDestinations;
      }
      return staticDestinations;
    }
  }

  /// Stream pour écouter les changements en temps réel (optionnel)
  static Stream<List<PopularDestination>> getDestinationsStream() {
    return _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PopularDestination.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Met en cache les destinations localement
  static Future<void> _cacheDestinations(List<PopularDestination> destinations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = destinations.map((d) => d.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      await prefs.setInt(_cacheVersionKey, _currentCacheVersion);
      myCustomPrintStatement("Destinations mises en cache (version $_currentCacheVersion)");
    } catch (e) {
      myCustomPrintStatement("Erreur lors de la mise en cache: $e");
    }
  }

  /// Récupère les destinations depuis le cache local
  static Future<List<PopularDestination>> _getCachedDestinations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      
      if (cachedData == null) return [];
      
      final List<dynamic> jsonList = json.decode(cachedData);
      return jsonList
          .map((json) => PopularDestination.fromJson(json))
          .toList();
    } catch (e) {
      myCustomPrintStatement("Erreur lors de la lecture du cache: $e");
      return [];
    }
  }

  /// Vérifie si le cache est encore valide
  static Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Vérifier la version du cache - si différente, invalider
      final cachedVersion = prefs.getInt(_cacheVersionKey) ?? 0;
      if (cachedVersion < _currentCacheVersion) {
        myCustomPrintStatement("⚠️ Cache version obsolète ($cachedVersion < $_currentCacheVersion) - invalidation forcée");
        await clearCache();
        return false;
      }

      final lastUpdateString = prefs.getString(_lastUpdateKey);

      if (lastUpdateString == null) return false;

      final lastUpdate = DateTime.parse(lastUpdateString);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);

      return difference.inHours < _cacheValidityHours;
    } catch (e) {
      myCustomPrintStatement("Erreur lors de la vérification du cache: $e");
      return false;
    }
  }

  /// Force le rafraîchissement du cache
  static Future<List<PopularDestination>> refreshDestinations({
    double? userLatitude,
    double? userLongitude,
  }) async {
    try {
      // Vider le cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);
      
      // Récupérer les nouvelles données
      return await getDestinations(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
    } catch (e) {
      myCustomPrintStatement("Erreur lors du rafraîchissement: $e");
      return await _getCachedDestinations();
    }
  }

  /// Destinations statiques comme fallback ultime
  static List<PopularDestination> _getStaticDestinations() {
    return PopularDestinations.destinations;
  }

  /// Utilitaire pour vider complètement le cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);
      await prefs.remove(_cacheVersionKey);
      myCustomPrintStatement("Cache des destinations vidé (y compris Tana Waterfront)");
    } catch (e) {
      myCustomPrintStatement("Erreur lors du vidage du cache: $e");
    }
  }

  /// Récupère la distance maximale autorisée depuis les settings Firestore
  static Future<double> _getMaxDistanceKm() async {
    try {
      final settingsDoc = await FirestoreServices.settings.doc("BfnqY5zbKjRDEiUZbaCx").get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data() as Map<String, dynamic>;
        final maxDistance = data['popular_destinations_max_distance_km'];
        if (maxDistance != null) {
          myCustomPrintStatement("Distance max récupérée depuis Firestore: ${maxDistance}km");
          return double.parse(maxDistance.toString());
        }
      }
      
      // Fallback par défaut
      myCustomPrintStatement("Utilisation de la distance par défaut: 50km");
      return 50.0;
    } catch (e) {
      myCustomPrintStatement("Erreur lors de la récupération de la distance max: $e");
      return 50.0; // Fallback par défaut
    }
  }

  /// Filtre les destinations par distance depuis la position utilisateur
  static Future<List<PopularDestination>> _filterDestinationsByDistance(
    List<PopularDestination> destinations,
    double userLatitude,
    double userLongitude,
  ) async {
    final maxDistanceKm = await _getMaxDistanceKm();
    
    return destinations.where((destination) {
      final distance = destination.distanceFromKm(userLatitude, userLongitude);
      final isWithinRange = distance <= maxDistanceKm;
      
      if (!isWithinRange) {
        myCustomPrintStatement(
          "Destination '${destination.name}' exclue (${distance.toStringAsFixed(1)}km > ${maxDistanceKm}km)"
        );
      }
      
      return isWithinRange;
    }).toList();
  }
}