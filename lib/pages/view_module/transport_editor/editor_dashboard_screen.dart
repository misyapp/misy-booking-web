import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/models/transport_line_validation.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/login_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/editor_new_line_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/editor_wizard_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/transport_editor/widgets/tutorial_helpers.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';
import 'package:rider_ride_hailing_app/services/transport_editor_service.dart';
import 'package:rider_ride_hailing_app/services/transport_lines_service.dart';
import 'package:showcaseview/showcaseview.dart';

/// Dashboard de l'éditeur terrain : liste des lignes avec pastilles de
/// validation par étape. Tri : non vérifiées d'abord, puis en cours,
/// puis entièrement validées.
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
  final GlobalKey _fabKey = GlobalKey();

  String _query = '';
  List<LineMetadata> _allMeta = [];
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    TutorialHelper.autoStartOnce(
      context: context,
      tourId: 'dashboard_v1',
      keys: [_searchKey, _cardKey, _pastillesKey, _fabKey],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditeur terrain transport'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Revoir le tuto',
            icon: const Icon(Icons.school_outlined),
            onPressed: () async {
              await TutorialHelper.reset('dashboard_v1');
              if (!mounted) return;
              ShowCaseWidget.of(context).startShowCase(
                [_searchKey, _cardKey, _pastillesKey, _fabKey],
              );
            },
          ),
        ],
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Map<String, TransportLineValidation>>(
              stream: TransportEditorService.instance.streamAllValidations(),
              builder: (ctx, snap) {
                final validations = snap.data ?? {};
                final filtered = _allMeta.where((m) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return m.lineNumber.toLowerCase().contains(q) ||
                      m.displayName.toLowerCase().contains(q);
                }).toList();
                filtered.sort((a, b) => _sortScore(a, validations)
                    .compareTo(_sortScore(b, validations)));

                return Column(
                  children: [
                    _buildSearchBar(),
                    _buildProgressBanner(validations),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final m = filtered[i];
                          final v = validations[m.lineNumber] ??
                              TransportLineValidation.empty(m.lineNumber);
                          return _buildCard(m, v, i);
                        },
                      ),
                    ),
                  ],
                );
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

  int _sortScore(
      LineMetadata m, Map<String, TransportLineValidation> validations) {
    final v = validations[m.lineNumber];
    if (v == null) return 0;
    if (v.isFullyValidated) return 2;
    if (v.completedCount > 0) return 1;
    return 0;
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TutoStep(
        stepKey: _searchKey,
        title: 'Rechercher une ligne',
        description:
            'Filtre par numéro (ex: « 129 ») ou par nom. Utile pour retrouver '
            'rapidement la ligne en cours de vérification.',
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher une ligne (numéro, nom…)',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
    );
  }

  Widget _buildProgressBanner(
      Map<String, TransportLineValidation> validations) {
    if (_allMeta.isEmpty) return const SizedBox.shrink();
    final total = _allMeta.length;
    final done = validations.values.where((v) => v.isFullyValidated).length;
    final pct = (done / total * 100).round();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8BC34A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF558B2F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Progression : $done / $total lignes entièrement validées '
              '($pct%)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      LineMetadata m, TransportLineValidation v, int index) {
    final card = Card(
      elevation: 2,
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _colorDot(m.colorValue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ligne ${m.lineNumber} · ${m.transportType}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
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
        _pastille('Aller', v.aller),
        const SizedBox(width: 6),
        _pastille('Retour', v.retour),
      ],
    );
    if (withTutoKey) {
      return TutoStep(
        stepKey: _pastillesKey,
        title: 'État des 2 vérifications',
        description:
            'Gris = à vérifier, vert = validé tel quel, orange = modifié. '
            'Les 2 pastilles : tracé aller (avec ses arrêts) et tracé retour '
            '(avec ses arrêts).',
        child: pastilles,
      );
    }
    return pastilles;
  }

  Widget _pastille(String label, ValidationStatus status) {
    Color bg;
    IconData? icon;
    switch (status) {
      case ValidationStatus.validated:
        bg = const Color(0xFF66BB6A);
        icon = Icons.check;
        break;
      case ValidationStatus.modified:
        bg = const Color(0xFFFF9800);
        icon = Icons.edit;
        break;
      case ValidationStatus.pending:
        bg = Colors.grey.shade300;
        icon = null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: status == ValidationStatus.pending
                  ? Colors.black87
                  : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const LoginPage()),
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
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
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
