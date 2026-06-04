import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';

/// Fiche d'information d'un arrêt — overlay flottant ancré au pixel de l'arrêt
/// (au-dessus, ou en-dessous si trop près du haut), avec un petit pointeur
/// triangulaire vers le marker. Header épuré (icône + nom + nombre de lignes)
/// puis LISTE verticale scrollable des lignes desservantes (badge + nom),
/// chaque ligne tappable. Style premium calme (ink navy #1D3557).
class StopCard extends StatelessWidget {
  final String stopName;
  final LatLng position;
  final List<String> lineNumbers;
  final Offset? screenAnchor;
  final Size screenSize;
  final VoidCallback onClose;
  final ValueChanged<String>? onLineTap;

  const StopCard({
    super.key,
    required this.stopName,
    required this.position,
    required this.lineNumbers,
    required this.screenAnchor,
    required this.screenSize,
    required this.onClose,
    this.onLineTap,
  });

  static const Color _ink = Color(0xFF1D3557);
  static const double _cardWidth = 340;
  static const double _gap = 14; // espace entre marker et card
  static const double _arrowSize = 10;

  // Hauteurs logiques pour estimer la taille de la card (positionnement +
  // pointeur). La liste scrolle au-delà de [_maxCardHeight].
  static const double _headerH = 52;
  static const double _rowH = 38;
  static const double _vPad = 12; // padding vertical (haut = bas)

  @override
  Widget build(BuildContext context) {
    if (screenAnchor == null) return const SizedBox.shrink();
    final locale = context.watch<LocaleProvider>().locale;
    final svc = PublicTransportService.instance;
    final displayName = stopName.trim().isEmpty
        ? TransitStrings.t('stop.unnamed', locale)
        : stopName;
    final anchor = screenAnchor!;

    // Hauteur : header + liste (1 row par ligne), bornée à ~52% de l'écran.
    final maxCardH = (screenSize.height * 0.52).clamp(220.0, 460.0);
    final listNaturalH = lineNumbers.length * _rowH + 8;
    final naturalH = _headerH + _vPad * 2 + listNaturalH;
    final cardH = naturalH.clamp(120.0, maxCardH);
    final listH = cardH - _headerH - _vPad * 2;

    // Au-dessus du marker par défaut, en-dessous si on touche le haut.
    final placeAbove = anchor.dy >= cardH + _gap + 16;
    final cardTop =
        placeAbove ? anchor.dy - cardH - _gap : anchor.dy + _gap;
    final cardLeft = (anchor.dx - _cardWidth / 2)
        .clamp(8.0, screenSize.width - _cardWidth - 8.0);
    final arrowLeft = anchor.dx - cardLeft - _arrowSize;
    final arrowTop = placeAbove ? cardH - 1 : -_arrowSize * 2 + 1;

    return Stack(
      children: [
        Positioned(
          left: cardLeft,
          top: cardTop,
          width: _cardWidth,
          child: SizedBox(
            height: cardH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // PointerInterceptor : insère un élément DOM au-dessus de la
                // carte (platform view) → la molette/scroll sur la card scrolle
                // la liste au lieu de zoomer la carte Google Maps.
                PointerInterceptor(
                  child: Material(
                  color: Colors.white,
                  elevation: 14,
                  borderRadius: BorderRadius.circular(16),
                  shadowColor: Colors.black.withOpacity(0.20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context, locale, svc, displayName),
                      const Divider(height: 1, thickness: 1),
                      SizedBox(
                        height: listH,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: lineNumbers.length,
                          itemBuilder: (_, i) {
                            final ln = lineNumbers[i];
                            return _LineRow(
                              lineNumber: ln,
                              color: _colorFor(svc, ln),
                              displayName: svc.metadataFor(ln)?.displayName ??
                                  'Ligne $ln',
                              onTap: onLineTap == null
                                  ? null
                                  : () => onLineTap!(ln),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                // Pointeur triangulaire vers le marker.
                Positioned(
                  left: arrowLeft.clamp(16, _cardWidth - _arrowSize * 2 - 16),
                  top: arrowTop,
                  child: CustomPaint(
                    size: Size(_arrowSize * 2, _arrowSize),
                    painter: _ArrowPainter(pointDown: placeAbove),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, AppLocale locale,
      PublicTransportService svc, String displayName) {
    final count = lineNumbers.length;
    final sub = count <= 1
        ? '$count ${TransitStrings.t('stop.line.one', locale)}'
        : '$count ${TransitStrings.t('stop.line.many', locale)}';
    return SizedBox(
      height: _headerH,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF2F7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_bus_filled_rounded,
                  size: 18, color: _ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      height: 1.15,
                      color: _ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: TransitStrings.t('stop.close', locale),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(PublicTransportService svc, String lineNumber) {
    final meta = svc.metadataFor(lineNumber);
    return meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
  }
}

/// Mini-carte de SURVOL (hover desktop) : aperçu compact — nom de l'arrêt +
/// pilules des lignes desservantes — flotté au-dessus de la bille survolée.
/// Non interactive (l'appelant l'enveloppe d'un IgnorePointer) : la fiche
/// complète [StopCard] ne s'ouvre qu'au clic. Style aligné sur StopCard.
class StopMiniCard extends StatelessWidget {
  final String stopName;
  final List<String> lineNumbers;

  const StopMiniCard({
    super.key,
    required this.stopName,
    required this.lineNumbers,
  });

  static const double width = 240;
  static const Color _ink = Color(0xFF1D3557);
  static const int _maxBadges = 8;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final svc = PublicTransportService.instance;
    final displayName = stopName.trim().isEmpty
        ? TransitStrings.t('stop.unnamed', locale)
        : stopName;
    final shown = lineNumbers.take(_maxBadges).toList();
    final overflow = lineNumbers.length - shown.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          elevation: 10,
          borderRadius: BorderRadius.circular(12),
          shadowColor: Colors.black.withOpacity(0.18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.15,
                    color: _ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final ln in shown) _miniBadge(svc, ln),
                    if (overflow > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF2F7),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '+$overflow',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Pointeur vers la bille survolée.
        CustomPaint(
          size: const Size(20, 10),
          painter: _ArrowPainter(pointDown: true),
        ),
      ],
    );
  }

  Widget _miniBadge(PublicTransportService svc, String lineNumber) {
    final meta = svc.metadataFor(lineNumber);
    final color =
        meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
    final textColor =
        color.computeLuminance() > 0.6 ? _ink : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        lineNumber,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final bool pointDown;
  _ArrowPainter({required this.pointDown});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
      path.close();
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width / 2, 0);
      path.close();
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.pointDown != pointDown;
}

/// Une ligne desservante : badge n° (couleur de la ligne) + nom, tappable.
class _LineRow extends StatelessWidget {
  final String lineNumber;
  final Color color;
  final String displayName;
  final VoidCallback? onTap;

  const _LineRow({
    required this.lineNumber,
    required this.color,
    required this.displayName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() > 0.6
        ? const Color(0xFF1D3557)
        : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                lineNumber,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1D3557),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
