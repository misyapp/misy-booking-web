#!/usr/bin/env python3
"""
Fetch all OpenStreetMap bus stops within 40 km of Antananarivo and generate
assets/osm_bus_stops_tana.json for the Misy transport editor.

Usage:
    python3 scripts/fetch_osm_bus_stops.py

Output:
    assets/osm_bus_stops_tana.json  (list of {id, name, lat, lng, tags})

Déduplication : stops dont le nom (normalisé) + position (≤ 30 m) coïncident
sont fusionnés. Les stops sans nom sont gardés mais avec name = "" (l'app
peut les afficher comme "Arrêt non nommé").
"""

import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request

OVERPASS_URLS = [
    "https://overpass.kumi.systems/api/interpreter",
    "https://z.overpass-api.de/api/interpreter",
    "https://overpass-api.de/api/interpreter",
]

OUTPUT_PATH = "assets/osm_bus_stops_tana.json"

CENTER_LAT = -18.8792
CENTER_LNG = 47.5079
RADIUS_METERS = 40000

OVERPASS_QUERY = f"""
[out:json][timeout:120];
(
  node["highway"="bus_stop"](around:{RADIUS_METERS},{CENTER_LAT},{CENTER_LNG});
  node["public_transport"="platform"](around:{RADIUS_METERS},{CENTER_LAT},{CENTER_LNG});
  node["public_transport"="stop_position"](around:{RADIUS_METERS},{CENTER_LAT},{CENTER_LNG});
);
out;
""".strip()


def fetch_overpass(query: str, timeout: int = 180) -> dict:
    data = urllib.parse.urlencode({"data": query}).encode("utf-8")
    for server_url in OVERPASS_URLS:
        for attempt in range(2):
            try:
                req = urllib.request.Request(server_url, data=data)
                req.add_header("User-Agent", "MisyBusStopsFetcher/1.0")
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    return json.loads(resp.read().decode("utf-8"))
            except Exception as e:
                print(f"  {server_url} attempt {attempt+1} failed: {e}")
                if attempt < 1:
                    time.sleep(5)
        print(f"  Switching server...")
    raise RuntimeError("Failed to fetch from all Overpass API servers")


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371000.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def normalize_name(name: str) -> str:
    return " ".join(name.lower().split())


def pick_name(tags: dict) -> str:
    for key in ("name", "name:fr", "name:mg", "ref", "loc_name", "old_name"):
        v = tags.get(key)
        if v:
            return v.strip()
    return ""


