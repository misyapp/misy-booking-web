# Guide consultant terrain — Éditeur transport Misy

Tu viens d'être nommé·e **consultant terrain** pour corriger les 95 lignes de bus (taxi-be) d'Antananarivo dans l'app Misy. Ce document explique ce que tu dois faire, comment utiliser l'outil, et comment lire les retours de l'admin.

---

## 1. Se connecter

URL : **<https://book.misy.app/#/transport-editor>**

1. Saisis l'email qu'on t'a communiqué (ex: `amttinarimalala@gmail.com`)
2. Colle le mot de passe temporaire (fourni une seule fois par ton admin)
3. Tu arrives sur le **Dashboard éditeur** avec la liste des 95 lignes

> ⚠️ Si tu vois « Accès refusé », déconnecte-toi, reconnecte-toi. Si ça persiste, contacte Stéphane (`admin@misyapp.com`).

---

## 2. Comprendre le Dashboard

Chaque ligne de la liste affiche :

- **Pastille couleur** (reprend la couleur officielle de la ligne)
- **Nom + numéro** (ex: « 015 · Ankadifotsy – Ivato »)
- **2 pastilles de statut** :
  - **Gris « Aller » / « Retour »** → à vérifier, rien n'a encore été fait
  - **Orange « Envoyé »** → tu as déjà envoyé une version, elle est en attente de review admin
  - **Vert « En prod »** → l'admin a validé, ta version est déployée
  - **Rouge « À refaire »** → **l'admin t'a renvoyé la direction**. Tape la pastille rouge pour lire le motif. Tu dois reconstruire la direction.

Une **barre de recherche** filtre par numéro ou nom.

Une **barre de progression** en haut te donne le total de lignes entièrement validées (aller + retour).

---

## 3. Travailler une ligne : le wizard en 2 étapes

Tape sur une carte → ouverture du wizard.

Le wizard a **2 étapes** (stepper en bas) :

1. **Tracé aller** (départ → arrivée, avec arrêts)
2. **Tracé retour** (sens inverse, avec arrêts)

Pour chaque étape, tu as **1 seul bouton principal** :

- **« Construire la ligne XXX »** → lance le sub-flow guidé (voir §4)

ℹ️ **Pourquoi pas de « Valider tel quel » ?** Parce que les tracés actuels ont été générés automatiquement et contiennent des erreurs. Ton rôle, c'est précisément de tout reconstruire à la main sur le terrain. Le tracé visible à l'écran ne sert que de **repère visuel** pour t'orienter.

Un bouton secondaire **« Passer à l'étape suivante »** permet de sauter temporairement sur l'autre direction si tu veux (utile pour comparer aller vs retour avant de commencer).

---

## 4. Le sub-flow guidé « Construire » (4 sous-étapes)

C'est ici que tu fais le vrai travail. 4 sous-étapes (stepper en haut de l'écran) :

### Étape 1 — Départ
- Barre de recherche pour trouver le terminus (ex: « Ankadifotsy »). Zoom automatique.
- Clique sur la carte pour poser le point → une boîte de dialogue te demande le nom
- OU clique sur un **marker bleu OSM** (arrêt de bus déjà cataloguer en OSM) → le nom est pré-rempli, tu valides ou corriges
- Le pin « D » (vert) apparaît, avec un halo pulsant pour attirer l'œil

### Étape 2 — Arrivée
- Même UX que l'étape 1 (recherche / clic carte / clic marker OSM)
- Le pin « A » (rouge) s'affiche
- **Un tracé automatique est calculé** entre les 2 terminus via OSRM

### Étape 3 — Arrêts
- Carte avec **1255 arrêts OSM** pré-bundlés (markers bleus)
- Pour ajouter un arrêt : clique un marker → nom pré-rempli, ou clique ailleurs sur la carte → saisie libre
- Les arrêts sont ajoutés **dans l'ordre** (numérotés en orange 1, 2, 3…)
- Clique le bouton **« Recalculer le tracé »** après avoir posé tes arrêts → OSRM repasse par tous les arrêts dans l'ordre
- Liste des arrêts dans la sidebar à gauche. Clique la croix à côté d'un arrêt pour le retirer.

