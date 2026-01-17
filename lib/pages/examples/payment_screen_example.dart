import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../widgets/misy_google_map.dart';
import '../../utils/map_utils.dart';

/// EXEMPLE D'UTILISATION : Écran de paiement avec carte Google Maps
/// Solution complète pour éviter le dézoom iOS avec bottom sheets
class PaymentScreenExample extends StatefulWidget {
  final LatLng? startPoint;
  final LatLng? endPoint;
  final LatLng? userPosition;

  const PaymentScreenExample({
    Key? key,
    this.startPoint,
    this.endPoint,
    this.userPosition,
  }) : super(key: key);

  @override
  State<PaymentScreenExample> createState() => _PaymentScreenExampleState();
}

class _PaymentScreenExampleState extends State<PaymentScreenExample> {
  GoogleMapController? _mapController;
  final GlobalKey<MisyGoogleMapState> _mapKey = GlobalKey();

  // Configuration des markers
  Set<Marker> get _markers {
    final markers = <Marker>{};
    
    if (widget.startPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: widget.startPoint!,
        infoWindow: const InfoWindow(title: 'Départ'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    
    if (widget.endPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('end'),
        position: widget.endPoint!,
        infoWindow: const InfoWindow(title: 'Arrivée'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    
    return markers;
  }

  // Configuration des polylines
  Set<Polyline> get _polylines {
    if (widget.startPoint == null || widget.endPoint == null) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [widget.startPoint!, widget.endPoint!],
        color: Colors.blue,
        width: 3,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // CARTE GOOGLE MAPS avec solution anti-dézoom iOS
          MisyGoogleMap(
            key: _mapKey,
            userPosition: widget.userPosition,
            startPoint: widget.startPoint,
            endPoint: widget.endPoint,
            markers: _markers,
            polylines: _polylines,
            bottomSheetHeightRatio: 0.5, // Bottom sheet occupe 50% de l'écran
            onMapCreated: _onMapCreated,
          ),

          // BOTTOM SHEET de paiement (50% de l'écran)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: _buildPaymentContent(),
            ),
          ),

          // Bouton de recentrage manuel (utile pour debug)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _recenterMap,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  /// Contenu de la bottom sheet de paiement
  Widget _buildPaymentContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle de la bottom sheet
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Titre
          const Text(
            'Choisir le mode de paiement',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Informations du trajet
          if (widget.startPoint != null && widget.endPoint != null) ...[
            _buildTripInfo(),
            const SizedBox(height: 20),
          ],

          // Options de paiement
          _buildPaymentOptions(),
        ],
      ),
    );
  }

  /// Informations du trajet
  Widget _buildTripInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résumé du trajet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Départ: ${widget.startPoint?.toString() ?? "Position actuelle"}'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Arrivée: ${widget.endPoint?.toString() ?? "Destination"}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Options de paiement
  Widget _buildPaymentOptions() {
    return Column(
      children: [
        _buildPaymentOption(
          title: 'Airtel Money',
          subtitle: 'Paiement mobile sécurisé',
          icon: Icons.phone_android,
          color: Colors.red,
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          title: 'Orange Money',
          subtitle: 'Paiement mobile Orange',
          icon: Icons.phone_android,
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          title: 'Telma MVola',
          subtitle: 'Paiement mobile Telma',
          icon: Icons.phone_android,
          color: Colors.blue,
        ),
      ],
    );
  }

  /// Option de paiement individuelle
  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _selectPaymentMethod(title),
      ),
    );
  }

  /// Callback de création de carte
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    debugPrint('🗺️ Carte créée avec solution anti-dézoom iOS');
  }

  /// Recentrage manuel de la carte
  Future<void> _recenterMap() async {
    if (_mapController != null) {
      await MapUtils.smartCenter(
        controller: _mapController!,
        startPoint: widget.startPoint,
        endPoint: widget.endPoint,
        userPosition: widget.userPosition,
        bottomSheetHeightRatio: 0.5,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carte recentrée')),
      );
    }
  }

  /// Sélection du mode de paiement
  void _selectPaymentMethod(String method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mode de paiement sélectionné'),
        content: Text('Vous avez choisi: $method'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// EXEMPLE D'USAGE dans votre application :
/*

// Dans votre page de paiement existante, remplacez la GoogleMap par :
Widget build(BuildContext context) {
  return PaymentScreenExample(
    userPosition: currentUserPosition,
    startPoint: pickupLocation,
    endPoint: dropoffLocation,
  );
}

// OU utilisez directement le widget MisyGoogleMap :
MisyGoogleMap(
  userPosition: userPosition,
  startPoint: startPoint,
  endPoint: endPoint,
  markers: markers,
  polylines: polylines,
  bottomSheetHeightRatio: 0.5, // 50% pour écran paiement
  onMapCreated: (controller) {
    // Votre logique existante
  },
)

*/