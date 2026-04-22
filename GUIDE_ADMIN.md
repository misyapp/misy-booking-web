# Guide admin transport — Misy

Ce guide explique le rôle d'admin transport (claim Firebase `transport_admin`) : reviewer le travail des consultants terrain et publier les directions validées en prod.

---

## 1. Créer un compte admin

Depuis ton Mac dev, à la racine du repo :

```bash
node scripts/create_transport_admin_user.js <email>
```

Ex :
```bash
node scripts/create_transport_admin_user.js admin@misyapp.com
```

Le script crée (ou met à jour) le compte Firebase Auth et pose les claims :
- `transport_admin: true` (accès review)
- `transport_editor: true` (hérite aussi des capacités consultant)

**Le mot de passe aléatoire s'affiche UNE SEULE FOIS** à la création. Note-le. Pour le réinitialiser :

```bash
node scripts/create_transport_admin_user.js <email> --reset
```

Si le compte existait déjà (cas de `admin@misyapp.com`), le script pose juste les claims sans toucher au mot de passe.

> ⚠️ Après première authentification ou changement de claim, l'admin doit **se déconnecter / se reconnecter** pour rafraîchir son ID token. Sinon les nouveaux claims ne sont pas visibles côté app.

---

## 2. Créer un compte consultant

Même principe, script différent :

```bash
node scripts/create_transport_editor_user.js <email>
```

Ne pose que le claim `transport_editor`. À utiliser pour les consultants terrain qui ne doivent pas avoir accès au review.

---

## 3. Accéder à l'UI admin

URL directe : **<https://book.misy.app/#/transport-admin>**

OU :

1. Va sur <https://book.misy.app/#/transport-editor>
2. Clique l'icône **🛡️ Review admin** dans la barre du haut (visible seulement si tu as le claim `transport_admin`)

---

## 4. Reviewer le travail

Page **Review admin — Transport** (bandeau violet) :

### Filtres
- **Dropdown « Consultant »** : filtre par adresse email. Utile quand plusieurs consultants travaillent en parallèle.
- Compteur à droite : `affichés / total`

### Liste des directions à reviewer
Chaque carte = **1 direction** (aller OU retour) à reviewer. Tri : nouveau en attente d'abord, puis déjà-rejeté, puis par date.

- Badge ligne + direction : `015 aller`, `017 retour`, etc.
- Consultant + date d'envoi
- Badge statut :
  - Gris **« À reviewer »** → première soumission à examiner
  - Rouge **« Rejeté (2e essai) »** → consultant t'a déjà renvoyé une direction, tu avais rejeté, il/elle a refait, nouvelle version à reviewer
- Si précédent rejet : affichage du motif que tu avais écrit

### Détail d'une direction
Tape **« Voir sur carte »** ou directement sur la carte → écran détail :

- **Colonne gauche (sidebar 320px)** :
  - Légende (prod actuelle en gris fantôme vs édition proposée en couleur ligne)
  - Métadonnées : consultant, nb vertices, nb arrêts
  - Liste numérotée des arrêts proposés
  - 2 boutons d'action en bas : **Demander refaire** (rouge) / **Valider** (vert)

- **Colonne droite** : carte OSM superposée :
  - Tracé **gris fantôme** = la version prod actuelle (asset bundlé)
  - Tracé **couleur ligne** = la version proposée par le consultant
  - Markers numérotés = arrêts proposés

### Action « Valider »
Clique « Valider » → boîte de confirmation → action :

