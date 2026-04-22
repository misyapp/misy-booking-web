#!/usr/bin/env node
/**
 * Pull des éditions de l'éditeur terrain depuis Firestore vers les GeoJSON
 * locaux + mise à jour du manifest.
 *
 * Workflow :
 *   1) Le consultant bosse sur book.misy.app/#/transport-editor (session web).
 *   2) Ses modifs vont dans Firestore : `transport_lines_edited/{ligne}`.
 *   3) En fin de journée, depuis le poste dev :
 *        node scripts/transport_editor_pull_cli.js status
 *        node scripts/transport_editor_pull_cli.js diff 017
 *        node scripts/transport_editor_pull_cli.js pull 017
 *        node scripts/transport_editor_pull_cli.js pull --all
 *        node scripts/transport_editor_pull_cli.js prune --all
 *   4) git diff → commit → rsync vers Bluehost.
 *
 * Pré-requis : assets/json_files/service_account_credential.json
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const COLL_EDITED = 'transport_lines_edited';
const COLL_VALIDATIONS = 'transport_line_validations';
const COLL_LOG = 'transport_edits_log';

const REPO_ROOT = path.resolve(__dirname, '..');
const ASSETS_DIR = path.resolve(REPO_ROOT, 'assets/transport_lines');
const CORE_DIR = path.resolve(ASSETS_DIR, 'core');
const MANIFEST_PATH = path.resolve(ASSETS_DIR, 'manifest.json');

const SERVICE_ACCOUNT_PATH = path.resolve(
  REPO_ROOT,
  'assets/json_files/service_account_credential.json',
);

function initFirebase() {
  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ Clé de service introuvable: ${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
  }
  const sa = require(SERVICE_ACCOUNT_PATH);
  admin.initializeApp({ credential: admin.credential.cert(sa) });
  return admin.firestore();
}

/**
 * Lit le FeatureCollection d'une direction dans un doc Firestore.
 * Gère les deux formats :
 *   - ancien : {aller: {feature_collection: {...}}}  (map direct)
 *   - nouveau : {aller: {feature_collection_json: "..."}} (string JSON, Firestore
 *     ne supporte pas les nested arrays donc on stringify)
 */
function extractFeatureCollection(dirMap) {
  if (!dirMap) return null;
  if (dirMap.feature_collection) return dirMap.feature_collection;
  if (typeof dirMap.feature_collection_json === 'string') {
    try {
      return JSON.parse(dirMap.feature_collection_json);
    } catch (e) {
      console.error('⚠️ feature_collection_json invalide:', e.message);
      return null;
    }
  }
  return null;
}

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith('--')) args[key] = true;
      else { args[key] = next; i++; }
    } else {
      args._.push(a);
    }
  }
  return args;
}

function readManifest() {
  if (!fs.existsSync(MANIFEST_PATH)) {
    return { version: '2.0', last_updated: today(), total_lines: 0, lines: [] };
  }
  return JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
}

function writeManifest(manifest) {
  manifest.last_updated = today();
  manifest.total_lines = manifest.lines.length;
  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2) + '\n');
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function assetPaths(lineNumber) {
  return {
    aller: path.join(CORE_DIR, `${lineNumber}_aller.geojson`),
    retour: path.join(CORE_DIR, `${lineNumber}_retour.geojson`),
  };
}

function relAsset(lineNumber, dir) {
  return `assets/transport_lines/core/${lineNumber}_${dir}.geojson`;
}

function writeFeatureCollection(filePath, fc) {
  // Tri cohérent : LineString en premier, puis Points d'arrêts.
  const features = (fc.features || []).slice();
  features.sort((a, b) => {
    const ta = a.geometry?.type, tb = b.geometry?.type;
    if (ta === tb) return 0;
    if (ta === 'LineString') return -1;
    if (tb === 'LineString') return 1;
    return 0;
  });
  fc.features = features;
  if (!fs.existsSync(path.dirname(filePath))) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
  }
  fs.writeFileSync(filePath, JSON.stringify(fc, null, 2) + '\n');
}

function countStops(fc) {
  return (fc?.features || []).filter(
    (f) => f.geometry?.type === 'Point' && f.properties?.type !== 'report_point',
  ).length;
}

// ─────────────────────── Commandes ───────────────────────

async function cmdStatus(db) {
  const snap = await db.collection(COLL_VALIDATIONS).get();
  if (snap.empty) {
    console.log('Aucune validation enregistrée.');
    return;
  }
  const rows = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  rows.sort((a, b) => a.id.localeCompare(b.id));
  const pad = (s, n) => String(s).padEnd(n);
  console.log(pad('Ligne', 16), pad('Aller', 12), pad('Retour', 12), 'par');
  console.log('─'.repeat(60));
  for (const r of rows) {
    // Schema 2 clés (post-avril 2026). Fallback sur l'ancien 4-clés (merge
    // route + stops) pour les docs pas encore migrés.
    const aller = r.aller || mergeLegacy(r.aller_route, r.aller_stops);
    const retour = r.retour || mergeLegacy(r.retour_route, r.retour_stops);
    console.log(
      pad(r.id, 16),
      pad(aller || 'pending', 12),
      pad(retour || 'pending', 12),
      r.updated_by_email || '-',
    );
  }
}

function mergeLegacy(route, stops) {
  if (route === 'modified' || stops === 'modified') return 'modified';
  if (route === 'validated' && stops === 'validated') return 'validated';
  return 'pending';
}

