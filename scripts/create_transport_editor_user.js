#!/usr/bin/env node
/**
 * Crée un compte Firebase Auth pour le consultant terrain transport,
 * avec le custom claim `transport_editor: true`.
 *
 * Usage :
 *   node scripts/create_transport_editor_user.js <email> [--password <pwd>] [--reset]
 *
 * Si --password n'est pas fourni, un mot de passe aléatoire est généré et
 * affiché UNE SEULE FOIS en sortie. À communiquer au consultant par un canal
 * sécurisé.
 *
 * Si le user existe déjà :
 *   - sans --reset : on set juste le claim (password inchangé)
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
    console.error('Usage: create_transport_editor_user.js <email> [--password <pwd>] [--reset]');
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
      displayName: 'Consultant Transport',
    });
    created = true;
  } else if (args.reset) {
    if (!password) password = genPassword();
    await auth.updateUser(user.uid, { password });
  }

  await auth.setCustomUserClaims(user.uid, { transport_editor: true });

  console.log('');
  console.log('━'.repeat(56));
  console.log(created ? '✅ Compte consultant créé' : '✅ Compte existant — claim set');
  console.log('━'.repeat(56));
  console.log(`email      : ${email}`);
  console.log(`uid        : ${user.uid}`);
  if (password) {
    console.log(`password   : ${password}`);
    console.log('(mot de passe visible UNE SEULE FOIS — à communiquer maintenant)');
  } else {
    console.log('password   : (inchangé — ajouter --reset pour en générer un nouveau)');
  }
  console.log('claim      : transport_editor = true');
  console.log('');
  console.log('Le consultant doit se déconnecter/reconnecter pour rafraîchir son ID token.');
  console.log('');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Erreur:', e.message);
  process.exit(1);
});
