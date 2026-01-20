import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as l;
import 'package:rider_ride_hailing_app/services/routing/osrm_secure_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rider_ride_hailing_app/contants/global_keys.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/modal/total_time_distance_modal.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import 'package:rider_ride_hailing_app/widget/show_custom_dialog.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import '../contants/global_data.dart';

// double? lat=null;
// double? lng=null;
String? currentFullAddress;
Position? currentPosition;
bool locationPopUpOpend = true;
StreamSubscription<Position>? positionStream;
l.Location location = l.Location();
bool applyDummyMadasagarPosition = false;
Future<void> getCurrentLocation() async {
  myCustomPrintStatement("🌍 getCurrentLocation() appelé");
  bool serviceEnabled;
  LocationPermission permission;

  // Check if location services are enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    myCustomPrintStatement("⚠️ Service de localisation désactivé");
    // Location services are disabled, handle the scenario
    return;
  }

  // Check location permissions
  permission = await Geolocator.checkPermission();
  myCustomPrintStatement("🔍 Permission initiale: $permission");

  if (permission == LocationPermission.deniedForever) {
    myCustomPrintStatement("❌ Permission refusée définitivement");
    // Location permissions are permanently denied, handle the scenario
    return;
  }

  if (permission == LocationPermission.denied) {
    myCustomPrintStatement("⚠️ Permission refusée, demande en cours...");
    // Location permissions are denied, request permissions
    permission = await Geolocator.requestPermission();
    myCustomPrintStatement("🔍 Permission après demande: $permission");

    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      myCustomPrintStatement("❌ Permission toujours refusée après demande");
      // Location permissions are still not granted, handle the scenario
      return;
    }
  }

  // Get the current location
  Position position;
  try {
    position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    myCustomPrintStatement("✅ Position obtenue: (${position.latitude}, ${position.longitude})");
  } catch (e) {
    myCustomPrintStatement("❌ Erreur lors de l'obtention de la position: $e");
    // Error occurred while fetching the location, handle the scenario
    return;
  }
  // Use the position.latitude and position.longitude properties
  currentPosition = position;

  myCustomPrintStatement("-----------lng--------lat");
  await getcurrentAddress();

  // ⚡ FIX CRITIQUE: Mettre à jour l'état de la permission dans GoogleMapProvider
  // pour activer le point bleu GPS sur la carte
  try {
    final context = MyGlobalKeys.navigatorKey.currentContext;
    if (context != null) {
      final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);

      // Si on arrive ici, c'est que la permission a été accordée
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        myCustomPrintStatement("🗺️ Mise à jour permission dans GoogleMapProvider: true");
        await mapProvider.updateLocationPermissionStatus(true);
        myCustomPrintStatement("✅ Point bleu GPS activé dans GoogleMapProvider");
      }
    } else {
      myCustomPrintStatement("⚠️ Context null, impossible de mettre à jour GoogleMapProvider");
    }
  } catch (e) {
    myCustomPrintStatement("⚠️ Erreur lors de la mise à jour GoogleMapProvider: $e");
  }

  // Do something with the latitude and longitude
  // ...
}

double calculateDistanceByArray(latlngs) {
  double d = 0;
  for (int i = 1; i < latlngs.length; i++) {
    d = d +
        getDistance(latlngs[i]['lat'], latlngs[i - 1]['lng'], latlngs[i]['lat'],
            latlngs[i]['lng']);
  }
  return d;
}

double calculateDistanceByArrayLatLng(List<List<double>> latlngs) {
  double d = 0;
  for (int i = 1; i < latlngs.length; i++) {
    d = d +
        getDistance(latlngs[i].first, latlngs[i - 1].last, latlngs[i].first,
            latlngs[i].last);
  }
  return d;
}

Future<String> getAddressByLatLong(latitude, longitude) async {
  myCustomPrintStatement("get address------------");

  List<Placemark> placemarks = await placemarkFromCoordinates(
    latitude,
    longitude,
  );

  Placemark placemark = placemarks[0];
  String address =
      "${placemark.street}, ${placemark.subLocality}, ${placemark.locality}";
  return address == ", , " ? "$latitude , $longitude" : address;
}

