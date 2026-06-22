// Régularise une course faite HORS-APP mais enregistrée comme ANNULÉE :
// la passe en TERMINÉE et la déplace de cancelledBooking → bookingHistory
// (collection canonique des courses terminées : sinon stats/dashboard ne la
// comptent pas, et l'espace compte la ré-affiche comme annulée via cancelledBy).
//
// Cas d'usage typique : le client a saisi un point de prise en charge erroné,
// le chauffeur n'a pas pu démarrer dans l'app et a fait la course hors-app.
// La commission reste celle déjà calculée dans le doc (souvent 0 si la zone
// est à 0%) — on ne recalcule rien.
//
// SÉCURITÉ : DRY-RUN par défaut (n'écrit RIEN). Garde-fous : la source doit
// exister dans cancelledBooking et la cible NE DOIT PAS déjà exister dans
// bookingHistory (pas d'écrasement). Écriture atomique (batch).
//
// Usage :
//   node scripts/fix_booking_to_completed.js <docId>            # dry-run
//   node scripts/fix_booking_to_completed.js <docId> --apply    # exécute
//   node scripts/fix_booking_to_completed.js <docId> --note "…" --apply
const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.resolve(
  __dirname, '../assets/json_files/service_account_credential.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

const args = process.argv.slice(2);
const APPLY = args.includes('--apply');
const TARGET_ID = args.find((a) => !a.startsWith('--'));
const noteIdx = args.indexOf('--note');
const NOTE = noteIdx !== -1 ? args[noteIdx + 1] : 'Course effectuée hors-app — régularisée en terminée.';

if (!TARGET_ID) {
  console.error('Usage: node scripts/fix_booking_to_completed.js <docId> [--note "…"] [--apply]');
  process.exit(1);
}

(async () => {
  const srcRef = db.collection('cancelledBooking').doc(TARGET_ID);
  const snap = await srcRef.get();
  if (!snap.exists) {
    console.error(`❌ cancelledBooking/${TARGET_ID} introuvable. Abandon.`);
    process.exit(1);
  }
  if (await db.collection('bookingHistory').doc(TARGET_ID).get().then((d) => d.exists)) {
    console.error(`❌ bookingHistory/${TARGET_ID} existe déjà. Abandon (pas d'écrasement).`);
    process.exit(1);
  }
  const data = snap.data();

  // Horodatage estimé : départ = heure programmée (ou requestTime), fin = +eta.
  const baseTs = data.scheduleTime instanceof Timestamp
    ? data.scheduleTime
    : (data.requestTime instanceof Timestamp ? data.requestTime : Timestamp.now());
  const startedTs = baseTs;
  const eta = Number(data.etaMinutes) || 30;
  const endTs = Timestamp.fromMillis(baseTs.toMillis() + eta * 60 * 1000);

  const completed = {
    ...data,
    status: 5, // RIDE_COMPLETE
    ride_status: 'Completed',
    startRide: true,
    startedTime: startedTs,
    reachedTime: startedTs,
    endTime: endTs,
    total_distance: data.total_distance || String(data.distance_in_km_approx || ''),
    // Nettoyage des marqueurs d'annulation (sinon recompté/affiché annulé) :
    cancelledBy: '',
    cancelledByUserId: '',
    reason: '',
    ride_cancelled_by: '',
    manualCorrection: {
      by: 'admin',
      at: FieldValue.serverTimestamp(),
      fromStatus: data.status,
      fromCollection: 'cancelledBooking',
      note: NOTE,
    },
  };

  console.log('===== PLAN =====');
  console.log(`Source : cancelledBooking/${TARGET_ID} (status ${data.status})`);
  console.log(`Cible  : bookingHistory/${TARGET_ID} (status 5 / Completed)`);
  console.log(`Passager(requestBy)=${data.requestBy}  Chauffeur(acceptedBy)=${data.acceptedBy}`);
  console.log(`Trajet : ${data.pickAddress}  →  ${data.dropAddress}`);
  console.log(`Prix=${data.ride_price_to_pay}  Gain=${data.ride_driver_earning}  Commission=${data.ride_price_commission}  ${data.paymentMethod}`);
  console.log('\nChamps modifiés :');
  console.log(`  status        : ${data.status} → 5`);
  console.log(`  ride_status   : ${data.ride_status} → Completed`);
  console.log(`  startedTime   : ${tsStr(data.startedTime)} → ${startedTs.toDate().toISOString()}`);
  console.log(`  endTime       : ${tsStr(data.endTime)} → ${endTs.toDate().toISOString()} (estimé, +${eta}min)`);
  console.log(`  total_distance: ${data.total_distance ?? '(absent)'} → ${completed.total_distance}`);
  console.log(`  cancelledBy   : ${data.cancelledBy} → "" ; reason → ""`);
  console.log(`  + manualCorrection { note: "${NOTE}" }`);
  console.log('\nPuis : suppression de cancelledBooking/' + TARGET_ID);

  if (!APPLY) {
    console.log('\n🟡 DRY-RUN — aucune écriture. Relancer avec --apply pour exécuter.');
    process.exit(0);
  }

  const batch = db.batch();
  batch.set(db.collection('bookingHistory').doc(TARGET_ID), completed);
  batch.delete(srcRef);
  await batch.commit();
  console.log('\n✅ APPLIQUÉ : course régularisée en terminée et migrée vers bookingHistory.');
  process.exit(0);
})().catch((e) => { console.error('ERREUR:', e); process.exit(1); });

function tsStr(v) {
  return v && v.toDate ? v.toDate().toISOString() : String(v);
}
