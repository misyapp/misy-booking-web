import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/models/route_planner.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';

/// Feuille de route détaillée d'un itinéraire — timeline verticale
/// inspirée d'IDF Mobilités. Pictos marche/bus, traits colorés couleur
/// ligne, noms d'arrêts en gras, durée par leg.
class RouteItineraryScreen extends StatelessWidget {
  final TransportRoute route;

  const RouteItineraryScreen({super.key, required this.route});

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
          TransitStrings.t('route.title', locale),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D3557),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildSummary(locale),
          const SizedBox(height: 18),
          for (var i = 0; i < route.steps.length; i++)
            _buildStep(
              route.steps[i],
              isFirst: i == 0,
              isLast: i == route.steps.length - 1,
              locale: locale,
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(AppLocale locale) {
    final transferLabel = route.numberOfTransfers == 0
        ? TransitStrings.t('route.transfers.zero', locale)
        : route.numberOfTransfers == 1
            ? TransitStrings.t('route.transfer.one', locale)
            : '${route.numberOfTransfers} ${TransitStrings.t('route.transfers.many', locale)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${route.totalDurationMinutes}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D3557),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    TransitStrings.t('route.minutes.short', locale),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$transferLabel · ${route.walkingTimeMinutes} ${TransitStrings.t('route.walking', locale)}',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const Spacer(),
          // Pictos lignes empruntées.
          Wrap(
            spacing: 4,
            children: [
              for (final ln in route.usedLines) _lineBadge(ln),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineBadge(String lineNumber) {
    final svc = PublicTransportService.instance;
    final meta = svc.metadataFor(lineNumber);
    final color =
        meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        lineNumber,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildStep(
    RouteStep step, {
    required bool isFirst,
    required bool isLast,
    required AppLocale locale,
  }) {
    final svc = PublicTransportService.instance;
    final isWalking = step.isWalking;
    final color = !isWalking && step.lineNumber != null
        ? (svc.metadataFor(step.lineNumber!) != null
            ? Color(svc.metadataFor(step.lineNumber!)!.colorValue)
            : const Color(0xFF1565C0))
        : const Color(0xFF6B7280);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colonne timeline gauche.
          SizedBox(
            width: 36,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Trait vertical (couleur ligne pour transport, gris dashed
                // pour marche).
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isFirst ? 18 : 0,
                      bottom: isLast ? 18 : 0,
                    ),
                    child: Center(
                      child: isWalking
                          ? CustomPaint(
                              painter: _DashedLinePainter(
                                color: const Color(0xFF6B7280),
                              ),
                              child: const SizedBox(width: 2),
                            )
                          : Container(width: 4, color: color),
                    ),
                  ),
                ),
                // Cercle/icône sur le bullet.
                Positioned(
                  top: 12,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isWalking ? Icons.directions_walk : Icons.directions_bus,
                      size: 12,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Contenu droite.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWalking)
                    _buildWalkContent(step, locale)
                  else
                    _buildTransportContent(step, color, locale),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkContent(RouteStep step, AppLocale locale) {
    final label = step.type == RouteStepType.walkFromStop
        ? TransitStrings.t('route.step.walk.dest', locale)
        : '${TransitStrings.t('route.step.walk.to', locale)} ${step.endStop?.name ?? step.startStop?.name ?? ""}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D3557),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${step.durationMinutes} ${TransitStrings.t('route.minutes.short', locale)} · ${(step.distanceMeters / 1000).toStringAsFixed(1)} km',
          style:
              const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildTransportContent(
      RouteStep step, Color color, AppLocale locale) {
    final lineNumber = step.lineNumber ?? '?';
    final terminus = step.direction ?? step.endStop?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                lineNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (terminus.isNotEmpty)
              Expanded(
                child: Text(
                  '${TransitStrings.t('route.step.toward', locale)} $terminus',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D3557),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (step.startStop != null)
          Text(
            step.startStop!.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D3557),
            ),
          ),
        // Arrêts intermédiaires (juste le nombre).
        if (step.intermediateStops.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '${step.intermediateStops.length} arrêt${step.intermediateStops.length > 1 ? "s" : ""} · ${step.durationMinutes} ${TransitStrings.t('route.minutes.short', locale)}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '${step.durationMinutes} ${TransitStrings.t('route.minutes.short', locale)}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        if (step.endStop != null)
          Row(
            children: [
              const Icon(Icons.flag, size: 12, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${TransitStrings.t('route.step.descend', locale)} ${step.endStop!.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D3557),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + 4).clamp(0, size.height)),
        paint,
      );
      y += 8;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
