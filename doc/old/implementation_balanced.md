# 🎯 APPROCHE ÉQUILIBRÉE - MISY V2

## Principe : Simple mais complet

### 🎨 PHASE 1: DESIGN SYSTEM (1.5 semaine)

#### Tâche 1.1: Palette complète
**Fichier**: `/lib/constants/my_colors.dart`
```dart
// Ajouter TOUTES les couleurs (15 lignes)
static Color coralPink = const Color(0xFFFF5357);
static Color horizonBlue = const Color(0xFF286EF0);
static Color textPrimary = const Color(0xFF3C4858);
static Color backgroundLight = const Color(0xFFF9FAFB);
static Color backgroundContrast = const Color(0xFFFFFFFF);
static Color success = const Color(0xFF10B981);
static Color warning = const Color(0xFFF59E0B);
static Color error = const Color(0xFFEF4444);
static Color borderLight = const Color(0xFFE5E7EB);
```

#### Tâche 1.2: Spacing & Shadows
**Fichier**: `/lib/constants/theme_data.dart`
```dart
// Ajouter constantes d'espacement (10 lignes)
static const double spacingXs = 4.0;
static const double spacingSm = 8.0;
static const double spacingMd = 12.0;
static const double spacingLg = 16.0;
static const double spacingXl = 24.0;

// Ajouter ombres standard
static BoxShadow cardShadow = BoxShadow(
  color: Colors.black.withOpacity(0.1),
  offset: Offset(0, 4),
  blurRadius: 10,
);
```

#### Tâche 1.3: Composants de base
**Modifications dans widgets existants**:
- `/lib/widget/round_edged_button.dart` → Ajouter variantes (primary/secondary)
- `/lib/widget/custom_card.dart` → Ajouter borderRadius et shadow

### 🪟 PHASE 2: BOTTOM SHEETS COMPLETS (1.5 semaine)

#### Tâche 2.1: DraggableBottomSheet réutilisable
**Nouveau fichier minimal**: `/lib/widget/draggable_bottom_sheet.dart`
```dart
// Widget wrapper simple (30 lignes max)
class DraggableBottomSheet extends StatelessWidget {
  final Widget child;
  final double minHeight;
  final double initialHeight;
  final double maxHeight;
  
  // Utilise DraggableScrollableSheet natif
  // Ajoute borderRadius et shadow
  // Gère l'overlay automatiquement
}
```

#### Tâche 2.2: Adapter les bottom sheets existants
- Wrapper chaque bottom sheet avec le nouveau widget
- Ajouter la gestion des 3 niveaux (40%, 60%, 90%)
- Connecter avec l'overlay de la carte

### 🏠 PHASE 3: HOME DYNAMIQUE (1 semaine)

#### Tâche 3.1: Gestion des niveaux
**Fichier**: `/lib/pages/view_module/home_page.dart`
```dart
// Ajouter enum et état (10 lignes)
enum HomeLevel { low, medium, full }
HomeLevel _currentLevel = HomeLevel.low;

// Stack avec AnimatedPositioned pour chaque niveau
// Réutiliser les widgets existants dans chaque niveau
```

#### Tâche 3.2: Quick Actions avec données existantes
- Utiliser `RecentSearchProvider` pour adresses récentes
- Créer constante pour Ivato
- Utiliser analytics pour "plus recherchée"

### 💳 PHASE 4: WALLET FONCTIONNEL (1.5 semaine)

#### Tâche 4.1: Étendre WalletProvider
```dart
// Ajouter méthodes (20 lignes)
Future<void> addFunds(double amount, PaymentMethod method);
Future<void> processRefund(String transactionId, double amount);
double calculateMisyPlusCashback(double amount, String rideType);
```

#### Tâche 4.2: UI Wallet améliorée
- Design moderne avec solde prominent
- Historique des transactions
- Bouton "Ajouter des fonds" fonctionnel

### 👤 PHASE 5: SOUS-MENUS COMPLETS (1 semaine)

#### Tâche 5.1: Tous les éléments demandés
- Header complet Mon Compte
- Grille responsive pour tuiles
- États vides avec SVG simples
- Bannières promotionnelles (Image widget)

### 🚀 PHASE 6: FEATURES MINIMALES MAIS FONCTIONNELLES (2 semaines)

#### Tâche 6.1: Ride Check simple
```dart
// Service minimal (30 lignes)
class RideCheckService {
  static String generateLink(String rideId) {
    // Créer URL Firebase Dynamic Links
    return 'https://misy.page.link/track/$rideId';
  }
}
```

#### Tâche 6.2: VOIP avec package existant
- Utiliser `agora_rtc_engine` (déjà dans beaucoup d'apps)
- UI simple avec bouton d'appel
- Masquage automatique des numéros

#### Tâche 6.3: Misy+ basique mais complet
```dart
// Étendre UserModel (5 lignes)
bool isMisyPlus;
DateTime? misyPlusExpiry;
String? misyPlusPlan; // 'monthly' ou 'yearly'

// Logique cashback dans WalletProvider
```

## 📊 DÉCOUPAGE OPTIMISÉ POUR AGENTS

### Structure des tâches :
1. **Tâches atomiques** : 20-50 lignes max
2. **Fichiers existants** : 80% du temps
3. **Nouveaux fichiers** : Seulement pour composants réutilisables
4. **Tests inclus** : Chaque tâche avec son test

### Exemple de brief optimisé :
```markdown
# TÂCHE: Ajouter palette de couleurs complète

## CONTEXTE
- Sprint: Design System
- Priorité: Haute
- Dépendances: Aucune

## MODIFICATIONS
1. Fichier: `/lib/constants/my_colors.dart`
2. Ajouter 9 couleurs (voir spec)
3. Mettre à jour méthodes existantes
4. Lignes à modifier: ~15-20

## VALIDATION
- [ ] Toutes les couleurs définies
- [ ] Compatible dark theme
- [ ] Test visuel sur HomeScreen
```

## ✅ AVANTAGES DE L'APPROCHE ÉQUILIBRÉE

1. **Couverture : 85%** des requirements
2. **Simplicité maintenue** : Modifications ciblées
3. **Qualité UX** : Animations et transitions incluses
4. **Évolutivité** : Base solide pour futures améliorations
5. **Temps réaliste** : 6-7 semaines

Cette approche trouve le bon équilibre entre simplicité d'implémentation et respect des spécifications.