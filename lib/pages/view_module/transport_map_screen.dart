import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'package:rider_ride_hailing_app/services/places_autocomplete_web.dart';
import 'package:rider_ride_hailing_app/services/osrm_service.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen_web.dart';

/// Page affichant les lignes de transport d'Antananarivo sur une carte
/// Style inspiré de Île-de-France Mobilités
class TransportMapScreen extends StatefulWidget {
  /// Mode initial: 0 = Itinéraire, 1 = Lignes
  final int initialMode;

  /// Adresse et position de départ pré-remplies (optionnel)
  final String? originAddress;
  final LatLng? originPosition;

  /// Adresse et position de destination pré-remplies (optionnel)
  final String? destinationAddress;
  final LatLng? destinationPosition;

  const TransportMapScreen({
    super.key,
    this.initialMode = 0,
    this.originAddress,
    this.originPosition,
    this.destinationAddress,
    this.destinationPosition,
  });

  @override
  State<TransportMapScreen> createState() => _TransportMapScreenState();
}

class _TransportMapScreenState extends State<TransportMapScreen> {
  GoogleMapController? _mapController;

  // Position par défaut: Antananarivo, Madagascar (centre ville)
  static const LatLng _defaultPosition = LatLng(-18.8792, 47.5079);

  // Style de carte personnalisé (même que home_screen_web)
  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#A6B5DE"}]},{"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":3}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#BCC5E8"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.local","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road","elementType":"labels","stylers":[{"visibility":"on"}]},{"featureType":"road.highway","elementType":"labels.icon","stylers":[{"visibility":"on"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#ADD4F5"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"poi","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"on"},{"color":"#B0B0B0"}]},{"featureType":"poi.business","elementType":"labels.text","stylers":[{"visibility":"off"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"transit.station.bus","elementType":"labels.text","stylers":[{"visibility":"on"},{"color":"#000000"}]},{"featureType":"transit.station.bus","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"transit.station.bus","elementType":"labels.icon","stylers":[{"visibility":"on"},{"color":"#4A4A4A"}]}]';

  // Données de lignes
  List<TransportLineGroup> _lineGroups = [];
  bool _isLoading = true;

  // Recherche
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchSuggestions = [];
  Timer? _searchDebounceTimer;
  bool _isSearching = false;

  // Géolocalisation
  LatLng? _userPosition;
  bool _isLocating = false;

  // Filtres par type de transport
  final Map<TransportType, bool> _typeFilters = {
    TransportType.bus: true,
    TransportType.urbanTrain: true,
    TransportType.telepherique: true,
  };

  // Lignes sélectionnées pour affichage
  final Set<String> _visibleLines = {};

  // Arrêt sélectionné pour le panneau de détails
  TransportStop? _selectedStop;
  TransportLine? _selectedStopLine;

  // Éléments de carte
  Set<Polyline> _polylines = {};
  Set<Marker> _busStopMarkers = {};
  Set<Marker> _railStopMarkers = {}; // Train et Téléphérique

  // Niveau de zoom actuel (pour masquer les arrêts quand dézoomé)
  double _currentZoom = 13.0;
  static const double _minZoomForBusStops = 14.5; // Bus: arrêts visibles seulement très zoomé
  static const double _minZoomForRailStops = 13.0; // Train/Téléphérique: arrêts visibles plus tôt

  // Cache des icônes personnalisées
  final Map<String, BitmapDescriptor> _markerIconCache = {};

  // Mode du panneau de gauche: 0 = Itinéraire, 1 = Lignes
  int _leftPanelMode = 0;

