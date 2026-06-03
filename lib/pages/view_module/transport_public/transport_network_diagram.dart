import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/models/schematic_plan.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
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
  late final Future<SchematicPlan> _planFuture = _load();

  Future<SchematicPlan> _load() async {
    final url = Uri.base.resolve('transport_schema/${widget.planFile}');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} pour ${widget.planFile}');
    }
    return SchematicPlan.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  void _openCentre() {
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
          return SchematicMapView(
            plan: snap.data!,
            showCentreRect: !widget.isCentre,
            centreLabel: TransitStrings.t('network.centre', locale),
            onCentreTap: _openCentre,
          );
        },
      ),
    );
  }
}
