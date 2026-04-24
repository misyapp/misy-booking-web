import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';
import 'package:rider_ride_hailing_app/services/transport_iam_service.dart';

/// Écran admin de gestion des comptes transport (IAM).
/// Accessible uniquement avec le claim `transport_admin`.
///
/// Liste les users avec claim editor/admin, permet de créer/modifier/
/// reset password/supprimer.
class IamScreen extends StatelessWidget {
  const IamScreen({super.key});

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
          return const _IamAccessDenied();
        }
        return const _IamBody();
      },
    );
  }
}

class _IamBody extends StatefulWidget {
  const _IamBody();

  @override
  State<_IamBody> createState() => _IamBodyState();
}

class _IamBodyState extends State<_IamBody> {
  List<TransportIamUser> _users = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await TransportIamService.instance.listUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  List<TransportIamUser> get _filtered {
    if (_query.isEmpty) return _users;
    final q = _query.toLowerCase();
    return _users
        .where((u) => (u.email ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IAM — Gestion des comptes transport'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildSearchBar(),
                    _buildCountBanner(),
                    Expanded(child: _buildList()),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Créer un compte'),
        onPressed: _onCreate,
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFE53935), size: 48),
            const SizedBox(height: 12),
            Text('Erreur : $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher par email…',
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
    );
  }

  Widget _buildCountBanner() {
    final total = _users.length;
    final admins = _users.where((u) => u.transportAdmin).length;
    final editors = _users.where((u) => u.transportEditor).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00897B)),
      ),
      child: Text(
        '$total compte${total > 1 ? "s" : ""} · $admins admin'
        '${admins > 1 ? "s" : ""} · $editors éditeur${editors > 1 ? "s" : ""}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildList() {
    final users = _filtered;
    if (users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucun compte.',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _buildUserCard(users[i]),
    );
  }

  Widget _buildUserCard(TransportIamUser u) {
    final isMe = u.uid == _currentUid;
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isMe
              ? const Color(0xFF00695C)
              : Colors.grey.shade300,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: u.transportAdmin
                  ? const Color(0xFF5E35B1)
                  : const Color(0xFF1565C0),
              child: Text(
                (u.email ?? '?').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          u.email ?? '(email inconnu)',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00695C),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Toi',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (u.transportAdmin)
                        _roleChip('Admin', const Color(0xFF5E35B1)),
                      if (u.transportEditor)
                        _roleChip('Éditeur', const Color(0xFF1565C0)),
                      if (u.disabled)
                        _roleChip('Désactivé', const Color(0xFFE53935)),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'roles',
                  child: Row(children: [
                    Icon(Icons.tune, size: 18),
                    SizedBox(width: 8),
                    Text('Modifier rôles'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(children: [
                    Icon(Icons.lock_reset, size: 18),
                    SizedBox(width: 8),
                    Text('Reset password'),
                  ]),
                ),
                if (!isMe)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFE53935)),
                      SizedBox(width: 8),
                      Text('Supprimer',
                          style: TextStyle(color: Color(0xFFE53935))),
                    ]),
                  ),
              ],
              onSelected: (v) => _onAction(v, u, isMe),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _onCreate() async {
    final result = await showDialog<_CreateDialogResult>(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );
    if (result == null) return;

    try {
      final created = await TransportIamService.instance.createUser(
        email: result.email,
        transportEditor: result.editor,
        transportAdmin: result.admin,
        password: result.customPassword,
      );
      if (!mounted) return;
      await _showPasswordDialog(
        title: 'Compte créé',
        email: created.email,
        password: created.password,
      );
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _onAction(
      String action, TransportIamUser u, bool isMe) async {
    switch (action) {
      case 'roles':
        await _onEditRoles(u, isMe);
        break;
      case 'reset':
        await _onResetPassword(u);
        break;
      case 'delete':
        await _onDelete(u);
        break;
    }
  }

  Future<void> _onEditRoles(TransportIamUser u, bool isMe) async {
    final result = await showDialog<_RolesDialogResult>(
      context: context,
      builder: (_) => _EditRolesDialog(user: u, isMe: isMe),
    );
    if (result == null) return;

    try {
      await TransportIamService.instance.setClaims(
        uid: u.uid,
        transportEditor: result.editor,
        transportAdmin: result.admin,
      );
      if (!mounted) return;
      _showSnack('Rôles mis à jour — le user doit se reconnecter.');
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _onResetPassword(TransportIamUser u) async {
    final confirmed = await _confirm(
      title: 'Reset password ?',
      content: 'Un nouveau mot de passe temporaire sera généré pour '
          '${u.email}. L\'ancien sera invalidé.',
      confirmLabel: 'Reset',
      confirmColor: const Color(0xFF1565C0),
    );
    if (!confirmed) return;

    try {
      final password =
          await TransportIamService.instance.resetPassword(uid: u.uid);
      if (!mounted) return;
      await _showPasswordDialog(
        title: 'Nouveau mot de passe',
        email: u.email ?? '',
        password: password,
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _onDelete(TransportIamUser u) async {
    final confirmed = await _confirm(
      title: 'Supprimer ${u.email} ?',
      content: 'Cette action est irréversible. Le compte Firebase Auth '
          'sera définitivement supprimé.',
      confirmLabel: 'Supprimer',
      confirmColor: const Color(0xFFE53935),
    );
    if (!confirmed) return;

    try {
      await TransportIamService.instance.deleteUser(uid: u.uid);
      if (!mounted) return;
      _showSnack('Compte supprimé.');
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<bool> _confirm({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _showPasswordDialog({
    required String title,
    required String email,
    required String password,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF43A047)),
          const SizedBox(width: 8),
          Text(title),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️  Ce mot de passe n\'est affiché qu\'UNE SEULE FOIS.',
              style: TextStyle(
                  color: Color(0xFFE65100), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Email : $email'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      password,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copier',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: password));
                      _showSnack('Copié dans le presse-papier.');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Transmets-le au user par un canal sécurisé '
              '(WhatsApp, SMS, pas par email).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('J\'ai copié'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFE53935),
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/* ─────────────────────────────────────────────────────────────── */

class _CreateDialogResult {
  _CreateDialogResult({
    required this.email,
    required this.editor,
    required this.admin,
    this.customPassword,
  });
  final String email;
  final bool editor;
  final bool admin;
  final String? customPassword;
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _editor = true;
  bool _admin = false;
  bool _customPwd = false;
  String? _emailError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un compte'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: const OutlineInputBorder(),
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Rôles',
                style: TextStyle(fontWeight: FontWeight.w600)),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _editor,
              onChanged: (v) => setState(() => _editor = v ?? false),
              title: const Text('Transport Editor (consultant terrain)'),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _admin,
              onChanged: (v) => setState(() => _admin = v ?? false),
              title: const Text('Transport Admin (review + IAM)'),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _customPwd,
              onChanged: (v) => setState(() => _customPwd = v ?? false),
              title: const Text('Mot de passe personnalisé'),
              subtitle: const Text(
                  'Sinon, un mot de passe aléatoire sera généré.',
                  style: TextStyle(fontSize: 11)),
            ),
            if (_customPwd) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _pwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe (min 8 chars)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00695C),
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Créer'),
        ),
      ],
    );
  }

  void _submit() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Email invalide');
      return;
    }
    if (!_editor && !_admin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Au moins un rôle requis.'),
        backgroundColor: Color(0xFFE53935),
      ));
      return;
    }
    if (_customPwd && _pwdCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mot de passe trop court (min 8 caractères).'),
        backgroundColor: Color(0xFFE53935),
      ));
      return;
    }

    Navigator.of(context).pop(_CreateDialogResult(
      email: email,
      editor: _editor,
      admin: _admin,
      customPassword: _customPwd ? _pwdCtrl.text : null,
    ));
  }
}

