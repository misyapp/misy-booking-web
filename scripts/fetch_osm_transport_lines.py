#!/usr/bin/env python3
"""
Fetch all bus route data from OpenStreetMap for Antananarivo
and generate GeoJSON files compatible with the Misy transport app.

Usage:
    python3 scripts/fetch_osm_transport_lines.py

Output:
    assets/transport_lines/core/{line}_{aller|retour}.geojson
"""

import json
import os
import sys
import time
import urllib.request
import urllib.parse

OVERPASS_URLS = [
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass-api.de/api/interpreter",
]
OUTPUT_DIR = "assets/transport_lines/core"

# Bounding box for Antananarivo area (south, west, north, east)
BBOX = "-19.1,47.3,-18.7,47.7"


def fetch_overpass(query: str, timeout: int = 180) -> dict:
    """Execute an Overpass API query, trying multiple servers."""
    data = urllib.parse.urlencode({"data": query}).encode("utf-8")

    for server_url in OVERPASS_URLS:
        for attempt in range(2):
            try:
                req = urllib.request.Request(server_url, data=data)
                req.add_header("User-Agent", "MisyTransportFetcher/1.0")
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    return json.loads(resp.read().decode("utf-8"))
            except Exception as e:
                print(f"  {server_url} attempt {attempt+1} failed: {e}")
                if attempt < 1:
                    time.sleep(5)
        print(f"  Switching server...")
    raise RuntimeError("Failed to fetch from all Overpass API servers")


def fetch_all_relation_tags() -> list:
    """Fetch all bus route relation tags (without geometry) in Antananarivo."""
    query = f"""
    [out:json][timeout:60];
    (
      relation["type"="route"]["route"="bus"]({BBOX});
      relation["type"="route"]["route"="share_taxi"]({BBOX});
      relation["type"="route"]["route"="minibus"]({BBOX});
    );
    out tags;
    """
    print("Fetching all bus route relation tags from OSM...")
    result = fetch_overpass(query, timeout=90)
    relations = [el for el in result["elements"] if el["type"] == "relation"]
    print(f"  Found {len(relations)} route relations")
    return relations


def fetch_relation_geometry(relation_id: int) -> dict:
    """Fetch full geometry (ways + nodes) for a single relation."""
    query = f"""
    [out:json][timeout:120];
    relation({relation_id});
    out body;
    >;
    out skel qt;
    """
    return fetch_overpass(query, timeout=150)


def fetch_relations_geometry(relation_ids: list) -> dict:
    """Fetch full geometry for a batch of relations."""
    ids_str = ",".join(str(rid) for rid in relation_ids)
    query = f"""
    [out:json][timeout:180];
    (
      relation(id:{ids_str});
    );
    out body;
    >;
    out skel qt;
    """
    return fetch_overpass(query, timeout=240)


def parse_elements(elements: list) -> tuple:
    """Parse OSM elements into nodes, ways, and relations."""
    nodes = {}
    ways = {}
    relations = []

    for el in elements:
        if el["type"] == "node":
            nodes[el["id"]] = (el["lon"], el["lat"])
        elif el["type"] == "way":
            ways[el["id"]] = el.get("nodes", [])
        elif el["type"] == "relation":
            relations.append(el)

    return nodes, ways, relations


def extract_route_coords(relation: dict, ways: dict, nodes: dict) -> list:
    """Extract ordered coordinates from a route relation's way members."""
    coords = []
    for member in relation.get("members", []):
        if member["type"] == "way" and member.get("role", "") in ("", "forward", "backward"):
            way_id = member["ref"]
            if way_id in ways:
                way_coords = []
                for node_id in ways[way_id]:
                    if node_id in nodes:
                        way_coords.append(list(nodes[node_id]))

                if coords and way_coords:
                    # Check if we need to reverse to connect
                    if coords[-1] == way_coords[0]:
                        coords.extend(way_coords[1:])
                    elif coords[-1] == way_coords[-1]:
                        coords.extend(reversed(way_coords[:-1]))
                    elif coords[0] == way_coords[-1]:
                        coords = way_coords[:-1] + coords
                    elif coords[0] == way_coords[0]:
                        coords = list(reversed(way_coords[1:])) + coords
                    else:
                        coords.extend(way_coords)
                else:
                    coords.extend(way_coords)
    return coords