Future<void> getcurrentAddress() async {
  var getAddress = await getAddressWithPlusCodeByLatLng(
      latitude: currentPosition!.latitude,
      longitude: currentPosition!.longitude);

  // Vérifier si les résultats sont vides avant d'y accéder
  if (getAddress['results'] == null || getAddress['results'].isEmpty) {
    myCustomPrintStatement("⚠️ Geocoding API: aucun résultat trouvé pour ${currentPosition!.latitude}, ${currentPosition!.longitude}");
    currentFullAddress = "${currentPosition!.latitude}, ${currentPosition!.longitude}";
    return;
  }

  // 🔧 FIX: Toujours nettoyer le Plus Code de l'adresse de fallback
  currentFullAddress = removeGooglePlusCode(getAddress['results'][0]['formatted_address']);

  // Chercher le Fokontany (neighborhood ou administrative_area_level_4)
  for (int i = 0; i < getAddress['results'].length; i++) {
    final List<dynamic> results =
        getAddress['results'][i]['address_components'] ?? [];
    for (final component in results) {
      final List<dynamic> types = component['types'] ?? [];

      if (types.contains("neighborhood") ||
          types.contains("administrative_area_level_4")) {
        myCustomPrintStatement(
            "i ---------$i ${component['long_name']}, ${getAddress['results'][0]['formatted_address']}}");
        currentFullAddress =
            "${component['long_name']}, ${removeGooglePlusCode(getAddress['results'][0]['formatted_address'])}";
        return;
      }
    }
  }
  currentFullAddress = currentFullAddress == ", , "
      ? "${currentPosition!.latitude} , ${currentPosition!.longitude}"
      : currentFullAddress;
}

Future<Map> getLatLngByPlaceId(String placeId) async {
  String url =
      'https://maps.googleapis.com/maps/api/place/details/json?placeid=$placeId&key=$googleMapApiKey';
  // http.Response response =
  // http.Response('{"message":"failure","status":0}', 404);
  try {
    http.Response response = await http.get(
      Uri.parse(url),
    );

    if (response.statusCode == 200) {
      myCustomPrintStatement(response.body.runtimeType);
      var jsonResponse = jsonDecode(response.body);
      return jsonResponse;
    } else {
      throw {"status": "0"};
    }
  } catch (e) {
    throw {"status": "0"};
  }
}

Future<Map> getAddressWithPlusCodeByLatLng(
    {required double latitude, required double longitude}) async {
  String url =
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$googleMapApiKey';
  // http.Response response =
  // http.Response('{"message":"failure","status":0}', 404);
  try {
    http.Response response = await http.get(
      Uri.parse(url),
    );

    if (response.statusCode == 200) {
      myCustomLogStatements("[URL] $url");
      var jsonResponse = jsonDecode(response.body);
      return jsonResponse;
    } else {
      throw {"status": "0"};
    }
  } catch (e) {
    throw {"status": "0"};
  }
}

String removeGooglePlusCode(String address) {
  return address.replaceAll(RegExp(r'\b[A-Z0-9]{4,}\+[A-Z0-9]{2,}\b,?\s*'), '');
}

