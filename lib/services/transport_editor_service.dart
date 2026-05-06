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

  /// Charge les métadonnées scalaires (display_name, color, cooperative,
  /// schedule, price_ariary, is_new_line, is_deleted, et les statuts admin
  /// par direction) pour TOUTES les lignes de `transport_lines_edited`.
  /// Inclut donc les lignes 100% Firestore créées par les consultants qui
  /// ne sont pas encore (ou pas du tout) publiées.
  ///
  /// Ne charge PAS les feature_collection (champ volumineux). Utilisé par le
  /// dashboard consultant pour afficher SES lignes en cours, peu importe leur
  /// statut admin.
  Future<Map<String, Map<String, dynamic>>> loadAllEditedMetadata() async {
    try {
      final snap = await _db.collection(collEdited).get();
      final out = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        for (final dir in ['aller', 'retour']) {
          if (data[dir] is Map) {
            final m = Map<String, dynamic>.from(data[dir] as Map);
            m.remove('feature_collection_json');
            data[dir] = m;
          }
        }
        out[doc.id] = data;
      }
      return out;
    } catch (e) {
      myCustomPrintStatement('loadAllEditedMetadata KO: $e');
      return {};
    }
  }

  /// Charge un snapshot live des codes + nom-normalisé→code depuis edited+
  /// published. Utilisé par `createNewLine` pour la vérification atomique
  /// d'unicité juste avant l'écriture, et par l'UI pour le check pré-submit.
  /// **Ne couvre pas le manifest bundlé** — l'UI est responsable de fournir
  /// ces codes-là. La normalisation des noms est faite via [normalizeName].
  Future<({Set<String> codes, Map<String, String> namesByCode})>
      loadFirestoreCodesAndNames() async {
    final codes = <String>{};
    final namesByCode = <String, String>{};
    void collect(String code, dynamic raw) {
      if (raw is! String) return;
      final norm = normalizeName(raw);
      if (norm.isEmpty) return;
      namesByCode[norm] = code;
    }

    final results = await Future.wait([
      _db.collection(collEdited).get(),
      _db.collection(collPublished).get(),
    ]);
    for (final snap in results) {
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['is_deleted'] == true) continue;
        codes.add(doc.id);
        collect(doc.id, data['display_name']);
      }
    }
    return (codes: codes, namesByCode: namesByCode);
  }

  /// Normalise un nom affiché pour la comparaison d'unicité : lowercase,
  /// espaces multiples → single, trim, accents PAS retirés (volontairement).
  static String normalizeName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Charge les métadonnées publiées (display_name, color, cooperative,
  /// schedule, is_deleted, etc.) pour toutes les lignes. Utilisé par
  /// `TransportLinesService.getAllLineMetadata` pour fusionner les overrides
  /// admin sur le manifest bundlé. Retourne un map `{lineNumber: data}`.
  ///
  /// Ne lit PAS les feature_collection (gros) — uniquement les champs scalaires.
  Future<Map<String, Map<String, dynamic>>> loadAllPublishedMetadata() async {
    try {
      final snap = await _db.collection(collPublished).get();
      final out = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        // On retire les FC volumineux — pas utile pour le manifest.
        for (final dir in ['aller', 'retour']) {
          if (data[dir] is Map) {
            final m = Map<String, dynamic>.from(data[dir] as Map);
            m.remove('feature_collection_json');
            data[dir] = m;
          }
        }
        out[doc.id] = data;
      }
      return out;
    } catch (e) {
      myCustomPrintStatement('loadAllPublishedMetadata KO: $e');
      return {};
    }
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

  /// Admin retouche le tracé/arrêts proposés par le consultant et publie
  /// directement. Combine [saveDirectionEdit] + [approveDirection] : écrit
  /// la FC dans transport_lines_edited (pour que le consultant voie la
  /// version admin la prochaine fois), publie en prod, marque
  /// admin_status=approved. Garde le statut consultant à `modified` —
  /// l'audit `admin_edited` trace le fait que l'admin a modifié.
  Future<void> adminEditAndPublish({
    required String lineNumber,
    required String direction, // 'aller' | 'retour'
    required Map<String, dynamic> featureCollection,
    Map<String, dynamic>? lineMetadata,
    int? numStops,
    int? numVertices,
  }) async {
    final now = FieldValue.serverTimestamp();
    final uid = AdminAuthService.instance.currentUid;
    final email = AdminAuthService.instance.currentEmail;
    final encoded = json.encode(featureCollection);

    // 1. Écrit dans transport_lines_edited (la prochaine ouverture du
    // wizard côté consultant chargera la version admin).
    await _db.collection(collEdited).doc(lineNumber).set({
      direction: {
        'feature_collection_json': encoded,
        'updated_at': now,
        'updated_by': uid,
      },
      'last_updated': now,
      'last_updated_by': uid,
    }, SetOptions(merge: true));

    // 2. Publie en prod (transport_lines_published).
    await _db.collection(collPublished).doc(lineNumber).set({
      'line_number': lineNumber,
      if (lineMetadata != null) ...{
        if (lineMetadata['display_name'] != null)
          'display_name': lineMetadata['display_name'],
        if (lineMetadata['transport_type'] != null)
          'transport_type': lineMetadata['transport_type'],
        if (lineMetadata['color'] != null) 'color': lineMetadata['color'],
      },
      direction: {
        'feature_collection_json': encoded,
        'published_at': now,
        'published_by_uid': uid,
        'published_by_email': email,
      },
      'last_updated': now,
    }, SetOptions(merge: true));

    // 3. Marque admin_status=approved + efface motif rejet précédent.
    await _db.collection(collValidations).doc(lineNumber).set({
      '${direction}_admin_status': AdminStatus.approved.code,
      '${direction}_reviewed_at': now,
      '${direction}_reviewed_by_email': email,
      '${direction}_rejection_reason': FieldValue.delete(),
      'updated_at': now,
    }, SetOptions(merge: true));

    // 4. Audit
    await _appendLog(
      lineNumber: lineNumber,
      direction: direction,
      kind: 'admin_review',
      action: 'admin_edited',
      verticesAfter: numVertices,
      stopsAfter: numStops,
    );
  }

  /// Charge les FC éditées (transport_lines_edited) pour les lignes touchées
  /// par un consultant donné. Retourne `{lineNumber: {direction: fc}}`.
  /// Hydrate les `feature_collection_json` en Map. Utilisé par la carte
  /// admin filtrée par profil consultant.
  Future<Map<String, Map<String, Map<String, dynamic>>>>
      loadEditedForConsultant(
    String email,
    Map<String, TransportLineValidation> validations,
  ) async {
    final lineNumbers = <String>{
      for (final v in validations.values)
        if (v.updatedByEmail == email) v.lineNumber,
    };
    return loadEditedForLines(lineNumbers);
  }

  /// Charge les FC éditées (transport_lines_edited) pour un set de lignes
  /// donné. Retourne `{lineNumber: {direction: fc}}`. Hydrate les
  /// `feature_collection_json` en Map. Utilisé par la carte éditeur pour
  /// afficher les submissions en cours en pointillé.
  Future<Map<String, Map<String, Map<String, dynamic>>>>
      loadEditedForLines(Iterable<String> lineNumbersIter) async {
    final lineNumbers = lineNumbersIter.toList();
    if (lineNumbers.isEmpty) return {};

    final out = <String, Map<String, Map<String, dynamic>>>{};
    // Firestore whereIn accepte 30 valeurs max → chunker.
    for (var i = 0; i < lineNumbers.length; i += 30) {
      final chunk = lineNumbers.sublist(
          i, i + 30 > lineNumbers.length ? lineNumbers.length : i + 30);
      final snap = await _db
          .collection(collEdited)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final perDir = <String, Map<String, dynamic>>{};
        for (final key in ['aller', 'retour']) {
          final dir = data[key];
          if (dir is! Map) continue;
          final encoded = dir['feature_collection_json'];
          if (encoded is! String) continue;
          try {
            perDir[key] = json.decode(encoded) as Map<String, dynamic>;
          } catch (_) {}
        }
        if (perDir.isNotEmpty) out[doc.id] = perDir;
      }
    }
    return out;
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

  // ───────────────────────── Métadonnées ligne ─────────────────────────

  /// Édite les métadonnées d'une ligne (nom affiché, type, couleur,
  /// coopérative, horaires) sans toucher au tracé. Écrit dans
  /// `transport_lines_edited` (visible immédiatement par le consultant) ET
  /// `transport_lines_published` (visible côté app prod). Marque admin_status
  /// inchangé — c'est volontairement une édition "soft" qui ne refait pas
  /// repasser la ligne par la review.
  ///
  /// Passer une chaîne vide / null à un champ pour l'effacer côté Firestore.
  Future<void> updateLineMetadata({
    required String lineNumber,
    String? displayName,
    String? transportType,
    String? colorHex,
    String? cooperative,
    Map<String, dynamic>? schedule,
    int? priceAriary,
    bool clearCooperative = false,
    bool clearSchedule = false,
    bool clearPrice = false,
  }) async {
    final now = FieldValue.serverTimestamp();
    final uid = AdminAuthService.instance.currentUid;
    final email = AdminAuthService.instance.currentEmail;

    // Si on change le nom affiché → vérifier qu'aucune AUTRE ligne ne porte
    // déjà ce nom (case-insensitive). Évite que 2 consultants créent
    // accidentellement le même libellé sur des codes différents.
    if (displayName != null && displayName.trim().isNotEmpty) {
      final norm = normalizeName(displayName);
      final snap = await loadFirestoreCodesAndNames();
      final owner = snap.namesByCode[norm];
      if (owner != null && owner != lineNumber) {
        throw LineDisplayNameExistsException(
            requested: displayName.trim(), conflictingCode: owner);
      }
    }

    final patch = <String, dynamic>{
      'last_updated': now,
      'last_updated_by': uid,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      patch['display_name'] = displayName.trim();
    }
    if (transportType != null && transportType.trim().isNotEmpty) {
      patch['transport_type'] = transportType.trim();
    }
    if (colorHex != null && colorHex.trim().isNotEmpty) {
      patch['color'] = colorHex.trim();
    }
    if (clearCooperative) {
      patch['cooperative'] = FieldValue.delete();
    } else if (cooperative != null && cooperative.trim().isNotEmpty) {
      patch['cooperative'] = cooperative.trim();
    }
    if (clearSchedule) {
      patch['schedule'] = FieldValue.delete();
    } else if (schedule != null) {
      patch['schedule'] = schedule;
    }
    if (clearPrice) {
      patch['price_ariary'] = FieldValue.delete();
    } else if (priceAriary != null) {
      patch['price_ariary'] = priceAriary;
    }

    // 1. Écrit dans transport_lines_edited (source de vérité session).
    await _db.collection(collEdited).doc(lineNumber).set(
          patch,
          SetOptions(merge: true),
        );

    // 2. Mirror dans transport_lines_published. La ligne y existe déjà
    //    (publiée précédemment) ou pas — `merge: true` gère les 2 cas.
    //    Pour les lignes jamais publiées, on crée juste les champs scalaires
    //    sans FC : l'app fallback sur l'asset bundlé pour le tracé, mais
    //    affiche bien le nouveau nom/coopérative/horaire.
    final pubPatch = Map<String, dynamic>.from(patch)
      ..['line_number'] = lineNumber
      ..remove('last_updated_by')
      ..['edited_metadata_at'] = now
      ..['edited_metadata_by_email'] = email;
    await _db.collection(collPublished).doc(lineNumber).set(
          pubPatch,
          SetOptions(merge: true),
        );

    await _appendLog(
      lineNumber: lineNumber,
      direction: 'aller', // n/a, kind=metadata
      kind: 'metadata',
      action: 'updated',
    );
  }

  // ───────────────────────── Suppression ─────────────────────────

  /// Le consultant demande la suppression d'une ligne. Écrit un drapeau
  /// `delete_requested` dans `transport_line_validations`, visible dans la
  /// queue admin. La ligne reste fonctionnelle côté app tant que l'admin n'a
  /// pas confirmé — la suppression réelle est `confirmDeleteLine`.
  Future<void> requestDeleteLine({
    required String lineNumber,
    required String reason,
  }) async {
    final now = FieldValue.serverTimestamp();
    final email = AdminAuthService.instance.currentEmail;
    final uid = AdminAuthService.instance.currentUid;

    await _db.collection(collValidations).doc(lineNumber).set({
      'delete_requested': true,
      'delete_request_reason': reason,
      'delete_requested_at': now,
      'delete_requested_by_email': email,
      'updated_at': now,
      'updated_by': uid,
      'updated_by_email': email,
    }, SetOptions(merge: true));

    // Mirror le flag dans transport_lines_edited pour que le wizard puisse
    // afficher l'état "demande de suppression en cours" sans nouveau stream.
    await _db.collection(collEdited).doc(lineNumber).set({
      'delete_requested': true,
      'delete_request_reason': reason,
      'last_updated': now,
    }, SetOptions(merge: true));

    await _appendLog(
      lineNumber: lineNumber,
      direction: 'aller',
      kind: 'delete',
      action: 'requested',
    );
  }

  /// Le consultant annule sa demande de suppression. Efface les drapeaux
  /// `delete_requested*` dans les 2 collections.
  Future<void> cancelDeleteRequest(String lineNumber) async {
    final now = FieldValue.serverTimestamp();
    final email = AdminAuthService.instance.currentEmail;

    await _db.collection(collValidations).doc(lineNumber).set({
      'delete_requested': FieldValue.delete(),
      'delete_request_reason': FieldValue.delete(),
      'delete_requested_at': FieldValue.delete(),
      'delete_requested_by_email': FieldValue.delete(),
      'updated_at': now,
      'updated_by_email': email,
    }, SetOptions(merge: true));

    await _db.collection(collEdited).doc(lineNumber).set({
      'delete_requested': FieldValue.delete(),
      'delete_request_reason': FieldValue.delete(),
      'last_updated': now,
    }, SetOptions(merge: true));

    await _appendLog(
      lineNumber: lineNumber,
      direction: 'aller',
      kind: 'delete',
      action: 'cancelled',
    );
  }

  /// Admin confirme la suppression : pose `is_deleted=true` dans
  /// `transport_lines_published` (filtré par l'app + le dashboard) et marque
  /// `deleted_at` dans `transport_lines_edited`. Conserve les docs pour
  /// l'audit — pas de delete physique.
  Future<void> confirmDeleteLine({
    required String lineNumber,
    String? adminNote,
  }) async {
    final now = FieldValue.serverTimestamp();
    final email = AdminAuthService.instance.currentEmail;
    final uid = AdminAuthService.instance.currentUid;

    await _db.collection(collPublished).doc(lineNumber).set({
      'line_number': lineNumber,
      'is_deleted': true,
      'deleted_at': now,
      'deleted_by_email': email,
      if (adminNote != null && adminNote.trim().isNotEmpty)
        'deleted_admin_note': adminNote.trim(),
      'last_updated': now,
    }, SetOptions(merge: true));

    await _db.collection(collEdited).doc(lineNumber).set({
      'is_deleted': true,
      'deleted_at': now,
      'deleted_by': uid,
      'last_updated': now,
    }, SetOptions(merge: true));

    await _appendLog(
      lineNumber: lineNumber,
      direction: 'aller',
      kind: 'delete',
      action: 'confirmed',
    );
  }

  /// Admin restaure une ligne supprimée. Efface le flag `is_deleted`.
  Future<void> restoreDeletedLine(String lineNumber) async {
    final now = FieldValue.serverTimestamp();
    await _db.collection(collPublished).doc(lineNumber).set({
      'is_deleted': FieldValue.delete(),
      'deleted_at': FieldValue.delete(),
      'deleted_by_email': FieldValue.delete(),
      'deleted_admin_note': FieldValue.delete(),
      'last_updated': now,
    }, SetOptions(merge: true));
    await _db.collection(collEdited).doc(lineNumber).set({
      'is_deleted': FieldValue.delete(),
      'deleted_at': FieldValue.delete(),
      'deleted_by': FieldValue.delete(),
      'last_updated': now,
    }, SetOptions(merge: true));
    await _appendLog(
      lineNumber: lineNumber,
      direction: 'aller',
      kind: 'delete',
      action: 'restored',
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
    String? cooperative,
    Map<String, dynamic>? schedule,
    int? priceAriary,
  }) async {
    final ref = _db.collection(collEdited).doc(lineNumber);

    // Vérification atomique d'unicité juste avant l'écriture (Firestore est
    // notre source de vérité pour edited+published — le manifest bundlé,
    // lui, est checké côté UI avant submit).
    final snap = await loadFirestoreCodesAndNames();
    if (snap.codes.contains(lineNumber)) {
      throw LineCodeExistsException(code: lineNumber);
    }
    final norm = normalizeName(displayName);
    final owner = snap.namesByCode[norm];
    if (owner != null) {
      throw LineDisplayNameExistsException(
          requested: displayName.trim(), conflictingCode: owner);
    }

    final coopClean = cooperative?.trim();

    await ref.set({
      'line_number': lineNumber,
      'display_name': displayName,
      'transport_type': transportType,
      'color': colorHex,
      'is_bundled': true,
      'is_new_line': true,
      if (coopClean != null && coopClean.isNotEmpty) 'cooperative': coopClean,
      if (schedule != null) 'schedule': schedule,
      if (priceAriary != null) 'price_ariary': priceAriary,
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

// ───────────────────── Exceptions d'unicité ─────────────────────

/// Levée par [TransportEditorService.createNewLine] quand le code/numéro
/// demandé existe déjà dans `transport_lines_edited` ou
/// `transport_lines_published`. L'UI catch l'exception pour afficher un
/// message dédié (suggestion de suffixe).
class LineCodeExistsException implements Exception {
  final String code;
  LineCodeExistsException({required this.code});
  @override
  String toString() =>
      'Le code « $code » est déjà utilisé. Ajoute un suffixe (bis, A, B, '
      'nom de quartier…) pour distinguer les lignes.';
}

/// Levée par [TransportEditorService.createNewLine] et
/// [TransportEditorService.updateLineMetadata] quand le nom affiché demandé
/// existe déjà sur une autre ligne (case-insensitive). [conflictingCode]
/// = code de la ligne qui porte déjà ce nom.
class LineDisplayNameExistsException implements Exception {
  final String requested;
  final String conflictingCode;
  LineDisplayNameExistsException({
    required this.requested,
    required this.conflictingCode,
  });
  @override
  String toString() =>
      'Le nom « $requested » est déjà utilisé par la ligne $conflictingCode. '
      'Si c\'est la même ligne, édite l\'existante. Sinon précise le nom '
      '(couleur, quartier, opérateur).';
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
