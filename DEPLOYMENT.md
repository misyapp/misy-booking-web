# Guide de déploiement - MISY Booking Web

Prod : **VPS OVH** `51.254.141.103` (hostname `newsletter.misy.email`), servi par nginx depuis `/var/www/book.misy.app/` (owner `www-data:www-data`).

## 🚀 Déploiement rapide

### Méthode 1: Script automatisé (recommandé)

```bash
# 1. Builder l'application
flutter build web --release

# 2. Déployer sur le serveur
./deploy.sh
```

### Méthode 2: Commande manuelle

```bash
# Build
flutter build web --release

# Deploy (OVH)
rsync -avz --delete --exclude='osrm-proxy.php' \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  --rsync-path="sudo rsync" \
  build/web/ ubuntu@51.254.141.103:/var/www/book.misy.app/
```

> ⚠️ `--rsync-path="sudo rsync"` est indispensable : le DocumentRoot appartient
> à `www-data` sur le VPS OVH, l'user `ubuntu` doit passer par sudo pour y
> écrire.
>
> ⚠️ `--exclude='osrm-proxy.php'` préserve le proxy OSRM côté serveur — ce
> fichier n'est pas dans le build Flutter et serait effacé par `--delete`.

## 🔧 Configuration SSH

### Clé SSH requise
- Fichier: `~/.ssh/id_rsa_misy`
- Permissions: `chmod 600 ~/.ssh/id_rsa_misy`

### Serveur de destination
- **Host**: 51.254.141.103 (OVH VPS, hostname `newsletter.misy.email`)
- **User**: ubuntu (passwordless sudo)
- **Path**: /var/www/book.misy.app/
- **URL publique**: https://book.misy.app

## 📋 Workflow de déploiement complet

### 1. Préparer l'environnement

```bash
# S'assurer que les secrets sont configurés
ls -la lib/config/secrets.dart
ls -la lib/services/firebase_access_token.dart
ls -la functions/serviceAccountKey.json
ls -la assets/json_files/service_account_credential.json
```

### 2. Tester localement

```bash
# Build en mode release
flutter build web --release

# Vérifier le build
ls -lh build/web/
```

### 3. Déployer

```bash
# Utiliser le script de déploiement
./deploy.sh

# OU commande manuelle
rsync -avz --delete --exclude='osrm-proxy.php' \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  --rsync-path="sudo rsync" \
  build/web/ ubuntu@51.254.141.103:/var/www/book.misy.app/
```

### 4. Vérifier le déploiement

```bash
# Le Last-Modified doit être d'aujourd'hui
curl -sI "https://book.misy.app/main.dart.js?$(date +%s)" | grep -i last-modified

# Ouvrir l'application
open https://book.misy.app

# OU vérifier via SSH
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 \
  "ls -lh /var/www/book.misy.app/"
```

## 🔐 Commandes SSH utiles

### Se connecter au serveur

```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103
```

### Vérifier les fichiers déployés

```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 \
  "ls -lh /var/www/book.misy.app/"
```

### Vérifier les logs nginx

```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 \
  "sudo tail -f /var/log/nginx/error.log"
```

### Redémarrer nginx (si nécessaire)

```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 \
  "sudo systemctl restart nginx"
```

### Vérifier l'espace disque

```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 "df -h /var/www/"
```

## 🔄 Mise à jour du code

### Workflow complet de mise à jour

```bash
# 1. Récupérer les dernières modifications
cd /Users/stephane/StudioProjects/misy-booking-web
git pull origin main

# 2. S'assurer que les dépendances sont à jour
flutter pub get

# 3. Builder la nouvelle version
flutter build web --release

# 4. Déployer
./deploy.sh

# 5. Vérifier que tout fonctionne
curl -sI "https://book.misy.app/main.dart.js?$(date +%s)" | grep -i last-modified
open https://book.misy.app
```

## 📊 Monitoring

### Vérifier que l'application est accessible

```bash
curl -I https://book.misy.app
```

### Vérifier les performances

```bash
curl -o /dev/null -s -w "Time: %{time_total}s\n" https://book.misy.app
```

## ⚠️ Dépannage

### Build échoue

```bash
# Nettoyer le cache Flutter
flutter clean
flutter pub get

# Rebuild
flutter build web --release
```

### Déploiement échoue (permission denied)

```bash
# Vérifier les permissions de la clé SSH
chmod 600 ~/.ssh/id_rsa_misy

# Vérifier la connexion SSH
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 "echo 'Connection OK'"
```

Si rsync échoue avec `permission denied` sur `/var/www/book.misy.app/`, vérifie
que `--rsync-path="sudo rsync"` est bien présent dans la commande.

### L'application ne se met pas à jour (cache)

Le service worker Flutter cache `main.dart.js` agressivement. Après un
déploiement :
- Fermer **toutes** les fenêtres privées du navigateur (pas juste l'onglet)
- OU DevTools → Application → Clear site data

```bash
# Vérifier que le fichier servi est bien le nouveau
curl -sI "https://book.misy.app/main.dart.js?$(date +%s)" | grep -i last-modified
```

## 🔗 Liens utiles

- **Application**: https://book.misy.app
- **Repository**: https://github.com/misyapp/misy-booking-web
- **Serveur**: ubuntu@51.254.141.103 (OVH VPS)

## 📝 Notes importantes

1. **Toujours tester localement** avant de déployer (`flutter run -d chrome`)
2. **Vérifier que les secrets sont configurés** avant le build
3. **Le flag `--delete`** dans rsync supprime les fichiers qui n'existent plus dans le build local
4. **`--exclude='osrm-proxy.php`** : toujours le garder, ce fichier est serveur-only
5. **`--rsync-path="sudo rsync"`** : obligatoire, DocumentRoot appartient à `www-data`
6. **Sauvegarder la clé SSH** `~/.ssh/id_rsa_misy` en lieu sûr
7. **Ne jamais committer** la clé SSH dans git
