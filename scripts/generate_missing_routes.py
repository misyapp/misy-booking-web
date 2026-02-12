#!/usr/bin/env python3
"""
Generate GeoJSON files for the 36 missing transport lines using:
1. Known Antananarivo neighborhood coordinates
2. Nominatim geocoding as fallback
3. OSRM routing between endpoints

Usage:
    python3 scripts/generate_missing_routes.py
"""

import json
import os
import time
import urllib.request
import urllib.parse
import re

OSRM_URL = "https://osrm2.misy.app"
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
GEOJSON_DIR = "assets/transport_lines/core"
MANIFEST_PATH = "assets/transport_lines/manifest.json"

# Known Antananarivo neighborhood coordinates (lat, lon)
KNOWN_PLACES = {
    "67ha": (-18.9137, 47.5225),
    "67 ha": (-18.9137, 47.5225),
    "67 hectares": (-18.9137, 47.5225),
    "analakely": (-18.9097, 47.5256),
    "ambohijatovo": (-18.9073, 47.5303),
    "soarano": (-18.9068, 47.5228),
    "antanimena": (-18.9043, 47.5313),
    "behoririka": (-18.9092, 47.5215),
    "andoharanofotsy": (-18.9685, 47.5270),
    "anosibe": (-18.9267, 47.5107),
    "mahamasina": (-18.9127, 47.5167),
    "anosy": (-18.9157, 47.5188),
    "ambohipo": (-18.9233, 47.5300),
    "ankatso": (-18.9237, 47.5078),
    "tsimbazaza": (-18.9218, 47.5220),
    "soavimasoandro": (-18.9368, 47.4868),
    "tanjombato": (-18.9478, 47.5068),
    "anosizato": (-18.9308, 47.4918),
    "ambatomena": (-18.9147, 47.5297),
    "manakambahiny": (-18.8967, 47.5378),
    "manankambahiny": (-18.8967, 47.5378),
    "mandroseza": (-18.9467, 47.5278),
    "soanierana": (-18.9167, 47.5093),
    "antanandrano": (-18.9058, 47.5138),
    "alarobia": (-18.9017, 47.5437),
    "androhibe": (-18.9083, 47.5497),
    "ambatoroka": (-18.9093, 47.5353),
    "ambodifilao": (-18.9167, 47.5237),
    "petite vitesse": (-18.9098, 47.5168),
    "soavina": (-18.8997, 47.5307),
    "ambolokandrina": (-18.9107, 47.5387),
    "mahazoarivo": (-18.9107, 47.5267),
    "anosipatrana": (-18.9187, 47.5287),
    "manjakamiadana": (-18.9227, 47.5187),
    "ambohitsoa": (-18.8997, 47.5437),
    "antsobolo": (-18.9367, 47.5297),
    "manjakaray": (-18.8997, 47.5247),
    "ambanidia": (-18.9183, 47.5250),
    "ambohipotsy": (-18.9158, 47.5273),
    "andranomena": (-18.9367, 47.5078),
    "soavinandriana": (-18.8907, 47.5147),
    "belair": (-18.8917, 47.5467),
    "rasalama": (-18.9043, 47.5313),  # Near Antanimena
    "isotry": (-18.9137, 47.5177),
    "ankadifotsy": (-18.9053, 47.5357),
    "ankadimbahoaka": (-18.9347, 47.5237),
    "ambohimanarina": (-18.8987, 47.5178),
    "itaosy": (-18.9218, 47.4708),
    "ivato": (-18.8008, 47.4788),
    "ambodifasina": (-18.8368, 47.4838),
}


def clean_place_name(raw: str) -> str:
    """Clean a direction/place name for geocoding."""
    name = raw.strip()

    # Remove prefixes like "A - ", "B - ", "A : Cf : "
    name = re.sub(r'^[A-Z]\s*[-:]\s*(Cf\s*:\s*)?', '', name)

    # Remove ">" direction markers
    name = name.replace('>', ' ').replace('<', ' ')

    # Take first meaningful part if composite (e.g., "Ambohijatovo - Soanierana" -> "Ambohijatovo")
    if ' - ' in name:
        parts = [p.strip() for p in name.split(' - ')]
        # Return the most specific part (longest)
        name = max(parts, key=len)

    # Remove common suffixes
    name = name.strip()
    return name


def geocode_place(name: str) -> tuple:
    """Geocode a place name, first checking known places, then Nominatim."""
    cleaned = clean_place_name(name)
    lower = cleaned.lower().strip()

    # Check known places
    if lower in KNOWN_PLACES:
        return KNOWN_PLACES[lower]

    # Try partial matches
    for key, coords in KNOWN_PLACES.items():
        if key in lower or lower in key:
            return coords

    # Fallback to Nominatim
    print(f"    Geocoding via Nominatim: '{cleaned}'...")
    params = urllib.parse.urlencode({
        "q": f"{cleaned}, Antananarivo, Madagascar",
        "format": "json",
        "limit": 1,
        "countrycodes": "mg",
    })
    url = f"{NOMINATIM_URL}?{params}"
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "MisyTransportGeocoder/1.0")

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            results = json.loads(resp.read().decode("utf-8"))
        if results:
            lat = float(results[0]["lat"])
            lon = float(results[0]["lon"])
            print(f"      Found: {lat}, {lon}")
            time.sleep(1.1)  # Nominatim rate limit
            return (lat, lon)
        else:
            print(f"      Not found!")
            time.sleep(1.1)
            return None
    except Exception as e:
        print(f"      Error: {e}")
        time.sleep(1.1)
        return None


