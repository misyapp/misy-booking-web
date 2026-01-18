# Guide pour les Agents IA - Projet Misy

## Contexte du Projet

**Misy** est une application mobile de covoiturage (ride-hailing) développée en Flutter pour le marché malgache. L'application permet aux utilisateurs de :
- Réserver des trajets immédiats ou planifiés
- Suivre leur conducteur en temps réel
- Payer via différentes méthodes (Airtel Money, Orange Money, Telma MVola)
- Gérer leur profil et historique de trajets

## Architecture Technique

Consultez le document `ARCHITECTURE_TECHNIQUE.md` pour une vue d'ensemble complète. Points clés :
- **Framework**: Flutter 3.x avec Dart >= 3.4.4
- **Gestion d'état**: Provider pattern avec ChangeNotifier
- **Backend**: Firebase suite (Auth, Firestore, Storage, Messaging)
- **Cartes**: Google Maps Flutter
- **Paiements**: Intégrations mobiles money malgaches

## Structure du Projet

### Organisation des dossiers clés
```
lib/
├── bottom_sheet_widget/     # Bottom sheets UI
├── contants/               # Constantes globales
│   ├── global_data.dart    # Variables globales
│   ├── language_strings.dart # Chaînes multilingues
│   ├── my_colors.dart      # Palette de couleurs
│   └── theme_data.dart     # Thème Material Design
├── functions/              # Utilitaires globales
├── modal/                  # Modèles de données (legacy)
├── models/                 # Nouveaux modèles (ex: PopularDestination)
├── pages/                  # Écrans de l'app
│   ├── auth_module/        # Authentification
│   └── view_module/        # Écrans principaux
├── provider/               # Providers pour la gestion d'état
├── services/               # Services métier
└── widget/                 # Widgets réutilisables
```

### Nouvelles fonctionnalités récentes
- **Destinations populaires** : Service complet avec cache local et Firestore
- **Design system modernisé** : Nouvelle palette de couleurs et thème Material Design 3
- **Interface Misy V2** : Refonte complète de l'écran d'accueil

## Conventions de Code

### Debugging et Logs
- Utiliser `myCustomPrintStatement()` depuis `functions/print_function.dart`
- Éviter `print()` directement, utiliser la fonction custom pour debug

### Gestion d'État
- Pattern Provider avec ChangeNotifier
- Providers organisés par domaine (auth, trip, payment, etc.)

### Style et Thème
- Police par défaut : `Poppins-Regular`
- Thème défini dans `contants/theme_data.dart`
- Support mode sombre/clair
- Couleurs centralisées dans `my_colors.dart`

### Services et Firebase
- Services organisés par responsabilité
- Firestore : collection principale via `FirestoreServices`
- Cache local avec SharedPreferences pour performances

## Workflow de Collaboration

⚠️ **IMPORTANT**: Ce projet utilise un workflow de collaboration spécialisé défini dans `COLLABORATION_WORKFLOW.md`. 

**Avant de commencer tout travail :**
1. Consultez le document `COLLABORATION_WORKFLOW.md` pour comprendre l'organisation des équipes
2. Identifiez si votre travail concerne l'équipe **UI** ou **Features**
3. Suivez la méthodologie de suivi de projet avec fichiers `SUIVI_[PROJET].md`
4. Respectez la stratégie Git avec la branche `develop` comme branche d'intégration

**Séparation des responsabilités :**
- **Équipe UI** : `lib/contants/`, `lib/widget/`, `lib/bottom_sheet_widget/`, `assets/`
- **Équipe Features** : `lib/services/`, `lib/provider/`, `lib/models/`, nouvelles pages

## Commandes et Outils

### Flutter Development Commands
- Use `flutter` command (fvm si disponible)

### Build & Deployment

#### Build Web Release
```bash
flutter build web --release
```

#### Déploiement sur book.misy.app
```bash
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa_misy" /Users/stephane/StudioProjects/misy-booking-web/build/web/ root@162.240.145.160:/home/misyapps/public_html/book/
```

#### Connexion SSH au serveur
```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160
```

### Informations Serveur
- **Serveur**: Bluehost (162.240.145.160)
- **URL Production**: https://book.misy.app
- **Répertoire Web**: `/home/misyapps/public_html/book/`
- **Clé SSH**: `~/.ssh/id_rsa_misy`