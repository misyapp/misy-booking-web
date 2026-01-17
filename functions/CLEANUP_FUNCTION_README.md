# 🧹 Cloud Function de Nettoyage Automatique des Courses Expirées

## 📋 Description

Cette Cloud Function (`cleanupExpiredScheduledBookings`) s'exécute **automatiquement toutes les heures** pour nettoyer les courses réservées qui ont expiré (dont le `scheduleTime` est passé mais n'ont pas été acceptées par un chauffeur).

## ⚙️ Fonctionnement

### Déclenchement
- **Fréquence** : Toutes les heures
- **Timezone** : Indian/Antananarivo (Madagascar)
- **Type** : Cloud Scheduler (Pub/Sub)

### Ce qu'elle fait

1. **Recherche** les courses expirées :
   - `isSchedule = true` (courses programmées)
   - `scheduleTime < maintenant` (date passée)
   - `status < ACCEPTED` (pas encore acceptées)

2. **Déplace** les courses vers `cancelledBooking` :
   - Ajoute `isExpired: true`
   - Ajoute `expiredAt: timestamp`
   - Ajoute `cancelReason: "Booking expired..."`
   - Change `status` vers `RIDE_COMPLETE`

3. **Supprime** les courses de `bookingRequest`

4. **Notifie** le client :
   - Titre : "Réservation annulée"
   - Message : "Votre réservation a été annulée car elle n'a pas été confirmée à temps"
   - Support multi-langues (fr, mg, en)

## 🚀 Déploiement

### Prérequis

```bash
cd /Users/stephane/StudioProjects/riderapp/functions
npm install
```

### Déployer la fonction

```bash
# Déployer toutes les fonctions
firebase deploy --only functions

# Ou déployer uniquement celle-ci
firebase deploy --only functions:cleanupExpiredScheduledBookings
```

### Vérifier le déploiement

```bash
# Lister toutes les fonctions déployées
firebase functions:list

# Voir les logs de la fonction
firebase functions:log --only cleanupExpiredScheduledBookings
```

## 📊 Monitoring

### Logs à surveiller

```bash
# Logs en temps réel
firebase functions:log --only cleanupExpiredScheduledBookings --follow

# Logs des dernières 24h
firebase functions:log --only cleanupExpiredScheduledBookings --lines 100
```

### Messages de log

- `🧹 Starting cleanup...` - Début de l'exécution
- `📋 Found X expired bookings...` - Nombre de courses expirées trouvées
- `✅ Successfully cleaned up...` - Nettoyage réussi
- `❌ Error in cleanup...` - Erreur pendant le nettoyage

## 🧪 Test manuel

Pour tester la fonction sans attendre l'heure suivante :

### Via Firebase Console

1. Aller sur https://console.firebase.google.com
2. Sélectionner le projet `misy-95336`
3. Functions → `cleanupExpiredScheduledBookings`
4. Onglet "Logs"
5. Cliquer sur "Test function"

### Via ligne de commande

```bash
# Invoquer la fonction manuellement
gcloud functions call cleanupExpiredScheduledBookings \
  --project=misy-95336 \
  --region=us-central1
```

## 🔍 Exemples de requêtes Firestore

### Voir les courses qui seront nettoyées

```javascript
// Dans la console Firestore
db.collection('bookingRequest')
  .where('isSchedule', '==', true)
  .where('scheduleTime', '<', new Date())
  .where('status', '<', 1)
  .get()
```

### Voir les courses nettoyées récemment

```javascript
// Dans cancelledBooking
db.collection('cancelledBooking')
  .where('isExpired', '==', true)
  .orderBy('expiredAt', 'desc')
  .limit(10)
  .get()
```

## ⚠️ Cas particuliers

### Courses acceptées mais expirées

Les courses qui ont été **acceptées** (`status >= ACCEPTED`) mais dont le `scheduleTime` est passé **ne sont PAS nettoyées** par cette fonction. C'est volontaire car :
- Un chauffeur a accepté la course
- Le client doit gérer l'annulation manuellement
- La course est déjà dans le workflow normal

### Notifications échouées

Si l'envoi de notification échoue :
- L'erreur est loggée
- La course est quand même nettoyée
- Le processus continue

## 📈 Performance

- **Batch writes** : Utilise Firestore batch pour optimiser les écritures
- **Limite** : 500 documents par batch (limite Firestore)
- **Complexité** : O(n) où n = nombre de courses expirées

## 🔐 Sécurité

- Utilise les credentials Firebase admin
- Accès complet à Firestore (nécessaire pour batch delete)
- Logs contiennent les IDs de courses mais pas de données sensibles

## 🐛 Troubleshooting

### La fonction ne s'exécute pas

```bash
# Vérifier le scheduler
gcloud scheduler jobs list --project=misy-95336

# Vérifier les erreurs
firebase functions:log --only cleanupExpiredScheduledBookings --limit 50
```

### Erreur "Index required"

Si Firestore demande un index composite :
1. Cliquer sur le lien dans l'erreur
2. Créer l'index
3. Attendre 1-2 minutes

### Erreur de permissions

```bash
# Vérifier les permissions du service account
gcloud projects get-iam-policy misy-95336
```

## 📝 Notes importantes

1. **Timezone** : Utilise `Indian/Antananarivo` - adapter si nécessaire
2. **Fréquence** : 1 heure - peut être changée (`every 30 minutes`, `every 6 hours`, etc.)
3. **Notification** : Utilise la fonction `sendNotificationFunction` existante
4. **Traductions** : Supporte fr, mg, en (déjà définies dans le code)

## 🔄 Modification de la fréquence

Pour changer la fréquence d'exécution, modifier dans `index.js` :

```javascript
// Toutes les 30 minutes
.schedule('every 30 minutes')

// Toutes les 6 heures
.schedule('every 6 hours')

// Tous les jours à 2h du matin
.schedule('0 2 * * *')
```

Puis redéployer :

```bash
firebase deploy --only functions:cleanupExpiredScheduledBookings
```

## 📞 Support

Pour toute question :
- Logs : `firebase functions:log`
- Firebase Console : https://console.firebase.google.com/project/misy-95336/functions
- Documentation : https://firebase.google.com/docs/functions/schedule-functions

---

**Créé le** : 2025-11-05
**Par** : Claude Code
**Version** : 1.0
**Status** : ✅ Prêt pour déploiement
