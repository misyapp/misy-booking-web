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
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'package:rider_ride_hailing_app/services/places_autocomplete_web.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen_web.dart';

/// Page affichant les lignes de transport d'Antananarivo sur une carte
/// Style inspiré de Île-de-France Mobilités
class TransportMapScreen extends StatefulWidget {
  const TransportMapScreen({super.key});

  @override
  State<TransportMapScreen> createState() => _TransportMapScreenState();
}

class _TransportMapScreenState extends State<TransportMapScreen> {
  GoogleMapController? _mapController;

  // Position par défaut: Antananarivo, Madagascar (centre ville)
  static const LatLng _defaultPosition = LatLng(-18.8792, 47.5079);

  // Style de carte personnalisé
  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9e4f4"}]},{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},{"featureType":"transit","stylers":[{"visibility":"off"}]}]';

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
  Set<Marker> _stopMarkers = {};

  // Cache des icônes personnalisées
  final Map<String, BitmapDescriptor> _markerIconCache = {};

  @override
  void initState() {
    super.initState();
    _loadTransportLines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
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
    final Set<Marker> newMarkers = {};

    // Ajouter le marker de position utilisateur
    if (_userPosition != null) {
      newMarkers.add(
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

      final color = Color(group.transportType.colorValue);

      // Ajouter les polylines aller et retour
      if (group.aller != null) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('${group.lineNumber}_aller'),
            points: group.aller!.coordinates,
            color: color,
            width: 5,
            patterns: [],
          ),
        );

        // Ajouter les markers des arrêts
        for (final stop in group.aller!.stops) {
          final markerId = '${group.lineNumber}_${stop.stopId}';
          final icon = await _getStopMarkerIcon(group.lineNumber, color);

          newMarkers.add(
            Marker(
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
            ),
          );
        }
      }

      if (group.retour != null) {
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('${group.lineNumber}_retour'),
            points: group.retour!.coordinates,
            color: color.withOpacity(0.6),
            width: 4,
            patterns: [PatternItem.dash(15), PatternItem.gap(8)],
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _polylines = newPolylines;
        _stopMarkers = newMarkers;
      });
    }
  }

  /// Crée une icône de marker personnalisée pour un arrêt
  Future<BitmapDescriptor> _getStopMarkerIcon(String lineNumber, Color color) async {
    final cacheKey = '${lineNumber}_${color.value}';

    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    try {
      // Créer un marker rond avec le numéro de ligne
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 36.0;

      // Cercle de fond
      final bgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, bgPaint);

      // Bordure blanche
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 1, borderPaint);

      // Texte du numéro de ligne
      final textPainter = TextPainter(
        text: TextSpan(
          text: _getShortLineNumber(lineNumber),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
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
    return Positioned.fill(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _defaultPosition,
          zoom: 13,
        ),
        style: _mapStyle,
        polylines: _polylines,
        markers: _stopMarkers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
        onTap: (_) {
          // Fermer le panneau de détails
          setState(() {
            _selectedStop = null;
            _selectedStopLine = null;
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
                    ? Color((item['data']['group'] as TransportLineGroup).transportType.colorValue)
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

  /// Panneau latéral gauche avec filtres et liste des lignes
  Widget _buildLeftPanel() {
    return Positioned(
      top: 80,
      left: 16,
      bottom: 16,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_transit, color: MyColors.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Lignes de transport',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Antananarivo • ${_lineGroups.length} lignes',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

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
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
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
        ),
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
    final color = Color(group.transportType.colorValue);
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

    final color = Color(_selectedStopLine!.transportType.colorValue);
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
                        final lineColor = Color(g.transportType.colorValue);
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

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreenWeb()),
    );
  }
}
