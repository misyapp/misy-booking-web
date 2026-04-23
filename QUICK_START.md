# 🚀 Guide de démarrage rapide - MISY Booking Web

## 📍 Pour les prochaines sessions

### Commandes essentielles

#### 🔄 Mettre à jour et déployer
```bash
cd /Users/stephane/StudioProjects/misy-booking-web
git pull origin main
flutter build web --release
./deploy.sh
```

#### 🔐 Connexion SSH au serveur (OVH)
```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103
```

#### 📦 Déploiement manuel (si besoin)
```bash
rsync -avz --delete --exclude='osrm-proxy.php' \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  --rsync-path="sudo rsync" \
  build/web/ ubuntu@51.254.141.103:/var/www/book.misy.app/
```

#### 🔍 Vérifier les fichiers sur le serveur
```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 "ls -lh /var/www/book.misy.app/"
```

#### 📋 Voir les logs nginx
```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 "sudo tail -f /var/log/nginx/error.log"
```

#### 🔄 Redémarrer nginx
```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 "sudo systemctl restart nginx"
```

#### ✅ Vérifier que le deploy a bien servi (cache SW)
```bash
curl -sI "https://book.misy.app/main.dart.js?$(date +%s)" | grep -i last-modified
# Le Last-Modified doit être d'aujourd'hui
```

## 🗂️ Structure du projet

```
misy-booking-web/
├── deploy.sh              # Script de déploiement automatisé (OVH)
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
- **Serveur prod**: ubuntu@51.254.141.103 (OVH VPS, hostname `newsletter.misy.email`)

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
ssh -i ~/.ssh/id_rsa_misy ubuntu@51.254.141.103 "echo 'OK'"
```

Si rsync retourne `permission denied` sur `/var/www/book.misy.app/` : vérifie
que `--rsync-path="sudo rsync"` est bien présent dans la commande (le
DocumentRoot appartient à `www-data`).

### L'app ne se met pas à jour (cache navigateur)
Le service worker Flutter cache `main.dart.js` agressivement :
- Fermer **toutes** les fenêtres privées (pas juste l'onglet)
- OU DevTools → Application → Clear site data

Si le problème persiste, vérifier que le fichier servi est bien le nouveau :
```bash
curl -sI "https://book.misy.app/main.dart.js?$(date +%s)" | grep -i last-modified
```

## 💡 Tips

1. **Toujours tester localement** avant de déployer (`flutter run -d chrome`)
2. **Vérifier git status** avant de committer
3. **Lire les logs** si quelque chose ne fonctionne pas
4. **Le script deploy.sh** fait tout automatiquement (y compris la vérif `Last-Modified`)

---

**Dernière mise à jour**: 2026-04-21
**Projet**: MISY Booking Web Application
**Serveur**: OVH VPS `51.254.141.103`
