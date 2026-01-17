import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/scripts/init_popular_destinations_firestore.dart';
import 'package:rider_ride_hailing_app/services/popular_destinations_service.dart';

/// Widget de test temporaire pour initialiser et gérer les destinations Firestore
/// À supprimer après la mise en production
class AdminDestinationsTestWidget extends StatefulWidget {
  const AdminDestinationsTestWidget({super.key});

  @override
  State<AdminDestinationsTestWidget> createState() => _AdminDestinationsTestWidgetState();
}

class _AdminDestinationsTestWidgetState extends State<AdminDestinationsTestWidget> {
  bool _isLoading = false;
  String _lastResult = '';

  Future<void> _runAction(String actionName, Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _lastResult = 'Exécution de $actionName...';
    });

    try {
      await action();
      setState(() {
        _lastResult = '✅ $actionName réussi !';
      });
    } catch (e) {
      setState(() {
        _lastResult = '❌ Erreur $actionName: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔧 Admin - Test Destinations Firestore',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MyColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Boutons d'action
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runAction(
                    'Initialisation Firestore',
                    InitPopularDestinationsFirestore.initializeDestinations,
                  ),
                  icon: const Icon(Icons.upload),
                  label: const Text('Initialiser Firestore'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.horizonBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runAction(
                    'Liste des destinations',
                    InitPopularDestinationsFirestore.listDestinations,
                  ),
                  icon: const Icon(Icons.list),
                  label: const Text('Lister'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runAction(
                    'Vider cache local',
                    PopularDestinationsService.clearCache,
                  ),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Vider Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runAction(
                    'Rafraîchir destinations',
                    () async {
                      await PopularDestinationsService.refreshDestinations();
                    },
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rafraîchir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.horizonBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runAction(
                    'Suppression complète',
                    InitPopularDestinationsFirestore.clearAllDestinations,
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('⚠️ Tout Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Indicateur de chargement
            if (_isLoading)
              const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Opération en cours...'),
                ],
              ),
            
            // Résultat de la dernière action
            if (_lastResult.isNotEmpty && !_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastResult.startsWith('✅') 
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastResult.startsWith('✅') 
                        ? Colors.green 
                        : Colors.red,
                    width: 1,
                  ),
                ),
                child: Text(
                  _lastResult,
                  style: TextStyle(
                    color: _lastResult.startsWith('✅') 
                        ? Colors.green.shade800 
                        : Colors.red.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
            const SizedBox(height: 12),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📝 Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1. "Initialiser Firestore" - Créer la collection avec données de base\n'
                    '2. "Lister" - Voir les destinations actuelles\n'
                    '3. "Vider Cache" - Forcer le rechargement depuis Firestore\n'
                    '4. "Rafraîchir" - Mettre à jour le cache\n'
                    '5. "Tout Supprimer" - Reset complet (attention!)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}