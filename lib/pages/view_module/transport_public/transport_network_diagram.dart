import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';

/// Écran plein-page : plan SCHÉMATIQUE octilinéaire du réseau taxi-be
/// d'Antananarivo, façon plan de métro.
///
/// Le schéma est PRÉ-CALCULÉ hors-ligne via la chaîne LOOM
/// (misy2loom.py | topo | loom | octi | transitmap | tier_style) — cf.
/// tools/schema/ — et servi comme SVG statique sous `web/transport_schema/`.
/// L'app ne fait que l'afficher avec pan/zoom via [InteractiveViewer].
///
/// DEUX niveaux (découpe par zone) :
///   • plan GLOBAL (`misy_octilineaire.svg`) — réseau entier ;
///   • plan CENTRE-VILLE (`misy_octilineaire_centre.svg`) — sous-réseau dense.
/// Sur le global, un RECTANGLE cliquable (position lue dans
/// `centre_hotspot.json`, calculé par hotspot.py) ouvre le plan centre.
///
/// Régénérer après maj des lignes = relancer `tools/schema/build_schema.sh`.
class TransportNetworkDiagramScreen extends StatefulWidget {
  /// Fichier SVG servi sous `transport_schema/`.
  final String svgFile;

  /// Plan centre-ville (pas de rectangle cliquable, simple fit).
  final bool isCentre;

  const TransportNetworkDiagramScreen({
    super.key,
    this.svgFile = 'misy_octilineaire.svg',
    this.isCentre = false,
  });

  @override
  State<TransportNetworkDiagramScreen> createState() =>
      _TransportNetworkDiagramScreenState();
}

class _Hotspot {
  final Size viewBox;
  final Rect rect;
  const _Hotspot(this.viewBox, this.rect);
}

class _TransportNetworkDiagramScreenState
    extends State<TransportNetworkDiagramScreen> {
  final TransformationController _tc = TransformationController();
  Future<_Hotspot?>? _hotspotFuture;
  bool _fitted = false;

  String get _svgUrl =>
      Uri.base.resolve('transport_schema/${widget.svgFile}').toString();

  @override
  void initState() {
    super.initState();
    if (!widget.isCentre) _hotspotFuture = _loadHotspot();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<_Hotspot?> _loadHotspot() async {
    try {
      final url = Uri.base.resolve('transport_schema/centre_hotspot.json');
      final res = await http.get(url);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final vb = (j['viewBox'] as List).map((e) => (e as num).toDouble()).toList();
      final r = (j['rect'] as List).map((e) => (e as num).toDouble()).toList();
      return _Hotspot(Size(vb[0], vb[1]), Rect.fromLTWH(r[0], r[1], r[2], r[3]));
    } catch (_) {
      return null;
    }
  }

  void _openCentre() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const TransportNetworkDiagramScreen(
        svgFile: 'misy_octilineaire_centre.svg',
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
      body: widget.isCentre ? _fitViewer() : _globalViewer(locale),
    );
  }

  /// Plan centre : simple fit + pan/zoom.
  Widget _fitViewer() => InteractiveViewer(
        minScale: 0.3,
        maxScale: 8.0,
        boundaryMargin: const EdgeInsets.all(600),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.network(_svgUrl,
                fit: BoxFit.contain, placeholderBuilder: _placeholder),
          ),
        ),
      );

  /// Plan global : SVG à la taille du viewBox + rectangle « centre-ville »
  /// cliquable, dans l'arbre de l'[InteractiveViewer] (le tap suit le zoom).
  Widget _globalViewer(AppLocale locale) => FutureBuilder<_Hotspot?>(
        future: _hotspotFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _placeholder(context);
          }
          final hs = snap.data;
          if (hs == null) return _fitViewer(); // pas de hotspot → fallback

          return LayoutBuilder(builder: (context, c) {
            if (!_fitted && c.maxWidth.isFinite && c.maxHeight.isFinite) {
              final scale = 0.96 *
                  (c.maxWidth / hs.viewBox.width <
                          c.maxHeight / hs.viewBox.height
                      ? c.maxWidth / hs.viewBox.width
                      : c.maxHeight / hs.viewBox.height);
              final dx = (c.maxWidth - hs.viewBox.width * scale) / 2;
              final dy = (c.maxHeight - hs.viewBox.height * scale) / 2;
              _tc.value = Matrix4.identity()
                ..translate(dx, dy)
                ..scale(scale);
              _fitted = true;
            }
            return InteractiveViewer(
              transformationController: _tc,
              constrained: false,
              minScale: 0.1,
              maxScale: 12.0,
              boundaryMargin: const EdgeInsets.all(2000),
              child: SizedBox(
                width: hs.viewBox.width,
                height: hs.viewBox.height,
                child: Stack(
                  children: [
                    SvgPicture.network(
                      _svgUrl,
                      width: hs.viewBox.width,
                      height: hs.viewBox.height,
                      fit: BoxFit.fill,
                      placeholderBuilder: _placeholder,
                    ),
                    Positioned.fromRect(
                      rect: hs.rect,
                      child: _hotspotBox(locale),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      );

  /// Le rectangle cliquable (dimensions en unités du viewBox SVG).
  Widget _hotspotBox(AppLocale locale) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openCentre,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x142563EB),
            border: Border.all(color: const Color(0xFF2563EB), width: 14),
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.all(34),
            padding:
                const EdgeInsets.symmetric(horizontal: 44, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(120),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 24)
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.zoom_in_map_rounded,
                    color: Colors.white, size: 84),
                const SizedBox(width: 20),
                Text(
                  TransitStrings.t('network.centre', locale),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 92,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _placeholder(BuildContext _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
}
