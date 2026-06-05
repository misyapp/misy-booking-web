import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';

/// Carte blanche centrée pour les écrans d'auth **plein-route** sur web
/// (Verify Phone Number, OTP…), reproduisant le pattern visuel de
/// [WebAuthScreen] (logo Misy, ConstrainedBox 460, Material radius 18,
/// elevation 18) — mais en page autonome sur fond [kWebPageBackground]
/// au lieu d'un dialog sur backdrop.
///
/// Les écrans gardent leur logique métier intacte : seul leur contenu
/// (`child`) est re-présenté dans la carte. Sur mobile ils conservent
/// leur Scaffold d'origine — ce shell n'est utilisé que sous `kIsWeb`.
class WebCardShell extends StatelessWidget {
  /// Contenu de la carte (le body existant de l'écran).
  final Widget child;

  /// Titre affiché sous le logo (ex. « Verify Phone Number »).
  final String? title;

  /// Action « retour » optionnelle, affichée en haut à gauche de la carte.
  final VoidCallback? onBack;

  /// Pied de carte optionnel (ex. bouton « Se déconnecter »).
  final Widget? footer;

  const WebCardShell({
    super.key,
    required this.child,
    this.title,
    this.onBack,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kWebPageBackground,
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: size.height < 700 ? 40 : 88,
            bottom: 32,
            left: 16,
            right: 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: kWebAuthCardMaxWidth),
              child: Material(
                color: Colors.white,
                elevation: 18,
                shadowColor: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(kWebCardRadius),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/icons/misy_logo_rose.png',
                              height: 56,
                            ),
                          ),
                          if (title != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              title!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          child,
                          if (footer != null) ...[
                            const SizedBox(height: 12),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                    if (onBack != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
