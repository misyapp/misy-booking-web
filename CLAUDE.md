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

#### Déploiement sur book.misy.app (OVH)
```bash
rsync -avz --delete --exclude='osrm-proxy.php' \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  --rsync-path="sudo rsync" \
  build/web/ ubuntu@51.254.141.103:/var/www/book.misy.app/
```

#### Vérification après deploy
```bash
curl -sI "https://book.misy.app/main.dart.js?$(date +%s)" | grep -i last-modified
# Last-Modified doit être d'aujourd'hui
```

#### Connexion SSH au serveur
```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103
```

### Informations Serveur
- **Serveur**: OVH VPS (51.254.141.103, hostname `newsletter.misy.email`)
- **URL Production**: https://book.misy.app
- **User SSH**: `ubuntu` (passwordless sudo)
- **Répertoire Web**: `/var/www/book.misy.app/` (owner `www-data:www-data`, d'où `--rsync-path="sudo rsync"`)
- **Clé SSH**: `~/.ssh/id_rsa_misy`
- `deploy.sh`, `DEPLOYMENT.md`, `DEPLOYMENT_WEB.md`, `QUICK_START.md`, `README.md` sont tous alignés sur OVH depuis le 2026-04-21. `CHANGELOG.md` garde les anciennes refs Bluehost (historique).

## Éditeur terrain transport (consultant)

Outil admin pour qu'un consultant terrain valide/corrige les 95 lignes de bus
une par une, et en crée de nouvelles. Accessible sur
`https://book.misy.app/#/transport-editor` après connexion avec un compte ayant
le custom claim `transport_editor: true`.

### Création d'un compte consultant

```bash
node scripts/create_transport_editor_user.js consultant-transport@misyapp.com
# → affiche uid + mot de passe temporaire (visible UNE SEULE FOIS)
# Pour remettre un mdp :
node scripts/create_transport_editor_user.js consultant-transport@misyapp.com --reset
```

Le consultant se connecte normalement via le flow auth Misy. L'entrée de menu
"Éditeur terrain" apparaît dans le menu utilisateur (en haut à droite) une fois
le claim détecté (re-login éventuellement nécessaire pour rafraîchir l'ID token).

### Architecture

- **UI Flutter** :
  `lib/pages/view_module/transport_editor/` — dashboard, wizard 4 étapes
  (tracé aller → tracé retour → arrêts aller → arrêts retour), écran nouvelle
  ligne, widgets `flutter_map` + tiles OSM.
- **Services** :
  `lib/services/transport_editor_service.dart` — I/O Firestore.
  `lib/services/admin_auth_service.dart` — gate custom claim.
  `lib/services/transport_osrm_service.dart` — routing OSRM
  (`router.project-osrm.org` + fallback `book.misy.app/osrm-proxy.php`).
- **Provider** :
  `lib/provider/transport_editor_provider.dart` — état wizard, undo/redo.
- **Tuto onboarding** : package `showcaseview`, wrapper
  `widgets/tutorial_helpers.dart`, déclenché à la 1ère visite de chaque écran,
  re-playable via l'icône école 🎓 dans l'AppBar.

### Collections Firestore

| Collection | Rôle |
|------------|------|
| `transport_lines_edited/{line}` | Source de vérité des éditions en cours (FeatureCollections aller + retour). Bootstrap paresseux depuis l'asset GeoJSON au 1er toucher. |
| `transport_line_validations/{line}` | État du wizard : `aller_route`, `retour_route`, `aller_stops`, `retour_stops` ∈ {pending, validated, modified}. |
| `transport_edits_log/{auto}` | Audit immuable de chaque validation/modification. Jamais purgé par le CLI. |

### Workflow de session terrain

1. **Avant la session** : créer le compte consultant (cf. plus haut).
2. **Pendant** : le consultant bosse sur son navigateur (book.misy.app).
   Toutes les modifs vont dans Firestore. Zéro accès fs.
3. **Après la session** (sur le Mac dev) :
   ```bash
   node scripts/transport_editor_pull_cli.js status       # vue d'ensemble
   node scripts/transport_editor_pull_cli.js diff 017     # diff avant écrasement
   node scripts/transport_editor_pull_cli.js pull 017     # ou pull --all
   git diff assets/transport_lines/                       # revue
   git add assets/transport_lines/ && git commit -m "..."
   flutter build web --release
   rsync -avz --delete --exclude='osrm-proxy.php' \
     -e "ssh -i ~/.ssh/id_rsa_misy" \
     --rsync-path="sudo rsync" \
     build/web/ ubuntu@51.254.141.103:/var/www/book.misy.app/
   ```
4. **Cleanup** (après validation des diff) :
   ```bash
   node scripts/transport_editor_pull_cli.js prune --all  # efface edited + validations
   # les logs audit restent intacts
   ```

### Règles Firestore recommandées

À ajouter dans ta console Firestore (ces 3 collections n'existent pas dans un
`firestore.rules` versionné aujourd'hui) :

```javascript
match /transport_lines_edited/{line} {
  allow read, write: if request.auth.token.transport_editor == true;
}
match /transport_line_validations/{line} {
  allow read, write: if request.auth.token.transport_editor == true;
}
match /transport_edits_log/{id} {
  allow create: if request.auth.token.transport_editor == true;
  allow read: if request.auth.token.transport_editor == true;
  allow update, delete: if false;  // logs immuables
}
```