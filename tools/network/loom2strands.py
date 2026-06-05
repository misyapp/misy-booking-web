#!/usr/bin/env python3
"""Convertit la sortie GÉOGRAPHIQUE de LOOM (post `topo | loom`, sans octi)
en « strand runs » consommés par la vue réseau de home_screen_web.dart :

    web/transport_network/network_strands.json
    { "meta":  {...},
      "lines": { "<line_number>": { "runs": [
          { "k": <densité max du corridor sur la pièce>,
            "pts": [[lat, lng, vLat, vLng], ...] } ] } } }

(vLat, vLng) = perpendiculaire unitaire (composantes nord/est, espace mètres)
× facteur de slot — la sémantique exacte de `_StrandPt` : le runtime applique
l'offset réel `slotWM` au zoom courant via `_applyStrandOffset`.

Pièges gérés (cf. tools/network/README.md et mémoire projet) :
  - l'ordre `properties.lines` d'une arête LOOM est RELATIF à son sens de
    parcours → ORIENTATION CANONIQUE (on retourne géométrie ET ordre
    ensemble, même règle que octi2json.py) ; la perpendiculaire étant
    calculée dans le même référentiel canonique, le produit slot×perp est
    invariant au retournement ;
  - rampes douces aux changements de slot (lissage du vecteur sur ±RAMP_M
    le long du parcours, après densification) — pas de marche aux nœuds ;
  - runs scindés au franchissement du seuil « corridor dense » (k ≤ DENSE_K
    vs k > DENSE_K) pour que le runtime amincisse les brins par pièce ;
  - tier 1 (train, téléphérique) non émis : tracé pur au-dessus, hors
    faisceau (comportement historique du runtime).

Usage : loom2strands.py <network_loom.json> <network_strands.json>
"""
import json
import math
import os
import sys
from collections import defaultdict
from datetime import date

BUNDLE = os.path.expanduser(
    "~/StudioProjects/misy_booking_web/assets/transport_lines_public")

DENSE_K = 6        # au-delà : corridor dense → brins amincis côté runtime
RAMP_M = 50.0      # demi-fenêtre de lissage du vecteur le long du parcours
STEP_M = 25.0      # densification max entre 2 points (zones courantes)
STEP_NODE_M = 9.0  # densification FINE près des jonctions (rampes nettes)
SHORT_EDGE_M = 20.0  # arête plus courte → hérite slot/k du voisin long
PRUNE_POS_M = 1.5  # simplification : écart max au segment (mètres)
PRUNE_VEC = 0.06   # simplification : écart max du vecteur à l'interpolation

M_LAT = 111320.0


def mlng_at(lat):
    return M_LAT * math.cos(math.radians(lat))


def dist_m(a, b, mlng):
    return math.hypot((b[0] - a[0]) * mlng, (b[1] - a[1]) * M_LAT)


def load_tier1_labels():
    """Lignes tier 1 du manifest (train, téléphérique) → exclues de l'émission."""
    man = json.load(open(os.path.join(BUNDLE, "manifest.json")))
    return {ln["line_number"].strip() for ln in man["lines"]
            if ln.get("importance_tier", 2) == 1}


def canonicalize(coords, lines, mlng):
    """Orientation canonique d'une arête : géométrie ET ordre retournés
    ENSEMBLE si l'arête est parcourue « à l'envers » (règle octi2json,
    transposée en mètres locaux pour ne pas biaiser par l'anisotropie)."""
    dx = (coords[-1][0] - coords[0][0]) * mlng
    dy = (coords[-1][1] - coords[0][1]) * M_LAT
    if dx < 0 or (dx == 0 and dy < 0):
        return list(reversed(coords)), list(reversed(lines)), True
    return coords, lines, False


