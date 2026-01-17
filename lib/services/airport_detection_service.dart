/// Service de détection d'aéroports dans les adresses
///
/// Détecte si une adresse correspond à un aéroport en utilisant
/// des mots-clés spécifiques (multilingue).
class AirportDetectionService {
  // Mots-clés pour la détection d'aéroports
  static const List<String> _airportKeywords = [
    'aéroport',
    'aeroport',
    'airport',
    'ivato', // Aéroport principal d'Antananarivo, Madagascar
    'nosy be', // Aéroport Fascene, Nosy Be
    'toamasina', // Aéroport de Toamasina
    'mahajanga', // Aéroport Amborovy
    'toliara', // Aéroport de Tuléar
    'antsiranana', // Aéroport Arrachart
    'terminal aérien',
    'terminal aerien',
    'air terminal',
  ];

  /// Détecte si une adresse correspond à un aéroport
  ///
  /// [address] L'adresse à analyser
  ///
  /// Retourne `true` si l'adresse contient un mot-clé d'aéroport
  static bool isAirportAddress(String? address) {
    if (address == null || address.isEmpty) {
      return false;
    }

    // Normaliser l'adresse (minuscules, supprimer accents)
    final normalized = _normalizeString(address);

    // Vérifier si l'adresse contient un mot-clé
    for (final keyword in _airportKeywords) {
      if (normalized.contains(keyword)) {
        print('✈️ AEROPORT DETECTE: "$address" contient "$keyword"');
        return true;
      }
    }

    print('❌ PAS D\'AEROPORT: "$address" (normalisé: "$normalized")');
    return false;
  }

  /// Extrait le nom de l'aéroport si détecté
  ///
  /// [address] L'adresse contenant potentiellement un aéroport
  ///
  /// Retourne le nom de l'aéroport ou null si non détecté
  static String? extractAirportName(String? address) {
    if (!isAirportAddress(address)) {
      return null;
    }

    // Liste des noms d'aéroports connus avec leurs variantes
    final airportNames = {
      'ivato': 'Aéroport International Ivato',
      'nosy be': 'Aéroport Fascene Nosy Be',
      'toamasina': 'Aéroport de Toamasina',
      'mahajanga': 'Aéroport Amborovy Mahajanga',
      'toliara': 'Aéroport de Tuléar',
      'antsiranana': 'Aéroport Arrachart Antsiranana',
    };

    final normalized = _normalizeString(address!);

    // Chercher le nom correspondant
    for (final entry in airportNames.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    // Retourner un nom générique si pas de correspondance exacte
    return 'Aéroport';
  }

  /// Valide le format d'un numéro de vol
  ///
  /// Accepte tous les formats courants :
  /// - AF934
  /// - AF 934
  /// - AIR FRANCE 934
  /// - AF-934
  ///
  /// [flightNumber] Le numéro de vol à valider
  ///
  /// Retourne `true` si le format est valide
  static bool isValidFlightNumber(String? flightNumber) {
    if (flightNumber == null || flightNumber.isEmpty) {
      return false;
    }

    // Accepter tout format avec au moins 2 caractères
    // (pas de validation stricte pour supporter toutes les compagnies)
    final trimmed = flightNumber.trim();
    return trimmed.length >= 2;
  }

  /// Normalise un numéro de vol pour affichage cohérent
  ///
  /// [flightNumber] Le numéro de vol brut
  ///
  /// Retourne le numéro normalisé en majuscules sans espaces excessifs
  static String normalizeFlightNumber(String flightNumber) {
    return flightNumber.trim().toUpperCase();
  }

  /// Normalise une chaîne pour la comparaison
  /// (minuscules, sans accents)
  static String _normalizeString(String input) {
    // Convertir en minuscules
    String result = input.toLowerCase();

    // Supprimer les accents
    const withAccents = 'àáâãäåèéêëìíîïòóôõöùúûüýÿ';
    const withoutAccents = 'aaaaaaeeeeiiiiooooouuuuyy';

    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result;
  }

  /// Génère une URL de recherche d'informations de vol
  ///
  /// [flightNumber] Le numéro de vol
  ///
  /// Retourne une URL vers Google Flights ou un moteur de recherche
  static String getFlightInfoUrl(String flightNumber) {
    final normalized = normalizeFlightNumber(flightNumber);
    // Google reconnaît automatiquement les numéros de vol
    return 'https://www.google.com/search?q=flight+$normalized';
  }

  /// Retourne l'émoji approprié selon le type de trajet
  ///
  /// [isPickup] true si c'est une récupération à l'aéroport (arrivée)
  ///
  /// Retourne '🛬' pour arrivée, '🛫' pour départ
  static String getAirportEmoji({required bool isPickup}) {
    return isPickup ? '🛬' : '🛫';
  }
}
