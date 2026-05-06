import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';

/// Métadonnées d'une direction (aller ou retour) depuis le manifest
class RouteMetadata {
  final String direction;
  final int numStops;
  final String? assetPath;
  final String? remoteUrl;

  const RouteMetadata({
    required this.direction,
    required this.numStops,
    this.assetPath,
    this.remoteUrl,
  });

  factory RouteMetadata.fromJson(Map<String, dynamic> json) {
    return RouteMetadata(
      direction: json['direction'] ?? '',
      numStops: json['num_stops'] ?? 0,
      assetPath: json['asset_path'],
      remoteUrl: json['remote_url'],
    );
  }
}

/// Horaires d'exploitation d'une ligne de transport.
///
/// Tous les champs sont optionnels — une ligne peut n'avoir que la coopérative,
/// ou seulement des horaires partiels. Affichage côté app fait du best-effort.
class LineSchedule {
  /// Première départ de la journée (HH:mm), ex: "05:30".
  final String? firstDeparture;

  /// Dernier départ de la journée (HH:mm), ex: "19:00".
  final String? lastDeparture;

  /// Intervalle moyen entre 2 départs (minutes). Null = pas de fréquence régulière.
  final int? frequencyMin;

  /// Jours d'exploitation (codes courts EN). Default = tous les jours.
  /// Valeurs valides : mon, tue, wed, thu, fri, sat, sun.
  final List<String> daysOfOperation;

  /// Note libre pour tout ce qui ne rentre pas dans les champs structurés
  /// (ex: "pas de service les jours fériés", "horaires réduits le dimanche").
  final String? notes;

  const LineSchedule({
    this.firstDeparture,
    this.lastDeparture,
    this.frequencyMin,
    this.daysOfOperation = const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
    this.notes,
  });

  bool get isEmpty =>
      firstDeparture == null &&
      lastDeparture == null &&
      frequencyMin == null &&
      (notes == null || notes!.trim().isEmpty);

  factory LineSchedule.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LineSchedule();
    final days = json['days_of_operation'];
    return LineSchedule(
      firstDeparture: json['first_departure'] as String?,
      lastDeparture: json['last_departure'] as String?,
      frequencyMin: (json['frequency_min'] as num?)?.toInt(),
      daysOfOperation: days is List
          ? days.map((d) => d.toString()).toList()
          : const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (firstDeparture != null) 'first_departure': firstDeparture,
        if (lastDeparture != null) 'last_departure': lastDeparture,
        if (frequencyMin != null) 'frequency_min': frequencyMin,
        'days_of_operation': daysOfOperation,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}

/// État de publication d'une ligne (utilisé uniquement par les écrans
/// éditeur/admin pour afficher un badge — l'app prod ne l'expose jamais
/// puisqu'elle ne consomme que les lignes publiées).
enum LinePublicationState {
  /// Présente dans `transport_lines_published` (visible côté app prod).
  published,

  /// Présente uniquement dans `transport_lines_edited` (consultant a créé
  /// la ligne, jamais validée par l'admin → invisible côté app prod).
  unpublishedNew,

  /// Présente dans `transport_lines_edited` avec au moins une direction
  /// rejetée par l'admin → consultant doit refaire avant publication.
  unpublishedRejected,
}

/// Métadonnées d'une ligne de transport depuis le manifest
class LineMetadata {
  final String lineNumber;
  final String displayName;
  final String transportType;
  final String colorHex;
  final bool isBundled;
  final RouteMetadata? aller;
  final RouteMetadata? retour;

  /// Coopérative / opérateur de la ligne (ex: "Kofifa", "Cotrabe"). Posé par
  /// le consultant ou l'admin lors de l'édition. Null = pas encore renseigné.
  final String? cooperative;

  /// Horaires d'exploitation. Null = pas encore renseignés.
  final LineSchedule? schedule;

  /// Prix du trajet en Ariary (tarif unique). Null = pas encore renseigné.
  /// Stocké en Firestore comme `price_ariary` (entier).
  final int? priceAriary;

  /// État de publication (par défaut `published`). Renseigné uniquement par
  /// `getAllLineMetadataForEditor()` pour permettre au dashboard consultant
  /// d'afficher un badge sur les lignes pas encore en prod.
  final LinePublicationState publicationState;

