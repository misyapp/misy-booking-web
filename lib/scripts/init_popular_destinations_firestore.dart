import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/models/popular_destination.dart';

class InitPopularDestinationsFirestore {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'popular_destinations';

  /// Initialise la collection Firestore avec les destinations existantes
  static Future<void> initializeDestinations() async {
    try {
      print('🚀 Initialisation des destinations populaires dans Firestore...');
      
      // Vérifier si la collection existe déjà et n'est pas vide
      final existingDocs = await _firestore
          .collection(_collectionName)
          .limit(1)
          .get();
      
      if (existingDocs.docs.isNotEmpty) {
        print('⚠️  La collection existe déjà avec des données. Arrêt de l\'initialisation.');
        return;
      }

      // Données à insérer
      final destinationsData = [
        {
          'name': 'Aéroport International Ivato',
          'address': 'Antananarivo 105, Madagascar',
          'latitude': -18.7969,
          'longitude': 47.4788,
          'icon': 'flight',
          'isActive': true,
          'order': 1,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Tana Waterfront',
          'address': 'Ambodivona, Antananarivo 101, Madagascar',
          'latitude': -18.9204,
          'longitude': 47.5208,
          'icon': 'shopping_bag',
          'isActive': true,
          'order': 2,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Gare de Soarano',
          'address': 'Antaninarenina, Antananarivo 101, Madagascar',
          'latitude': -18.9137,
          'longitude': 47.5214,
          'icon': 'train',
          'isActive': true,
          'order': 3,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Palais de la Reine',
          'address': 'Haute-Ville, Antananarivo 101, Madagascar',
          'latitude': -18.9061,
          'longitude': 47.5240,
          'icon': 'account_balance',
          'isActive': true,
          'order': 4,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Lac Anosy',
          'address': 'Isoraka, Antananarivo 101, Madagascar',
          'latitude': -18.9244,
          'longitude': 47.5287,
          'icon': 'landscape',
          'isActive': true,
          'order': 5,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Centre Commercial Tanjombato',
          'address': 'Tanjombato, Antananarivo, Madagascar',
          'latitude': -18.9386,
          'longitude': 47.4731,
          'icon': 'shopping_mall',
          'isActive': true,
          'order': 6,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Université d\'Antananarivo',
          'address': 'Ankatso, Antananarivo 101, Madagascar',
          'latitude': -18.9061,
          'longitude': 47.5309,
          'icon': 'school',
          'isActive': true,
          'order': 7,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Hôpital Joseph Ravoahangy Andrianavalona',
          'address': 'Antananarivo 101, Madagascar',
          'latitude': -18.9061,
          'longitude': 47.5200,
          'icon': 'local_hospital',
          'isActive': true,
          'order': 8,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Mahamasina Stadium',
          'address': 'Mahamasina, Antananarivo 101, Madagascar',
          'latitude': -18.9204,
          'longitude': 47.5287,
          'icon': 'stadium',
          'isActive': true,
          'order': 9,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
        {
          'name': 'Parc de Tsimbazaza',
          'address': 'Tsimbazaza, Antananarivo 101, Madagascar',
          'latitude': -18.9283,
          'longitude': 47.5275,
          'icon': 'park',
          'isActive': true,
          'order': 10,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
      ];

      // Insérer les données en batch
      final batch = _firestore.batch();
      
      for (int i = 0; i < destinationsData.length; i++) {
        final docRef = _firestore
            .collection(_collectionName)
            .doc('destination_${i + 1}');
        batch.set(docRef, destinationsData[i]);
      }

      await batch.commit();
      
      print('✅ ${destinationsData.length} destinations populaires ajoutées avec succès !');
      
      // Afficher un résumé
      print('\\n📊 Résumé des destinations ajoutées:');
      for (int i = 0; i < destinationsData.length; i++) {
        print('  ${i + 1}. ${destinationsData[i]['name']}');
      }
      
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
      rethrow;
    }
  }

  /// Ajoute une nouvelle destination
  static Future<void> addDestination({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String icon,
    bool isActive = true,
    int? order,
  }) async {
    try {
      // Déterminer l'ordre automatiquement si non spécifié
      if (order == null) {
        final lastDoc = await _firestore
            .collection(_collectionName)
            .orderBy('order', descending: true)
            .limit(1)
            .get();
        
        order = lastDoc.docs.isEmpty ? 1 : (lastDoc.docs.first.data()['order'] as int) + 1;
      }

      final data = {
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'icon': icon,
        'isActive': isActive,
        'order': order,
        'lastUpdated': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _firestore.collection(_collectionName).add(data);
      print('✅ Destination "$name" ajoutée avec succès !');
      
    } catch (e) {
      print('❌ Erreur lors de l\'ajout de la destination: $e');
      rethrow;
    }
  }

  /// Désactive une destination (la cache sans la supprimer)
  static Future<void> deactivateDestination(String destinationId) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(destinationId)
          .update({
        'isActive': false,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      
      print('✅ Destination "$destinationId" désactivée !');
    } catch (e) {
      print('❌ Erreur lors de la désactivation: $e');
      rethrow;
    }
  }

  /// Active une destination
  static Future<void> activateDestination(String destinationId) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(destinationId)
          .update({
        'isActive': true,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      
      print('✅ Destination "$destinationId" activée !');
    } catch (e) {
      print('❌ Erreur lors de l\'activation: $e');
      rethrow;
    }
  }

  /// Réorganise l'ordre des destinations
  static Future<void> reorderDestinations(Map<String, int> newOrders) async {
    try {
      final batch = _firestore.batch();
      
      for (final entry in newOrders.entries) {
        final docRef = _firestore.collection(_collectionName).doc(entry.key);
        batch.update(docRef, {
          'order': entry.value,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
      
      await batch.commit();
      print('✅ Ordre des destinations mis à jour !');
      
    } catch (e) {
      print('❌ Erreur lors de la réorganisation: $e');
      rethrow;
    }
  }

  /// Affiche toutes les destinations actuelles
  static Future<void> listDestinations() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('order')
          .get();

      print('\\n📍 Destinations populaires actuelles:');
      print('${'=' * 50}');
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['isActive'] ? '✅' : '❌';
        print('$status [${data['order']}] ${data['name']}');
        print('   📍 ${data['address']}');
        print('   🏷️  ID: ${doc.id}');
        print('   🎨 Icône: ${data['icon']}');
        print('');
      }
      
      print('Total: ${querySnapshot.docs.length} destinations');
      
    } catch (e) {
      print('❌ Erreur lors de la récupération: $e');
      rethrow;
    }
  }

  /// Nettoie complètement la collection (ATTENTION: supprime tout!)
  static Future<void> clearAllDestinations() async {
    try {
      print('⚠️  ATTENTION: Suppression de toutes les destinations...');
      
      final querySnapshot = await _firestore.collection(_collectionName).get();
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('✅ ${querySnapshot.docs.length} destinations supprimées.');
      
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      rethrow;
    }
  }
}