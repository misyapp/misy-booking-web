const admin = require('firebase-admin');
const fs = require('fs');

async function enablePricingForTests() {
  try {
    console.log('🔥 Activation temporaire du nouveau système de pricing pour les tests...');
    
    // Utiliser le service account key du projet
    const serviceAccountPath = './assets/json_files/service_account_credential.json';
    const serviceAccount = require('.' + serviceAccountPath);
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'misy-95336'
    });
    
    const db = admin.firestore();
    
    // Activer le nouveau système temporairement
    await db.collection('setting').doc('pricing_config_v2').update({
      enableNewPricingSystem: true
    });
    
    console.log('✅ Nouveau système de pricing ACTIVÉ pour les tests');
    console.log('⚠️ N\'oubliez pas de le désactiver après les tests !');
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    process.exit(1);
  }
}

enablePricingForTests();