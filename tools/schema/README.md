# Plan schématique octilinéaire (LOOM)

La vue « plan schéma » (façon métro) du réseau taxi-be est **pré-calculée
hors-ligne** par [LOOM](https://github.com/ad-freiburg/loom) (Brosi & Bast,
Université de Fribourg) — pas par du code Flutter (l'auto-layout octilinéaire
est NP-difficile).

## Pipeline

```
misy2loom.py  (notre bundle GeoJSON → graphe de lignes LOOM)
   │
   topo        (graphe sans recouvrement = fusion des corridors)
   loom        (ordre optimal des lignes dans les faisceaux)
   octi        (octilinéarisation → angles 0/45/90°)
   transitmap -l   (→ SVG)
   │
   ▼
web/transport_schema/misy_octilineaire.svg   (servi statique, affiché par
                                              transport_network_diagram.dart)
```

## Régénérer (après maj des lignes)

```bash
./tools/schema/build_schema.sh          # régénère le SVG
git add web/transport_schema && git commit -m "chore: maj plan schéma"
flutter build web --release && ./deploy.sh
```

Prérequis : LOOM cloné + buildé (voir l'en-tête de `build_schema.sh`). Les
binaires sont attendus dans `~/StudioProjects/_tools/loom/build` (override via
`LOOM_BUILD=...`).

## Variantes

- **Octilinéaire** (par défaut) : plan métro abstrait, max lisibilité.
- **Géographique + faisceaux** : retirer `octi` du pipe → géographie réelle
  avec faisceaux de lignes ordonnés/décalés proprement (utile pour la carte live).

## Voir le rendu sans navigateur

```bash
qlmanage -t -s 2000 -o /tmp misy_octi.svg   # → /tmp/misy_octi.svg.png
```
