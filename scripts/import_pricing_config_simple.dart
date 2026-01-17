// Script Dart simple pour générer le JSON de configuration
// À copier-coller manuellement dans Firestore

void main() {
  print('🔥 Configuration Pricing Misy 2.0\n');
  
  final config = {
    "version": "2.0",
    "enableNewPricingSystem": false,
    "floorPrices": {
      "taxi_moto": 6000,
      "classic": 8000,
      "confort": 11000,
      "4x4": 13000,
      "van": 15000
    },
    "pricePerKm": {
      "taxi_moto": 2000,
      "classic": 2750,
      "confort": 3850,
      "4x4": 4500,
      "van": 5000
    },
    "floorPriceThreshold": 3.0,
    "trafficMultiplier": 1.4,
    "trafficPeriods": [
      {
        "startTime": "07:00",
        "endTime": "09:59",
        "daysOfWeek": [1, 2, 3, 4, 5]
      },
      {
        "startTime": "16:00",
        "endTime": "18:59", 
        "daysOfWeek": [1, 2, 3, 4, 5]
      }
    ],
    "longTripThreshold": 15.0,
    "longTripMultiplier": 1.2,
    "reservationSurcharge": {
      "taxi_moto": 3600,
      "classic": 5000,
      "confort": 7000,
      "4x4": 8200,
      "van": 9100
    },
    "reservationAdvanceMinutes": 10,
    "enableRounding": true,
    "roundingStep": 500
  };
  
  print('📋 JSON à copier dans Firestore :\n');
  print('Collection: setting');
  print('Document ID: pricing_config_v2\n');
  
  // Affichage du JSON formaté
  print('=== DÉBUT JSON ===');
  _printJsonFormatted(config, 0);
  print('=== FIN JSON ===\n');
  
  print('📍 Instructions :');
  print('1. Aller sur Firebase Console');
  print('2. Ouvrir Firestore Database');
  print('3. Collection "setting" > Add document');
  print('4. Document ID: pricing_config_v2');
  print('5. Coller le JSON ci-dessus');
  print('6. Sauvegarder\n');
  
  print('⚠️ IMPORTANT: enableNewPricingSystem = false');
  print('✅ Le système reste inactif jusqu\'à activation manuelle');
}

void _printJsonFormatted(dynamic obj, int indent) {
  final spaces = '  ' * indent;
  
  if (obj is Map) {
    print('$spaces{');
    final keys = obj.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final value = obj[key];
      final comma = i < keys.length - 1 ? ',' : '';
      
      if (value is Map || value is List) {
        print('$spaces  "$key":');
        _printJsonFormatted(value, indent + 1);
        print('$spaces$comma');
      } else if (value is String) {
        print('$spaces  "$key": "$value"$comma');
      } else {
        print('$spaces  "$key": $value$comma');
      }
    }
    print('$spaces}');
  } else if (obj is List) {
    print('$spaces[');
    for (int i = 0; i < obj.length; i++) {
      final item = obj[i];
      final comma = i < obj.length - 1 ? ',' : '';
      
      if (item is Map || item is List) {
        _printJsonFormatted(item, indent + 1);
        print('$spaces$comma');
      } else if (item is String) {
        print('$spaces  "$item"$comma');
      } else {
        print('$spaces  $item$comma');
      }
    }
    print('$spaces]');
  }
}