def extract_stops(relation: dict, nodes: dict) -> list:
    """Extract stop positions from a route relation."""
    stops = []
    seen_positions = set()
    stop_index = 0

    for member in relation.get("members", []):
        if member["type"] == "node" and member.get("role", "").startswith("stop"):
            node_id = member["ref"]
            if node_id in nodes:
                lon, lat = nodes[node_id]
                pos_key = f"{round(lat, 5)}_{round(lon, 5)}"
                if pos_key not in seen_positions:
                    seen_positions.add(pos_key)
                    stop_index += 1
                    stops.append({
                        "type": "Feature",
                        "geometry": {
                            "type": "Point",
                            "coordinates": [lon, lat]
                        },
                        "properties": {
                            "name": f"Arret {stop_index}",
                            "stop_id": node_id,
                            "type": "stop",
                            "osm_matched": True
                        }
                    })

    # Also check platform members (some routes use platform role)
    if not stops:
        for member in relation.get("members", []):
            if member["type"] == "node" and "platform" in member.get("role", ""):
                node_id = member["ref"]
                if node_id in nodes:
                    lon, lat = nodes[node_id]
                    pos_key = f"{round(lat, 5)}_{round(lon, 5)}"
                    if pos_key not in seen_positions:
                        seen_positions.add(pos_key)
                        stop_index += 1
                        stops.append({
                            "type": "Feature",
                            "geometry": {
                                "type": "Point",
                                "coordinates": [lon, lat]
                            },
                            "properties": {
                                "name": f"Arret {stop_index}",
                                "stop_id": node_id,
                                "type": "stop",
                                "osm_matched": True
                            }
                        })

    return stops


def build_geojson(line_number: str, direction: str, coords: list, stops: list) -> dict:
    """Build a GeoJSON FeatureCollection for a route."""
    return {
        "type": "FeatureCollection",
        "properties": {
            "line": line_number,
            "direction": direction,
            "num_stops": len(stops),
            "num_coordinates": len(coords),
            "source": "openstreetmap"
        },
        "features": [
            {
                "type": "Feature",
                "geometry": {
                    "type": "LineString",
                    "coordinates": coords
                },
                "properties": {
                    "type": "route"
                }
            },
            *stops
        ]
    }


def normalize_line_number(tags: dict) -> str:
    """Extract the raw line identifier from OSM relation tags (keeps sub-variants)."""
    # Try ref tag first (most reliable)
    if tags.get("ref"):
        return tags["ref"].strip()

    # Parse from name
    name = tags.get("name", "").strip()
    if not name:
        return ""

    for prefix in ["Ligne_", "Ligne ", "ligne_", "ligne ", "Line_", "Line "]:
        if name.startswith(prefix):
            name = name[len(prefix):]
            break

    # Remove direction suffixes like _A, _R, _Manga_A, _Mena_R
    parts = name.split("_")
    if len(parts) > 1 and parts[-1] in ("A", "R"):
        parts = parts[:-1]
    if len(parts) > 1 and parts[-1] in ("Manga", "Mena", "Maintso", "Fotsy"):
        parts = parts[:-1]

    return "_".join(parts).strip()


def extract_base_line(osm_line_num: str) -> str:
    """Extract the base line number from an OSM line identifier.

    Examples:
        '194-Ambohimangakely' -> '194'
        '133_Cité' -> '133'
        '126_67Ha' -> '126'
        'A-Ambaniala' -> 'A'
        'E-ALASORA-KOFIATRA' -> 'E'
        'H-Ambatolampy' -> 'H'
        'Ambohidratrimo' -> 'Ambohidratrimo'
        '147Bis-Manga' -> '147Bis'
        '135-II' -> '135'
    """
    import re

    # First try: match a leading number pattern (with optional letter suffix)
    m = re.match(r'^(\d+[A-Za-z]?(?:Bis|BIS)?)', osm_line_num)
    if m:
        return m.group(1)

    # For letter lines like A, D, E, G, H, J - take first segment
    parts = re.split(r'[-_]', osm_line_num)
    if parts and len(parts[0]) <= 2 and parts[0].isalpha():
        return parts[0].upper()

    # For named lines like Ambohidratrimo, Mahitsy
    return osm_line_num