### Étape 4 — Affiner (optionnel)
- Si le tracé ne passe pas exactement où tu veux entre 2 arrêts, clique sur la carte pour ajouter un **waypoint** (point de passage sans arrêt)
- Clique « Recalculer le tracé » après avoir posé les waypoints
- Les waypoints ne sont pas affichés aux users finaux, ils servent juste à forcer le bus à passer par un endroit précis

### Repère visuel : calque orange pulsant
Tout au long des 4 sous-étapes, le tracé actuellement enregistré pour la direction apparaît en **orange semi-transparent qui pulse** en arrière-plan. C'est un **repère** pour t'orienter, pas une donnée à copier : tu dois tout reconstruire. Un toggle dans l'AppBar (icône « layers ») permet de le masquer si ça te gêne.

### Valider la construction
Bouton **« Terminer »** en bas à droite → renvoie au wizard. La direction est **envoyée à l'admin pour review** (pastille passe à orange « Envoyé » dans le dashboard).

---

## 5. Lire les retours de l'admin

Quand l'admin **rejette** une direction :

- La pastille passe en **rouge « À refaire »** sur le dashboard
- **Tape la pastille rouge** → un tooltip s'affiche avec le motif écrit par l'admin (ex: « le tracé ne passe pas par l'arrêt X », « le terminus est mal placé »)
- Clique la carte de la ligne → le wizard s'ouvre sur la direction concernée
- Clique « Construire la ligne XXX » → recommence le sub-flow en tenant compte du motif

Quand l'admin **valide** :

- La pastille passe en **vert « En prod »**
- Plus besoin d'y toucher. La direction est **immédiatement en prod** côté app (pas de rebuild nécessaire).

---

## 6. Créer une nouvelle ligne (rare)

Bouton rouge en bas à droite du dashboard : **« + Nouvelle ligne »**.

1. Numéro, nom, type (bus/taxi/tram), couleur
2. Construire l'aller via le sub-flow 4 étapes
3. Construire le retour via le sub-flow 4 étapes (l'aller s'affiche en fond comme repère)
4. Valider → la ligne est créée dans Firestore, en attente review admin

---

## 7. FAQ

**Q : J'ai fait une erreur, comment annuler ?**
A : Dans le sub-flow, icône **undo** en haut à droite annule la dernière action (jusqu'à 50 actions). Bouton **« Précédent »** en bas à gauche revient à la sous-étape précédente.

**Q : OSRM ne répond pas, erreur « OSRM KO ».**
A : Le serveur routier public est parfois surchargé. Réessaie 10-20s plus tard. Si ça persiste plusieurs minutes, contacte Stéphane.

**Q : Je ne vois pas la ligne que je cherche.**
A : Utilise la barre de recherche. Si elle n'existe vraiment pas, crée-la avec le bouton « + Nouvelle ligne ».

**Q : Je dois me déconnecter comment ?**
A : Ferme juste l'onglet. Ou utilise le menu utilisateur en haut à droite.

**Q : Je perds mon travail si je ferme l'onglet en plein sub-flow ?**
A : Oui — le sub-flow n'est sauvegardé qu'à la fin (bouton « Terminer »). Avant ça, tout est en mémoire navigateur. Termine tes sessions proprement.

---

## 8. Contacts

- **Admin transport** : Stéphane — `admin@misyapp.com`
- **Problème technique** : déconnecte-toi, vide le cache (Cmd+Shift+R sur Mac, Ctrl+Shift+R sur Windows), reconnecte-toi. Si ça persiste, capture d'écran + message à l'admin.

Bon boulot ! 🚌
