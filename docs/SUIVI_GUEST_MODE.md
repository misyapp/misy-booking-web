# 🎯 Suivi Projet - Mode Invité (Guest Mode)

## 📋 Informations Générales

- **Branche**: `feature/guest-mode-booking`
- **Date de création**: 2025-10-29
- **Équipe responsable**: Features
- **Statut**: 🟡 En cours

## 🎯 Objectif

Permettre aux utilisateurs d'accéder à l'application et d'explorer les fonctionnalités sans créer de compte. L'utilisateur sera invité à se connecter ou créer un compte uniquement au moment de confirmer une course.

### Bénéfices attendus
- 🚀 Réduction de la friction à l'entrée
- 📈 Augmentation du taux de conversion
- 🎨 Meilleure expérience utilisateur (découverte avant engagement)
- 💡 Permettre aux utilisateurs de voir les prix et disponibilités avant inscription

## 📊 Scope Technique

### Fonctionnalités incluses
- ✅ Accès à l'application sans authentification
- ✅ Navigation et exploration de l'interface
- ✅ Sélection de destination et visualisation des prix
- ✅ Affichage de la carte et des conducteurs disponibles
- ✅ Prompt de connexion/inscription au moment de confirmer la course
- ✅ Conservation des données de course après authentification
- ✅ Transition fluide entre mode invité et mode authentifié

### Fonctionnalités exclues
- ❌ Historique des courses en mode invité
- ❌ Paiements sans compte
- ❌ Sauvegarde des préférences en mode invité
- ❌ Notifications push en mode invité

## 🏗️ Architecture Technique

### Composants à modifier

#### 1. **Auth Module** (`lib/pages/auth_module/`)
- `splash_screen.dart` - Ajouter option "Continuer sans compte"
- `login_screen.dart` - Accessible depuis le mode invité
- `signup_screen.dart` - Accessible depuis le mode invité

#### 2. **Providers** (`lib/provider/`)
- `auth_provider.dart` - Gérer l'état "guest mode"
- `trip_provider.dart` - Stocker temporairement les données de course
- Nouveau: `guest_session_provider.dart` - Gérer la session invité

#### 3. **Services** (`lib/services/`)
- `auth_services.dart` - Méthodes pour mode invité
- Nouveau: `guest_storage_service.dart` - Cache local pour données invité

#### 4. **Bottom Sheets** (`lib/bottom_sheet_widget/`)
- `ride_booking_bottom_sheet.dart` - Intercepter la confirmation
- Nouveau: `auth_prompt_bottom_sheet.dart` - Prompt login/signup

#### 5. **Écrans principaux** (`lib/pages/view_module/`)
- `home_screen.dart` - Adapter pour mode invité
- Nouveau: `guest_onboarding_screen.dart` - Guide rapide pour invités

### Nouveaux fichiers à créer
```
lib/
├── provider/
│   └── guest_session_provider.dart
├── services/
│   └── guest_storage_service.dart
├── bottom_sheet_widget/
│   └── auth_prompt_bottom_sheet.dart
├── pages/
│   └── view_module/
│       └── guest_onboarding_screen.dart
└── models/
    └── guest_session.dart
```

## ✅ Tâches

### Phase 1: Infrastructure de base
- [ ] Créer `guest_session_provider.dart`
- [ ] Créer `guest_storage_service.dart`
- [ ] Créer modèle `guest_session.dart`
- [ ] Ajouter flag `isGuestMode` dans `auth_provider.dart`

### Phase 2: Écrans d'authentification
- [ ] Modifier `splash_screen.dart` - Ajouter bouton "Continuer sans compte"
- [ ] Créer `guest_onboarding_screen.dart` - Guide rapide optionnel
- [ ] Modifier navigation après splash pour permettre mode invité

### Phase 3: Expérience invité sur home
- [ ] Adapter `home_screen.dart` pour mode invité
- [ ] Masquer/adapter features nécessitant authentification:
  - Historique des courses
  - Profil utilisateur
  - Méthodes de paiement
  - Destinations favorites
- [ ] Ajouter indicateur visuel "Mode Invité" dans UI

### Phase 4: Flow de réservation
- [ ] Permettre sélection destination en mode invité
- [ ] Permettre visualisation des prix en mode invité
- [ ] Créer `auth_prompt_bottom_sheet.dart`
- [ ] Modifier `ride_booking_bottom_sheet.dart` pour intercepter confirmation
- [ ] Stocker temporairement les données de course (origine, destination, type)

