# 🚀 Brief Agent 2: SVG, Animations et Composants

## 🎯 Mission
Moderniser les assets visuels, l'animation de chargement et les composants boutons pour Misy V2 selon l'approche LEAN.

## 📋 Tâches assignées

### 1. Conversion PNG vers SVG (SP1.3a)
**Répertoire cible**: `/assets/icons/`

**Actions LEAN**:
1. Créer un script bash simple pour la conversion batch
2. Convertir les PNG existants en SVG
3. Conserver les PNG originaux pour compatibilité

**Script à créer** (`convert_icons.sh`):
```bash
#!/bin/bash
# Script de conversion PNG vers SVG
for file in assets/icons/*.png; do
  if [ -f "$file" ]; then
    filename=$(basename "$file" .png)
    # Utiliser ImageMagick ou potrace
    convert "$file" -background none "assets/icons/${filename}.svg"
    echo "Converti: $filename.png -> $filename.svg"
  fi
done
```

**Alternative manuelle**:
- Utiliser un outil en ligne comme png2svg.com
- Priorité aux icônes principales utilisées dans l'UI

### 2. Animation du loader (SP1.3b)
**Fichier à modifier**: `/lib/widget/custom_loader.dart`

**Actions LEAN**:
1. Vérifier si le package `loading_animation_widget` est installé
2. Remplacer l'animation actuelle par TwistingDots
3. Utiliser les nouvelles couleurs

**Code à implémenter** (~5-10 lignes):
```dart
import 'package:loading_animation_widget/loading_animation_widget.dart';

// Remplacer le widget de chargement actuel par:
return LoadingAnimationWidget.twistingDots(
  leftDotColor: MyColors.coralPink,
  rightDotColor: MyColors.horizonBlue,
  size: 200,
);
```

**Si le package n'est pas disponible**, créer une animation simple:
```dart
return Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: MyColors.coralPink,
        shape: BoxShape.circle,
      ),
    ),
    SizedBox(width: 10),
    Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: MyColors.horizonBlue,
        shape: BoxShape.circle,
      ),
    ),
  ],
);
```

### 3. Extension des boutons (SP1.4)
**Fichier à modifier**: `/lib/widget/round_edged_button.dart`

**Actions LEAN**:
1. Ajouter des factory constructors
2. Ne PAS modifier le constructeur principal
3. Réutiliser la logique existante

**Code à ajouter** (~15-20 lignes):
```dart
// Factory constructors à ajouter dans la classe RoundEdgedButton
factory RoundEdgedButton.primary({
  required String text,
  required VoidCallback onPressed,
  double? width,
  double? height,
  Widget? iconLeft,
}) {
  return RoundEdgedButton(
    text: text,
    onPressed: onPressed,
    color: MyColors.coralPink,
    borderRadius: 12,
    width: width,
    height: height,
    iconLeft: iconLeft,
    elevation: 2,
  );
}

factory RoundEdgedButton.secondary({
  required String text,
  required VoidCallback onPressed,
  double? width,
  double? height,
  Widget? iconLeft,
}) {
  return RoundEdgedButton(
    text: text,
    onPressed: onPressed,
    color: MyColors.horizonBlue,
    borderRadius: 12,
    width: width,
    height: height,
    iconLeft: iconLeft,
    elevation: 2,
  );
}
```

## ✅ Checklist de validation

Avant de marquer une tâche comme complétée:

- [ ] Script de conversion fonctionne ou icônes converties manuellement
- [ ] Au moins 5 icônes principales converties en SVG
- [ ] Loader animé utilise les nouvelles couleurs
- [ ] Factory constructors ajoutés et fonctionnels
- [ ] Aucune régression dans l'UI existante
- [ ] Code compile sans erreur

## 🔄 Process

1. **Commencer par** la tâche 3 (boutons) car indépendante
2. **Puis** tâche 2 (loader) - rapide à implémenter
3. **Finir par** tâche 1 (SVG) - peut être plus longue
4. Mettre à jour `/doc/phase1_suivi/TODO.md` après chaque tâche
5. Commit séparés pour chaque tâche:
   - "feat(ui): add primary and secondary button factories"
   - "feat(ui): update loader animation with new colors"
   - "feat(assets): convert icons to SVG format"

## ⚠️ Points d'attention

- **SVG**: Garder une taille de fichier raisonnable (<10KB par icône)
- **Loader**: Si le package n'existe pas, créer une animation simple
- **Boutons**: Tester que les boutons existants ne sont pas cassés
- Ne PAS modifier la structure des widgets existants
- Préserver la rétrocompatibilité

## 🛠️ Dépendances possibles

Vérifier si ces packages sont déjà dans `pubspec.yaml`:
- `flutter_svg` (pour afficher les SVG)
- `loading_animation_widget` (pour le loader)

Si non présents, les ajouter avec:
```yaml
dependencies:
  flutter_svg: ^2.0.7
  loading_animation_widget: ^1.2.0+4
```

## 📞 Support

En cas de blocage:
1. Documenter dans `/doc/phase1_suivi/TODO.md`
2. Proposer une solution alternative LEAN
3. Continuer avec la tâche suivante

**Temps estimé**: 3-4 heures
**Deadline**: Dans les 24h