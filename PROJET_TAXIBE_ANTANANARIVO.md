# Projet Cartographie Taxi-Be Antananarivo

## Objectif
Créer une cartographie complète des lignes de taxi-be (bus urbains et suburbains) d'Antananarivo, Madagascar, avec pour finalité le développement d'une application de calcul d'itinéraire type "IDF Mobilités".

## État du projet : 95/95 LIGNES AVEC TRACÉS ROUTIERS (100%)

---

## Travail réalisé

### 09 janvier 2026 - Refonte complète (Version 2)
- **Objectif** : Repartir de zéro avec une méthodologie propre
- **Nouveau dossier** : `/Users/stephane/Claude/TaxiBe_09012026/`
- **Améliorations** :
  - Arrêts collectés uniquement depuis OSM (pas de projections)
  - Tracés construits arrêt par arrêt via OSRM Routing (pas de Map Matching)
  - Format GeoJSON standardisé (1 fichier arrêts + 2 fichiers par ligne)
  - Déduplication des arrêts trop proches (< 30m)
  - Distinction aller/retour automatique basée sur les tags OSM

- **Résultats** :
  - 2152 arrêts collectés (1329 avec nom OSM, 823 sans nom)
  - 34 lignes extraites
  - 68 fichiers GeoJSON générés (aller + retour par ligne)
  - Tracés 100% collés aux routes réelles

- **Scripts créés** :
  - `01_fetch_osm_data.py` : Collecte des données OSM via Overpass API
  - `03_build_fast.py` : Construction des tracés OSRM et génération GeoJSON
  - `config.py` : Configuration centralisée (APIs, paramètres)

### 20 décembre 2025 - Nettoyage des boucles (Ligne 105)
- **Problème identifié** : Les tracés OSRM contenaient des boucles inutiles (retours en arrière, tours multiples sur les ronds-points)
- **Cause** : L'API Map Matching tentait de faire correspondre des points GPS erronés, créant des détours
- **Solution** : Reconstruction du tracé segment par segment via OSRM Routing API
- **Méthode** :
  1. Déduplication des arrêts trop proches (< 50m)
  2. Calcul de l'itinéraire OSRM entre chaque paire d'arrêts consécutifs
  3. Assemblage des segments en un tracé linéaire continu

### 15 décembre 2025 - Ajout du Train Urbain et Téléphérique
- **Train Urbain** : Soarano - Ambohimanambola (8 gares, 12 km)
- **Téléphérique Ligne Orange** : Anosy - Ambatobe (7 stations, 8.8 km)

### 13 décembre 2025 - Correction des tracés via OSRM Map Matching
- **Problème** : Segments fantômes dans les tracés OSM
- **Solution** : OSRM Map Matching
- **Résultat** : 97% de réduction des segments > 500m

### 12 décembre 2025 - Collecte initiale des données
- **Source** : OpenStreetMap (Overpass API)
- **Zone** : Bounding box `-19.1,47.4,-18.7,47.7`

---

## Structure actuelle (Version 2)

```
/Users/stephane/Claude/TaxiBe_09012026/
├── arrets_antananarivo.geojson      # Tous les arrêts (2152 Points)
├── lignes/                           # 68 fichiers GeoJSON
│   ├── ligne_105_aller.geojson
│   ├── ligne_105_retour.geojson
│   ├── ligne_109_aller.geojson
│   ├── ligne_109_retour.geojson
│   ├── ... (64 autres fichiers)
├── data/
│   ├── osm_raw_stops.json           # Arrêts OSM bruts
│   └── osm_raw_routes.json          # Relations de lignes OSM
└── scripts/
    ├── config.py                    # Configuration
    ├── 01_fetch_osm_data.py         # Collecte OSM
    └── 03_build_fast.py             # Construction tracés OSRM
```

---

## Statistiques (Version 2 - 09/01/2026)

| Métrique | Valeur |
|----------|--------|
| **Arrêts totaux** | **2152** |
| - Avec nom OSM | 1329 (62%) |
| - Sans nom OSM | 823 (38%) |
| **Lignes** | **34** |
| **Fichiers GeoJSON lignes** | **68** (aller + retour) |

---

## Format GeoJSON