/* ─────────────────────────────────────────────────────────────── */

class _RolesDialogResult {
  _RolesDialogResult({required this.editor, required this.admin});
  final bool editor;
  final bool admin;
}

class _EditRolesDialog extends StatefulWidget {
  const _EditRolesDialog({required this.user, required this.isMe});
  final TransportIamUser user;
  final bool isMe;

  @override
  State<_EditRolesDialog> createState() => _EditRolesDialogState();
}

class _EditRolesDialogState extends State<_EditRolesDialog> {
  late bool _editor;
  late bool _admin;

  @override
  void initState() {
    super.initState();
    _editor = widget.user.transportEditor;
    _admin = widget.user.transportAdmin;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modifier rôles — ${widget.user.email ?? widget.user.uid}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _editor,
              onChanged: (v) => setState(() => _editor = v ?? false),
              title: const Text('Transport Editor'),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _admin,
              onChanged: widget.isMe
                  ? null
                  : (v) => setState(() => _admin = v ?? false),
              title: const Text('Transport Admin'),
              subtitle: widget.isMe
                  ? const Text(
                      'Tu ne peux pas retirer ton propre rôle admin.',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFFE65100)))
                  : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'Le user devra se déconnecter/reconnecter pour que les '
              'nouveaux rôles prennent effet.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00695C),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (!_editor && !_admin) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Au moins un rôle requis (utilise « Supprimer » sinon).'),
                backgroundColor: Color(0xFFE53935),
              ));
              return;
            }
            Navigator.of(context)
                .pop(_RolesDialogResult(editor: _editor, admin: _admin));
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/* ─────────────────────────────────────────────────────────────── */

class _IamAccessDenied extends StatelessWidget {
  const _IamAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accès refusé'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Seuls les comptes avec le claim `transport_admin` peuvent '
                'gérer les comptes transport.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Se connecter'),
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/transport-login', (_) => false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
