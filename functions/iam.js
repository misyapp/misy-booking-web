/**
 * IAM Transport — gestion des comptes `transport_editor` / `transport_admin`.
 *
 * 5 fonctions callable (v2), toutes gardées par le claim `transport_admin`.
 *
 *   iamListTransportUsers         liste paginée des users avec au moins un claim
 *   iamCreateTransportUser        crée user + claims, retourne password généré
 *   iamSetTransportClaims         toggle editor/admin sur user existant
 *   iamResetTransportPassword     génère un nouveau mot de passe temporaire
 *   iamDeleteTransportUser        supprime le user Auth (pas soi-même)
 *
 * Les mots de passe générés sont visibles UNE SEULE FOIS dans la réponse
 * et ne sont jamais stockés en clair côté serveur.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");

const PASSWORD_ALPHABET =
  "abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789";
const PASSWORD_LENGTH = 18;

function generatePassword() {
  const bytes = crypto.randomBytes(PASSWORD_LENGTH);
  let out = "";
  for (let i = 0; i < PASSWORD_LENGTH; i++) {
    out += PASSWORD_ALPHABET[bytes[i] % PASSWORD_ALPHABET.length];
  }
  return out;
}

function assertAdmin(request) {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Connexion requise.");
  }
  if (auth.token.transport_admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Ce compte n'a pas le claim transport_admin."
    );
  }
  return auth;
}

function sanitizeRoles(data) {
  const editor = data.transport_editor === true;
  const adminFlag = data.transport_admin === true;
  return { editor, admin: adminFlag };
}

function userRecordToPayload(u) {
  const claims = u.customClaims || {};
  return {
    uid: u.uid,
    email: u.email || null,
    disabled: u.disabled === true,
    created_at: u.metadata?.creationTime || null,
    last_sign_in_at: u.metadata?.lastSignInTime || null,
    transport_editor: claims.transport_editor === true,
    transport_admin: claims.transport_admin === true,
  };
}

/* ─────────────────────────────────────────────────────────────── */

exports.iamListTransportUsers = onCall(async (request) => {
  assertAdmin(request);

  const result = [];
  let pageToken = undefined;
  let pages = 0;
  const MAX_PAGES = 20;

  do {
    const res = await admin.auth().listUsers(1000, pageToken);
    for (const u of res.users) {
      const claims = u.customClaims || {};
      if (claims.transport_editor === true || claims.transport_admin === true) {
        result.push(userRecordToPayload(u));
      }
    }
    pageToken = res.pageToken;
    pages++;
  } while (pageToken && pages < MAX_PAGES);

  result.sort((a, b) => (a.email || "").localeCompare(b.email || ""));
  return { users: result, count: result.length };
});

/* ─────────────────────────────────────────────────────────────── */

exports.iamCreateTransportUser = onCall(async (request) => {
  assertAdmin(request);
  const data = request.data || {};

  const email = typeof data.email === "string" ? data.email.trim() : "";
  if (!email || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "Email invalide.");
  }
  const { editor, admin: adminFlag } = sanitizeRoles(data);
  if (!editor && !adminFlag) {
    throw new HttpsError(
      "invalid-argument",
      "Au moins un rôle requis (editor ou admin)."
    );
  }

  const explicitPassword =
    typeof data.password === "string" && data.password.length >= 8
      ? data.password
      : null;
  const password = explicitPassword || generatePassword();

  let userRecord;
  try {
    userRecord = await admin.auth().createUser({ email, password });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "Un compte existe déjà avec cet email. Utilise « Reset password » ou « Modifier rôles »."
      );
    }
    logger.error("iamCreateTransportUser createUser failed", e);
    throw new HttpsError("internal", e.message || "Création échouée.");
  }

  const claims = {};
  if (editor) claims.transport_editor = true;
  if (adminFlag) claims.transport_admin = true;
  await admin.auth().setCustomUserClaims(userRecord.uid, claims);

  logger.info(
    `iam: user ${email} créé par ${request.auth.token.email} (editor=${editor}, admin=${adminFlag})`
  );

  return {
    uid: userRecord.uid,
    email: userRecord.email,
    password,
    generated_password: explicitPassword === null,
    transport_editor: editor,
    transport_admin: adminFlag,
  };
});

/* ─────────────────────────────────────────────────────────────── */

exports.iamSetTransportClaims = onCall(async (request) => {
  const auth = assertAdmin(request);
  const data = request.data || {};

  const uid = typeof data.uid === "string" ? data.uid : "";
  if (!uid) throw new HttpsError("invalid-argument", "uid requis.");
  const { editor, admin: adminFlag } = sanitizeRoles(data);

  if (!editor && !adminFlag) {
    throw new HttpsError(
      "invalid-argument",
      "Impossible de retirer les 2 rôles (utilise « Supprimer »)."
    );
  }

  if (uid === auth.uid && !adminFlag) {
    throw new HttpsError(
      "failed-precondition",
      "Tu ne peux pas retirer ton propre rôle transport_admin."
    );
  }

  const existing = await admin.auth().getUser(uid);
  const newClaims = { ...(existing.customClaims || {}) };
  delete newClaims.transport_editor;
  delete newClaims.transport_admin;
  if (editor) newClaims.transport_editor = true;
  if (adminFlag) newClaims.transport_admin = true;

  await admin.auth().setCustomUserClaims(uid, newClaims);

  logger.info(
    `iam: claims de ${existing.email} mis à jour par ${auth.token.email} (editor=${editor}, admin=${adminFlag})`
  );

  return {
    uid,
    transport_editor: editor,
    transport_admin: adminFlag,
  };
});

/* ─────────────────────────────────────────────────────────────── */

exports.iamResetTransportPassword = onCall(async (request) => {
  const auth = assertAdmin(request);
  const data = request.data || {};

  const uid = typeof data.uid === "string" ? data.uid : "";
  if (!uid) throw new HttpsError("invalid-argument", "uid requis.");

  const target = await admin.auth().getUser(uid);
  const claims = target.customClaims || {};
  if (claims.transport_editor !== true && claims.transport_admin !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Ce compte n'est pas un compte transport — refus par sécurité."
    );
  }

  const password = generatePassword();
  await admin.auth().updateUser(uid, { password });

  logger.info(
    `iam: password reset pour ${target.email} par ${auth.token.email}`
  );

  return { uid, email: target.email, password };
});

/* ─────────────────────────────────────────────────────────────── */

exports.iamDeleteTransportUser = onCall(async (request) => {
  const auth = assertAdmin(request);
  const data = request.data || {};

  const uid = typeof data.uid === "string" ? data.uid : "";
  if (!uid) throw new HttpsError("invalid-argument", "uid requis.");

  if (uid === auth.uid) {
    throw new HttpsError(
      "failed-precondition",
      "Tu ne peux pas supprimer ton propre compte."
    );
  }

  const target = await admin.auth().getUser(uid);
  const claims = target.customClaims || {};
  if (claims.transport_editor !== true && claims.transport_admin !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Ce compte n'est pas un compte transport — refus par sécurité."
    );
  }

  await admin.auth().deleteUser(uid);

  logger.info(
    `iam: user ${target.email} supprimé par ${auth.token.email}`
  );

  return { uid, email: target.email, deleted: true };
});
