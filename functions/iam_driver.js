/**
 * IAM Driver — gestion du custom claim `driver` sur les comptes chauffeur.
 *
 * Consommé par l'espace chauffeur web (beta.misy.app/chauffeurs/espace),
 * où auth.client.ts:assertDriver() lit le claim pour autoriser l'accès.
 *
 * 2 fonctions callable (v2), gardées par le claim `transport_admin` (même
 * pattern que iam.js qui gère transport_editor / transport_admin).
 *
 *   iamSetDriverClaim          toggle driver:true/false sur 1 UID
 *   iamBackfillDriverClaims    pose driver:true sur tous les UIDs qui ont
 *                              users/{uid}.vehicleData (heuristique driver)
 *
 * À lancer une seule fois pour la migration initiale, puis ponctuellement
 * via iamSetDriverClaim quand un nouveau chauffeur est onboardé. Idéalement,
 * le signup chauffeur dans driverapp poserait le claim directement (trigger
 * onCreate users/{uid} si vehicleData présent) — V2.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

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

/* ─────────────────────────────────────────────────────────────── */

exports.iamSetDriverClaim = onCall(async (request) => {
  const auth = assertAdmin(request);
  const data = request.data || {};

  const uid = typeof data.uid === "string" ? data.uid : "";
  if (!uid) throw new HttpsError("invalid-argument", "uid requis.");
  const value = data.driver === true;

  const target = await admin.auth().getUser(uid);
  const newClaims = { ...(target.customClaims || {}) };
  if (value) newClaims.driver = true;
  else delete newClaims.driver;

  await admin.auth().setCustomUserClaims(uid, newClaims);

  logger.info(
    `iam_driver: claim driver=${value} sur ${target.email || target.phoneNumber || uid} ` +
    `par ${auth.token.email || auth.uid}`
  );

  return { uid, driver: value };
});

/* ─────────────────────────────────────────────────────────────── */

exports.iamBackfillDriverClaims = onCall(
  { timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    const auth = assertAdmin(request);
    const data = request.data || {};
    const dryRun = data.dryRun !== false; // par défaut dry-run pour safety

    const db = admin.firestore();
    const stats = {
      scanned: 0,
      driverCandidates: 0,
      claimAdded: 0,
      claimAlreadySet: 0,
      claimSkipped: 0,
      errors: [],
    };

    // Pagination Firestore : 500 docs par page pour rester sous timeout.
    let lastDoc = null;
    let pageNum = 0;
    const MAX_PAGES = 50; // 25 000 users max — suffit largement

    do {
      let q = db.collection("users").orderBy("__name__").limit(500);
      if (lastDoc) q = q.startAfter(lastDoc);

      const snap = await q.get();
      if (snap.empty) break;

      for (const doc of snap.docs) {
        stats.scanned++;
        const d = doc.data() || {};
        const looksLikeDriver = Boolean(
          d.vehicleData || d.role === "driver" || d.driverId
        );
        if (!looksLikeDriver) continue;

        stats.driverCandidates++;

        let userRecord;
        try {
          userRecord = await admin.auth().getUser(doc.id);
        } catch (err) {
          // Doc Firestore sans user Auth correspondant — log et skip
          stats.errors.push({ uid: doc.id, error: "no-auth-user" });
          continue;
        }

        const claims = userRecord.customClaims || {};
        if (claims.driver === true) {
          stats.claimAlreadySet++;
          continue;
        }

        if (dryRun) {
          stats.claimSkipped++;
        } else {
          try {
            await admin.auth().setCustomUserClaims(doc.id, {
              ...claims,
              driver: true,
            });
            stats.claimAdded++;
          } catch (err) {
            stats.errors.push({ uid: doc.id, error: err.message });
          }
        }
      }

      lastDoc = snap.docs[snap.docs.length - 1];
      pageNum++;
    } while (lastDoc && pageNum < MAX_PAGES);

    logger.info(
      `iam_driver: backfill terminé par ${auth.token.email || auth.uid} ` +
      `(dryRun=${dryRun}, stats=${JSON.stringify(stats)})`
    );

    return { dryRun, ...stats };
  }
);
