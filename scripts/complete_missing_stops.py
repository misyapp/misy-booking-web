#!/usr/bin/env python3
"""
Complete missing bus stops for transport lines using OpenStreetMap data
and rebuild routes via OSRM segment-by-segment through each stop.

Method:
1. Fetch ALL bus stops from OSM in Antananarivo area (single bulk query)
2. For each line missing stops:
   a. Load existing route, identify Primus (start) and Terminus (end)
   b. Filter OSM stops within 100m corridor, RIGHT side of road only
   c. Order stops along route
   d. Re-route via OSRM: Primus → Stop1 → Stop2 → ... → Terminus
   e. For retour: Terminus → StopN → ... → Stop1 → Primus
3. Update GeoJSON files and manifest

Usage:
    python3 scripts/complete_missing_stops.py          # Process missing lines
    python3 scripts/complete_missing_stops.py --audit   # Audit all 95 lines
    python3 scripts/complete_missing_stops.py --line 009 # Process single line
"""

import json
import math
import os
import sys
import time
import urllib.request
import urllib.parse

# ── Configuration ──────────────────────────────────────────────────────────

OVERPASS_URLS = [
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass-api.de/api/interpreter",
]
OSRM_URL = "https://osrm2.misy.app"
GEOJSON_DIR = "assets/transport_lines/core"
MANIFEST_PATH = "assets/transport_lines/manifest.json"

# Bounding box for Antananarivo area
BBOX = "-19.1,47.3,-18.7,47.7"

# Geometry constants at latitude ~-18.9
LON_SCALE = 105600   # meters per degree longitude
LAT_SCALE = 111000   # meters per degree latitude
BUFFER_M = 100       # search corridor width (meters)
MIN_SPACING_M = 30   # minimum spacing between stops (meters)
CENTERLINE_TOL_M = 5 # centerline tolerance (meters)
OSRM_DELAY = 0.3     # delay between OSRM requests (seconds)


# ── Network helpers ────────────────────────────────────────────────────────

def fetch_overpass(query: str, timeout: int = 180) -> dict:
    """Execute an Overpass API query, trying multiple servers."""
    data = urllib.parse.urlencode({"data": query}).encode("utf-8")

    for server_url in OVERPASS_URLS:
        for attempt in range(2):
            try:
                req = urllib.request.Request(server_url, data=data)
                req.add_header("User-Agent", "MisyTransportFetcher/2.0")
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    return json.loads(resp.read().decode("utf-8"))
            except Exception as e:
                print(f"  {server_url} attempt {attempt+1} failed: {e}")
                if attempt < 1:
                    time.sleep(5)
        print(f"  Switching server...")
    raise RuntimeError("Failed to fetch from all Overpass API servers")


def osrm_route(from_lon, from_lat, to_lon, to_lat, retries=3):
    """Get a road route between two points via OSRM.
    Returns list of [lon, lat] coordinates or None."""
    url = (
        f"{OSRM_URL}/route/v1/driving/"
        f"{from_lon},{from_lat};{to_lon},{to_lat}"
        f"?overview=full&geometries=geojson"
    )

    for attempt in range(retries):
        try:
            req = urllib.request.Request(url)
            req.add_header("User-Agent", "MisyTransportStops/1.0")
            with urllib.request.urlopen(req, timeout=15) as resp:
                result = json.loads(resp.read().decode("utf-8"))

            if result.get("code") == "Ok" and result.get("routes"):
                return result["routes"][0]["geometry"]["coordinates"]
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(2)
            else:
                print(f"    OSRM error: {e}")
    return None


# ── Geometry helpers ───────────────────────────────────────────────────────

def meters_between(lon1, lat1, lon2, lat2):
    """Approximate distance in meters between two points."""
    dx = (lon2 - lon1) * LON_SCALE
    dy = (lat2 - lat1) * LAT_SCALE
    return math.sqrt(dx * dx + dy * dy)


def point_to_segment(px, py, ax, ay, bx, by):
    """Distance from point P to segment AB.
    Returns (distance_meters, t_parameter, proj_lon, proj_lat)."""
    dx = (bx - ax) * LON_SCALE
    dy = (by - ay) * LAT_SCALE
    len_sq = dx * dx + dy * dy

    if len_sq == 0:
        dist = meters_between(px, py, ax, ay)
        return dist, 0.0, ax, ay

    t = ((px - ax) * LON_SCALE * dx + (py - ay) * LAT_SCALE * dy) / len_sq
    t = max(0.0, min(1.0, t))

    proj_lon = ax + t * (bx - ax)
    proj_lat = ay + t * (by - ay)
    dist = meters_between(px, py, proj_lon, proj_lat)
    return dist, t, proj_lon, proj_lat


