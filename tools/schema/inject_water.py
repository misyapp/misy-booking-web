#!/usr/bin/env python3
"""Injecte le repère EAU dans le linegraph LOOM, APRÈS `topo` (pour éviter la
fusion des nœuds eau avec les arrêts — leçon des moignons), AVANT `loom|octi`.

L'eau devient des « lignes » sentinelles (id préfixe `W_`) qu'`octi` met en
page AVEC le réseau → placement cohérent par rapport aux arrêts/tracés et
rendu octilinéaire (façon « le Rhin » du plan CTS).

Convention d'id (parsée par octi2json.py) : `W_<KIND>__<Label_avec_underscores>__<n>`
  ex. W_RIVER__Ikopa__0 · W_CANAL__Canal_Andriantany__1 · W_LAKE__Lac_Anosy__0

- rivières/canaux : chaîne de nœuds ré-échantillonnée (~600 m) ;
- lacs : MINI-ARÊTE 2 nœuds (~200 m) au centroïde (un anneau serait écrasé par
  la grille octi) — le painter dessine un glyphe de lac à cet endroit ;
- `MISY_BBOX="W,S,E,N"` (env, plan centre) : clippe l'eau à la zone.

Usage : … | topo | python3 inject_water.py | loom | octi | …
"""
import json
import math
import os
import sys

WATER = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "water_tana.geojson")
SAMPLE_M = 600.0
LAKE_EDGE_M = 200.0
COLOR = "9FC7E8"

MLAT = 111320.0


def main():
    graph = json.load(sys.stdin)
    water = json.load(open(WATER))

    bbox = os.environ.get("MISY_BBOX", "").strip()
    clip = None
    if bbox:
        W, S, E, N = (float(v) for v in bbox.split(","))
        clip = (W, S, E, N)

    def inb(p):
        return clip is None or (clip[0] <= p[0] <= clip[2]
                                and clip[1] <= p[1] <= clip[3])

    mlng = MLAT * math.cos(math.radians(-18.88))

    def dist(a, b):
        return math.hypot((a[0] - b[0]) * mlng, (a[1] - b[1]) * MLAT)

    def resample(pts, step):
        out = [pts[0]]
        acc = 0.0
        for i in range(1, len(pts)):
            d = dist(pts[i - 1], pts[i])
            acc += d
            if acc >= step or i == len(pts) - 1:
                out.append(pts[i])
                acc = 0.0
        return out

    feats = graph["features"]
    nid = 0

    def add_chain(pts, lineid):
        nonlocal nid
        ids = []
        for p in pts:
            ids.append("wn%d" % nid)
            feats.append({"type": "Feature",
                          "geometry": {"type": "Point", "coordinates": list(p)},
                          "properties": {"id": ids[-1], "station_id": ids[-1],
                                         "station_label": ""}})
            nid += 1
        for i in range(len(ids) - 1):
            feats.append({"type": "Feature",
                          "geometry": {"type": "LineString",
                                       "coordinates": [list(pts[i]), list(pts[i + 1])]},
                          "properties": {"from": ids[i], "to": ids[i + 1],
                                         "lines": [{"id": lineid, "label": "",
                                                    "color": COLOR}]}})

    n_chains = 0
    for k, f in enumerate(water.get("features", [])):
        pr = f.get("properties", {})
        g = f["geometry"]
        kind = pr.get("kind", "river")
        label = (pr.get("label", "") or "").replace(" ", "_")
        if g["type"] == "LineString":
            # clip à la zone : on garde les sous-suites de points dans la bbox
            runs, cur = [], []
            for p in g["coordinates"]:
                if inb(p):
                    cur.append(tuple(p))
                elif cur:
                    runs.append(cur)
                    cur = []
            if cur:
                runs.append(cur)
            for r in runs:
                if len(r) < 2:
                    continue
                pts = resample(r, SAMPLE_M)
                if len(pts) < 2:
                    continue
                add_chain(pts, "W_%s__%s__%d" % (kind.upper(), label, n_chains))
                n_chains += 1
        elif g["type"] == "Polygon":
            ring = g["coordinates"][0]
            cx = sum(p[0] for p in ring) / len(ring)
            cy = sum(p[1] for p in ring) / len(ring)
            if not inb((cx, cy)):
                continue
            half = (LAKE_EDGE_M / 2.0) / mlng
            add_chain([(cx - half, cy), (cx + half, cy)],
                      "W_LAKE__%s__%d" % (label, n_chains))
            n_chains += 1

    print("EAU injectée: %d chaînes (clip=%s)" % (n_chains, bbox or "non"),
          file=sys.stderr)
    json.dump(graph, sys.stdout)


if __name__ == "__main__":
    main()
