# TODO : Migration des destinations populaires vers Firestore

## 🎯 Objectif

Remplacer la liste statique des destinations populaires par une gestion dynamique via Firestore pour permettre la mise à jour en temps réel des destinations sans redéploiement de l'application.

## 📋 État actuel

**Fichier concerné :** `lib/models/popular_destination.dart`

Actuellement, les destinations sont définies dans une liste statique :
```dart
static const List<PopularDestination> destinations = [
  PopularDestination(
    name: 'Aéroport International Ivato',
    address: 'Antananarivo 105, Madagascar',
    latitude: -18.7969,
    longitude: 47.4788,
    icon: Icons.flight,
  ),
  // ... autres destinations
];
```

## 🔧 Structure Firestore proposée

### Collection : `popular_destinations`

```json
{
  "destination_1": {
    "name": "Aéroport International Ivato",
    "address": "Antananarivo 105, Madagascar",
    "latitude": -18.7969,
    "longitude": 47.4788,
    "icon": "flight",
    "isActive": true,
    "order": 1,
    "lastUpdated": "2025-01-23T10:00:00Z",
    "createdAt": "2025-01-23T10:00:00Z"
  },
  "destination_2": {
    "name": "Tana Waterfront",
    "address": "Ambodivona, Antananarivo 101, Madagascar",
    "latitude": -18.9204,
    "longitude": 47.5208,
    "icon": "shopping_bag",
    "isActive": true,
    "order": 2,
    "lastUpdated": "2025-01-23T10:00:00Z",
    "createdAt": "2025-01-23T10:00:00Z"
  }
}
```

### Mapping des icônes

Convertir les `IconData` en strings :
- `Icons.flight` → `"flight"`
- `Icons.shopping_bag` → `"shopping_bag"`
- `Icons.train` → `"train"`
- `Icons.account_balance` → `"account_balance"`
- `Icons.landscape` → `"landscape"`

## 🛠️ Modifications techniques nécessaires

### 1. Créer le service Firestore

**Nouveau fichier :** `lib/services/popular_destinations_service.dart`

```dart
class PopularDestinationsService {
  static Future<List<PopularDestination>> getDestinations() async {}
  static Future<void> cacheDestinations(List<PopularDestination> destinations) async {}
  static List<PopularDestination> getCachedDestinations() {}
}
```

### 2. Modifier le modèle de données

**Fichier :** `lib/models/popular_destination.dart`

- Ajouter `fromFirestore()` factory constructor
- Ajouter `toFirestore()` method
- Gérer la conversion string → IconData
- Ajouter champs `isActive`, `order`, `lastUpdated`

### 3. Modifier le widget

**Fichier :** `lib/widget/popular_destinations_widget.dart`

- Remplacer la liste statique par un `FutureBuilder` ou `StreamBuilder`
- Ajouter gestion du loading
- Ajouter gestion d'erreur avec fallback sur cache local
- Filtrer les destinations `isActive: true`
- Trier par `order`

### 4. Ajouter gestion du cache

**Utiliser :** `lib/services/share_prefrence_service.dart`

- Cache local des destinations
- Mise à jour périodique
- Mode offline

## ✅ Avantages

- **📱 Admin friendly** : Destinations modifiables depuis un panel admin
- **🚀 Déploiement rapide** : Ajout/suppression sans redéploiement app
- **📍 Géolocalisation précise** : Coordonnées mises à jour facilement
- **📊 Ordre configurable** : Réorganisation des destinations
- **⏸️ Contrôle d'affichage** : Activation/désactivation temporaire
- **🌍 Localisation** : Possibilité d'ajouter des traductions par région

## ⚠️ Points d'attention

### Performance
- **Cache local** : Éviter les appels réseau répétés
- **Mise à jour incrémentale** : Vérifier `lastUpdated` avant fetch complète
- **Limitation réseau** : Gérer les cas de connexion lente

### Robustesse
- **Fallback** : Garder une liste de base en cas d'échec réseau
- **Validation** : Vérifier la validité des coordonnées côté client
- **Timeout** : Limiter le temps d'attente des requêtes Firestore

### Sécurité
- **Règles Firestore** : Lecture publique, écriture admin uniquement
- **Validation des données** : S'assurer de la cohérence des coordonnées

## 📊 Estimation

| Aspect | Estimation |
|--------|------------|
| **Complexité** | Moyenne (2-3h de développement) |
| **Impact utilisateur** | Faible (changement transparent) |
| **Priorité** | Basse (amélioration future) |
| **Tests nécessaires** | Connexion réseau, cache, fallback |

## 🚀 Plan de migration

### Phase 1 : Préparation
1. Créer la collection Firestore
2. Migrer les données existantes
3. Configurer les règles de sécurité

### Phase 2 : Développement
1. Créer le service PopularDestinationsService
2. Modifier le modèle PopularDestination
3. Adapter le widget PopularDestinationsWidget

### Phase 3 : Tests
1. Tester avec/sans connexion réseau
2. Valider le cache local
3. Vérifier les performances

### Phase 4 : Déploiement
1. Déployer en mode feature flag
2. Monitorer les performances
3. Activer pour tous les utilisateurs

---

**Date de création :** 23 janvier 2025  
**Statut :** À faire  
**Assigné à :** À définir