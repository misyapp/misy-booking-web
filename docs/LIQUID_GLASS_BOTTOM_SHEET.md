# Liquid Glass Bottom Sheet - Guide d'implémentation

## Vue d'ensemble

Bottom sheet à 3 états avec animation fluide style iOS "Liquid Glass". La sheet suit le doigt de l'utilisateur pendant le drag et snap vers l'état le plus proche au relâchement.

## Les 3 États

| État | Nom | Description | Hauteur |
|------|-----|-------------|---------|
| 0 | **Collapsed** | Petite bulle flottante | 80px fixe |
| 1 | **Intermediate** | Bulle moyenne avec infos | ~38% écran |
| 2 | **Expanded** | Sheet plein écran | 90% écran |

## Variables de contrôle

```dart
// État actuel (0, 1, 2)
int _sheetState = 1;

// Position continue (0.0 = collapsed, 0.5 = intermediate, 1.0 = expanded)
double _sheetExtent = 0.5;

// Constantes
final double _collapsedHeight = 80.0;
final double _expandedHeightRatio = 0.90; // 90% de l'écran
const double minTopRadius = 40.0; // Rayon coins en position expanded
```

## Logique d'interpolation

La magie est dans l'interpolation continue entre les états :

```dart
final screenHeight = MediaQuery.of(context).size.height;
final expandedHeight = screenHeight * _expandedHeightRatio;
final intermediateHeight = screenHeight * 0.38;

double currentHeight;
double currentMargin;
double currentBottomMargin;
double currentOpacity;
double currentTopBorderRadius;
double currentBottomBorderRadius;

if (_sheetExtent <= 0.5) {
  // Transition collapsed (0) → intermediate (0.5)
  final t = _sheetExtent / 0.5; // 0 à 1
  currentHeight = _collapsedHeight + (intermediateHeight - _collapsedHeight) * t;
  currentMargin = 12; // Marge égale sur les côtés
  currentBottomMargin = 12; // Marge égale en bas
  currentTopBorderRadius = 40; // Même arrondi que expanded
  currentBottomBorderRadius = 40; // Bulle flottante
  currentOpacity = 0.96;
} else {
  // Transition intermediate (0.5) → expanded (1.0)
  final t = (_sheetExtent - 0.5) / 0.5; // 0 à 1
  currentHeight = intermediateHeight + (expandedHeight - intermediateHeight) * t;
  currentMargin = 12 * (1 - t); // 12 → 0
  currentBottomMargin = 12 * (1 - t); // 12 → 0
  currentTopBorderRadius = 40; // Constant
  currentBottomBorderRadius = 40 * (1 - t); // 40 → 0
  currentOpacity = 0.96 + (0.04 * t); // 0.96 → 1.0
}

// BorderRadius avec coins différents haut/bas
final borderRadius = BorderRadius.only(
  topLeft: Radius.circular(currentTopBorderRadius),
  topRight: Radius.circular(currentTopBorderRadius),
  bottomLeft: Radius.circular(currentBottomBorderRadius),
  bottomRight: Radius.circular(currentBottomBorderRadius),
);
```

## Gestion des gestes

```dart
GestureDetector(
  onVerticalDragUpdate: (details) {
    setState(() {
      // Le sheet suit le doigt
      _sheetExtent -= details.primaryDelta! / (screenHeight * 0.5);
      _sheetExtent = _sheetExtent.clamp(0.0, 1.0);

      // Mettre à jour l'état pour le contenu
      if (_sheetExtent < 0.25) {
        _sheetState = 0;
      } else if (_sheetExtent < 0.75) {
        _sheetState = 1;
      } else {
        _sheetState = 2;
      }
    });
  },
  onVerticalDragEnd: (details) {
    // Snap vers l'état le plus proche
    setState(() {
      if (_sheetExtent < 0.25) {
        _sheetState = 0;
        _sheetExtent = 0.0;
      } else if (_sheetExtent < 0.75) {
        _sheetState = 1;
        _sheetExtent = 0.5;
      } else {
        _sheetState = 2;
        _sheetExtent = 1.0;
      }
    });
  },
  onTap: () {
    // Cycle vers l'état suivant au tap
    setState(() {
      if (_sheetState == 0) {
        _sheetState = 1;
        _sheetExtent = 0.5;
      } else if (_sheetState == 1) {
        _sheetState = 2;
        _sheetExtent = 1.0;
      }
    });
  },
  child: // ... votre widget
)
```