  // Itinéraire
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  List<Map<String, dynamic>> _originSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];
  Timer? _originDebounceTimer;
  Timer? _destinationDebounceTimer;
  LatLng? _originPosition;
  LatLng? _destinationPosition;
  TransportRoute? _currentRoute;
  bool _isCalculatingRoute = false;
  Set<Polyline> _routePolylines = {};
  Set<Marker> _routeMarkers = {};

  // Durées réelles de marche (OSRM) par étape
  Map<int, int> _actualWalkingDurations = {};
  // Durée totale réelle (avec OSRM)
  int _actualTotalDuration = 0;
  // Durée marche vers premier arrêt
  int _walkToStartDuration = 0;
  // Durée marche depuis dernier arrêt
  int _walkToEndDuration = 0;

  @override
  void initState() {
    super.initState();
    _loadTransportLines();
    _initializeFromParams();
  }

  /// Initialise les champs depuis les paramètres passés au widget
  void _initializeFromParams() {
    // Définir le mode initial
    _leftPanelMode = widget.initialMode;

    // Pré-remplir l'origine si fournie
    if (widget.originAddress != null) {
      _originController.text = widget.originAddress!;
    }
    if (widget.originPosition != null) {
      _originPosition = widget.originPosition;
    }

    // Pré-remplir la destination si fournie
    if (widget.destinationAddress != null) {
      _destinationController.text = widget.destinationAddress!;
    }
    if (widget.destinationPosition != null) {
      _destinationPosition = widget.destinationPosition;
    }

    // Si les deux positions sont fournies, calculer l'itinéraire automatiquement
    if (_originPosition != null && _destinationPosition != null) {
      // Attendre que le widget soit construit avant de calculer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateRoute();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _originDebounceTimer?.cancel();
    _destinationDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTransportLines() async {
    try {
      final lines = await TransportLinesService.instance.loadAllLines();
      if (mounted) {
        setState(() {
          _lineGroups = lines;
          _isLoading = false;
          // Afficher toutes les lignes par défaut
          for (final group in lines) {
            _visibleLines.add(group.lineNumber);
          }
        });
        // Mettre à jour la carte avec toutes les lignes
        _updateMapDisplay();
      }
      myCustomPrintStatement('${_lineGroups.length} groupes de lignes chargés');
    } catch (e) {
      myCustomPrintStatement('Erreur chargement lignes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Recherche avec debounce
  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();

    if (query.length < 2) {
      setState(() {
        _searchSuggestions = [];
      });
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      // Chercher dans les arrêts d'abord
      final stopResults = _searchInStops(query);

      // Puis chercher via Google Places
      final placeResults = await PlacesAutocompleteWeb.getPlacePredictions(query);

      if (mounted) {
        setState(() {
          _searchSuggestions = [
            ...stopResults.map((s) => {'type': 'stop', 'data': s}),
            ...placeResults.map((p) => {'type': 'place', ...p}),
          ];
        });
      }
    });
  }

  /// Recherche dans les arrêts locaux
  List<Map<String, dynamic>> _searchInStops(String query) {
    final results = <Map<String, dynamic>>[];
    final queryLower = query.toLowerCase();

    for (final group in _lineGroups) {
      for (final line in group.lines) {
        for (final stop in line.stops) {
          if (stop.name.toLowerCase().contains(queryLower)) {
            results.add({
              'stop': stop,
              'line': line,
              'group': group,
            });
            if (results.length >= 5) return results;
          }
        }
      }
    }
    return results;
  }

  /// Sélection d'une suggestion de recherche
  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    setState(() {
      _searchSuggestions = [];
      _isSearching = true;
    });

    if (result['type'] == 'stop') {
      final stop = result['data']['stop'] as TransportStop;
      final line = result['data']['line'] as TransportLine;
      final group = result['data']['group'] as TransportLineGroup;

      _searchController.text = stop.name;

      // S'assurer que la ligne est visible
      _visibleLines.add(group.lineNumber);

      // Sélectionner l'arrêt
      setState(() {
        _selectedStop = stop;
        _selectedStopLine = line;
      });

      // Centrer la carte sur l'arrêt
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(stop.position, 15),
      );

      _updateMapDisplay();
    } else {
      // C'est un lieu Google Places
      _searchController.text = result['description'] ?? '';

      try {
        final details = await PlacesAutocompleteWeb.getPlaceDetails(result['place_id']);
        if (details != null && details['result']?['geometry']?['location'] != null) {
          final location = details['result']['geometry']['location'];
          final position = LatLng(location['lat'], location['lng']);

          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(position, 15),
          );
        }
      } catch (e) {
        debugPrint('Error getting place details: $e');
      }
    }

    setState(() {
      _isSearching = false;
    });
    _searchFocusNode.unfocus();
  }

  /// Géolocalisation de l'utilisateur
  Future<void> _locateUser() async {
    setState(() {
      _isLocating = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _userPosition = userLatLng;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userLatLng, 15),
      );

      _updateMapDisplay();
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de localisation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  /// Toggle filtre par type
  void _toggleTypeFilter(TransportType type) {
    setState(() {
      _typeFilters[type] = !_typeFilters[type]!;

      // Mettre à jour les lignes visibles
      for (final group in _lineGroups) {
        if (group.transportType == type) {
          if (_typeFilters[type]!) {
            _visibleLines.add(group.lineNumber);
          } else {
            _visibleLines.remove(group.lineNumber);
          }
        }
      }
    });
    _updateMapDisplay();
  }

  /// Toggle visibilité d'une ligne
  void _toggleLineVisibility(String lineNumber) {
    setState(() {
      if (_visibleLines.contains(lineNumber)) {
        _visibleLines.remove(lineNumber);
      } else {
        _visibleLines.add(lineNumber);
      }
    });
    _updateMapDisplay();
  }

  /// Met à jour l'affichage de la carte
  Future<void> _updateMapDisplay() async {
    final Set<Polyline> newPolylines = {};
    final Set<Marker> newBusMarkers = {};
    final Set<Marker> newRailMarkers = {};

    // Ajouter le marker de position utilisateur (dans rail pour qu'il soit toujours visible)
    if (_userPosition != null) {
      newRailMarkers.add(
        Marker(
          markerId: const MarkerId('user_position'),
          position: _userPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: const InfoWindow(title: 'Ma position'),
          zIndex: 100,
        ),
      );
    }

    // Parcourir les lignes visibles
    for (final group in _lineGroups) {
      if (!_visibleLines.contains(group.lineNumber)) continue;
      if (!_typeFilters[group.transportType]!) continue;

      final color = Color(TransportLineColors.getLineColor(group.lineNumber, group.transportType));

      // Largeur selon le type de transport (train et téléphérique plus gros)
      final bool isRailType = group.transportType == TransportType.urbanTrain ||
          group.transportType == TransportType.telepherique;
      final int lineWidth = isRailType ? 6 : 5;

      // Style IDFM: ligne colorée simple
      if (group.aller != null) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('${group.lineNumber}_aller'),
            points: group.aller!.coordinates,
            color: color,
            width: lineWidth,
            patterns: [],
          ),
        );

        // Ajouter les markers des arrêts (cercles avec numéro)
        for (final stop in group.aller!.stops) {
          final markerId = '${group.lineNumber}_${stop.stopId}';
          final icon = await _getCircleMarkerIcon(group.lineNumber, color);

          final marker = Marker(
            markerId: MarkerId(markerId),
            position: stop.position,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(
              title: stop.name,
              snippet: 'Ligne ${group.displayName}',
            ),
            onTap: () {
              setState(() {
                _selectedStop = stop;
                _selectedStopLine = group.aller;
              });
            },
          );

          // Séparer bus et rail
          if (isRailType) {
            newRailMarkers.add(marker);
          } else {
            newBusMarkers.add(marker);
          }
        }
      }

      if (group.retour != null) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('${group.lineNumber}_retour'),
            points: group.retour!.coordinates,
            color: color.withValues(alpha: 0.6),
            width: lineWidth - 1,
            patterns: [],
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _polylines = newPolylines;
        _busStopMarkers = newBusMarkers;
        _railStopMarkers = newRailMarkers;
      });
    }
  }

  /// Crée une icône de marker personnalisée pour un arrêt (style IDFM)
  Future<BitmapDescriptor> _getStopMarkerIcon(String lineNumber, Color color) async {
    final cacheKey = '${lineNumber}_${color.value}';

    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    try {
      // Créer un petit marker rond style IDFM
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 24.0;

      // Ombre légère
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(const Offset(size / 2, size / 2 + 1), size / 2 - 1, shadowPaint);

      // Cercle de fond blanc
      final whiteBgPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, whiteBgPaint);

      // Cercle coloré intérieur
      final colorPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, colorPaint);

      // Dessiner le contenu selon le type
      final isTrain = lineNumber.contains('TRAIN') || lineNumber.contains('TCE');
      final isCable = lineNumber.contains('TELEPHERIQUE');

      if (isTrain) {
        _drawTrainIcon(canvas, size);
      } else if (isCable) {
        _drawCableCarIcon(canvas, size);
      } else {
        // Bus: afficher le numéro
        final shortNumber = lineNumber.replaceAll(RegExp(r'[^0-9]'), '');
        final textPainter = TextPainter(
          text: TextSpan(
            text: shortNumber,
            style: TextStyle(
              color: Colors.white,
              fontSize: shortNumber.length > 2 ? 8 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            (size - textPainter.width) / 2,
            (size - textPainter.height) / 2,
          ),
        );
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final icon = BitmapDescriptor.bytes(bytes);
      _markerIconCache[cacheKey] = icon;

      return icon;
    } catch (e) {
      debugPrint('Error creating marker icon: $e');
      return BitmapDescriptor.defaultMarkerWithHue(
        _getHueFromColor(color),
      );
    }
  }

  /// Crée un petit point blanc avec bordure colorée pour les arrêts intermédiaires
  Future<BitmapDescriptor> _getWhiteDotMarkerIcon(Color borderColor) async {
    final cacheKey = 'white_dot_${borderColor.value}';

    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 16.0;

      // Ombre légère
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(const Offset(size / 2, size / 2 + 0.5), size / 2 - 1, shadowPaint);

      // Bordure colorée
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, borderPaint);

      // Centre blanc
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, whitePaint);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final icon = BitmapDescriptor.bytes(bytes);
      _markerIconCache[cacheKey] = icon;

      return icon;
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  /// Crée un cercle coloré avec numéro de ligne (style IDFM)
  Future<BitmapDescriptor> _getCircleMarkerIcon(String lineNumber, Color color) async {
    final cacheKey = 'circle_${lineNumber}_${color.value}';

    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 22.0;
      const center = Offset(size / 2, size / 2);

      // Contour blanc
      final whiteBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, size / 2, whiteBorderPaint);

      // Cercle coloré principal
      final colorPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, size / 2 - 1.5, colorPaint);

      // Dessiner le numéro ou icône
      final isTrain = lineNumber.contains('TRAIN') || lineNumber.contains('TCE');
      final isCable = lineNumber.contains('TELEPHERIQUE');

      if (isTrain) {
        // Icône train simplifiée
        final iconPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        // Rectangle pour le train
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 8, height: 6),
            const Radius.circular(1),
          ),
          iconPaint,
        );
      } else if (isCable) {
        // Icône téléphérique simplifiée
        final iconPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        // Ligne horizontale
        canvas.drawLine(
          Offset(center.dx - 5, center.dy - 2),
          Offset(center.dx + 5, center.dy - 2),
          iconPaint,
        );
        // Cabine
        final cabinPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(center.dx, center.dy + 2), width: 6, height: 5),
            const Radius.circular(1),
          ),
          cabinPaint,
        );
      } else {
        // Bus: afficher le numéro
        final shortNumber = lineNumber.replaceAll(RegExp(r'^0+'), ''); // Enlever les zéros initiaux
        final displayNumber = shortNumber.isEmpty ? lineNumber : shortNumber;
        final textPainter = TextPainter(
          text: TextSpan(
            text: displayNumber,
            style: TextStyle(
              color: Colors.white,
              fontSize: displayNumber.length > 2 ? 7 : 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            (size - textPainter.width) / 2,
            (size - textPainter.height) / 2,
          ),
        );
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final icon = BitmapDescriptor.bytes(bytes);
      _markerIconCache[cacheKey] = icon;

      return icon;
    } catch (e) {
      debugPrint('Error creating circle marker icon: $e');
      return BitmapDescriptor.defaultMarkerWithHue(_getHueFromColor(color));
    }
  }

  /// Crée le marker d'origine (cercle avec point - style cible)
  Future<BitmapDescriptor> _getOriginMarkerIcon() async {
    const cacheKey = 'origin_marker';

    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 28.0;

      // Ombre
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(const Offset(size / 2, size / 2 + 1), size / 2 - 2, shadowPaint);

      // Cercle extérieur (bordure noire)
      final borderPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3, borderPaint);

      // Cercle intérieur blanc
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 5, whitePaint);

      // Point central noir
      final dotPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), 4, dotPaint);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final icon = BitmapDescriptor.bytes(bytes);
      _markerIconCache[cacheKey] = icon;

      return icon;
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  /// Crée le marker de destination (cercle avec drapeau)
  Future<BitmapDescriptor> _getDestinationMarkerIcon() async {
    const cacheKey = 'destination_marker';

    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 32.0;

      // Ombre
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(const Offset(size / 2, size / 2 + 1), 12, shadowPaint);

      // Cercle rouge
      final redPaint = Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), 12, redPaint);

      // Bordure rouge foncé
      final borderPaint = Paint()
        ..color = const Color(0xFFB71C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(const Offset(size / 2, size / 2), 12, borderPaint);

      // Icône de destination (carré blanc ou point)
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), 5, whitePaint);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final icon = BitmapDescriptor.bytes(bytes);
      _markerIconCache[cacheKey] = icon;

      return icon;
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  /// Dessine une icône de train simplifiée
  void _drawTrainIcon(Canvas canvas, double size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final center = size / 2;

    // Corps du train (rectangle arrondi)
    final trainRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center, center), width: 10, height: 8),
      const Radius.circular(2),
    );
    canvas.drawRRect(trainRect, paint);

    // Fenêtre du train
    final windowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(center, center - 1), width: 6, height: 3),
      windowPaint,
    );

    // Roues (deux petits cercles)
    canvas.drawCircle(Offset(center - 3, center + 5), 1.5, paint);
    canvas.drawCircle(Offset(center + 3, center + 5), 1.5, paint);

    // Rails
    canvas.drawLine(
      Offset(center - 6, center + 6.5),
      Offset(center + 6, center + 6.5),
      strokePaint,
    );
  }

  /// Dessine une icône de téléphérique simplifiée
  void _drawCableCarIcon(Canvas canvas, double size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final center = size / 2;

    // Câble (ligne diagonale en haut)
    canvas.drawLine(
      Offset(center - 7, center - 5),
      Offset(center + 7, center - 5),
      strokePaint,
    );

    // Attache au câble
    canvas.drawLine(
      Offset(center, center - 5),
      Offset(center, center - 2),
      strokePaint,
    );

    // Cabine (rectangle arrondi)
    final cabinRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center, center + 3), width: 10, height: 8),
      const Radius.circular(2),
    );
    canvas.drawRRect(cabinRect, paint);

    // Fenêtre de la cabine
    final windowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(center, center + 2), width: 6, height: 4),
      windowPaint,
    );
  }

  /// Raccourcit le numéro de ligne pour l'affichage
  String _getShortLineNumber(String lineNumber) {
    if (lineNumber.contains('TRAIN') || lineNumber.contains('TCE')) {
      return 'TCE';
    }
    if (lineNumber.contains('TELEPHERIQUE')) {
      return 'T';
    }
    return lineNumber;
  }

  /// Convertit une couleur en hue pour BitmapDescriptor
  double _getHueFromColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

  /// Calcule la distance entre deux points
  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(from.latitude)) *
            math.cos(_toRadians(to.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  /// Calcule le prix total d'un itinéraire
  /// Bus/Taxi-be: 600 Ar par trajet
  /// Train TCE: 3000 Ar
  /// Téléphérique: 3000 Ar
  int _calculateRoutePrice(TransportRoute route) {
    int totalPrice = 0;

    for (final step in route.steps) {
      if (step.isWalking) continue;

      switch (step.transportType) {
        case TransportType.bus:
          totalPrice += 600;
        case TransportType.urbanTrain:
          totalPrice += 3000;
        case TransportType.telepherique:
          totalPrice += 3000;
      }
    }

    return totalPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          // Carte Google Maps
          _buildMap(),

          // Header avec recherche
          _buildHeader(),

          // Panneau latéral gauche avec filtres
          _buildLeftPanel(),

          // Panneau de détails de l'arrêt (droite)
          if (_selectedStop != null) _buildStopDetailPanel(),
        ],
      ),
    );
  }

  /// Carte Google Maps
  Widget _buildMap() {
    // Si un itinéraire est affiché, ne montrer que l'itinéraire
    // Sinon, montrer les lignes de transport
    final Set<Polyline> allPolylines;
    Set<Marker> allMarkers;

    if (_currentRoute != null || _routePolylines.isNotEmpty) {
      // Mode itinéraire: seulement les segments de route (toujours affichés)
      allPolylines = _routePolylines;
      allMarkers = _routeMarkers;
    } else {
      // Mode exploration: combiner les markers selon le niveau de zoom
      allPolylines = _polylines;

      // Rail (train/téléphérique): visible à partir de zoom 12
      // Bus: visible à partir de zoom 14.5
      final showRailStops = _currentZoom >= _minZoomForRailStops;
      final showBusStops = _currentZoom >= _minZoomForBusStops;

      allMarkers = <Marker>{};
      if (showRailStops) {
        allMarkers.addAll(_railStopMarkers);
      }
      if (showBusStops) {
        allMarkers.addAll(_busStopMarkers);
      }
    }

    return Positioned.fill(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _defaultPosition,
          zoom: 13,
        ),
        style: _mapStyle,
        polylines: allPolylines,
        markers: allMarkers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
        onCameraMove: (position) {
          // Mettre à jour le niveau de zoom et reconstruire si on passe un seuil
          final oldShowRail = _currentZoom >= _minZoomForRailStops;
          final oldShowBus = _currentZoom >= _minZoomForBusStops;
          final newShowRail = position.zoom >= _minZoomForRailStops;
          final newShowBus = position.zoom >= _minZoomForBusStops;

          _currentZoom = position.zoom;

          if (oldShowRail != newShowRail || oldShowBus != newShowBus) {
            setState(() {});
          }
        },
        onTap: (_) {
          // Fermer le panneau de détails et les suggestions
          setState(() {
            _selectedStop = null;
            _selectedStopLine = null;
            _searchSuggestions = [];
            _originSuggestions = [];
            _destinationSuggestions = [];
          });
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        mapType: MapType.normal,
      ),
    );
  }

  /// Header avec logo, navigation et recherche
  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Logo Misy
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _navigateToHome(),
                child: Image.asset(
                  MyImagesUrl.misyLogoRose,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(width: 32),

            // Onglets de navigation
            _buildNavTab('Accueil', Icons.home_outlined, false, _navigateToHome),
            _buildNavTab('Carte des transports', Icons.map_outlined, true, null),

            const SizedBox(width: 32),

            // Barre de recherche
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildSearchBar(),
              ),
            ),

            const SizedBox(width: 16),

            // Bouton Ma position
            _buildLocationButton(),
          ],
        ),
      ),
    );
  }

  /// Barre de recherche
  Widget _buildSearchBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.search, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un arrêt, une adresse...',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchSuggestions = [];
                    });
                  },
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),

        // Suggestions de recherche
        if (_searchSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchSuggestions.length,
              itemBuilder: (context, index) {
                final item = _searchSuggestions[index];
                return _buildSearchSuggestionItem(item);
              },
            ),
          ),
      ],
    );
  }

  /// Élément de suggestion de recherche
  Widget _buildSearchSuggestionItem(Map<String, dynamic> item) {
    final isStop = item['type'] == 'stop';

    return InkWell(
      onTap: () => _selectSearchResult(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isStop
                    ? Color(TransportLineColors.getLineColor(
                        (item['data']['group'] as TransportLineGroup).lineNumber,
                        (item['data']['group'] as TransportLineGroup).transportType))
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isStop ? Icons.directions_bus : Icons.location_on,
                color: isStop ? Colors.white : Colors.grey.shade600,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStop
                        ? (item['data']['stop'] as TransportStop).name
                        : item['description'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isStop)
                    Text(
                      'Ligne ${(item['data']['group'] as TransportLineGroup).displayName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bouton de géolocalisation
  Widget _buildLocationButton() {
    return Tooltip(
      message: 'Ma position',
      child: InkWell(
        onTap: _isLocating ? null : _locateUser,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _userPosition != null ? MyColors.primaryColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _isLocating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.my_location,
                  color: _userPosition != null ? Colors.white : Colors.grey.shade700,
                  size: 20,
                ),
        ),
      ),
    );
  }

  /// Onglet de navigation
  Widget _buildNavTab(String label, IconData icon, bool isActive, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 18,
          color: isActive ? MyColors.primaryColor : Colors.black54,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? MyColors.primaryColor : Colors.black54,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? MyColors.primaryColor.withOpacity(0.1) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  /// Panneau latéral gauche avec onglets Lignes/Itinéraire
  Widget _buildLeftPanel() {
    return Positioned(
      top: 80,
      left: 16,
      bottom: 16,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Onglets Lignes / Itinéraire
            _buildPanelTabs(),

            // Contenu selon l'onglet sélectionné
            Expanded(
              child: _leftPanelMode == 0
                  ? _buildItineraryPanel()
                  : _buildLinesPanel(),
            ),
          ],
        ),
      ),
    );
  }

  /// Onglets du panneau de gauche
  Widget _buildPanelTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPanelTab(
              icon: Icons.directions,
              label: 'Itinéraire',
              isSelected: _leftPanelMode == 0,
              onTap: () => setState(() => _leftPanelMode = 0),
            ),
          ),
          Expanded(
            child: _buildPanelTab(
              icon: Icons.map_outlined,
              label: 'Lignes',
              isSelected: _leftPanelMode == 1,
              onTap: () => setState(() {
                _leftPanelMode = 1;
                _clearRoute();
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? MyColors.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? MyColors.primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? MyColors.primaryColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Panneau des lignes de transport
  Widget _buildLinesPanel() {
    return Column(
      children: [
        // Filtres par type
        _buildTypeFilters(),

        const Divider(height: 1),

        // Liste des lignes
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildLinesList(),
        ),

        // Bouton zoom
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _zoomToFitAllLines,
                  icon: const Icon(Icons.zoom_out_map, size: 18),
                  label: const Text('Voir toutes les lignes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MyColors.primaryColor,
                    side: BorderSide(color: MyColors.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Panneau de calcul d'itinéraire
  Widget _buildItineraryPanel() {
    return Column(
      children: [
        // Formulaire origine/destination
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Champ Départ
              _buildItineraryField(
                controller: _originController,
                focusNode: _originFocusNode,
                label: 'DÉPART',
                hint: 'Gare, station, arrêt ou lieu',
                icon: Icons.trip_origin,
                iconColor: Colors.green,
                suggestions: _originSuggestions,
                onChanged: _onOriginChanged,
                onSuggestionSelected: _selectOrigin,
                onUseMyLocation: _useMyLocationAsOrigin,
              ),

              const SizedBox(height: 8),

              // Bouton inverser
              Center(
                child: IconButton(
                  onPressed: _swapOriginDestination,
                  icon: Icon(Icons.swap_vert, color: Colors.grey.shade600),
                  tooltip: 'Inverser',
                ),
              ),

              const SizedBox(height: 8),

              // Champ Arrivée
              _buildItineraryField(
                controller: _destinationController,
                focusNode: _destinationFocusNode,
                label: 'ARRIVÉE',
                hint: 'Gare, station, arrêt ou lieu',
                icon: Icons.location_on,
                iconColor: MyColors.primaryColor,
                suggestions: _destinationSuggestions,
                onChanged: _onDestinationChanged,
                onSuggestionSelected: _selectDestination,
              ),

              const SizedBox(height: 16),

              // Bouton Rechercher
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_originPosition != null && _destinationPosition != null && !_isCalculatingRoute)
                      ? _calculateRoute
                      : null,
                  icon: _isCalculatingRoute
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isCalculatingRoute ? 'Recherche...' : 'Rechercher un itinéraire'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Résultats de l'itinéraire
        Expanded(
          child: _currentRoute != null
              ? _buildRouteResults()
              : _buildItineraryPlaceholder(),
        ),
      ],
    );
  }

  /// Champ de saisie pour l'itinéraire
  Widget _buildItineraryField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required List<Map<String, dynamic>> suggestions,
    required Function(String) onChanged,
    required Function(Map<String, dynamic>) onSuggestionSelected,
    VoidCallback? onUseMyLocation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (onUseMyLocation != null)
                IconButton(
                  onPressed: onUseMyLocation,
                  icon: Icon(Icons.my_location, size: 18, color: Colors.grey.shade600),
                  tooltip: 'Ma position',
                ),
              if (controller.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    controller.clear();
                    if (label == 'DÉPART') {
                      setState(() {
                        _originPosition = null;
                        _originSuggestions = [];
                      });
                    } else {
                      setState(() {
                        _destinationPosition = null;
                        _destinationSuggestions = [];
                      });
                    }
                  },
                  icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // Suggestions
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final item = suggestions[index];
                return _buildSuggestionItem(item, onSuggestionSelected);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> item, Function(Map<String, dynamic>) onSelect) {
    final isStop = item['type'] == 'stop';

    return InkWell(
      onTap: () => onSelect(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isStop ? Icons.directions_bus : Icons.location_on,
              size: 18,
              color: isStop ? MyColors.primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isStop
                    ? (item['data']['stop'] as TransportStop).name
                    : item['description'] ?? '',
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Placeholder quand aucun itinéraire n'est calculé
  Widget _buildItineraryPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Recherchez un itinéraire',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entrez un lieu de départ et une destination pour calculer votre trajet en transport en commun.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Affichage des résultats de l'itinéraire
  Widget _buildRouteResults() {
    if (_currentRoute == null) return const SizedBox();

    // Calculer le prix total
    final totalPrice = _calculateRoutePrice(_currentRoute!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé durée et prix
          Row(
            children: [
              // Durée
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MyColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: MyColors.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Durée',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_actualTotalDuration > 0 ? _actualTotalDuration : _currentRoute!.totalDurationMinutes} min',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: MyColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Prix
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Prix',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalPrice Ar',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Info correspondances et distance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sync_alt, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${_currentRoute!.numberOfTransfers} correspondance${_currentRoute!.numberOfTransfers > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 16),
                Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${(_currentRoute!.totalDistance).toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Étapes
          Text(
            'Détail du trajet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),

          // Marche vers le premier arrêt (si applicable)
          if (_walkToStartDuration > 0)
            _buildWalkToStartStep(),

          ..._currentRoute!.steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isFirst = index == 0 && _walkToStartDuration == 0;
            final isLast = index == _currentRoute!.steps.length - 1 && _walkToEndDuration == 0;
            return _buildRouteStep(step, index, isFirst, isLast);
          }),

          // Marche vers la destination (si applicable)
          if (_walkToEndDuration > 0)
            _buildWalkToEndStep(),

          const SizedBox(height: 16),

          // Bouton effacer
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearRoute,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Effacer l\'itinéraire'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Affichage d'une étape de l'itinéraire
  Widget _buildRouteStep(RouteStep step, int stepIndex, bool isFirst, bool isLast) {
    final color = step.isWalking
        ? Colors.grey.shade600
        : Color(TransportLineColors.getLineColor(step.lineNumber, step.transportType));

    // Utiliser la durée OSRM réelle pour les étapes de marche si disponible
    final actualDuration = step.isWalking && _actualWalkingDurations.containsKey(stepIndex)
        ? _actualWalkingDurations[stepIndex]!
        : step.durationMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicateur visuel
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  step.isWalking
                      ? Icons.directions_walk
                      : _getTransportIcon(step.transportType),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: color.withValues(alpha: 0.3),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Détails de l'étape
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!step.isWalking)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          step.lineName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (!step.isWalking) const SizedBox(width: 8),
                    Text(
                      step.isWalking ? 'Marche' : 'Direction ${step.direction}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.isWalking
                      ? 'De ${step.startStop.name} à ${step.endStop.name}'
                      : '${step.startStop.name} → ${step.endStop.name}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$actualDuration min${step.isWalking ? '' : ' • ${step.numberOfStops} arrêt${step.numberOfStops > 1 ? 's' : ''}'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Affichage de la marche vers le premier arrêt
  Widget _buildWalkToStartStep() {
    final firstStep = _currentRoute!.steps.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.directions_walk,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.shade300,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marche',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vers ${firstStep.startStop.name}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_walkToStartDuration min',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Affichage de la marche vers la destination
  Widget _buildWalkToEndStep() {
    final lastStep = _currentRoute!.steps.last;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.directions_walk,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marche',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'De ${lastStep.endStop.name} vers destination',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_walkToEndDuration min',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Filtres par type de transport
  Widget _buildTypeFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modes de transport',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeFilterChip(TransportType.bus, Icons.directions_bus, 'Bus'),
              _buildTypeFilterChip(TransportType.urbanTrain, Icons.train, 'Train'),
              _buildTypeFilterChip(TransportType.telepherique, Icons.airline_seat_legroom_extra, 'Téléphérique'),
            ],
          ),
        ],
      ),
    );
  }

  /// Chip de filtre par type
  Widget _buildTypeFilterChip(TransportType type, IconData icon, String label) {
    final isActive = _typeFilters[type]!;
    final color = Color(type.colorValue);

    return FilterChip(
      selected: isActive,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isActive ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      labelStyle: TextStyle(
        color: isActive ? Colors.white : color,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      side: BorderSide(color: color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => _toggleTypeFilter(type),
    );
  }

  /// Liste des lignes
  Widget _buildLinesList() {
    final filteredLines = _lineGroups
        .where((g) => _typeFilters[g.transportType]!)
        .toList();

    if (filteredLines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Aucune ligne',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredLines.length,
      itemBuilder: (context, index) {
        final group = filteredLines[index];
        return _buildLineItem(group);
      },
    );
  }

  /// Élément de ligne dans la liste
  Widget _buildLineItem(TransportLineGroup group) {
    final isVisible = _visibleLines.contains(group.lineNumber);
    final color = Color(TransportLineColors.getLineColor(group.lineNumber, group.transportType));
    final numStops = group.aller?.numStops ?? group.retour?.numStops ?? 0;

    return InkWell(
      onTap: () => _toggleLineVisibility(group.lineNumber),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isVisible ? color.withOpacity(0.08) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isVisible ? color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Badge de ligne
            Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                _getShortLineNumber(group.lineNumber),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$numStops arrêts',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle de visibilité
            Switch(
              value: isVisible,
              onChanged: (_) => _toggleLineVisibility(group.lineNumber),
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  /// Panneau de détails d'un arrêt
  Widget _buildStopDetailPanel() {
    if (_selectedStop == null || _selectedStopLine == null) return const SizedBox();

    final color = Color(TransportLineColors.getLineColor(_selectedStopLine!.lineNumber, _selectedStopLine!.transportType));
    final distance = _userPosition != null
        ? _calculateDistance(_userPosition!, _selectedStop!.position)
        : null;

    // Trouver les autres lignes passant par cet arrêt
    final connectingLines = <TransportLineGroup>[];
    for (final group in _lineGroups) {
      for (final line in group.lines) {
        for (final stop in line.stops) {
          if (stop.stopId == _selectedStop!.stopId &&
              group.lineNumber != _selectedStopLine!.lineNumber) {
            if (!connectingLines.contains(group)) {
              connectingLines.add(group);
            }
          }
        }
      }
    }

    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec couleur de la ligne
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.place, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedStop!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Ligne ${_selectedStopLine!.displayName}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _selectedStop = null;
                        _selectedStopLine = null;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Contenu
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Distance si disponible
                  if (distance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_walk, size: 18, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text(
                            distance < 1
                                ? '${(distance * 1000).toInt()} m'
                                : '${distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            ' de votre position',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),

                  // Correspondances
                  if (connectingLines.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Correspondances',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: connectingLines.map((g) {
                        final lineColor = Color(TransportLineColors.getLineColor(g.lineNumber, g.transportType));
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: lineColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getShortLineNumber(g.lineNumber),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Direction
                  const SizedBox(height: 16),
                  Text(
                    'Direction',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedStopLine!.isRetour
                              ? Icons.arrow_back
                              : Icons.arrow_forward,
                          color: color,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedStopLine!.direction.isNotEmpty
                                ? _selectedStopLine!.direction
                                : _selectedStopLine!.directionLabel,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Zoom pour voir toutes les lignes
  void _zoomToFitAllLines() {
    if (_polylines.isEmpty) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (final polyline in _polylines) {
      for (final point in polyline.points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  /// Retourne l'icône appropriée pour un type de transport
  IconData _getTransportIcon(TransportType type) {
    switch (type) {
      case TransportType.bus:
        return Icons.directions_bus;
      case TransportType.urbanTrain:
        return Icons.train;
      case TransportType.telepherique:
        return Icons.airline_seat_legroom_extra;
    }
  }

  /// Gestion du changement dans le champ origine
  void _onOriginChanged(String query) {
    _originDebounceTimer?.cancel();

    if (query.length < 2) {
      setState(() {
        _originSuggestions = [];
      });
      return;
    }

    _originDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      // Chercher dans les arrêts
      final stopResults = _searchInStops(query);

      // Puis chercher via Google Places
      final placeResults = await PlacesAutocompleteWeb.getPlacePredictions(query);

      if (mounted) {
        setState(() {
          _originSuggestions = [
            ...stopResults.map((s) => {'type': 'stop', 'data': s}),
            ...placeResults.map((p) => {'type': 'place', ...p}),
          ];
        });
      }
    });
  }

  /// Gestion du changement dans le champ destination
  void _onDestinationChanged(String query) {
    _destinationDebounceTimer?.cancel();

    if (query.length < 2) {
      setState(() {
        _destinationSuggestions = [];
      });
      return;
    }

    _destinationDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      // Chercher dans les arrêts
      final stopResults = _searchInStops(query);

      // Puis chercher via Google Places
      final placeResults = await PlacesAutocompleteWeb.getPlacePredictions(query);

      if (mounted) {
        setState(() {
          _destinationSuggestions = [
            ...stopResults.map((s) => {'type': 'stop', 'data': s}),
            ...placeResults.map((p) => {'type': 'place', ...p}),
          ];
        });
      }
    });
  }

  /// Sélection d'une origine
  Future<void> _selectOrigin(Map<String, dynamic> item) async {
    setState(() {
      _originSuggestions = [];
    });

    if (item['type'] == 'stop') {
      final stop = item['data']['stop'] as TransportStop;
      _originController.text = stop.name;
      setState(() {
        _originPosition = stop.position;
      });
      myCustomPrintStatement('Origin set to stop: ${stop.name} at ${stop.position}');
    } else {
      // C'est un lieu Google Places
      _originController.text = item['description'] ?? '';
      myCustomPrintStatement('Fetching place details for: ${item['place_id']}');
      try {
        final details = await PlacesAutocompleteWeb.getPlaceDetails(item['place_id']);
        myCustomPrintStatement('Place details response: $details');
        if (details != null && details['result']?['geometry']?['location'] != null) {
          final location = details['result']['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          setState(() {
            _originPosition = LatLng(lat, lng);
          });
          myCustomPrintStatement('Origin set to place: $lat, $lng');
        } else {
          myCustomPrintStatement('Could not get location from place details');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible de localiser cette adresse. Essayez un arrêt de transport.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        myCustomPrintStatement('Error getting place details: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
    _originFocusNode.unfocus();
  }

  /// Sélection d'une destination
  Future<void> _selectDestination(Map<String, dynamic> item) async {
    setState(() {
      _destinationSuggestions = [];
    });

    if (item['type'] == 'stop') {
      final stop = item['data']['stop'] as TransportStop;
      _destinationController.text = stop.name;
      setState(() {
        _destinationPosition = stop.position;
      });
      myCustomPrintStatement('Destination set to stop: ${stop.name} at ${stop.position}');
    } else {
      // C'est un lieu Google Places
      _destinationController.text = item['description'] ?? '';
      myCustomPrintStatement('Fetching place details for: ${item['place_id']}');
      try {
        final details = await PlacesAutocompleteWeb.getPlaceDetails(item['place_id']);
        myCustomPrintStatement('Place details response: $details');
        if (details != null && details['result']?['geometry']?['location'] != null) {
          final location = details['result']['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          setState(() {
            _destinationPosition = LatLng(lat, lng);
          });
          myCustomPrintStatement('Destination set to place: $lat, $lng');
        } else {
          myCustomPrintStatement('Could not get location from place details');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible de localiser cette adresse. Essayez un arrêt de transport.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        myCustomPrintStatement('Error getting place details: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
    _destinationFocusNode.unfocus();
  }

  /// Utiliser la position actuelle comme origine
  Future<void> _useMyLocationAsOrigin() async {
    setState(() {
      _isLocating = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        _originPosition = _userPosition;
        _originController.text = 'Ma position';
        _originSuggestions = [];
      });

      _updateMapDisplay();
    } catch (e) {
      myCustomPrintStatement('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de localisation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  /// Inverser origine et destination
  void _swapOriginDestination() {
    final tempText = _originController.text;
    final tempPosition = _originPosition;

    setState(() {
      _originController.text = _destinationController.text;
      _originPosition = _destinationPosition;
      _destinationController.text = tempText;
      _destinationPosition = tempPosition;
      _originSuggestions = [];
      _destinationSuggestions = [];
    });
  }

  /// Calculer l'itinéraire
  Future<void> _calculateRoute() async {
    if (_originPosition == null || _destinationPosition == null) return;

    // Sauvegarder la référence pour éviter les erreurs de contexte désactivé
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isCalculatingRoute = true;
      _currentRoute = null;
      _routePolylines = {};
      _routeMarkers = {};
    });

    try {
      myCustomPrintStatement('Calculating route from $_originPosition to $_destinationPosition');
      final route = await TransportLinesService.instance.findRoute(
        _originPosition!,
        _destinationPosition!,
      );

      if (route != null) {
        // Créer les polylines pour l'itinéraire
        final Set<Polyline> routePolylines = {};
        final Set<Marker> routeMarkers = {};
        final Map<int, int> walkingDurations = {};
        int totalDuration = 0;
        int walkToStartDuration = 0;
        int walkToEndDuration = 0;

        // Marker de départ (cercle avec point - style cible)
        final originIcon = await _getOriginMarkerIcon();
        routeMarkers.add(
          Marker(
            markerId: const MarkerId('route_origin'),
            position: _originPosition!,
            icon: originIcon,
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(title: 'Départ', snippet: _originController.text),
            zIndex: 200,
          ),
        );

        // Marker d'arrivée (cercle avec point rouge)
        final destinationIcon = await _getDestinationMarkerIcon();
        routeMarkers.add(
          Marker(
            markerId: const MarkerId('route_destination'),
            position: _destinationPosition!,
            icon: destinationIcon,
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(title: 'Arrivée', snippet: _destinationController.text),
            zIndex: 200,
          ),
        );

        // Ajouter marche du départ au premier arrêt si nécessaire
        if (route.steps.isNotEmpty) {
          final firstStop = route.steps.first.startStop;
          final distanceToFirstStop = _calculateDistance(_originPosition!, firstStop.position);

          if (distanceToFirstStop > 0.03) { // Plus de 30m
            final walkToStart = await OsrmService.getWalkingRoute(
              _originPosition!,
              firstStop.position,
            );

            if (walkToStart != null) {
              walkToStartDuration = walkToStart.durationMinutes;
              totalDuration += walkToStartDuration;
              routePolylines.add(
                Polyline(
                  polylineId: const PolylineId('walk_to_start'),
                  points: walkToStart.points,
                  color: Colors.grey.shade600,
                  width: 6,
                  patterns: [PatternItem.dot, PatternItem.gap(8)],
                  zIndex: 10,
                ),
              );
            }
          }
        }

        // Polylines et markers pour chaque étape
        for (int i = 0; i < route.steps.length; i++) {
          final step = route.steps[i];
          final color = step.isWalking
              ? Colors.grey.shade600
              : Color(TransportLineColors.getLineColor(step.lineNumber, step.transportType));

          List<LatLng> points;

          if (step.isWalking) {
            // Utiliser OSRM pour le trajet à pied
            final walkRoute = await OsrmService.getWalkingRoute(
              step.startStop.position,
              step.endStop.position,
            );

            if (walkRoute != null) {
              points = walkRoute.points;
              // Stocker la durée réelle OSRM
              walkingDurations[i] = walkRoute.durationMinutes;
              totalDuration += walkRoute.durationMinutes;
            } else {
              // Fallback: ligne directe avec estimation conservative
              points = [step.startStop.position, step.endStop.position];
              walkingDurations[i] = step.durationMinutes;
              totalDuration += step.durationMinutes;
            }

            routePolylines.add(
              Polyline(
                polylineId: PolylineId('route_step_$i'),
                points: points,
                color: color,
                width: 6,
                patterns: [PatternItem.dot, PatternItem.gap(8)],
                zIndex: 10,
              ),
            );
          } else {
            // Ajouter la durée du transport
            totalDuration += step.durationMinutes;
            // Pour le transport: utiliser les coordonnées réelles de la ligne
            points = await _getLineSegmentCoordinates(
              step.lineNumber,
              step.startStop,
              step.endStop,
              step.intermediateStops,
            );

            // Bordure (ligne plus large et plus foncée en dessous)
            final borderColor = HSLColor.fromColor(color)
                .withLightness((HSLColor.fromColor(color).lightness * 0.6).clamp(0.0, 1.0))
                .toColor();

            routePolylines.add(
              Polyline(
                polylineId: PolylineId('route_step_${i}_border'),
                points: points,
                color: borderColor,
                width: 14,
                patterns: [],
                zIndex: 9,
              ),
            );

            // Ligne principale (colorée)
            routePolylines.add(
              Polyline(
                polylineId: PolylineId('route_step_$i'),
                points: points,
                color: color,
                width: 8,
                patterns: [],
                zIndex: 10,
              ),
            );

            // Markers pour les arrêts de cette ligne
            // Logo de ligne uniquement pour entrée et sortie
            final lineIcon = await _getStopMarkerIcon(step.lineNumber, color);
            // Point blanc pour les arrêts intermédiaires
            final whiteIcon = await _getWhiteDotMarkerIcon(color);

            // Arrêt de départ (logo de ligne)
            routeMarkers.add(
              Marker(
                markerId: MarkerId('stop_${i}_start'),
                position: step.startStop.position,
                icon: lineIcon,
                anchor: const Offset(0.5, 0.5),
                infoWindow: InfoWindow(
                  title: step.startStop.name,
                  snippet: 'Monter - ${step.lineName}',
                ),
                zIndex: 100,
              ),
            );

            // Arrêts intermédiaires (points blancs)
            for (int j = 0; j < step.intermediateStops.length; j++) {
              final intermediateStop = step.intermediateStops[j];
              routeMarkers.add(
                Marker(
                  markerId: MarkerId('stop_${i}_$j'),
                  position: intermediateStop.position,
                  icon: whiteIcon,
                  anchor: const Offset(0.5, 0.5),
                  infoWindow: InfoWindow(
                    title: intermediateStop.name,
                    snippet: step.lineName,
                  ),
                  zIndex: 90,
                ),
              );
            }

            // Arrêt d'arrivée (logo de ligne)
            routeMarkers.add(
              Marker(
                markerId: MarkerId('stop_${i}_end'),
                position: step.endStop.position,
                icon: lineIcon,
                anchor: const Offset(0.5, 0.5),
                infoWindow: InfoWindow(
                  title: step.endStop.name,
                  snippet: 'Descendre - ${step.lineName}',
                ),
                zIndex: 100,
              ),
            );
          }

          // Markers pour les correspondances (changement de ligne)
          if (i > 0 && !step.isWalking) {
            routeMarkers.add(
              Marker(
                markerId: MarkerId('route_transfer_$i'),
                position: step.startStop.position,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                infoWindow: InfoWindow(
                  title: 'Correspondance',
                  snippet: step.startStop.name,
                ),
                zIndex: 150,
              ),
            );
          }
        }

        // Ajouter marche du dernier arrêt à la destination si nécessaire
        if (route.steps.isNotEmpty) {
          final lastStop = route.steps.last.endStop;
          final distanceFromLastStop = _calculateDistance(lastStop.position, _destinationPosition!);

          if (distanceFromLastStop > 0.05) { // Plus de 50m
            final walkToEnd = await OsrmService.getWalkingRoute(
              lastStop.position,
              _destinationPosition!,
            );

            if (walkToEnd != null) {
              walkToEndDuration = walkToEnd.durationMinutes;
              totalDuration += walkToEndDuration;
              routePolylines.add(
                Polyline(
                  polylineId: const PolylineId('walk_to_end'),
                  points: walkToEnd.points,
                  color: Colors.grey.shade600,
                  width: 6,
                  patterns: [PatternItem.dot, PatternItem.gap(8)],
                  zIndex: 10,
                ),
              );
            }
          }
        }

        setState(() {
          _currentRoute = route;
          _routePolylines = routePolylines;
          _routeMarkers = routeMarkers;
          _actualWalkingDurations = walkingDurations;
          _actualTotalDuration = totalDuration;
          _walkToStartDuration = walkToStartDuration;
          _walkToEndDuration = walkToEndDuration;
        });

        // Zoomer sur l'itinéraire
        _zoomToRoute();
      } else {
        myCustomPrintStatement('No route found');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Aucun itinéraire trouvé. Essayez des lieux plus proches du réseau de transport.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      myCustomPrintStatement('Error calculating route: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  /// Obtient les coordonnées du segment de ligne entre deux arrêts
  Future<List<LatLng>> _getLineSegmentCoordinates(
    String lineNumber,
    TransportNode startStop,
    TransportNode endStop,
    List<TransportNode> intermediateStops,
  ) async {
    // Trouver la ligne correspondante
    for (final group in _lineGroups) {
      if (group.lineNumber == lineNumber ||
          (lineNumber.contains('TRAIN') && group.lineNumber.contains('TRAIN')) ||
          (lineNumber.contains('TELEPHERIQUE') && group.lineNumber.contains('TELEPHERIQUE'))) {

        for (final line in group.lines) {
          // Trouver les indices des arrêts dans la ligne
          int startIndex = -1;
          int endIndex = -1;

          for (int i = 0; i < line.stops.length; i++) {
            final stopDistance = _calculateDistance(line.stops[i].position, startStop.position);
            if (stopDistance < 0.1) { // 100m de tolérance
              startIndex = i;
              break;
            }
          }

          for (int i = 0; i < line.stops.length; i++) {
            final stopDistance = _calculateDistance(line.stops[i].position, endStop.position);
            if (stopDistance < 0.1) {
              endIndex = i;
            }
          }

          if (startIndex != -1 && endIndex != -1) {
            // Extraire le segment de coordonnées de la polyline
            return _extractLineSegment(
              line.coordinates,
              line.stops[startIndex].position,
              line.stops[endIndex].position,
            );
          }
        }
      }
    }

    // Fallback: points directs entre les arrêts
    final points = <LatLng>[startStop.position];
    for (final stop in intermediateStops) {
      points.add(stop.position);
    }
    points.add(endStop.position);
    return points;
  }

  /// Extrait un segment de la polyline entre deux positions
  List<LatLng> _extractLineSegment(
    List<LatLng> lineCoordinates,
    LatLng startPosition,
    LatLng endPosition,
  ) {
    if (lineCoordinates.isEmpty) {
      return [startPosition, endPosition];
    }

    // Trouver l'index du point le plus proche du début
    int startIdx = 0;
    double minStartDist = double.infinity;
    for (int i = 0; i < lineCoordinates.length; i++) {
      final dist = _calculateDistance(lineCoordinates[i], startPosition);
      if (dist < minStartDist) {
        minStartDist = dist;
        startIdx = i;
      }
    }

    // Trouver l'index du point le plus proche de la fin
    int endIdx = lineCoordinates.length - 1;
    double minEndDist = double.infinity;
    for (int i = 0; i < lineCoordinates.length; i++) {
      final dist = _calculateDistance(lineCoordinates[i], endPosition);
      if (dist < minEndDist) {
        minEndDist = dist;
        endIdx = i;
      }
    }

    // S'assurer que startIdx < endIdx, sinon inverser
    if (startIdx > endIdx) {
      final temp = startIdx;
      startIdx = endIdx;
      endIdx = temp;
    }

    // Extraire le segment
    final segment = lineCoordinates.sublist(startIdx, endIdx + 1);

    // S'assurer qu'on a au moins 2 points
    if (segment.length < 2) {
      return [startPosition, endPosition];
    }

    return segment;
  }

  /// Zoomer pour voir tout l'itinéraire
  void _zoomToRoute() {
    if (_currentRoute == null) return;

    final allPoints = <LatLng>[];
    if (_originPosition != null) allPoints.add(_originPosition!);
    if (_destinationPosition != null) allPoints.add(_destinationPosition!);

    for (final step in _currentRoute!.steps) {
      allPoints.add(step.startStop.position);
      for (final stop in step.intermediateStops) {
        allPoints.add(stop.position);
      }
      allPoints.add(step.endStop.position);
    }

    if (allPoints.isEmpty) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  /// Effacer l'itinéraire
  void _clearRoute() {
    setState(() {
      _currentRoute = null;
      _routePolylines = {};
      _routeMarkers = {};
      _originController.clear();
      _destinationController.clear();
      _originPosition = null;
      _destinationPosition = null;
      _originSuggestions = [];
      _destinationSuggestions = [];
      // Réinitialiser les durées de marche OSRM
      _actualWalkingDurations = {};
      _actualTotalDuration = 0;
      _walkToStartDuration = 0;
      _walkToEndDuration = 0;
    });
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreenWeb()),
    );
  }
}
