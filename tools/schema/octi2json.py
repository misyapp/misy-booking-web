#!/usr/bin/env python3
"""Convertit la sortie `octi` (linegraph octilinéarisé, EAU incluse via
inject_water.py) en un JSON compact rendu par le CustomPainter Flutter
(zoom sémantique).

- stations : nœuds octi (positions octilinéarisées projetées) + nom + degré ;
- edges    : géométrie octi + faisceau ordonné {color, tier} par ligne ;
- water    : lignes sentinelles `W_<KIND>__<Label>__<n>` (injectées AVANT loom)
             → réassemblées par id ; lacs (W_LAKE) → point central (glyphe) ;
- continuations (plan centre) : sidecar de misy2loom (station_id + direction
  sortante [est,nord]) → flèches « la ligne continue hors zone ».

Sortie JSON :
  { "size":[w,h], "edges":[...], "stations":[...],
    "water":[{"kind","label","pts":[[x,y]...]}],
    "continuations":[{"x","y","dx","dy","n"}], "centreRect":[x,y,w,h] }

Usage : python3 octi2json.py <octi.json> <out.json> [continuations_sidecar.json]
"""
import collections
import json
import math
import os
import re
import sys

BUNDLE = os.path.expanduser(
    "~/StudioProjects/misy_booking_web/assets/transport_lines_public")
TARGET_W = 1600.0
PAD = 70.0

# MISY_CTS=1 : enrichissements pour le rendu CTS (painter v2) — le défaut
# reste BIT-À-BIT identique (fallback). Ajoute : `label` par brin d'edge
# (pastilles de numéro), `legendLines` global (légende), kind `pole`
# (double anneau : gares routières / hubs majeurs).
CTS = os.environ.get("MISY_CTS", "").strip() in ("1", "true", "yes")
# Pôle d'échange : seuil de lignes desservies OU nom épinglé (sous-chaîne
# normalisée — mots rares pour éviter les faux positifs).
POLE_N = int(os.environ.get("MISY_POLE_N", "22"))
POLE_PINNED = ("maki", "gare routiere", "soarano")


def norm_name(s):
    s = (s or "").strip().lower()
    for x, y in [("à", "a"), ("â", "a"), ("é", "e"), ("è", "e"), ("ê", "e"),
                 ("î", "i"), ("ô", "o"), ("ù", "u"), ("û", "u"), ("ç", "c")]:
        s = s.replace(x, y)
    return " ".join(s.split())


def line_base(num):
    m = re.match(r"^(\d+)", (num or "").strip())
    return m.group(1) if m else (num or "").strip()


def dp(pts, tol=6.0):
    """Douglas-Peucker (espace canvas) — garde les vrais coudes, tue le
    micro-wobble géographique résiduel d'octi."""
    if len(pts) < 3:
        return pts
    ax, ay = pts[0]
    bx, by = pts[-1]
    dmax, idx = 0.0, 0
    for i in range(1, len(pts) - 1):
        px, py = pts[i]
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
        d = math.hypot(px - (ax + t * dx), py - (ay + t * dy))
        if d > dmax:
            dmax, idx = d, i
    if dmax > tol:
        return dp(pts[:idx + 1], tol)[:-1] + dp(pts[idx:], tol)
    return [pts[0], pts[-1]]


def parse_water_id(lid):
    """W_RIVER__Ikopa__0 → ("river", "Ikopa") ; None si pas une eau."""
    if not lid.startswith("W_"):
        return None
    parts = lid.split("__")
    kind = parts[0][2:].lower()
    label = parts[1].replace("_", " ") if len(parts) > 1 else ""
    return (kind, label)


