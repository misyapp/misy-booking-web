# MISY Booking Web Application

Application web Flutter pour la réservation de courses MISY.

## 🌐 Déploiement

L'application est déployée sur: **https://book.misy.app**

## 🚀 Technologies

- **Flutter Web** - Framework de développement
- **Firebase** - Backend (Firestore, Auth, Storage)
- **Google Maps API** - Cartographie et localisation
- **Bluehost** - Hébergement web

## 📦 Structure du projet

Ce projet est une version web-only de l'application MISY, optimisée pour fonctionner dans un navigateur avec:
- Stubs dart:io pour la compatibilité web
- Google Maps JavaScript API
- Upload de fichiers via Firebase Storage Web API

## 🛠️ Build et déploiement

### Build
```bash
flutter build web --release
```

### Déploiement sur Bluehost

**Méthode rapide** (recommandé):
```bash
./deploy.sh
```

**Méthode manuelle**:
```bash
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa_misy" \
  build/web/ root@162.240.145.160:/home/misyapp/booking_web/
```

📖 **Guide complet**: Voir [DEPLOYMENT.md](DEPLOYMENT.md) pour toutes les commandes SSH et le workflow de déploiement.

## 🔧 Configuration

### Secrets et clés API

**IMPORTANT:** Avant de pouvoir builder le projet, vous devez configurer les secrets:

1. **Firebase Service Account** - Créez `functions/serviceAccountKey.json` avec vos credentials Google Cloud
2. **Firebase Access Token** - Créez `lib/services/firebase_access_token.dart` avec la fonction `getAccessToken()`
3. **Twilio Config** (optionnel) - Copiez `lib/config/secrets.example.dart` vers `lib/config/secrets.dart` et remplissez vos clés Twilio

Ces fichiers sont dans `.gitignore` et ne doivent JAMAIS être committés sur GitHub.

### Google Maps API
L'API key Google Maps est configurée dans `web/index.html`:
```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY&libraries=places"></script>
```

### Firebase
Configuration dans `lib/firebase_options.dart` pour le support web.

## 📝 Compatibilité Web

Le projet utilise un système de stubs conditionnels pour remplacer `dart:io` sur le web:
- `lib/utils/platform_stub.dart` - Stubs pour Platform, File, Directory
- `lib/utils/platform_io.dart` - Exports pour mobile
- `lib/utils/platform.dart` - Export conditionnel

## 📄 License

Propriétaire - MISY App
