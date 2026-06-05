# Arbitrage à trancher : publier un feed GTFS public ?

`PLAN_GTFS.md` (déjà spécifié, non implémenté) prévoit d'exposer le réseau
taxi-be en **GTFS public** (Google Maps, Transitland, OpenTripPlanner…).
Cette intention est **en tension directe** avec la protection anti-scraping
qu'on vient de poser (filigrane + © + blocage Referer).

## Les deux trajectoires (s'excluent en grande partie)

### A. Réseau = actif protégé (statu quo, protections actives)
- Les tracés/arrêts restent fermés ; filigrane + légal + friction nginx.
- Moat = la donnée elle-même.
- Risque : un concurrent ou Google reconstruit le réseau autrement ; Misy
  reste la seule source mais invisible hors de son app.

### B. Réseau = bien commun, distribution maximale (feed GTFS public)
- Le réseau apparaît dans Google Maps, etc. → visibilité massive, Misy
  devient « la » référence du taxi-be d'Antananarivo.
- Les tracés deviennent publics **par choix** → filigrane/blocage perdent
  leur objet sur les données publiées (le feed est libre par définition).
- Moat = **fraîcheur** (pipeline éditeur terrain, mises à jour rapides) +
  **couverture** + **l'app** (réservation, prix, course privée). La donnée
  brute n'est plus le moat, l'exécution l'est.

## Recommandation
Ne pas faire les deux à moitié. Tant que la décision B n'est pas prise,
**garder A** (protections actives — c'est l'état actuel). Si B est retenue
un jour : publier un feed GTFS *officiel* (attribué Misy, à jour) devient
la meilleure défense contre le scraping (pourquoi voler ce qui est donné,
et moins frais ?), et on relâche le blocage Referer sur le seul endpoint
GTFS public.

→ **DÉCISION 06/06/2026 : trajectoire A retenue (protéger).** Pas de feed GTFS public. À ne pas rouvrir sans décision explicite de Stéphane.
