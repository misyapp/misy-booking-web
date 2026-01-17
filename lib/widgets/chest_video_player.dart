import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';

class ChestVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onVideoEnd;
  final String chestTier;

  const ChestVideoPlayer({
    super.key,
    required this.controller,
    required this.onVideoEnd,
    required this.chestTier,
  });

  @override
  State<ChestVideoPlayer> createState() => _ChestVideoPlayerState();
}

class _ChestVideoPlayerState extends State<ChestVideoPlayer> {
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _initializeAndPlay();
  }

  Future<void> _initializeAndPlay() async {
    try {
      // Vérifier si le controller est initialisé
      if (!widget.controller.value.isInitialized) {
        myCustomPrintStatement('ChestVideoPlayer: Controller non initialisé pour ${widget.chestTier}');
        widget.onVideoEnd(); // Fallback immédiat
        return;
      }

      myCustomPrintStatement('ChestVideoPlayer: Démarrage vidéo ${widget.chestTier}');

      // Écouter la fin de la vidéo
      widget.controller.addListener(_videoListener);

      // Remettre à zéro et jouer
      await widget.controller.seekTo(Duration.zero);
      await widget.controller.play();
      
      setState(() {
        _hasStarted = true;
      });

    } catch (e) {
      myCustomPrintStatement('ChestVideoPlayer: Erreur démarrage vidéo ${widget.chestTier} - $e');
      widget.onVideoEnd(); // Fallback en cas d'erreur
    }
  }

  void _videoListener() {
    if (widget.controller.value.position >= widget.controller.value.duration) {
      myCustomPrintStatement('ChestVideoPlayer: Fin de vidéo ${widget.chestTier}');
      widget.onVideoEnd();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
          // Vidéo en plein écran
          if (_hasStarted && widget.controller.value.isInitialized)
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),
            ),

          // Fallback pendant l'initialisation
          if (!_hasStarted)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),


          ],
        ),
      ),
    );
  }
}