import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen_web.dart';

/// Page affichant les lignes de transport d'Antananarivo sur une carte
class TransportMapScreen extends StatefulWidget {
  const TransportMapScreen({super.key});

  @override
  State<TransportMapScreen> createState() => _TransportMapScreenState();
}

class _TransportMapScreenState extends State<TransportMapScreen> {
  GoogleMapController? _mapController;

  // Position par défaut: Antananarivo, Madagascar (centre ville)
  static const LatLng _defaultPosition = LatLng(-18.8792, 47.5079);

  // Style de carte personnalisé (identique à home_screen_web)
  static const String _mapStyle = '[{"elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#A6B5DE"}]},{"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":3}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#BCC5E8"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.arterial","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road.local","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"road.local","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"road","elementType":"labels","stylers":[{"visibility":"on"}]},{"featureType":"road.highway","elementType":"labels.icon","stylers":[{"visibility":"on"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#ADD4F5"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#7A7A7A"}]},{"featureType":"poi","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"on"},{"color":"#B0B0B0"}]},{"featureType":"poi.business","elementType":"labels.text","stylers":[{"visibility":"off"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#E5E9EC"}]},{"featureType":"transit.station.bus","elementType":"labels.text","stylers":[{"visibility":"on"},{"color":"#000000"}]},{"featureType":"transit.station.bus","elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":2}]},{"featureType":"transit.station.bus","elementType":"labels.icon","stylers":[{"visibility":"on"},{"color":"#4A4A4A"}]}]';

  // Données de lignes
  List<TransportLineGroup> _lineGroups = [];
  bool _isLoading = true;

  // Filtres
  TransportType? _selectedTypeFilter;
  TransportLineGroup? _selectedLineGroup;
  bool _showAller = true;
  bool _showRetour = true;