def find_nearest_segment(stop_lon, stop_lat, route_coords):
    """Find the nearest route segment to a stop.
    Returns (distance_m, segment_index, t, proj_lon, proj_lat)."""
    best_dist = float('inf')
    best_seg = 0
    best_t = 0.0
    best_proj_lon = route_coords[0][0]
    best_proj_lat = route_coords[0][1]

    for i in range(len(route_coords) - 1):
        ax, ay = route_coords[i]
        bx, by = route_coords[i + 1]
        dist, t, plon, plat = point_to_segment(stop_lon, stop_lat, ax, ay, bx, by)

        if dist < best_dist:
            best_dist = dist
            best_seg = i
            best_t = t
            best_proj_lon = plon
            best_proj_lat = plat

    return best_dist, best_seg, best_t, best_proj_lon, best_proj_lat


def is_right_side(stop_lon, stop_lat, seg_start, seg_end):
    """Check if a point is on the right side of a directed segment.
    Uses cross product: cross < 0 means right side.
    Returns (is_right, cross_distance_meters)."""
    ax, ay = seg_start
    bx, by = seg_end
    px, py = stop_lon, stop_lat

    # Direction vector (scaled to meters)
    dx = (bx - ax) * LON_SCALE
    dy = (by - ay) * LAT_SCALE

    # Vector from A to P (scaled to meters)
    vx = (px - ax) * LON_SCALE
    vy = (py - ay) * LAT_SCALE

    # Cross product
    cross = dx * vy - dy * vx

    # cross < 0 → right side, cross > 0 → left side
    # Normalize by segment length to get perpendicular distance
    seg_len = math.sqrt(dx * dx + dy * dy)
    if seg_len > 0:
        cross_dist = abs(cross) / seg_len
    else:
        cross_dist = 0

    return cross < 0, cross_dist


# ── OSM data fetching ──────────────────────────────────────────────────────

def fetch_all_bus_stops():
    """Fetch all bus stops in Antananarivo area from OSM."""
    query = f"""
    [out:json][timeout:120];
    (
      node["highway"="bus_stop"]({BBOX});
      node["public_transport"="stop_position"]({BBOX});
      node["public_transport"="platform"]({BBOX});
    );
    out body;
    """
    print("Fetching all bus stops from OSM...")
    result = fetch_overpass(query, timeout=150)

    stops = []
    seen_ids = set()
    for el in result.get("elements", []):
        if el["type"] == "node" and el["id"] not in seen_ids:
            seen_ids.add(el["id"])
            tags = el.get("tags", {})
            stops.append({
                "id": el["id"],
                "lon": el["lon"],
                "lat": el["lat"],
                "name": tags.get("name", ""),
            })

    print(f"  Found {len(stops)} bus stops in Antananarivo area")
    return stops


# ── Core logic ─────────────────────────────────────────────────────────────

def filter_stops_for_route(all_stops, route_coords):
    """Filter OSM stops within corridor and on the right side of the route.
    Returns list of dicts with stop info + projection data."""
    candidates = []

    for stop in all_stops:
        dist, seg_idx, t, proj_lon, proj_lat = find_nearest_segment(
            stop["lon"], stop["lat"], route_coords
        )

        if dist > BUFFER_M:
            continue

        right, cross_dist = is_right_side(
            stop["lon"], stop["lat"],
            route_coords[seg_idx],
            route_coords[min(seg_idx + 1, len(route_coords) - 1)]
        )

        # Keep if right side OR very close to centerline
        if right or cross_dist < CENTERLINE_TOL_M:
            candidates.append({
                "id": stop["id"],
                "lon": stop["lon"],
                "lat": stop["lat"],
                "name": stop["name"],
                "snap_distance": round(dist, 1),
                "seg_idx": seg_idx,
                "t": t,
                "proj_lon": proj_lon,
                "proj_lat": proj_lat,
            })

    return candidates


