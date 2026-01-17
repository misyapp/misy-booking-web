# Fonctionnalité Multilingue et Traduction Automatique

## Résumé des modifications

### 1. Nouvelles langues ajoutées
- **Italien (it)** : ~800 clés de traduction
- **Polonais (pl)** : ~800 clés de traduction

### 2. Détection automatique de la langue
L'application détecte maintenant automatiquement la langue du smartphone au premier lancement :
- Si la langue du téléphone est supportée (EN, FR, MG, IT, PL) → cette langue est utilisée
- Sinon → **Anglais par défaut**
- Si l'utilisateur change manuellement la langue → son choix est conservé

### 3. Traduction automatique du chat
Les messages entre le rider et le driver sont automatiquement traduits :
- Le message original est affiché en italique
- La traduction est affichée au-dessus
- Utilise LibreTranslate (solution open-source auto-hébergée)

---

## Architecture serveur

### Configuration actuelle sur osrm2.misy.app

| Service | Port | Technologie | Dossier |
|---------|------|-------------|---------|
| OSRM (routing) | 5000 | PM2 / Node.js | /usr/local/bin |
| LibreTranslate | 5050 | Docker | ~/libretranslate |

### LibreTranslate
- **URL** : `http://osrm2.misy.app:5050`
- **Langues supportées** : EN, FR, IT, PL
- **Limite caractères** : 5000
- **Mémoire allouée** : 2 Go
- **Redémarrage auto** : Oui (systemd)

---

## Fichiers modifiés

### Backend / Services
| Fichier | Description |
|---------|-------------|
| `lib/services/translation_service.dart` | **Nouveau** - Service de traduction via LibreTranslate |

### Configuration des langues
| Fichier | Description |
|---------|-------------|
| `lib/contants/global_data.dart` | Ajout IT et PL à `languagesList` |
| `lib/contants/language_strings.dart` | Ajout de `italianStrings` et `polishStrings` + mise à jour de `translate()` |

### Logique applicative
| Fichier | Description |
|---------|-------------|
| `lib/provider/auth_provider.dart` | Détection automatique de la langue avec fallback EN |
| `lib/pages/view_module/trip_chat_screen.dart` | Intégration traduction auto des messages driver |

### Scripts
| Fichier | Description |
|---------|-------------|
| `scripts/install_libretranslate.sh` | Script d'installation LibreTranslate (référence) |

---

## Commandes serveur

### Connexion SSH
```bash
ssh -i ~/.ssh/id_rsa_misy ubuntu@osrm2.misy.app
```

### Gestion LibreTranslate

```bash
# Voir les logs en temps réel
sudo docker logs -f libretranslate

# Statut du conteneur
sudo docker ps

# Redémarrer le service
sudo systemctl restart libretranslate

# Arrêter le service
sudo systemctl stop libretranslate

# Démarrer le service
sudo systemctl start libretranslate

# Statut systemd
sudo systemctl status libretranslate
```

### Gestion OSRM (inchangé)
```bash
# Statut PM2
pm2 list

# Logs OSRM
pm2 logs osrm-hmac-proxy

# Redémarrer OSRM
pm2 restart osrm-hmac-proxy
```

---

## API LibreTranslate

### Endpoint de traduction
```bash
curl -X POST http://osrm2.misy.app:5050/translate \
  -H "Content-Type: application/json" \
  -d '{
    "q": "Bonjour, je suis en route",
    "source": "fr",
    "target": "it"
  }'
```

**Réponse** :
```json
{"translatedText": "Salve, sto arrivando"}
```

### Liste des langues disponibles
```bash
curl http://osrm2.misy.app:5050/languages
```

### Détection de langue
```bash
curl -X POST http://osrm2.misy.app:5050/detect \
  -H "Content-Type: application/json" \
  -d '{"q": "Ciao come stai?"}'
```

---

## Utilisation dans le code Flutter

### Traduire un texte
```dart
import 'package:rider_ride_hailing_app/services/translation_service.dart';

final translationService = TranslationService.instance;

// Traduire vers une langue spécifique
String translated = await translationService.translateText(
  text: "Hello, I'm on my way",
  sourceLanguage: 'en',
  targetLanguage: 'fr',
);

// Traduire vers la langue de l'utilisateur actuel
String translated = await translationService.translateToUserLanguage(
  "Bonjour",
  'fr', // langue source
);
```

### Vérifier si le service est disponible
```dart
bool available = await TranslationService.instance.isServiceAvailable();
```

### Activer/désactiver la traduction auto
```dart
// Sauvegarder la préférence
await TranslationService.instance.setAutoTranslateEnabled(true);

// Lire la préférence
bool enabled = await TranslationService.instance.isAutoTranslateEnabled();
```

---

## Ajouter une nouvelle langue

### 1. Ajouter à la liste des langues
Dans `lib/contants/global_data.dart` :
```dart
List languagesList = [
  {'key': 'en', 'value': 'English'},
  {'key': 'mg', 'value': 'Malagasy'},
  {'key': 'fr', 'value': 'French'},
  {'key': 'it', 'value': 'Italian'},
  {'key': 'pl', 'value': 'Polish'},
  {'key': 'xx', 'value': 'Nouvelle Langue'}, // Ajouter ici
];
```

### 2. Créer les traductions
Dans `lib/contants/language_strings.dart` :
```dart
static Map<String, String> nouvelleLangStrings = {
  // Copier toutes les clés de englishStrings et traduire
};
```

### 3. Mettre à jour la fonction translate()
```dart
String translate(String key) {
  final languageKey = selectedLanguageNotifier.value["key"];
  switch (languageKey) {
    // ... cases existants ...
    case "xx":
      return MultiLangStrings.nouvelleLangStrings[key] ?? "$key";
    // ...
  }
}
```

### 4. Mettre à jour la détection automatique
Dans `lib/provider/auth_provider.dart`, ajouter le code langue au map `supportedLangs`.

### 5. Ajouter à LibreTranslate (optionnel)
Si la langue est supportée par LibreTranslate, modifier le docker-compose sur le serveur :
```yaml
environment:
  - LT_LOAD_ONLY=en,fr,it,pl,xx  # Ajouter le code langue
```

Puis redémarrer :
```bash
cd ~/libretranslate
sudo docker compose down
sudo docker compose up -d
```

---

## Dépannage

### LibreTranslate ne répond pas
1. Vérifier que le conteneur tourne : `sudo docker ps`
2. Vérifier les logs : `sudo docker logs libretranslate`
3. Redémarrer : `sudo systemctl restart libretranslate`

### Traduction lente
- Le cache local évite les requêtes répétées (500 entrées max)
- Timeout configuré à 10 secondes
- En cas d'échec, le texte original est affiché

### Port 5050 non accessible
Vérifier le firewall OVH et s'assurer que le port 5050 est ouvert en entrée.

---

## Notes de sécurité

- LibreTranslate est accessible sans authentification (usage interne uniquement)
- Pour une utilisation en production à grande échelle, considérer :
  - Ajouter un reverse proxy nginx avec SSL
  - Configurer le rate limiting (`LT_REQ_LIMIT`)
  - Restreindre l'accès par IP si possible

---

*Document généré le 6 décembre 2025*