def edge_perps(coords, mlng):
    """Perpendiculaire unitaire (nord, est) par point de la géométrie
    CANONIQUE : tangente par différence centrale, tournée de +90° boussole
    ((N,E) → (−E,N)) — même convention que _precomputeStrandRuns."""
    n = len(coords)
    out = []
    for i in range(n):
        a = coords[max(0, i - 1)]
        b = coords[min(n - 1, i + 1)]
        tE = (b[0] - a[0]) * mlng
        tN = (b[1] - a[1]) * M_LAT
        ln = math.hypot(tE, tN)
        if ln < 1e-9:
            out.append(out[-1] if out else (0.0, 0.0))
            continue
        out.append((-tE / ln, tN / ln))  # (perpN, perpE)
    return out


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    gj = json.load(open(sys.argv[1]))
    tier1 = load_tier1_labels()

    # ── 1. Arêtes canonicalisées + entrées par ligne ─────────────────────
    # entry = par (ligne, arête) : géométrie canonique partagée, slot, k.
    edges = []           # [{coords, perps, k, node_a, node_b}]  (canonique)
    by_line = defaultdict(list)   # label → [entryIdx]
    entry_edge = []      # entryIdx → (edgeIdx, slot)
    lat0 = None
    for ft in gj["features"]:
        if ft["geometry"]["type"] != "LineString":
            continue
        coords = ft["geometry"]["coordinates"]
        if len(coords) < 2:
            continue
        if lat0 is None:
            lat0 = coords[0][1]
        mlng = mlng_at(coords[0][1])
        props = ft.get("properties", {})
        lines = props.get("lines", [])
        # dédup sécurité (ordre préservé)
        seen, ll = set(), []
        for l in lines:
            if l["id"] in seen:
                continue
            seen.add(l["id"])
            ll.append(l)
        if not ll:
            continue
        coords_c, ll_c, flipped = canonicalize(coords, ll, mlng)
        node_a = props.get("from")
        node_b = props.get("to")
        if flipped:
            node_a, node_b = node_b, node_a
        k = len(ll_c)
        eidx = len(edges)
        edges.append({
            "coords": coords_c,
            "perps": edge_perps(coords_c, mlng),
            "k": k,
            "a": node_a,   # nœud côté coords_c[0]
            "b": node_b,   # nœud côté coords_c[-1]
        })
        for idx, l in enumerate(ll_c):
            label = l["label"].strip()
            if label in tier1:
                continue
            slot = idx - (k - 1) / 2.0
            by_line[label].append(len(entry_edge))
            entry_edge.append((eidx, slot, label))

    # ── 2. Chaînage par ligne (runs continus) ────────────────────────────
    # Marche gloutonne : on coupe quand le nœud n'a pas EXACTEMENT 2
    # incidences pour la ligne (embranchement/boucle → runs séparés, qui
    # partagent leur point de bout : aucun trou visuel).
    out_lines = {}
    max_corridor = 0
    for label, entry_idxs in by_line.items():
        incid = defaultdict(list)   # node → [(entryIdx, 'a'|'b')]
        for ei in entry_idxs:
            eidx, _, _ = entry_edge[ei]
            incid[edges[eidx]["a"]].append((ei, "a"))
            incid[edges[eidx]["b"]].append((ei, "b"))
        unused = set(entry_idxs)
        chains = []

        def walk(start_ei, start_end):
            """Suit la ligne depuis une extrémité d'arête ; renvoie la liste
            ordonnée de (entryIdx, reversed_for_travel)."""
            chain = []
            ei, end = start_ei, start_end
            while True:
                unused.discard(ei)
                eidx, _, _ = entry_edge[ei]
                # entré par `end` → on parcourt vers l'autre bout
                rev = end == "b"
                chain.append((ei, rev))
                nxt_node = edges[eidx]["a" if rev else "b"]
                cands = [(j, e) for (j, e) in incid[nxt_node] if j in unused]
                if len(incid[nxt_node]) != 2 or len(cands) != 1:
                    return chain
                ei, end = cands[0]

        # extrémités d'abord (nœuds à 1 incidence), puis boucles résiduelles
        for node, inc in incid.items():
            if len(inc) == 1 and inc[0][0] in unused:
                chains.append(walk(*inc[0]))
        while unused:
            ei = min(unused)
            chains.append(walk(ei, "a"))

        # ── 3. Pièces → points annotés + densification + lissage ────────
        runs = []
        for chain in chains:
            # 3a. FUSION DES ARÊTES COURTES : une arête < SHORT_EDGE_M
            # (arrêts très proches) fait flicker le slot aux nœuds →
            # elle hérite slot ET k de son plus proche voisin long (avant,
            # sinon après) et devient une simple continuation.
            entries = []
            for (ei, rev) in chain:
                eidx, slot, _ = entry_edge[ei]
                e = edges[eidx]
                mlng_e = mlng_at(e["coords"][0][1])
                length = sum(
                    dist_m(e["coords"][i], e["coords"][i + 1], mlng_e)
                    for i in range(len(e["coords"]) - 1))
                entries.append({"e": e, "rev": rev, "slot": slot,
                                "k": e["k"], "len": length})
            for i, en in enumerate(entries):
                if en["len"] >= SHORT_EDGE_M:
                    continue
                donor = None
                for j in range(i - 1, -1, -1):
                    if entries[j]["len"] >= SHORT_EDGE_M:
                        donor = entries[j]
                        break
                if donor is None:
                    for j in range(i + 1, len(entries)):
                        if entries[j]["len"] >= SHORT_EDGE_M:
                            donor = entries[j]
                            break
                if donor is not None:
                    en["slot"] = donor["slot"]
                    en["k"] = donor["k"]

            pts = []        # [lng, lat, vN, vE, k]
            junctions = []  # index des points de raccord entre arêtes
            for en in entries:
                e, rev, slot = en["e"], en["rev"], en["slot"]
                idxs = range(len(e["coords"]) - 1, -1, -1) if rev \
                    else range(len(e["coords"]))
                for i in idxs:
                    c = e["coords"][i]
                    pN, pE = e["perps"][i]
                    p = (c[0], c[1], pN * slot, pE * slot, en["k"])
                    if pts and pts[-1][0] == p[0] and pts[-1][1] == p[1]:
                        # jonction d'arêtes : même position — on garde la
                        # NOUVELLE annotation (slot/k de l'arête entrante),
                        # le lissage fera la rampe.
                        pts[-1] = p
                        junctions.append(len(pts) - 1)
                        continue
                    pts.append(p)
                max_corridor = max(max_corridor, en["k"])
            if len(pts) < 2:
                continue
            mlng = mlng_at(pts[0][1])

            # arclength des jonctions → densification ADAPTATIVE : fine
            # (STEP_NODE_M) dans les fenêtres de rampe autour des
            # jonctions, grossière (STEP_M) ailleurs — rampes nettes sans
            # gonfler le JSON.
            cum_raw = [0.0] * len(pts)
            for i in range(1, len(pts)):
                cum_raw[i] = cum_raw[i - 1] + dist_m(
                    (pts[i - 1][0], pts[i - 1][1]),
                    (pts[i][0], pts[i][1]), mlng)
            jdists = sorted(cum_raw[j] for j in junctions)

            def near_junction(d):
                # peu de jonctions par run → scan linéaire suffisant
                return any(abs(d - jd) <= RAMP_M for jd in jdists)

            dense = [pts[0]]
            for ip in range(1, len(pts)):
                p = pts[ip]
                prev = dense[-1]
                d = dist_m((prev[0], prev[1]), (p[0], p[1]), mlng)
                mid = (cum_raw[ip - 1] + cum_raw[ip]) / 2
                step = STEP_NODE_M if near_junction(mid) else STEP_M
                steps = max(1, int(math.ceil(d / step)))
                for s in range(1, steps + 1):
                    t = s / steps
                    dense.append((
                        prev[0] + (p[0] - prev[0]) * t,
                        prev[1] + (p[1] - prev[1]) * t,
                        prev[2] + (p[2] - prev[2]) * t,
                        prev[3] + (p[3] - prev[3]) * t,
                        p[4] if t > 0.5 else prev[4],
                    ))

            # lissage du vecteur sur ±RAMP_M le long du parcours (rampes
            # douces aux changements de slot ; zones constantes inchangées)
            n = len(dense)
            cum = [0.0] * n
            for i in range(1, n):
                cum[i] = cum[i - 1] + dist_m(
                    (dense[i - 1][0], dense[i - 1][1]),
                    (dense[i][0], dense[i][1]), mlng)
            sm = []
            j0 = 0
            for i in range(n):
                while cum[i] - cum[j0] > RAMP_M:
                    j0 += 1
                j1 = i
                while j1 + 1 < n and cum[j1 + 1] - cum[i] <= RAMP_M:
                    j1 += 1
                cnt = j1 - j0 + 1
                sN = sum(dense[j][2] for j in range(j0, j1 + 1)) / cnt
                sE = sum(dense[j][3] for j in range(j0, j1 + 1)) / cnt
                sm.append((dense[i][0], dense[i][1], sN, sE, dense[i][4]))

            # scission au franchissement du seuil dense (k ≤ DENSE_K vs >)
            pieces = []
            cur = [sm[0]]
            for p in sm[1:]:
                if (p[4] > DENSE_K) != (cur[-1][4] > DENSE_K):
                    cur.append(p)        # point partagé → aucun trou
                    pieces.append(cur)
                    cur = [p]
                else:
                    cur.append(p)
            if len(cur) >= 2:
                pieces.append(cur)

            # simplification gloutonne : on supprime les points dont la
            # position ET le vecteur s'interpolent linéairement
            for piece in pieces:
                kept = [piece[0]]
                i = 0
                while i < len(piece) - 1:
                    j = i + 2
                    last_ok = i + 1
                    while j < len(piece):
                        a, b = piece[i], piece[j]
                        seg = dist_m((a[0], a[1]), (b[0], b[1]), mlng)
                        ok = True
                        if seg < 1e-6:
                            ok = False
                        else:
                            for m in range(i + 1, j):
                                p = piece[m]
                                t = dist_m((a[0], a[1]), (p[0], p[1]),
                                           mlng) / seg
                                t = min(1.0, max(0.0, t))
                                ix = a[0] + (b[0] - a[0]) * t
                                iy = a[1] + (b[1] - a[1]) * t
                                if dist_m((ix, iy), (p[0], p[1]),
                                          mlng) > PRUNE_POS_M:
                                    ok = False
                                    break
                                if (abs(a[2] + (b[2] - a[2]) * t - p[2])
                                        > PRUNE_VEC or
                                        abs(a[3] + (b[3] - a[3]) * t - p[3])
                                        > PRUNE_VEC):
                                    ok = False
                                    break
                        if not ok:
                            break
                        last_ok = j
                        j += 1
                    kept.append(piece[last_ok])
                    i = last_ok
                kmax = max(p[4] for p in kept)
                runs.append({
                    "k": kmax,
                    "pts": [[round(p[1], 6), round(p[0], 6),
                             round(p[2], 3), round(p[3], 3)] for p in kept],
                })
        if runs:
            out_lines[label] = {"runs": runs}

    out = {
        "meta": {
            "generated": date.today().isoformat(),
            "nLines": len(out_lines),
            "maxCorridor": max_corridor,
            "denseK": DENSE_K,
        },
        "lines": out_lines,
    }
    json.dump(out, open(sys.argv[2], "w"), separators=(",", ":"))
    npts = sum(len(r["pts"]) for l in out_lines.values() for r in l["runs"])
    nruns = sum(len(l["runs"]) for l in out_lines.values())
    print("OK lines=%d runs=%d pts=%d maxCorridor=%d → %s (%.0f Ko)" % (
        len(out_lines), nruns, npts, max_corridor, sys.argv[2],
        os.path.getsize(sys.argv[2]) / 1024), file=sys.stderr)


if __name__ == "__main__":
    main()
