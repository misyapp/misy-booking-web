# 🎨 Brief Agent 1: Couleurs et Thème

## 🎯 Mission
Implémenter la nouvelle palette de couleurs et la typographie Azo Sans pour Misy V2 selon l'approche LEAN.

## 📋 Tâches assignées

### 1. Palette de couleurs (SP1.1)
**Fichier à modifier**: `/lib/constants/my_colors.dart`

**Actions LEAN**:
1. Ajouter les 9 nouvelles couleurs comme propriétés statiques
2. Mettre à jour les méthodes existantes primaryColor() et secondaryColor()
3. Ne PAS créer de nouveaux fichiers

**Code à ajouter** (~20 lignes):
```dart
// Nouvelles couleurs Misy V2
static Color coralPink = const Color(0xFFFF5357);
static Color horizonBlue = const Color(0xFF286EF0);
static Color textPrimary = const Color(0xFF3C4858);
static Color textSecondary = const Color(0xFF6B7280);
static Color backgroundLight = const Color(0xFFF9FAFB);
static Color backgroundContrast = const Color(0xFFFFFFFF);
static Color success = const Color(0xFF10B981);
static Color warning = const Color(0xFFF59E0B);
static Color error = const Color(0xFFEF4444);
static Color borderLight = const Color(0xFFE5E7EB);

// Mise à jour des méthodes existantes
static Color primaryColor() => coralPink;
static Color secondaryColor() => horizonBlue;
```

### 2. Typographie Azo Sans (SP1.2)
**Fichier à modifier**: `/lib/constants/theme_data.dart`

**Actions LEAN**:
1. Importer le package google_fonts si pas déjà fait
2. Remplacer ou modifier le TextTheme existant
3. Utiliser Azo Sans avec fallback sur Inter ou Poppins

**Code à implémenter** (~10 lignes):
```dart
import 'package:google_fonts/google_fonts.dart';

// Dans la méthode de création du theme
static TextTheme textTheme = GoogleFonts.getTextTheme(
  'Inter', // Fallback car Azo Sans non disponible dans Google Fonts
).copyWith(
  headlineLarge: TextStyle(fontWeight: FontWeight.w500), // MD
  headlineMedium: TextStyle(fontWeight: FontWeight.w500), // MD
  bodyLarge: TextStyle(fontWeight: FontWeight.w300), // Lt
  bodyMedium: TextStyle(fontWeight: FontWeight.w300), // Lt
);
```

## ✅ Checklist de validation

Avant de marquer une tâche comme complétée:

- [ ] Le code compile sans erreur
- [ ] Les modifications sont < 50 lignes au total
- [ ] Aucun nouveau fichier créé
- [ ] Les tests existants passent
- [ ] Les couleurs s'affichent correctement dans l'app
- [ ] La typographie est appliquée globalement

## 🔄 Process

1. Lire les fichiers existants pour comprendre la structure
2. Faire les modifications minimales
3. Tester localement
4. Mettre à jour `/doc/phase1_suivi/TODO.md`
5. Commit avec message: "feat(design): implement color palette and typography for Misy V2"

## ⚠️ Points d'attention

- Ne PAS refactorer le code existant
- Ne PAS ajouter de features non demandées
- Respecter exactement les valeurs hexadécimales fournies
- Si Azo Sans n'est pas disponible, utiliser Inter comme fallback
- Garder la rétrocompatibilité avec le code existant

## 📞 Support

En cas de blocage:
1. Documenter le problème dans `/doc/phase1_suivi/TODO.md`
2. Continuer avec la tâche suivante si possible
3. Notifier le coordinateur

**Temps estimé**: 2-3 heures
**Deadline**: Dans les 24h