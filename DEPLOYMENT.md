# Guide de déploiement - MISY Booking Web

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

# Deploy
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa_misy" \
  build/web/ root@162.240.145.160:/home/misyapp/booking_web/
```

## 🔧 Configuration SSH

### Clé SSH requise
- Fichier: `~/.ssh/id_rsa_misy`
- Permissions: `chmod 600 ~/.ssh/id_rsa_misy`

### Serveur de destination
- **Host**: 162.240.145.160
- **User**: root
- **Path**: /home/misyapp/booking_web/
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
rsync -avz --delete \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  build/web/ \
  root@162.240.145.160:/home/misyapp/booking_web/
```

### 4. Vérifier le déploiement

```bash
# Ouvrir l'application
open https://book.misy.app

# OU vérifier via SSH
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 \
  "ls -lh /home/misyapp/booking_web/"
```

## 🔐 Commandes SSH utiles

### Se connecter au serveur

```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160
```

### Vérifier les fichiers déployés

```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 \
  "ls -lh /home/misyapp/booking_web/"
```

### Vérifier les logs du serveur web

```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 \
  "tail -f /var/log/apache2/error.log"
```

### Redémarrer le serveur web (si nécessaire)

```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 \
  "systemctl restart apache2"
```

### Vérifier l'espace disque

```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 \
  "df -h /home/misyapp/"
```

## 🔄 Mise à jour du code

### Workflow complet de mise à jour

```bash
# 1. Récupérer les dernières modifications
cd /Users/stephane/StudioProjects/misy_booking_web
git pull origin main

# 2. S'assurer que les dépendances sont à jour
flutter pub get

# 3. Builder la nouvelle version
flutter build web --release

# 4. Déployer
./deploy.sh

# 5. Vérifier que tout fonctionne
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
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 "echo 'Connection OK'"
```

### L'application ne se met pas à jour

```bash
# Force le cache refresh
# Ajouter --delete à rsync pour supprimer les anciens fichiers
rsync -avz --delete --force \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  build/web/ \
  root@162.240.145.160:/home/misyapp/booking_web/
```

## 🔗 Liens utiles

- **Application**: https://book.misy.app
- **Repository**: https://github.com/misyapp/misy-booking-web
- **Serveur**: root@162.240.145.160

## 📝 Notes importantes

1. **Toujours tester localement** avant de déployer
2. **Vérifier que les secrets sont configurés** avant le build
3. **Le flag `--delete`** dans rsync supprime les fichiers qui n'existent plus dans le build local
4. **Sauvegarder la clé SSH** `~/.ssh/id_rsa_misy` en lieu sûr
5. **Ne jamais committer** la clé SSH dans git