/// Calcule la distance à vol d'oiseau entre deux points (formule Haversine)
/// Retourne la distance en kilomètres
double _calculateHaversineDistance(
  double lat1, double lon1,
  double lat2, double lon2,
) {
  const double earthRadiusKm = 6371.0;

  final double dLat = _toRadians(lat2 - lat1);
  final double dLon = _toRadians(lon2 - lon1);

  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;

Future<TotalTimeDistanceModal> getTotalTimeCalculate(
    String origin, String destination) async {
  myCustomPrintStatement('🚗 Calcul temps trajet: $origin → $destination');

  List<double> parseLatLng(String value) {
    final components = value.split(',').map((part) => part.trim()).toList();
    if (components.length != 2) {
      throw FormatException('Invalid lat,lng format: $value');
    }
    final double latitude = double.parse(components[0]);
    final double longitude = double.parse(components[1]);
    return <double>[latitude, longitude];
  }

  final List<double> originCoords = parseLatLng(origin);
  final List<double> destinationCoords = parseLatLng(destination);
  const String queryParams = 'overview=full&geometries=polyline';
  final String coordinates =
      '${originCoords[1]},${originCoords[0]};${destinationCoords[1]},${destinationCoords[0]}';

  // Construction du path pour OSRM (sans le domaine)
  final String path = '/route/v1/driving/$coordinates';

  // Système de retry avec timeout progressif
  const int maxRetries = 3;
  const List<int> timeouts = [5, 8, 12]; // Timeouts progressifs en secondes

  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      myCustomPrintStatement('🧭 LocationService → Fetching time/distance via OSRM (tentative ${attempt + 1}/$maxRetries)');
      final http.Response response = await OsrmSecureClient.secureGet(
        path: path,
        queryParams: queryParams,
        timeoutSeconds: timeouts[attempt],
      );

      if (response.statusCode == 200) {
        final result = _createTotalTimeDistance(response.body);

        // Validation: vérifier que la distance n'est pas 0
        if (result.distance <= 0) {
          myCustomPrintStatement('⚠️ OSRM retourné distance = 0, tentative de retry...');
          continue; // Retry
        }

        myCustomPrintStatement('✅ Distance calculée: ${result.distance} km');
        return result;
      }

      myCustomPrintStatement('⚠️ OSRM status ${response.statusCode}, retry...');
    } catch (error) {
      myCustomPrintStatement('⚠️ OSRM tentative ${attempt + 1} échouée: $error');

      // Attendre un peu avant le retry (sauf pour le dernier)
      if (attempt < maxRetries - 1) {
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }

  // Après tous les retries OSRM échoués, utiliser Haversine comme fallback
  myCustomPrintStatement('⚠️ OSRM ÉCHEC après $maxRetries tentatives, utilisation fallback Haversine');
  myCustomPrintStatement('📍 Origin: $origin, Destination: $destination');

  // Calcul de distance à vol d'oiseau avec facteur correctif pour route
  final double straightLineDistance = _calculateHaversineDistance(
    originCoords[0], originCoords[1],
    destinationCoords[0], destinationCoords[1],
  );

  // Facteur 1.3 pour approximer la distance routière (routes rarement en ligne droite)
  const double roadFactor = 1.3;
  final double estimatedRoadDistance = straightLineDistance * roadFactor;

  // Estimation du temps: ~30 km/h en moyenne en ville
  const double averageSpeedKmh = 30.0;
  final int estimatedTimeMinutes = (estimatedRoadDistance / averageSpeedKmh * 60).ceil();

  myCustomPrintStatement('📏 Fallback Haversine: ${straightLineDistance.toStringAsFixed(2)} km vol d\'oiseau → ${estimatedRoadDistance.toStringAsFixed(2)} km estimé');

  return TotalTimeDistanceModal(
    time: estimatedTimeMinutes,
    distance: (estimatedRoadDistance * 10).roundToDouble() / 10, // Arrondi 1 décimale
  );
}

TotalTimeDistanceModal _createTotalTimeDistance(String body) {
  final Map<String, dynamic> data = json.decode(body) as Map<String, dynamic>;
  final List<dynamic> routes = data['routes'] as List<dynamic>? ?? <dynamic>[];

  if (routes.isEmpty) {
    throw Exception('OSRM response missing routes');
  }

  final Map<String, dynamic> primaryRoute =
      routes.first as Map<String, dynamic>;

  final double distanceMeters =
      (primaryRoute['distance'] as num?)?.toDouble() ?? 0;
  final double durationSeconds =
      (primaryRoute['duration'] as num?)?.toDouble() ?? 0;

  final int durationMinutes = durationSeconds > 0
      ? (durationSeconds / 60).ceil()
      : 0;

  myCustomPrintStatement(
      '✅ Temps total calculé via OSRM: ${durationSeconds.toStringAsFixed(1)}s (${durationMinutes}min)');

  return TotalTimeDistanceModal(
    distance: ((distanceMeters / 1000) * 10).roundToDouble() / 10,
    time: durationMinutes,
  );
}

Future<Map> getAddressByLatLongFromApi(String lat, String long) async {
  String url =
      'https://maps.googleapis.com/maps/api/place/details/json?location=$lat,$long&key=$googleMapApiKey';
  // http.Response response =
  // http.Response('{"message":"failure","status":0}', 404);
  try {
    http.Response response = await http.get(
      Uri.parse(url),
    );

    if (response.statusCode == 200) {
      myCustomPrintStatement("Url is that $url");
      myCustomPrintStatement(response.body.runtimeType);
      var jsonResponse = jsonDecode(response.body);
      return jsonResponse;
    } else {
      throw {"status": "0"};
    }
  } catch (e) {
    throw {"status": "0"};
  }
}

double getDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = math.cos;
  var a = 0.5 -
      c((lat2 - lat1) * p) / 2 +
      c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * math.asin(math.sqrt(a));
}

Future askLocationPermission() async {
  bool serviceEnabled = await location.serviceEnabled();
  myCustomPrintStatement("service enabled $serviceEnabled");
  if (!serviceEnabled) {
    bool b = await location.requestService();
    if (b == true) {
      await ask();
    } else {
      showSnackbar("Le service de localisation doit être activé");
      await askLocationPermission();
    }
  } else {
    await ask();
  }
}

