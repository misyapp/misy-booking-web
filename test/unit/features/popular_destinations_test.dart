import 'package:flutter_test/flutter_test.dart';
import 'package:rider_ride_hailing_app/models/popular_destination.dart';
import 'package:flutter/material.dart';

void main() {
  group('PopularDestination Model Tests', () {
    test('fromJson should create PopularDestination correctly', () {
      final json = {
        'id': 'test_1',
        'name': 'Test Destination',
        'address': 'Test Address',
        'latitude': -18.9204,
        'longitude': 47.5208,
        'iconString': 'flight',
        'isActive': true,
        'order': 1,
        'lastUpdated': '2025-01-24T10:00:00Z',
        'createdAt': '2025-01-24T10:00:00Z',
      };

      final destination = PopularDestination.fromJson(json);

      expect(destination.id, 'test_1');
      expect(destination.name, 'Test Destination');
      expect(destination.address, 'Test Address');
      expect(destination.latitude, -18.9204);
      expect(destination.longitude, 47.5208);
      expect(destination.iconString, 'flight');
      expect(destination.icon, Icons.flight);
      expect(destination.isActive, true);
      expect(destination.order, 1);
    });

    test('toJson should serialize PopularDestination correctly', () {
      final destination = const PopularDestination(
        id: 'test_1',
        name: 'Test Destination',
        address: 'Test Address',
        latitude: -18.9204,
        longitude: 47.5208,
        icon: Icons.flight,
        iconString: 'flight',
        isActive: true,
        order: 1,
      );

      final json = destination.toJson();

      expect(json['id'], 'test_1');
      expect(json['name'], 'Test Destination');
      expect(json['address'], 'Test Address');
      expect(json['latitude'], -18.9204);
      expect(json['longitude'], 47.5208);
      expect(json['iconString'], 'flight');
      expect(json['isActive'], true);
      expect(json['order'], 1);
    });

    test('fromFirestore should create PopularDestination correctly', () {
      final firestoreData = {
        'name': 'Firestore Destination',
        'address': 'Firestore Address',
        'latitude': -18.9204,
        'longitude': 47.5208,
        'icon': 'shopping_bag',
        'isActive': true,
        'order': 2,
        'lastUpdated': '2025-01-24T10:00:00Z',
        'createdAt': '2025-01-24T10:00:00Z',
      };

      final destination = PopularDestination.fromFirestore(firestoreData, 'firestore_1');

      expect(destination.id, 'firestore_1');
      expect(destination.name, 'Firestore Destination');
      expect(destination.address, 'Firestore Address');
      expect(destination.iconString, 'shopping_bag');
      expect(destination.icon, Icons.shopping_bag);
      expect(destination.isActive, true);
      expect(destination.order, 2);
    });

    test('toFirestore should serialize for Firestore correctly', () {
      final destination = const PopularDestination(
        id: 'test_1',
        name: 'Test Destination',
        address: 'Test Address',
        latitude: -18.9204,
        longitude: 47.5208,
        icon: Icons.train,
        iconString: 'train',
        isActive: true,
        order: 3,
      );

      final firestoreData = destination.toFirestore();

      expect(firestoreData['name'], 'Test Destination');
      expect(firestoreData['address'], 'Test Address');
      expect(firestoreData['latitude'], -18.9204);
      expect(firestoreData['longitude'], 47.5208);
      expect(firestoreData['icon'], 'train');
      expect(firestoreData['isActive'], true);
      expect(firestoreData['order'], 3);
      // Note: id n'est pas inclus dans toFirestore()
      expect(firestoreData.containsKey('id'), false);
    });

    test('icon mapping should work correctly', () {
      final testCases = [
        {'iconString': 'flight', 'expectedIcon': Icons.flight},
        {'iconString': 'shopping_bag', 'expectedIcon': Icons.shopping_bag},
        {'iconString': 'train', 'expectedIcon': Icons.train},
        {'iconString': 'account_balance', 'expectedIcon': Icons.account_balance},
        {'iconString': 'landscape', 'expectedIcon': Icons.landscape},
        {'iconString': 'unknown', 'expectedIcon': Icons.place}, // fallback
      ];

      for (final testCase in testCases) {
        final destination = PopularDestination.fromJson({
          'id': 'test',
          'name': 'Test',
          'address': 'Test',
          'latitude': 0.0,
          'longitude': 0.0,
          'iconString': testCase['iconString'],
          'isActive': true,
          'order': 1,
        });

        expect(destination.icon, testCase['expectedIcon'],
            reason: 'Icon mapping failed for ${testCase['iconString']}');
      }
    });

    test('fromLegacy should convert legacy format correctly', () {
      final legacy = PopularDestination.fromLegacy(
        name: 'Legacy Destination',
        address: 'Legacy Address',
        latitude: -18.9204,
        longitude: 47.5208,
        icon: Icons.flight,
      );

      expect(legacy.name, 'Legacy Destination');
      expect(legacy.address, 'Legacy Address');
      expect(legacy.latitude, -18.9204);
      expect(legacy.longitude, 47.5208);
      expect(legacy.icon, Icons.flight);
      expect(legacy.iconString, 'flight');
      expect(legacy.isActive, true);
      expect(legacy.order, 0);
      expect(legacy.id, 'legacy_legacy_destination');
    });

    test('default values should be set correctly', () {
      final destination = PopularDestination.fromJson({
        'id': 'test',
        'name': 'Test',
        'address': 'Test',
        'latitude': 0.0,
        'longitude': 0.0,
        // Missing: iconString, isActive, order
      });

      expect(destination.iconString, 'place'); // default
      expect(destination.icon, Icons.place); // default
      expect(destination.isActive, true); // default
      expect(destination.order, 0); // default
    });
  });

  group('PopularDestinations Static Data Tests', () {
    test('static destinations should have correct structure', () {
      final destinations = PopularDestinations.destinations;

      expect(destinations.isNotEmpty, true);
      
      for (final destination in destinations) {
        expect(destination.id.isNotEmpty, true);
        expect(destination.name.isNotEmpty, true);
        expect(destination.address.isNotEmpty, true);
        expect(destination.iconString.isNotEmpty, true);
        expect(destination.isActive, true);
        expect(destination.order, greaterThan(0));
      }
    });

    test('static destinations should be ordered correctly', () {
      final destinations = PopularDestinations.destinations;
      
      for (int i = 0; i < destinations.length - 1; i++) {
        expect(destinations[i].order, lessThanOrEqualTo(destinations[i + 1].order),
            reason: 'Destinations should be ordered by order field');
      }
    });

    test('static destinations should have unique IDs', () {
      final destinations = PopularDestinations.destinations;
      final ids = destinations.map((d) => d.id).toList();
      final uniqueIds = ids.toSet();
      
      expect(ids.length, uniqueIds.length,
          reason: 'All destination IDs should be unique');
    });
  });
}