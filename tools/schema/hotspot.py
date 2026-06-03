#!/usr/bin/env python3
"""Calcule le RECTANGLE « centre-ville » dans les coordonnées du SVG GLOBAL.

Le carré cliquable de l'app doit se poser sur le cœur dense du plan global.
On repère ce cœur par la DENSITÉ des stations (`station-poly`) : on grille le
plan, on garde les cellules denses (≥ 30 % du pic) et on prend leur bbox.

Sortie : web/transport_schema/centre_hotspot.json
  { "viewBox": [w, h], "rect": [x, y, w, h] }   (coordonnées SVG)

Usage : python3 hotspot.py <global.svg> <out.json>
"""
import json
import re
import sys


def main():
    svg = open(sys.argv[1]).read()
    out = sys.argv[2]

    m = re.search(r'viewBox="([\d.\- ]+)"', svg)
    _, _, vbw, vbh = map(float, m.group(1).split())

    pts = []
    for mm in re.finditer(r'<polygon class="station-poly"[^>]*points="([^"]*)"', svg):
        cc = [tuple(map(float, p.split(",")))
              for p in mm.group(1).split() if "," in p]
        if cc:
            pts.append((sum(c[0] for c in cc) / len(cc),
                        sum(c[1] for c in cc) / len(cc)))

    # grille 40×40 → histogramme de densité
    cell = max(vbw, vbh) / 40.0
    grid = {}
    for x, y in pts:
        k = (int(x // cell), int(y // cell))
        grid[k] = grid.get(k, 0) + 1
    peak = max(grid.values())
    thr = peak * 0.30
    dense = [(gx, gy) for (gx, gy), n in grid.items() if n >= thr]

    xs = [gx for gx, _ in dense]
    ys = [gy for _, gy in dense]
    x0 = min(xs) * cell
    y0 = min(ys) * cell
    x1 = (max(xs) + 1) * cell
    y1 = (max(ys) + 1) * cell
    # petite marge
    pad = cell * 0.6
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(vbw, x1 + pad), min(vbh, y1 + pad)

    data = {"viewBox": [round(vbw, 2), round(vbh, 2)],
            "rect": [round(x0, 2), round(y0, 2),
                     round(x1 - x0, 2), round(y1 - y0, 2)]}
    json.dump(data, open(out, "w"))
    sys.stderr.write("HOTSPOT %s\n" % data)


if __name__ == "__main__":
    main()
