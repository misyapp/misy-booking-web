import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/pages/view_module/home_screen_web.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';

/// Écran d'entrée pour le Web
/// Affiche directement HomeScreenWeb tout en initialisant l'authentification en arrière-plan
class WebEntryScreen extends StatefulWidget {
  const WebEntryScreen({super.key});

  @override
  State<WebEntryScreen> createState() => _WebEntryScreenState();
}

class _WebEntryScreenState extends State<WebEntryScreen> {
  @override
  void initState() {
    super.initState();

    // Initialiser l'authentification en arrière-plan après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }

  Future<void> _initializeAuth() async {
    try {
      final auth = Provider.of<CustomAuthProvider>(context, listen: false);
      // Appeler splashAuthentication - cela initialise tout
      // Sur le web, l'utilisateur est déjà sur HomeScreenWeb
      auth.splashAuthentication(context);
    } catch (e) {
      // Ignorer les erreurs d'auth sur le web - l'utilisateur peut continuer sans être connecté
      debugPrint('Web auth init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Afficher directement HomeScreenWeb
    return const HomeScreenWeb();
  }
}