  const LineMetadata({
    required this.lineNumber,
    required this.displayName,
    required this.transportType,
    required this.colorHex,
    required this.isBundled,
    this.aller,
    this.retour,
    this.cooperative,
    this.schedule,
    this.priceAriary,
    this.publicationState = LinePublicationState.published,
  });

  factory LineMetadata.fromJson(Map<String, dynamic> json) {
    return LineMetadata(
      lineNumber: json['line_number'],
      displayName: json['display_name'],
      transportType: json['transport_type'],
      colorHex: json['color'],
      isBundled: json['is_bundled'] ?? false,
      aller: json['aller'] != null
          ? RouteMetadata.fromJson(json['aller'])
          : null,
      retour: json['retour'] != null
          ? RouteMetadata.fromJson(json['retour'])
          : null,
      cooperative: (json['cooperative'] as String?)?.trim().isEmpty == true
          ? null
          : json['cooperative'] as String?,
      schedule: json['schedule'] is Map
          ? LineSchedule.fromJson(
              Map<String, dynamic>.from(json['schedule'] as Map))
          : null,
      priceAriary: (json['price_ariary'] as num?)?.toInt(),
    );
  }

  /// Reproduit l'objet en remplaçant les champs fournis. Utile pour fusionner
  /// les overrides Firestore (cooperative/schedule/prix édités) sur les
  /// métadonnées du manifest.
  LineMetadata copyWith({
    String? displayName,
    String? colorHex,
    String? transportType,
    String? cooperative,
    LineSchedule? schedule,
    int? priceAriary,
    LinePublicationState? publicationState,
  }) {
    return LineMetadata(
      lineNumber: lineNumber,
      displayName: displayName ?? this.displayName,
      transportType: transportType ?? this.transportType,
      colorHex: colorHex ?? this.colorHex,
      isBundled: isBundled,
      aller: aller,
      retour: retour,
      cooperative: cooperative ?? this.cooperative,
      schedule: schedule ?? this.schedule,
      priceAriary: priceAriary ?? this.priceAriary,
      publicationState: publicationState ?? this.publicationState,
    );
  }

  bool get isUnpublished =>
      publicationState != LinePublicationState.published;

  int get colorValue {
    try {
      return int.parse(colorHex.replaceFirst('0x', ''), radix: 16);
    } catch (_) {
      return 0xFF2196F3; // Bleu par défaut
    }
  }
}

/// Service pour charger et gérer les lignes de transport depuis le manifest et GeoJSON
class TransportLinesService {
  static TransportLinesService? _instance;
  static TransportLinesService get instance {
    _instance ??= TransportLinesService._();
    return _instance!;
  }

  TransportLinesService._();

  /// Cache des lignes groupées (toutes les lignes chargées)
  final Map<String, TransportLineGroup> _linesCache = {};

  /// Manifest des lignes disponibles
  Map<String, LineMetadata>? _manifest;

  /// Graphe du réseau pour le calcul d'itinéraire
  TransportGraph? _transportGraph;

  /// Durée cache remote (7 jours)
  static const int _cacheDurationMs = 7 * 24 * 60 * 60 * 1000;

  /// Charge le manifest depuis les assets
  Future<void> _loadManifest() async {
    if (_manifest != null) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/transport_lines/manifest.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final lines = data['lines'] as List<dynamic>;

      _manifest = {};
      for (final lineData in lines) {
        final metadata = LineMetadata.fromJson(lineData as Map<String, dynamic>);
        _manifest![metadata.lineNumber] = metadata;
      }

      myCustomPrintStatement(
        'Manifest chargé: ${_manifest!.length} lignes '
        '(${_manifest!.values.where((m) => m.isBundled).length} embarquées)',
      );
    } catch (e) {
      myCustomPrintStatement('Erreur chargement manifest: $e');
      _manifest = {};
    }
  }

