import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/services/admin_auth_service.dart';

/// Page de login unique pour les rôles `transport_editor` et `transport_admin`.
///
/// Après authentification Firebase email/password, lit les custom claims
/// et redirige vers `/transport-admin` (priorité admin) ou `/transport-editor`.
/// Si aucun claim n'est présent, déconnecte et affiche un message d'erreur.
class TransportLoginScreen extends StatefulWidget {
  const TransportLoginScreen({super.key});

  @override
  State<TransportLoginScreen> createState() => _TransportLoginScreenState();
}

class _TransportLoginScreenState extends State<TransportLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AdminAuthService.instance.invalidate();

      final isAdmin =
          await AdminAuthService.instance.isTransportAdmin(forceRefresh: true);
      final isEditor =
          await AdminAuthService.instance.isTransportEditor(forceRefresh: true);

      if (!mounted) return;

      if (isAdmin) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/transport-admin',
          (_) => false,
        );
        return;
      }
      if (isEditor) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/transport-editor',
          (_) => false,
        );
        return;
      }

      await FirebaseAuth.instance.signOut();
      AdminAuthService.instance.invalidate();
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Ce compte n\'a ni le rôle transport_editor ni transport_admin.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _mapAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur inattendue : $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessaie dans quelques minutes.';
      case 'network-request-failed':
        return 'Pas de connexion réseau.';
      default:
        return e.message ?? 'Échec de la connexion (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildEmailField(),
                      const SizedBox(height: 14),
                      _buildPasswordField(),
                      const SizedBox(height: 8),
                      if (_errorMessage != null) _buildErrorBanner(),
                      const SizedBox(height: 16),
                      _buildSubmitButton(),
                      const SizedBox(height: 14),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFF1565C0),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.directions_bus,
              color: Colors.white, size: 32),
        ),
        const SizedBox(height: 14),
        const Text(
          'Espace Transport',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Connexion consultant terrain ou admin',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email, AutofillHints.username],
      textInputAction: TextInputAction.next,
      enabled: !_loading,
      decoration: InputDecoration(
        labelText: 'Email',
        prefixIcon: const Icon(Icons.mail_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Email requis.';
        if (!v.contains('@') || !v.contains('.')) {
          return 'Format email invalide.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      enabled: !_loading,
      onFieldSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'Mot de passe',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Afficher' : 'Masquer',
          icon: Icon(_obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Mot de passe requis.';
        return null;
      },
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE53935)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFE53935), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                  color: Color(0xFFC62828), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _loading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: _loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Text(
              'Se connecter',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'Accès réservé aux comptes avec le claim `transport_editor` '
      'ou `transport_admin`.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
    );
  }
}
