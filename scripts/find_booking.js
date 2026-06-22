// LECTURE SEULE — retrouve une course par téléphone / prix / date dans les
// collections bookingRequest, bookingHistory, cancelledBooking, et affiche
// les champs clés. Ne modifie RIEN.
//
// Usage : node scripts/find_booking.js
const admin = require('firebase-admin');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.resolve(
  __dirname,
  '../assets/json_files/service_account_credential.json',
);
const serviceAccount = require(SERVICE_ACCOUNT_PATH);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// Critères issus de la capture WhatsApp.
const DRIVER_PHONE_FRAG = '385476634'; // Eric Mamy
const PASSENGER_PHONE_FRAG = '336759442'; // andry tahiana
const PRICE_FRAG = '44500';

const COLLECTIONS = ['cancelledBooking', 'bookingHistory', 'bookingRequest'];

const s = (v) => (v == null ? '' : String(v));
const tsStr = (v) => {
  try {
    if (v && v.toDate) return v.toDate().toISOString();
  } catch (_) {}
  return s(v);
};

function matches(d) {
  const blob = JSON.stringify(d);
  return (
    blob.includes(DRIVER_PHONE_FRAG) ||
    blob.includes(PASSENGER_PHONE_FRAG) ||
    blob.includes(PRICE_FRAG)
  );
}

(async () => {
  for (const col of COLLECTIONS) {
    let snap;
    try {
      snap = await db
        .collection(col)
        .orderBy('requestTime', 'desc')
        .limit(400)
        .get();
    } catch (e) {
      // Pas de requestTime indexé sur cette collection → fallback brut.
      snap = await db.collection(col).limit(400).get();
    }
    const hits = [];
    snap.forEach((doc) => {
      const d = doc.data();
      if (matches(d)) hits.push({ id: doc.id, d });
    });
    console.log(`\n===== ${col} : ${hits.length} match(es) sur ${snap.size} lus =====`);
    for (const { id, d } of hits) {
      console.log('-'.repeat(70));
      console.log('docId        :', id);
      console.log('id (champ)   :', s(d.id));
      console.log('status       :', s(d.status));
      console.log('ride_status  :', s(d.ride_status));
      console.log('isSchedule   :', s(d.isSchedule));
      console.log('pickAddress  :', s(d.pickAddress));
      console.log('dropAddress  :', s(d.dropAddress));
      console.log('price_to_pay :', s(d.ride_price_to_pay));
      console.log('base_price   :', s(d.vehicle_base_price));
      console.log('bonus_price  :', s(d.ride_bonus_price));
      console.log('total_dist   :', s(d.total_distance));
      console.log('paymentMethod:', s(d.paymentMethod));
      console.log('acceptedBy   :', s(d.acceptedBy));
      console.log('requestBy    :', s(d.requestBy));
      console.log('cancelledBy  :', s(d.cancelledBy));
      console.log('cancelReason :', s(d.cancelReason));
      console.log('requestTime  :', tsStr(d.requestTime));
      console.log('scheduleTime :', tsStr(d.scheduleTime));
      console.log('endTime      :', tsStr(d.endTime));
      console.log('cancelledAt  :', tsStr(d.cancelledAt));
      console.log('commission   :', s(d.commission ?? d.misy_commission ?? d.adminCommission));
      console.log('driver_gain  :', s(d.driver_earning ?? d.driverGain ?? d.gain_chauffeur));
    }
  }
  console.log('\n(LECTURE SEULE — aucune écriture effectuée)');
  process.exit(0);
})().catch((e) => {
  console.error('ERREUR:', e);
  process.exit(1);
});
