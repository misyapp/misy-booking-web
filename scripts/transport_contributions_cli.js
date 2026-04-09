#!/usr/bin/env node
/**
 * CLI de modération + export des contributions utilisateur sur les lignes de transport.
 *
 * Workflow :
 *   1) `list <ligne>`            -> voir les contributions en attente (filtre spam/test)
 *   2) `approve <id>`            -> valider (status -> reviewed)
 *   3) `reject  <id>`            -> rejeter (status -> rejected) pour spam/test
 *   4) `export  <ligne>`         -> exporter en GeoJSON (uniquement validées) pour QGIS
 *
 * Seules les contributions au statut `reviewed` ou `implemented` sont exportées.
 * Les `pending` et `rejected` sont volontairement exclues de l'export.
 *
 * Pré-requis : assets/json_files/service_account_credential.json
 *
 * Exemples :
 *   node scripts/transport_contributions_cli.js list 129
 *   node scripts/transport_contributions_cli.js list 129 --status pending
 *   node scripts/transport_contributions_cli.js approve abc123 --note "validé sur place"
 *   node scripts/transport_contributions_cli.js reject  xyz789 --note "spam"
 *   node scripts/transport_contributions_cli.js export 129
 *   node scripts/transport_contributions_cli.js export 129 --out /tmp/ligne_129.geojson
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const COLLECTION = 'transport_contributions';
const SERVICE_ACCOUNT_PATH = path.resolve(
  __dirname,
  '../assets/json_files/service_account_credential.json',
);

function initFirebase() {
  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ Clé de service introuvable: ${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
  }
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  return admin.firestore();
}

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith('--')) {
        args[key] = true;
      } else {
        args[key] = next;
        i++;
      }
    } else {
      args._.push(a);
    }
  }
  return args;
}

function fmtDate(ts) {
  if (!ts) return '-';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toISOString().replace('T', ' ').slice(0, 16);
}

async function cmdList(db, args) {
  const lineNumber = args._[0];
  if (!lineNumber) {
    console.error('Usage: list <ligne> [--status pending|reviewed|implemented|rejected]');
    process.exit(1);
  }
  const status = args.status || 'pending';
  const snap = await db
    .collection(COLLECTION)
    .where('line_number', '==', lineNumber)
    .where('status', '==', status)
    .orderBy('submitted_at', 'desc')
    .get();

  if (snap.empty) {
    console.log(`Aucune contribution (ligne=${lineNumber}, status=${status})`);
    return;
  }

  console.log(`📋 ${snap.size} contribution(s) — ligne ${lineNumber} — status=${status}\n`);
  snap.docs.forEach((doc) => {
    const d = doc.data();
    const ed = d.edit_data || {};
    const loc = d.location;
    console.log(`─ ${doc.id}`);
    console.log(`  user      : ${d.user_name || '-'} (${d.user_id || '-'})`);
    console.log(`  type      : ${d.contribution_type || '-'}  action: ${ed.action || '-'}`);
    console.log(`  desc      : ${(d.description || '').slice(0, 120)}`);
    console.log(`  location  : ${loc ? `${loc.latitude.toFixed(5)},${loc.longitude.toFixed(5)}` : '-'}`);
    console.log(`  submitted : ${fmtDate(d.submitted_at)}`);
    if (ed.stop_name) console.log(`  stop      : ${ed.stop_name}`);
    if (ed.route_segment) console.log(`  segment   : ${ed.route_segment.length} pts (retour)`);
    if (ed.route_aller_segment) console.log(`  segment   : ${ed.route_aller_segment.length} pts (aller)`);
    console.log();
  });
}

async function cmdSetStatus(db, args, newStatus) {
  const id = args._[0];
  if (!id) {
    console.error(`Usage: ${newStatus === 'reviewed' ? 'approve' : 'reject'} <contributionId> [--note "..."]`);
    process.exit(1);
  }
  const ref = db.collection(COLLECTION).doc(id);
  const doc = await ref.get();
  if (!doc.exists) {
    console.error(`❌ Contribution introuvable: ${id}`);
    process.exit(1);
  }
  await ref.update({
    status: newStatus,
    moderator_notes: args.note || '',
    reviewed_by: 'cli-admin',
    reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`✅ ${id} -> status=${newStatus}`);
}

function buildFeatures(doc) {
  const d = doc.data();
  const ed = d.edit_data || {};
  const features = [];
  const baseProps = {
    id: doc.id,
    line_number: d.line_number,
    contribution_type: d.contribution_type,
    action: ed.action || null,
    description: d.description || '',
    user_name: d.user_name || '',
    status: d.status,
    submitted_at: fmtDate(d.submitted_at),
    moderator_notes: d.moderator_notes || '',
  };

  // Point principal (toujours présent : la position du signalement)
  if (d.location) {
    features.push({
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: [d.location.longitude, d.location.latitude],
      },
      properties: { ...baseProps, kind: 'report_point' },
    });
  }

  // Arrêt déplacé : ancien + nouveau
  if (ed.old_coordinates) {
    features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [ed.old_coordinates.lng, ed.old_coordinates.lat] },
      properties: { ...baseProps, kind: 'stop_old', stop_name: ed.stop_name || null },
    });
  }
  if (ed.new_coordinates) {
    features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [ed.new_coordinates.lng, ed.new_coordinates.lat] },
      properties: { ...baseProps, kind: 'stop_new', stop_name: ed.stop_name || null },
    });
  }

  // Segments de tracé (déjà stockés en [lng, lat])
  if (Array.isArray(ed.route_segment) && ed.route_segment.length >= 2) {
    features.push({
      type: 'Feature',
      geometry: { type: 'LineString', coordinates: ed.route_segment },
      properties: { ...baseProps, kind: 'route_segment_retour' },
    });
  }
  if (Array.isArray(ed.route_aller_segment) && ed.route_aller_segment.length >= 2) {
    features.push({
      type: 'Feature',
      geometry: { type: 'LineString', coordinates: ed.route_aller_segment },
      properties: { ...baseProps, kind: 'route_segment_aller' },
    });
  }

  // Primus / terminus
  if (ed.primus) {
    features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [ed.primus.lng, ed.primus.lat] },
      properties: { ...baseProps, kind: 'primus', name: ed.primus_name || null },
    });
  }
  if (ed.terminus) {
    features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [ed.terminus.lng, ed.terminus.lat] },
      properties: { ...baseProps, kind: 'terminus', name: ed.terminus_name || null },
    });
  }

  return features;
}

async function cmdExport(db, args) {
  const lineNumber = args._[0];
  if (!lineNumber) {
    console.error('Usage: export <ligne> [--out file.geojson] [--include-implemented]');
    process.exit(1);
  }

  // On exporte UNIQUEMENT les contributions validées par un admin.
  // Par défaut: reviewed + implemented. Jamais pending ni rejected.
  const allowedStatuses = ['reviewed', 'implemented'];

  const snap = await db
    .collection(COLLECTION)
    .where('line_number', '==', lineNumber)
    .where('status', 'in', allowedStatuses)
    .get();

  if (snap.empty) {
    console.log(`Aucune contribution validée pour la ligne ${lineNumber}.`);
    console.log(`(astuce: utiliser "approve <id>" pour valider des contributions pending)`);
    return;
  }

  const features = [];
  snap.docs.forEach((doc) => features.push(...buildFeatures(doc)));

  const fc = {
    type: 'FeatureCollection',
    name: `contributions_ligne_${lineNumber}`,
    crs: { type: 'name', properties: { name: 'urn:ogc:def:crs:OGC:1.3:CRS84' } },
    features,
  };

  const outPath = args.out || path.resolve(process.cwd(), `contributions_ligne_${lineNumber}.geojson`);
  fs.writeFileSync(outPath, JSON.stringify(fc, null, 2));
  console.log(`✅ ${features.length} feature(s) issus de ${snap.size} contribution(s) validée(s)`);
  console.log(`📁 ${outPath}`);
  console.log(`   -> Ouvrir dans QGIS: Couche > Ajouter une couche > Vecteur`);
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
      case 'list':
        await cmdList(db, args);
        break;
      case 'approve':
        await cmdSetStatus(db, args, 'reviewed');
        break;
      case 'reject':
        await cmdSetStatus(db, args, 'rejected');
        break;
      case 'export':
        await cmdExport(db, args);
        break;
      default:
        console.error(`Commande inconnue: ${cmd}`);
        console.error('Commandes: list | approve | reject | export');
        process.exit(1);
    }
  } catch (e) {
    console.error('❌ Erreur:', e.message);
    process.exit(1);
  }
  process.exit(0);
}

main();
