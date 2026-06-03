/// Configuration de la carto auto-hébergée (migration Google Maps → OSM/flutter_map).
///
/// Le fond de carte est servi en **tuiles vectorielles PMTiles** statiques
/// (range-requests nginx), avec un style répliquant la charte Misy.
class MapTilesConfig {
  MapTilesConfig._();

  /// URL du PMTiles vectoriel en prod (sous-domaine dédié, compartimenté).
  static const String pmtilesUrl = 'https://tiles.misy.app/madagascar.pmtiles';

  /// Override pour le dé-risque / dev local
  /// (ex. `--dart-define=PMTILES_URL=http://localhost:8099/madagascar.pmtiles`).
  static const String _pmtilesOverride =
      String.fromEnvironment('PMTILES_URL', defaultValue: '');

  static String get effectivePmtilesUrl =>
      _pmtilesOverride.isNotEmpty ? _pmtilesOverride : pmtilesUrl;

  /// Template XYZ des tuiles vectorielles servies par un mini-serveur pmtiles
  /// (go-pmtiles / Cloudflare Worker). **Voie retenue pour le web dart2js** :
  /// le client ne parse pas le PMTiles (offsets 64 bits → `Uint64` non supporté
  /// par dart2js), il reçoit du MVT déjà découpé. Vide = lecture directe du
  /// `.pmtiles` (uniquement possible en build WASM).
  /// Prod : `https://tiles.misy.app/madagascar/{z}/{x}/{y}.mvt`.
  static const String vectorTileUrlTemplate =
      String.fromEnvironment('VECTOR_TILE_URL', defaultValue: '');

  /// Template XYZ des **tuiles raster** (PNG/WebP) stylées charte, servies par
  /// tileserver-gl / un raster pré-rendu (go-pmtiles). **Voie retenue sur web**
  /// (le rendu vectoriel client `vector_map_tiles` est cassé sur Flutter web :
  /// `path_provider.getTemporaryDirectory` indisponible). Si défini, `BookingMap`
  /// utilise un `TileLayer` raster (increvable) plutôt que `VectorTileLayer`.
  /// Prod : `https://tiles.misy.app/styles/misy/{z}/{x}/{y}.png`.
  static const String rasterTileUrlTemplate =
      String.fromEnvironment('RASTER_TILE_URL', defaultValue: '');

  /// Style MapLibre/OpenMapTiles (charte : routes lavande #A6B5DE, POI masqués).
  static const String styleAsset = 'assets/map/misy-style.json';

  /// Nom de la source vectorielle déclarée dans le style.json.
  static const String sourceName = 'openmaptiles';

  /// Imagerie satellite gratuite (confirmation du point de dépose). Attribution
  /// « Tiles © Esri » obligatoire. Usage faible (uniquement à la confirmation).
  static const String esriSatelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
}