def order_and_deduplicate(candidates):
    """Order candidates along route and remove duplicates within MIN_SPACING_M."""
    # Sort by position along route
    candidates.sort(key=lambda c: (c["seg_idx"], c["t"]))

    # Deduplicate
    result = []
    for c in candidates:
        if result:
            prev = result[-1]
            dist = meters_between(prev["lon"], prev["lat"], c["lon"], c["lat"])
            if dist < MIN_SPACING_M:
                # Keep the one with a name, or the closer one
                if c["name"] and not prev["name"]:
                    result[-1] = c
                continue
        result.append(c)

    return result


def generate_synthetic_stops(route_coords, target_count):
    """Generate evenly spaced stops along a route as fallback."""
    if target_count <= 0:
        return []

    # Calculate cumulative distances along route
    cum_dist = [0.0]
    for i in range(1, len(route_coords)):
        d = meters_between(
            route_coords[i-1][0], route_coords[i-1][1],
            route_coords[i][0], route_coords[i][1]
        )
        cum_dist.append(cum_dist[-1] + d)

    total_dist = cum_dist[-1]
    if total_dist == 0:
        return []

    # Space stops evenly (including start/end as primus/terminus, not stops)
    spacing = total_dist / (target_count + 1)
    stops = []

    for i in range(1, target_count + 1):
        target_d = spacing * i

        # Find the segment containing this distance
        for j in range(1, len(cum_dist)):
            if cum_dist[j] >= target_d:
                seg_frac = (target_d - cum_dist[j-1]) / (cum_dist[j] - cum_dist[j-1]) if cum_dist[j] > cum_dist[j-1] else 0
                lon = route_coords[j-1][0] + seg_frac * (route_coords[j][0] - route_coords[j-1][0])
                lat = route_coords[j-1][1] + seg_frac * (route_coords[j][1] - route_coords[j-1][1])
                stops.append({
                    "id": 0,
                    "lon": round(lon, 7),
                    "lat": round(lat, 7),
                    "name": "",
                    "snap_distance": 0.0,
                    "seg_idx": j - 1,
                    "t": seg_frac,
                    "synthetic": True,
                })
                break

    return stops


def build_route_through_stops(primus, stops, terminus):
    """Build a complete route by OSRM routing between consecutive points.
    primus/terminus: [lon, lat], stops: list of dicts with lon/lat.
    Returns list of [lon, lat] coordinates."""
    waypoints = [primus] + [[s["lon"], s["lat"]] for s in stops] + [terminus]
    all_coords = []

    for i in range(len(waypoints) - 1):
        from_pt = waypoints[i]
        to_pt = waypoints[i + 1]

        segment = osrm_route(from_pt[0], from_pt[1], to_pt[0], to_pt[1])
        time.sleep(OSRM_DELAY)

        if segment:
            if all_coords:
                # Skip first point to avoid duplicates at junctions
                all_coords.extend(segment[1:])
            else:
                all_coords.extend(segment)
        else:
            # Fallback: straight line
            print(f"      OSRM failed for segment {i}, using straight line")
            if all_coords:
                all_coords.append(to_pt)
            else:
                all_coords.extend([from_pt, to_pt])

    return all_coords


def build_stop_features(stops, start_index=1):
    """Convert stop dicts to GeoJSON Point features."""
    features = []
    for i, stop in enumerate(stops):
        name = stop["name"] if stop["name"] else f"Arret {start_index + i}"
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [stop["lon"], stop["lat"]]
            },
            "properties": {
                "name": name,
                "stop_id": stop["id"],
                "type": "stop",
                "osm_matched": not stop.get("synthetic", False),
                "snap_distance": stop.get("snap_distance", 0.0),
            }
        })
    return features


# ── File processing ────────────────────────────────────────────────────────

def identify_files_needing_stops():
    """Read manifest and identify lines/directions that need stops."""
    with open(MANIFEST_PATH) as f:
        manifest = json.load(f)

    needed = []

    for line in manifest["lines"]:
        ln = line["line_number"]

        for direction in ["aller", "retour"]:
            d = line.get(direction)
            if not d:
                continue

            filepath = d.get("asset_path", f"{GEOJSON_DIR}/{ln}_{direction}.geojson")
            if not os.path.exists(filepath):
                continue

            # Check if file already has stops
            with open(filepath) as f:
                gj = json.load(f)

            has_stops = any(
                feat.get("geometry", {}).get("type") == "Point" and
                feat.get("properties", {}).get("type") == "stop"
                for feat in gj.get("features", [])
            )

            if not has_stops:
                declared_stops = d.get("num_stops", 0)
                needed.append({
                    "line_number": ln,
                    "direction": direction,
                    "direction_name": d.get("direction", ""),
                    "filepath": filepath,
                    "declared_stops": declared_stops,
                    "geojson": gj,
                })

    return needed, manifest


