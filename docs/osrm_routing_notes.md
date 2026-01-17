## OSRM Routing Migration Notes

### Contexte
- Remplacement des appels Directions API vers `https://osrm2.misy.app`.
- Fallback automatique vers `https://osrm1.misy-app.com` lorsque OSRM2 échoue ou dépasse 3 s de timeout.
- Journalisation explicite dans la console Flutter pour identifier la source utilisée.

### Fichiers clés
- `lib/services/route_service.dart`
  - Construction des URLs OSRM (`osrm2Url`, `osrm1Url`) avec profils autorisés (`driving`, `walking`, `cycling`).
  - Timeout de 3 s sur OSRM2 et fallback OSRM1 avec logs `[ROUTING]`.
  - Parsing OSRM centralisé dans `_parseOsrmResponse`.
  - Ancien appel Google Directions conservé/commenté avec `// [DEPRECATED] Google Directions API - remplacé par OSRM2.misy.app`.
- `lib/services/location.dart`
  - Méthode `getTotalTimeCalculate` utilise OSRM2 → fallback OSRM1 avec même logique de timeout/logs.
  - `_createTotalTimeDistance` extrait distance/durée du payload OSRM.
  - Ancienne implémentation Google Directions commentée avec l’en-tête `[DEPRECATED]`.

### Ajouter / modifier un serveur OSRM
1. **Point d’entrée principal** : `RouteService.fetchRoute`.
   - Les URLs sont construites en fonction du profil (`driving` par défaut) et de la liste ordonnée des points (origin → waypoints → destination).
   - Pour ajouter un nouveau serveur, définir l’URL juste avant le bloc `try` (ex : `final String osrm3Url = ...`) puis ajuster la logique du `try/catch` (par exemple tester OSRM3 avant OSRM2, ou l’utiliser comme second fallback).
2. **Calculs de temps/distance** : `LocationService.getTotalTimeCalculate`.
   - Réutilise la même chaîne `coordinates` et les mêmes `queryParams`.
   - Introduire le nouveau serveur dans la séquence de fallback en dupliquant le motif `try { ... } catch { ... }`.
3. **Timeouts & Logs** :
   - Le timeout est appliqué via `http.get(...).timeout(const Duration(seconds: 3))`.
   - Conserver les logs `print('[ROUTING] ...')` pour garder la traçabilité côté DevTools.
4. **Paramètres OSRM** :
   - La query string actuelle force `overview=full` et `geometries=polyline` pour rester compatible avec le décodage polyline existant.
   - Ajouter des paramètres supplémentaires en concaténant à `queryParams`.

### Tests / Validation
- `flutter analyze lib/services/route_service.dart lib/services/location.dart`.
- Vérifier manuellement dans Flutter DevTools → Network :
  - requêtes vers `https://osrm2.misy.app/...`.
  - En cas d’échec simulé, présence des requêtes fallback `https://osrm1.misy-app.com/...`.
- Exemple de coordonnées de test : Ankorondrano (`-18.8875, 47.5113`) → Analakely (`-18.9148, 47.5254`).

### Points d’attention
- Ne pas modifier `parseOsrmResponse` / `_createTotalTimeDistance` sans garantir la compatibilité des polylines (format polyline encodé par OSRM).
- Toute nouvelle utilisation doit respecter l’ordre `longitude,latitude` imposé par OSRM dans la chaîne `coordinates`.