def main():
    octi = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    cont_path = sys.argv[3] if len(sys.argv) > 3 else None

    man = json.load(open(os.path.join(BUNDLE, "manifest.json")))
    tier_of = {}
    for ln in man["lines"]:
        b = line_base(ln["line_number"])
        tier_of[b] = min(tier_of.get(b, 9), int(ln.get("importance_tier", 2)))

    feats = octi["features"]
    nodes = [f for f in feats if f["geometry"]["type"] == "Point"]
    lines = [f for f in feats if f["geometry"]["type"] == "LineString"]

    # ---- projection équirectangulaire commune (bornes = TOUS les nœuds) ----
    lats = [f["geometry"]["coordinates"][1] for f in nodes]
    midlat = (min(lats) + max(lats)) / 2.0
    cosm = math.cos(math.radians(midlat))

    def raw(lng, lat):
        return (lng * cosm, -lat)

    rxs = [raw(*f["geometry"]["coordinates"])[0] for f in nodes]
    rys = [raw(*f["geometry"]["coordinates"])[1] for f in nodes]
    minx, maxx, miny, maxy = min(rxs), max(rxs), min(rys), max(rys)
    scale = (TARGET_W - 2 * PAD) / (maxx - minx) if maxx > minx else 1.0
    W = TARGET_W
    H = (maxy - miny) * scale + 2 * PAD

    def proj(lng, lat):
        x, y = raw(lng, lat)
        return [round((x - minx) * scale + PAD, 1),
                round((y - miny) * scale + PAD, 1)]

    # ---- séparer EAU / réseau ----
    net_lines, water_segs = [], collections.defaultdict(list)
    for f in lines:
        ll = f["properties"].get("lines", [])
        wid = parse_water_id(ll[0]["id"]) if ll else None
        if wid and all(parse_water_id(l["id"]) for l in ll):
            water_segs[ll[0]["id"]].append(
                dp([proj(c[0], c[1]) for c in f["geometry"]["coordinates"]]))
        else:
            net_lines.append(f)

    # ---- lignes par nœud (réseau seul) ----
    node_lines = collections.defaultdict(set)
    for f in net_lines:
        p = f["properties"]
        for ln in p.get("lines", []):
            node_lines[p["from"]].add(ln["label"])
            node_lines[p["to"]].add(ln["label"])

    # ---- stations (nœuds eau « wn* » exclus) ----
    stations = []
    by_station_id = {}
    for f in nodes:
        p = f["properties"]
        sid = str(p.get("station_id", ""))
        by_station_id[sid] = f
        if sid.startswith("wn"):
            continue
        name = p.get("station_label", "") or ""
        deg = int(p.get("deg", 2))
        lns = node_lines.get(p["id"], set())
        if not lns:
            continue
        tier = min((tier_of.get(l, 2) for l in lns), default=2)
        if deg <= 1:
            kind = "terminus"
        elif len(lns) >= 7 or deg >= 4:
            kind = "interchange"
        else:
            kind = "stop"
        if CTS:
            nn = norm_name(name)
            if len(lns) >= POLE_N or any(p in nn for p in POLE_PINNED):
                kind = "pole"  # candidat — dédup spatiale plus bas
        x, y = proj(*f["geometry"]["coordinates"])
        stations.append({"x": x, "y": y, "name": name, "kind": kind,
                         "tier": tier, "n": len(lns)})

    if CTS:
        # Dédup spatiale des pôles : le seuil/épinglage marque tout le
        # QUARTIER (4× Anosy, 4× Soarano…) ; on ne garde que le meilleur
        # (n max) dans un rayon canvas, les autres redeviennent des
        # correspondances. ~80 px/km sur le plan global.
        POLE_RADIUS = 55.0
        cands = sorted((s for s in stations if s["kind"] == "pole"),
                       key=lambda s: -s["n"])
        kept = []
        for s in cands:
            if any(math.hypot(s["x"] - k["x"], s["y"] - k["y"]) < POLE_RADIUS
                   for k in kept):
                s["kind"] = "interchange"
            else:
                kept.append(s)

    # ---- arêtes réseau ----
    # 1) SIMPLIFICATION Douglas-Peucker : les points intermédiaires d'octi sont
    #    des résidus géographiques courbes → brins « pas linéaires ». On garde
    #    les vrais coudes (L octilinéaires), on tue le micro-wobble.
    # 2) ORIENTATION CANONIQUE : sans elle, le côté des offsets de faisceau
    #    saute d'une arête à l'autre (brins « cassés » aux nœuds). On retourne
    #    pts ET l'ordre des lignes ENSEMBLE (l'ordre loom est relatif au sens
    #    de parcours de l'arête).
    edges = []
    for f in net_lines:
        pts = dp([proj(c[0], c[1]) for c in f["geometry"]["coordinates"]])
        if CTS:
            # `label` conservé : pastilles de numéro le long des brins.
            ll = [{"color": "#" + l["color"],
                   "tier": tier_of.get(l["label"], 2),
                   "label": l["label"]}
                  for l in f["properties"].get("lines", [])]
        else:
            ll = [{"color": "#" + l["color"],
                   "tier": tier_of.get(l["label"], 2)}
                  for l in f["properties"].get("lines", [])]
        if len(pts) < 2 or not ll:
            continue
        dx = pts[-1][0] - pts[0][0]
        dy = pts[-1][1] - pts[0][1]
        if dx < 0 or (dx == 0 and dy < 0):
            pts.reverse()
            ll.reverse()
        edges.append({"pts": pts, "lines": ll})

    # ---- eau : réassembler les segments par id (jointure par extrémités) ----
    def stitch(segs):
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
                    if a[-1] == b[0]:
                        a.extend(b[1:]); chains[j] = []; merged = True
                    elif a[-1] == b[-1]:
                        a.extend(b[-2::-1]); chains[j] = []; merged = True
                    elif a[0] == b[-1]:
                        chains[i] = b[:-1] + a; chains[j] = []; merged = True
                    elif a[0] == b[0]:
                        chains[i] = b[::-1][:-1] + a; chains[j] = []; merged = True
        return [c for c in chains if len(c) >= 2]

    wlist = []
    for lid, segs in water_segs.items():
        kind, label = parse_water_id(lid)
        if kind == "lake":
            allp = [p for s in segs for p in s]
            cx = sum(p[0] for p in allp) / len(allp)
            cy = sum(p[1] for p in allp) / len(allp)
            wlist.append({"kind": "lake", "label": label,
                          "pts": [[round(cx, 1), round(cy, 1)]]})
        else:
            for chain in stitch(segs):
                wlist.append({"kind": kind, "label": label, "pts": chain})

    # ---- continuations (sidecar misy2loom, plan centre) ----
    continuations = []
    if cont_path and os.path.exists(cont_path):
        miss = 0
        for c in json.load(open(cont_path)):
            f = by_station_id.get(str(c["station_id"]))
            if f is None:
                miss += 1
                continue
            x, y = proj(*f["geometry"]["coordinates"])
            dx, dy = c["dir"][0], -c["dir"][1]   # [est,nord] → canvas (y vers le bas)
            d = math.hypot(dx, dy) or 1.0
            continuations.append({"x": x, "y": y,
                                  "dx": round(dx / d, 3), "dy": round(dy / d, 3),
                                  "n": int(c.get("n", 1))})
        if miss:
            sys.stderr.write("⚠ %d continuations sans nœud octi (fusion topo)\n" % miss)

    # ---- bbox dense (carré « centre-ville ») ----
    cell = max(W, H) / 36.0
    grid = collections.Counter()
    for s in stations:
        grid[(int(s["x"] // cell), int(s["y"] // cell))] += 1
    centre_rect = None
    if grid:
        peak = max(grid.values())
        dense = [(gx, gy) for (gx, gy), c in grid.items() if c >= peak * 0.32]
        xs = [gx for gx, _ in dense]
        ys = [gy for _, gy in dense]
        x0 = max(0, min(xs) * cell - cell * 0.5)
        y0 = max(0, min(ys) * cell - cell * 0.5)
        x1 = min(W, (max(xs) + 1) * cell + cell * 0.5)
        y1 = min(H, (max(ys) + 1) * cell + cell * 0.5)
        centre_rect = [round(x0, 1), round(y0, 1),
                       round(x1 - x0, 1), round(y1 - y0, 1)]

    data = {"size": [round(W, 1), round(H, 1)], "edges": edges,
            "stations": stations, "water": wlist,
            "continuations": continuations, "centreRect": centre_rect}
    if CTS:
        # Liste globale des lignes (légende) : dédup par label, tri tier
        # puis numéro de base (numériques d'abord), pastille = couleur ligne.
        # `name` = display_name du manifest quand il diffère du label
        # (TELEPHERIQUE_Orange → « Téléphérique Orange »).
        display_of = {}
        for ln in man["lines"]:
            b = line_base(ln["line_number"])
            if b not in display_of or ln["line_number"].strip() == b:
                display_of[b] = ln.get("display_name", "")
        seen = {}
        for f in net_lines:
            for l in f["properties"].get("lines", []):
                entry = {
                    "label": l["label"],
                    "color": "#" + l["color"],
                    "tier": tier_of.get(l["label"], 2),
                }
                disp = display_of.get(l["label"], "")
                if disp and disp != l["label"]:
                    entry["name"] = disp
                seen.setdefault(l["label"], entry)

        def legend_key(e):
            m = re.match(r"^(\d+)", e["label"])
            return (e["tier"], 0 if m else 1,
                    int(m.group(1)) if m else 0, e["label"])

        data["legendLines"] = sorted(seen.values(), key=legend_key)
    json.dump(data, open(out, "w"), separators=(",", ":"))
    sys.stderr.write(
        "JSON %s : %d edges, %d stations, %d water, %d continuations\n"
        % (out, len(edges), len(stations), len(wlist), len(continuations)))


if __name__ == "__main__":
    main()