def process_line_direction(entry, all_osm_stops, paired_stops=None):
    """Process a single line+direction: find stops, rebuild route.

    Args:
        entry: dict from identify_files_needing_stops
        all_osm_stops: list of all OSM stops
        paired_stops: if provided (for retour), use these stops reversed
                      instead of searching OSM again

    Returns:
        (stops_found, stop_features) or None on failure
    """
    ln = entry["line_number"]
    direction = entry["direction"]
    filepath = entry["filepath"]
    gj = entry["geojson"]

    # Extract existing route coordinates
    route_coords = None
    for feat in gj.get("features", []):
        if feat.get("geometry", {}).get("type") == "LineString":
            route_coords = feat["geometry"]["coordinates"]
            break

    if not route_coords or len(route_coords) < 2:
        print(f"    No route found in {filepath}, skipping")
        return None

    primus = route_coords[0]
    terminus = route_coords[-1]

    if paired_stops is not None:
        # For retour: use aller stops in reverse order
        stops = list(reversed(paired_stops))
        print(f"    Using {len(stops)} stops from aller (reversed)")
    else:
        # Filter OSM stops along route, right side
        candidates = filter_stops_for_route(all_osm_stops, route_coords)
        stops = order_and_deduplicate(candidates)
        print(f"    Found {len(stops)} OSM stops (right side, ordered)")

        # Fallback if no OSM stops
        if len(stops) == 0:
            target = entry["declared_stops"]
            if target > 0:
                print(f"    No OSM stops found, generating {target} synthetic stops")
                stops = generate_synthetic_stops(route_coords, target)
            else:
                print(f"    No stops found and no target count, skipping")
                return None

    # Build route through stops via OSRM
    print(f"    Routing via OSRM: Primus → {len(stops)} stops → Terminus...")
    new_coords = build_route_through_stops(primus, stops, terminus)

    if not new_coords or len(new_coords) < 2:
        print(f"    OSRM routing failed, keeping original route")
        new_coords = route_coords

    # Build stop features
    stop_features = build_stop_features(stops)

    # Build updated GeoJSON
    updated_gj = {
        "type": "FeatureCollection",
        "properties": {
            "line": gj.get("properties", {}).get("line", ln),
            "direction": gj.get("properties", {}).get("direction", entry["direction_name"]),
            "num_stops": len(stop_features),
            "num_coordinates": len(new_coords),
            "source": "osm_stops_osrm",
            "road_snapped": True,
        },
        "features": [
            {
                "type": "Feature",
                "geometry": {
                    "type": "LineString",
                    "coordinates": new_coords,
                },
                "properties": {
                    "type": "route",
                }
            },
            *stop_features,
        ]
    }

    # Write
    with open(filepath, "w") as f:
        json.dump(updated_gj, f, indent=2)

    print(f"    ✓ Written {filepath}: {len(stop_features)} stops, {len(new_coords)} coords")
    return stops


def update_manifest(manifest, processed_lines=None):
    """Update manifest.json with actual stop counts from GeoJSON files.
    If processed_lines is given, only update those lines (set of (line_number, direction))."""
    for line in manifest["lines"]:
        ln = line["line_number"]

        for direction in ["aller", "retour"]:
            d = line.get(direction)
            if not d:
                continue

            # Skip lines not in processed set
            if processed_lines and (ln, direction) not in processed_lines:
                continue

            filepath = d.get("asset_path", f"{GEOJSON_DIR}/{ln}_{direction}.geojson")
            if not os.path.exists(filepath):
                continue

            with open(filepath) as f:
                gj = json.load(f)

            actual_stops = sum(
                1 for feat in gj.get("features", [])
                if feat.get("geometry", {}).get("type") == "Point" and
                feat.get("properties", {}).get("type") == "stop"
            )

            d["num_stops"] = actual_stops

    with open(MANIFEST_PATH, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"\n✓ Manifest updated: {MANIFEST_PATH}")


