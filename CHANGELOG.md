# Historique des modifications - MISY Booking Web

## 2026-02-10 - 95/95 lignes transport avec tracés routiers + mode édition

### Transport : couverture 100%
- **38 lignes extraites d'OpenStreetMap** via Overpass API (script `fetch_osm_transport_lines.py`)
- **36 lignes générées par géocodage** des quartiers Antananarivo + routage OSRM (script `generate_missing_routes.py`)
- **188 fichiers GeoJSON** tous recalés sur le réseau routier (script `snap_routes_to_roads.py`)
- **96 couleurs uniques** par ligne dans `_fixedColors` (recherche web couleurs taxi-be)
- **Manifest synchronisé** : 95 lignes bundled à 100%

### Mode édition collaboratif ("Modifier le tracé")
- Flow Primus/Terminus avec Google Places Autocomplete
- Auto-calcul OSRM du tracé (plus de bouton "Calculer")
- Waypoints draggables + tap-to-delete + midpoint drag handles
- Aller/Retour avec reset complet
- Popup contribution (prénom requis + description optionnelle)
- Popup confirmation sortie si travail en cours

### Arrêts sur la carte
- Marqueurs avec numéro de ligne + couleur
- Déduplication aller/retour (precision ~10m)

### Fichiers modifiés
- `assets/transport_lines/core/*.geojson` — 188 fichiers
- `assets/transport_lines/manifest.json` — 95 lignes bundled
- `lib/models/transport_line.dart` — couleurs uniques
- `lib/models/transport_contribution.dart` — modèle EditData
- `lib/pages/view_module/home_screen_web.dart` — mode édition + arrêts
- `lib/services/transport_contribution_service.dart` — contributorName
- `scripts/fetch_osm_transport_lines.py` — NEW
- `scripts/generate_missing_routes.py` — NEW
- `scripts/snap_routes_to_roads.py` — NEW

---

## 2026-01-17 (15:45) - Ajout du guide de déploiement et scripts SSH

### Nouveaux fichiers ajoutés

- **`deploy.sh`** - Script automatisé de déploiement vers le serveur Bluehost
- **`DEPLOYMENT.md`** - Guide complet avec toutes les commandes SSH et workflows
- **`README.md`** - Mise à jour avec références au guide de déploiement

### Commandes SSH disponibles

#### Déploiement rapide
```bash
./deploy.sh
```

#### Commandes utiles pour les prochaines sessions
```bash
# Se connecter au serveur
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160

# Vérifier les fichiers déployés
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 "ls -lh /home/misyapp/booking_web/"

# Voir les logs
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 "tail -f /var/log/apache2/error.log"

# Redémarrer Apache
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 "systemctl restart apache2"
```

### Workflow de mise à jour complet
```bash
# 1. Récupérer les modifications
git pull origin main

# 2. Builder
flutter build web --release

# 3. Déployer
./deploy.sh
```

---

## 2026-01-17 (12:36-13:30) - Création du projet GitHub misy-booking-web

### Actions réalisées

#### 12:36 - Initialisation du projet
- Création du répertoire `/Users/stephane/StudioProjects/misy_booking_web`
- Copie des fichiers du projet riderapp (excluant .git, build, plateformes natives)
- Total: 3641 fichiers copiés

#### 12:40 - Configuration Git
- Initialisation du dépôt git local
- Création du fichier `.gitignore` pour Flutter
- Configuration de l'exclusion des fichiers de build et dépendances

#### 12:45 - Création du README
- Documentation du projet
- Instructions de build et déploiement
- Configuration Google Maps API et Firebase

#### 12:50 - Création du dépôt GitHub
- Création du repository public `misy-booking-web` via gh CLI
- Organisation: misyapp
- URL: https://github.com/misyapp/misy-booking-web

#### 12:55 - Gestion des secrets (Tentative 1)
- Premier commit de 3640 fichiers
- **ÉCHEC**: Push bloqué par GitHub Push Protection
- Secrets détectés:
  - `functions/serviceAccountKey.json` (Google Cloud Service Account)
  - `lib/services/firebase_access_token.dart` (Firebase credentials)
  - `lib/provider/auth_provider.dart:983` (Twilio Account SID)

#### 13:10 - Sécurisation des secrets
- Ajout au `.gitignore`:
  - `functions/serviceAccountKey.json`
  - `lib/services/firebase_access_token.dart`
  - `lib/config/secrets.dart`
  - `assets/json_files/service_account_credential.json`

#### 13:15 - Création des fichiers exemples
- `functions/serviceAccountKey.example.json`
- `lib/services/firebase_access_token.example.dart`
- `lib/config/secrets.example.dart`
- `assets/json_files/service_account_credential.example.json`

#### 13:20 - Refactoring du code Twilio
- Modification de `lib/provider/auth_provider.dart`
- Extraction du Account SID vers `AppSecrets.twilioAccountSid`
- Import ajouté: `import '../config/secrets.dart';`
- Changement ligne 983:
  ```dart
  // Avant:
  'https://api.twilio.com/2010-04-01/Accounts/ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/Messages.json'

  // Après:
  'https://api.twilio.com/2010-04-01/Accounts/${AppSecrets.twilioAccountSid}/Messages.json'
  ```

#### 13:25 - Mise à jour de la documentation
- Ajout de section "Secrets et clés API" dans README.md
- Instructions de configuration pour les développeurs
- Avertissement sur la non-inclusion des secrets dans git

#### 13:30 - Commit et push final
- Amendement du commit initial
- Retrait des fichiers secrets du commit
- Ajout des fichiers exemples et modifications
- **SUCCÈS**: Push vers GitHub réussi
- Commit hash: `91928b2`

### Fichiers modifiés dans le commit final

#### Supprimés (ajoutés au .gitignore)
- `functions/serviceAccountKey.json`
- `assets/json_files/service_account_credential.json`
- `lib/services/firebase_access_token.dart`

#### Ajoutés
- `.gitignore` (mis à jour avec les secrets)
- `README.md` (section secrets ajoutée)
- `functions/serviceAccountKey.example.json`
- `assets/json_files/service_account_credential.example.json`
- `lib/services/firebase_access_token.example.dart`
- `lib/config/secrets.example.dart`

#### Modifiés
- `lib/provider/auth_provider.dart` (refactoring Twilio)

### Configuration requise avant build

Pour builder ce projet, chaque développeur doit créer:

1. **Firebase Service Account Keys**:
   - `functions/serviceAccountKey.json`
   - `assets/json_files/service_account_credential.json`
   
2. **Firebase Access Token**:
   - `lib/services/firebase_access_token.dart`
   
3. **Twilio et autres secrets**:
   - `lib/config/secrets.dart` (copier depuis `secrets.example.dart`)

### Architecture de sécurité

- ✅ Tous les secrets sont exclus de git via `.gitignore`
- ✅ Fichiers exemples fournis pour faciliter la configuration
- ✅ Documentation claire dans README.md
- ✅ Code refactorisé pour utiliser les variables de configuration
- ✅ Protection GitHub Push Protection respectée

### Déploiement

L'application est déployée sur: **https://book.misy.app**

Commande de déploiement:
```bash
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa_misy" \
  build/web/ root@162.240.145.160:/home/misyapp/booking_web/
```

---

**Auteur**: misyapp (admin@misyapp.com)  
**Co-Author**: Claude Opus 4.5 (noreply@anthropic.com)  
**Date**: Samedi 17 janvier 2026