Future ask() async {
  LocationPermission permission = await Geolocator.checkPermission();
  var m1 = await Permission.locationWhenInUse.status;
  if (m1 == PermissionStatus.granted) {
    return;
  }

  if (permission == LocationPermission.denied) {
    // Location permissions are denied, request permissions
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse &&
        permission == LocationPermission.always) {
      // Location permissions are still not granted, handle the scenario
    } else if (permission == LocationPermission.denied) {
      return showPermissionNeedPopup();
    } else if (permission == LocationPermission.deniedForever) {
      locationPopUpOpend = false;
      openAppSettingpopup();
    }
  } else if (permission == LocationPermission.deniedForever) {
    if (locationPopUpOpend) {
      locationPopUpOpend = false;
      await openAppSettingpopup();
    } else {
      return;
    }
  }
}

Future askForIntroScrenn() async {
  LocationPermission permission = await Geolocator.checkPermission();
  var m1 = await Permission.locationWhenInUse.status;
  if (m1 == PermissionStatus.granted) {
    return;
  }

  if (permission == LocationPermission.denied) {
    // Location permissions are denied, request permissions
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse &&
        permission == LocationPermission.always) {
      // Location permissions are still not granted, handle the scenario
      return;
    } else if (permission == LocationPermission.denied) {
      return;
    } else if (permission == LocationPermission.deniedForever) {
      return;
      // locationPopUpOpend = false;
    }
  } else if (permission == LocationPermission.deniedForever) {
    if (locationPopUpOpend) {
      // locationPopUpOpend = false;
      return openAppSettings();
    } else {
      return openAppSettings();
    }
  }
}

openAppSettingpopup() async {
  return await showCustomDialog(
      barrierDismissible: false,
      verticalInsetPadding: 20,
      // ignore: deprecated_member_use
      child: WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParagraphText(translate("openAppSettingMsg")),
            vSizedBox,
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              RoundEdgedButton(
                text: translate("openAppSetting"),
                horizontlyPadding: 10,
                verticalMargin: 0,
                fontSize: 12,
                height: 40,
                onTap: () {
                  locationPopUpOpend = true;
                  Navigator.pop(MyGlobalKeys.navigatorKey.currentContext!);
                  Future.delayed(const Duration(milliseconds: 500), () async {
                    await openAppSettings();
                  });
                },
              )
            ])
          ],
        ),
      ));
}

showPermissionNeedPopup() async {
  return await showCustomDialog(
      barrierDismissible: false,
      verticalInsetPadding: 20,
      // ignore: deprecated_member_use
      child: WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParagraphText(translate("prePermissionPopup")),
            vSizedBox,
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              RoundEdgedButton(
                text: translate("Allow"),
                horizontlyPadding: 25,
                verticalMargin: 0,
                fontSize: 12,
                height: 40,
                onTap: () {
                  Navigator.pop(
                      MyGlobalKeys.navigatorKey.currentContext!, true);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    ask();
                  });
                },
              )
            ])
          ],
        ),
      ));
}

