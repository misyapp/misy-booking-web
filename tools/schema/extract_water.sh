#!/bin/bash
# Extrait le repère EAU d'Antananarivo (Ikopa, Canal Andriantany, lacs) depuis
# le PBF Geofabrik LOCAL (téléchargé par planetiler pour les tuiles) et produit
# tools/schema/water_tana.geojson (réel, simplifié) consommé par inject_water.py.
#
# Prérequis : brew install osmium-tool ; PBF dans _tools/tiles/data/sources/.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PBF="${MISY_PBF:-$HOME/StudioProjects/_tools/tiles/data/sources/madagascar.osm.pbf}"
[ -f "$PBF" ] || { echo "❌ PBF introuvable: $PBF"; exit 1; }
command -v osmium >/dev/null || { echo "❌ osmium manquant (brew install osmium-tool)"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ extract bbox Tana"
osmium extract -b 47.30,-19.05,47.65,-18.70 "$PBF" -o "$TMP/tana.osm.pbf" --overwrite
echo "→ tags-filter eau"
osmium tags-filter "$TMP/tana.osm.pbf" w/waterway=river,canal w/natural=water r/natural=water \
  -o "$TMP/water.osm.pbf" --overwrite
echo "→ export GeoJSON"
osmium export "$TMP/water.osm.pbf" -o "$TMP/water_full.geojson" --overwrite

echo "→ filtre + stitch + simplification"
python3 - "$TMP/water_full.geojson" "$HERE/water_tana.geojson" <<'PY'
import json, math, sys

src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))

MLAT = 111320.0
MLNG = 111320.0 * math.cos(math.radians(-18.88))

def m(a, b):  # distance mètres
    return math.hypot((a[0]-b[0])*MLNG, (a[1]-b[1])*MLAT)

def simplify(pts, tol=40.0):  # Douglas-Peucker
    if len(pts) < 3:
        return pts
    def seg_d(p, a, b):
        ax, ay = (a[0]*MLNG, a[1]*MLAT); bx, by = (b[0]*MLNG, b[1]*MLAT)
        px, py = (p[0]*MLNG, p[1]*MLAT)
        dx, dy = bx-ax, by-ay
        L2 = dx*dx+dy*dy
        t = 0 if L2 == 0 else max(0, min(1, ((px-ax)*dx+(py-ay)*dy)/L2))
        return math.hypot(px-(ax+t*dx), py-(ay+t*dy))
    dmax, idx = 0, 0
    for i in range(1, len(pts)-1):
        dd = seg_d(pts[i], pts[0], pts[-1])
        if dd > dmax:
            dmax, idx = dd, i
    if dmax > tol:
        return simplify(pts[:idx+1], tol)[:-1] + simplify(pts[idx:], tol)
    return [pts[0], pts[-1]]

def stitch(segs, tol=120.0):  # joint glouton (extrémités < tol mètres)
    chains = [list(s) for s in segs]
    merged = True
    while merged:
        merged = False
        for i in range(len(chains)):
            if not chains[i]:
                continue
            for j in range(len(chains)):
                if i == j or not chains[j]:
                    continue
                a, b = chains[i], chains[j]
                if m(a[-1], b[0]) < tol:   a.extend(b[1:]);  chains[j] = []; merged = True
                elif m(a[-1], b[-1]) < tol: a.extend(b[-2::-1]); chains[j] = []; merged = True
                elif m(a[0], b[-1]) < tol:  chains[i] = b[:-1]+a; chains[j] = []; merged = True
                elif m(a[0], b[0]) < tol:   chains[i] = b[::-1][:-1]+a; chains[j] = []; merged = True
    return [c for c in chains if len(c) >= 2]

def length_m(pts):
    return sum(m(pts[i], pts[i+1]) for i in range(len(pts)-1))

def name_of(f):
    return (f.get('properties', {}).get('name') or '')

rivers, canals = [], []
lakes = {}
for f in d['features']:
    p = f.get('properties', {})
    g = f['geometry']
    n = name_of(f).lower()
    if g['type'] == 'LineString':
        if p.get('waterway') == 'river' and 'ikopa' in n:
            rivers.append(g['coordinates'])
        elif p.get('waterway') == 'canal' and 'andriantany' in n:
            canals.append(g['coordinates'])
    elif g['type'] in ('Polygon', 'MultiPolygon') and p.get('natural') == 'water':
        ring = (g['coordinates'][0] if g['type'] == 'Polygon'
                else max((poly[0] for poly in g['coordinates']), key=len))
        if 'anosy' in n:
            lakes['Lac Anosy'] = ring
        elif 'masay' in n:
            lakes['Marais Masay'] = ring
        elif 'behoririka' in n:
            lakes['Behoririka'] = ring

feats = []
for label, segs, kind, minlen in (("Ikopa", rivers, "river", 2000.0),
                                  ("Canal Andriantany", canals, "canal", 800.0)):
    for chain in stitch(segs):
        if length_m(chain) < minlen:   # écarte bras/fragments mineurs
            continue
        s = simplify(chain)
        if len(s) >= 2:
            feats.append({"type": "Feature",
                          "properties": {"kind": kind, "label": label},
                          "geometry": {"type": "LineString", "coordinates":
                                       [[round(x, 5), round(y, 5)] for x, y in s]}})
for label, ring in lakes.items():
    s = simplify(ring, 25.0)
    feats.append({"type": "Feature",
                  "properties": {"kind": "lake", "label": label},
                  "geometry": {"type": "Polygon", "coordinates":
                               [[[round(x, 5), round(y, 5)] for x, y in s]]}})

out = {"type": "FeatureCollection",
       "_note": "Repère EAU Antananarivo — EXTRAIT OSM RÉEL (madagascar.osm.pbf "
                "Geofabrik via osmium, stitch + Douglas-Peucker). Régénérer : "
                "tools/schema/extract_water.sh",
       "features": feats}
json.dump(out, open(dst, 'w'), ensure_ascii=False, indent=1)
tot = sum(len(f['geometry']['coordinates']) if f['geometry']['type'] == 'LineString'
          else len(f['geometry']['coordinates'][0]) for f in feats)
print("OK %d features, %d points → %s" % (len(feats), tot, dst))
PY
