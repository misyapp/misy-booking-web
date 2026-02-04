import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/scripts/regenerate_driver_invoices_2025.dart';

/// Page pour régénérer TOUTES les factures driver 2025 avec TVA 0%
class TestInvoiceRegenerationPage extends StatefulWidget {
  const TestInvoiceRegenerationPage({Key? key}) : super(key: key);

  @override
  State<TestInvoiceRegenerationPage> createState() => _TestInvoiceRegenerationPageState();
}

class _TestInvoiceRegenerationPageState extends State<TestInvoiceRegenerationPage> {
  bool _isRunning = false;
  bool _isDryRun = true;
  final List<String> _logs = [];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    // Lancer automatiquement la régénération au démarrage
    Future.delayed(const Duration(seconds: 2), () {
      _startRegeneration();
    });
  }

  Future<void> _countInvoices() async {
    try {
      final bookings = await RegenerateDriverInvoices2025.listAffectedBookings();
      setState(() {
        _totalCount = bookings.length;
        _logs.add('📊 ${bookings.length} factures driver 2025 à régénérer');
      });
    } catch (e) {
      setState(() => _logs.add('❌ Erreur comptage: $e'));
    }
  }

  Future<void> _startRegeneration() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _logs.clear();
      _logs.add(_isDryRun
          ? '🔍 MODE TEST - Aucune modification ne sera effectuée'
          : '🚀 RÉGÉNÉRATION RÉELLE EN COURS...');
    });

    try {
      await RegenerateDriverInvoices2025.regenerateAll(
        dryRun: _isDryRun,
        onProgress: (message) {
          setState(() => _logs.add(message));
        },
      );
    } catch (e) {
      setState(() => _logs.add('❌ ERREUR: $e'));
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Régénération Factures 2025 - TVA 0%'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Correction TVA Factures Driver',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Ce script va régénérer toutes les factures driver 2025 avec:'),
                    const Text('• TVA 0% (au lieu de 20%)'),
                    const Text('• Mention: "Exonéré de TVA - Régime de l\'impôt synthétique"'),
                    const SizedBox(height: 8),
                    Text(
                      'Total: $_totalCount factures à traiter',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mode switch
            Row(
              children: [
                const Text('Mode: '),
                Switch(
                  value: !_isDryRun,
                  onChanged: _isRunning ? null : (value) {
                    setState(() => _isDryRun = !value);
                  },
                  activeColor: Colors.red,
                ),
                Text(
                  _isDryRun ? 'TEST (simulation)' : 'RÉEL (modification)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDryRun ? Colors.blue : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _startRegeneration,
                icon: _isRunning
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, size: 32),
                label: Text(
                  _isRunning
                      ? 'Régénération en cours...'
                      : _isDryRun
                          ? 'LANCER TEST (simulation)'
                          : 'RÉGÉNÉRER TOUTES LES FACTURES',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDryRun ? Colors.blue : Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logs
            const Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logs[index],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
