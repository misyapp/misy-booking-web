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

/// Liste expansible des arrêts d'une ligne sous forme de "plan tramway".
///
/// Cas LINÉAIRE (aller ≈ retour inversé) : 1 colonne d'arrêts du début au
/// terminus. Cas CIRCULAIRE (aller et retour empruntent des routes
/// différentes) : 2 sections empilées avec headers de terminus, chacune
/// avec son propre tracé coloré continu et ses arrêts en ordre.
class _LineStopList extends StatelessWidget {
  final String lineNumber;

  const _LineStopList({required this.lineNumber});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final svc = PublicTransportService.instance;
    final meta = svc.metadataFor(lineNumber);
    final color =
        meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
    final branches = svc.lineBranchesFor(lineNumber);

    if (branches.isLinear) {
      if (branches.mainBranch.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(46, 4, 8, 10),
        child: _BranchView(
          stops: branches.mainBranch,
          color: color,
        ),
      );
    }

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
              label: '$towardLabel $allerHeader',
              color: color,
            ),
            const SizedBox(height: 2),
            _BranchView(
              stops: branches.allerBranch,
              color: color,
            ),
          ],
          if (branches.retourBranch.isNotEmpty) ...[
            const SizedBox(height: 14),
            _BranchHeader(
              label: '$towardLabel $retourHeader',
              color: color,
            ),
            const SizedBox(height: 2),
            _BranchView(
              stops: branches.retourBranch,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
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