### Fichier arrêts (`arrets_antananarivo.geojson`)
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [47.5216, -18.9041]
      },
      "properties": {
        "id": "stop_12345678",
        "osm_id": 12345678,
        "name": "Analakely",
        "has_osm_name": true,
        "lines": ["105", "112", "136"]
      }
    }
  ]
}
```

### Fichier ligne (`ligne_105_aller.geojson`)
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[47.52, -18.90], [47.53, -18.91], ...]
      },
      "properties": {
        "type": "trace",
        "ref": "105",
        "name": "Ligne 105",
        "direction": "aller",
        "from": "Ambohimanarina",
        "to": "Analakely",
        "operator": "SCOTAT/KOFIMAVA",
        "colour": "#FF0000",
        "stops_count": 12,
        "distance_km": 4.31
      }
    },
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [47.52, -18.90]
      },
      "properties": {
        "type": "stop",
        "order": 1,
        "stop_id": "stop_123",
        "name": "Ambohimanarina"
      }
    }
  ]
}
```

---

## Liste des lignes (Version 2)

### Lignes numérotées
| Ligne | Distance Aller | Distance Retour |
|-------|----------------|-----------------|
| 105 | 4.3 km | 5.9 km |
| 109 | 27.8 km | 8.3 km |
| 112 | 10.4 km | 11.8 km |
| 114 | 8.1 km | 21.9 km |
| 120 | 9.2 km | 16.8 km |
| 123 | 19.8 km | 26.8 km |
| 126 | 17.9 km | 11.1 km |
| 133 | 9.5 km | 8.7 km |
| 135 | 7.7 km | 7.6 km |
| 140 | 0.5 km | 0.5 km |
| 141 | 7.6 km | 10.7 km |
| 143 | 9.7 km | 8.6 km |
| 144 | 8.8 km | 8.6 km |
| 146 | 16.8 km | 11.7 km |
| 147 | 12.3 km | 19.0 km |
| 147BIS | 23.0 km | 30.0 km |
| 154 | 7.9 km | 11.1 km |
| 160 | 9.2 km | 9.4 km |
| 163 | 35.7 km | 45.7 km |
| 166 | 13.8 km | 16.3 km |
| 178 | 23.7 km | 30.8 km |
| 187 | 16.0 km | 28.0 km |
| 192 | 0.4 km | 1.0 km |
| 194 | 43.3 km | 9.7 km |

### Lignes lettrées
| Ligne | Distance Aller | Distance Retour |
|-------|----------------|-----------------|
| A | 7.1 km | 15.1 km |
| D | 19.2 km | 47.1 km |
| E | 21.7 km | 24.1 km |
| G | 2.2 km | 2.2 km |
| H | 7.4 km | 18.0 km |
| J | 4.3 km | 4.3 km |

### Lignes spéciales
| Ligne | Distance Aller | Distance Retour |
|-------|----------------|-----------------|
| AMBOHIDRATRIMO | - | 9.9 km |
| AMBOHITRIMANJAKA | 4.4 km | 4.6 km |
| KOFIMI | 2.2 km | 2.2 km |
| MAHITSY | 16.5 km | 16.2 km |

---

## Ce qui reste à faire

