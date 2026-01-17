# Workflow de Collaboration - Projet Misy

## Vue d'ensemble

Ce document définit la méthodologie de travail collaborative pour le projet Misy, permettant à deux équipes de travailler simultanément sans interférence :

- **Équipe UI** : Aspects visuels et esthétiques
- **Équipe Features** : Nouvelles fonctionnalités (ex: système de fidélité avec loterie)

## 1. Stratégie Git et Branching

### Structure des Branches

```
main (production stable)
├── develop (branche d'intégration)
├── feature/ui-* (équipe UI)
├── feature/loyalty-* (équipe features)
├── feature/ui-component-* (composants UI spécifiques)
├── feature/loyalty-system-* (système de fidélité)
└── hotfix/* (corrections urgentes)
```

### Workflow de Développement

1. **Création de branche** : depuis `develop`
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/ui-home-redesign  # ou feature/loyalty-points-system
   ```

2. **Développement** : commits réguliers avec messages explicites
   ```bash
   git add .
   git commit -m "feat(ui): update home screen design with Misy 2.0 colors"
   ```

3. **Pull Request** : vers `develop` avec review obligatoire
   - Template PR à utiliser (voir section 5)
   - Review croisée entre équipes
   - Tests automatiques passants

4. **Déploiement** : `main` <- `develop` après validation complète

## 2. Séparation des Responsabilités

### 🎨 Équipe UI (Esthétique & Interface)

**Zones de responsabilité principale :**
- `lib/contants/` : couleurs, thèmes, styles, constantes visuelles
- `lib/widget/` : composants UI réutilisables
- `lib/bottom_sheet_widget/` : interfaces des bottom sheets
- `assets/` : icônes, images, fonts, ressources visuelles
- Améliorations visuelles des pages existantes

**Fichiers critiques :**
- `lib/contants/my_colors.dart` : palette de couleurs
- `lib/contants/theme_data.dart` : thème Material Design
- `lib/widget/round_edged_button.dart` : composants de base
- Tous les widgets dans `lib/widget/`

### ⚙️ Équipe Features (Fonctionnalités & Logique)

**Zones de responsabilité principale :**
- `lib/services/` : nouveaux services (loyalty, lottery, etc.)
- `lib/provider/` : nouvelle logique métier et gestion d'état
- `lib/models/` : nouveaux modèles de données
- `lib/pages/view_module/` : nouvelles pages complètes
- Firebase : collections, Cloud Functions, règles de sécurité

**Fichiers critiques :**
- Services de fidélité : `lib/services/loyalty_service.dart`
- Providers : `lib/provider/loyalty_provider.dart`
- Modèles : `lib/models/loyalty/`
- Pages : nouvelles pages dans `view_module/`

### 🚨 Zones de Coordination Obligatoire

**Fichiers nécessitant coordination :**
- `lib/pages/view_module/home_screen.dart` : modifications simultanées probables
- `lib/contants/global_data.dart` : nouvelles constantes globales
- `lib/pages/view_module/main_navigation_screen.dart` : navigation
- Providers partagés : `auth_provider.dart`, `trip_provider.dart`

## 3. Méthodologie de Suivi de Projet

### Structure des Fichiers de Suivi

Chaque projet/feature doit avoir son fichier de suivi : `SUIVI_[NOM_DU_PROJET].md`

**Exemples :**
- `SUIVI_LOYALTY_SYSTEM.md`
- `SUIVI_HOME_REDESIGN.md`
- `SUIVI_PAYMENT_UI_UPGRADE.md`

### Structure Standard d'un Fichier de Suivi

```markdown
# Suivi - [Nom du Projet]

## 📋 Informations Générales
- **Équipe** : [UI/Features]
- **Sprint** : [Numéro du sprint]
- **Dates** : [Date début] - [Date fin estimée]
- **Responsable** : [Nom]
- **Status Global** : [En cours/Terminé/Bloqué]

## 🎯 Objectifs du Projet
[Description des objectifs principaux]

## 📈 Sprints

### Sprint 1 : [Nom du Sprint]
**Dates** : [DD/MM] - [DD/MM]
**Objectif** : [Objectif du sprint]

#### Tâches
- [ ] **Tâche 1** : [Description]
  - [ ] Sous-tâche 1.1 : [Description] - [Assigné à] - [Status]
  - [x] Sous-tâche 1.2 : [Description] - [Assigné à] - ✅ Terminé
  
- [x] **Tâche 2** : [Description] - ✅ Terminé
  - [x] Sous-tâche 2.1 : [Description] - [Assigné à] - ✅ Terminé

