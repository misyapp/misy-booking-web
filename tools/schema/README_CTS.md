# Plan schématique CTS — rendu pro (flag `SCHEMATIC_CTS`)

Refonte du rendu de la vue schématique façon **plan CTS Strasbourg** :
octilinéaire **géoschématique** (`octi --geo-pen`, reste reconnaissable
géographiquement), symbologie complète, labels auto dé-chevauchés.
Derrière `--dart-define=SCHEMATIC_CTS=true` — sans le flag (ou si les
artefacts `misy_cts*.json` sont absents / 404), le rendu historique est
servi à l'identique.

## Chaîne

- `bash tools/schema/build_schema_cts.sh` → `misy2loom (fusion par base)
  | topo | inject_water | loom | octi (--geo-pen, -g 130%, pens 45°)` →
  `MISY_CTS=1 octi2json.py` → `web/transport_schema/misy_cts{,_centre}.json`
  (+ SVG transitmap de contrôle, gitignorés). Tuning : env `GEO_PEN`,
  `GRID_PCT`, `MISY_POLE_N`.
- Runtime : `SchematicPainterCts` + `SchematicLabelLayout` (module pur,
  testé) + `SchematicLegend`. Le painter legacy `_SchematicPainter` est
  STRICTEMENT intact.

## Alphabet

casing blanc sous rubans ; épaisseur de brin ∝ densité corridor (2,2→3,5 px,
antennes fines / troncs épais) ; tier 1 = voie ferrée (traverses) ; arrêt =
tiret blanc perpendiculaire ; correspondance = pastille cerclée ; terminus =
capsule orientée + grappe de pastilles numéros ; pôle = double anneau
(n ≥ 22 ou noms épinglés, dédup spatiale) ; pastilles numéro le long des
antennes (≤ 3 lignes) ; coudes arrondis au rendu ; fond crème, eau bleu
clair ; légende générée (charte Misy, jamais sur les tracés).

## Labels (automatique seul, validé 05/06/2026)

Glouton par priorité, 8 candidats {0°, ±45°} (jamais vertical), collision
AABB réelle (labels + segments de tracés) via grille spatiale, bbox jamais
tronquée, paliers de zoom (majeurs < 2×fit, +n≥4 < 4×fit, tous ensuite),
majeurs à cheval sur tracé en dernier recours (halo), force-directed léger
(≤ 5 crans) réservé aux majeurs, arrêts simples masquables.

## Limites connues (v1, 05/06/2026)

- **Clusters très denses (Soarano/Analakely)** : au dézoom complet,
  ~41/191 labels majeurs posés (limite de packing du centre) — les autres
  apparaissent en zoomant ; focus+context = v2.
- **~10 % de labels masqués/sous-optimaux assumé** (aucune retouche
  manuelle en v1).
- **Fusion par base** : 194 Vert / 194 Rouge = un seul ruban « 194 »
  (couleur de la ligne nue) — voulu pour le schématique.
- **octi non-déterministe** entre runs → committer les artefacts d'UN run
  contrôlé sur ses SVG ; ne pas régénérer en CI.
- **geo-pen 1.0 / -g 130 %** : premier réglage — itérer UN paramètre à la
  fois (QA sur les SVG) si le centre paraît trop tortueux ou trop serré.
- **Pastilles absentes en fallback legacy** (`SchLine.label` null sur les
  anciens JSON).

## QA

- `flutter test test/unit/schematic_label_layout_test.dart` (module labels)
- `flutter test --dart-define=SCHEMATIC_CTS=true test/schema_preview_cts_test.dart`
  → `/tmp/misy_cts*_preview.png` (⚠️ polices factices = rectangles ;
  géométrie/symbologie seulement)
- Visuel réel : `flutter run -d chrome --dart-define=SCHEMATIC_CTS=true`
  → mode TC → bouton « Réseau ».
