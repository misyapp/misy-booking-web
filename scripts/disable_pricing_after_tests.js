const admin = require('firebase-admin');
const fs = require('fs');

async function disablePricingAfterTests() {
  try {
    console.log('🔒 Désactivation du nouveau système de pricing après les tests...');
    
    // Utiliser le service account key du projet
    const serviceAccountPath = './assets/json_files/service_account_credential.json';
    const serviceAccount = require('.' + serviceAccountPath);
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'misy-95336'
    });
    
    const db = admin.firestore();
    
    // Désactiver le nouveau système
    await db.collection('setting').doc('pricing_config_v2').update({
      enableNewPricingSystem: false
    });
    
    console.log('✅ Nouveau système de pricing DÉSACTIVÉ');
    console.log('🛡️ L\'application reste sur l\'ancien système en production');
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    process.exit(1);
  }
}

disablePricingAfterTests();