// LECTURE SEULE — vérifie l'état post-correction.
const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.resolve(
  __dirname, '../assets/json_files/service_account_credential.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const ID = 'SVhSUo74bK3Kggyp5wcZ';
const ts = (v) => (v && v.toDate ? v.toDate().toISOString() : String(v));
(async () => {
  const cancelled = await db.collection('cancelledBooking').doc(ID).get();
  const hist = await db.collection('bookingHistory').doc(ID).get();
  console.log(`cancelledBooking/${ID} exists: ${cancelled.exists}`);
  console.log(`bookingHistory/${ID}  exists: ${hist.exists}`);
  if (hist.exists) {
    const d = hist.data();
    console.log('\n--- bookingHistory doc ---');
    for (const k of ['status','ride_status','startedTime','reachedTime','endTime',
      'total_distance','cancelledBy','reason','ride_price_to_pay','ride_driver_earning',
      'ride_price_commission','paymentMethod']) {
      console.log(`  ${k} = ${ts(d[k])}`);
    }
    console.log('  manualCorrection =', JSON.stringify(d.manualCorrection));
  }
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
