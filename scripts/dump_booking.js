// LECTURE SEULE — dump complet du doc cible + une course terminée de réf,
// et vérifie la présence du docId dans les 3 collections. Ne modifie RIEN.
const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.resolve(
  __dirname, '../assets/json_files/service_account_credential.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const TARGET_ID = 'SVhSUo74bK3Kggyp5wcZ';

(async () => {
  // 1. Présence du docId dans chaque collection.
  for (const col of ['cancelledBooking', 'bookingHistory', 'bookingRequest']) {
    const doc = await db.collection(col).doc(TARGET_ID).get();
    console.log(`${col}/${TARGET_ID} exists: ${doc.exists}`);
  }

  // 2. Dump complet du doc cible (toutes les clés triées).
  const target = (await db.collection('cancelledBooking').doc(TARGET_ID).get()).data();
  console.log('\n===== DOC CIBLE (cancelledBooking) — TOUTES LES CLÉS =====');
  console.log(Object.keys(target).sort().join(', '));
  console.log('\n--- valeurs ---');
  for (const k of Object.keys(target).sort()) {
    let v = target[k];
    if (v && v.toDate) v = v.toDate().toISOString() + ' (Timestamp)';
    else if (typeof v === 'object') v = JSON.stringify(v);
    console.log(`${k} = ${v}`);
  }

  // 3. Schéma d'une course terminée de réf (status 5) du MÊME chauffeur.
  const driverId = target.acceptedBy;
  let ref;
  try {
    const qs = await db.collection('bookingHistory')
      .where('acceptedBy', '==', driverId)
      .where('status', '==', 5)
      .limit(1).get();
    if (!qs.empty) ref = qs.docs[0];
  } catch (e) { console.log('query ref err:', e.message); }
  if (!ref) {
    const qs = await db.collection('bookingHistory')
      .where('status', '==', 5).limit(1).get();
    if (!qs.empty) ref = qs.docs[0];
  }
  if (ref) {
    const r = ref.data();
    console.log(`\n===== COURSE TERMINÉE DE RÉF (bookingHistory/${ref.id}) =====`);
    console.log(Object.keys(r).sort().join(', '));
    console.log('\n--- champs financiers/statut de la réf ---');
    for (const k of ['status','ride_status','endTime','cancelledBy','cancelledAt',
      'commission','misy_commission','adminCommission','driver_earning','driverGain',
      'gain_chauffeur','ride_price_to_pay','vehicle_base_price','ride_bonus_price',
      'total_distance','paymentStatusSummary','isSchedule']) {
      let v = r[k];
      if (v && v.toDate) v = v.toDate().toISOString();
      else if (typeof v === 'object') v = JSON.stringify(v);
      if (v !== undefined) console.log(`${k} = ${v}`);
    }
  } else {
    console.log('\n(aucune course terminée de réf trouvée)');
  }
  console.log('\n(LECTURE SEULE — aucune écriture)');
  process.exit(0);
})().catch((e) => { console.error('ERREUR:', e); process.exit(1); });
