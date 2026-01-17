import 'package:video_player/video_player.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

class VideoPreloadService {
  static final VideoPreloadService _instance = VideoPreloadService._internal();
  factory VideoPreloadService() => _instance;
  VideoPreloadService._internal();

  static VideoPreloadService get instance => _instance;

  // Map pour stocker les controllers par tier
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _isLoaded = {};

  // Mapping des tiers vers les fichiers vidéo
  final Map<String, String> _videoAssets = {
    'tier1': 'assets/video/opening_bronze.mp4',
    'tier2': 'assets/video/opening_silver.mp4',
    'tier3': 'assets/video/opening_gold.mp4',
  };

  /// Précharge toutes les vidéos des coffres
  Future<void> preloadAllVideos() async {
    myCustomPrintStatement('VideoPreloadService: Démarrage du préchargement des vidéos...');

    final futures = _videoAssets.entries.map((entry) => _preloadVideo(entry.key, entry.value));
    
    await Future.wait(futures);
    
    final loadedCount = _isLoaded.values.where((loaded) => loaded).length;
    myCustomPrintStatement('VideoPreloadService: $loadedCount/${_videoAssets.length} vidéos préchargées avec succès');
  }

  /// Précharge une vidéo spécifique
  Future<void> _preloadVideo(String tier, String assetPath) async {
    try {
      myCustomPrintStatement('VideoPreloadService: Préchargement $tier -> $assetPath');

      final controller = VideoPlayerController.asset(assetPath);
      await controller.initialize();
      
      // Préparation pour un démarrage rapide
      await controller.setLooping(false);
      await controller.setVolume(1.0);
      
      _controllers[tier] = controller;
      _isLoaded[tier] = true;
      
      myCustomPrintStatement('VideoPreloadService: ✅ $tier préchargé avec succès');
    } catch (e) {
      myCustomPrintStatement('VideoPreloadService: ❌ Erreur préchargement $tier - $e');
      _isLoaded[tier] = false;
    }
  }

  /// Obtient le controller pour un tier donné
  VideoPlayerController? getController(String tier) {
    if (_isLoaded[tier] == true && _controllers.containsKey(tier)) {
      return _controllers[tier];
    }
    return null;
  }

  /// Vérifie si une vidéo est disponible
  bool isVideoReady(String tier) {
    return _isLoaded[tier] == true;
  }

  /// Remet une vidéo à zéro pour la prochaine lecture
  Future<void> resetVideo(String tier) async {
    final controller = _controllers[tier];
    if (controller != null && controller.value.isInitialized) {
      await controller.seekTo(Duration.zero);
      await controller.pause();
    }
  }

  /// Dispose toutes les ressources vidéo
  void dispose() {
    myCustomPrintStatement('VideoPreloadService: Nettoyage des ressources vidéo...');
    
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    
    _controllers.clear();
    _isLoaded.clear();
    
    myCustomPrintStatement('VideoPreloadService: Ressources nettoyées');
  }

  /// Obtient le statut de préchargement
  Map<String, bool> getLoadingStatus() {
    return Map.from(_isLoaded);
  }
}