  /// Charge toutes les lignes de transport (bundled + remote)
  Future<List<TransportLineGroup>> loadAllLines() async {
    // Retourner le cache complet si déjà rempli avec toutes les lignes
    if (_linesCache.isNotEmpty && _manifest != null && _linesCache.length >= _manifest!.length) {
      myCustomPrintStatement('Lignes de transport chargées depuis le cache (${_linesCache.length})');
      return _linesCache.values.toList();
    }

    await _loadManifest();
    if (_manifest == null || _manifest!.isEmpty) return [];

    myCustomPrintStatement('Chargement de ${_manifest!.length} lignes de transport...');

    // Charger toutes les lignes (bundled + remote) en parallèle
    final futures = <Future<void>>[];
    for (final metadata in _manifest!.values) {
      if (_linesCache.containsKey(metadata.lineNumber)) continue;
      futures.add(_loadAndCacheLine(metadata));
    }
    await Future.wait(futures);

    myCustomPrintStatement('${_linesCache.length}/${_manifest!.length} lignes chargées');
    return _linesCache.values.toList();
  }

  Future<void> _loadAndCacheLine(LineMetadata metadata) async {
    try {
      final lineGroup = await _loadLineFromMetadata(metadata);
      if (lineGroup != null) {
        _linesCache[metadata.lineNumber] = lineGroup;
      }
    } catch (e) {
      myCustomPrintStatement(
        'Erreur chargement ligne ${metadata.lineNumber}: $e',
      );
    }
  }

  /// Charge une ligne spécifique (avec lazy loading pour les remote)
  Future<TransportLineGroup?> loadLine(String lineNumber) async {
    // Vérifier le cache
    if (_linesCache.containsKey(lineNumber)) {
      return _linesCache[lineNumber];
    }

    await _loadManifest();
    final metadata = _manifest?[lineNumber];
    if (metadata == null) return null;

    final lineGroup = await _loadLineFromMetadata(metadata);
    if (lineGroup != null) {
      _linesCache[lineNumber] = lineGroup;
    }

    return lineGroup;
  }

  /// Retourne la liste des métadonnées de toutes les lignes disponibles
  /// (sans charger les GeoJSON, juste les infos du manifest).
  ///
  /// Fusionne les overrides Firestore `transport_lines_published` (nom,
  /// couleur, coopérative, horaires édités par les consultants + validés par
  /// l'admin) sur le manifest bundlé. Filtre les lignes marquées `is_deleted`.
  Future<List<LineMetadata>> getAllLineMetadata() async {
    await _loadManifest();
    final base = _manifest?.values.toList() ?? [];
    final overrides = await TransportEditorService.instance
        .loadAllPublishedMetadata();
    final out = <LineMetadata>[];
    final seen = <String>{};
    for (final m in base) {
      final ov = overrides[m.lineNumber];
      if (ov?['is_deleted'] == true) continue; // ligne supprimée
      seen.add(m.lineNumber);
      out.add(_overlay(m, ov));
    }
    // Lignes 100% Firestore (créées par consultant après build de l'app et
    // donc absentes du manifest bundlé). On les expose ici pour qu'elles
    // apparaissent dans le dashboard et l'app prod.
    overrides.forEach((line, data) {
      if (seen.contains(line)) return;
      if (data['is_deleted'] == true) return;
      out.add(LineMetadata(
        lineNumber: line,
        displayName: (data['display_name'] as String?) ?? 'Ligne $line',
        transportType: (data['transport_type'] as String?) ?? 'bus',
        colorHex: (data['color'] as String?) ?? '0xFF1565C0',
        isBundled: false,
        cooperative: (data['cooperative'] as String?)?.trim().isEmpty == true
            ? null
            : data['cooperative'] as String?,
        schedule: data['schedule'] is Map
            ? LineSchedule.fromJson(
                Map<String, dynamic>.from(data['schedule'] as Map))
            : null,
      ));
    });
    return out;
  }

  /// Applique les overrides Firestore sur une `LineMetadata` du manifest.
  /// Garde les valeurs du manifest pour les champs non présents.
  LineMetadata _overlay(LineMetadata m, Map<String, dynamic>? ov) {
    if (ov == null) return m;
    return m.copyWith(
      displayName: ov['display_name'] as String?,
      colorHex: ov['color'] as String?,
      transportType: ov['transport_type'] as String?,
      cooperative: (ov['cooperative'] as String?)?.trim().isEmpty == true
          ? null
          : ov['cooperative'] as String?,
      schedule: ov['schedule'] is Map
          ? LineSchedule.fromJson(
              Map<String, dynamic>.from(ov['schedule'] as Map))
          : null,
      priceAriary: (ov['price_ariary'] as num?)?.toInt(),
    );
  }

