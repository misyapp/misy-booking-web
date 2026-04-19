import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/transport_line_validation.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';

/// Service I/O pour l'éditeur terrain transport.
///
/// Trois collections gérées :
///   - transport_lines_edited/{line} — source de vérité de la session (GeoJSON)
///   - transport_line_validations/{line} — statut du wizard
///   - transport_edits_log/{auto} — audit immuable
class TransportEditorService {
  TransportEditorService._();
  static final TransportEditorService instance = TransportEditorService._();

  static const String collEdited = 'transport_lines_edited';
  static const String collValidations = 'transport_line_validations';
  static const String collLog = 'transport_edits_log';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ───────────────────────── Validations ─────────────────────────

  /// Stream de toutes les validations → pour dashboard live.
  Stream<Map<String, TransportLineValidation>> streamAllValidations() {
    return _db.collection(collValidations).snapshots().map((snap) {
      final out = <String, TransportLineValidation>{};
      for (final doc in snap.docs) {
        out[doc.id] =
            TransportLineValidation.fromFirestore(doc.id, doc.data());
      }
      return out;
    });
  }

  Future<TransportLineValidation> getValidation(String lineNumber) async {
    final doc = await _db.collection(collValidations).doc(lineNumber).get();
    if (!doc.exists) return TransportLineValidation.empty(lineNumber);
    return TransportLineValidation.fromFirestore(lineNumber, doc.data()!);
  }

  Future<void> _setStepStatus(
    String lineNumber,
    EditorStep step,
    ValidationStatus status,
  ) async {
    await _db.collection(collValidations).doc(lineNumber).set({
      step.fieldKey: status.code,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': AdminAuthService.instance.currentUid,
      'updated_by_email': AdminAuthService.instance.currentEmail,
    }, SetOptions(merge: true));
  }

  // ───────────────────────── Edited doc ─────────────────────────

  /// Charge le doc Firestore de la ligne. S'il n'existe pas, bootstrap depuis
  /// le GeoJSON actuel (asset ou remote) et le persiste.
  Future<Map<String, dynamic>> loadOrBootstrap(String lineNumber) async {
    final ref = _db.collection(collEdited).doc(lineNumber);
    final snap = await ref.get();
    if (snap.exists) return snap.data()!;

    // Bootstrap : charger depuis TransportLinesService
    final svc = TransportLinesService.instance;
    final metadata = await svc.getAllLineMetadata().then(
          (list) => list.where((m) => m.lineNumber == lineNumber).toList(),
        );
    if (metadata.isEmpty) {
      throw Exception('Ligne $lineNumber absente du manifest');
    }
    final m = metadata.first;

    final aller = await _loadRawGeoJson(m.aller);
    final retour = await _loadRawGeoJson(m.retour);

    final payload = <String, dynamic>{
      'line_number': lineNumber,
      'display_name': m.displayName,
      'transport_type': m.transportType,
      'color': m.colorHex,
      'is_bundled': m.isBundled,
      if (aller != null) 'aller': {'feature_collection': aller},
      if (retour != null) 'retour': {'feature_collection': retour},
      'created_at': FieldValue.serverTimestamp(),
      'last_updated': FieldValue.serverTimestamp(),
      'last_updated_by': AdminAuthService.instance.currentUid,
      'bootstrapped_from_asset': true,
    };
    await ref.set(payload);
    return payload;
  }

  Future<Map<String, dynamic>?> _loadRawGeoJson(
    dynamic routeMetadata,
  ) async {
    if (routeMetadata == null) return null;
    try {
      final String? assetPath = routeMetadata.assetPath;
      final String? remoteUrl = routeMetadata.remoteUrl;
      String raw;
      if (assetPath != null) {
        raw = await rootBundle.loadString(assetPath);
      } else if (remoteUrl != null) {
        final resp = await http.get(Uri.parse(remoteUrl));
        if (resp.statusCode != 200) return null;
        raw = resp.body;
      } else {
        return null;
      }
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      myCustomPrintStatement('Erreur load raw geojson: $e');
      return null;
    }
  }

