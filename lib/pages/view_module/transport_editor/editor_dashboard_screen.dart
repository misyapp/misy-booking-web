import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/models/transport_line_validation.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/admin_review_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/editor_new_line_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/editor_wizard_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/annotation_dialog.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/tutorial_helpers.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'package:showcaseview/showcaseview.dart';

/// Dashboard de l'éditeur terrain : KPI + carte + liste des lignes +
/// annotations + activité. Même structure que l'écran admin pour cohérence
/// visuelle.
class EditorDashboardScreen extends StatelessWidget {
  const EditorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminAuthService.instance.isTransportEditor(forceRefresh: true),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data != true) {
          return const _AccessDeniedScreen();
        }
        return ShowCaseWidget(
          onFinish: () {},
          builder: (ctx) => const _DashboardBody(),
        );
      },
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _pastillesKey = GlobalKey();
  final GlobalKey _annotationKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  // Bumped à v3 pour relancer auto chez les consultants existants → leur
  // montrer la nouvelle interface dashboard (KPI + carte + cards).
  static const String _tourId = 'dashboard_v3_layout';

  String _query = '';
  String? _mapFilterLine;
  List<LineMetadata> _allMeta = [];
  bool _loadingMeta = true;
  Future<List<TransportLineGroup>>? _linesFuture;
  // Cache des FCs édités (submissions en cours) pour rendre les directions
  // non-approved en pointillé sur la carte. Recalculé via [_loadEditedFor]
  // quand le set de lignes "modifiées" change.
  Map<String, Map<String, Map<String, dynamic>>> _editedFcs = {};
  String? _loadedEditedSig;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _linesFuture = TransportLinesService.instance.loadAllLines();
    TutorialHelper.autoStartOnce(
      context: context,
      tourId: _tourId,
      keys: [
        _searchKey,
        _cardKey,
        _pastillesKey,
        _annotationKey,
        _fabKey,
      ],
    );
  }

  Future<void> _loadMetadata() async {
    final meta = await TransportLinesService.instance.getAllLineMetadata();
    meta.sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
    if (mounted) {
      setState(() {
        _allMeta = meta;
        _loadingMeta = false;
      });
    }
  }

  LineMetadata? _metaFor(String lineNumber) {
    for (final m in _allMeta) {
      if (m.lineNumber == lineNumber) return m;
    }
    return null;
  }

  /// Extrait les points LatLng du LineString d'une FeatureCollection brute
  /// (lit `[lng, lat]` GeoJSON, retourne LatLng latlong2).
  List<LatLng> _extractLineStringFromFc(Map<String, dynamic> fc) {
    final pts = <LatLng>[];
    for (final f in (fc['features'] as List? ?? [])) {
      final g = f['geometry'] as Map?;
      if (g == null || g['type'] != 'LineString') continue;
      for (final c in (g['coordinates'] as List? ?? [])) {
        pts.add(LatLng(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        ));
      }
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditeur terrain transport'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          FutureBuilder<bool>(
            future: AdminAuthService.instance.isTransportAdmin(),
            builder: (ctx, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Review admin',
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminReviewScreen(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Revoir le tuto',
            icon: const Icon(Icons.school_outlined),
            onPressed: () async {
              await TutorialHelper.reset(_tourId);
              if (!mounted) return;
              ShowCaseWidget.of(context).startShowCase([
                _searchKey,
                _cardKey,
                _pastillesKey,
                _annotationKey,
                _fabKey,
              ]);
            },
          ),
          _ProfileMenu(),
          const SizedBox(width: 4),
        ],
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Map<String, TransportLineValidation>>(
              stream: TransportEditorService.instance.streamAllValidations(),
              builder: (ctx, snap) {
                final validations = snap.data ?? {};
                return LayoutBuilder(builder: (ctx, c) {
                  final isWide = c.maxWidth >= 1100;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKpiRow(validations),
                        const SizedBox(height: 16),
                        if (isWide)
                          SizedBox(
                            height: 520,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                    flex: 6,
                                    child: _buildMapCard(validations)),
                                const SizedBox(width: 16),
                                Expanded(
                                    flex: 4,
                                    child: _buildLinesCard(validations)),
                              ],
                            ),
                          )
                        else ...[
                          SizedBox(
                              height: 380,
                              child: _buildMapCard(validations)),
                          const SizedBox(height: 16),
                          SizedBox(
                              height: 520,
                              child: _buildLinesCard(validations)),
                        ],
                        const SizedBox(height: 16),
                        if (isWide)
                          SizedBox(
                            height: 420,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                    flex: 5,
                                    child:
                                        _buildAnnotationsCard(validations)),
                                const SizedBox(width: 16),
                                Expanded(
                                    flex: 5, child: _buildActivityCard()),
                              ],
                            ),
                          )
                        else ...[
                          SizedBox(
                              height: 360,
                              child: _buildAnnotationsCard(validations)),
                          const SizedBox(height: 16),
                          SizedBox(
                              height: 360, child: _buildActivityCard()),
                        ],
                      ],
                    ),
                  );
                });
              },
            ),
      floatingActionButton: TutoStep(
        stepKey: _fabKey,
        title: 'Nouvelle ligne',
        description:
            'Appuie ici pour créer une nouvelle ligne de bus from scratch : '
            'numéro, couleur, tracé aller/retour, arrêts.',
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditorNewLineScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle ligne'),
        ),
      ),
    );
  }

  /* ──────────────────── KPI ROW ──────────────────── */

  Widget _buildKpiRow(Map<String, TransportLineValidation> validations) {
    final total = _allMeta.length;
    final published = validations.values.where((v) => v.isPublished).length;
    int sent = 0;
    int rejected = 0;
    int annotated = 0;
    for (final v in validations.values) {
      bool hasAnnotation = false;
      for (final step in EditorStep.values) {
        final cs = v.statusFor(step);
        final admin = v.adminReviewFor(step);
        if (admin.status == AdminStatus.rejected) {
          rejected++;
        } else if (cs == ValidationStatus.modified &&
            admin.status != AdminStatus.approved) {
          sent++;
        }
        if (v.noteFor(step) != null || v.flagFor(step) != null) {
          hasAnnotation = true;
        }
      }
      if (hasAnnotation) annotated++;
    }

    final kpis = [
      _Kpi('Lignes totales', '$total', Icons.directions_bus,
          const Color(0xFF1565C0)),
      _Kpi('En prod', '$published', Icons.check_circle,
          const Color(0xFF43A047)),
      _Kpi('Envoyées', '$sent', Icons.schedule, const Color(0xFFFB8C00)),
      _Kpi('À refaire', '$rejected', Icons.replay, const Color(0xFFE53935)),
      _Kpi('Annotées', '$annotated', Icons.sticky_note_2_outlined,
          const Color(0xFF1E88E5)),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      final narrow = c.maxWidth < 900;
      if (narrow) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < kpis.length; i++) ...[
                SizedBox(width: 200, child: _kpiCard(kpis[i])),
                if (i != kpis.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        );
      }
      return Row(
        children: [
          for (var i = 0; i < kpis.length; i++) ...[
            Expanded(child: _kpiCard(kpis[i])),
            if (i != kpis.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    });
  }

  Widget _kpiCard(_Kpi kpi) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kpi.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(kpi.icon, color: kpi.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(kpi.value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                Text(kpi.label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ──────────────────── MAP CARD ──────────────────── */

  Widget _buildMapCard(Map<String, TransportLineValidation> validations) {
    // Lignes avec au moins une direction "modified" (= submission en cours
    // pas encore approved). Sera fetchée pour rendu pointillé.
    final linesWithSubmission = <String>{
      for (final v in validations.values)
        if (v.statusFor(EditorStep.aller) == ValidationStatus.modified ||
            v.statusFor(EditorStep.retour) == ValidationStatus.modified)
          v.lineNumber,
    };
    final sig = (linesWithSubmission.toList()..sort()).join(',');
    if (sig != _loadedEditedSig) {
      _loadEditedFor(linesWithSubmission, sig);
    }
    return _dashboardCard(
      title: 'Carte des lignes',
      icon: Icons.map_outlined,
      child: FutureBuilder<List<TransportLineGroup>>(
        future: _linesFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Text('Erreur chargement lignes : ${snap.error ?? ""}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          // Carte = lignes validées admin (trait plein) + submissions en
          // cours (trait pointillé). Affiche les 2 mêmes si aucune ligne
          // n'est encore publiée.
          final groups = snap.data!;
          final relevant = groups.where((g) {
            final v = validations[g.lineNumber];
            if (v == null) return false;
            return v.allerAdmin.status == AdminStatus.approved ||
                v.retourAdmin.status == AdminStatus.approved ||
                v.statusFor(EditorStep.aller) == ValidationStatus.modified ||
                v.statusFor(EditorStep.retour) == ValidationStatus.modified;
          }).toList();
          if (relevant.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Aucune ligne avec submission ou validation pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMapFilterBar(relevant),
              const SizedBox(height: 8),
              Expanded(child: _buildMap(relevant, validations)),
            ],
          );
        },
      ),
    );
  }

  /// Charge en cache les FCs édités (submissions en cours). Schédulé après
  /// le frame courant pour ne pas appeler setState pendant build.
  void _loadEditedFor(Set<String> lineNumbers, String sig) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final docs = await TransportEditorService.instance
            .loadEditedForLines(lineNumbers);
        if (!mounted || _loadedEditedSig == sig) return;
        setState(() {
          _editedFcs = docs;
          _loadedEditedSig = sig;
        });
      } catch (_) {
        // Tant pis : la carte affichera juste les lignes approved.
      }
    });
  }

  Widget _buildMapFilterBar(List<TransportLineGroup> groups) {
    final sorted = [...groups]
      ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: Color(0xFF1565C0)),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _mapFilterLine,
              underline: const SizedBox.shrink(),
              hint: const Text('Toutes les lignes',
                  style: TextStyle(fontSize: 12)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Toutes les lignes',
                      style: TextStyle(fontSize: 12)),
                ),
                for (final g in sorted)
                  DropdownMenuItem<String?>(
                    value: g.lineNumber,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(_metaFor(g.lineNumber)?.colorValue ??
                                0xFF1565C0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ligne ${g.lineNumber} — ${g.displayName}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _mapFilterLine = v),
            ),
          ),
          if (_mapFilterLine != null)
            IconButton(
              tooltip: 'Réinitialiser',
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => setState(() => _mapFilterLine = null),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(List<TransportLineGroup> groups,
      Map<String, TransportLineValidation> validations) {
    final filtered = _mapFilterLine == null
        ? groups
        : groups.where((g) => g.lineNumber == _mapFilterLine).toList();

    final polylines = <Polyline>[];
    final allPoints = <LatLng>[];

    // Pour chaque direction d'une ligne pertinente :
    //   admin_status approved → trait plein depuis groups (= published)
    //   sinon (modified) → trait pointillé depuis transport_lines_edited
    for (final g in filtered) {
      final v = validations[g.lineNumber];
      if (v == null) continue;
      final meta = _metaFor(g.lineNumber);
      final color =
          meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);

      for (final step in EditorStep.values) {
        final dirKey = step.isAller ? 'aller' : 'retour';
        final adminApproved =
            v.adminReviewFor(step).status == AdminStatus.approved;
        final consultantSubmitted =
            v.statusFor(step) == ValidationStatus.modified;

        if (adminApproved) {
          for (final line in g.lines) {
            if (line.direction != dirKey) continue;
            if (line.coordinates.length < 2) continue;
            final pts = line.coordinates
                .map((c) => LatLng(c.latitude, c.longitude))
                .toList();
            polylines.add(Polyline(
              points: pts,
              color: color.withOpacity(0.85),
              strokeWidth: 3.5,
            ));
            allPoints.addAll(pts);
          }
        } else if (consultantSubmitted) {
          final fc = _editedFcs[g.lineNumber]?[dirKey];
          if (fc == null) continue;
          final pts = _extractLineStringFromFc(fc);
          if (pts.length < 2) continue;
          polylines.add(Polyline(
            points: pts,
            color: color.withOpacity(0.85),
            strokeWidth: 3,
            pattern: StrokePattern.dashed(segments: const [10.0, 6.0]),
          ));
          allPoints.addAll(pts);
        }
      }
    }

    final initialCamera = (_mapFilterLine != null && allPoints.isNotEmpty)
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(allPoints),
            padding: const EdgeInsets.all(40),
          )
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FlutterMap(
        key: ValueKey('editor-map-${_mapFilterLine ?? "all"}'),
        options: MapOptions(
          initialCenter: const LatLng(-18.8792, 47.5079),
          initialZoom: 12,
          initialCameraFit: initialCamera,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'app.misy.book',
          ),
          PolylineLayer(polylines: polylines),
        ],
      ),
    );
  }

  /* ──────────────────── LINES LIST CARD ──────────────────── */

  Widget _buildLinesCard(Map<String, TransportLineValidation> validations) {
    final filtered = _allMeta.where((m) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return m.lineNumber.toLowerCase().contains(q) ||
          m.displayName.toLowerCase().contains(q);
    }).toList();
    filtered.sort((a, b) =>
        _sortScore(a, validations).compareTo(_sortScore(b, validations)));

    return _dashboardCard(
      title: 'Lignes',
      icon: Icons.list_alt,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('${filtered.length} / ${_allMeta.length}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TutoStep(
            stepKey: _searchKey,
            title: 'Rechercher une ligne',
            description:
                'Filtre par numéro (ex: « 129 ») ou par nom. Utile pour retrouver '
                'rapidement la ligne en cours de vérification.',
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher (numéro, nom…)',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Aucune ligne ne correspond.',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final m = filtered[i];
                      final v = validations[m.lineNumber] ??
                          TransportLineValidation.empty(m.lineNumber);
                      return _buildLineCard(m, v, i);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /* ──────────────────── ANNOTATIONS CARD ──────────────────── */

  Widget _buildAnnotationsCard(
      Map<String, TransportLineValidation> validations) {
    final annotated = <_AnnotatedDirection>[];
    for (final v in validations.values) {
      for (final step in EditorStep.values) {
        final note = v.noteFor(step);
        final flag = v.flagFor(step);
        if (note == null && flag == null) continue;
        annotated.add(_AnnotatedDirection(
          lineNumber: v.lineNumber,
          step: step,
          note: note,
          flag: flag,
          updatedAt: v.updatedAt,
        ));
      }
    }
    annotated.sort((a, b) {
      final ad = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final bd = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bd.compareTo(ad);
    });

    return _dashboardCard(
      title: 'Notes & drapeaux',
      icon: Icons.sticky_note_2_outlined,
      child: annotated.isEmpty
          ? const Center(
              child: Text('Aucune note pour le moment.',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: annotated.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (ctx, i) =>
                  _buildAnnotationRow(annotated[i], validations),
            ),
    );
  }

  Widget _buildAnnotationRow(
      _AnnotatedDirection a, Map<String, TransportLineValidation> validations) {
    final meta = _metaFor(a.lineNumber);
    final lineColor =
        meta != null ? Color(meta.colorValue) : const Color(0xFF1565C0);
    final dirLabel = a.step.isAller ? 'Aller' : 'Retour';
    final dateStr = a.updatedAt == null
        ? '—'
        : DateFormat('dd/MM HH:mm').format(a.updatedAt!);

    return InkWell(
      onTap: () {
        if (meta == null) return;
        final v = validations[a.lineNumber] ??
            TransportLineValidation.empty(a.lineNumber);
        _openWizard(meta, v);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: lineColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('Ligne ${a.lineNumber} · $dirLabel',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      if (a.flag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: a.flag!.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(a.flag!.label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  if (a.note != null) ...[
                    const SizedBox(height: 2),
                    Text(a.note!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(dateStr,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  /* ──────────────────── ACTIVITY CARD ──────────────────── */

  Widget _buildActivityCard() {
    return _dashboardCard(
      title: 'Activité récente',
      icon: Icons.history,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('transport_edits_log')
            .orderBy('timestamp', descending: true)
            .limit(30)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Erreur : ${snap.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('Pas encore d\'activité.',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (ctx, i) => _buildActivityRow(docs[i].data()),
          );
        },
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> log) {
    final action = (log['action'] as String?) ?? '?';
    final kind = (log['kind'] as String?) ?? '';
    final line = (log['line_number'] as String?) ?? '?';
    final direction = (log['direction'] as String?) ?? '';
    final email = (log['user_email'] as String?) ?? 'inconnu';
    final ts = log['timestamp'];
    DateTime? date;
    if (ts is Timestamp) date = ts.toDate();
    final dateStr =
        date == null ? '' : DateFormat('dd/MM HH:mm').format(date);

    Color color;
    IconData icon;
    String label;
    switch (action) {
      case 'approved':
        color = const Color(0xFF43A047);
        icon = Icons.check_circle;
        label = 'Validé';
        break;
      case 'rejected':
        color = const Color(0xFFE53935);
        icon = Icons.replay;
        label = 'Rejeté';
        break;
      case 'admin_edited':
        color = const Color(0xFF7E57C2);
        icon = Icons.edit_location_alt;
        label = 'Modifié admin';
        break;
      case 'created':
        color = const Color(0xFF1565C0);
        icon = Icons.add_circle;
        label = 'Créée';
        break;
      case 'rebuilt':
        color = const Color(0xFFFB8C00);
        icon = Icons.edit_location_alt;
        label = 'Éditée';
        break;
      case 'noted':
        color = const Color(0xFF1E88E5);
        icon = Icons.sticky_note_2_outlined;
        label = 'Note';
        break;
      default:
        color = Colors.grey;
        icon = Icons.circle;
        label = action;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Ligne $line${direction.isNotEmpty ? " · $direction" : ""}'
                        '${kind == "new_line" ? " (nouvelle)" : ""}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(email,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(dateStr,
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  /* ──────────────────── DASHBOARD CARD WRAPPER ──────────────────── */

  Widget _dashboardCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  /* ──────────────────── LINE LIST ITEM ──────────────────── */

  int _sortScore(
      LineMetadata m, Map<String, TransportLineValidation> validations) {
    final v = validations[m.lineNumber];
    if (v == null) return 0;
    if (v.isFullyValidated) return 2;
    if (v.completedCount > 0) return 1;
    return 0;
  }

  Widget _buildLineCard(
      LineMetadata m, TransportLineValidation v, int index) {
    final card = Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: v.isFullyValidated
              ? const Color(0xFF66BB6A)
              : Colors.grey.shade300,
          width: v.isFullyValidated ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openWizard(m, v),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _colorDot(m.colorValue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.displayName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Ligne ${m.lineNumber} · ${m.transportType}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    _buildPastilles(v, withTutoKey: index == 0),
                  ],
                ),
              ),
              Icon(
                v.isFullyValidated
                    ? Icons.check_circle
                    : Icons.chevron_right,
                color: v.isFullyValidated
                    ? const Color(0xFF43A047)
                    : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );

    if (index == 0) {
      return TutoStep(
        stepKey: _cardKey,
        title: 'Une ligne à vérifier',
        description:
            'Chaque carte représente une ligne. Touche la pour lancer le '
            'wizard de vérification en 2 étapes (aller + retour).',
        child: card,
      );
    }
    return card;
  }

  Widget _buildPastilles(TransportLineValidation v,
      {bool withTutoKey = false}) {
    final pastilles = Row(
      children: [
        _pastilleWithAnnotation(EditorStep.aller, 'Aller', v.aller,
            v.allerAdmin, v, withTutoKey: withTutoKey),
        const SizedBox(width: 6),
        _pastilleWithAnnotation(EditorStep.retour, 'Retour', v.retour,
            v.retourAdmin, v),
      ],
    );
    if (withTutoKey) {
      return TutoStep(
        stepKey: _pastillesKey,
        title: 'État des 2 vérifications',
        description:
            'Gris = à vérifier, orange = modifié (en attente review admin), '
            'rouge = à refaire (l\'admin a renvoyé, tape pour voir le motif), '
            'vert = validé par admin et en prod.',
        child: pastilles,
      );
    }
    return pastilles;
  }

  /// Pastille standard + drapeau couleur + bouton 📝 pour annoter cette
  /// direction. Le bouton porte le tuto-key annotation si c'est la première
  /// carte (paramètre `withTutoKey` reusé pour l'aller du 1er item).
  Widget _pastilleWithAnnotation(
    EditorStep step,
    String label,
    ValidationStatus status,
    AdminReview admin,
    TransportLineValidation v, {
    bool withTutoKey = false,
  }) {
    final note = v.noteFor(step);
    final flag = v.flagFor(step);
    final hasAnnotation = note != null || flag != null;

    final annotationButton = InkWell(
      onTap: () => _editAnnotation(v.lineNumber, step, note, flag),
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: hasAnnotation
            ? '${flag?.label ?? ""}${flag != null && note != null ? "\n" : ""}${note ?? ""}'
            : 'Ajouter une note ou un drapeau',
        child: Container(
          padding: const EdgeInsets.all(3),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                hasAnnotation ? Icons.edit_note : Icons.note_add_outlined,
                size: 18,
                color: hasAnnotation
                    ? (flag?.color ?? const Color(0xFF1565C0))
                    : Colors.grey,
              ),
              if (flag != null)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: flag.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final wrapped = withTutoKey
        ? TutoStep(
            stepKey: _annotationKey,
            title: 'Note + drapeau couleur (perso)',
            description:
                'Tape l\'icône 📝 à côté de Aller ou Retour pour poser un '
                'drapeau couleur (rouge/orange/jaune/vert/bleu) ou une note '
                'libre. Visible dans la liste pour toi ET pour l\'admin '
                'reviewer. Sert à signaler "à confirmer sur place" sans '
                'changer le statut.',
            child: annotationButton,
          )
        : annotationButton;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pastille(label, status, admin),
        const SizedBox(width: 2),
        wrapped,
      ],
    );
  }

  Future<void> _editAnnotation(
    String lineNumber,
    EditorStep step,
    String? currentNote,
    ConsultantFlag? currentFlag,
  ) async {
    final direction = step.isAller ? 'aller' : 'retour';
    final result = await AnnotationDialog.show(
      context: context,
      lineNumber: lineNumber,
      directionLabel: direction,
      initialNote: currentNote,
      initialFlag: currentFlag,
    );
    if (result == null || !mounted) return;
    try {
      await TransportEditorService.instance.setConsultantAnnotation(
        lineNumber: lineNumber,
        direction: direction,
        note: result.note,
        flag: result.flag,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note enregistrée ✓'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Widget _pastille(String label, ValidationStatus status, AdminReview admin) {
    // Priorité d'affichage :
    //   1. rejected → rouge "À refaire" (plus critique, consultant doit agir)
    //   2. approved → vert "En prod"
    //   3. modified → orange "Envoyé"
    //   4. pending → gris
    Color bg;
    IconData? icon;
    String displayLabel = label;
    String? rejectReason;

    if (admin.status == AdminStatus.rejected) {
      bg = const Color(0xFFE53935);
      icon = Icons.replay;
      displayLabel = '$label · À refaire';
      rejectReason = admin.rejectionReason;
    } else if (admin.status == AdminStatus.approved) {
      bg = const Color(0xFF66BB6A);
      icon = Icons.check_circle;
      displayLabel = '$label · En prod';
    } else {
      switch (status) {
        case ValidationStatus.validated:
          bg = const Color(0xFF66BB6A);
          icon = Icons.check;
          break;
        case ValidationStatus.modified:
          bg = const Color(0xFFFF9800);
          icon = Icons.schedule; // en attente admin
          displayLabel = '$label · Envoyé';
          break;
        case ValidationStatus.pending:
          bg = Colors.grey.shade300;
          icon = null;
      }
    }

    final pastille = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11,
                color: bg == Colors.grey.shade300
                    ? Colors.black54
                    : Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 10,
              color: bg == Colors.grey.shade300 ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (rejectReason != null && rejectReason.isNotEmpty) {
      return Tooltip(
        message: 'Motif admin : $rejectReason',
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 6),
        child: pastille,
      );
    }
    return pastille;
  }

  Widget _colorDot(int colorValue) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }

  void _openWizard(LineMetadata m, TransportLineValidation v) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorWizardScreen(
          lineNumber: m.lineNumber,
          initialStep: v.nextPendingStep,
        ),
      ),
    );
  }
}

/* ──────────────────── DATA CLASSES ──────────────────── */

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);
}

class _AnnotatedDirection {
  final String lineNumber;
  final EditorStep step;
  final String? note;
  final ConsultantFlag? flag;
  final DateTime? updatedAt;
  _AnnotatedDirection({
    required this.lineNumber,
    required this.step,
    required this.note,
    required this.flag,
    required this.updatedAt,
  });
}

/* ──────────────────── PROFILE MENU ──────────────────── */

class _ProfileMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '—';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      tooltip: 'Compte',
      offset: const Offset(0, 48),
      icon: CircleAvatar(
        radius: 15,
        backgroundColor: Colors.white,
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connecté en tant que',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Color(0xFFE53935), size: 20),
              SizedBox(width: 10),
              Text('Se déconnecter',
                  style: TextStyle(color: Color(0xFFE53935))),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'logout') {
          await FirebaseAuth.instance.signOut();
          AdminAuthService.instance.invalidate();
          if (!context.mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/transport-login',
            (_) => false,
          );
        }
      },
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isSignedIn ? 'Accès refusé' : 'Connexion requise'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSignedIn ? Icons.lock_outline : Icons.login,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  isSignedIn
                      ? 'Cet espace est réservé au consultant terrain.'
                      : 'Espace éditeur terrain transport',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  isSignedIn
                      ? 'Le compte connecté n\'a pas le rôle `transport_editor`. '
                          'Déconnecte-toi et reconnecte-toi avec le compte '
                          'consultant fourni par Misy.'
                      : 'Connecte-toi avec le compte consultant fourni par Misy '
                          '(email + mot de passe).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                if (isSignedIn) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      AdminAuthService.instance.invalidate();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/transport-login',
                        (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Se déconnecter + reconnecter'),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/transport-login',
                      (_) => false,
                    ),
                    icon: const Icon(Icons.login),
                    label: const Text('Se connecter'),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Retour à l\'accueil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