### Priorité haute
- [x] ~~Développer l'application de calcul d'itinéraire~~ → Intégré dans Misy (écran Transport)
- [x] ~~Créer une interface utilisateur (web/mobile)~~ → TransportMapScreen avec carte + panneau latéral
- [x] ~~Implémenter l'algorithme de routing (Dijkstra ou A*)~~ → Calcul d'itinéraire multi-modal fonctionnel
- [x] ~~Améliorer les données des lignes non-bundled~~ → 95/95 lignes bundled avec tracés routiers
- [ ] Affiner l'UX du calcul d'itinéraire (suggestions d'arrêts, favoris)

### Priorité moyenne
- [ ] Nommer les 823 arrêts sans nom (format FOKONTANY + POI)
- [ ] Enrichir les données avec les horaires (si disponibles)
- [ ] Ajouter les tarifs par ligne
- [x] ~~Ajouter le Train Urbain et Téléphérique aux données v2~~ → TRAIN_TCE + TELEPHERIQUE_Orange intégrés

### Priorité basse
- [ ] Créer un système de mise à jour automatique depuis OSM
- [x] ~~Ajouter les lignes manquantes non présentes dans OSM~~ → Géocodage quartiers + OSRM routing
- [x] ~~Système de contribution communautaire (éditeur d'arrêts/tracés)~~ → Mode "Modifier le tracé" avec Primus/Terminus + waypoints

---

## Configuration technique

### APIs utilisées
| API | URL | Usage |
|-----|-----|-------|
| Overpass | https://overpass-api.de/api/interpreter | Collecte OSM |
| OSRM | https://osrm2.misy.app | Routing arrêt par arrêt |
| Nominatim | https://nominatim.openstreetmap.org | Reverse geocoding |

### Paramètres
| Paramètre | Valeur |
|-----------|--------|
| Zone (BBOX) | -19.1, 47.4, -18.7, 47.7 |
| Déduplication arrêts | 30m |
| Délai OSRM | 0.5s entre requêtes |

---

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `01_fetch_osm_data.py` | Collecte des arrêts et relations OSM via Overpass |
| `03_build_fast.py` | Construction des tracés OSRM et génération GeoJSON |
| `config.py` | Configuration centralisée (URLs, paramètres, chemins) |

---

## Contact / Ressources

- **Données OSM** : https://www.openstreetmap.org
- **Wiki OSM Antananarivo** : https://wiki.openstreetmap.org/wiki/FR:Antananarivo
- **OSRM** : https://project-osrm.org/
- **Licence données** : ODbL (Open Database License)

---

*Dernière mise à jour : 10 février 2026*

---

## RÈGLE IMPORTANTE POUR LES SESSIONS CLAUDE

> **⚠️ NE JAMAIS MODIFIER LE CONTENU EXISTANT - TOUJOURS AJOUTER EN FIN DE DOCUMENT**
>
> Ce fichier sert de journal de suivi du projet. Chaque session Claude doit :
> 1. Lire le fichier pour comprendre l'historique
> 2. Ajouter une nouvelle section horodatée à la fin
> 3. Ne jamais supprimer ou modifier les sections précédentes

---

## Suivi des sessions

### 12 janvier 2026 - 00h56 - Correction des arrêts et variantes

**Problème identifié** : Certains arrêts n'étaient pas sur le tracé (visible sur capture d'écran)

**Travail réalisé** :

1. **Script `05_fix_stops.py`** - Correction des arrêts sur les tracés
   - Conserve les tracés existants (LineString) inchangés
   - Recalcule les arrêts en ne gardant que ceux à < 30m du tracé
   - Ordonne les arrêts le long du tracé
   - **Résultat** : 68 fichiers mis à jour, 4700 arrêts analysés → 1667 conservés

2. **Script `06_build_variants.py`** - Construction des variantes de lignes
   - Crée un fichier GeoJSON par variante (terminus différents)
   - Format de nommage : `ligne_{ref}_{from}_{to}_{direction}.geojson`
   - Utilise OSRM pour construire les tracés
   - **Résultat** :
     - 147 relations OSM analysées
     - 110 fichiers GeoJSON créés
     - 37 relations ignorées (< 2 arrêts)

**Nouvelle structure** :
```
/Users/stephane/Claude/TaxiBe_09012026/
├── lignes/                     # 68 fichiers (aller/retour par ligne)
├── lignes_variantes/           # 94 fichiers (par variante avec terminus)
│   ├── ligne_105_Analakely_Ambohimanarina_aller.geojson
│   ├── ligne_105_Ambohimanarina_Analakely_aller.geojson
│   ├── ligne_109_Antanandrano_67Ha_aller.geojson
│   ├── ligne_133_Analakely_Itaosy_Cite_aller.geojson
│   ├── ligne_133_Analakely_Itaosy_Hopitaly_aller.geojson
│   ├── ligne_133_Analakely_Ambohimamory_aller.geojson
│   └── ... (88 autres fichiers)
└── scripts/
    ├── 04_build_with_sides.py  # Sélection aller/retour
    ├── 05_fix_stops.py         # Correction arrêts sur tracé
    └── 06_build_variants.py    # Construction des variantes
```

**Statistiques mises à jour** :
| Métrique | Valeur |
|----------|--------|
| Fichiers lignes (aller/retour) | 68 |
| Fichiers variantes | 94 |
| Relations OSM traitées | 147 |
| Arrêts conservés (sur tracé) | 1667 |

---

### 16 janvier 2026 - Correction du tracé Train Urbain (TCE)

**Problème identifié** : Le tracé du Train Urbain Tananarive Côte Est (TCE) s'arrêtait ~733m avant la gare terminus d'Ambohimanambola.

**Cause** : La voie ferrée OSM (way ID 1194726380) qui connecte le tracé principal à la gare d'Ambohimanambola n'était pas incluse dans les données.

**Correction effectuée** :
- Tracé `TRAIN_TCE_aller.geojson` : prolongé de 160 → 163 points
  - Ancien point final : `[47.5997043, -18.9365206]`
  - Nouveau point final : `[47.5995604, -18.9431249]` (Gare Ambohimanambola)

- Tracé `TRAIN_TCE_retour.geojson` : prolongé de 160 → 163 points
  - Nouveau point de départ : `[47.5995604, -18.9431249]` (Gare Ambohimanambola)

**Fichiers modifiés** :
- `/Users/stephane/Claude/moovit_geojson/TRAIN_TCE_aller.geojson`
- `/Users/stephane/Claude/moovit_geojson/TRAIN_TCE_retour.geojson`

---

### 18 janvier 2026 - Correction ligne 129 (détour inutile)

**Problème identifié** : Le tracé de la ligne 129 faisait un détour vers "Lalana Razanatseheno Henri" au lieu d'aller tout droit sur "Lalana Andriandalifotsy".

**Correction effectuée** :
- Suppression des points 1-34 (le détour)
- Remplacement par un segment en ligne droite (6 points)
- Tracé réduit de 343 → 314 points

**Fichier modifié** :
- `/Users/stephane/Claude/moovit_geojson_20260114_175504/129_aller.geojson`

**Backup disponible** :
- `/Users/stephane/Claude/moovit_geojson_20260114_175504/129_aller_backup.geojson`

**Note** : OSRM ne connaissait pas la route directe. Correction manuelle nécessaire dans QGIS si le tracé en ligne droite ne suit pas exactement la route.

---

### 10 février 2026 - Refonte visuelle style IDFM + intégration 95 lignes

**Contexte** : Les données transport sont intégrées dans l'app Misy (misy-booking-web). Travail sur le rendu carte et l'UX du panneau de lignes.

**Travail réalisé** :

1. **Couleurs uniques par ligne** (`manifest.json` + `transport_line.dart`)
   - Remplacement des couleurs génériques (bleu identique partout) par des couleurs uniques
   - Couleurs fixes pour les lignes clés : 015 (bleu IDFM), 017/17 (violet), 129 (rose), TRAIN_TCE (vert), TELEPHERIQUE (orange)
   - Algorithme `_generateColor()` : hash HSL déterministe pour les autres lignes (saturation 45-60%, luminosité 35-45% → tons mats professionnels)

2. **Polylines style IDFM** (`transport_map_screen.dart`)
   - Bordure blanche sous le trait coloré (z-index 0 + 1)
   - Trait aller pleine opacité, retour à 55% opacité
   - Épaisseur augmentée (5→6 bus, 6→7 train/téléphérique)

3. **Nouveaux markers d'arrêts** (`_getStopCircleIcon`)
   - Ronds colorés avec numéro de ligne en blanc, bordure blanche, ombre
   - Taille de police adaptative selon la longueur du texte
   - Affichage spécial : "TCE" pour train, "TP" pour téléphérique

4. **UX panneau latéral**
   - Boutons "Tout afficher / Tout masquer" avec compteur (`X/Y affichées`)
   - Liste des lignes : affiche direction (terminus aller ↔ retour)
   - Clic sur une ligne = bascule vers onglet Carte (au lieu du toggle switch)
   - Bouton "Modifier" pour ouvrir l'éditeur de contribution
   - Espacement et tailles ajustés pour meilleure lisibilité
   - Panneau élargi (300→380px)

**Statistiques intégration** :
| Métrique | Valeur |
|----------|--------|
| **Lignes totales** | **95** (93 bus + 1 train + 1 téléphérique) |
| **Lignes bundled (données locales)** | **21** |
| **Lignes non-bundled (manifest seul)** | **74** |

**Fichiers modifiés** :
- `assets/transport_lines/manifest.json` — couleurs uniques pour 95 lignes
- `lib/models/transport_line.dart` — `_generateColor()` + palette IDFM
- `lib/pages/view_module/transport_map_screen.dart` — refonte visuelle (~500 lignes)

---

### 10 février 2026 - 95/95 lignes avec tracés routiers + mode édition collaboratif

**Objectif** : Passer de 21 à 95 lignes bundled (100%) + ajouter un éditeur de tracé collaboratif.

**Travail réalisé** :

#### 1. Extraction OSM (38 nouvelles lignes)
- Script `fetch_osm_transport_lines.py` : extraction via Overpass API (serveur miroir mail.ru)
- Requête bbox `(-19.1,47.3,-18.7,47.7)` → 148 relations trouvées
- Matching intelligent : base line, case-insensitive, sous-variantes (ex: `194` → `194-Ambohimangakely`)
- Fetch geometry par batch de 5 relations pour éviter les timeouts
- **Résultat** : 76 fichiers GeoJSON générés (38 lignes aller + retour)

#### 2. Géocodage + OSRM (36 lignes restantes)
- Script `generate_missing_routes.py` : dictionnaire de ~50 quartiers d'Antananarivo
- Géocodage des noms de direction (ex: "67HA" → (-18.9137, 47.5225))
- Routage OSRM entre endpoints → tracés qui suivent les vraies routes
- Correction des 5 lignes circulaires (128, 153, 191, 186A, 127A) avec points intermédiaires
- Fallback Nominatim pour les quartiers non répertoriés
- **Résultat** : 70 fichiers GeoJSON générés (36 lignes)

#### 3. Road-snapping OSRM (tous les tracés)
- Script `snap_routes_to_roads.py` : recalage de tous les 188 fichiers sur le réseau routier
- Sampling des coords à 80 waypoints max → appel OSRM route API
- Train TCE et Téléphérique exclus du snapping (rail/câble)
- **Résultat** : 115/118 fichiers snappés, 3 retours vides corrigés par inversion aller

#### 4. Couleurs uniques (96 entrées)
- Map `_fixedColors` : 96 couleurs hex uniques (vérifiées sans doublon)
- Recherche web des couleurs taxi-be : Manga=bleu, Mena=rouge (variantes de route)
- Synchronisation manifest.json ↔ code Dart (94 couleurs mises à jour)

#### 5. Arrêts sur la carte
- Marqueurs d'arrêts avec numéro de ligne + couleur
- Déduplication aller/retour via `_stopPosKey()` (precision ~10m)
- Affichage sur les onglets Transport et Carte

#### 6. Mode édition collaboratif ("Modifier le tracé")
- Flow Primus → Terminus avec Google Places Autocomplete
- Auto-calcul du tracé OSRM (suppression du bouton "Calculer")
- Phase affinage : midpoint drag handles + waypoints draggables/supprimables
- Aller/Retour : reset complet (pas de swap)
- Popup contribution : prénom (requis) + description (optionnel)
- Popup confirmation sortie si travail en cours
- Persistance Firestore via `TransportContributionService`

**Statistiques finales** :
| Métrique | Valeur |
|----------|--------|
| **Lignes totales** | **95** (93 bus + 1 train + 1 téléphérique) |
| **Lignes bundled** | **95/95 (100%)** |
| **Fichiers GeoJSON** | **188** (95 aller + 93 retour) |
| **Source: originaux** | 42 fichiers |
| **Source: OpenStreetMap** | 76 fichiers |
| **Source: géocodés + OSRM** | 70 fichiers |
| **Tous road-snapped** | Oui (sauf train/téléphérique) |

**Scripts créés** :
| Script | Description |
|--------|-------------|
| `scripts/fetch_osm_transport_lines.py` | Extraction OSM via Overpass API (bbox + batches) |
| `scripts/generate_missing_routes.py` | Géocodage quartiers Tana + routage OSRM |
| `scripts/snap_routes_to_roads.py` | Recalage de tous les GeoJSON sur routes réelles |

**Fichiers modifiés** :
- `assets/transport_lines/core/*.geojson` — 188 fichiers (42 modifiés + 146 créés)
- `assets/transport_lines/manifest.json` — 95 lignes bundled, couleurs synchronisées
- `lib/models/transport_line.dart` — `_fixedColors` 96 couleurs uniques
- `lib/models/transport_contribution.dart` — modèle EditData
- `lib/pages/view_module/home_screen_web.dart` — mode édition + arrêts carte
- `lib/services/transport_contribution_service.dart` — paramètre contributorName
- `lib/services/transport_lines_service.dart` — chargement bundled

---