def osrm_route(from_coords: tuple, to_coords: tuple) -> list:
    """Get a road route between two points via OSRM."""
    from_lat, from_lon = from_coords
    to_lat, to_lon = to_coords

    url = (
        f"{OSRM_URL}/route/v1/driving/"
        f"{from_lon},{from_lat};{to_lon},{to_lat}"
        f"?overview=full&geometries=geojson"
    )

    for attempt in range(3):
        try:
            req = urllib.request.Request(url)
            req.add_header("User-Agent", "MisyTransportGeocoder/1.0")
            with urllib.request.urlopen(req, timeout=15) as resp:
                result = json.loads(resp.read().decode("utf-8"))

            if result.get("code") == "Ok" and result.get("routes"):
                return result["routes"][0]["geometry"]["coordinates"]
        except Exception as e:
            if attempt < 2:
                time.sleep(2)
    return None


def build_geojson(line_number: str, direction: str, coords: list) -> dict:
    """Build a GeoJSON FeatureCollection for a route."""
    return {
        "type": "FeatureCollection",
        "properties": {
            "line": line_number,
            "direction": direction,
            "num_stops": 0,
            "num_coordinates": len(coords),
            "source": "geocoded_osrm",
            "road_snapped": True
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
            }
        ]
    }


def main():
    os.makedirs(GEOJSON_DIR, exist_ok=True)

    with open(MANIFEST_PATH) as f:
        manifest = json.load(f)

    generated = 0
    failed = 0

    for line in manifest["lines"]:
        ln = line["line_number"]
        aller_path = os.path.join(GEOJSON_DIR, f"{ln}_aller.geojson")
        retour_path = os.path.join(GEOJSON_DIR, f"{ln}_retour.geojson")

        if os.path.exists(aller_path):
            continue

        aller_data = line.get("aller", {})
        retour_data = line.get("retour", {})

        from_name = aller_data.get("direction", "")
        to_name = retour_data.get("direction", "")

        if not from_name:
            print(f"  {ln}: no endpoint names, skipping")
            failed += 1
            continue

        print(f"\n  {ln}: {from_name} <-> {to_name}")

        # Geocode endpoints
        from_coords = geocode_place(from_name)
        if not from_coords:
            print(f"    Could not geocode FROM: '{from_name}'")
            failed += 1
            continue

        if to_name:
            to_coords = geocode_place(to_name)
        else:
            to_coords = None

        if not to_coords:
            # If no destination, try reverse of from
            print(f"    No TO endpoint, using nearby landmark as destination")
            # Use Analakely (city center) as default destination
            to_coords = KNOWN_PLACES["analakely"]

        print(f"    FROM: {from_coords} -> TO: {to_coords}")

        # Route via OSRM
        route_coords = osrm_route(from_coords, to_coords)
        if not route_coords or len(route_coords) < 2:
            print(f"    OSRM routing failed!")
            failed += 1
            continue

        # Generate aller
        aller_gj = build_geojson(ln, from_name, route_coords)
        with open(aller_path, "w") as f:
            json.dump(aller_gj, f, indent=2)
        generated += 1
        print(f"    {ln}_aller: {len(route_coords)} coords")

        # Generate retour (reverse)
        if retour_data:
            retour_coords = list(reversed(route_coords))
            retour_gj = build_geojson(ln, to_name or "retour", retour_coords)
            with open(retour_path, "w") as f:
                json.dump(retour_gj, f, indent=2)
            generated += 1
            print(f"    {ln}_retour: {len(retour_coords)} coords (reversed)")

        time.sleep(0.3)

    # Update manifest
    updated = 0
    for line in manifest["lines"]:
        ln = line["line_number"]
        changed = False
        for direction in ["aller", "retour"]:
            d = line.get(direction)
            if d:
                filepath = os.path.join(GEOJSON_DIR, f"{ln}_{direction}.geojson")
                if os.path.exists(filepath):
                    asset_path = f"assets/transport_lines/core/{ln}_{direction}.geojson"
                    if d.get("asset_path") != asset_path:
                        d["asset_path"] = asset_path
                        changed = True
        if changed:
            line["is_bundled"] = True
            updated += 1

    with open(MANIFEST_PATH, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"\n\nGenerated {generated} GeoJSON files, {failed} failed")
    print(f"Updated {updated} lines in manifest")

    # Final check
    total = len(manifest["lines"])
    bundled = sum(1 for l in manifest["lines"] if l.get("is_bundled"))
    print(f"\nTotal coverage: {bundled}/{total} lines ({bundled*100//total}%)")


if __name__ == "__main__":
    main()