  /// Variante de [getAllLineMetadata] destinée aux **écrans éditeur/admin**.
  /// Inclut en plus les lignes 100% Firestore présentes dans
  /// `transport_lines_edited` mais pas (encore) dans `transport_lines_published`
  /// — typiquement : nouvelles lignes créées par un consultant en attente
  /// de review, ou lignes rejetées par l'admin.
  ///
  /// Marque ces lignes avec `publicationState` ∈
  /// {`unpublishedNew`, `unpublishedRejected`} pour permettre au dashboard
  /// d'afficher un badge.
  ///
  /// L'app prod doit continuer à appeler [getAllLineMetadata] (qui filtre
  /// les non-publiées, sinon des lignes non validées remonteraient en prod).
  Future<List<LineMetadata>> getAllLineMetadataForEditor() async {
    await _loadManifest();
    final base = _manifest?.values.toList() ?? [];
    final published = await TransportEditorService.instance
        .loadAllPublishedMetadata();
    final edited = await TransportEditorService.instance
        .loadAllEditedMetadata();
    final out = <LineMetadata>[];
    final seen = <String>{};

    for (final m in base) {
      final pub = published[m.lineNumber];
      if (pub?['is_deleted'] == true) continue;
      seen.add(m.lineNumber);
      // Les lignes du manifest sont par définition publiées (on les overlay
      // avec les overrides published si présents). edited n'est pas overlayé
      // ici — il est juste utilisé comme source pour les nouvelles lignes
      // ci-dessous.
      out.add(_overlay(m, pub));
    }

    // Lignes 100% Firestore (présentes dans edited et/ou published mais pas
    // dans le manifest). On donne priorité aux données published si elles
    // existent (= ligne approuvée par admin), sinon on prend celles d'edited.
    final firestoreCodes = {...published.keys, ...edited.keys};
    for (final code in firestoreCodes) {
      if (seen.contains(code)) continue;
      final pub = published[code];
      final ed = edited[code];
      if (pub?['is_deleted'] == true || ed?['is_deleted'] == true) continue;

      final src = pub ?? ed!;
      LinePublicationState state;
      if (pub != null) {
        // Présente dans published → publiée. Si elle est aussi dans edited
        // avec une dir rejetée, c'est qu'une nouvelle édition a été demandée
        // par l'admin → on garde published comme état (la prod l'utilise).
        state = LinePublicationState.published;
      } else {
        // Pas dans published → nouvelle ligne. On distingue 2 cas :
        // - au moins une dir rejetée par l'admin → unpublishedRejected
        // - sinon → unpublishedNew (en attente de 1ère review)
        final allerRejected = ed?['aller_admin_status'] == 'rejected';
        final retourRejected = ed?['retour_admin_status'] == 'rejected';
        state = (allerRejected || retourRejected)
            ? LinePublicationState.unpublishedRejected
            : LinePublicationState.unpublishedNew;
      }

      out.add(LineMetadata(
        lineNumber: code,
        displayName: (src['display_name'] as String?) ?? 'Ligne $code',
        transportType: (src['transport_type'] as String?) ?? 'bus',
        colorHex: (src['color'] as String?) ?? '0xFF1565C0',
        isBundled: false,
        cooperative: (src['cooperative'] as String?)?.trim().isEmpty == true
            ? null
            : src['cooperative'] as String?,
        schedule: src['schedule'] is Map
            ? LineSchedule.fromJson(
                Map<String, dynamic>.from(src['schedule'] as Map))
            : null,
        priceAriary: (src['price_ariary'] as num?)?.toInt(),
        publicationState: state,
      ));
    }
    return out;
  }

