import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/services/places_autocomplete_web.dart';

/// TextField avec dropdown d'autocomplete Google Places (Madagascar).
/// Quand l'user sélectionne une prédiction, appelle [onPlaceSelected] avec
/// les coordonnées + le nom du lieu, ce qui permet à l'appelant de zoomer
/// la carte sur la zone.
class PlaceSearchField extends StatefulWidget {
  final String hint;
  final void Function(LatLng position, String description) onPlaceSelected;

  const PlaceSearchField({
    super.key,
    required this.hint,
    required this.onPlaceSelected,
  });

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focus = FocusNode();

  Timer? _debounce;
  OverlayEntry? _overlay;
  List<Map<String, dynamic>> _predictions = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().length < 3) {
        setState(() => _predictions = []);
        _removeOverlay();
        return;
      }
      setState(() => _loading = true);
      final preds = await PlacesAutocompleteWeb.getPlacePredictions(value);
      if (!mounted) return;
      setState(() {
        _predictions = preds;
        _loading = false;
      });
      if (preds.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  Future<void> _onPredictionTapped(Map<String, dynamic> pred) async {
    final placeId = pred['place_id']?.toString();
    if (placeId == null) return;
    _controller.text = pred['description']?.toString() ?? '';
    _removeOverlay();
    setState(() => _loading = true);
    final details = await PlacesAutocompleteWeb.getPlaceDetails(placeId);
    if (!mounted) return;
    setState(() => _loading = false);
    final loc = (details?['result']?['geometry']?['location']) as Map?;
    if (loc == null) {
      _showSnack('Impossible de récupérer la position du lieu');
      return;
    }
    final lat = (loc['lat'] as num).toDouble();
    final lng = (loc['lng'] as num).toDouble();
    widget.onPlaceSelected(LatLng(lat, lng), _controller.text);
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    // Largeur identique au TextField pour rester confiné dans son conteneur
    // (utile dans une sidebar étroite : évite le débordement hors carte).
    final renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 280.0;
    _overlay = OverlayEntry(
      builder: (ctx) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: const Offset(0, 56),
          showWhenUnlinked: false,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _predictions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _predictions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 20),
                    title: Text(
                      p['description']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => _onPredictionTapped(p),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (_controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _removeOverlay();
                        setState(() => _predictions = []);
                      },
                    )
                  : null),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
