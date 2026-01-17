import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class PopularDestination {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final IconData icon;
  final String iconString;
  final bool isActive;
  final int order;
  final DateTime? lastUpdated;
  final DateTime? createdAt;

  const PopularDestination({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.icon,
    required this.iconString,
    this.isActive = true,
    this.order = 0,
    this.lastUpdated,
    this.createdAt,
  });

  factory PopularDestination.fromFirestore(Map<String, dynamic> data, String id) {
    return PopularDestination(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      iconString: data['icon'] ?? 'place',
      icon: _getIconFromString(data['icon'] ?? 'place'),
      isActive: data['isActive'] ?? true,
      order: data['order'] ?? 0,
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory PopularDestination.fromJson(Map<String, dynamic> json) {
    return PopularDestination(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      iconString: json['iconString'] ?? 'place',
      icon: _getIconFromString(json['iconString'] ?? 'place'),
      isActive: json['isActive'] ?? true,
      order: json['order'] ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'iconString': iconString,
      'isActive': isActive,
      'order': order,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'icon': iconString,
      'isActive': isActive,
      'order': order,
      'lastUpdated': (lastUpdated ?? DateTime.now()).toIso8601String(),
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  static IconData _getIconFromString(String iconString) {
    switch (iconString) {
      case 'flight':
        return Icons.flight;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'train':
        return Icons.train;
      case 'account_balance':
        return Icons.account_balance;
      case 'landscape':
        return Icons.landscape;
      case 'place':
        return Icons.place;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'shopping_mall':
        return Icons.shopping_cart;
      case 'church':
        return Icons.church;
      case 'stadium':
        return Icons.stadium;
      case 'park':
        return Icons.park;
      case 'hotel':
        return Icons.hotel;
      default:
        return Icons.place;
    }
  }

  factory PopularDestination.fromLegacy({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required IconData icon,
  }) {
    String iconString = _getStringFromIcon(icon);
    return PopularDestination(
      id: 'legacy_${name.toLowerCase().replaceAll(' ', '_')}',
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      icon: icon,
      iconString: iconString,
      isActive: true,
      order: 0,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }

  static String _getStringFromIcon(IconData icon) {
    if (icon == Icons.flight) return 'flight';
    if (icon == Icons.shopping_bag) return 'shopping_bag';
    if (icon == Icons.train) return 'train';
    if (icon == Icons.account_balance) return 'account_balance';
    if (icon == Icons.landscape) return 'landscape';
    if (icon == Icons.place) return 'place';
    if (icon == Icons.local_hospital) return 'local_hospital';
    if (icon == Icons.school) return 'school';
    if (icon == Icons.restaurant) return 'restaurant';
    if (icon == Icons.local_gas_station) return 'local_gas_station';
    if (icon == Icons.shopping_cart) return 'shopping_mall';
    if (icon == Icons.church) return 'church';
    if (icon == Icons.stadium) return 'stadium';
    if (icon == Icons.park) return 'park';
    if (icon == Icons.hotel) return 'hotel';
    return 'place';
  }

  /// Calcule la distance en kilomètres entre cette destination et un point donné
  /// Utilise la formule de Haversine pour calculer la distance orthodromique
  double distanceFromKm(double userLatitude, double userLongitude) {
    const double earthRadiusKm = 6371.0;
    
    // Conversion des degrés en radians
    double lat1Rad = userLatitude * pi / 180;
    double lon1Rad = userLongitude * pi / 180;
    double lat2Rad = latitude * pi / 180;
    double lon2Rad = longitude * pi / 180;
    
    // Différences
    double deltaLat = lat2Rad - lat1Rad;
    double deltaLon = lon2Rad - lon1Rad;
    
    // Formule de Haversine
    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c;
  }
}

class PopularDestinations {
  static const List<PopularDestination> destinations = [
    PopularDestination(
      id: 'legacy_1',
      name: 'Aéroport International Ivato',
      address: 'Antananarivo 105, Madagascar',
      latitude: -18.7969,
      longitude: 47.4788,
      icon: Icons.flight,
      iconString: 'flight',
      isActive: true,
      order: 1,
    ),
    PopularDestination(
      id: 'legacy_2',
      name: 'Gare de Soarano',
      address: 'Antaninarenina, Antananarivo 101, Madagascar',
      latitude: -18.9137,
      longitude: 47.5214,
      icon: Icons.train,
      iconString: 'train',
      isActive: true,
      order: 2,
    ),
    PopularDestination(
      id: 'legacy_3',
      name: 'Palais de la Reine',
      address: 'Haute-Ville, Antananarivo 101, Madagascar',
      latitude: -18.9061,
      longitude: 47.5240,
      icon: Icons.account_balance,
      iconString: 'account_balance',
      isActive: true,
      order: 3,
    ),
    PopularDestination(
      id: 'legacy_4',
      name: 'Lac Anosy',
      address: 'Isoraka, Antananarivo 101, Madagascar',
      latitude: -18.9244,
      longitude: 47.5287,
      icon: Icons.landscape,
      iconString: 'landscape',
      isActive: true,
      order: 4,
    ),
  ];
}