  /// Snapshot synchrone des codes + nom-normalisé→code connus côté UI.
  /// Source : manifest bundlé chargé en mémoire + appel Firestore live.
  /// Utilisé par le formulaire création pour le check pré-submit et la
  /// suggestion live "codes déjà utilisés".
  Future<({Set<String> codes, Map<String, String> namesByCode})>
      getExistingCodesAndDisplayNames() async {
    await _loadManifest();
    final fs = await TransportEditorService.instance
        .loadFirestoreCodesAndNames();
    final codes = <String>{...fs.codes};
    final namesByCode = <String, String>{...fs.namesByCode};
    if (_manifest != null) {
      for (final m in _manifest!.values) {
        codes.add(m.lineNumber);
        final norm = TransportEditorService.normalizeName(m.displayName);
        if (norm.isNotEmpty) {
          namesByCode.putIfAbsent(norm, () => m.lineNumber);
        }
      }
    }
    return (codes: codes, namesByCode: namesByCode);
  }

  /// Charge une ligne depuis ses métadonnées
  Future<TransportLineGroup?> _loadLineFromMetadata(
    LineMetadata metadata,
  ) async {
    try {
      TransportLine? allerLine;
      TransportLine? retourLine;

      if (metadata.aller != null) {
        allerLine = await _loadSingleRoute(
          metadata.lineNumber,
          metadata.aller!,
          metadata.isBundled,
          false,
        );
      }

      if (metadata.retour != null) {
        retourLine = await _loadSingleRoute(
          metadata.lineNumber,
          metadata.retour!,
          metadata.isBundled,
          true,
        );
      }

      if (allerLine == null && retourLine == null) return null;

      return TransportLineGroup(
        lineNumber: metadata.lineNumber,
        displayName: metadata.displayName,
        transportType: allerLine?.transportType ??
            retourLine?.transportType ??
            TransportType.bus,
        aller: allerLine,
        retour: retourLine,
      );
    } catch (e) {
      myCustomPrintStatement(
        'Erreur _loadLineFromMetadata ${metadata.lineNumber}: $e',
      );
      return null;
    }
  }

  /// Charge un tracé unique (aller OU retour).
  ///
  /// Ordre de lookup :
  /// 1. Firestore `transport_lines_published/{line}.{direction}` (prod live
  ///    éditée par les consultants + validée par l'admin). Si présent →
  ///    gagne sur l'asset bundlé, permet de pousser des corrections sans
  ///    rebuild Flutter.
  /// 2. Asset bundlé (`assets/transport_lines/core/{line}_{dir}.geojson`).
  /// 3. Remote Firebase Storage via URL (legacy).
  Future<TransportLine?> _loadSingleRoute(
    String lineNumber,
    RouteMetadata route,
    bool isBundled,
    bool isRetour,
  ) async {
    try {
      final direction = isRetour ? 'retour' : 'aller';
      final filename = '${lineNumber}_$direction.geojson';

      // 1. Essai Firestore prod live (bypass cache — les validations admin
      //    doivent apparaître immédiatement côté app).
      final published = await TransportEditorService.instance
          .loadPublishedFeatureCollection(lineNumber, direction);
      if (published != null) {
        return TransportLine.fromGeoJson(published, filename);
      }

      // 2. Asset bundlé
      String geojsonContent;
      if (isBundled && route.assetPath != null) {
        geojsonContent = await rootBundle.loadString(route.assetPath!);
      } else if (route.remoteUrl != null) {
        // 3. Remote (legacy Firebase Storage)
        geojsonContent = await _fetchRemoteGeoJson(route.remoteUrl!);
      } else {
        return null;
      }

      final geojson = json.decode(geojsonContent) as Map<String, dynamic>;
      return TransportLine.fromGeoJson(geojson, filename);
    } catch (e) {
      myCustomPrintStatement(
        'Erreur _loadSingleRoute $lineNumber: $e',
      );
      return null;
    }
  }

  /// Télécharge un GeoJSON remote avec cache local (SharedPreferences)
  Future<String> _fetchRemoteGeoJson(String url) async {
    // Vérifier le cache local
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'geojson_${url.hashCode}';
    final cached = prefs.getString(cacheKey);

    if (cached != null) {
      final cacheTime = prefs.getInt('${cacheKey}_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - cacheTime < _cacheDurationMs) {
        myCustomPrintStatement('GeoJSON depuis cache: $url');
        return cached;
      }
    }

    // Télécharger depuis remote
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      // Sauvegarder en cache local
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt(
        '${cacheKey}_time',
        DateTime.now().millisecondsSinceEpoch,
      );

      myCustomPrintStatement('GeoJSON téléchargé: $url');
      return response.body;
    }

