import 'package:flutter/material.dart';

/// Palette et constantes de la déclinaison **web desktop** de book.misy.app.
///
/// Source de vérité visuelle : la carte d'auth [WebAuthScreen] (corail Misy,
/// cartes blanches arrondies sur fond gris clair). Tout nouvel écran web
/// (cartes auth, espace compte…) doit piocher ici plutôt que redéclarer
/// ses couleurs en local.
const Color kWebCoral = Color(0xFFFF5357);
const Color kWebCoralDark = Color(0xFFD93B40);

/// Fond de page des écrans web hors carte (gris très clair, façon dashboard).
const Color kWebPageBackground = Color(0xFFF7F8FA);

/// Rayon standard des cartes web.
const double kWebCardRadius = 18;

/// Largeur max de la carte d'auth centrée (parité WebAuthScreen).
const double kWebAuthCardMaxWidth = 460;
