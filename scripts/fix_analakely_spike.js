#!/usr/bin/env node
/**
 * Redresse le tracé entre « Analakely Sicam/Roso » et « Analakely Terminus 113 »
 * dans le bundle public (assets/transport_lines_public/core).
 *
 * LE DÉFAUT (constaté 30/07/2026) : sur cette portion, la rue va tout droit
 * (~101 m) mais le routage OSM fait un aller-retour vers le nœud
 * [47.524694, -18.907314] — 147 m à l'est puis 130 m de retour, d'où le
 * « triangle » visible sur la carte. Trois tracés sont touchés (113/115/142
 * aller) ; les ~23 autres lignes qui passent par ce même nœud le traversent
 * normalement (détour ≈ 1.0) et ne doivent PAS être modifiées.
 *
 * LA CORRECTION : dans la fenêtre entre les deux arrêts, on supprime les
 * vertices qui s'écartent de plus de [MAX_DEVIATION_M] de la droite qui joint
 * ces deux arrêts. Le reste de la géométrie est conservé tel quel (les vertices
 * légitimes sont à ≤ 6 m de cette droite = largeur de chaussée). Le résultat
 * reproduit la géométrie du bundle admin, où 113_aller est déjà propre.
 *
 * ⚠️ À REJOUER APRÈS CHAQUE `publish-bundle` : celui-ci régénère le bundle
 * public depuis Firestore `transport_lines_published`, qui contient toujours le
 * défaut. Tant que la source Firestore n'est pas corrigée, ce script est le
 * rattrapage.
 *
 * Usage :
 *   node scripts/fix_analakely_spike.js --dry-run   # rapport seul
 *   node scripts/fix_analakely_spike.js             # applique
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const PUBLIC_CORE_DIR = path.resolve(
  REPO_ROOT,
  'assets/transport_lines_public/core',
);

/** Les deux arrêts qui bornent la portion à redresser. */
const STOP_A = { name: 'Analakely Sicam/Roso', lng: 47.52288, lat: -18.907229 };
const STOP_B = {
  name: 'Analakely Terminus 113',
  lng: 47.523803,
  lat: -18.907474,
};

/** Un vertex plus loin que ça de la droite A-B est une aberration de routage. */
const MAX_DEVIATION_M = 15;
/** Rattachement d'un arrêt à son vertex : au-delà, la ligne ne dessert pas l'arrêt. */
const STOP_SNAP_M = 60;
/** En dessous de ce rapport (parcouru / direct), la portion est déjà droite. */
const MIN_DETOUR_RATIO = 1.5;

const LAT_SCALE = 111320;
const LNG_SCALE = 111320 * Math.cos((-18.907 * Math.PI) / 180);

const toXY = ([lng, lat]) => [lng * LNG_SCALE, lat * LAT_SCALE];
const dist = (p, q) => Math.hypot(p[0] - q[0], p[1] - q[1]);

/** Distance d'un point au SEGMENT ab (mètres, plan local). */
function distToSegment(p, a, b) {
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  const len2 = dx * dx + dy * dy;
  const t =
    len2 === 0
      ? 0
      : Math.max(
          0,
          Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / len2),
        );
  return Math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy));
}

const lineStringOf = (fc) =>
  (fc.features || []).find((f) => f.geometry?.type === 'LineString') || null;

function nearestIndex(coords, target) {
  const t = toXY([target.lng, target.lat]);
  let best = -1;
  let bestD = Infinity;
  coords.forEach((c, i) => {
    const d = dist(toXY(c), t);
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  });
  return { index: best, distM: bestD };
}

function pathLength(coords, lo, hi) {
  let total = 0;
  for (let i = lo; i < hi; i++) total += dist(toXY(coords[i]), toXY(coords[i + 1]));
  return total;
}

function main() {
  const dryRun = process.argv.includes('--dry-run');
  const files = fs
    .readdirSync(PUBLIC_CORE_DIR)
    .filter((f) => f.endsWith('.geojson'))
    .sort();

  let fixed = 0;
  let scanned = 0;
  const skippedStraight = [];

  for (const file of files) {
    const full = path.join(PUBLIC_CORE_DIR, file);
    let fc;
    try {
      fc = JSON.parse(fs.readFileSync(full, 'utf8'));
    } catch (e) {
      console.log(`⚠️  ${file}: JSON illisible (${e.message}). Skip.`);
      continue;
    }
    const feature = lineStringOf(fc);
    if (!feature) continue;
    const coords = feature.geometry.coordinates;

    const a = nearestIndex(coords, STOP_A);
    const b = nearestIndex(coords, STOP_B);
    // La ligne doit desservir LES DEUX arrêts pour être concernée.
    if (a.distM > STOP_SNAP_M || b.distM > STOP_SNAP_M) continue;
    scanned++;

    const lo = Math.min(a.index, b.index);
    const hi = Math.max(a.index, b.index);
    if (hi - lo < 2) continue; // rien entre les deux bornes

    const travelled = pathLength(coords, lo, hi);
    const direct = dist(toXY(coords[lo]), toXY(coords[hi]));
    const ratio = direct > 0.5 ? travelled / direct : Infinity;
    if (ratio < MIN_DETOUR_RATIO) {
      skippedStraight.push(`${file} (détour ×${ratio.toFixed(2)})`);
      continue;
    }

    // Bornes de la droite de référence + purge des vertices aberrants.
    const refA = toXY(coords[lo]);
    const refB = toXY(coords[hi]);
    const removed = [];
    const kept = [];
    coords.forEach((c, i) => {
      if (i > lo && i < hi) {
        const dev = distToSegment(toXY(c), refA, refB);
        if (dev > MAX_DEVIATION_M) {
          removed.push({ i, c, dev });
          return;
        }
      }
      // Déduplique les vertices consécutifs identiques (artefacts de couture).
      const prev = kept[kept.length - 1];
      if (prev && prev[0] === c[0] && prev[1] === c[1]) return;
      kept.push(c);
    });

    if (removed.length === 0) continue;

    const newRatio =
      pathLength(kept, ...(() => {
        const na = nearestIndex(kept, STOP_A).index;
        const nb = nearestIndex(kept, STOP_B).index;
        return [Math.min(na, nb), Math.max(na, nb)];
      })()) / direct;

    console.log(
      `${dryRun ? '🔎' : '✅'} ${file.padEnd(24)} détour ×${ratio
        .toFixed(1)
        .padStart(5)} → ×${newRatio.toFixed(2)}  | ${
        removed.length
      } vertex retiré(s) : ${removed
        .map((r) => `#${r.i} [${r.c}] écart ${Math.round(r.dev)} m`)
        .join(', ')}`,
    );

    if (!dryRun) {
      feature.geometry.coordinates = kept;
      fs.writeFileSync(full, JSON.stringify(fc, null, 2) + '\n');
    }
    fixed++;
  }

  console.log(
    `\n${dryRun ? 'DRY-RUN — ' : ''}${fixed} fichier(s) ${
      dryRun ? 'à corriger' : 'corrigé(s)'
    } sur ${scanned} desservant les deux arrêts.`,
  );
  if (skippedStraight.length) {
    console.log(
      `Déjà droits, intacts : ${skippedStraight.join(', ')}`,
    );
  }
}

main();
