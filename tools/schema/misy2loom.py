#!/usr/bin/env python3
"""Convertit le bundle transport public Misy (manifest.json + core/*.geojson)
en un graphe de lignes GeoJSON consommable par LOOM (topo|loom|octi|transitmap).

Sortie (stdout) : FeatureCollection avec
  - Points  : nœuds-stations  {id, station_id, station_label}
  - LineStrings : arêtes       {from, to, lines:[{id,label,color}]}

On clusterise les arrêts globalement (proximité ~35 m ou même nom) → un même
arrêt partagé par plusieurs lignes = un seul nœud (correspondance). Chaque arête
= portion de la polyligne entre 2 arrêts consécutifs (sliced sur le tracé réel
pour que `topo` fusionne correctement les corridors partagés).
"""
import json
import math
import os
import re
import sys
from collections import OrderedDict

BUNDLE = os.path.expanduser(
    "~/StudioProjects/misy_booking_web/assets/transport_lines_public")
PROX_M = 35.0          # fusion par proximité
SAME_NAME_M = 250.0    # fusion par nom identique

def hav(a, b):
    R = 6371000.0
    dlat = math.radians(b[1] - a[1]); dlng = math.radians(b[0] - a[0])
    la1 = math.radians(a[1]); la2 = math.radians(b[1])
    h = math.sin(dlat/2)**2 + math.cos(la1)*math.cos(la2)*math.sin(dlng/2)**2
    return 2 * R * math.asin(math.sqrt(h))

def norm(s):
    s = (s or "").strip().lower()
    for x, y in [("à","a"),("â","a"),("ä","a"),("é","e"),("è","e"),("ê","e"),
                 ("ë","e"),("î","i"),("ï","i"),("ô","o"),("ö","o"),("ù","u"),
                 ("û","u"),("ü","u"),("ç","c"),("ñ","n")]:
        s = s.replace(x, y)
    return " ".join(s.split())

clusters = []  # {pos:[lng,lat], name, namenorm, id}
def find_or_make(pos, name):
    nn = norm(name)
    for c in clusters:
        d = hav(c["pos"], pos)
        if nn and c["namenorm"] == nn and d <= SAME_NAME_M:
            return c
        if d <= PROX_M:
            if len(name) > len(c["name"]):
                c["name"] = name; c["namenorm"] = nn
            return c
    c = {"pos": pos, "name": name, "namenorm": nn, "id": "n%d" % len(clusters)}
    clusters.append(c)
    return c

def nearest_idx(pt, coords):
    best, bi = 1e18, 0
    for i, c in enumerate(coords):
        d = (c[0]-pt[0])**2 + (c[1]-pt[1])**2
        if d < best:
            best, bi = d, i
    return bi

def line_base(num):
    """Numéro de base d'une ligne : '133A'/'133B'→'133', '147 Bleu'→'147',
    '147BIS'→'147'. Les lignes sans préfixe numérique (A, MAHITSY…) restent
    elles-mêmes. → fusionne les variantes en un seul brin par numéro."""
    m = re.match(r"^(\d+)", (num or "").strip())
    return m.group(1) if m else (num or "").strip()

def main():
    man = json.load(open(os.path.join(BUNDLE, "manifest.json")))

    # Couleur par numéro de base : on privilégie la ligne « nue » (line_number
    # == base) ; sinon la 1re variante rencontrée.
    base_color = {}
    for ln in man["lines"]:
        num = ln["line_number"]
        b = line_base(num)
        col = ln.get("color", "0xFF1565C0")
        hx = col[-6:] if col.startswith("0x") else col.lstrip("#")
        if b not in base_color or num.strip() == b:
            base_color[b] = hx

    edges = []  # {from,to,coords,lineid,label,color}
    for ln in man["lines"]:
        num = ln["line_number"]
        base = line_base(num)
        hexcol = base_color.get(base, "1565C0")
        lineid = "L_" + base.replace(" ", "_")
        label = base
        # On utilise l'aller comme séquence canonique (le retour recouvre le
        # tronc ; topo fusionnera). Couvre l'essentiel pour un schéma V1.
        ap = ln.get("aller", {}).get("asset_path")
        if not ap:
            continue
        path = os.path.join(os.path.dirname(BUNDLE), ap) if not ap.startswith("assets") \
            else os.path.join(os.path.dirname(os.path.dirname(BUNDLE)), ap)
        path = os.path.join(os.path.expanduser("~/StudioProjects/misy_booking_web"), ap)
        if not os.path.exists(path):
            print("MISS " + path, file=sys.stderr); continue
        gj = json.load(open(path))
        line_coords = None
        stops = []
        for ft in gj["features"]:
            g = ft["geometry"]
            if g["type"] == "LineString":
                line_coords = g["coordinates"]
            elif g["type"] == "Point" and ft.get("properties", {}).get("type") == "stop":
                stops.append((ft["properties"].get("order", 0),
                              g["coordinates"], ft["properties"].get("name", "")))
        if not line_coords or len(stops) < 2:
            continue
        stops.sort(key=lambda s: s[0])
        # cluster chaque arrêt + indice sur la polyligne
        nodeids = []
        idxs = []
        for _, pos, name in stops:
            c = find_or_make(pos, name)
            nodeids.append(c["id"])
            idxs.append(nearest_idx(pos, line_coords))
        # arêtes = portion de tracé entre arrêts consécutifs
        for i in range(len(stops) - 1):
            a, b = idxs[i], idxs[i+1]
            if b <= a:
                seg = [stops[i][1], stops[i+1][1]]
            else:
                seg = line_coords[a:b+1]
            if len(seg) < 2:
                seg = [stops[i][1], stops[i+1][1]]
            if nodeids[i] == nodeids[i+1]:
                continue
            edges.append({"from": nodeids[i], "to": nodeids[i+1], "coords": seg,
                          "lineid": lineid, "label": label, "color": hexcol})

    # --- Filtrage par ZONE (optionnel) : MISY_BBOX="W,S,E,N" -------------------
    # Pour les plans zoomés (centre-ville…), on ne garde que le sous-graphe
    # induit par les arrêts DANS la bbox → LOOM tourne sur un réseau réduit.
    cl_by_id = {c["id"]: c for c in clusters}
    bbox = os.environ.get("MISY_BBOX", "").strip()
    if bbox:
        W, S, E, N = (float(v) for v in bbox.split(","))

        def _in(i):
            x, y = cl_by_id[i]["pos"]
            return W <= x <= E and S <= y <= N
        edges = [e for e in edges if _in(e["from"]) and _in(e["to"])]
        print("ZONE %s → %d arêtes" % (bbox, len(edges)), file=sys.stderr)

    feats = []
    used = set(e["from"] for e in edges) | set(e["to"] for e in edges)
    for c in clusters:
        if c["id"] not in used:
            continue
        feats.append({"type": "Feature",
                      "geometry": {"type": "Point", "coordinates": c["pos"]},
                      "properties": {"id": c["id"], "station_id": c["id"],
                                     "station_label": c["name"]}})
    for e in edges:
        feats.append({"type": "Feature",
                      "geometry": {"type": "LineString", "coordinates": e["coords"]},
                      "properties": {"from": e["from"], "to": e["to"],
                                     "lines": [{"id": e["lineid"], "label": e["label"],
                                                "color": e["color"]}]}})
    json.dump({"type": "FeatureCollection", "features": feats}, sys.stdout)
    print("OK nodes=%d edges=%d" % (len(used), len(edges)), file=sys.stderr)

if __name__ == "__main__":
    main()
