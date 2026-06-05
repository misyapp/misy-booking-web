#!/usr/bin/env python3
"""Filigrane géométrique INVISIBLE des tracés taxi-be servis au client +
détecteur de copie. Anti-scraping niveau 1 (le meilleur ROI) : on ne peut
pas empêcher la copie de données affichées, mais on peut la rendre PROUVABLE.

Principe (technique des « trap streets » des cartographes, version
géométrique) : chaque sommet des polylignes est déplacé perpendiculairement
de quelques décimètres (≤ AMP_M ~1,5 m) selon un motif sinusoïdal
DÉTERMINISTE seedé par (version de déploiement + numéro de ligne). C'est :
  - INVISIBLE à l'usage (sous l'épaisseur du trait, dans le bruit GPS) ;
  - sans effet sur l'app (snap d'arrêts, routing : tolérances ≫ 1,5 m) ;
  - une SIGNATURE : si un concurrent réaffiche nos tracés, `--verify`
    retrouve le motif → preuve de copie (date de version comprise).

Le seed de chaque déploiement est journalisé hors dépôt
(~/.misy/watermark-registry.jsonl) : c'est la pièce qui date la fuite.

Usage :
  watermark.py apply <build/web> [--version YYYYMMDD-N]   # avant rsync
  watermark.py verify <fichier_suspect.geojson> [--version V]  # corrélation
"""
import glob
import hashlib
import json
import math
import os
import sys

AMP_M = 1.5          # amplitude max du déplacement perpendiculaire (mètres)
M_LAT = 111320.0
REGISTRY = os.path.expanduser("~/.misy/watermark-registry.jsonl")
COPYRIGHT = ("© 2026 Misy — base de données de tracés taxi-be protégée "
             "(droit sui generis des bases de données). Usage exclusif de "
             "l'application Misy. Filigrane traçable intégré.")


def _seed(version, line_key):
    h = hashlib.sha256(f"{version}|{line_key}".encode()).digest()
    # deux flottants pseudo-aléatoires stables : phase + fréquence
    phase = int.from_bytes(h[:4], "big") / 0xFFFFFFFF * 2 * math.pi
    freq = 0.4 + int.from_bytes(h[4:8], "big") / 0xFFFFFFFF * 1.2
    return phase, freq


def _offsets(coords, version, line_key):
    """Déplacement (dlng, dlat) en degrés à appliquer à chaque sommet."""
    phase, freq = _seed(version, line_key)
    out = []
    n = len(coords)
    for i in range(n):
        lng, lat = coords[i][0], coords[i][1]
        mlng = M_LAT * math.cos(math.radians(lat))
        # tangente locale → perpendiculaire unitaire
        a = coords[max(0, i - 1)]
        b = coords[min(n - 1, i + 1)]
        tE = (b[0] - a[0]) * mlng
        tN = (b[1] - a[1]) * M_LAT
        ln = math.hypot(tE, tN)
        if ln < 1e-9:
            out.append((0.0, 0.0))
            continue
        # perpendiculaire (−tN, tE) normalisée
        pE, pN = -tN / ln, tE / ln
        amp = AMP_M * math.sin(phase + freq * i)
        dE, dN = pE * amp, pN * amp           # mètres
        out.append((dE / mlng, dN / M_LAT))   # → degrés
    return out


def _walk_linestrings(gj):
    """Itère les LineString d'un FeatureCollection ou d'un network_strands."""
    if gj.get("type") == "FeatureCollection":
        for ft in gj.get("features", []):
            if ft.get("geometry", {}).get("type") == "LineString":
                yield ft["geometry"]["coordinates"]


def _line_key_of(path):
    return os.path.basename(path).rsplit(".", 1)[0]


