import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';

/// Écran plein-page : plan SCHÉMATIQUE octilinéaire du réseau taxi-be
/// d'Antananarivo, façon plan de métro.
///
/// Le schéma est PRÉ-CALCULÉ hors-ligne via la chaîne LOOM
/// (misy2loom.py | topo | loom | octi | transitmap) — cf. _tools/ — et servi
/// comme SVG statique sous `web/transport_schema/`. L'app ne fait que
/// l'afficher (téléchargé à l'ouverture de l'écran, pas dans le bundle initial)
/// avec pan/zoom via [InteractiveViewer]. Régénérer après maj des lignes =
/// relancer la chaîne LOOM et remplacer le SVG.
class TransportNetworkDiagramScreen extends StatelessWidget {
  const TransportNetworkDiagramScreen({super.key});

  // Même origine que l'app (book.misy.app) → URL relative résolue à l'exécution.
  static String get _svgUrl =>
      Uri.base.resolve('transport_schema/misy_octilineaire.svg').toString();

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
          TransitStrings.t('network.title', locale),
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
      body: InteractiveViewer(
        minScale: 0.3,
        maxScale: 8.0,
        boundaryMargin: const EdgeInsets.all(600),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.network(
              _svgUrl,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
