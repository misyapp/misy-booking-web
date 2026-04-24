import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider_ride_hailing_app/models/transport_line.dart';
import 'package:rider_ride_hailing_app/models/transport_line_validation.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/osm_base_map.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'dart:convert';

/// UI admin pour reviewer le travail des consultants par direction
/// (aller / retour). Accessible uniquement avec le claim `transport_admin`.
///
/// Liste les directions `modified` par les consultants en attente de review.
/// Filtre par consultant. Actions : Valider → publie dans Firestore prod.
/// Demander refaire → remet consultant à pending + enregistre motif.
class AdminReviewScreen extends StatelessWidget {
  const AdminReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminAuthService.instance.isTransportAdmin(forceRefresh: true),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data != true) {
          return const _AdminAccessDenied();
        }
        return const _AdminReviewBody();
      },
    );
  }
}

class _AdminReviewBody extends StatefulWidget {
  const _AdminReviewBody();

  @override
  State<_AdminReviewBody> createState() => _AdminReviewBodyState();
}

class _AdminReviewBodyState extends State<_AdminReviewBody> {
  String? _filterEmail;
  List<LineMetadata> _allMeta = [];
  bool _loadingMeta = true;
  Future<List<TransportLineGroup>>? _linesFuture;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _linesFuture = TransportLinesService.instance.loadAllLines();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review admin — Transport'),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Gérer les comptes (IAM)',
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/transport-iam'),
          ),
          IconButton(
            tooltip: 'Aller à l\'éditeur terrain',
            icon: const Icon(Icons.edit_location_alt_outlined),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              '/transport-editor',
              (_) => false,
            ),
          ),
          _AdminProfileMenu(),
          const SizedBox(width: 4),
        ],
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Map<String, TransportLineValidation>>(
              stream:
                  TransportEditorService.instance.streamAllValidations(),
              builder: (ctx, snap) {
                final validations = snap.data ?? {};
                final items = _buildReviewItems(validations);
                final emails = _distinctEmails(items);
                final filtered = _filterEmail == null
                    ? items
                    : items
                        .where((i) => i.consultantEmail == _filterEmail)
                        .toList();

                return LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth >= 1100;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildKpiRow(validations, items),
                          const SizedBox(height: 16),
                          if (isWide)
                            SizedBox(
                              height: 520,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 6, child: _buildMapCard()),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 4,
                                    child: _buildPendingCard(
                                        emails, items.length,
                                        filtered.length, filtered),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            SizedBox(height: 380, child: _buildMapCard()),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 460,
                              child: _buildPendingCard(
                                  emails, items.length, filtered.length,
                                  filtered),
                            ),
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
                                    child: _buildConsultantsCard(validations),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _buildActivityCard(),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            SizedBox(
                              height: 360,
                              child: _buildConsultantsCard(validations),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(height: 360, child: _buildActivityCard()),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  /* ──────────────────── KPI ROW ──────────────────── */

  Widget _buildKpiRow(
      Map<String, TransportLineValidation> validations, List<ReviewItem> items) {
    final total = _allMeta.length;
    final published =
        validations.values.where((v) => v.isPublished).length;
    final pending = items
        .where((i) => i.adminStatus == AdminStatus.pending)
        .length;
    final rejected = items
        .where((i) => i.adminStatus == AdminStatus.rejected)
        .length;
    final activeConsultants = _distinctEmails(items).length;

    final kpis = [
      _Kpi('Lignes totales', '$total', Icons.directions_bus,
          const Color(0xFF5E35B1)),
      _Kpi('En prod', '$published', Icons.check_circle,
          const Color(0xFF43A047)),
      _Kpi('En attente', '$pending', Icons.pending_actions,
          const Color(0xFFFB8C00)),
      _Kpi('Rejetées', '$rejected', Icons.replay,
          const Color(0xFFE53935)),
      _Kpi('Consultants actifs', '$activeConsultants', Icons.people,
          const Color(0xFF1565C0)),
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
                Text(
                  kpi.value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  kpi.label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ──────────────────── MAP CARD ──────────────────── */

  Widget _buildMapCard() {
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
          return _buildMap(snap.data!);
        },
      ),
    );
  }

  Widget _buildMap(List<TransportLineGroup> groups) {
    final polylines = <Polyline>[];
    for (final g in groups) {
      final meta = _metaFor(g.lineNumber);
      final color =
          meta != null ? Color(meta.colorValue) : const Color(0xFF5E35B1);
      for (final line in g.lines) {
        if (line.coordinates.length < 2) continue;
        polylines.add(Polyline(
          points: line.coordinates
              .map((c) => LatLng(c.latitude, c.longitude))
              .toList(),
          color: color.withOpacity(0.75),
          strokeWidth: 3,
        ));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(-18.8792, 47.5079), // Tana
          initialZoom: 12,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'app.misy.book',
          ),
          PolylineLayer(polylines: polylines),
        ],
      ),
    );
  }

  /* ──────────────────── PENDING QUEUE CARD ──────────────────── */

  Widget _buildPendingCard(
      List<String> emails, int total, int shown, List<ReviewItem> filtered) {
    return _dashboardCard(
      title: 'File de review',
      icon: Icons.inbox_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF5E35B1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$shown / $total',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
      child: Column(
        children: [
          _buildFilterBar(emails, total, shown),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildReviewCard(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  /* ──────────────────── CONSULTANTS CARD ──────────────────── */

  Widget _buildConsultantsCard(
      Map<String, TransportLineValidation> validations) {
    final stats = <String, _ConsultantStat>{};
    for (final v in validations.values) {
      final email = v.updatedByEmail;
      if (email == null || email.isEmpty) continue;
      final s = stats.putIfAbsent(email, () => _ConsultantStat(email));
      for (final step in EditorStep.values) {
        final consultant = v.statusFor(step);
        final admin = v.adminReviewFor(step);
        if (consultant == ValidationStatus.modified &&
            admin.status != AdminStatus.approved) {
          s.pending++;
        }
        if (admin.status == AdminStatus.approved) s.approved++;
        if (admin.status == AdminStatus.rejected) s.rejected++;
      }
      if (v.updatedAt != null &&
          (s.lastActivity == null ||
              v.updatedAt!.isAfter(s.lastActivity!))) {
        s.lastActivity = v.updatedAt;
      }
    }

    final list = stats.values.toList()
      ..sort((a, b) {
        final ad = a.lastActivity?.millisecondsSinceEpoch ?? 0;
        final bd = b.lastActivity?.millisecondsSinceEpoch ?? 0;
        return bd.compareTo(ad);
      });

    return _dashboardCard(
      title: 'Consultants',
      icon: Icons.people_outline,
      child: list.isEmpty
          ? const Center(
              child: Text('Aucune activité consultant enregistrée.',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (ctx, i) => _buildConsultantRow(list[i]),
            ),
    );
  }

  Widget _buildConsultantRow(_ConsultantStat s) {
    final initial =
        s.email.isNotEmpty ? s.email[0].toUpperCase() : '?';
    final dateStr = s.lastActivity == null
        ? '—'
        : DateFormat('dd/MM HH:mm').format(s.lastActivity!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1565C0),
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _miniCount(s.pending, 'en attente',
                        const Color(0xFFFB8C00)),
                    const SizedBox(width: 8),
                    _miniCount(
                        s.approved, 'validés', const Color(0xFF43A047)),
                    const SizedBox(width: 8),
                    _miniCount(
                        s.rejected, 'rejetés', const Color(0xFFE53935)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(dateStr,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _miniCount(int count, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$count $label',
            style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  /* ──────────────────── ACTIVITY CARD (audit log) ──────────────────── */

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

  /* ──────────────────── CARD WRAPPER ──────────────────── */

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
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF5E35B1)),
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

  /// Aplatit les validations en items "une direction à reviewer".
  /// Critère : consultant_status == `modified` et admin_status != `approved`.
  List<ReviewItem> _buildReviewItems(
      Map<String, TransportLineValidation> validations) {
    final items = <ReviewItem>[];
    for (final v in validations.values) {
      for (final step in EditorStep.values) {
        final consultant = v.statusFor(step);
        final admin = v.adminReviewFor(step);
        if (consultant != ValidationStatus.modified) continue;
        if (admin.status == AdminStatus.approved) continue;
        items.add(ReviewItem(
          lineNumber: v.lineNumber,
          direction: step.isAller ? 'aller' : 'retour',
          consultantEmail: v.updatedByEmail,
          consultantStatus: consultant,
          adminStatus: admin.status,
          rejectionReason: admin.rejectionReason,
          updatedAt: v.updatedAt,
        ));
      }
    }
    // Tri : pending avant rejected (rejected déjà traité une fois), puis par
    // date décroissante (plus récent en haut).
    items.sort((a, b) {
      final as = a.adminStatus == AdminStatus.pending ? 0 : 1;
      final bs = b.adminStatus == AdminStatus.pending ? 0 : 1;
      if (as != bs) return as.compareTo(bs);
      final ad = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final bd = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bd.compareTo(ad);
    });
    return items;
  }

  List<String> _distinctEmails(List<ReviewItem> items) {
    final set = <String>{};
    for (final i in items) {
      if (i.consultantEmail != null && i.consultantEmail!.isNotEmpty) {
        set.add(i.consultantEmail!);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  Widget _buildFilterBar(
      List<String> emails, int total, int shown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: Color(0xFF5E35B1)),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _filterEmail,
              underline: const SizedBox.shrink(),
              hint: const Text('Tous les consultants',
                  style: TextStyle(fontSize: 12)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tous les consultants',
                      style: TextStyle(fontSize: 12)),
                ),
                for (final e in emails)
                  DropdownMenuItem<String?>(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 12)),
                  ),
              ],
              onChanged: (v) => setState(() => _filterEmail = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewItem item) {
    final meta = _metaFor(item.lineNumber);
    final title = meta != null
        ? '${meta.displayName} — ${item.direction}'
        : 'Ligne ${item.lineNumber} — ${item.direction}';
    final isRejectedBefore = item.adminStatus == AdminStatus.rejected;
    final dateStr = item.updatedAt == null
        ? ''
        : DateFormat('dd/MM/yyyy HH:mm').format(item.updatedAt!);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isRejectedBefore
              ? const Color(0xFFE57373)
              : Colors.grey.shade300,
          width: isRejectedBefore ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetail(item, meta),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (meta != null)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(meta.colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  if (meta != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  _buildAdminBadge(item.adminStatus),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Par ${item.consultantEmail ?? "inconnu"}'
                '${dateStr.isEmpty ? "" : " · $dateStr"}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              if (isRejectedBefore && item.rejectionReason != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Motif précédent : ${item.rejectionReason}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFC62828)),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openDetail(item, meta),
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Voir sur carte'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminBadge(AdminStatus status) {
    Color bg;
    String label;
    switch (status) {
      case AdminStatus.pending:
        bg = const Color(0xFF9E9E9E);
        label = 'À reviewer';
        break;
      case AdminStatus.rejected:
        bg = const Color(0xFFE53935);
        label = 'Rejeté (2e essai)';
        break;
      case AdminStatus.approved:
        bg = const Color(0xFF43A047);
        label = 'Validé';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _openDetail(ReviewItem item, LineMetadata? meta) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewDetailScreen(item: item, meta: meta),
      ),
    );
  }
}

/// Représente une direction à reviewer (ligne + aller/retour).
class ReviewItem {
  final String lineNumber;
  final String direction; // 'aller' | 'retour'
  final String? consultantEmail;
  final ValidationStatus consultantStatus;
  final AdminStatus adminStatus;
  final String? rejectionReason;
  final DateTime? updatedAt;

  const ReviewItem({
    required this.lineNumber,
    required this.direction,
    required this.consultantEmail,
    required this.consultantStatus,
    required this.adminStatus,
    required this.rejectionReason,
    required this.updatedAt,
  });
}

// ─────────────────────── Detail screen ───────────────────────

/// Écran détail : carte avec la FC éditée + fantôme de l'asset bundlé
/// actuel pour comparaison visuelle. Boutons Valider / Demander refaire.
class ReviewDetailScreen extends StatefulWidget {
  final ReviewItem item;
  final LineMetadata? meta;

  const ReviewDetailScreen({super.key, required this.item, this.meta});

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  final MapController _mapController = MapController();
  Map<String, dynamic>? _editedFc;
  Map<String, dynamic>? _bundledFc;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBoth();
  }

  Future<void> _loadBoth() async {
    try {
      final doc = await TransportEditorService.instance
          .loadOrBootstrap(widget.item.lineNumber);
      final dir = doc[widget.item.direction] as Map<String, dynamic>?;
      final fc = dir?['feature_collection'] as Map<String, dynamic>?;

      Map<String, dynamic>? bundled;
      final route = widget.item.direction == 'aller'
          ? widget.meta?.aller
          : widget.meta?.retour;
      if (route?.assetPath != null) {
        try {
          final raw = await rootBundle.loadString(route!.assetPath!);
          bundled = json.decode(raw) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _editedFc = fc;
        _bundledFc = bundled;
        _loading = false;
      });
      _fitToEdited();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Chargement KO: $e';
        _loading = false;
      });
    }
  }

  List<LatLng> _extractLineString(Map<String, dynamic>? fc) {
    if (fc == null) return const [];
    final pts = <LatLng>[];
    for (final f in (fc['features'] as List? ?? [])) {
      final g = f['geometry'] as Map?;
      if (g == null) continue;
      if (g['type'] == 'LineString') {
        for (final c in (g['coordinates'] as List? ?? [])) {
          pts.add(LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ));
        }
      }
    }
    return pts;
  }

  List<({LatLng pos, String name})> _extractStops(
      Map<String, dynamic>? fc) {
    if (fc == null) return const [];
    final stops = <({LatLng pos, String name})>[];
    for (final f in (fc['features'] as List? ?? [])) {
      final g = f['geometry'] as Map?;
      if (g == null || g['type'] != 'Point') continue;
      final props = (f['properties'] as Map?) ?? const {};
      if (props['type'] == 'waypoint') continue;
      final c = g['coordinates'] as List;
      stops.add((
        pos: LatLng(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        ),
        name: (props['name'] as String?) ?? '',
      ));
    }
    return stops;
  }

  void _fitToEdited() {
    final pts = [
      ..._extractLineString(_editedFc),
      ..._extractStops(_editedFc).map((e) => e.pos),
    ];
    if (pts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(50),
        ));
      } catch (_) {}
    });
  }

  Color get _lineColor {
    if (widget.meta != null) return Color(widget.meta!.colorValue);
    return const Color(0xFF1565C0);
  }

  Future<void> _approve() async {
    if (_editedFc == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Valider cette direction ?'),
        content: Text(
            'La direction ${widget.item.direction} de la ligne ${widget.item.lineNumber} '
            'sera publiée en prod (Firestore). L\'app la consommera immédiatement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      await TransportEditorService.instance.approveDirection(
        lineNumber: widget.item.lineNumber,
        direction: widget.item.direction,
        featureCollection: _editedFc!,
        lineMetadata: widget.meta == null
            ? null
            : {
                'display_name': widget.meta!.displayName,
                'transport_type': widget.meta!.transportType,
                'color': widget.meta!.colorHex,
              },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Direction publiée en prod ✓')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _reject() async {
    final reason = await _promptReason();
    if (reason == null || reason.trim().isEmpty) return;
    if (!mounted) return;
    setState(() => _acting = true);
    try {
      await TransportEditorService.instance.rejectDirection(
        lineNumber: widget.item.lineNumber,
        direction: widget.item.direction,
        reason: reason.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande de refaire envoyée au consultant')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<String?> _promptReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Demander un refaire'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Motif obligatoire — visible par le consultant sur son dashboard.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Ex: le tracé ne passe pas par l\'arrêt X, '
                      'le terminus est mal placé, …',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(c, v);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editedPts = _extractLineString(_editedFc);
    final editedStops = _extractStops(_editedFc);
    final bundledPts = _extractLineString(_bundledFc);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review — Ligne ${widget.item.lineNumber} (${widget.item.direction})',
        ),
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Row(
                  children: [
                    SizedBox(width: 320, child: _buildSidebar(editedStops)),
                    Expanded(
                      child: OsmBaseMap(
                        controller: _mapController,
                        children: [
                          // Bundled (ref prod actuelle) en gris semi-transparent
                          if (bundledPts.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: bundledPts,
                                  strokeWidth: 4,
                                  color: const Color(0xFF888888).withOpacity(0.35),
                                  borderStrokeWidth: 1,
                                  borderColor: Colors.white.withOpacity(0.5),
                                ),
                              ],
                            ),
                          // Édité (proposé par le consultant) en couleur de ligne
                          if (editedPts.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: editedPts,
                                  strokeWidth: 5,
                                  color: _lineColor,
                                  borderStrokeWidth: 2,
                                  borderColor: Colors.white,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              for (int i = 0; i < editedStops.length; i++)
                                Marker(
                                  point: editedStops[i].pos,
                                  width: 28,
                                  height: 28,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _lineColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSidebar(List<({LatLng pos, String name})> stops) {
    return Material(
      color: const Color(0xFFFAFAFA),
      elevation: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 4,
                      color: const Color(0xFF888888).withOpacity(0.35),
                    ),
                    const SizedBox(width: 8),
                    const Text('Prod actuelle (asset bundlé)',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 20, height: 5, color: _lineColor),
                    const SizedBox(width: 8),
                    Text('Édition proposée',
                        style: TextStyle(
                            fontSize: 12,
                            color: _lineColor,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consultant : ${widget.item.consultantEmail ?? "?"}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 4),
                Text('Vertices : ${_extractLineString(_editedFc).length}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black87)),
                Text('Arrêts : ${stops.length}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              itemCount: stops.length,
              itemBuilder: (ctx, i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _lineColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(stops[i].name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _acting ? null : _reject,
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Demander refaire'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _acting ? null : _approve,
                    icon: _acting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Empty state ───────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Rien à reviewer pour le moment.',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Les directions éditées par les consultants apparaîtront ici.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AdminProfileMenu extends StatelessWidget {
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
            color: Color(0xFF5E35B1),
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

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied();

  @override
  Widget build(BuildContext context) {
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isSignedIn ? 'Accès refusé' : 'Connexion requise'),
        backgroundColor: const Color(0xFF5E35B1),
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
                Icon(isSignedIn ? Icons.lock_outline : Icons.login,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  isSignedIn
                      ? 'Cet espace est réservé à l\'admin transport.'
                      : 'Connecte-toi avec un compte admin transport.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                if (!isSignedIn)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Se connecter'),
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/transport-login',
                      (_) => false,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Se déconnecter + reconnecter'),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      AdminAuthService.instance.invalidate();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/transport-login',
                        (_) => false,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Kpi {
  _Kpi(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _ConsultantStat {
  _ConsultantStat(this.email);
  final String email;
  int pending = 0;
  int approved = 0;
  int rejected = 0;
  DateTime? lastActivity;
}