  // Éléments de carte
  Set<Polyline> _polylines = {};
  Set<Marker> _stopMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadTransportLines();
  }

  Future<void> _loadTransportLines() async {
    try {
      final lines = await TransportLinesService.instance.loadAllLines();
      if (mounted) {
        setState(() {
          _lineGroups = lines;
          _isLoading = false;
        });
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

  /// Affiche une ligne sur la carte
  void _selectLine(TransportLineGroup lineGroup) {
    setState(() {
      _selectedLineGroup = lineGroup;
    });
    _updateMapDisplay();
  }

  /// Met à jour l'affichage de la carte avec les polylines et markers
  void _updateMapDisplay() {
    if (_selectedLineGroup == null) {
      setState(() {
        _polylines = {};
        _stopMarkers = {};
      });
      return;
    }

    final Set<Polyline> newPolylines = {};
    final Set<Marker> newMarkers = {};
    final List<LatLng> allCoordinates = [];

    // Ajouter la ligne aller si sélectionnée
    if (_showAller && _selectedLineGroup!.aller != null) {
      final aller = _selectedLineGroup!.aller!;
      final color = Color(aller.transportType.colorValue);

      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('aller'),
          points: aller.coordinates,
          color: color,
          width: 4,
        ),
      );

      allCoordinates.addAll(aller.coordinates);

      // Ajouter les markers des arrêts
      for (final stop in aller.stops) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('aller_${stop.stopId}'),
            position: stop.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHue(aller.transportType),
            ),
            infoWindow: InfoWindow(
              title: stop.name,
              snippet: 'Aller',
            ),
          ),
        );
      }
    }

    // Ajouter la ligne retour si sélectionnée
    if (_showRetour && _selectedLineGroup!.retour != null) {
      final retour = _selectedLineGroup!.retour!;
      final color = Color(retour.transportType.colorValue).withOpacity(0.7);

      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('retour'),
          points: retour.coordinates,
          color: color,
          width: 4,
          patterns: [PatternItem.dash(10), PatternItem.gap(5)],
        ),
      );

      allCoordinates.addAll(retour.coordinates);

      // Ajouter les markers des arrêts (seulement si on n'affiche pas l'aller, pour éviter les doublons)
      if (!_showAller) {
        for (final stop in retour.stops) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('retour_${stop.stopId}'),
              position: stop.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(retour.transportType),
              ),
              infoWindow: InfoWindow(
                title: stop.name,
                snippet: 'Retour',
              ),
            ),
          );
        }
      }
    }

    setState(() {
      _polylines = newPolylines;
      _stopMarkers = newMarkers;
    });

    // Ajuster la caméra pour voir toute la ligne
    if (allCoordinates.isNotEmpty && _mapController != null) {
      _fitMapToCoordinates(allCoordinates);
    }
  }

  /// Ajuste la caméra pour voir toutes les coordonnées
  void _fitMapToCoordinates(List<LatLng> coordinates) {
    if (coordinates.isEmpty) return;

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final coord in coordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  /// Obtient la teinte du marker selon le type de transport
  double _getMarkerHue(TransportType type) {
    switch (type) {
      case TransportType.bus:
        return BitmapDescriptor.hueAzure;
      case TransportType.urbanTrain:
        return BitmapDescriptor.hueGreen;
      case TransportType.telepherique:
        return BitmapDescriptor.hueOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte Google Maps pleine page
          _buildMap(),

          // Header avec logo et navigation
          _buildHeader(),

          // Panneau latéral avec liste des lignes
          _buildSidePanel(),
        ],
      ),
    );
  }

  /// Carte Google Maps
  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _defaultPosition,
        zoom: 13,
      ),
      style: _mapStyle,
      polylines: _polylines,
      markers: _stopMarkers,
      onMapCreated: (controller) {
        _mapController = controller;
        if (kIsWeb) {
          _applyMapStyleViaJS();
        }
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: false,
      mapType: MapType.normal,
    );
  }

  /// Applique le style de carte via JavaScript
  void _applyMapStyleViaJS() {
    try {
      final window = js_util.globalThis;
      final fn = js_util.getProperty(window, 'applyMisyMapStyle');
      if (fn != null) {
        js_util.callMethod(window, 'applyMisyMapStyle', []);
      }
    } catch (e) {
      debugPrint('Error applying map style via JS: $e');
    }
  }

  /// Header avec logo et navigation
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo Misy
          Image.asset(
            MyImagesUrl.misyLogoRose,
            height: 32,
            fit: BoxFit.contain,
          ),

          const SizedBox(width: 32),

          // Onglets de navigation principaux
          _buildNavTab('Accueil', Icons.home_outlined, false, () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreenWeb()),
            );
          }),
          _buildNavTab('Carte des transports', Icons.directions_bus_outlined, true, null),

          const Spacer(),
        ],
      ),
    );
  }

  /// Onglet de navigation
  Widget _buildNavTab(String label, IconData icon, bool isActive, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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

  /// Panneau latéral avec liste des lignes
  Widget _buildSidePanel() {
    return Positioned(
      top: 80,
      left: 24,
      bottom: 24,
      child: Container(
        width: 360,
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
            // Titre
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lignes de transport',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Antananarivo',
                    style: TextStyle(
                      fontSize: 14,
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

            // Options aller/retour si une ligne est sélectionnée
            if (_selectedLineGroup != null) _buildDirectionToggle(),
          ],
        ),
      ),
    );
  }

  /// Filtres par type de transport
  Widget _buildTypeFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('Tous', null),
          const SizedBox(width: 8),
          _buildFilterChip('Bus', TransportType.bus),
          const SizedBox(width: 8),
          _buildFilterChip('Train', TransportType.urbanTrain),
          const SizedBox(width: 8),
          _buildFilterChip('Teleph.', TransportType.telepherique),
        ],
      ),
    );
  }

  /// Chip de filtre
  Widget _buildFilterChip(String label, TransportType? type) {
    final isSelected = _selectedTypeFilter == type;
    Color chipColor;

    if (type == null) {
      chipColor = MyColors.primaryColor;
    } else {
      chipColor = Color(type.colorValue);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTypeFilter = type;
          _selectedLineGroup = null;
          _polylines = {};
          _stopMarkers = {};
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// Liste des lignes filtrées
  Widget _buildLinesList() {
    List<TransportLineGroup> filteredLines = _lineGroups;

    if (_selectedTypeFilter != null) {
      filteredLines = _lineGroups
          .where((g) => g.transportType == _selectedTypeFilter)
          .toList();
    }

    if (filteredLines.isEmpty) {
      return Center(
        child: Text(
          'Aucune ligne disponible',
          style: TextStyle(color: Colors.grey.shade600),
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

  /// Élément de liste pour une ligne
  Widget _buildLineItem(TransportLineGroup group) {
    final isSelected = _selectedLineGroup?.lineNumber == group.lineNumber;
    final color = Color(group.transportType.colorValue);
    final numStops = group.aller?.numStops ?? group.retour?.numStops ?? 0;

    return InkWell(
      onTap: () => _selectLine(group),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
        ),
        child: Row(
          children: [
            // Badge de la ligne
            Container(
              width: 50,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                group.lineNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Informations de la ligne
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
                  const SizedBox(height: 2),
                  Text(
                    '$numStops arrêts • ${group.transportType.displayName}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Icône selon le type
            Icon(
              _getTransportIcon(group.transportType),
              color: color,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Icône selon le type de transport
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

  /// Toggle aller/retour
  Widget _buildDirectionToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Direction',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Toggle Aller
              Expanded(
                child: _buildDirectionButton(
                  'Aller',
                  _showAller,
                  _selectedLineGroup?.aller != null,
                  () {
                    setState(() {
                      _showAller = !_showAller;
                    });
                    _updateMapDisplay();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Toggle Retour
              Expanded(
                child: _buildDirectionButton(
                  'Retour',
                  _showRetour,
                  _selectedLineGroup?.retour != null,
                  () {
                    setState(() {
                      _showRetour = !_showRetour;
                    });
                    _updateMapDisplay();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bouton de direction
  Widget _buildDirectionButton(
    String label,
    bool isActive,
    bool isAvailable,
    VoidCallback onTap,
  ) {
    final color = _selectedLineGroup != null
        ? Color(_selectedLineGroup!.transportType.colorValue)
        : MyColors.primaryColor;

    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive && isAvailable ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAvailable ? color.withOpacity(0.3) : Colors.grey.shade300,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive && isAvailable ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
