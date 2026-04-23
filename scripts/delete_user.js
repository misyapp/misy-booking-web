#!/usr/bin/env node
/**
 * Supprime un utilisateur Firebase Auth par email.
 *
 * ATTENTION : destructif. Supprime le user Auth + custom claims. Les docs
 * Firestore éventuels ne sont PAS touchés (la recherche en cours ne renvoie
 * rien dans users/adminUsers/admins/drivers ; si tu ajoutes d'autres
 * collections, c'est à faire à la main).
 *
 * Usage :
 *   node scripts/delete_user.js <email> [--yes]
 *
 * Sans --yes, affiche juste le compte à supprimer sans rien faire (dry-run).
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

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
}

async function main() {
  const args = process.argv.slice(2);
  const email = args.find((a) => !a.startsWith('--'));
  const confirmed = args.includes('--yes');
  if (!email) {
    console.error('Usage: node scripts/delete_user.js <email> [--yes]');
    process.exit(1);
  }

  initFirebase();
  const auth = admin.auth();

  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      console.log(`ℹ  ${email} n'existe pas dans Firebase Auth — rien à faire.`);
      process.exit(0);
    }
    throw e;
  }

  console.log('');
  console.log('━'.repeat(56));
  console.log('Compte à supprimer :');
  console.log('━'.repeat(56));
  console.log(`  email        : ${email}`);
  console.log(`  uid          : ${user.uid}`);
  console.log(`  displayName  : ${user.displayName || '-'}`);
  console.log(`  createdAt    : ${user.metadata.creationTime}`);
  console.log(`  lastSignIn   : ${user.metadata.lastSignInTime}`);
  console.log(`  customClaims : ${JSON.stringify(user.customClaims || {})}`);
  console.log('');

  if (!confirmed) {
    console.log('⚠  Dry-run — relance avec --yes pour supprimer réellement.');
    process.exit(0);
  }

  await auth.deleteUser(user.uid);
  console.log('✅ Supprimé de Firebase Auth.');
  console.log('');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Erreur:', e);
  process.exit(1);
});