Future<void> startLocationListner(Function callbck) async {
  myCustomPrintStatement("🚀 startLocationListner() appelé");

  await askLocationPermission();

  myCustomPrintStatement("🔍 Vérification de la permission après askLocationPermission()");

  // ⚡ FIX: Obtenir immédiatement la position APRÈS que l'utilisateur accorde la permission
  // Cela évite d'afficher "Position non disponible" et rafraîchit l'interface
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    myCustomPrintStatement("🔍 Permission détectée: $permission");

    // Si la permission est accordée, obtenir la position immédiatement
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      myCustomPrintStatement("✅ Permission accordée - Obtention position immédiate...");

      // ⚡ Mettre à jour l'état de la permission dans GoogleMapProvider pour activer le point bleu
      try {
        final mapProvider = Provider.of<GoogleMapProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);
        myCustomPrintStatement("🗺️ Appel de updateLocationPermissionStatus(true)");
        await mapProvider.updateLocationPermissionStatus(true);
        myCustomPrintStatement("✅ Permission mise à jour dans GoogleMapProvider");
      } catch (e) {
        myCustomPrintStatement("⚠️ Impossible de mettre à jour GoogleMapProvider: $e");
      }

      // 1. Obtenir INSTANTANÉMENT la dernière position connue (cache système)
      try {
        final cachedPosition = await Geolocator.getLastKnownPosition();
        if (cachedPosition != null) {
          currentPosition = cachedPosition;
          DevFestPreferences.updateLocation(
              LatLng(cachedPosition.latitude, cachedPosition.longitude));
          myCustomPrintStatement("⚡ Position cache instantanée: ${cachedPosition.latitude}, ${cachedPosition.longitude}");

          // Mettre à jour le mapProvider immédiatement (via setPosition pour notifyListeners)
          try {
            final mapProvider = Provider.of<GoogleMapProvider>(
                MyGlobalKeys.navigatorKey.currentContext!,
                listen: false);
            mapProvider.setPosition(cachedPosition.latitude, cachedPosition.longitude);
          } catch (e) {
            myCustomPrintStatement("⚠️ Impossible de mettre à jour mapProvider avec cache: $e");
          }

          // Appeler le callback avec la position cache
          callbck();
        }
      } catch (e) {
        myCustomPrintStatement("⚠️ Pas de position en cache: $e");
      }

      // 2. Ensuite obtenir la position GPS fraîche (peut prendre quelques secondes)
      try {
        final freshPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            myCustomPrintStatement("⏱️ Timeout GPS 10s - utilisation position cache");
            throw TimeoutException('GPS timeout');
          },
        );

        currentPosition = freshPosition;
        DevFestPreferences.updateLocation(
            LatLng(freshPosition.latitude, freshPosition.longitude));
        myCustomPrintStatement("📍 Position GPS fraîche: ${freshPosition.latitude}, ${freshPosition.longitude}");

        await getcurrentAddress();
        myCustomPrintStatement("🏠 Adresse: $currentFullAddress");

        // Appeler le callback avec la position fraîche
        callbck();
      } catch (e) {
        myCustomPrintStatement("⚠️ Erreur position fraîche (utilisation cache): $e");
        // Si on a déjà une position en cache, on continue
        if (currentPosition != null) {
          await getcurrentAddress();
        }
      }
    } else {
      myCustomPrintStatement("⚠️ Permission de localisation refusée ou limitée: $permission");

      // ⚡ Mettre à jour l'état de la permission dans GoogleMapProvider
      try {
        final mapProvider = Provider.of<GoogleMapProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);
        myCustomPrintStatement("🗺️ Appel de updateLocationPermissionStatus(false)");
        await mapProvider.updateLocationPermissionStatus(false);
      } catch (e) {
        myCustomPrintStatement("⚠️ Impossible de mettre à jour GoogleMapProvider: $e");
      }
    }
  } catch (e) {
    myCustomPrintStatement("❌ Erreur lors de l'obtention de la position initiale: $e");
  }

  // Démarrer l'écoute continue des changements de position
  positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, distanceFilter: 10))
      .listen((Position? position) async {
    myCustomPrintStatement(position == null
        ? 'Unknown'
        : '${position.latitude.toString()}, ${position.longitude.toString()}');
    if (position != null) {
      currentPosition = position;

      // 🎯 FIX: Synchroniser mapProvider.currentPosition avec la vraie position GPS
      // Utiliser setPosition() pour déclencher notifyListeners() et reconstruire les widgets
      try {
        final mapProvider = Provider.of<GoogleMapProvider>(
            MyGlobalKeys.navigatorKey.currentContext!,
            listen: false);
        mapProvider.setPosition(position.latitude, position.longitude);
      } catch (e) {
        myCustomPrintStatement("⚠️ Impossible de mettre à jour mapProvider: $e");
      }

      DevFestPreferences.updateLocation(
          LatLng(position.latitude, position.longitude));
      myCustomPrintStatement("callback before");
      if (currentFullAddress == null) {
        myCustomPrintStatement("getting current address");
        await getcurrentAddress();
      }

      callbck();
    }
  });
}

Future<List> getPlacePridiction(text) async {
  // Vérifier si currentPosition est disponible
  if (currentPosition == null) {
    myCustomPrintStatement("⚠️ getPlacePridiction: currentPosition est null, recherche sans localisation");
    // Faire la recherche sans le paramètre location
    String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$text&key=$googleMapApiKey&language=en";
    final response = await http.get(Uri.parse(url));
    final extractedData = json.decode(response.body);
    if (extractedData["error_message"] != null) {
      myCustomLogStatements("request for url $url ${extractedData["error_message"]}");
      return [];
    }
    return extractedData["predictions"] ?? [];
  }

  String url =
      "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$text&key=$googleMapApiKey&language=en&radius=500&location=${currentPosition!.latitude},${currentPosition!.longitude}";
  final response = await http.get(Uri.parse(url));
  final extractedData = json.decode(response.body);
  myCustomLogStatements(
      "extractedData url is that $url \nextractedData $extractedData");
  if (extractedData["error_message"] != null) {
    var error = extractedData["error_message"];
    if (error == "This API project is not authorized to use this API.") {
      error +=
          " Make sure the Places API is activated on your Google Cloud Platform";
    }
    // ignore: prefer_interpolation_to_compose_strings
    myCustomLogStatements("request for url $url " + error);
    return [];
  } else {
    final predictions = extractedData["predictions"];
    return predictions ?? [];
  }
}
