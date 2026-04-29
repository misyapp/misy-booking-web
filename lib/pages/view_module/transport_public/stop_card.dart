import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';

/// Carte d'information d'un arrêt — affichée en overlay flottant ancré au
/// pixel correspondant à l'arrêt (au-dessus, ou en-dessous si trop près du
/// haut). Style inspiré de la fiche arrêt sur me-deplacer.iledefrance-mobilites.fr
/// avec un petit pointeur triangulaire vers le marker.
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

  static const double _cardWidth = 320;
  static const double _cardEstimatedHeight = 170;
  static const double _gap = 14; // espace entre marker et card
  static const double _arrowSize = 10;

  @override
  Widget build(BuildContext context) {
    if (screenAnchor == null) {
      return const SizedBox.shrink();
    }
    final locale = context.watch<LocaleProvider>().locale;
    final svc = PublicTransportService.instance;
    final displayName = stopName.trim().isEmpty
        ? TransitStrings.t('stop.unnamed', locale)
        : stopName;

    final anchor = screenAnchor!;

    // Décide si on affiche au-dessus ou en-dessous du marker selon l'espace
    // disponible. Au-dessus par défaut (UX standard) sauf si on touche le
    // haut de l'écran.
    final placeAbove = anchor.dy >= _cardEstimatedHeight + _gap + 16;
    final cardTop = placeAbove
        ? anchor.dy - _cardEstimatedHeight - _gap
        : anchor.dy + _gap;

    // Centre horizontal sur le marker, mais clamp aux bords de l'écran.
    var cardLeft = anchor.dx - _cardWidth / 2;
    cardLeft = cardLeft.clamp(8.0, screenSize.width - _cardWidth - 8.0);

    final arrowLeft = anchor.dx - cardLeft - _arrowSize;
    final arrowTop =
        placeAbove ? _cardEstimatedHeight - 1 : -_arrowSize * 2 + 1;

    return Stack(
      children: [
        Positioned(
          left: cardLeft,
          top: cardTop,
          width: _cardWidth,
          child: SizedBox(
            // Hauteur réservée pour positionner correctement la pointe
            // triangulaire en bas (même quand le contenu est court).
            height: _cardEstimatedHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: Colors.white,
                  elevation: 12,
                  borderRadius: BorderRadius.circular(14),
                  shadowColor: Colors.black.withOpacity(0.18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 17,
                              color: Color(0xFF1D3557),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF1D3557),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              tooltip:
                                  TransitStrings.t('stop.close', locale),
                              onPressed: onClose,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 25),
                          child: Text(
                            TransitStrings.t('stop.lines.served', locale),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 25),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final ln in lineNumbers)
                                _LineChip(
                                  lineNumber: ln,
                                  color: _colorFor(svc, ln),
                                  displayName:
                                      svc.metadataFor(ln)?.displayName ??
                                          'Ligne $ln',
                                  onTap: onLineTap == null
                                      ? null
                                      : () => onLineTap!(ln),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Pointeur triangulaire vers le marker.
                Positioned(
                  left: arrowLeft.clamp(12, _cardWidth - _arrowSize * 2 - 12),
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

  Color _colorFor(PublicTransportService svc, String lineNumber) {
    final meta = svc.metadataFor(lineNumber);
    return meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
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

class _LineChip extends StatelessWidget {
  final String lineNumber;
  final Color color;
  final String displayName;
  final VoidCallback? onTap;

  const _LineChip({
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                  fontSize: 12,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1D3557),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
