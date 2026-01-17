import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pricing/pricing_config_v2.dart';
import '../../services/pricing/pricing_config_service.dart';

/// Écran admin temporaire pour importer la configuration de pricing
/// 
/// ⚠️ À supprimer après import réussi !
class PricingConfigImportScreen extends StatefulWidget {
  @override
  _PricingConfigImportScreenState createState() => _PricingConfigImportScreenState();
}

class _PricingConfigImportScreenState extends State<PricingConfigImportScreen> {
  bool _isImporting = false;
  String _status = '';
  PricingConfigV2? _importedConfig;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import Pricing Config'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ ADMIN UNIQUEMENT', 
                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    SizedBox(height: 8),
                    Text('Ce script importe la configuration Misy 2.0 dans Firestore.'),
                    Text('✅ enableNewPricingSystem sera mis à FALSE par défaut.'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            Center(
              child: ElevatedButton(
                onPressed: _isImporting ? null : _importConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: _isImporting 
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)),
                          SizedBox(width: 16),
                          Text('Import en cours...'),
                        ],
                      )
                    : Text('🚀 IMPORTER LA CONFIG', style: TextStyle(fontSize: 16)),
              ),
            ),
            
            SizedBox(height: 24),
            
            if (_status.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(_status),
                    ],
                  ),
                ),
              ),
            
            if (_importedConfig != null)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Configuration importée:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(_importedConfig!.summary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _importConfig() async {
    setState(() {
      _isImporting = true;
      _status = 'Création de la configuration par défaut...';
    });
    
    try {
      // 1. Créer la config par défaut
      final config = PricingConfigV2.defaultConfig();
      
      setState(() {
        _status = 'Import dans Firestore (setting/pricing_config_v2)...';
      });
      
      // 2. Importer dans Firestore
      await FirebaseFirestore.instance
          .collection('setting')
          .doc('pricing_config_v2')
          .set(config.toJson());
      
      setState(() {
        _status = 'Vérification de l\'import...';
      });
      
      // 3. Vérifier l'import
      final doc = await FirebaseFirestore.instance
          .collection('setting')
          .doc('pricing_config_v2')
          .get();
      
      if (doc.exists) {
        final importedConfig = PricingConfigV2.fromJson(doc.data()!);
        
        setState(() {
          _isImporting = false;
          _importedConfig = importedConfig;
          _status = '✅ SUCCESS !\n\n'
                   '📍 Document créé: setting/pricing_config_v2\n'
                   '🔒 Système désactivé: ${!importedConfig.enableNewPricingSystem}\n'
                   '📋 ${importedConfig.supportedCategories.length} catégories configurées\n'
                   '⏰ ${importedConfig.trafficPeriods.length} créneaux d\'embouteillages\n\n'
                   '🎯 Le système est prêt pour les tests !';
        });
        
        // Vider le cache pour forcer le rechargement
        await PricingConfigService.clearCache();
        
      } else {
        throw Exception('Document non trouvé après création');
      }
      
    } catch (e) {
      setState(() {
        _isImporting = false;
        _status = '❌ ERREUR: $e\n\n'
                 '💡 Vérifications:\n'
                 '- Connexion Firebase OK ?\n'
                 '- Permissions Firestore OK ?\n'
                 '- Collection "setting" existe ?';
      });
    }
  }
}