import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/models/pricing/pricing_config_v2.dart';

/// Script pour importer la configuration de pricing v2 dans Firestore
/// 
/// Usage: dart run scripts/import_pricing_config.dart
void main() async {
  try {
    // Initialiser Firebase (assurez-vous que firebase_options.dart est configuré)
    await Firebase.initializeApp();
    
    print('🔥 Connexion à Firebase réussie');
    
    // Créer la configuration par défaut
    final config = PricingConfigV2.defaultConfig();
    
    print('📋 Configuration créée :');
    print(config.summary);
    
    // Importer dans Firestore
    await FirebaseFirestore.instance
        .collection('setting')
        .doc('pricing_config_v2')
        .set(config.toJson());
    
    print('✅ Configuration importée avec succès dans Firestore !');
    print('📍 Chemin: setting/pricing_config_v2');
    
    // Vérifier l'import
    final doc = await FirebaseFirestore.instance
        .collection('setting')
        .doc('pricing_config_v2')
        .get();
    
    if (doc.exists) {
      print('✅ Vérification OK - Document créé');
      final importedConfig = PricingConfigV2.fromJson(doc.data()!);
      print('📊 Système activé: ${importedConfig.enableNewPricingSystem}');
      print('🏷️ Version: ${importedConfig.version}');
    } else {
      print('❌ Erreur - Document non trouvé après import');
    }
    
  } catch (e) {
    print('❌ Erreur lors de l\'import: $e');
    print('💡 Assurez-vous que Firebase est configuré correctement');
  }
}