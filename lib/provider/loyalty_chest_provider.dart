import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/loyalty_chest.dart';
import 'package:rider_ride_hailing_app/services/chest_reward_service.dart';

class LoyaltyChestProvider extends ChangeNotifier {
  List<LoyaltyChest> _chests = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetched;
  
  static const int cacheValidityMinutes = 30;

  List<LoyaltyChest> get chests => _chests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  bool get isCacheValid {
    if (_lastFetched == null) return false;
    return DateTime.now().difference(_lastFetched!).inMinutes < cacheValidityMinutes;
  }

  /// Charge les configurations des coffres depuis Firestore
  Future<void> loadChestConfigurations({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid && _chests.isNotEmpty) {
      myCustomPrintStatement('LoyaltyChestProvider: Utilisation du cache pour les coffres');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      myCustomPrintStatement('LoyaltyChestProvider: Chargement des configurations des coffres...');
      
      final chestConfigRef = FirebaseFirestore.instance
          .collection('setting')
          .doc('loyalty_config')
          .collection('loyalty_chest_config');

      final snapshot = await chestConfigRef.get();
      
      List<LoyaltyChest> loadedChests = [];
      
      if (snapshot.docs.isEmpty) {
        myCustomPrintStatement('LoyaltyChestProvider: Aucune configuration trouvée, utilisation des valeurs par défaut');
        loadedChests = LoyaltyChest.defaultChests;
      } else {
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final chest = LoyaltyChest.fromJson({
              'tier': doc.id,
              ...data,
            });
            loadedChests.add(chest);
          } catch (e) {
            myCustomPrintStatement('LoyaltyChestProvider: Erreur parsing coffre ${doc.id} - $e');
          }
        }
      }

      // Trier les coffres par prix croissant pour assurer l'ordre logique
      loadedChests.sort((a, b) => a.price.compareTo(b.price));
      
      _chests = loadedChests;
      _lastFetched = DateTime.now();
      
      myCustomPrintStatement('LoyaltyChestProvider: ${_chests.length} coffres chargés avec succès');
      
    } catch (e) {
      myCustomPrintStatement('LoyaltyChestProvider: Erreur chargement coffres - $e');
      _errorMessage = 'Erreur lors du chargement des coffres: $e';
      
      // En cas d'erreur, utiliser les valeurs par défaut
      if (_chests.isEmpty) {
        _chests = LoyaltyChest.defaultChests;
        myCustomPrintStatement('LoyaltyChestProvider: Utilisation des coffres par défaut suite à l\'erreur');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtient un coffre par son tier
  LoyaltyChest? getChestByTier(String tier) {
    try {
      return _chests.firstWhere((chest) => chest.tier == tier);
    } catch (e) {
      myCustomPrintStatement('LoyaltyChestProvider: Coffre $tier non trouvé');
      return null;
    }
  }

  /// Vérifie si un utilisateur peut déverrouiller un coffre
  bool canUnlockChest(String tier, double userPoints) {
    final chest = getChestByTier(tier);
    if (chest == null) return false;
    
    return userPoints >= chest.price && (chest.availability ?? true);
  }

  /// Obtient la liste des coffres disponibles pour un utilisateur
  List<LoyaltyChest> getAvailableChests(double userPoints) {
    return _chests.where((chest) => 
      canUnlockChest(chest.tier, userPoints)
    ).toList();
  }

  /// Obtient la liste des coffres non disponibles pour un utilisateur
  List<LoyaltyChest> getUnavailableChests(double userPoints) {
    return _chests.where((chest) => 
      !canUnlockChest(chest.tier, userPoints)
    ).toList();
  }

  /// Rafraîchit les données depuis Firestore
  Future<void> refresh() async {
    await loadChestConfigurations(forceRefresh: true);
  }

  /// Nettoie les erreurs
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Déverrouille un coffre et retourne le résultat de la récompense
  Future<ChestRewardResult> unlockChest(String tier, String userId) async {
    try {
      myCustomPrintStatement('LoyaltyChestProvider: Déverrouillage coffre $tier pour user $userId');
      
      final chest = getChestByTier(tier);
      if (chest == null) {
        return ChestRewardResult.failure('Coffre non trouvé: $tier');
      }

      // Utiliser le service de récompense pour ouvrir le coffre
      final result = await ChestRewardService.instance.openChest(
        userId: userId,
        chest: chest,
      );

      if (result.isSuccess) {
        myCustomPrintStatement('LoyaltyChestProvider: ✅ Coffre $tier ouvert avec succès - Gain: ${result.reward?.amount} MGA');
      } else {
        myCustomPrintStatement('LoyaltyChestProvider: ❌ Échec ouverture coffre $tier - ${result.errorMessage}');
      }

      return result;
    } catch (e) {
      myCustomPrintStatement('LoyaltyChestProvider: Erreur déverrouillage coffre $tier - $e');
      return ChestRewardResult.failure('Erreur lors de l\'ouverture du coffre: $e');
    }
  }

  /// Valide les probabilités d'un coffre
  bool validateChestProbabilities(String tier) {
    final chest = getChestByTier(tier);
    if (chest == null) return false;
    
    return ChestRewardService.instance.validateChestProbabilities(chest);
  }

  /// Calcule les statistiques d'un coffre
  ChestStats? getChestStats(String tier) {
    final chest = getChestByTier(tier);
    if (chest == null) return null;
    
    return ChestRewardService.instance.calculateChestStats(chest);
  }
}