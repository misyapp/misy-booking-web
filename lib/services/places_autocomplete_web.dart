// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Service d'autocomplete Google Places pour le Web
/// Utilise l'API JavaScript de Google Places (chargée dans index.html)
class PlacesAutocompleteWeb {
  static AutocompleteService? _autocompleteService;

  /// Initialise le service d'autocomplete
  static void _initService() {
    if (_autocompleteService == null) {
      _autocompleteService = AutocompleteService();
    }
  }

  /// Recherche des prédictions d'adresses
  static Future<List<Map<String, dynamic>>> getPlacePredictions(String input) async {
    if (input.isEmpty || input.length < 3) {
      return [];
    }

    _initService();

    final completer = Completer<List<Map<String, dynamic>>>();

    final request = AutocompletionRequest(
      input: input,
      componentRestrictions: ComponentRestrictions(country: 'mg'),
    );

    _autocompleteService!.getPlacePredictions(
      request,
      (JSArray? predictions, String status) {
        if (status == 'OK' && predictions != null) {
          final results = <Map<String, dynamic>>[];
          final length = predictions.length;

          for (var i = 0; i < length; i++) {
            final prediction = predictions[i] as AutocompletePrediction;
            results.add({
              'description': prediction.description,
              'place_id': prediction.placeId,
            });
          }

          completer.complete(results);
        } else {
          completer.complete([]);
        }
      }.toJS,
    );

    return completer.future;
  }

  /// Récupère les détails d'un lieu par son place_id
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final completer = Completer<Map<String, dynamic>?>();

    try {
      // Créer un élément div temporaire pour PlacesService
      final div = web.document.createElement('div') as web.HTMLDivElement;
      final service = PlacesService(div);

      final request = PlaceDetailsRequest(
        placeId: placeId,
        fields: ['geometry', 'formatted_address', 'name'].toJS,
      );

      service.getDetails(
        request,
        (PlaceResult? place, String status) {
          print('PlacesService.getDetails status: $status');
          if (status == 'OK' && place != null) {
            final location = place.geometry?.location;
            if (location != null) {
              final lat = location.lat();
              final lng = location.lng();
              print('Place location: $lat, $lng');
              completer.complete({
                'result': {
                  'geometry': {
                    'location': {
                      'lat': lat,
                      'lng': lng,
                    }
                  },
                  'formatted_address': place.formattedAddress,
                  'name': place.name,
                }
              });
            } else {
              print('Place geometry.location is null');
              completer.complete(null);
            }
          } else {
            print('PlacesService error status: $status');
            completer.complete(null);
          }
        }.toJS,
      );

      // Timeout after 10 seconds
      return completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('PlacesService.getDetails timeout');
          return null;
        },
      );
    } catch (e) {
      print('PlacesService exception: $e');
      return null;
    }
  }
}

// Bindings JavaScript pour Google Places API

@JS('google.maps.places.AutocompleteService')
extension type AutocompleteService._(JSObject _) implements JSObject {
  external AutocompleteService();
  external void getPlacePredictions(AutocompletionRequest request, JSFunction callback);
}

@JS()
extension type AutocompletionRequest._(JSObject _) implements JSObject {
  external factory AutocompletionRequest({
    String input,
    ComponentRestrictions? componentRestrictions,
  });
}

@JS()
extension type ComponentRestrictions._(JSObject _) implements JSObject {
  external factory ComponentRestrictions({String country});
}

@JS()
extension type AutocompletePrediction._(JSObject _) implements JSObject {
  external String get description;
  @JS('place_id')
  external String get placeId;
}

@JS('google.maps.places.PlacesService')
extension type PlacesService._(JSObject _) implements JSObject {
  external PlacesService(web.HTMLDivElement div);
  external void getDetails(PlaceDetailsRequest request, JSFunction callback);
}

@JS()
extension type PlaceDetailsRequest._(JSObject _) implements JSObject {
  external factory PlaceDetailsRequest({
    String placeId,
    JSArray<JSString> fields,
  });
}

@JS()
extension type PlaceResult._(JSObject _) implements JSObject {
  external PlaceGeometry? get geometry;
  @JS('formatted_address')
  external String? get formattedAddress;
  external String? get name;
}

@JS()
extension type PlaceGeometry._(JSObject _) implements JSObject {
  external GoogleLatLng? get location;
}

@JS('google.maps.LatLng')
extension type GoogleLatLng._(JSObject _) implements JSObject {
  external double lat();
  external double lng();
}

extension on List<String> {
  JSArray<JSString> get toJS {
    final arr = <JSString>[];
    for (final s in this) {
      arr.add(s.toJS);
    }
    return arr.toJS;
  }
}
