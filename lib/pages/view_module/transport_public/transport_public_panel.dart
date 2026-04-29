import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/transit_strings.dart';
import 'package:rider_ride_hailing_app/provider/locale_provider.dart';
import 'package:rider_ride_hailing_app/services/public_transport_service.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart'
    show LineMetadata;
import 'package:rider_ride_hailing_app/widget/home_mode_toggle.dart';
import 'package:rider_ride_hailing_app/widget/language_switcher.dart';

/// Panneau gauche en mode "Transport en commun" — Phase 1.
///
/// V1 contenu : header + switcher de langue + toggle Course/Transport +
/// liste scrollable des lignes admin-validées (numéro coloré, nom,
/// nb d'arrêts). Tap sur une ligne → callback [onLineSelected] pour la
/// mettre en évidence sur la carte.
class TransportPublicPanel extends StatelessWidget {
  final HomeMode mode;
  final ValueChanged<HomeMode> onModeChanged;
  final String? selectedLine; // null = toutes affichées en plein
  final ValueChanged<String?> onLineSelected;

  const TransportPublicPanel({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.selectedLine,
    required this.onLineSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      bottom: 16,
      // PointerInterceptor : sans ça les événements scroll/wheel sur la
      // sidebar traversent jusqu'à la carte Google Maps en dessous et
      // déclenchent zoom/pan involontaires (mode Course utilise le même
      // pattern via _WebScrollIsolator dans home_screen_web.dart).
      child: PointerInterceptor(
        child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const Divider(height: 1, thickness: 1),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: HomeModeToggle(
                  current: mode,
                  onChanged: onModeChanged,
                ),
              ),
              Expanded(
                child: _LinesList(
                  selectedLine: selectedLine,
                  onLineSelected: onLineSelected,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5357).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_bus_outlined,
              color: Color(0xFFFF5357),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TransitStrings.t('transit.title', locale),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1D3557),
                  ),
                ),
                Text(
                  TransitStrings.t('transit.subtitle', locale),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const LanguageSwitcher(),
        ],
      ),
    );
  }
}

/// Liste scrollable. Wrapper StatefulWidget pour piloter l'init du
/// PublicTransportService (FutureBuilder une seule fois).
class _LinesList extends StatefulWidget {
  final String? selectedLine;
  final ValueChanged<String?> onLineSelected;

  const _LinesList({
    required this.selectedLine,
    required this.onLineSelected,
  });

  @override
  State<_LinesList> createState() => _LinesListState();
}

