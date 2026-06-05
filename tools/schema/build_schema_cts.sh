#!/bin/bash
# Régénère le plan schématique CTS (rendu pro type CTS Strasbourg, painter
# v2 derrière --dart-define=SCHEMATIC_CTS=true) : octilinéaire
# GÉOSCHÉMATIQUE (octi --geo-pen : reste reconnaissable géographiquement)
# et AÉRÉ (-g > 100 % : espace les clusters denses Soarano/Analakely).
#
# Sorties SÉPARÉES de build_schema.sh (fallback intact — les artefacts
# misy_octilineaire* ne sont PAS touchés) :
#   web/transport_schema/misy_cts.json + misy_cts_centre.json   (committés)
#   tools/schema/misy_cts{,_centre}.svg                          (QA, gitignorés)
#
# ⚠️ octi est non-déterministe : committer les artefacts d'UN même run,
# contrôlés sur les SVG de CE run. Fusion par numéro de base conservée
# (JAMAIS MISY_FULL_LINE_IDS ici).
#
# Prérequis : LOOM buildé (voir en-tête de build_schema.sh).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
LOOM_BUILD="${LOOM_BUILD:-$HOME/StudioProjects/_tools/loom/build}"

for bin in topo loom octi transitmap; do
  [ -x "$LOOM_BUILD/$bin" ] || { echo "❌ LOOM introuvable: $LOOM_BUILD/$bin (voir build_schema.sh)"; exit 1; }
done

# Mêmes définitions que build_schema.sh
CENTRE_BBOX="${CENTRE_BBOX:-47.49055,-18.93339,47.52853,-18.88399}"
DESTDIR="$REPO/web/transport_schema"
mkdir -p "$DESTDIR"

# Tuning octi GÉOSCHÉMATIQUE (itérer UN paramètre à la fois, QA SVG entre
# chaque ; surchargeables par env pour les essais) :
#   GEO_PEN   : attache au tracé géographique réel (0 = libre)
#   GRID_PCT  : taille de cellule en % de la distance inter-stations —
#               > 100 % aère les zones denses
#   pens de coudes : favoriser les 45°, pénaliser 90° serrés
GEO_PEN="${GEO_PEN:-1.0}"
GRID_PCT="${GRID_PCT:-130%}"
OCTI_FLAGS=(
  --geo-pen "$GEO_PEN"
  -g "$GRID_PCT"
  --pen-180 0 --pen-135 1 --pen-90 2 --pen-45 1
  --max-grid-dist 3 --density-pen 10
  --retry-on-error
)

# render_cts <graph.json> <basename> [bbox] [cont_sidecar]
render_cts() {
  local graph="$1" base="$2" bbox="${3:-}" cont="${4:-}"
  local octi="$HERE/${base}_octi.json"
  cat "$graph" \
    | "$LOOM_BUILD/topo" \
    | MISY_BBOX="$bbox" python3 "$HERE/inject_water.py" \
    | "$LOOM_BUILD/loom" \
        --same-seg-cross-pen 25 --diff-seg-cross-pen 15 \
        --in-stat-cross-pen-same-seg 40 --in-stat-cross-pen-diff-seg 20 \
        --sep-pen 20 --in-stat-sep-pen 30 \
    | "$LOOM_BUILD/octi" "${OCTI_FLAGS[@]}" > "$octi"
  if [ -n "$cont" ]; then
    MISY_CTS=1 python3 "$HERE/octi2json.py" "$octi" "$DESTDIR/${base}.json" "$cont"
  else
    MISY_CTS=1 python3 "$HERE/octi2json.py" "$octi" "$DESTDIR/${base}.json"
  fi
  # SVG de contrôle QA (géométrie seule, jamais consommé par l'app)
  cat "$octi" \
    | "$LOOM_BUILD/transitmap" -l --line-width 14 --line-spacing 4 \
    | python3 "$HERE/tier_style.py" > "$HERE/${base}.svg"
  echo "✓ $DESTDIR/${base}.json + $HERE/${base}.svg (QA)"
}

# 1) Plan GLOBAL
echo "→ [cts global] bundle → graphe LOOM (fusion par base)"
python3 "$HERE/misy2loom.py" > "$HERE/misy_cts_graph.json"
echo "→ [cts global] topo|eau|loom|octi(geo-pen=$GEO_PEN, g=$GRID_PCT) → JSON + SVG"
render_cts "$HERE/misy_cts_graph.json" "misy_cts"

# 2) Plan CENTRE-VILLE (sous-graphe bbox + continuations)
CONT="$HERE/misy_cts_graph_centre_cont.json"
echo "→ [cts centre] bundle → graphe LOOM (bbox $CENTRE_BBOX)"
MISY_BBOX="$CENTRE_BBOX" MISY_CONT_OUT="$CONT" \
  python3 "$HERE/misy2loom.py" > "$HERE/misy_cts_graph_centre.json"
echo "→ [cts centre] topo|eau|loom|octi → JSON + SVG"
render_cts "$HERE/misy_cts_graph_centre.json" "misy_cts_centre" "$CENTRE_BBOX" "$CONT"

echo "Ensuite : QA sur les SVG, puis git add web/transport_schema/misy_cts*.json"
echo "Test app : flutter run -d chrome --dart-define=SCHEMATIC_CTS=true"
