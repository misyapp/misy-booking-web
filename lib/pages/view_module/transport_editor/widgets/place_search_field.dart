import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/services/nominatim_service.dart';

/// TextField avec dropdown d'autocomplete Nominatim (OSM, API gratuite).
/// Quand l'user sélectionne une prédiction, appelle [onPlaceSelected] avec
/// les coordonnées + le nom du lieu. Nominatim renvoie les coords directement,
/// donc pas de second appel type "place details".
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
  List<NominatimPlace> _predictions = [];
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
    // Debounce à 400 ms pour rester confortable avec la Nominatim Usage Policy
    // (~1 req/sec conseillé pour de la saisie interactive).
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.trim().length < 3) {
        setState(() => _predictions = []);
        _removeOverlay();
        return;
      }
      setState(() => _loading = true);
      final preds = await NominatimService.instance.search(value);
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

  void _onPredictionTapped(NominatimPlace p) {
    _controller.text = p.displayName;
    _removeOverlay();
    widget.onPlaceSelected(LatLng(p.lat, p.lon), p.displayName);
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
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
                      p.shortName,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      p.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
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
