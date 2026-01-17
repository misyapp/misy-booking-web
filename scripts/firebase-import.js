const admin = require('firebase-admin');
const fs = require('fs');

// Configuration Pricing Misy 2.0
const pricingConfig = {
  version: "2.0",
  enableNewPricingSystem: false,
  floorPrices: {
    taxi_moto: 6000,
    classic: 8000,
    confort: 11000,
    "4x4": 13000,
    van: 15000
  },
  pricePerKm: {
    taxi_moto: 2000,
    classic: 2750,
    confort: 3850,
    "4x4": 4500,
    van: 5000
  },
  floorPriceThreshold: 3.0,
  trafficMultiplier: 1.4,
  trafficPeriods: [
    {
      startTime: "07:00",
      endTime: "09:59",
      daysOfWeek: [1, 2, 3, 4, 5]
    },
    {
      startTime: "16:00",
      endTime: "18:59",
      daysOfWeek: [1, 2, 3, 4, 5]
    }
  ],
  longTripThreshold: 15.0,
  longTripMultiplier: 1.2,
  reservationSurcharge: {
    taxi_moto: 3600,
    classic: 5000,
    confort: 7000,
    "4x4": 8200,
    van: 9100
  },
  reservationAdvanceMinutes: 10,
  enableRounding: true,
  roundingStep: 500
};

async function importPricingConfig() {
  try {
    console.log('🔥 Initialisation Firebase Admin...');
    
    // Utiliser le service account key du projet
    const serviceAccountPath = './assets/json_files/service_account_credential.json';
    
    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require('.' + serviceAccountPath);
      console.log(`📋 Service account trouvé: ${serviceAccountPath}`);
      
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'misy-95336'
      });
    } else {
      throw new Error('Service account key non trouvé: ' + serviceAccountPath);
    }
    
    const db = admin.firestore();
    
    console.log('📍 Import dans collection "setting", document "pricing_config_v2"...');
    
    // Importer la configuration
    await db.collection('setting').doc('pricing_config_v2').set(pricingConfig);
    
    console.log('✅ Configuration importée avec succès !');
    
    // Vérifier l'import
    const doc = await db.collection('setting').doc('pricing_config_v2').get();
    
    if (doc.exists) {
      const data = doc.data();
      console.log('✅ Vérification OK - Document créé');
      console.log(`📊 Système activé: ${data.enableNewPricingSystem}`);
      console.log(`🏷️ Version: ${data.version}`);
      console.log(`🚗 Catégories: ${Object.keys(data.floorPrices).length}`);
      console.log(`⏰ Créneaux embouteillages: ${data.trafficPeriods.length}`);
    } else {
      console.log('❌ Erreur - Document non trouvé après import');
    }
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Erreur lors de l\'import:', error.message);
    console.log('\n💡 Solutions possibles:');
    console.log('1. Vérifier que le service account key existe');
    console.log('2. Vérifier les permissions Firestore');
    console.log('3. Vérifier la connexion Internet');
    console.log('4. Essayer: firebase login --reauth');
    
    process.exit(1);
  }
}

// Exécuter l'import
importPricingConfig();