  /// Marque l'étape comme validée telle quelle (aucune modif du FC).
  Future<void> markValidated(String lineNumber, EditorStep step) async {
    await _setStepStatus(lineNumber, step, ValidationStatus.validated);
    await _appendLog(
      lineNumber: lineNumber,
      direction: step.isAller ? 'aller' : 'retour',
      kind: step.isRoute ? 'route' : 'stops',
      action: 'validated',
    );
  }

  /// Écrit un FeatureCollection modifié (tracé ou arrêts) pour une direction.
  /// Pour une étape "route" : remplace le LineString, conserve les Points.
  /// Pour une étape "stops" : remplace les Points, conserve le LineString.
  Future<void> saveStepEdit({
    required String lineNumber,
    required EditorStep step,
    required Map<String, dynamic> updatedFeatureCollection,
    int? verticesBefore,
    int? verticesAfter,
    int? stopsBefore,
    int? stopsAfter,
  }) async {
    final direction = step.isAller ? 'aller' : 'retour';
    final ref = _db.collection(collEdited).doc(lineNumber);
    await ref.set({
      direction: {
        'feature_collection': updatedFeatureCollection,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': AdminAuthService.instance.currentUid,
      },
      'last_updated': FieldValue.serverTimestamp(),
      'last_updated_by': AdminAuthService.instance.currentUid,
    }, SetOptions(merge: true));

    await _setStepStatus(lineNumber, step, ValidationStatus.modified);
    await _appendLog(
      lineNumber: lineNumber,
      direction: direction,
      kind: step.isRoute ? 'route' : 'stops',
      action: 'modified',
      verticesBefore: verticesBefore,
      verticesAfter: verticesAfter,
      stopsBefore: stopsBefore,
      stopsAfter: stopsAfter,
    );
  }

  // ───────────────────────── Nouvelle ligne ─────────────────────────

  Future<void> createNewLine({
    required String lineNumber,
    required String displayName,
    required String transportType,
    required String colorHex,
    required Map<String, dynamic> allerFeatureCollection,
    required Map<String, dynamic> retourFeatureCollection,
  }) async {
    final ref = _db.collection(collEdited).doc(lineNumber);
    final exists = (await ref.get()).exists;
    if (exists) {
      throw Exception('Ligne $lineNumber existe déjà');
    }

    await ref.set({
      'line_number': lineNumber,
      'display_name': displayName,
      'transport_type': transportType,
      'color': colorHex,
      'is_bundled': true,
      'is_new_line': true,
      'aller': {
        'feature_collection': allerFeatureCollection,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': AdminAuthService.instance.currentUid,
      },
      'retour': {
        'feature_collection': retourFeatureCollection,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': AdminAuthService.instance.currentUid,
      },
      'created_at': FieldValue.serverTimestamp(),
      'last_updated': FieldValue.serverTimestamp(),
      'last_updated_by': AdminAuthService.instance.currentUid,
    });

    // Marquer les 4 étapes comme modified (= nouvelle création)
    await _db.collection(collValidations).doc(lineNumber).set({
      for (final s in EditorStep.values) s.fieldKey: ValidationStatus.modified.code,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': AdminAuthService.instance.currentUid,
      'updated_by_email': AdminAuthService.instance.currentEmail,
      'is_new_line': true,
    }, SetOptions(merge: true));

    await _appendLog(
      lineNumber: lineNumber,
      direction: 'aller',
      kind: 'new_line',
      action: 'created',
    );
  }

  // ───────────────────────── Log audit ─────────────────────────