    throw Exception('Échec téléchargement GeoJSON: ${response.statusCode}');
  }

  /// Génère une clé unique pour grouper les lignes
  String _getGroupKey(String lineNumber) {
    final normalized = lineNumber.toUpperCase().trim();
    if (normalized.contains('TRAIN') || normalized.contains('TCE')) {
      return 'TRAIN_TCE';
    }
    if (normalized.contains('TELEPHERIQUE')) {
      return 'TELEPHERIQUE_ORANGE';
    }
    return normalized;
  }

  /// Filtre les lignes par type de transport
  Future<List<TransportLineGroup>> getLinesByType(TransportType type) async {
    final allLines = await loadAllLines();
    return allLines.where((group) => group.transportType == type).toList();
  }

  /// Récupère un groupe de ligne par son numéro
  Future<TransportLineGroup?> getLineGroup(String lineNumber) async {
    // Essayer d'abord le cache puis charger
    if (_linesCache.containsKey(lineNumber)) {
      return _linesCache[lineNumber];
    }

    // Essayer le lazy loading
    final loaded = await loadLine(lineNumber);
    if (loaded != null) return loaded;

    // Fallback: chercher dans toutes les lignes déjà chargées
    final allLines = await loadAllLines();
    try {
      return allLines.firstWhere(
        (group) =>
            _getGroupKey(group.lineNumber) == _getGroupKey(lineNumber),
      );
    } catch (_) {
      return null;
    }
  }

  /// Vide le cache pour forcer un rechargement
  void clearCache() {
    _linesCache.clear();
    _manifest = null;
    _transportGraph = null;
    myCustomPrintStatement('Cache des lignes de transport vidé');
  }

  /// Récupère la liste des types de transport disponibles
  Future<List<TransportType>> getAvailableTypes() async {
    final allLines = await loadAllLines();
    final types = <TransportType>{};
    for (final group in allLines) {
      types.add(group.transportType);
    }
    return types.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  /// Initialise le graphe du réseau de transport
  Future<void> initializeGraph() async {
    if (_transportGraph != null) return;

    final lines = await loadAllLines();
    _transportGraph = TransportGraph();
    _transportGraph!.buildFromLines(lines);

    myCustomPrintStatement(
      'Graphe initialisé: ${_transportGraph!.nodes.length} arrêts, '
      '${_transportGraph!.edges.length} connexions',
    );
  }

  /// Calcule un itinéraire entre deux positions
  Future<TransportRoute?> findRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    await initializeGraph();

    if (_transportGraph == null) return null;

    final route = _transportGraph!.findRoute(origin, destination);

    if (route != null) {
      myCustomPrintStatement(
        'Itinéraire trouvé: ${route.steps.length} étapes, '
        '${route.totalDurationMinutes} min, '
        '${route.numberOfTransfers} correspondance(s)',
      );
    } else {
      myCustomPrintStatement('Aucun itinéraire trouvé');
    }

    return route;
  }

  /// Calcule plusieurs itinéraires entre deux positions
  Future<List<TransportRoute>> findMultipleRoutes(
    LatLng origin,
    LatLng destination, {
    int maxRoutes = 5,
  }) async {
    await initializeGraph();

    if (_transportGraph == null) return [];

    final routes = _transportGraph!.findMultipleRoutes(
      origin,
      destination,
      maxRoutes: maxRoutes,
    );

    myCustomPrintStatement(
      '${routes.length} itinéraires trouvés entre $origin et $destination',
    );

    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      myCustomPrintStatement(
        '  Option ${i + 1}: ${route.totalDurationMinutes} min, '
        '${route.numberOfTransfers} correspondance(s)',
      );
    }

    return routes;
  }

  /// Trouve l'arrêt le plus proche d'une position
  Future<TransportNode?> findNearestStop(LatLng position) async {
    await initializeGraph();
    return _transportGraph?.findNearestStop(position);
  }

  /// Obtient tous les arrêts du réseau
  Future<List<TransportNode>> getAllStops() async {
    await initializeGraph();
    return _transportGraph?.nodes.values.toList() ?? [];
  }
}
