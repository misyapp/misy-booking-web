import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/network_diagram_layout.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';
import 'package:rider_ride_hailing_app/widget/transport/network_diagram_painter.dart';

/// Écran plein-page qui affiche le diagramme schématique du réseau
/// taxi-be d'Antananarivo, à la manière d'un plan tramway. Pan/zoom via
/// [InteractiveViewer], rendu via [NetworkDiagramPainter].
///
/// Le layout est calculé une fois au montage à partir du
/// [PublicTransportService] déjà chargé. Si jamais le service n'est pas
/// encore prêt (cas où l'utilisateur ouvre directement la page sans
/// passer par le mode public), on déclenche `ensureLoaded` puis on
/// recalcule.
class TransportNetworkDiagramScreen extends StatefulWidget {
  const TransportNetworkDiagramScreen({super.key});

  @override
  State<TransportNetworkDiagramScreen> createState() =>
      _TransportNetworkDiagramScreenState();
}

class _TransportNetworkDiagramScreenState
    extends State<TransportNetworkDiagramScreen> {
  // Taille du canvas logique du diagramme. Choisie large pour donner de
  // l'espace aux 40 lignes — l'InteractiveViewer pan/zoom permet de
  // naviguer dedans.
  static const Size _canvasSize = Size(2400, 1800);

  late Future<NetworkDiagramLayout> _layoutFuture;

  @override
  void initState() {
    super.initState();
    _layoutFuture = _ensureLayout();
  }

  Future<NetworkDiagramLayout> _ensureLayout() async {
    final svc = PublicTransportService.instance;
    await svc.ensureLoaded();
    return NetworkDiagramLayout.compute(svc, targetSize: _canvasSize);
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
      body: FutureBuilder<NetworkDiagramLayout>(
        future: _layoutFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  TransitStrings.t('state.error', locale),
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final layout = snap.data!;
          return InteractiveViewer(
            minScale: 0.3,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(200),
            constrained: false,
            child: SizedBox(
              width: layout.canvasSize.width,
              height: layout.canvasSize.height,
              child: CustomPaint(
                painter: NetworkDiagramPainter(layout: layout),
                size: layout.canvasSize,
              ),
            ),
          );
        },
      ),
    );
  }
}