  Future<void> _appendLog({
    required String lineNumber,
    required String direction,
    required String kind,
    required String action,
    int? verticesBefore,
    int? verticesAfter,
    int? stopsBefore,
    int? stopsAfter,
  }) async {
    await _db.collection(collLog).add({
      'line_number': lineNumber,
      'direction': direction,
      'kind': kind,
      'action': action,
      'user_uid': AdminAuthService.instance.currentUid,
      'user_email': AdminAuthService.instance.currentEmail,
      if (verticesBefore != null) 'vertices_before': verticesBefore,
      if (verticesAfter != null) 'vertices_after': verticesAfter,
      if (stopsBefore != null) 'stops_before': stopsBefore,
      if (stopsAfter != null) 'stops_after': stopsAfter,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

// ─────────────────────── Helpers GeoJSON ────────────────────────

/// Outils pour manipuler un FeatureCollection représentant une direction
/// (LineString + Points d'arrêts). Tout en `Map<String, dynamic>` pour rester
/// compatible direct avec Firestore.
class GeoJsonHelpers {
  /// Extrait les coordonnées du LineString (en [lng, lat]).
  static List<List<double>> extractLineString(Map<String, dynamic> fc) {
    final features = (fc['features'] as List?) ?? [];
    for (final f in features) {
      final g = f['geometry'] as Map<String, dynamic>?;
      if (g != null && g['type'] == 'LineString') {
        return (g['coordinates'] as List)
            .map((c) => [(c[0] as num).toDouble(), (c[1] as num).toDouble()])
            .toList();
      }
    }
    return [];
  }

  /// Extrait les arrêts (Features Point avec properties.type == 'stop').
  static List<Map<String, dynamic>> extractStops(Map<String, dynamic> fc) {
    final features = (fc['features'] as List?) ?? [];
    return features
        .cast<Map<String, dynamic>>()
        .where((f) {
          final g = f['geometry'] as Map<String, dynamic>?;
          if (g == null || g['type'] != 'Point') return false;
          final p = f['properties'] as Map<String, dynamic>?;
          return p != null && (p['type'] == 'stop' || p['type'] == null);
        })
        .toList();
  }

  /// Construit un Feature LineString depuis une liste de [lng, lat].
  static Map<String, dynamic> makeLineStringFeature(
    List<List<double>> coordinates, {
    Map<String, dynamic>? properties,
  }) {
    return {
      'type': 'Feature',
      'geometry': {'type': 'LineString', 'coordinates': coordinates},
      'properties': properties ?? {},
    };
  }

  /// Construit un Feature Point d'arrêt.
  static Map<String, dynamic> makeStopFeature({
    required double lng,
    required double lat,
    required String name,
    String? stopId,
  }) {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lng, lat],
      },
      'properties': {
        'name': name,
        'type': 'stop',
        if (stopId != null) 'stop_id': stopId,
      },
    };
  }

  /// Remplace le LineString d'un FC par une nouvelle liste de coordonnées.
  /// Conserve tous les Features Point existants.
  static Map<String, dynamic> replaceLineString(
    Map<String, dynamic> fc,
    List<List<double>> newCoords,
  ) {
    final features = List<Map<String, dynamic>>.from(
      (fc['features'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
    // Retirer l'ancien LineString
    features.removeWhere((f) {
      final g = f['geometry'] as Map<String, dynamic>?;
      return g != null && g['type'] == 'LineString';
    });
    // Ajouter le nouveau en tête
    features.insert(0, makeLineStringFeature(newCoords));
    return {
      ...fc,
      'features': features,
    };
  }

  /// Remplace les Features Point (arrêts) par la nouvelle liste.
  /// Conserve le LineString existant.
  static Map<String, dynamic> replaceStops(
    Map<String, dynamic> fc,
    List<Map<String, dynamic>> newStops,
  ) {
    final features = <Map<String, dynamic>>[];
    for (final f in (fc['features'] as List? ?? [])
        .cast<Map<String, dynamic>>()) {
      final g = f['geometry'] as Map<String, dynamic>?;
      if (g != null && g['type'] == 'LineString') {
        features.add(f);
      }
    }
    features.addAll(newStops);
    return {
      ...fc,
      'features': features,
    };
  }

  /// FeatureCollection vide (pour une nouvelle ligne from scratch).
  static Map<String, dynamic> emptyFeatureCollection({
    required String lineNumber,
    required String direction,
  }) {
    return {
      'type': 'FeatureCollection',
      'properties': {
        'line': lineNumber,
        'direction': direction,
        'source': 'misy-editor',
        'num_stops': 0,
      },
      'features': [],
    };
  }
}
