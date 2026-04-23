#!/usr/bin/env node
/**
 * READ-ONLY — liste tous les users Firebase Auth qui n'ont de doc dans aucune
 * des collections Firestore métier (users, drivers, adminUsers, admins).
 *
 * Distingue 3 catégories :
 *   - TECHNIQUE  : claims transport_admin/transport_editor ou autre claim → compte
 *                  outil, absence de doc Firestore attendue.
 *   - SUSPECT    : aucun claim, aucun doc → probablement un signup raté
 *                  (Auth OK, Firestore KO) ou un compte oublié.
 *   - NORMAL     : au moins un doc Firestore trouvé, pas listé.
 *
 * Aucune écriture. Uniquement un compte-rendu.
 *
 * Usage :
 *   node scripts/find_orphan_users.js [--verbose]
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.resolve(
  __dirname,
  '../assets/json_files/service_account_credential.json',
);

const COLLECTIONS = ['users', 'drivers', 'adminUsers', 'admins'];
const GETALL_BATCH = 300;

function initFirebase() {
  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ Clé de service introuvable: ${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
  }
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

async function listAllAuthUsers(auth) {
  const all = [];
  let pageToken;
  do {
    const res = await auth.listUsers(1000, pageToken);
    all.push(...res.users);
    pageToken = res.pageToken;
  } while (pageToken);
  return all;
}

async function batchedExistence(db, collection, uids) {
  const existence = new Map();
  for (let i = 0; i < uids.length; i += GETALL_BATCH) {
    const slice = uids.slice(i, i + GETALL_BATCH);
    const refs = slice.map((u) => db.collection(collection).doc(u));
    const snaps = await db.getAll(...refs);
    snaps.forEach((s, idx) => existence.set(slice[idx], s.exists));
  }
  return existence;
}

function hasAnyClaim(claims) {
  if (!claims) return false;
  return Object.keys(claims).length > 0;
}

async function main() {
  const verbose = process.argv.includes('--verbose');
  initFirebase();
  const auth = admin.auth();
  const db = admin.firestore();

  console.log('▸ Récupération des users Firebase Auth…');
  const authUsers = await listAllAuthUsers(auth);
  console.log(`  ${authUsers.length} users Auth`);

  const uids = authUsers.map((u) => u.uid);
  const existenceByCol = {};
  for (const col of COLLECTIONS) {
    console.log(`▸ Check Firestore ${col}/{uid}…`);
    existenceByCol[col] = await batchedExistence(db, col, uids);
  }

  const technical = [];
  const anonymous = [];
  const socialAbandon = [];
  const passwordOrphan = [];
  const other = [];
  let normal = 0;

  for (const u of authUsers) {
    const foundIn = COLLECTIONS.filter((c) => existenceByCol[c].get(u.uid));
    if (foundIn.length > 0) {
      normal++;
      continue;
    }
    const providers = u.providerData.map((p) => p.providerId);
    const row = {
      uid: u.uid,
      email: u.email || '-',
      displayName: u.displayName || '-',
      phone: u.phoneNumber || '-',
      providers: providers.join(',') || '-',
      createdAt: u.metadata.creationTime || '-',
      lastSignIn: u.metadata.lastSignInTime || '-',
      claims: u.customClaims || {},
    };
    if (hasAnyClaim(u.customClaims)) {
      technical.push(row);
    } else if (providers.length === 0) {
      anonymous.push(row);
    } else if (providers.includes('password') && u.email) {
      passwordOrphan.push(row);
    } else if (providers.some((p) => ['facebook.com', 'google.com', 'apple.com'].includes(p))) {
      socialAbandon.push(row);
    } else {
      other.push(row);
    }
  }

  const fmtRow = (r) => {
    const claims = Object.keys(r.claims).length ? JSON.stringify(r.claims) : '(aucun)';
    return [
      `  uid         : ${r.uid}`,
      `  email       : ${r.email}`,
      `  displayName : ${r.displayName}`,
      `  phone       : ${r.phone}`,
      `  providers   : ${r.providers}`,
      `  createdAt   : ${r.createdAt}`,
      `  lastSignIn  : ${r.lastSignIn}`,
      `  claims      : ${claims}`,
    ].join('\n');
  };

  console.log('');
  console.log('━'.repeat(64));
  console.log('RÉCAP');
  console.log('━'.repeat(64));
  console.log(`Auth users total          : ${authUsers.length}`);
  console.log(`  ✓ avec doc Firestore    : ${normal}`);
  console.log(`  ⚙ technique (claims)    : ${technical.length}`);
  console.log(`  👻 anonyme (guest)      : ${anonymous.length}`);
  console.log(`  🔓 social abandonné     : ${socialAbandon.length}`);
  console.log(`  ⚠  password orphan      : ${passwordOrphan.length}`);
  console.log(`  ? autre                 : ${other.length}`);
  console.log('');

  if (technical.length > 0) {
    console.log('━'.repeat(64));
    console.log(`⚙ TECHNIQUE (${technical.length}) — orphelins attendus`);
    console.log('━'.repeat(64));
    for (const r of technical) {
      const claims = Object.keys(r.claims).join(',');
      console.log(`  ${r.email.padEnd(42)} [${claims}]`);
    }
    console.log('');
  }

  if (passwordOrphan.length > 0) {
    console.log('━'.repeat(64));
    console.log(`⚠  PASSWORD ORPHAN (${passwordOrphan.length}) — signup email/mdp probablement raté`);
    console.log('    (Auth créé, pas de doc Firestore — même symptôme que admin@misyapp.com)');
    console.log('━'.repeat(64));
    const sorted = passwordOrphan.slice().sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
    if (verbose) {
      for (const r of sorted) {
        console.log(fmtRow(r));
        console.log('');
      }
    } else {
      for (const r of sorted.slice(0, 30)) {
        console.log(`  ${r.createdAt.padEnd(34)} ${r.email}`);
      }
      if (sorted.length > 30) console.log(`  … +${sorted.length - 30} autres (--verbose pour tout voir)`);
    }
    console.log('');
  }

  if (socialAbandon.length > 0 && verbose) {
    console.log('━'.repeat(64));
    console.log(`🔓 SOCIAL ABANDONNÉ (${socialAbandon.length})`);
    console.log('━'.repeat(64));
    for (const r of socialAbandon) {
      console.log(`  ${r.createdAt.padEnd(34)} ${r.providers.padEnd(14)} ${r.displayName}`);
    }
    console.log('');
  }

  if (other.length > 0) {
    console.log('━'.repeat(64));
    console.log(`? AUTRE (${other.length}) — providers inattendus`);
    console.log('━'.repeat(64));
    for (const r of other.slice(0, 20)) {
      console.log(`  ${r.providers.padEnd(20)} ${r.email || r.phone || r.uid}`);
    }
    console.log('');
  }

  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Erreur:', e);
  process.exit(1);
});
