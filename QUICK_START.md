# 🚀 Guide de démarrage rapide - MISY Booking Web

## 📍 Pour les prochaines sessions

### Commandes essentielles

#### 🔄 Mettre à jour et déployer
```bash
cd /Users/stephane/StudioProjects/misy_booking_web
git pull origin main
flutter build web --release
./deploy.sh
```

#### 🔐 Connexion SSH au serveur
```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160
```

#### 📦 Déploiement manuel (si besoin)
```bash
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa_misy" \
  build/web/ root@162.240.145.160:/home/misyapp/booking_web/
```

#### 🔍 Vérifier les fichiers sur le serveur
```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 "ls -lh /home/misyapp/booking_web/"
```

#### 📋 Voir les logs Apache
```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 "tail -f /var/log/apache2/error.log"
```

#### 🔄 Redémarrer Apache
```bash
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 "systemctl restart apache2"
```

## 🗂️ Structure du projet

```
misy_booking_web/
├── deploy.sh              # Script de déploiement automatisé
├── DEPLOYMENT.md          # Guide complet de déploiement
├── CHANGELOG.md           # Historique horodaté des modifications
├── README.md              # Documentation principale
├── QUICK_START.md         # Ce fichier (référence rapide)
├── lib/
│   ├── config/
│   │   ├── secrets.dart           # ⚠️ À créer (non versionné)
│   │   └── secrets.example.dart   # Template
│   └── services/
│       ├── firebase_access_token.dart         # ⚠️ À créer (non versionné)
│       └── firebase_access_token.example.dart # Template
├── functions/
│   ├── serviceAccountKey.json         # ⚠️ À créer (non versionné)
│   └── serviceAccountKey.example.json # Template
└── assets/
    └── json_files/
        ├── service_account_credential.json         # ⚠️ À créer (non versionné)
        └── service_account_credential.example.json # Template
```

## ⚙️ Configuration requise (première utilisation)

Si c'est votre première fois avec ce projet, créez les fichiers de secrets :

```bash
# 1. Copier les templates
cp lib/config/secrets.example.dart lib/config/secrets.dart
cp lib/services/firebase_access_token.example.dart lib/services/firebase_access_token.dart
cp functions/serviceAccountKey.example.json functions/serviceAccountKey.json
cp assets/json_files/service_account_credential.example.json assets/json_files/service_account_credential.json

# 2. Éditer chaque fichier avec vos vraies clés (voir DEPLOYMENT.md)
```

## 🌐 URLs importantes

- **Application web**: https://book.misy.app
- **Repository GitHub**: https://github.com/misyapp/misy-booking-web
- **Serveur**: root@162.240.145.160

## 📚 Documentation complète

- **README.md** - Vue d'ensemble du projet
- **DEPLOYMENT.md** - Guide détaillé de déploiement avec toutes les commandes SSH
- **CHANGELOG.md** - Historique horodaté de toutes les modifications

## 🆘 Problèmes courants

### Build échoue
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Déploiement échoue
```bash
# Vérifier les permissions de la clé SSH
chmod 600 ~/.ssh/id_rsa_misy

# Tester la connexion
ssh -i ~/.ssh/id_rsa_misy root@162.240.145.160 "echo 'OK'"
```

### L'app ne se met pas à jour
```bash
# Forcer le refresh du cache
rsync -avz --delete --force \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  build/web/ \
  root@162.240.145.160:/home/misyapp/booking_web/
```

## 💡 Tips

1. **Toujours tester localement** avant de déployer
2. **Vérifier git status** avant de committer
3. **Lire les logs** si quelque chose ne fonctionne pas
4. **Le script deploy.sh** fait tout automatiquement

---

**Dernière mise à jour**: 2026-01-17 15:45  
**Projet**: MISY Booking Web Application  
**Version**: 1.0.0
