import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';

/// Carte d'information d'un arrêt — affichée en overlay flottant en bas
/// centre de la carte quand l'utilisateur clique sur un marker.
///
/// Style inspiré de la fiche arrêt sur me-deplacer.iledefrance-mobilites.fr :
/// nom de l'arrêt en gros, header avec coordonnées, liste des lignes
/// desservant l'arrêt sous forme de pastilles colorées avec numéro et
/// nom complet. Bouton fermeture en haut à droite.
class StopCard extends StatelessWidget {
  final String stopName;
  final LatLng position;
  final List<String> lineNumbers;
  final VoidCallback onClose;
  final ValueChanged<String>? onLineTap;

  const StopCard({
    super.key,
    required this.stopName,
    required this.position,
    required this.lineNumbers,
    required this.onClose,
    this.onLineTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final svc = PublicTransportService.instance;
    final displayName =
        stopName.trim().isEmpty ? TransitStrings.t('stop.unnamed', locale) : stopName;

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: Colors.white,
            elevation: 12,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.black.withOpacity(0.18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Color(0xFF1D3557),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1D3557),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
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
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      TransitStrings.t('stop.lines.served', locale),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ln in lineNumbers) _LineChip(
                          lineNumber: ln,
                          color: _colorFor(svc, ln),
                          displayName: svc.metadataFor(ln)?.displayName ??
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
        ),
      ),
    );
  }

  Color _colorFor(PublicTransportService svc, String lineNumber) {
    final meta = svc.metadataFor(lineNumber);
    return meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
  }
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
