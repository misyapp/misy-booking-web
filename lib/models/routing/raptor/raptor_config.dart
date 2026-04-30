/// Constantes RAPTOR. Modifiables sans toucher l'algo.
class RaptorConfig {
  RaptorConfig._();

  /// Headway constant utilisé quand une ligne n'a pas de fréquence connue.
  /// Bus taxi-be Tana : passage estimé 6-12 min selon ligne, on prend 10.
  static const double defaultHeadwayMin = 10.0;

  /// Vitesse moyenne en bus (km/h) — entre arrêts dans le réseau Tana.
  static const double busSpeedKmh = 15.0;

  /// Vitesse de marche piétonne (km/h, ~ 4.5 km/h = 75 m/min).
  static const double walkSpeedKmh = 4.5;

  /// Nombre maximum de correspondances explorées (rondes RAPTOR).
  /// 4 transferts couvre quasiment 100% des trajets utiles à Tana.
  static const int kMax = 4;

  /// Rayon de footpath entre 2 stops (mètres). Au-delà, on considère que
  /// la marche n'est plus une option de correspondance crédible.
  static const double footpathRadiusMeters = 400.0;

  /// Rayon max pour fusionner 2 stops du même nom dans le clusterizer.
  /// Si même nom mais > 300m, on garde 2 stops séparés (homonymes).
  static const double sameNameClusterMaxMeters = 300.0;

  /// Rayon strict de fusion par proximité géométrique (sans regarder le nom).
  /// Capture les arrêts aller/retour à quelques mètres l'un de l'autre.
  static const double geometricClusterMaxMeters = 50.0;

  /// Distance origin→1er stop max (km). Au-delà, on ne propose pas de route.
  static const double accessKm = 4.5;

  /// Temps de marche max total (min) pour qu'une route soit acceptable.
  static const int maxTotalWalkMin = 60;

  /// Temps de marche max sur 1 leg (min).
  static const int maxSingleWalkMin = 30;
}
