#!/usr/bin/env node
/**
 * Crée un compte Firebase Auth pour l'admin transport (review / publication),
 * avec les custom claims `transport_admin: true` ET `transport_editor: true`
 * (l'admin hérite des capacités editor pour pouvoir accéder au wizard si besoin).
 *
 * Usage :
 *   node scripts/create_transport_admin_user.js <email> [--password <pwd>] [--reset]
 *
 * Si --password n'est pas fourni, un mot de passe aléatoire est généré et
 * affiché UNE SEULE FOIS en sortie. À communiquer à l'admin par un canal
 * sécurisé.
 *
 * Si le user existe déjà :
 *   - sans --reset : on set juste les claims (password inchangé)
 *   - avec --reset : on remet un nouveau password
 */

const admin = require('firebase-admin');
const crypto = require('crypto');
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

function genPassword() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  const bytes = crypto.randomBytes(16);
  let out = '';
  for (const b of bytes) out += alphabet[b % alphabet.length];
  return out;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const email = args._[0];
  if (!email) {
    console.error('Usage: create_transport_admin_user.js <email> [--password <pwd>] [--reset]');
    process.exit(1);
  }

  initFirebase();
  const auth = admin.auth();

  let user;
  let password = args.password || null;
  let created = false;

  try {
    user = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }

  if (!user) {
    if (!password) password = genPassword();
    user = await auth.createUser({
      email,
      password,
      emailVerified: true,
      displayName: 'Admin Transport',
    });
    created = true;
  } else if (args.reset) {
    if (!password) password = genPassword();
    await auth.updateUser(user.uid, { password });
  }

  // Admin = editor + admin (accès cumulatif)
  await auth.setCustomUserClaims(user.uid, {
    transport_admin: true,
    transport_editor: true,
  });

  console.log('');
  console.log('━'.repeat(56));
  console.log(created ? '✅ Compte admin créé' : '✅ Compte existant — claims set');
  console.log('━'.repeat(56));
  console.log(`email      : ${email}`);
  console.log(`uid        : ${user.uid}`);
  if (password) {
    console.log(`password   : ${password}`);
    console.log('(mot de passe visible UNE SEULE FOIS — à communiquer maintenant)');
  } else {
    console.log('password   : (inchangé — ajouter --reset pour en générer un nouveau)');
  }
  console.log('claims     : transport_admin = true, transport_editor = true');
  console.log('');
  console.log('L\'admin doit se déconnecter/reconnecter pour rafraîchir son ID token.');
  console.log('');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Erreur:', e.message);
  process.exit(1);
});
