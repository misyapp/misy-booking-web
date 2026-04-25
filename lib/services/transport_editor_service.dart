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
  static const String collPublished = 'transport_lines_published';

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
    if (snap.exists) return _hydrateDoc(snap.data()!);

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
      if (aller != null) 'aller': {'feature_collection_json': json.encode(aller)},
      if (retour != null) 'retour': {'feature_collection_json': json.encode(retour)},
      'created_at': FieldValue.serverTimestamp(),
      'last_updated': FieldValue.serverTimestamp(),
      'last_updated_by': AdminAuthService.instance.currentUid,
      'bootstrapped_from_asset': true,
    };
    await ref.set(payload);

    // Retour hydraté (forme Map attendue par les callers)
    return <String, dynamic>{
      ...payload,
      if (aller != null) 'aller': {'feature_collection': aller},
      if (retour != null) 'retour': {'feature_collection': retour},
    };
  }

  /// Firestore ne supporte pas les nested arrays (cf. LineString.coordinates).
  /// On stocke les FeatureCollections encodés en JSON string côté Firestore et
  /// on les hydrate (décode) en Map côté app.
  Map<String, dynamic> _hydrateDoc(Map<String, dynamic> raw) {
    final out = Map<String, dynamic>.from(raw);
    for (final key in ['aller', 'retour']) {
      final dir = raw[key];
      if (dir is Map) {
        final hydrated = Map<String, dynamic>.from(dir);
        final encoded = hydrated['feature_collection_json'];
        if (encoded is String) {
          hydrated['feature_collection'] =
              json.decode(encoded) as Map<String, dynamic>;
          hydrated.remove('feature_collection_json');
        }
        out[key] = hydrated;
      }
    }
    return out;
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

  /// Remplace entièrement une direction (tracé + arrêts) — utilisé par le
  /// sub-flow "Construire la ligne". Marque la direction à `modified`.
  Future<void> saveDirectionEdit({
    required String lineNumber,
    required String direction, // 'aller' | 'retour'
    required Map<String, dynamic> featureCollection,
    int? numStops,
    int? numVertices,
  }) async {
    final ref = _db.collection(collEdited).doc(lineNumber);
    await ref.set({
      direction: {
        'feature_collection_json': json.encode(featureCollection),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': AdminAuthService.instance.currentUid,
      },
      'last_updated': FieldValue.serverTimestamp(),
      'last_updated_by': AdminAuthService.instance.currentUid,
    }, SetOptions(merge: true));

    final key = direction == 'aller'
        ? EditorStep.aller.fieldKey
        : EditorStep.retour.fieldKey;
    await _db.collection(collValidations).doc(lineNumber).set({
      key: ValidationStatus.modified.code,
      // Remet le statut admin à pending et efface un éventuel motif de rejet
      // précédent : chaque nouvelle édition consultant = nouvelle review admin.
      '${direction}_admin_status': AdminStatus.pending.code,
      '${direction}_rejection_reason': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': AdminAuthService.instance.currentUid,
      'updated_by_email': AdminAuthService.instance.currentEmail,
    }, SetOptions(merge: true));

    await _appendLog(
      lineNumber: lineNumber,
      direction: direction,
      kind: 'direction',
      action: 'rebuilt',
      verticesAfter: numVertices,
      stopsAfter: numStops,
    );
  }

  // ───────────────────────── Admin review ─────────────────────────

  /// Valide la direction éditée par un consultant : copie le FC dans la
  /// collection prod (`transport_lines_published`) et met à jour le statut
  /// admin. L'app lit cette collection en priorité → la ligne arrive en
  /// prod sans rebuild Flutter.
  Future<void> approveDirection({
    required String lineNumber,
    required String direction, // 'aller' | 'retour'
    required Map<String, dynamic> featureCollection,
    Map<String, dynamic>? lineMetadata, // display_name, color, transport_type
  }) async {
    final now = FieldValue.serverTimestamp();
    final uid = AdminAuthService.instance.currentUid;
    final email = AdminAuthService.instance.currentEmail;

    // 1. Écrit le FC validé dans la collection prod.
    final pubRef = _db.collection(collPublished).doc(lineNumber);
    await pubRef.set({
      'line_number': lineNumber,
      if (lineMetadata != null) ...{
        if (lineMetadata['display_name'] != null)
          'display_name': lineMetadata['display_name'],
        if (lineMetadata['transport_type'] != null)
          'transport_type': lineMetadata['transport_type'],
        if (lineMetadata['color'] != null) 'color': lineMetadata['color'],
      },
      direction: {
        'feature_collection_json': json.encode(featureCollection),
        'published_at': now,
        'published_by_uid': uid,
        'published_by_email': email,
      },
      'last_updated': now,
    }, SetOptions(merge: true));

    // 2. MAJ statut admin dans transport_line_validations.
    await _db.collection(collValidations).doc(lineNumber).set({
      '${direction}_admin_status': AdminStatus.approved.code,
      '${direction}_reviewed_at': now,
      '${direction}_reviewed_by_email': email,
      // Efface un éventuel motif de rejet précédent
      '${direction}_rejection_reason': FieldValue.delete(),
      'updated_at': now,
    }, SetOptions(merge: true));

    await _appendLog(
      lineNumber: lineNumber,
      direction: direction,
      kind: 'admin_review',
      action: 'approved',
    );
  }

  /// Rejette la direction : remet le statut consultant à `pending` (→ il
  /// retrouve la ligne à refaire dans son dashboard) et enregistre un motif.
  Future<void> rejectDirection({
    required String lineNumber,
    required String direction, // 'aller' | 'retour'
    required String reason,
  }) async {
    final now = FieldValue.serverTimestamp();
    final email = AdminAuthService.instance.currentEmail;

    await _db.collection(collValidations).doc(lineNumber).set({
      '${direction}_admin_status': AdminStatus.rejected.code,
      '${direction}_reviewed_at': now,
      '${direction}_reviewed_by_email': email,
      '${direction}_rejection_reason': reason,
      // Rebascule le statut consultant à `pending` → force le refaire
      direction: ValidationStatus.pending.code,
      'updated_at': now,
    }, SetOptions(merge: true));

    await _appendLog(
      lineNumber: lineNumber,
      direction: direction,
      kind: 'admin_review',
      action: 'rejected',
    );
  }

  /// Charge la FC publiée pour une direction donnée (null si pas publiée).
  /// Utilisé par TransportLinesService pour lire la prod Firestore en
  /// priorité sur l'asset bundlé.
  Future<Map<String, dynamic>?> loadPublishedFeatureCollection(
      String lineNumber, String direction) async {
    final snap = await _db.collection(collPublished).doc(lineNumber).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    final dir = data[direction];
    if (dir is! Map) return null;
    final encoded = dir['feature_collection_json'];
    if (encoded is! String) return null;
    try {
      return json.decode(encoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────── Annotations consultant ─────────────────────────

  /// Pose / met à jour la note libre + le drapeau couleur d'une direction.
  /// Passer `note: null` (ou chaîne vide) ou `flag: null` les efface.
  /// Ne touche PAS aux autres champs (status, admin review).
  Future<void> setConsultantAnnotation({
    required String lineNumber,
    required String direction, // 'aller' | 'retour'
    String? note,
    ConsultantFlag? flag,
  }) async {
    final cleanNote = note?.trim();
    final ref = _db.collection(collValidations).doc(lineNumber);
    await ref.set({
      '${direction}_consultant_note':
          (cleanNote == null || cleanNote.isEmpty)
              ? FieldValue.delete()
              : cleanNote,
      '${direction}_consultant_flag':
          flag == null ? FieldValue.delete() : flag.code,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': AdminAuthService.instance.currentUid,
      'updated_by_email': AdminAuthService.instance.currentEmail,
    }, SetOptions(merge: true));

    await _appendLog(
      lineNumber: lineNumber,
      direction: direction,
      kind: 'annotation',
      action: 'noted',
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
        'feature_collection_json': json.encode(allerFeatureCollection),
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': AdminAuthService.instance.currentUid,
      },
      'retour': {
        'feature_collection_json': json.encode(retourFeatureCollection),
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
