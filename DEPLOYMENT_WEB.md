# 🌐 Déploiement Web - book.misy.app

## 📋 Vue d'ensemble

Ce document explique comment déployer la version web de l'application MISY Booking sur `book.misy.app`.

## 🏗️ Architecture

### Structure des branches

```
riderapp/
├── main                      # Production mobile (iOS/Android)
├── web-booking-platform      # Version web ← VOUS ÊTES ICI
└── feature/*                 # Autres features
```

### Fichiers générés

Après compilation (`flutter build web --release`):
```
/Users/stephane/StudioProjects/riderapp/build/web/
├── index.html
├── main.dart.js
├── flutter.js
├── flutter_service_worker.js
├── manifest.json
├── version.json
├── assets/
│   ├── AssetManifest.json
│   ├── FontManifest.json
│   ├── fonts/
│   ├── packages/
│   └── shaders/
├── canvaskit/
└── icons/
```

## 🚀 Déploiement sur Hostinger

### Étape 1: Créer le sous-domaine

1. Connectez-vous à **Hostinger**
2. Allez dans **Domaines** → `misy.app`
3. Créez le sous-domaine `book.misy.app`
4. Pointez-le vers le dossier: `/public_html/book`

### Étape 2: Uploader les fichiers

#### Option A: Via FTP
```bash
# Connexion FTP
Host: ftp.misy.app
User: votre_utilisateur_hostinger
Pass: votre_mot_de_passe

# Uploader TOUT le contenu de:
Source: /Users/stephane/StudioProjects/riderapp/build/web/
Destination: /public_html/book/
```

#### Option B: Via File Manager Hostinger
1. Ouvrez le **File Manager** dans Hostinger
2. Naviguez vers `/public_html/`
3. Créez le dossier `book/` si nécessaire
4. Uploadez tous les fichiers de `build/web/` dans `book/`

### Étape 3: Configuration .htaccess

Créez un fichier `.htaccess` dans `/public_html/book/`:

```apache
# Flutter Web Routing
<IfModule mod_rewrite.c>
  RewriteEngine On

  # Ne pas rediriger les fichiers existants
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d

  # Rediriger toutes les requêtes vers index.html
  RewriteRule ^(.*)$ /index.html [L,QSA]
</IfModule>

# Cache Control pour les assets
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/jpg "access plus 1 year"
  ExpiresByType image/jpeg "access plus 1 year"
  ExpiresByType image/gif "access plus 1 year"
  ExpiresByType image/png "access plus 1 year"
  ExpiresByType image/svg+xml "access plus 1 year"
  ExpiresByType text/css "access plus 1 month"
  ExpiresByType application/javascript "access plus 1 month"
  ExpiresByType application/wasm "access plus 1 month"
</IfModule>

# Compression
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/x-javascript application/json
</IfModule>

# MIME Types
AddType application/wasm .wasm
```

### Étape 4: Vérification

Une fois déployé, testez:

1. **URL principale:** https://book.misy.app
2. **Routing:** https://book.misy.app/login (doit rediriger correctement)
3. **Assets:** Vérifiez que les images et icônes se chargent
4. **Console:** Ouvrez les DevTools Chrome et vérifiez qu'il n'y a pas d'erreurs

## 🔄 Workflow de développement

### 1. Développement local

```bash
cd /Users/stephane/StudioProjects/riderapp

# Tester sur Chrome
flutter run -d chrome

# OU lancer un serveur local après build
flutter build web --release
cd build/web
python3 -m http.server 8000
# Ouvrir: http://localhost:8000
```

### 2. Build production

```bash
cd /Users/stephane/StudioProjects/riderapp

# Build optimisé pour production
flutter build web --release

# Les fichiers seront dans:
# build/web/
```

### 3. Déploiement

```bash
# Option 1: Script SCP (à créer)
scp -r build/web/* user@ftp.misy.app:/public_html/book/

# Option 2: Rsync (plus rapide pour les mises à jour)
rsync -avz --delete build/web/ user@ftp.misy.app:/public_html/book/

# Option 3: File Manager Hostinger (interface web)
```

### 4. Commit et push

```bash
# Sauvegarder les changements
git add .
git commit -m "feat(web): [description des changements]"
git push origin web-booking-platform
```

## 📱 Fonctionnalités Web vs Mobile

### ✅ Disponible sur Web
- ✅ Authentification (Email/Password, Google Sign-In)
- ✅ Réservation de courses
- ✅ Carte interactive (Google Maps)
- ✅ Sélection pickup/drop
- ✅ Choix du type de véhicule
- ✅ Paiement (cash uniquement sur web pour l'instant)
- ✅ Historique des courses
- ✅ Profil utilisateur

### ⚠️ Limitations Web
- ❌ Notifications push (non supporté navigateur)
- ❌ Géolocalisation en arrière-plan
- ❌ Certains plugins natifs (caméra, etc.)

### 🔧 À adapter pour le web

Si certaines fonctionnalités ne marchent pas:

1. **Géolocalisation:** Utiliser `geolocator_web` (déjà inclus)
2. **Stockage:** Utiliser `shared_preferences_web` (déjà inclus)
3. **Authentification:** Utiliser `firebase_auth_web` (déjà inclus)

## 🐛 Dépannage

### Problème: Page blanche

**Solution:**
- Vérifiez que tous les fichiers sont bien uploadés
- Vérifiez le `.htaccess`
- Consultez la console Chrome (F12) pour les erreurs

### Problème: Firebase ne se connecte pas

**Solution:**
- Vérifiez que `firebase_options.dart` contient la bonne config web
- Vérifiez que le domaine `book.misy.app` est autorisé dans Firebase Console

### Problème: Routes ne fonctionnent pas

**Solution:**
- Vérifiez le `.htaccess`
- Assurez-vous que mod_rewrite est activé sur Hostinger

## 🔐 Sécurité Firebase

### Autoriser le domaine dans Firebase

1. Allez dans **Firebase Console** → Votre projet
2. **Authentication** → **Settings** → **Authorized domains**
3. Ajoutez: `book.misy.app`

### Firestore Security Rules

Assurez-vous que vos règles autorisent les requêtes web:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Booking requests
    match /bookingRequest/{bookingId} {
      allow create: if request.auth != null;
      allow read, update: if request.auth != null;
    }
  }
}
```

## 📊 Monitoring

### Analytics

Firebase Analytics est automatiquement activé. Vous pouvez suivre:
- Nombre de visiteurs web vs mobile
- Taux de conversion des réservations
- Pages les plus visitées

### Performance

```bash
# Tester la taille du build
du -sh build/web

# Optimiser si nécessaire
flutter build web --release --tree-shake-icons
```

## 🔄 Mises à jour

Pour mettre à jour la version web:

```bash
# 1. Faire vos modifications
git add .
git commit -m "fix(web): ..."

# 2. Rebuild
flutter build web --release

# 3. Déployer
# Uploader build/web/* vers Hostinger

# 4. Push
git push origin web-booking-platform
```

## 📝 Notes importantes

- **Ne pas merger `web-booking-platform` dans `main`** (sauf si vous voulez activer le web pour tous)
- **Tester localement avant chaque déploiement**
- **Vérifier la console Firebase pour les erreurs**
- **Monitorer les performances** (temps de chargement)

## 🆘 Support

En cas de problème:
1. Vérifier les logs Hostinger
2. Vérifier la console Chrome (F12)
3. Vérifier Firebase Console → Firestore → Usage
4. Tester en local d'abord

---

**Dernière mise à jour:** 2026-01-16
**Branche:** web-booking-platform
**Environnement:** Production (Hostinger)