class _LinesListState extends State<_LinesList> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = PublicTransportService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 12),
                Text(
                  TransitStrings.t('state.loading', locale),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  TransitStrings.t('state.error', locale),
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _loadFuture =
                        PublicTransportService.instance.ensureLoaded();
                  }),
                  child: Text(TransitStrings.t('state.retry', locale)),
                ),
              ],
            ),
          );
        }

        final metas = PublicTransportService.instance.allMetadata;
        if (metas.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                TransitStrings.t('lines.empty', locale),
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Row(
                children: [
                  Text(
                    '${metas.length} ${TransitStrings.t('lines.count', locale)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (widget.selectedLine != null)
                    TextButton(
                      onPressed: () => widget.onLineSelected(null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        TransitStrings.t('lines.show.all', locale),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                itemCount: metas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final isSelected =
                      widget.selectedLine == metas[i].lineNumber;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LineRow(
                        meta: metas[i],
                        selected: isSelected,
                        onTap: () {
                          final selected = isSelected
                              ? null
                              : metas[i].lineNumber;
                          widget.onLineSelected(selected);
                        },
                      ),
                      if (isSelected)
                        _LineStopList(lineNumber: metas[i].lineNumber),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LineRow extends StatelessWidget {
  final LineMetadata meta;
  final bool selected;
  final VoidCallback onTap;

  const _LineRow({
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final color = Color(meta.colorValue);
    // Compte d'arrêts UNIQUES (aller + retour dédupliqués par nom et
    // proximité) — sinon une ligne A→B→A afficherait ~2× le vrai nombre.
    final stops = PublicTransportService.instance
        .uniqueStopCountFor(meta.lineNumber);

    return Material(
      color: selected
          ? color.withOpacity(0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: selected
                      ? Border.all(color: const Color(0xFF1D3557), width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  meta.lineNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: const Color(0xFF1D3557),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$stops ${TransitStrings.t('lines.stops.short', locale)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.expand_less
                    : Icons.chevron_right,
                size: 16,
                color: selected ? color : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Schéma topologique d'une ligne, type "plan tramway", affiché sous le row
/// de ligne quand celle-ci est sélectionnée. Branche selon
/// [LineSchematic.topology] :
///
/// - linear : 1 colonne avec tous les arrêts en ordre (aller).
/// - trunkLoop : trunk commun en colonne centrale + boucle = rectangle 2
///   colonnes (aller à gauche, retour à droite) fermé en haut et en bas
///   par des connecteurs horizontaux.
/// - loopOnly : juste le rectangle, pas de trunk.
/// - complex (multi-loops, alternances) : fallback rendu legacy "2 sections
///   empilées" pour ne pas casser l'écran.
class _LineStopList extends StatelessWidget {
  final String lineNumber;

  const _LineStopList({required this.lineNumber});

  @override
  Widget build(BuildContext context) {
    final svc = PublicTransportService.instance;
    final meta = svc.metadataFor(lineNumber);
    final color =
        meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
    final schema = svc.lineSchematicFor(lineNumber);

    switch (schema.topology) {
      case LineTopology.empty:
        return const SizedBox.shrink();
      case LineTopology.linear:
        if (schema.linearStops.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(46, 4, 8, 10),
          child: _BranchView(
            stops: schema.linearStops,
            color: color,
          ),
        );
      case LineTopology.trunkLoop:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
          child: _TrunkLoopSchematic(schema: schema, color: color),
        );
      case LineTopology.loopOnly:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
          child: _TrunkLoopSchematic(schema: schema, color: color),
        );
      case LineTopology.complex:
        return _LegacyBranchesView(
          lineNumber: lineNumber,
          color: color,
        );
    }
  }
}

/// Fallback pour les topologies non gérées V1 : rend l'aller et le retour
/// comme 2 sections empilées avec headers terminus (= ancien comportement
/// avant l'ajout de _TrunkLoopSchematic).
class _LegacyBranchesView extends StatelessWidget {
  final String lineNumber;
  final Color color;

  const _LegacyBranchesView({
    required this.lineNumber,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final svc = PublicTransportService.instance;
    final branches = svc.lineBranchesFor(lineNumber);

    final allerHeader = branches.allerTerminusName ??
        TransitStrings.t('branch.aller', locale);
    final retourHeader = branches.retourTerminusName ??
        TransitStrings.t('branch.retour', locale);
    final towardLabel = TransitStrings.t('branch.toward', locale);

    return Padding(
      padding: const EdgeInsets.fromLTRB(46, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (branches.allerBranch.isNotEmpty) ...[
            _BranchHeader(
                label: '$towardLabel $allerHeader', color: color),
            const SizedBox(height: 2),
            _BranchView(stops: branches.allerBranch, color: color),
          ],
          if (branches.retourBranch.isNotEmpty) ...[
            const SizedBox(height: 14),
            _BranchHeader(
                label: '$towardLabel $retourHeader', color: color),
            const SizedBox(height: 2),
            _BranchView(stops: branches.retourBranch, color: color),
          ],
        ],
      ),
    );
  }
}

/// Schéma topologique trunk + boucle (rectangle) ou loop-only.
///
/// Layout :
/// - Trunk avant : colonne verticale centrée (si présent).
/// - Boucle : 2 colonnes parallèles (aller à gauche, retour à droite) avec
///   un connecteur horizontal en haut (jonction trunk → branches) et un
///   connecteur horizontal en bas (fermeture du rectangle).
/// - Trunk après : colonne verticale centrée sous la boucle (si présent).
///
/// Implémentation : Stack + CustomPaint pour les traits + Positioned pour
/// les bullets et les noms d'arrêts. Mesures hard-codées par tier — la
/// sidebar est de largeur fixe (320px) donc pas de LayoutBuilder à gérer.
class _TrunkLoopSchematic extends StatelessWidget {
  final LineSchematic schema;
  final Color color;

  const _TrunkLoopSchematic({required this.schema, required this.color});

  // Largeur utile de la sidebar après les paddings (320 - 16 - 16 - 20 marg).
  static const double _w = 268;
  // Position X de l'axe trunk (centré).
  static const double _xTrunk = _w / 2;
  // Position X des branches aller (gauche) et retour (droite).
  static const double _xAller = 22;
  static const double _xRetour = _w - 22;
  // Hauteur d'une rangée (1 arrêt).
  static const double _rowH = 26;
  // Marge avant le 1er arrêt et après le dernier (effet départ/terminus).
  static const double _topPad = 8;
  static const double _bottomPad = 8;

  @override
  Widget build(BuildContext context) {
    final trunkBefore = schema.trunkBeforeLoop;
    final trunkAfter = schema.trunkAfterLoop;
    final allerLoop = schema.allerLoopStops;
    final retourLoop = schema.retourLoopStops;

    // On aligne aller et retour de la boucle sur le MAX de leurs longueurs
    // (les rangées vides côté plus court sont juste le trait coloré qui
    // continue, sans bullet ni nom).
    final loopRowsCount = allerLoop.length > retourLoop.length
        ? allerLoop.length
        : retourLoop.length;
    if (loopRowsCount == 0 && trunkBefore.isEmpty && trunkAfter.isEmpty) {
      return const SizedBox.shrink();
    }

    final trunkBeforeH = _topPad + trunkBefore.length * _rowH;
    final loopH = _topPad + loopRowsCount * _rowH + _bottomPad;
    final trunkAfterH = trunkAfter.length * _rowH + _bottomPad;
    final totalH = trunkBeforeH + loopH + trunkAfterH;

    return SizedBox(
      width: _w,
      height: totalH,
      child: Stack(
        children: [
          // Couches de traits dessinées en CustomPaint pour avoir la maîtrise
          // exacte des connecteurs horizontaux et des verticaux qui doivent
          // coïncider parfaitement.
          Positioned.fill(
            child: CustomPaint(
              painter: _TrunkLoopPainter(
                color: color,
                trunkBeforeH: trunkBeforeH,
                loopH: loopH,
                trunkAfterH: trunkAfterH,
                hasTrunkBefore: trunkBefore.isNotEmpty,
                hasTrunkAfter: trunkAfter.isNotEmpty,
                hasLoop: loopRowsCount > 0,
              ),
            ),
          ),
          // Bullets et noms du trunk avant la boucle.
          for (var i = 0; i < trunkBefore.length; i++)
            _trunkBullet(
              top: _topPad + i * _rowH,
              stop: trunkBefore[i],
              isTerminus: i == 0,
            ),
          // Bullets et noms de la boucle (2 colonnes parallèles).
          for (var i = 0; i < allerLoop.length; i++)
            _branchBullet(
              top: trunkBeforeH + _topPad + i * _rowH,
              x: _xAller,
              stop: allerLoop[i],
              isLeftSide: true,
              isTerminus: i == allerLoop.length - 1,
            ),
          for (var i = 0; i < retourLoop.length; i++)
            _branchBullet(
              top: trunkBeforeH + _topPad + i * _rowH,
              x: _xRetour,
              stop: retourLoop[i],
              isLeftSide: false,
              isTerminus: i == 0,
            ),
          // Bullets et noms du trunk après la boucle.
          for (var i = 0; i < trunkAfter.length; i++)
            _trunkBullet(
              top: trunkBeforeH + loopH + i * _rowH,
              stop: trunkAfter[i],
              isTerminus: i == trunkAfter.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _trunkBullet({
    required double top,
    required BranchStop stop,
    required bool isTerminus,
  }) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: _rowH,
      child: Row(
        children: [
          SizedBox(
            width: _xTrunk + 8,
            child: Align(
              alignment: const Alignment(0, 0),
              child: _bullet(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                stop.name.trim().isEmpty ? '—' : stop.name,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF1D3557),
                  fontWeight: isTerminus ? FontWeight.w700 : FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchBullet({
    required double top,
    required double x,
    required BranchStop stop,
    required bool isLeftSide,
    required bool isTerminus,
  }) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: _rowH,
      child: Stack(
        children: [
          // Bullet centré sur la colonne.
          Positioned(
            left: x - 5,
            top: _rowH / 2 - 5,
            width: 10,
            height: 10,
            child: _bullet(),
          ),
          // Nom : pour la branche aller (gauche) — texte à gauche du bullet,
          // right-aligned. Pour retour (droite) — texte à droite du bullet,
          // left-aligned.
          if (isLeftSide)
            Positioned(
              left: 0,
              right: _w - x + 8,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: _stopText(stop, isTerminus),
                ),
              ),
            )
          else
            Positioned(
              left: x + 8,
              right: 0,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: _stopText(stop, isTerminus),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bullet() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }

  Widget _stopText(BranchStop stop, bool isTerminus) {
    return Text(
      stop.name.trim().isEmpty ? '—' : stop.name,
      style: TextStyle(
        fontSize: 11,
        color: const Color(0xFF1D3557),
        fontWeight: isTerminus ? FontWeight.w700 : FontWeight.w400,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Painter qui dessine les traits colorés du schéma trunk + loop :
/// - trait vertical du trunk (avant et après la boucle si applicable)
/// - traits verticaux des 2 branches de la boucle
/// - connecteur horizontal en haut de la boucle (jonction trunk → branches)
/// - connecteur horizontal en bas de la boucle (fermeture du rectangle)
class _TrunkLoopPainter extends CustomPainter {
  final Color color;
  final double trunkBeforeH;
  final double loopH;
  final double trunkAfterH;
  final bool hasTrunkBefore;
  final bool hasTrunkAfter;
  final bool hasLoop;

  static const double _xTrunk = _TrunkLoopSchematic._xTrunk;
  static const double _xAller = _TrunkLoopSchematic._xAller;
  static const double _xRetour = _TrunkLoopSchematic._xRetour;

  _TrunkLoopPainter({
    required this.color,
    required this.trunkBeforeH,
    required this.loopH,
    required this.trunkAfterH,
    required this.hasTrunkBefore,
    required this.hasTrunkAfter,
    required this.hasLoop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Trunk avant : trait vertical de y=0 jusqu'au début de la boucle.
    if (hasTrunkBefore) {
      canvas.drawLine(
        Offset(_xTrunk, 4),
        Offset(_xTrunk, trunkBeforeH),
        paint,
      );
    }

    if (hasLoop) {
      final loopTop = trunkBeforeH;
      final loopBottom = trunkBeforeH + loopH;

      // Connecteur HAUT : trait horizontal qui relie le trunk (xTrunk) aux
      // 2 branches (xAller et xRetour). Si pas de trunk avant, le connecteur
      // démarre quand même horizontalement entre xAller et xRetour.
      if (hasTrunkBefore) {
        // T-junction : trait horizontal de xAller à xRetour passant par
        // xTrunk (qui doit être au milieu).
        canvas.drawLine(
          Offset(_xAller, loopTop),
          Offset(_xRetour, loopTop),
          paint,
        );
      } else {
        // Pas de trunk : juste le top du rectangle.
        canvas.drawLine(
          Offset(_xAller, loopTop + 4),
          Offset(_xRetour, loopTop + 4),
          paint,
        );
      }

      // Branches verticales (aller à gauche, retour à droite).
      final branchTop = hasTrunkBefore ? loopTop : loopTop + 4;
      final branchBottom = hasTrunkAfter ? loopBottom : loopBottom - 4;
      canvas.drawLine(
        Offset(_xAller, branchTop),
        Offset(_xAller, branchBottom),
        paint,
      );
      canvas.drawLine(
        Offset(_xRetour, branchTop),
        Offset(_xRetour, branchBottom),
        paint,
      );

      // Connecteur BAS : trait horizontal qui ferme le rectangle.
      if (hasTrunkAfter) {
        canvas.drawLine(
          Offset(_xAller, loopBottom),
          Offset(_xRetour, loopBottom),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(_xAller, loopBottom - 4),
          Offset(_xRetour, loopBottom - 4),
          paint,
        );
      }
    }

    // Trunk après : trait vertical sous la boucle.
    if (hasTrunkAfter) {
      final yStart = trunkBeforeH + loopH;
      canvas.drawLine(
        Offset(_xTrunk, yStart),
        Offset(_xTrunk, yStart + trunkAfterH - 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrunkLoopPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.trunkBeforeH != trunkBeforeH ||
      oldDelegate.loopH != loopH ||
      oldDelegate.trunkAfterH != trunkAfterH ||
      oldDelegate.hasTrunkBefore != hasTrunkBefore ||
      oldDelegate.hasTrunkAfter != hasTrunkAfter ||
      oldDelegate.hasLoop != hasLoop;
}

/// Header d'une branche : flèche + nom du terminus en couleur de la ligne.
class _BranchHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _BranchHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.arrow_forward, size: 12, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tracé vertical type plan tramway : 1 trait coloré continu de haut en
/// bas + 1 bullet rond blanc bordé couleur ligne pour chaque arrêt.
/// Le 1er et le dernier arrêt (terminus) sont mis en évidence (font w600).
class _BranchView extends StatelessWidget {
  final List<BranchStop> stops;
  final Color color;

  const _BranchView({required this.stops, required this.color});

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stops.length; i++)
          _BranchStopRow(
            name: stops[i].name,
            color: color,
            isFirst: i == 0,
            isLast: i == stops.length - 1,
            isTerminus: i == 0 || i == stops.length - 1,
          ),
      ],
    );
  }
}

class _BranchStopRow extends StatelessWidget {
  final String name;
  final Color color;
  final bool isFirst;
  final bool isLast;
  final bool isTerminus;

  const _BranchStopRow({
    required this.name,
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.isTerminus,
  });

  @override
  Widget build(BuildContext context) {
    final display = name.trim().isEmpty ? '—' : name;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colonne timeline : trait coloré + bullet rond. Le trait est
          // tronqué au-dessus du 1er bullet et en-dessous du dernier pour
          // donner l'effet "départ / terminus".
          SizedBox(
            width: 18,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isFirst ? 12 : 0,
                      bottom: isLast ? 12 : 0,
                    ),
                    child: Center(
                      child: Container(
                        width: 3,
                        color: color.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                display,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF1D3557),
                  fontWeight:
                      isTerminus ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
