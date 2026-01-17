# ⚡ Quick Reference - Interface Redesign

## 🏃‍♂️ Actions Rapides

### Ajouter un nouvel état au bottom sheet
```dart
// Dans home_screen.dart, méthode _buildBottomSheetContent
: tripProvider.currentStep == CustomTripType.VOTRE_NOUVEL_ETAT
    ? VotreNouveauWidget(
        onCallback: () {
          // Action de retour
          tripProvider.setScreen(CustomTripType.ETAT_SUIVANT);
        },
      )
```

### Modifier les niveaux du bottom sheet
```dart
// Dans home_screen.dart, constantes de classe
static const double _minBottomSheetHeight = 0.35;  // Niveau bas
static const double _midBottomSheetHeight = 0.60;  // Niveau moyen
static const double _maxBottomSheetHeight = 0.90;  // Niveau haut
```

### Changer l'icône d'un onglet
```dart
// Dans main_navigation_screen.dart
BottomNavigationBarItem(
  icon: ImageIcon(AssetImage(MyImagesUrl.VOTRE_ICONE)),
  label: 'Votre Label',
)
```

---

## 🔍 Diagnostic Rapide

### L'app ne démarre pas
```bash
fvm flutter clean
fvm flutter pub get
fvm flutter analyze lib/pages/view_module/
```

### Bottom sheet ne glisse pas
- Vérifier que `GestureDetector` global utilise `HitTestBehavior.translucent`
- S'assurer qu'aucun widget parent ne capture les gestes
- Vérifier qu'il n'y a pas de `SingleChildScrollView` qui interfère

### Bouton non clicable
- Utiliser `InkWell` + `Material` au lieu de `GestureDetector`
- Vérifier que la zone tactile n'est pas masquée par un autre widget

### Navigation ne fonctionne pas
- Vérifier que `physics: NeverScrollableScrollPhysics()` est présent
- Tester avec `_onItemTapped` directement

---

## 📁 Fichiers Critiques

| Fichier | Fonction | À ne pas toucher |
|---------|----------|------------------|
| `main_navigation_screen.dart` | Bottom navigation | Logique PageView |
| `home_screen.dart` | Interface hybride | Gestion des gestes |
| `old_home_screen.dart` | Backup | **JAMAIS MODIFIER** |
| `trip_provider.dart` | Logique métier | **JAMAIS MODIFIER** |

---

## 🧪 Tests Essentiels

### Avant chaque commit
```bash
# 1. Analyse syntaxique
fvm flutter analyze lib/pages/view_module/

# 2. Test compilation
fvm flutter build apk --debug

# 3. Test fonctionnel
fvm flutter run
# Tester : navigation, glissement, boutons, redirections
```

### Checklist fonctionnel
- [ ] Onglets naviguent sans swipe
- [ ] Bottom sheet glisse sur 3 niveaux
- [ ] Bouton "Trajets" → Page saisie adresses
- [ ] Bouton "Trajets planifiés" → Page réservation
- [ ] Champ "Où allez-vous ?" clicable
- [ ] Bouton menu ouvre le drawer
- [ ] Page "Mon compte" = EditProfileScreen

---

## 🚨 Alertes de Sécurité

### ⛔ NE JAMAIS :
- Modifier `TripProvider` sans validation complète
- Supprimer `old_home_screen.dart`
- Changer la logique de `CustomDrawer`
- Toucher aux imports des bottom sheets existants

### ✅ TOUJOURS :
- Tester sur iOS et Android
- Préserver la logique métier
- Documenter les changements importants
- Faire des backups avant modifications majeures

---

## 📱 États TripProvider Supportés

| État | Widget affiché | Fichier source |
|------|----------------|----------------|
| `null` | Interface par défaut | `home_screen.dart` |
| `setYourDestination` | Interface par défaut | `home_screen.dart` |
| `choosePickupDropLocation` | Saisie adresses | `pickup_and_drop_location_sheet.dart` |
| `selectScheduleTime` | Réservation planifiée | `schedule_ride_with_custom_time.dart` |

### Pour ajouter un nouvel état :
1. Importer le widget : `import 'package:rider_ride_hailing_app/bottom_sheet_widget/votre_widget.dart';`
2. Ajouter la condition dans `_buildBottomSheetContent`
3. Tester la transition depuis/vers cet état

---

## 🎨 Customisation Rapide

### Couleurs
```dart
MyColors.primaryColor      // Couleur principale Misy
MyColors.blackColor        // Thème sombre
MyColors.whiteColor        // Thème clair
```

### Animations
```dart
Duration(milliseconds: 300)  // Durée standard
Curves.easeInOut            // Courbe standard
```

### Espacements
```dart
const EdgeInsets.symmetric(horizontal: 20)  // Padding standard
const SizedBox(height: 24)                  // Espacement standard
```

---

## 📞 Aide d'Urgence

### Rollback rapide
```bash
git checkout HEAD~1 lib/pages/view_module/home_screen.dart
git checkout HEAD~1 lib/pages/view_module/main_navigation_screen.dart
```

### Debug avec logs
```dart
import 'package:rider_ride_hailing_app/functions/print_function.dart';

myCustomPrintStatement("DEBUG: État actuel = ${tripProvider.currentStep}");
```

### Reset complet de l'état
```dart
Provider.of<TripProvider>(context, listen: false)
    .setScreen(CustomTripType.setYourDestination);
```

---

*Référence mise à jour le 06/07/2025*