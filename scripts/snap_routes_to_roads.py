#!/usr/bin/env python3
"""
Snap transport route GeoJSON coordinates to actual roads using OSRM.

Takes raw OSM coordinates and routes them through OSRM to ensure they follow
real roads instead of cutting through buildings/terrain.

Usage:
    python3 scripts/snap_routes_to_roads.py
"""

import json
import os
import sys
import time
import urllib.request
import urllib.parse

OSRM_URL = "https://osrm2.misy.app"
GEOJSON_DIR = "assets/transport_lines/core"
MAX_WAYPOINTS_PER_REQUEST = 80


def osrm_route(coords: list, retries: int = 3) -> list:
    """Route through OSRM and return snapped coordinates.

    Args:
        coords: list of [lon, lat] pairs
    Returns:
        list of [lon, lat] snapped to roads
    """
    coords_str = ";".join(f"{c[0]},{c[1]}" for c in coords)
    url = f"{OSRM_URL}/route/v1/driving/{coords_str}?overview=full&geometries=geojson"

    for attempt in range(retries):
        try:
            req = urllib.request.Request(url)
            req.add_header("User-Agent", "MisyTransportSnapper/1.0")
            with urllib.request.urlopen(req, timeout=30) as resp:
                result = json.loads(resp.read().decode("utf-8"))

            if result.get("code") == "Ok" and result.get("routes"):
                return result["routes"][0]["geometry"]["coordinates"]
            else:
                print(f"    OSRM returned: {result.get('code', 'unknown')}")
                return None
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(2)
            else:
                print(f"    OSRM error: {e}")
                return None
    return None


def sample_coords(coords: list, max_points: int) -> list:
    """Sample coordinates evenly, always keeping first and last."""
    if len(coords) <= max_points:
        return coords

    # Always keep first and last, sample evenly in between
    step = (len(coords) - 1) / (max_points - 1)
    indices = [int(round(i * step)) for i in range(max_points)]
    # Ensure last index is included
    indices[-1] = len(coords) - 1
    # Remove duplicates while preserving order
    seen = set()
    unique_indices = []
    for idx in indices:
        if idx not in seen:
            seen.add(idx)
            unique_indices.append(idx)

    return [coords[i] for i in unique_indices]


def snap_route_coords(coords: list) -> list:
    """Snap a full route to roads, splitting into chunks if needed."""
    if len(coords) < 3:
        return coords

    # Sample to manageable number of waypoints
    sampled = sample_coords(coords, MAX_WAYPOINTS_PER_REQUEST)

    # If still too many, split into overlapping chunks
    if len(sampled) > MAX_WAYPOINTS_PER_REQUEST:
        chunk_size = MAX_WAYPOINTS_PER_REQUEST - 5  # overlap of 5 points
        all_snapped = []
        for i in range(0, len(sampled), chunk_size):
            chunk = sampled[i:i + MAX_WAYPOINTS_PER_REQUEST]
            if len(chunk) < 2:
                break
            snapped_chunk = osrm_route(chunk)
            if snapped_chunk:
                if all_snapped:
                    # Skip first few points to avoid overlap
                    all_snapped.extend(snapped_chunk[3:])
                else:
                    all_snapped.extend(snapped_chunk)
            else:
                return None
            time.sleep(0.3)
        return all_snapped
    else:
        return osrm_route(sampled)


def process_geojson(filepath: str) -> bool:
    """Process a single GeoJSON file, snapping its route to roads."""
    with open(filepath) as f:
        gj = json.load(f)

    # Find the route feature
    route_feature = None
    for feat in gj.get("features", []):
        if feat.get("properties", {}).get("type") == "route":
            route_feature = feat
            break

    if not route_feature:
        return False

    original_coords = route_feature["geometry"]["coordinates"]
    if len(original_coords) < 3:
        return False

    # Snap to roads
    snapped = snap_route_coords(original_coords)
    if not snapped or len(snapped) < 3:
        return False

    # Update the coordinates
    route_feature["geometry"]["coordinates"] = snapped
    gj["properties"]["num_coordinates"] = len(snapped)
    gj["properties"]["road_snapped"] = True

    with open(filepath, "w") as f:
        json.dump(gj, f, indent=2)

    return True


def main():
    geojson_files = sorted([
        f for f in os.listdir(GEOJSON_DIR)
        if f.endswith(".geojson")
    ])

    print(f"Found {len(geojson_files)} GeoJSON files to process")

    snapped = 0
    skipped = 0
    failed = 0

    for i, filename in enumerate(geojson_files):
        filepath = os.path.join(GEOJSON_DIR, filename)

        # Check if already snapped
        with open(filepath) as f:
            gj = json.load(f)
        if gj.get("properties", {}).get("road_snapped"):
            skipped += 1
            continue

        # Get original coord count
        route_feat = None
        for feat in gj.get("features", []):
            if feat.get("properties", {}).get("type") == "route":
                route_feat = feat
                break
        orig_count = len(route_feat["geometry"]["coordinates"]) if route_feat else 0

        print(f"[{i+1}/{len(geojson_files)}] {filename} ({orig_count} coords)...", end=" ", flush=True)

        if process_geojson(filepath):
            # Re-read to get new count
            with open(filepath) as f:
                new_gj = json.load(f)
            new_route = None
            for feat in new_gj.get("features", []):
                if feat.get("properties", {}).get("type") == "route":
                    new_route = feat
                    break
            new_count = len(new_route["geometry"]["coordinates"]) if new_route else 0
            print(f"OK ({orig_count} -> {new_count} coords)")
            snapped += 1
        else:
            print("FAILED")
            failed += 1

        # Rate limit
        time.sleep(0.5)

    print(f"\nDone: {snapped} snapped, {skipped} already done, {failed} failed")


if __name__ == "__main__":
    main()