async function cmdDiff(db, args) {
  const lineNumber = args._[0];
  if (!lineNumber) {
    console.error('Usage: diff <ligne>');
    process.exit(1);
  }
  const doc = await db.collection(COLL_EDITED).doc(lineNumber).get();
  if (!doc.exists) {
    console.log(`Aucune édition pour la ligne ${lineNumber}`);
    return;
  }
  const data = doc.data();
  const paths = assetPaths(lineNumber);

  for (const dir of ['aller', 'retour']) {
    const remote = extractFeatureCollection(data[dir]);
    if (!remote) continue;
    const localPath = paths[dir];
    const existsLocal = fs.existsSync(localPath);
    if (!existsLocal) {
      console.log(`[${dir}] nouveau fichier : ${localPath}`);
      continue;
    }
    const local = JSON.parse(fs.readFileSync(localPath, 'utf8'));
    const lsLocal = (local.features || []).find((f) => f.geometry?.type === 'LineString');
    const lsRemote = (remote.features || []).find((f) => f.geometry?.type === 'LineString');
    const vLocal = lsLocal?.geometry?.coordinates?.length || 0;
    const vRemote = lsRemote?.geometry?.coordinates?.length || 0;
    const sLocal = countStops(local);
    const sRemote = countStops(remote);
    console.log(`[${dir}]`);
    console.log(`  vertices : ${vLocal} → ${vRemote}  (Δ ${vRemote - vLocal})`);
    console.log(`  arrêts   : ${sLocal} → ${sRemote}  (Δ ${sRemote - sLocal})`);
  }
}

async function cmdPull(db, args) {
  const lineNumber = args._[0];
  if (!args.all && !lineNumber) {
    console.error('Usage: pull <ligne>   ou   pull --all');
    process.exit(1);
  }

  let docs;
  if (args.all) {
    const snap = await db.collection(COLL_EDITED).get();
    docs = snap.docs;
  } else {
    const d = await db.collection(COLL_EDITED).doc(lineNumber).get();
    if (!d.exists) {
      console.error(`❌ Aucun document pour ${lineNumber}`);
      process.exit(1);
    }
    docs = [d];
  }

  const manifest = readManifest();
  const byLine = new Map(manifest.lines.map((l) => [l.line_number, l]));

  let touched = 0;
  for (const doc of docs) {
    const lineNumber = doc.id;
    const data = doc.data();
    const paths = assetPaths(lineNumber);

    for (const dir of ['aller', 'retour']) {
      const fc = extractFeatureCollection(data[dir]);
      if (!fc) continue;
      writeFeatureCollection(paths[dir], fc);
      console.log(`✅ ${dir.padEnd(6)} ${lineNumber}  → ${paths[dir]}`);
      touched++;
    }

    // MAJ manifest
    const existing = byLine.get(lineNumber);
    const entry = existing || {
      line_number: lineNumber,
      display_name: data.display_name || `Ligne ${lineNumber}`,
      transport_type: data.transport_type || 'bus',
      color: data.color || '0xFF1565C0',
      is_bundled: true,
    };
    entry.display_name = data.display_name || entry.display_name;
    entry.transport_type = data.transport_type || entry.transport_type;
    entry.color = data.color || entry.color;
    entry.is_bundled = data.is_bundled ?? entry.is_bundled ?? true;

    const allerFc = extractFeatureCollection(data.aller);
    if (allerFc) {
      entry.aller = {
        direction: allerFc.properties?.direction || entry.aller?.direction || '',
        num_stops: countStops(allerFc),
        asset_path: relAsset(lineNumber, 'aller'),
        remote_url: entry.aller?.remote_url,
      };
    }
    const retourFc = extractFeatureCollection(data.retour);
    if (retourFc) {
      entry.retour = {
        direction: retourFc.properties?.direction || entry.retour?.direction || '',
        num_stops: countStops(retourFc),
        asset_path: relAsset(lineNumber, 'retour'),
        remote_url: entry.retour?.remote_url,
      };
    }
    if (!existing) {
      manifest.lines.push(entry);
      byLine.set(lineNumber, entry);
    }
  }

  manifest.lines.sort((a, b) => a.line_number.localeCompare(b.line_number));
  writeManifest(manifest);
  console.log(`\n📝 manifest mis à jour (${manifest.lines.length} lignes)`);
  console.log(`\n${touched} fichier(s) écrit(s). git diff pour revue.`);
}

async function cmdPrune(db, args) {
  const lineNumber = args._[0];
  if (!args.all && !lineNumber) {
    console.error('Usage: prune <ligne>   ou   prune --all');
    process.exit(1);
  }
  const lines = args.all
    ? (await db.collection(COLL_EDITED).get()).docs.map((d) => d.id)
    : [lineNumber];

  for (const line of lines) {
    await db.collection(COLL_EDITED).doc(line).delete().catch(() => {});
    await db.collection(COLL_VALIDATIONS).doc(line).delete().catch(() => {});
    console.log(`🗑  ${line}  (edited + validations supprimés — logs conservés)`);
  }
}

async function main() {
  const [, , cmd, ...rest] = process.argv;
  if (!cmd || cmd === '--help' || cmd === '-h') {
    console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]);
    process.exit(0);
  }
  const args = parseArgs(rest);
  const db = initFirebase();

  try {
    switch (cmd) {
      case 'status':
        await cmdStatus(db, args);
        break;
      case 'diff':
        await cmdDiff(db, args);
        break;
      case 'pull':
        await cmdPull(db, args);
        break;
      case 'prune':
        await cmdPrune(db, args);
        break;
      default:
        console.error(`Commande inconnue: ${cmd}`);
        console.error('Commandes: status | diff | pull | prune');
        process.exit(1);
    }
  } catch (e) {
    console.error('❌ Erreur:', e.message);
    process.exit(1);
  }
  process.exit(0);
}

main();
