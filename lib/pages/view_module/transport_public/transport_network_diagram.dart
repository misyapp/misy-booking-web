import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/models/schematic_plan.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/widget/transport/schematic_legend.dart';
import 'package:rider_ride_hailing_app/widget/transport/schematic_map_view.dart';

/// Écran plein-page : plan SCHÉMATIQUE octilinéaire du réseau taxi-be
/// d'Antananarivo, façon plan de métro (CTS).
///
/// La mise en page est PRÉ-CALCULÉE hors-ligne par la chaîne LOOM puis exportée
/// en JSON par `tools/schema/octi2json.py` (cf. `web/transport_schema/*.json`).
/// Le rendu est fait par [SchematicMapView] (CustomPainter) avec ZOOM SÉMANTIQUE
/// : au zoom, seules les positions s'écartent ; police des labels et largeur des
/// traits restent constantes ; les noms d'arrêts apparaissent progressivement.
///
/// DEUX niveaux : plan GLOBAL (`misy_octilineaire.json`, avec carré « centre-
/// ville » cliquable) + plan CENTRE (`misy_octilineaire_centre.json`).
class TransportNetworkDiagramScreen extends StatefulWidget {
  final String planFile;
  final bool isCentre;

  const TransportNetworkDiagramScreen({
    super.key,
    this.planFile = 'misy_octilineaire.json',
    this.isCentre = false,
  });

  @override
  State<TransportNetworkDiagramScreen> createState() =>
      _TransportNetworkDiagramScreenState();
}

class _TransportNetworkDiagramScreenState
    extends State<TransportNetworkDiagramScreen> {
  /// Rendu CTS (cf. SchematicMapView.kCts) : on charge alors les artefacts
  /// `misy_cts*.json` ; 404/erreur → FALLBACK silencieux sur les fichiers
  /// historiques + rendu legacy (les anciens JSON n'ont pas `legendLines`,
  /// le painter v1 reste choisi par le flag — garde-fou intégral).
  static const bool _kCts = bool.fromEnvironment('SCHEMATIC_CTS');

  late final Future<SchematicPlan> _planFuture = _load();

  String get _ctsPlanFile =>
      widget.planFile.replaceFirst('misy_octilineaire', 'misy_cts');

  Future<SchematicPlan> _fetch(String file) async {
    final url = Uri.base.resolve('transport_schema/$file');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} pour $file');
    }
    return SchematicPlan.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SchematicPlan> _load() async {
    if (_kCts) {
      try {
        return await _fetch(_ctsPlanFile);
      } catch (_) {
        // artefacts CTS absents → fichiers historiques (fallback)
      }
    }
    return _fetch(widget.planFile);
  }

  void _openCentre() {
    // Toujours le nom legacy : l'écran enfant refait lui-même l'essai
    // CTS (misy_cts_centre.json) avec le même fallback.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const TransportNetworkDiagramScreen(
        planFile: 'misy_octilineaire_centre.json',
        isCentre: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D3557),
        elevation: 1,
        title: Text(
          TransitStrings.t(
              widget.isCentre ? 'network.centre.title' : 'network.title',
              locale),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D3557),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: TransitStrings.t('network.close', locale),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<SchematicPlan>(
        future: _planFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8194A8))),
            ));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final plan = snap.data!;
          return Stack(children: [
            SchematicMapView(
              plan: plan,
              showCentreRect: !widget.isCentre,
              centreLabel: TransitStrings.t('network.centre', locale),
              onCentreTap: _openCentre,
            ),
            // Légende générée (mode CTS uniquement : legendLines présent)
            if (plan.legendLines != null && plan.legendLines!.isNotEmpty)
              Positioned(
                left: 12,
                bottom: 16,
                child: SchematicLegend(lines: plan.legendLines!),
              ),
          ]);
        },
      ),
    );
  }
}
