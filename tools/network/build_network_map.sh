#!/bin/bash
# Régénère les faisceaux GÉOGRAPHIQUES de la vue réseau « toutes lignes »
# (book.misy.app, mode Transport en commun) via la chaîne LOOM, et écrit
# web/transport_network/network_strands.json (consommé derrière le flag
# --dart-define=LOOM_NETWORK=true).
#
# Différences avec tools/schema/build_schema.sh (plan SCHÉMATIQUE, intact) :
#   - PAS d'octilinéarisation (`octi`) : on reste sur la vraie géographie ;
#   - PAS d'injection d'eau (elle ne sert qu'au rendu schématique) ;
#   - ids de lignes COMPLETS (MISY_FULL_LINE_IDS=1 : 193A ≠ 193B, chacune sa
#     couleur) au lieu de la fusion par numéro de base ;
#   - réseau ENTIER (pas de MISY_BBOX).
#
# Usage :
#   bash tools/network/build_network_map.sh [--pull]
#     --pull : régénère d'abord le bundle depuis les lignes EN PROD Firestore
#              (transport_lines_published, admin-approved) via
#              `node scripts/transport_editor_pull_cli.js publish-bundle`.
#
# Prérequis : LOOM cloné + buildé (voir en-tête de tools/schema/build_schema.sh).
# Override le chemin des binaires via LOOM_BUILD.
#
# ⚠️ LOOM est légèrement non-déterministe : committer le JSON et contrôler le
# SVG issus du MÊME run. Ne pas régénérer en CI.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SCHEMA="$REPO/tools/schema"
LOOM_BUILD="${LOOM_BUILD:-$HOME/StudioProjects/_tools/loom/build}"

for bin in topo loom transitmap; do
  [ -x "$LOOM_BUILD/$bin" ] || { echo "❌ LOOM introuvable: $LOOM_BUILD/$bin (voir tools/schema/build_schema.sh)"; exit 1; }
done

if [ "${1:-}" = "--pull" ]; then
  echo "→ pull Firestore prod → bundle (publish-bundle)"
  (cd "$REPO" && node scripts/transport_editor_pull_cli.js publish-bundle)
fi

DESTDIR="$REPO/web/transport_network"
mkdir -p "$DESTDIR"

echo "→ bundle → graphe LOOM (ids complets, réseau entier)"
MISY_FULL_LINE_IDS=1 python3 "$SCHEMA/misy2loom.py" > "$HERE/network_graph.json"

echo "→ topo | loom (géographique, sans octi/eau)"
cat "$HERE/network_graph.json" \
  | "$LOOM_BUILD/topo" \
  | "$LOOM_BUILD/loom" \
      --same-seg-cross-pen 25 --diff-seg-cross-pen 15 \
      --in-stat-cross-pen-same-seg 40 --in-stat-cross-pen-diff-seg 20 \
      --sep-pen 20 --in-stat-sep-pen 30 \
  > "$HERE/network_loom.json"

echo "→ loom2strands → $DESTDIR/network_strands.json"
python3 "$HERE/loom2strands.py" "$HERE/network_loom.json" "$DESTDIR/network_strands.json"

echo "→ SVG de contrôle visuel (transitmap, géographique)"
cat "$HERE/network_loom.json" \
  | "$LOOM_BUILD/transitmap" -l --line-width 14 --line-spacing 4 \
  > "$HERE/network_control.svg"

echo "✓ $DESTDIR/network_strands.json + $HERE/network_control.svg (QA visuelle)"
echo "Ensuite : ouvrir network_control.svg, puis flutter run -d chrome --dart-define=LOOM_NETWORK=true"