def detect_direction(tags: dict) -> str:
    """Detect if this is aller or retour from OSM tags."""
    name = tags.get("name", "").lower()

    # Check explicit direction markers
    if name.endswith("_r") or "_retour" in name or "_mena_r" in name or "_manga_r" in name:
        return "retour"
    if name.endswith("_a") or "_aller" in name or "_mena_a" in name or "_manga_a" in name:
        return "aller"

    # Check from/to tags
    if tags.get("direction") and "retour" in tags.get("direction", "").lower():
        return "retour"

    return "unknown"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Read manifest to know which lines we need
    manifest_path = "assets/transport_lines/manifest.json"
    with open(manifest_path) as f:
        manifest = json.load(f)

    # Find lines that need GeoJSON
    existing_files = set(os.listdir(OUTPUT_DIR))
    needed_lines = set()
    for line in manifest["lines"]:
        ln = line["line_number"]
        for direction in ["aller", "retour"]:
            d = line.get(direction)
            if d:
                filename = f"{ln}_{direction}.geojson"
                if filename not in existing_files:
                    needed_lines.add(ln)

    print(f"Lines needing GeoJSON: {len(needed_lines)}")
    print(f"  {', '.join(sorted(needed_lines))}")

    # Step 1: Fetch all relation tags (lightweight, no geometry)
    all_relations = fetch_all_relation_tags()

    # Group by normalized line number AND by base line number
    line_relations = {}  # exact osm key -> list of (direction, relation_id, tags)
    base_line_relations = {}  # base line -> list of (direction, relation_id, tags)
    for rel in all_relations:
        tags = rel.get("tags", {})
        line_num = normalize_line_number(tags)
        if not line_num:
            continue
        direction = detect_direction(tags)
        entry = (direction, rel["id"], tags)

        if line_num not in line_relations:
            line_relations[line_num] = []
        line_relations[line_num].append(entry)

        # Also index by base line number for fuzzy matching
        base = extract_base_line(line_num)
        if base not in base_line_relations:
            base_line_relations[base] = []
        base_line_relations[base].append(entry)

    print(f"\nFound {len(line_relations)} unique OSM line keys, {len(base_line_relations)} base lines")
    for base in sorted(base_line_relations.keys()):
        variants = [k for k in line_relations.keys() if extract_base_line(k) == base]
        count = len(base_line_relations[base])
        print(f"  {base}: {count} relation(s) [{', '.join(variants)}]")

    # Step 2: Identify which relations we need geometry for
    needed_relation_ids_set = set()
    # list of (relation_id, manifest_line_number, role)
    needed_assignments = []

    def find_routes_for_line(ln):
        """Find OSM routes matching a manifest line number."""
        routes = None

        # Try exact match first
        if ln in line_relations:
            return line_relations[ln]

        # Try with leading zeros removed
        ln_stripped = ln.lstrip("0") or "0"
        if ln_stripped in line_relations:
            return line_relations[ln_stripped]

        # Try base line matching (e.g., "194" matches "194-Ambohimangakely")
        search_keys = [ln, ln.lstrip("0") or "0", ln.upper(), ln.capitalize()]
        for key in search_keys:
            if key in base_line_relations:
                print(f"  {ln}: matched via base line '{key}'")
                return base_line_relations[key]

        # Special cases: case insensitive
        ln_lower = ln.lower()
        for base_key in base_line_relations:
            if base_key.lower() == ln_lower:
                print(f"  {ln}: matched case-insensitive '{base_key}'")
                return base_line_relations[base_key]

        # Sub-variant matching: "133A" -> check for "133" sub-variants
        import re
        m = re.match(r'^(\d+)([A-Z]+)$', ln)
        if m:
            base_num = m.group(1)
            if base_num in base_line_relations:
                print(f"  {ln}: using base line '{base_num}' variants")
                return base_line_relations[base_num]

        # 147BIS -> 147Bis
        if "BIS" in ln.upper():
            bis_key = ln.replace("BIS", "Bis").replace("bis", "Bis")
            for bk in [bis_key, bis_key.upper()]:
                if bk in base_line_relations:
                    print(f"  {ln}: matched '{bk}'")
                    return base_line_relations[bk]

        return None

    # Track which variant index each sub-line should use from a shared pool
    base_usage_count = {}  # base_line -> count of manifest lines using it

    for ln in sorted(needed_lines):
        routes = find_routes_for_line(ln)

        if not routes:
            print(f"  {ln}: NOT FOUND in OSM data")
            continue

        # Determine which pair from the pool to use
        # Group routes into pairs (aller/retour)
        aller_candidates = [r for r in routes if r[0] == "aller"]
        retour_candidates = [r for r in routes if r[0] == "retour"]
        unknown_candidates = [r for r in routes if r[0] == "unknown"]

        # Build available pairs
        pairs = []
        used_rids = set()
        for ac in aller_candidates:
            for rc in retour_candidates:
                if ac[1] != rc[1]:
                    pairs.append((ac, rc))
        if not pairs:
            # Pair up unknowns
            for i in range(0, len(unknown_candidates) - 1, 2):
                pairs.append((unknown_candidates[i], unknown_candidates[i + 1]))
            if not pairs and unknown_candidates:
                pairs.append((unknown_candidates[0], None))
            if not pairs and aller_candidates:
                pairs.append((aller_candidates[0], None))
            if not pairs and retour_candidates:
                pairs.append((None, retour_candidates[0]))

        if not pairs and routes:
            # Fallback: just use first route
            pairs.append((routes[0], None))

        # Get a unique base key for rotation
        import re
        m = re.match(r'^(\d+)', ln)
        base_key = m.group(1) if m else ln.upper()
        pair_idx = base_usage_count.get(base_key, 0)
        base_usage_count[base_key] = pair_idx + 1

        pair = pairs[pair_idx % len(pairs)] if pairs else (None, None)

        if pair[0]:
            rid = pair[0][1]
            needed_relation_ids_set.add(rid)
            needed_assignments.append((rid, ln, "aller" if pair[1] else "single"))

        if pair[1]:
            rid = pair[1][1]
            needed_relation_ids_set.add(rid)
            needed_assignments.append((rid, ln, "retour"))

    needed_relation_ids = list(needed_relation_ids_set)

    print(f"\nNeed to fetch geometry for {len(needed_relation_ids)} relations")

    # Step 3: Fetch geometry in batches of 5
    BATCH_SIZE = 5
    all_nodes = {}
    all_ways = {}
    all_full_relations = []

    for i in range(0, len(needed_relation_ids), BATCH_SIZE):
        batch = needed_relation_ids[i:i + BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        total_batches = (len(needed_relation_ids) + BATCH_SIZE - 1) // BATCH_SIZE
        print(f"\nFetching batch {batch_num}/{total_batches} ({len(batch)} relations)...")

        try:
            result = fetch_relations_geometry(batch)
            nodes, ways, relations = parse_elements(result["elements"])
            all_nodes.update(nodes)
            all_ways.update(ways)
            all_full_relations.extend(relations)
            print(f"  Got {len(nodes)} nodes, {len(ways)} ways, {len(relations)} relations")
        except Exception as e:
            print(f"  Batch failed: {e}")
            # Try one by one
            for rid in batch:
                try:
                    print(f"  Retrying relation {rid} individually...")
                    result = fetch_relation_geometry(rid)
                    nodes, ways, relations = parse_elements(result["elements"])
                    all_nodes.update(nodes)
                    all_ways.update(ways)
                    all_full_relations.extend(relations)
                    print(f"    Got {len(nodes)} nodes, {len(ways)} ways")
                except Exception as e2:
                    print(f"    Failed: {e2}")

        # Respect Overpass rate limits
        if i + BATCH_SIZE < len(needed_relation_ids):
            time.sleep(3)

    print(f"\nTotal: {len(all_nodes)} nodes, {len(all_ways)} ways, {len(all_full_relations)} relations")

    # Build index of fetched relations by ID
    rel_by_id = {rel["id"]: rel for rel in all_full_relations}

    # Step 4: Generate GeoJSON files
    generated = 0
    for rid, ln, role in needed_assignments:
        if rid not in rel_by_id:
            print(f"  {ln} (relation {rid}): geometry not fetched")
            continue

        rel = rel_by_id[rid]
        coords = extract_route_coords(rel, all_ways, all_nodes)
        stops = extract_stops(rel, all_nodes)

        if not coords:
            print(f"  {ln} (relation {rid}): no coordinates extracted")
            continue

        if role == "single":
            # Save as aller
            geojson = build_geojson(ln, rel.get("tags", {}).get("name", ""), coords, stops)
            filepath = os.path.join(OUTPUT_DIR, f"{ln}_aller.geojson")
            if not os.path.exists(filepath):
                with open(filepath, "w") as f:
                    json.dump(geojson, f, indent=2)
                generated += 1
                print(f"  {ln}_aller: {len(coords)} coords, {len(stops)} stops")

            # Generate retour by reversing
            retour_coords = list(reversed(coords))
            retour_stops = list(reversed(stops))
            geojson_r = build_geojson(ln, "retour", retour_coords, retour_stops)
            filepath_r = os.path.join(OUTPUT_DIR, f"{ln}_retour.geojson")
            if not os.path.exists(filepath_r):
                with open(filepath_r, "w") as f:
                    json.dump(geojson_r, f, indent=2)
                generated += 1
                print(f"  {ln}_retour: {len(retour_coords)} coords, {len(retour_stops)} stops (reversed)")
        else:
            # aller or retour
            direction = role
            geojson = build_geojson(ln, rel.get("tags", {}).get("name", ""), coords, stops)
            filepath = os.path.join(OUTPUT_DIR, f"{ln}_{direction}.geojson")
            if not os.path.exists(filepath):
                with open(filepath, "w") as f:
                    json.dump(geojson, f, indent=2)
                generated += 1
                print(f"  {ln}_{direction}: {len(coords)} coords, {len(stops)} stops")

    print(f"\nGenerated {generated} GeoJSON files")

    # Step 5: For lines with only aller, generate retour by reversing
    for line in manifest["lines"]:
        ln = line["line_number"]
        aller_path = os.path.join(OUTPUT_DIR, f"{ln}_aller.geojson")
        retour_path = os.path.join(OUTPUT_DIR, f"{ln}_retour.geojson")
        if os.path.exists(aller_path) and not os.path.exists(retour_path) and line.get("retour"):
            with open(aller_path) as f:
                aller_gj = json.load(f)
            route_feature = aller_gj["features"][0]
            retour_coords = list(reversed(route_feature["geometry"]["coordinates"]))
            stop_features = [ft for ft in aller_gj["features"] if ft.get("properties", {}).get("type") == "stop"]
            retour_stops = list(reversed(stop_features))
            retour_gj = build_geojson(ln, "retour", retour_coords, retour_stops)
            with open(retour_path, "w") as f:
                json.dump(retour_gj, f, indent=2)
            generated += 1
            print(f"  {ln}_retour: generated by reversing aller ({len(retour_coords)} coords)")

    # Step 6: Update manifest to mark lines as bundled
    updated = 0
    for line in manifest["lines"]:
        ln = line["line_number"]
        changed = False
        for direction in ["aller", "retour"]:
            d = line.get(direction)
            if d:
                filepath = os.path.join(OUTPUT_DIR, f"{ln}_{direction}.geojson")
                if os.path.exists(filepath):
                    asset_path = f"assets/transport_lines/core/{ln}_{direction}.geojson"
                    if d.get("asset_path") != asset_path:
                        d["asset_path"] = asset_path
                        changed = True
                    # Update num_stops from actual file
                    with open(filepath) as f:
                        gj = json.load(f)
                    actual_stops = len([ft for ft in gj.get("features", []) if ft.get("properties", {}).get("type") == "stop"])
                    actual_coords = len(gj.get("features", [{}])[0].get("geometry", {}).get("coordinates", []))
                    if actual_stops > 0:
                        d["num_stops"] = actual_stops

        if changed:
            line["is_bundled"] = True
            updated += 1

    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"\nUpdated {updated} lines in manifest (now bundled)")

    # Report remaining missing
    still_missing = []
    for line in manifest["lines"]:
        ln = line["line_number"]
        for direction in ["aller", "retour"]:
            d = line.get(direction)
            if d:
                filepath = os.path.join(OUTPUT_DIR, f"{ln}_{direction}.geojson")
                if not os.path.exists(filepath):
                    still_missing.append(f"{ln}_{direction}")

    if still_missing:
        print(f"\nStill missing {len(still_missing)} GeoJSON files:")
        for m in still_missing:
            print(f"  {m}")
    else:
        print("\nAll lines have GeoJSON files!")


if __name__ == "__main__":
    main()
