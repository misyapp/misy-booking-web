#!/usr/bin/env python3
"""Post-traitement du SVG transitmap : HIÉRARCHIE D'ÉPAISSEUR par tier.

LOOM/transitmap rend toutes les lignes à la même largeur. On lit le tier
d'importance de chaque ligne (manifest : importance_tier 1/2/3), on en déduit
un facteur d'épaisseur par COULEUR de ligne, et on réécrit `stroke-width` de
chaque trait coloré du SVG.

  tier 1 (téléphérique, train, structurant) → épais   = squelette
  tier 2 (lignes principales)               → normal
  tier 3 (dessertes locales)                → fin

LOOM fait toute la mise en page ; on ne touche QUE la largeur de rendu.
Usage : transitmap … | python3 tier_style.py > out.svg
"""
import json
import os
import re
import sys

BUNDLE = os.path.expanduser(
    "~/StudioProjects/misy_booking_web/assets/transport_lines_public")

# Facteur d'épaisseur par tier (1 = inchangé).
TIER_FACTOR = {1: 2.4, 2: 1.0, 3: 0.62}


def main():
    man = json.load(open(os.path.join(BUNDLE, "manifest.json")))
    # couleur hex (maj) → tier le PLUS important (min) vu sur cette couleur
    color_tier = {}
    for ln in man["lines"]:
        col = ln.get("color", "0xFF1565C0")
        hx = (col[-6:] if col.startswith("0x") else col.lstrip("#")).upper()
        tier = int(ln.get("importance_tier", 2))
        color_tier[hx] = min(color_tier.get(hx, 9), tier)

    svg = sys.stdin.read()

    def repl(m):
        style = m.group(0)
        cm = re.search(r"stroke:#([0-9a-fA-F]{6})", style)
        wm = re.search(r"stroke-width:([0-9.]+)", style)
        if not cm or not wm:
            return style
        hx = cm.group(1).upper()
        if hx in ("000000", "FFFFFF"):
            return style
        f = TIER_FACTOR.get(color_tier.get(hx, 2), 1.0)
        if f == 1.0:
            return style
        w = float(wm.group(1)) * f
        return style[:wm.start(1)] + ("%.4f" % w) + style[wm.end(1):]

    sys.stdout.write(re.sub(r'style="[^"]*"', repl, svg))


if __name__ == "__main__":
    main()