1. La FeatureCollection est écrite dans Firestore `transport_lines_published/{line}.{direction}`
2. Le statut admin passe à `approved`, le motif de rejet (s'il y en avait un) est effacé
3. Un log audit est créé dans `transport_edits_log`

**Effet immédiat côté app** : l'app Misy lit `transport_lines_published` **en priorité** sur les assets bundlés → la version validée est live dans les ~5 secondes sur `book.misy.app` (après un refresh utilisateur).

### Action « Demander refaire »
Clique « Demander refaire » → boîte avec textarea **obligatoire** :

- Écris un motif explicite (ex: « le tracé coupe à travers le marché d'Analakely au lieu de passer par Tsaralalana », « le terminus d'Ivato est mal placé, il est 200m au nord »)
- Envoie → action :
  1. Statut admin passe à `rejected`, le motif est stocké
  2. Le statut consultant repasse à `pending` → le consultant voit la ligne réapparaître comme « à faire » avec la pastille rouge et ton motif
  3. Log audit créé

> ℹ️ Quand le consultant refait la direction (`commitReplaceDirection`), le statut admin est **automatiquement** remis à `pending` et le motif effacé → tu retrouves la nouvelle version dans ta liste à reviewer (badge rouge « Rejeté 2e essai » pour te signaler que c'est une reprise).

---

## 5. Workflow CLI (optionnel, pour archive git)

L'app consomme directement Firestore en prod. Mais tu peux vouloir archiver les directions validées dans git pour historique + fallback offline. Le CLI `transport_editor_pull_cli.js` gère ça.

Commandes :

```bash
# Vue d'ensemble (5 colonnes: Ligne, Aller, Retour, A-Admin, R-Admin)
node scripts/transport_editor_pull_cli.js status

# Diff Firestore edited vs asset bundlé (avant écrasement)
node scripts/transport_editor_pull_cli.js diff 017

# Pull une ligne spécifique (tout ce qui est édité, peu importe admin_status)
node scripts/transport_editor_pull_cli.js pull 017

# Pull toutes les lignes
node scripts/transport_editor_pull_cli.js pull --all

# NOUVEAU : Pull uniquement les directions validées par l'admin
node scripts/transport_editor_pull_cli.js pull --all --approved-only
```

Après un pull :

```bash
git diff assets/transport_lines/
git add assets/transport_lines/
git commit -m "transport: pull lignes validées {date}"
# optionnel : rebuild + deploy si tu veux que le bundled asset suive
flutter build web --release
rsync -avz --delete --exclude='osrm-proxy.php' \
  -e "ssh -i ~/.ssh/id_rsa_misy" \
  --rsync-path="sudo rsync" \
  build/web/ ubuntu@51.254.141.103:/var/www/book.misy.app/
```

### Prune (nettoyage Firestore)

```bash
# Supprime les docs transport_lines_edited + validations d'une ligne
node scripts/transport_editor_pull_cli.js prune 017

# Prune all (⚠️ après avoir confirmé que tout est bien pull+commit en git)
node scripts/transport_editor_pull_cli.js prune --all
```

Les logs d'audit (`transport_edits_log`) ne sont **jamais** effacés par le CLI.

---

## 6. Architecture de la persistence (pour référence)

| Collection Firestore | Rôle | Écrit par |
|---|---|---|
| `transport_lines_edited/{line}` | Brouillon de travail du consultant | Consultant |
| `transport_line_validations/{line}` | États `aller` / `retour` (pending/modified) + champs admin (`{dir}_admin_status`, `{dir}_rejection_reason`, etc.) | Consultant + Admin |
| `transport_lines_published/{line}` | **Source de vérité prod** — lue par l'app | Admin (via `approveDirection`) |
| `transport_edits_log/{auto}` | Audit immuable de chaque action | System (pas modifiable) |

Lookup côté app (`TransportLinesService._loadSingleRoute`) :
1. `transport_lines_published/{line}.{direction}` (Firestore live) — **prioritaire**
2. Asset bundlé (`assets/transport_lines/core/{line}_{dir}.geojson`)
3. Remote Firebase Storage (legacy)

---

## 7. Règles Firestore

Fichier versionné : `firestore.rules`. Redéploiement :

```bash
firebase deploy --only firestore:rules --project misy-95336
```

Résumé des règles transport :

- `transport_lines_edited` — read/write si `transport_editor`
- `transport_line_validations` — read/create si `transport_editor`, update si editor OU admin
- `transport_lines_published` — **read public**, write si `transport_admin`
- `transport_edits_log` — create/read si editor OU admin, jamais d'update/delete

---

## 8. FAQ admin

**Q : Je valide mais la ligne ne change pas côté app.**
A : Force un refresh (Cmd+Shift+R). Si ça persiste, vérifie dans la console Firebase que `transport_lines_published/{line}` contient bien le champ `{direction}.feature_collection_json` avec le bon JSON.

**Q : Comment gérer un consultant qui soumet des bêtises en boucle ?**
A : Contacte-le directement avec capture d'écran. Si besoin, révoque son accès :
```bash
# Retire les claims Firebase (au prochain refresh token il perdra l'accès)
# TODO: commande dédiée non encore scriptée — à faire via Firebase console pour l'instant
```

**Q : Je veux voir tout l'historique de reviews.**
A : Collection Firestore `transport_edits_log` — filtre par `kind='admin_review'`. Chaque doc contient `action` (`approved`/`rejected`), `line_number`, `direction`, `user_email`, `timestamp`.

**Q : Je veux rollback une ligne à sa version asset bundlé.**
A : Supprime le doc correspondant dans `transport_lines_published/{line}` via Firebase console, OU retire juste le champ `{direction}` du doc. L'app retombera sur l'asset bundlé au prochain load.

---

## 9. Contacts / escalation

- **Issues app** : GitHub repo `misyapp/misy-booking-web`
- **Firebase console** : <https://console.firebase.google.com/project/misy-95336>
- **Dashboard OVH** : 51.254.141.103 (SSH via `~/.ssh/id_rsa_misy`)

Bonne review 🛡️
