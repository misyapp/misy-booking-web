#!/bin/bash
# Régénère le plan SCHÉMATIQUE octilinéaire (façon métro) du réseau taxi-be
# via la chaîne LOOM, et le copie dans web/transport_schema/.
#
# Prérequis (build local, hors repo) : LOOM cloné + buildé.
#   brew install cmake
#   git clone --recurse-submodules https://github.com/ad-freiburg/loom.git \
#     ~/StudioProjects/_tools/loom
#   cd ~/StudioProjects/_tools/loom && mkdir build && cd build \
#     && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j4
#
# Override le chemin des binaires LOOM via LOOM_BUILD si besoin.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
LOOM_BUILD="${LOOM_BUILD:-$HOME/StudioProjects/_tools/loom/build}"

for bin in topo loom octi transitmap; do
  [ -x "$LOOM_BUILD/$bin" ] || { echo "❌ LOOM introuvable: $LOOM_BUILD/$bin (voir en-tête)"; exit 1; }
done

# Bbox du centre-ville (pic de densité ±2000 m, élargie ~1.5 km au NORD) : W,S,E,N
CENTRE_BBOX="${CENTRE_BBOX:-47.49055,-18.93339,47.52853,-18.88399}"

DESTDIR="$REPO/web/transport_schema"
mkdir -p "$DESTDIR"

# render <graph.json> <basename> [bbox] [cont_sidecar]
# topo | inject_water (EAU dans LOOM) | loom | octi → JSON (app) + SVG (fallback)
render() {
  local graph="$1" base="$2" bbox="${3:-}" cont="${4:-}"
  local octi="$HERE/${base}_octi.json"
  cat "$graph" \
    | "$LOOM_BUILD/topo" \
    | MISY_BBOX="$bbox" python3 "$HERE/inject_water.py" \
    | "$LOOM_BUILD/loom" \
        --same-seg-cross-pen 25 --diff-seg-cross-pen 15 \
        --in-stat-cross-pen-same-seg 40 --in-stat-cross-pen-diff-seg 20 \
        --sep-pen 20 --in-stat-sep-pen 30 \
    | "$LOOM_BUILD/octi" > "$octi"
  # JSON consommé par le CustomPainter Flutter (zoom sémantique)
  if [ -n "$cont" ]; then
    python3 "$HERE/octi2json.py" "$octi" "$DESTDIR/${base}.json" "$cont"
  else
    python3 "$HERE/octi2json.py" "$octi" "$DESTDIR/${base}.json"
  fi
  # SVG conservé en fallback / aperçu
  cat "$octi" \
    | "$LOOM_BUILD/transitmap" -l --line-width 14 --line-spacing 4 \
    | python3 "$HERE/tier_style.py" > "$DESTDIR/${base}.svg"
  echo "✓ $DESTDIR/${base}.{json,svg}"
}

# 1) Plan GLOBAL
echo "→ [global] bundle → graphe LOOM"
python3 "$HERE/misy2loom.py" > "$HERE/misy_graph.json"
echo "→ [global] topo|eau|loom|octi → JSON + SVG"
render "$HERE/misy_graph.json" "misy_octilineaire"

# 2) Plan CENTRE-VILLE (sous-graphe dans la bbox + continuations)
CONT="$HERE/misy_graph_centre_cont.json"
echo "→ [centre] bundle → graphe LOOM (bbox $CENTRE_BBOX)"
MISY_BBOX="$CENTRE_BBOX" MISY_CONT_OUT="$CONT" \
  python3 "$HERE/misy2loom.py" > "$HERE/misy_graph_centre.json"
echo "→ [centre] topo|eau|loom|octi → JSON + SVG"
render "$HERE/misy_graph_centre.json" "misy_octilineaire_centre" "$CENTRE_BBOX" "$CONT"

echo "Ensuite : git add web/transport_schema && commit && flutter build web --release && ./deploy.sh"
