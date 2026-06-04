# Vue réseau « toutes lignes » — faisceaux LOOM pré-calculés

Pipeline de build qui remplace l'heuristique runtime de faisceaux
(`_precomputeStrandRuns`, slots −1/0/+1, max 3 brins) par un ordonnancement
**pro calculé par [LOOM](https://github.com/ad-freiburg/loom)** : sur chaque
corridor partagé (jusqu'à ~12 lignes superposées sur le même axe à Tana),
les lignes deviennent des **rubans parallèles ordonnés** (croisements
minimisés), sur la vraie géographie — pas de plan schématique ici (ça, c'est
`tools/schema/`).

## Chaîne

```
Firestore prod (transport_lines_published, admin-approved)
  │  node scripts/transport_editor_pull_cli.js publish-bundle   (--pull)
  ▼
assets/transport_lines_public/  (manifest.json + core/*.geojson)
  │  MISY_FULL_LINE_IDS=1 misy2loom.py     (1 ligne LOOM par line_number)
  ▼
graphe LOOM ──► topo ──► loom (ordre optimal par tronçon) ──► network_loom.json
  │                                                             │
  │  loom2strands.py                                            │ transitmap
  ▼                                                             ▼
web/transport_network/network_strands.json            network_control.svg (QA)
```

- **`topo`** fusionne les tronçons co-linéaires en arêtes partagées ;
- **`loom`** calcule l'ordre des lignes sur chaque arête (minimise
  croisements/séparations — mêmes pénalités que le plan schématique) ;
- **`loom2strands.py`** reconstruit des polylignes continues PAR LIGNE,
  annotées d'un vecteur latéral unitaire × facteur de slot (sémantique
  `_StrandPt` du runtime) avec rampes douces aux changements de slot ;
- le runtime (`home_screen_web.dart`) applique l'offset réel au zoom courant
  (`_applyStrandOffset`, largeur écran constante) — voir le flag ci-dessous.

## Usage

```bash
# bundle déjà à jour :
bash tools/network/build_network_map.sh
# en repartant des lignes prod Firestore :
bash tools/network/build_network_map.sh --pull
```

Puis QA :
1. ouvrir `tools/network/network_control.svg` (rendu transitmap du même
   graphe : les faisceaux doivent être ordonnés, géographiques) ;
2. `flutter run -d chrome --dart-define=LOOM_NETWORK=true` → vue réseau TC ;
   sans le define = ancien rendu heuristique (A/B sur la même branche) ;
3. committer `web/transport_network/network_strands.json`.

## Prérequis

LOOM buildé localement (voir l'en-tête de `tools/schema/build_schema.sh`).
Override du chemin : `LOOM_BUILD=/chemin/vers/loom/build`.

## ⚠️ Pièges

- **LOOM est légèrement non-déterministe** : toujours committer le JSON
  contrôlé sur le SVG du MÊME run ; ne pas régénérer en CI.
- **L'ordre des lignes d'une arête LOOM est RELATIF au sens de parcours** :
  `loom2strands.py` applique l'orientation canonique (retourne géométrie ET
  ordre ensemble) — même piège que `octi2json.py` (cf. mémoire projet).
- `MISY_FULL_LINE_IDS` ne doit JAMAIS être posé pour `tools/schema/`
  (le plan schématique repose sur la fusion par numéro de base).
- Tier 1 (train, téléphérique) volontairement absent du JSON : le runtime
  les trace en ligne pleine au-dessus, hors faisceau (comportement historique).

## Limites connues (v1, 05/06/2026)

- **Corridors très denses** : densité max constatée = 26 lignes sur le même
  tronc. Brins amincis en `64/k` px (min 2,5) au-delà de `denseK=6` →
  ruban ≈ 117 px à l'écran (constant au zoom) : il déborde la rue, c'est
  inhérent au choix « toutes les lignes visibles et ordonnées ».
- **Billes d'arrêts** : snappées sur le tracé OSM brut, les rubans suivent
  la géométrie `topo` (axe partagé) → décalage possible ≤ ~25 m à fort
  zoom. v2 : snapper sur la géométrie LOOM.
- **Antennes retour (sens uniques)** : LOOM ne voit que l'aller ; le retour
  divergent est repris du découpage mergé runtime, sans offset — raccord au
  tronc LOOM approximatif (≤ ~25 m) possible aux jonctions.
- **Dézoom squelette (< 15)** : offsets LOOM neutralisés (une ligne seule
  s'écarterait de sa rue) → les corridors « s'ouvrent » en rubans au
  franchissement du zoom 15.
- **Poids** : `network_strands.json` ≈ 720 Ko brut (~180 Ko gzip nginx),
  chargé une fois par session TC.
- **Génération** : topo+loom < 10 s sur le réseau entier ; non-déterministe
  d'un run à l'autre (cf. Pièges).
