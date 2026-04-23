#!/usr/bin/env node
/**
 * Diagnostic READ-ONLY d'un utilisateur Misy.
 *
 * Vérifie si un email existe dans Firebase Auth, et si son UID a bien un doc
 * correspondant dans les collections Firestore candidates (users, adminUsers,
 * admins, drivers). Aucune écriture, aucune suppression.
 *
 * Usage :
 *   node scripts/check_user.js <email>
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.resolve(
  __dirname,
  '../assets/json_files/service_account_credential.json',
);

const FIRESTORE_COLLECTIONS = ['users', 'adminUsers', 'admins', 'drivers'];

function initFirebase() {
  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ Clé de service introuvable: ${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
  }
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

function fmtDate(ms) {
  if (!ms) return '-';
  const d = new Date(Number(ms));
  return isNaN(d.getTime()) ? '-' : d.toISOString();
}

async function checkAuth(auth, email) {
  try {
    const user = await auth.getUserByEmail(email);
    return { found: true, user };
  } catch (e) {
    if (e.code === 'auth/user-not-found') return { found: false };
    throw e;
  }
}

async function checkFirestoreDoc(db, collection, uid) {
  try {
    const snap = await db.collection(collection).doc(uid).get();
    return { exists: snap.exists, data: snap.exists ? snap.data() : null };
  } catch (e) {
    return { exists: false, error: e.message };
  }
}

async function searchFirestoreByEmail(db, collection, email) {
  try {
    const qs = await db.collection(collection).where('email', '==', email).limit(5).get();
    return qs.docs.map((d) => ({ id: d.id, data: d.data() }));
  } catch (e) {
    return [];
  }
}

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error('Usage: node scripts/check_user.js <email>');
    process.exit(1);
  }

  initFirebase();
  const auth = admin.auth();
  const db = admin.firestore();

  console.log('');
  console.log('━'.repeat(64));
  console.log(`🔎 Diagnostic pour: ${email}`);
  console.log('━'.repeat(64));

  // 1. Firebase Auth
  const authRes = await checkAuth(auth, email);
  console.log('');
  console.log('▸ Firebase Auth');
  if (!authRes.found) {
    console.log('  ✗ non trouvé (email libre pour inscription)');
  } else {
    const u = authRes.user;
    console.log(`  ✓ uid          : ${u.uid}`);
    console.log(`    emailVerified: ${u.emailVerified}`);
    console.log(`    disabled     : ${u.disabled}`);
    console.log(`    displayName  : ${u.displayName || '-'}`);
    console.log(`    phoneNumber  : ${u.phoneNumber || '-'}`);
    console.log(`    createdAt    : ${fmtDate(u.metadata.creationTime && Date.parse(u.metadata.creationTime))}`);
    console.log(`    lastSignIn   : ${fmtDate(u.metadata.lastSignInTime && Date.parse(u.metadata.lastSignInTime))}`);
    console.log(`    providers    : ${u.providerData.map((p) => p.providerId).join(', ') || '-'}`);
    console.log(`    customClaims : ${JSON.stringify(u.customClaims || {})}`);
  }

  // 2. Firestore — doc par uid dans collections candidates
  if (authRes.found) {
    const uid = authRes.user.uid;
    console.log('');
    console.log(`▸ Firestore (doc id = uid ${uid})`);
    for (const col of FIRESTORE_COLLECTIONS) {
      const res = await checkFirestoreDoc(db, col, uid);
      if (res.exists) {
        const keys = Object.keys(res.data).slice(0, 12).join(', ');
        console.log(`  ✓ ${col}/${uid}`);
        console.log(`      champs : ${keys}${Object.keys(res.data).length > 12 ? ', …' : ''}`);
        if (res.data.isCustomer !== undefined) console.log(`      isCustomer   : ${res.data.isCustomer}`);
        if (res.data.is_customer !== undefined) console.log(`      is_customer  : ${res.data.is_customer}`);
        if (res.data.isDriver !== undefined) console.log(`      isDriver     : ${res.data.isDriver}`);
        if (res.data.is_driver !== undefined) console.log(`      is_driver    : ${res.data.is_driver}`);
        if (res.data.isSuperUser !== undefined) console.log(`      isSuperUser  : ${res.data.isSuperUser}`);
        if (res.data.role !== undefined) console.log(`      role         : ${res.data.role}`);
      } else {
        console.log(`  ✗ ${col}/${uid}`);
      }
    }
  }

  // 3. Firestore — fallback : recherche par email (au cas où uid mismatch)
  console.log('');
  console.log(`▸ Firestore (fallback : where email == ${email})`);
  for (const col of FIRESTORE_COLLECTIONS) {
    const hits = await searchFirestoreByEmail(db, col, email);
    if (hits.length === 0) {
      console.log(`  ✗ ${col} : 0 hit`);
    } else {
      console.log(`  ✓ ${col} : ${hits.length} hit(s)`);
      for (const h of hits) console.log(`      - id=${h.id}`);
    }
  }

  // 4. Verdict
  console.log('');
  console.log('━'.repeat(64));
  if (!authRes.found) {
    console.log('VERDICT : email totalement libre — inscription possible.');
  } else {
    const uid = authRes.user.uid;
    const results = await Promise.all(
      FIRESTORE_COLLECTIONS.map((c) => checkFirestoreDoc(db, c, uid)),
    );
    const collectionsWithDoc = FIRESTORE_COLLECTIONS.filter((_, i) => results[i].exists);
    if (collectionsWithDoc.length === 0) {
      console.log('VERDICT : ORPHELIN — user en Auth sans aucun doc Firestore connu.');
      console.log('          Options : (a) auth.deleteUser(uid) pour libérer l\'email,');
      console.log('                    (b) recréer un doc users/{uid} pour réparer.');
    } else {
      console.log(`VERDICT : user présent dans ${collectionsWithDoc.join(', ')}.`);
      console.log('          Inscription bloquée = comportement normal (email déjà utilisé).');
    }
  }
  console.log('━'.repeat(64));
  console.log('');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Erreur:', e);
  process.exit(1);
});
