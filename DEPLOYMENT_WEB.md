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

## 🚀 Déploiement sur OVH VPS

Cible actuelle : **VPS OVH** `51.254.141.103` (hostname `newsletter.misy.email`), servi par **nginx** depuis `/var/www/book.misy.app/` (owner `www-data:www-data`). SSH user `ubuntu` avec passwordless sudo. Clé privée : `~/.ssh/id_rsa_misy`.

### Étape 1: Build Flutter

```bash
flutter build web --release
```

### Étape 2: Upload des fichiers via rsync

```bash
rsync -avz --delete --exclude='osrm-proxy.php' \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  --rsync-path="sudo rsync" \
  build/web/ ubuntu@51.254.141.103:/var/www/book.misy.app/
```

> ⚠️ `--rsync-path="sudo rsync"` est indispensable car `/var/www/book.misy.app/` appartient à `www-data`.
>
> ⚠️ `--exclude='osrm-proxy.php'` préserve le proxy OSRM serveur (pas dans le build Flutter).

Alternative : `./deploy.sh` (script automatisé qui fait la même chose + vérif).

### Étape 3: Configuration nginx

Le vhost nginx est déjà configuré côté serveur (SPA fallback + gzip). Pour référence, le bloc de routing Flutter Web ressemble à :

```nginx
server {
  listen 443 ssl http2;
  server_name book.misy.app;
  root /var/www/book.misy.app;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location ~* \.(?:js|css|wasm)$ {
    expires 30d;
    add_header Cache-Control "public, no-transform";
  }

  location ~* \.(?:png|jpg|jpeg|gif|svg|ico)$ {
    expires 1y;
    add_header Cache-Control "public, no-transform";
  }

  # osrm-proxy.php → FastCGI PHP (proxy OSRM)
  location = /osrm-proxy.php {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php-fpm.sock;
  }
}
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
# Script automatisé (recommandé)
./deploy.sh

# OU commande manuelle
rsync -avz --delete --exclude='osrm-proxy.php' \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  --rsync-path="sudo rsync" \
  build/web/ ubuntu@51.254.141.103:/var/www/book.misy.app/
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
- Vérifiez la config nginx (`sudo nginx -t && sudo systemctl reload nginx`)
- Consultez la console Chrome (F12) pour les erreurs
- Vérifiez que le service worker n'a pas caché une vieille version (DevTools → Application → Clear site data)

### Problème: Firebase ne se connecte pas

**Solution:**
- Vérifiez que `firebase_options.dart` contient la bonne config web
- Vérifiez que le domaine `book.misy.app` est autorisé dans Firebase Console

### Problème: Routes ne fonctionnent pas

**Solution:**
- Vérifiez le SPA fallback nginx : `try_files $uri $uri/ /index.html;`
- Tester depuis la prod : `curl -I https://book.misy.app/transport-editor`

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

# 3. Déployer (OVH)
./deploy.sh

# 4. Vérifier
curl -sI "https://book.misy.app/main.dart.js?$(date +%s)" | grep -i last-modified

# 5. Push
git push origin main
```

## 📝 Notes importantes

- **Ne pas merger `web-booking-platform` dans `main`** (sauf si vous voulez activer le web pour tous)
- **Tester localement avant chaque déploiement**
- **Vérifier la console Firebase pour les erreurs**
- **Monitorer les performances** (temps de chargement)

## 🆘 Support

En cas de problème:
1. Vérifier les logs nginx : `ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 "sudo tail -f /var/log/nginx/error.log"`
2. Vérifier la console Chrome (F12)
3. Vérifier Firebase Console → Firestore → Usage
4. Tester en local d'abord (`flutter run -d chrome`)

---

**Dernière mise à jour:** 2026-04-21
**Branche:** main
**Environnement:** Production (OVH VPS `51.254.141.103`)
