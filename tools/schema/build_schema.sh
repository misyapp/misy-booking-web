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

echo "→ bundle Misy → graphe LOOM"
python3 "$HERE/misy2loom.py" > "$HERE/misy_graph.json"
echo "→ topo | loom | octi | transitmap"
cat "$HERE/misy_graph.json" \
  | "$LOOM_BUILD/topo" \
  | "$LOOM_BUILD/loom" \
  | "$LOOM_BUILD/octi" \
  | "$LOOM_BUILD/transitmap" -l > "$HERE/misy_octi.svg"

DEST="$REPO/web/transport_schema/misy_octilineaire.svg"
mkdir -p "$(dirname "$DEST")"
cp "$HERE/misy_octi.svg" "$DEST"
echo "✓ $DEST ($(wc -c < "$DEST") octets)"
echo "Ensuite : git add web/transport_schema && commit && flutter build web --release && ./deploy.sh"