def main():
    print(f"Overpass query : bus stops around ({CENTER_LAT}, {CENTER_LNG})"
          f" r={RADIUS_METERS // 1000} km ...")
    result = fetch_overpass(OVERPASS_QUERY)
    elements = result.get("elements", [])
    print(f"  → {len(elements)} éléments bruts reçus")

    raw_stops = []
    for el in elements:
        if el.get("type") != "node":
            continue
        lat = el.get("lat")
        lng = el.get("lon")
        if lat is None or lng is None:
            continue
        tags = el.get("tags") or {}
        raw_stops.append(
            {
                "id": f"node/{el['id']}",
                "name": pick_name(tags),
                "lat": round(lat, 6),
                "lng": round(lng, 6),
                "tags": {
                    k: v
                    for k, v in tags.items()
                    if k
                    in (
                        "highway",
                        "public_transport",
                        "network",
                        "operator",
                        "shelter",
                        "bench",
                        "name",
                        "name:fr",
                        "name:mg",
                        "ref",
                    )
                },
            }
        )

    print(f"  → {len(raw_stops)} nodes géolocalisés")

    # Étape 1 : les stops SANS nom proches (≤ 40 m) d'un stop nommé héritent
    # du nom du stop nommé le plus proche. Ça couvre le cas « OSM a un node
    # platform sans name à côté d'un stop_position nommé ».
    inherited = 0
    for s in raw_stops:
        if s["name"]:
            continue
        closest = None
        closest_d = 40.0
        for t in raw_stops:
            if not t["name"]:
                continue
            d = haversine_m(s["lat"], s["lng"], t["lat"], t["lng"])
            if d < closest_d:
                closest_d = d
                closest = t
        if closest is not None:
            s["name"] = closest["name"]
            s["tags"] = dict(s.get("tags") or {}, inherited_name="true")
            inherited += 1
    print(f"  → {inherited} stops non nommés ont hérité d'un nom proche (≤ 40 m)")

    # Étape 2 : clustering union-find des stops nommés à ≤ 25 m, puis
    # renommage de chaque cluster avec un nom commun.
    # - Si tous les noms du cluster sont déjà identiques → pas touché
    # - Sinon, on prend les noms "minimaux" (ceux qui ne sont contenus dans
    #   aucun autre nom du cluster) et on les concatène en ordre alphabétique
    #
    # Ça regroupe « Andohanimandroseza » + « Clinique » → « Andohanimandroseza
    # Clinique » sur les 2 arrêts de chaque côté de la route.
    parent = list(range(len(raw_stops)))

    def _find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def _union(a, b):
        ra, rb = _find(a), _find(b)
        if ra != rb:
            parent[ra] = rb

    for i in range(len(raw_stops)):
        if not raw_stops[i]["name"]:
            continue
        for j in range(i + 1, len(raw_stops)):
            if not raw_stops[j]["name"]:
                continue
            d = haversine_m(
                raw_stops[i]["lat"], raw_stops[i]["lng"],
                raw_stops[j]["lat"], raw_stops[j]["lng"],
            )
            if d <= 25:
                _union(i, j)

    clusters = {}
    for i in range(len(raw_stops)):
        if not raw_stops[i]["name"]:
            continue
        clusters.setdefault(_find(i), []).append(i)

    def _strip(s):
        # Normalisation forte : lowercase, retire tout ce qui n'est pas
        # alphanumérique. Sert pour détecter les sous-chaînes même quand
        # la casse/ponctuation/espaces diffèrent (ex: "Andranomena_159"
        # ⊂ "Terminus Andranomena 159", ou "67 Ha" == "67Ha").
        return "".join(c for c in s.lower() if c.isalnum())

    composed = 0
    for idxs in clusters.values():
        if len(idxs) < 2:
            continue
        # Dédup par nom normalisé (garde la forme la plus longue en cas
        # d'égalité, ex: "67 Ha Nord Lavage" vs "67Ha Nord Lavage")
        by_norm = {}
        for k in idxs:
            n = raw_stops[k]["name"]
            key = _strip(n)
            if not key:
                continue
            if key not in by_norm or len(n) > len(by_norm[key]):
                by_norm[key] = n
        if len(by_norm) <= 1:
            # Les noms sont tous équivalents une fois normalisés : on
            # harmonise sur la forme la plus longue.
            if len(by_norm) == 1:
                canonical = next(iter(by_norm.values()))
                for k in idxs:
                    if raw_stops[k]["name"] != canonical:
                        raw_stops[k]["name"] = canonical
                        composed += 1
            continue
        # Filtre substring sur la forme normalisée
        ordered = sorted(by_norm.items(), key=lambda kv: len(kv[0]), reverse=True)
        minimal = []  # List[(norm, original)]
        for norm, orig in ordered:
            if any(norm in m_norm for m_norm, _ in minimal):
                continue
            # Retire éventuellement les existants qui deviennent subsumés
            minimal = [(mn, mo) for mn, mo in minimal if mn not in norm] + [(norm, orig)]
        common = " ".join(orig for _, orig in sorted(minimal, key=lambda x: x[1].lower()))
        for k in idxs:
            if raw_stops[k]["name"] != common:
                raw_stops[k]["name"] = common
                composed += 1
    print(f"  → {composed} stops ont reçu un nom composé (clusters proches)")

    # Étape 2b : nettoyage final des noms — collapse les mots dupliqués
    # consécutifs (ex: "Sampanana Sampanana Andoh…" → "Sampanana Andoh…"),
    # et dédup les mots identiques (case-insensitive) dans le même nom.
    cleaned = 0
    for s in raw_stops:
        name = s.get("name") or ""
        if not name:
            continue
        words = name.split()
        seen = set()
        out = []
        for w in words:
            wn = "".join(c for c in w.lower() if c.isalnum())
            if not wn:
                out.append(w)
                continue
            if wn in seen:
                continue
            seen.add(wn)
            out.append(w)
        new_name = " ".join(out).strip()
        if new_name != name:
            s["name"] = new_name
            cleaned += 1
    print(f"  → {cleaned} noms nettoyés (mots dupliqués retirés)")

    # Étape 3 : déduplication agressive — même nom + ≤ 10 m = vrai doublon
    # (même node OSM tagué à la fois bus_stop et platform, typiquement).
    # Au-delà, on GARDE les 2 stops : paire aller/retour de chaque côté de
    # la route.
    dedup = []
    skipped = 0
    for stop in raw_stops:
        matched = None
        if stop["name"]:
            norm = normalize_name(stop["name"])
            for kept in dedup:
                if not kept["name"]:
                    continue
                if normalize_name(kept["name"]) != norm:
                    continue
                d = haversine_m(stop["lat"], stop["lng"], kept["lat"], kept["lng"])
                if d <= 10:
                    matched = kept
                    break
        if matched is None:
            dedup.append(stop)
        else:
            skipped += 1
    print(f"  → {len(dedup)} après dédup stricte ({skipped} vrais doublons fusionnés)")

    dedup.sort(key=lambda s: (s["name"] == "", s["name"].lower(), s["lat"], s["lng"]))

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(
            {
                "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "center": {"lat": CENTER_LAT, "lng": CENTER_LNG},
                "radius_m": RADIUS_METERS,
                "count": len(dedup),
                "stops": dedup,
            },
            f,
            ensure_ascii=False,
            indent=2,
        )

    size_kb = os.path.getsize(OUTPUT_PATH) / 1024
    named = sum(1 for s in dedup if s["name"])
    print(f"✅ {OUTPUT_PATH}  ({size_kb:.1f} KB, {named}/{len(dedup)} nommés)")


if __name__ == "__main__":
    sys.exit(main() or 0)