## Style visuel

### Container principal

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeOutCubic,
  decoration: BoxDecoration(
    // Blanc légèrement bleuté
    color: const Color(0xFFF5F8FF).withValues(alpha: currentOpacity),
    borderRadius: borderRadius,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, -4),
      ),
    ],
  ),
  child: _buildSheetContent(),
)
```

### Positionnement

```dart
Positioned(
  left: currentMargin,
  right: currentMargin,
  bottom: currentBottomMargin,
  height: currentHeight,
  child: // ... GestureDetector + AnimatedContainer
)
```

## Contenu selon l'état

```dart
Widget _buildSheetContent() {
  switch (_sheetState) {
    case 0:
      return _buildCollapsedContent();  // Avatar + statut court
    case 1:
      return _buildIntermediateContent(); // Infos moyennes
    case 2:
      return _buildExpandedContent(); // Toutes les infos
    default:
      return _buildIntermediateContent();
  }
}
```

### Collapsed (État 0) - Bulle minimale

```dart
Widget _buildCollapsedContent() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(
      children: [
        // Handle bar centré
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        // Contenu minimal (avatar + texte)
        Row(
          children: [
            CircleAvatar(radius: 20, ...),
            const SizedBox(width: 12),
            Text("Statut court"),
          ],
        ),
      ],
    ),
  );
}
```

## Boutons flottants

Pour les boutons au-dessus de la sheet, calculer leur position :

```dart
double _calculateSheetHeight() {
  final screenHeight = MediaQuery.of(context).size.height;
  final expandedHeight = screenHeight * _expandedHeightRatio;
  final intermediateHeight = screenHeight * 0.38;

  if (_sheetExtent <= 0.5) {
    final t = _sheetExtent / 0.5;
    return _collapsedHeight + (intermediateHeight - _collapsedHeight) * t;
  } else {
    final t = (_sheetExtent - 0.5) / 0.5;
    return intermediateHeight + (expandedHeight - intermediateHeight) * t;
  }
}

// Positionnement du bouton
Positioned(
  right: 24,
  bottom: _calculateSheetHeight() + 32, // 32px au-dessus de la sheet
  child: // ... bouton
)
```

### Masquer les boutons en expanded

```dart
AnimatedOpacity(
  duration: const Duration(milliseconds: 200),
  opacity: _sheetExtent > 0.8 ? 0.0 : 1.0,
  child: IgnorePointer(
    ignoring: _sheetExtent > 0.8,
    child: // ... bouton
  ),
)
```

## Style des boutons (Liquid Glass simple)

```dart
Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: Colors.white,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 10,
        spreadRadius: 0,
      ),
    ],
  ),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Center(
        child: Icon(icon, color: MyColors.primaryColor, size: 22),
      ),
    ),
  ),
)
```

## Notes importantes

### Limitations Flutter

⚠️ **BackdropFilter + ClipRRect** crée une bordure visible. Pour un effet "blur/givré" parfait style Apple, il faudrait du code natif. La solution actuelle utilise un fond semi-transparent sans blur.

### Valeurs recommandées

| Propriété | Collapsed/Intermediate | Expanded |
|-----------|----------------------|----------|
| Opacité | 96% | 100% |
| Marge latérale | 12px | 0px |
| Marge bas | 12px | 0px |
| Rayon coins haut | 40px | 40px |
| Rayon coins bas | 40px | 0px |
| Couleur | `#F5F8FF` (blanc bleuté) | |
| Handle bar | `Colors.grey[300]` - 40x4px | (identique) |

## Comment utiliser ce guide

Quand tu veux appliquer ce pattern à une autre bottom sheet, dis-moi :

> "Applique le pattern Liquid Glass du fichier `docs/LIQUID_GLASS_BOTTOM_SHEET.md` sur [nom de l'écran/fichier]"

Je lirai ce fichier et adapterai le code en conséquence.

## Fichier de référence

L'implémentation complète se trouve dans :
`lib/pages/share/live_share_viewer_screen.dart`

Méthode principale : `_buildLiquidGlassSheet()`