# ── Audit ──────────────────────────────────────────────────────────────────

def audit_all_lines():
    """Audit all 95 lines for consistency."""
    with open(MANIFEST_PATH) as f:
        manifest = json.load(f)

    total_files = 0
    files_with_stops = 0
    files_without_stops = 0
    mismatches = []
    total_stops = 0

    print("\n" + "=" * 60)
    print("AUDIT REPORT - All Transport Lines")
    print("=" * 60)

    for line in manifest["lines"]:
        ln = line["line_number"]

        for direction in ["aller", "retour"]:
            d = line.get(direction)
            if not d:
                continue

            filepath = d.get("asset_path", f"{GEOJSON_DIR}/{ln}_{direction}.geojson")
            total_files += 1

            if not os.path.exists(filepath):
                print(f"  MISSING: {filepath}")
                continue

            with open(filepath) as f:
                gj = json.load(f)

            actual_stops = sum(
                1 for feat in gj.get("features", [])
                if feat.get("geometry", {}).get("type") == "Point" and
                feat.get("properties", {}).get("type") == "stop"
            )

            manifest_stops = d.get("num_stops", 0)
            total_stops += actual_stops

            if actual_stops > 0:
                files_with_stops += 1
            else:
                files_without_stops += 1
                print(f"  NO STOPS: {ln} {direction} (manifest says {manifest_stops})")

            if actual_stops != manifest_stops:
                mismatches.append({
                    "line": ln,
                    "direction": direction,
                    "manifest": manifest_stops,
                    "actual": actual_stops,
                })

    print(f"\n{'─' * 40}")
    print(f"Total files:          {total_files}")
    print(f"Files with stops:     {files_with_stops}")
    print(f"Files without stops:  {files_without_stops}")
    print(f"Total stops:          {total_stops}")
    print(f"Manifest mismatches:  {len(mismatches)}")

    if mismatches:
        print(f"\nMismatches:")
        for m in mismatches:
            print(f"  {m['line']} {m['direction']}: manifest={m['manifest']}, actual={m['actual']}")

    print("=" * 60)
    return files_without_stops == 0


# ── Main ───────────────────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]

    # Audit mode
    if "--audit" in args:
        ok = audit_all_lines()
        sys.exit(0 if ok else 1)

    # Single line mode
    target_line = None
    if "--line" in args:
        idx = args.index("--line")
        if idx + 1 < len(args):
            target_line = args[idx + 1]

    # Phase 1: Fetch all OSM bus stops
    all_osm_stops = fetch_all_bus_stops()

    # Phase 2: Identify files needing stops
    needed, manifest = identify_files_needing_stops()

    if target_line:
        needed = [n for n in needed if n["line_number"] == target_line]

    if not needed:
        print("No files need processing!")
        audit_all_lines()
        return

    print(f"\n{len(needed)} files need stops across {len(set(n['line_number'] for n in needed))} lines")

    # Group by line for aller/retour pairing
    by_line = {}
    for entry in needed:
        ln = entry["line_number"]
        if ln not in by_line:
            by_line[ln] = {}
        by_line[ln][entry["direction"]] = entry

    # Phase 3: Process each line
    processed = 0
    failed = 0
    processed_lines = set()  # Track (line_number, direction) pairs

    for ln, directions in sorted(by_line.items()):
        print(f"\n{'─' * 50}")
        print(f"Line {ln}")

        aller_stops = None

        # Process aller first
        if "aller" in directions:
            print(f"  Processing aller...")
            result = process_line_direction(directions["aller"], all_osm_stops)
            if result is not None:
                aller_stops = result
                processed += 1
                processed_lines.add((ln, "aller"))
            else:
                failed += 1

        # Process retour (using aller stops reversed if available)
        if "retour" in directions:
            print(f"  Processing retour...")
            result = process_line_direction(
                directions["retour"],
                all_osm_stops,
                paired_stops=aller_stops,
            )
            if result is not None:
                processed += 1
                processed_lines.add((ln, "retour"))
            else:
                failed += 1

    # Phase 4: Update manifest (only processed lines)
    print(f"\n{'─' * 50}")
    update_manifest(manifest, processed_lines)

    print(f"\n✓ Done: {processed} files processed, {failed} failures")

    # Phase 5: Audit
    audit_all_lines()


if __name__ == "__main__":
    main()