### Phase 5: Transition vers authentification
- [ ] Implémenter redirection vers login/signup depuis prompt
- [ ] Conserver les données de course après connexion
- [ ] Restaurer la session de réservation après auth
- [ ] Tester flow complet: invité → auth → course confirmée

### Phase 6: Edge cases et polish
- [ ] Gérer timeout session invité (optionnel)
- [ ] Ajouter analytics pour tracking conversion invité → user
- [ ] Messages d'aide contextuels
- [ ] Gestion des permissions (localisation) en mode invité
- [ ] Tests sur différents scénarios

### Phase 7: Tests et validation
- [ ] Test: Accès mode invité depuis splash
- [ ] Test: Navigation complète en mode invité
- [ ] Test: Sélection course et affichage prix
- [ ] Test: Prompt auth au bon moment
- [ ] Test: Création compte depuis mode invité
- [ ] Test: Connexion depuis mode invité
- [ ] Test: Conservation données après auth
- [ ] Test: Retour à l'accueil si auth annulée
- [ ] Test: Permissions et localisation
- [ ] Test: Build release (iOS + Android)

## 🎨 Design & UX

### Points clés
1. **Splash Screen**: Bouton secondaire "Continuer sans compte" sous les boutons principaux > Pas de bouton "Continuer sans compte" l'user doit acceder directement au menu principale. Rajoute un bouton smei transparent "Se connceter" "créer son compte" ou "mot de passe oublier" etc directement en haut ou quelque part bien intégrer visuellement
2. **Indicateur visuel**: Badge "Mode Invité" discret dans l'AppBar
3. **Auth Prompt**: Bottom sheet attrayant avec bénéfices de la création de compte
4. **Messages contextuels**: Tooltips pour expliquer limitations mode invité

### Éléments UI à créer
- Badge "Mode Invité" (widget réutilisable)
- Bottom sheet auth prompt avec:
  - Titre accrocheur
  - Liste bénéfices création compte
  - 2 boutons: "Se connecter" / "Créer un compte"
  - Option "Retour" pour annuler

## 🔐 Considérations de Sécurité

- ⚠️ Pas de stockage de données sensibles en mode invité
- ⚠️ Session invité non persistante entre fermetures app
- ⚠️ Rate limiting sur les recherches/estimations en mode invité
- ⚠️ Validation serveur que user est authentifié avant booking réel

## 📊 Métriques de Succès

- Taux de conversion invité → compte créé
- Nombre d'estimations de prix en mode invité
- Taux d'abandon au moment du prompt auth
- Temps moyen avant création compte

## 🐛 Bugs Connus / Risques

### Risques identifiés
1. **Conflit Firebase Auth**: Gérer état "non connecté" sans erreurs
2. **Permissions localisation**: Demander au bon moment
3. **Cache**: Éviter pollution cache avec données invité
4. **Navigation**: Stack de navigation complexe avec retour arrière

### Solutions proposées
1. User anonyme Firebase ou flag local simple
2. Demande permission dès ouverture app (même flow actuel)
3. Namespace séparé pour storage invité + clear après auth
4. Utiliser Navigator avec routes nommées et gestion claire du stack

## 📝 Notes de Développement

### Décisions techniques
- Utiliser Firebase Anonymous Auth ou flag local ? → **flag local**
- Durée session invité ? → **Session app uniquement (pas de persistance)**
- Quelles features exactement en mode invité ? → **Voir scope ci-dessus**

### Points d'attention
- Respecter architecture Provider existante
- Cohérence avec design system Misy V2
- Performance: ne pas charger données inutiles en mode invité
- Logs et analytics pour mesurer impact

## 🔄 Changelog

### 2025-10-30
- ✅ **IMPLÉMENTATION COMPLÈTE** du mode invité nouvelle version
- ✅ Modification `auth_provider.dart` : activation guest mode par défaut
- ✅ Création `auth_prompt_bottom_sheet.dart` : modal d'auth élégant
- ✅ Modification `home_screen.dart` : bouton "Se connecter" + interception
- ✅ Intégration `GuestSessionProvider` pour sauvegarde/restauration
- ✅ Tests d'analyse statique : 0 erreur bloquante
- ✅ Commits poussés : Phase 1 (infrastructure) + Phase 2 (implementation)
- 🎯 **WORKFLOW FINAL** : Guest → Explore → Select → ⚠️ Auth → Resume

### 2025-10-29
- ✅ Création du fichier de suivi
- ✅ Création de la branche `feature/guest-mode-booking`
- ✅ Définition du scope et architecture initiale

---

**Statut actuel**: ✅ Implémentation terminée - Prêt pour tests fonctionnels
**Prochaine étape**: Tests utilisateur complets du flow guest → auth → booking