def apply(build_dir, version):
    core = os.path.join(build_dir, "assets", "assets",
                        "transport_lines_public", "core")
    files = sorted(glob.glob(os.path.join(core, "*.geojson")))
    touched = 0
    for f in files:
        gj = json.load(open(f))
        key = _line_key_of(f)
        for coords in _walk_linestrings(gj):
            offs = _offsets(coords, version, key)
            for i, (dlng, dlat) in enumerate(offs):
                coords[i][0] = round(coords[i][0] + dlng, 7)
                coords[i][1] = round(coords[i][1] + dlat, 7)
        gj.setdefault("properties", {})["_wm"] = {"v": version, "c": COPYRIGHT}
        json.dump(gj, open(f, "w"), separators=(",", ":"))
        touched += 1

    # © dans le manifest servi
    man = os.path.join(build_dir, "assets", "assets",
                       "transport_lines_public", "manifest.json")
    if os.path.exists(man):
        m = json.load(open(man))
        m["_wm"] = {"v": version, "c": COPYRIGHT}
        json.dump(m, open(man, "w"), separators=(",", ":"))

    # © dans les faisceaux LOOM (pas de filigrane géo : géométrie dérivée,
    # déjà couverte par le bundle ; on marque juste la propriété)
    strands = os.path.join(build_dir, "transport_network",
                           "network_strands.json")
    if os.path.exists(strands):
        s = json.load(open(strands))
        s.setdefault("meta", {})["_wm"] = {"v": version, "c": COPYRIGHT}
        json.dump(s, open(strands, "w"), separators=(",", ":"))

    os.makedirs(os.path.dirname(REGISTRY), exist_ok=True)
    with open(REGISTRY, "a") as r:
        r.write(json.dumps({"version": version, "files": touched,
                            "amp_m": AMP_M}) + "\n")
    print("✓ filigrane v=%s appliqué à %d tracés + manifest + strands"
          % (version, touched))
    print("  seed journalisé → %s" % REGISTRY)


def verify(suspect, version, ref=None, key=None):
    """Le tracé suspect est-il une COPIE de notre version filigranée ?

    On compare le suspect à NOTRE source non-filigranée (par défaut le
    bundle du dépôt) appariée par numéro de ligne, et on mesure la
    corrélation entre l'écart observé (suspect − source) et le motif
    attendu pour (version, ligne). corr ≈ +1 → c'est notre filigrane
    (preuve de copie) ; ≈ 0 → données indépendantes.

    Suppose les sommets préservés (cas du scrape direct du JSON, le plus
    courant). Le suspect peut être un fichier .geojson OU un dossier ;
    `--ref` = dossier core/ de référence (défaut : bundle du dépôt)."""
    ref = ref or os.path.expanduser(
        "~/StudioProjects/misy_booking_web/assets/transport_lines_public/core")

    def first_ls(path):
        for c in _walk_linestrings(json.load(open(path))):
            return c
        return None

    pairs = []  # (suspect_coords, ref_coords, line_key)
    if os.path.isdir(suspect):
        for sf in sorted(glob.glob(os.path.join(suspect, "*.geojson"))):
            k = _line_key_of(sf)
            rf = os.path.join(ref, os.path.basename(sf))
            if os.path.exists(rf):
                sc, rc = first_ls(sf), first_ls(rf)
                if sc and rc and len(sc) == len(rc):
                    pairs.append((sc, rc, k))
    else:
        sc = first_ls(suspect)
        k = key or _line_key_of(suspect)
        rf = os.path.join(ref, k + ".geojson")
        rc = first_ls(rf) if os.path.exists(rf) else None
        if sc and rc and len(sc) == len(rc):
            pairs.append((sc, rc, k))

    if not pairs:
        print("verify: aucune ligne appariable (sommets non préservés ou "
              "ref introuvable) — comparer manuellement une ligne avec "
              "--ref <core/> --key <num>")
        return

    num, den_s, den_e = 0.0, 0.0, 0.0
    M = M_LAT
    for sc, rc, k in pairs:
        offs = _offsets(rc, version, k)  # motif attendu (degrés)
        for i in range(len(rc)):
            obsE = (sc[i][0] - rc[i][0])
            obsN = (sc[i][1] - rc[i][1])
            expE, expN = offs[i]
            num += obsE * expE + obsN * expN
            den_s += obsE * obsE + obsN * obsN
            den_e += expE * expE + expN * expN
    corr = num / math.sqrt(den_s * den_e) if den_s > 0 and den_e > 0 else 0.0
    verdict = ("⚠️  COPIE de notre filigrane (preuve)" if corr > 0.7
               else "≈ indépendant (pas notre filigrane)" if abs(corr) < 0.3
               else "indéterminé (sommets resamplés ? mauvaise version ?)")
    print("lignes appariées : %d" % len(pairs))
    print("corrélation au motif v=%s : %.3f → %s" % (version, corr, verdict))


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    cmd, target = sys.argv[1], sys.argv[2]
    version = "dev"
    if "--version" in sys.argv:
        version = sys.argv[sys.argv.index("--version") + 1]
    ref = sys.argv[sys.argv.index("--ref") + 1] if "--ref" in sys.argv else None
    key = sys.argv[sys.argv.index("--key") + 1] if "--key" in sys.argv else None
    if cmd == "apply":
        apply(target, version)
    elif cmd == "verify":
        verify(target, version, ref=ref, key=key)
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