**Résumé Sprint 1** : [Bilan, blocages, points d'attention]

### Sprint 2 : [Nom du Sprint]
[...répéter la structure]

## 🔄 Journal des Modifications
- **[Date]** : [Description de l'avancement]
- **[Date]** : [Problème rencontré et résolution]

## 📝 Résumé Final (pour PR)
[Résumé concis pour la Pull Request - sera copié dans la description du PR]

### Fonctionnalités Ajoutées
- [Liste des nouvelles fonctionnalités]

### Modifications UI
- [Liste des changements visuels]

### Impact Technique
- [Fichiers modifiés, dépendances ajoutées, etc.]

### Tests
- [Tests ajoutés/modifiés]

### Notes pour la Review
- [Points d'attention pour les reviewers]
```


## 4. Standards Techniques

### 🎨 Standards Équipe UI

**Conventions obligatoires :**
- Respecter le design system Misy V2
- Utiliser les couleurs définies dans `my_colors.dart`
- Maintenir la cohérence des animations (durées, courbes)
- Tester sur différentes tailles d'écran
- **Tests requis** : tests de widgets pour chaque nouveau composant

**Exemple de commit UI :**
```bash
git commit -m "feat(ui): redesign home screen with new color palette

- Update primary colors to Misy 2.0 specifications
- Add smooth transitions between bottom sheet states
- Improve accessibility with better contrast ratios
- Update button styles to match design system

Ref: SUIVI_HOME_REDESIGN.md"
```

### ⚙️ Standards Équipe Features

**Conventions obligatoires :**
- Utiliser le pattern Provider pour la gestion d'état
- Services organisés par responsabilité fonctionnelle
- Documentation complète pour les nouvelles APIs
- Gestion d'erreurs robuste
- **Tests requis** : tests unitaires + tests d'intégration

**Exemple de commit Features :**
```bash
git commit -m "feat(loyalty): implement points calculation service

- Add LoyaltyService with points calculation logic
- Create LoyaltyProvider for state management
- Implement Firestore integration for loyalty data
- Add unit tests for points calculation algorithms

Ref: SUIVI_LOYALTY_SYSTEM.md"
```

## 5. Processus de Review

### 📝 Template Pull Request

```markdown
## 📋 Type de PR
- [ ] 🎨 UI/UX (équipe UI)
- [ ] ⚙️ Feature (équipe Features)
- [ ] 🐛 Bug fix
- [ ] 📚 Documentation

## 🎯 Description
[Description claire des modifications]

## 📁 Fichiers de Suivi
- Lien vers le fichier `SUIVI_[PROJET].md`
- Section du fichier concernée

## 🧪 Tests
- [ ] Tests unitaires ajoutés/mis à jour
- [ ] Tests d'intégration passants
- [ ] Tests manuels effectués

## 📱 Screenshots (UI uniquement)
[Captures d'écran avant/après]

## 🔍 Points d'Attention pour Review
- [Points spécifiques à vérifier]
- [Dépendances avec autre équipe]

## ✅ Checklist
- [ ] Code respecte les standards de l'équipe
- [ ] Documentation mise à jour
- [ ] Tests passants
- [ ] Pas de conflit avec develop
- [ ] Fichier de suivi mis à jour
```

### 👥 Review Croisée

**Processus obligatoire :**
1. **Auto-review** : équipe créatrice vérifie sa PR
2. **Review technique** : équipe opposée vérifie les impacts
3. **Review fonctionnelle** : test de la fonctionnalité par les deux équipes
4. **Approbation** : minimum 2 approbations (1 par équipe)

### ✅ Critères de Validation

**Critères obligatoires pour merger :**
- [ ] Tous les tests automatiques passent
- [ ] Performance maintenue (pas de régression)
- [ ] Accessibilité respectée (contraste, navigation)
- [ ] Documentation à jour
- [ ] Fichier de suivi complété
- [ ] Pas de code en commentaire ou debug

## 6. Gestion des Urgences

### 🚨 Hotfix Workflow

**Pour les corrections urgentes :**
1. Branche depuis `main` : `hotfix/critical-bug-fix`
2. Fix rapide avec tests
3. Merge direct vers `main` et `develop`
4. Notification immédiate aux deux équipes

## 7. Bonnes Pratiques

### 📝 Documentation Continue
- Mettre à jour le fichier de suivi **quotidiennement**
- Documenter les décisions techniques importantes
- Maintenir les README des nouveaux modules

### 🔄 Intégration Continue
- Rebase régulier depuis `develop`
- Tests locaux avant chaque push
- Intégration fréquente (éviter les grosses PR)

### 🎯 Focus sur la Qualité
- Code review constructive et bienveillante
- Partage de connaissances entre équipes
- Amélioration continue des processus

---

**Version** : 1.0
