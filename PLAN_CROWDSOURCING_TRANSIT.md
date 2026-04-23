# Plan — Crowdsourcing passif transit Misy (Waze-like)

> Document de planification, pas encore implémenté. Rédigé 2026-04-23.

## 1. Objectif

Offrir aux utilisateurs de Misy (rider app + book.misy.app) un signal temps
réel sur les bus de Tana, **sans installer de trackers physiques** dans les
véhicules, **sans accord des coopératives**, et **sans budget infra lourd**.

Principe : les utilisateurs Misy qui ouvrent l'app pendant un trajet en bus
contribuent passivement et anonymement leur position. Avec ~5 % de pénétration
utilisateur par ligne, le signal agrégé devient suffisant pour calculer des ETA
et des positions de véhicule estimées.

Sortie : flux **GTFS-RT** (complément du GTFS statique généré par le CLI) +
affichage in-app des positions live et ETA par arrêt.

## 2. Positionnement vs le reste du système transit

```
  transport_lines_published (Firestore)
            │
            ▼
  CLI gtfs → feed.zip (statique)         ← routes, shapes, frequencies
            │
            ▼
  Consumers externes (Google, Transitland, OTP)

  ───────────────────────────────────────────────────────────

  Users Misy (app)
       │   (GPS + activity)
       ▼
  transit_live_positions (Firestore, éphémère)
       │
       ▼
  Cloud Function scheduled 30s → agrégation
       │
       ▼
  transit_live_estimates (Firestore, lu par apps)
       │
       ▼
  GTFS-RT feed (vehicle_positions.pb) exposé sur book.misy.app/gtfs-rt/
```

Le GTFS statique (frequencies) reste le fallback quand aucun contributeur n'est
présent sur une ligne.

## 3. Détection passive : "l'utilisateur est-il dans un bus ?"

C'est le point le plus délicat. On ne peut pas demander explicitement à l'user
(friction tue l'adoption). Il faut inférer.

### Signaux disponibles

| Signal | Plateforme | Fiabilité | Usage |
|---|---|---|---|
| Vitesse GPS (5-40 km/h avec arrêts) | partout | moyenne | filtre grossier |
| Activity Recognition API | Android (natif), iOS (`CMMotionActivity`) | bonne | filtre "IN_VEHICLE" |
| Position sur polyline ligne connue (buffer 50m) | partout | haute | localisation + match ligne |
| Pattern stop-go régulier | partout | haute si >3 min d'obs | filtre anti-voiture privée |
| Toggle explicite utilisateur "Je suis dans le bus XX" | UX | parfaite | opt-in power user |

### Stratégie proposée

Score de confiance `0..1` combinant ces signaux, mis à jour toutes les 15–30s.
Contribution envoyée uniquement si `confidence > 0.6` **et** `activity == IN_VEHICLE`
**et** `position ∈ buffer(polyline_ligne, 50m)`.

Le toggle explicite existe aussi comme fallback (pour power users et pour
bootstrapping — au début on aura peu de data, un "Je prends la ligne 017" aide
à seeder).

### Anti faux-positifs

- Voiture privée sur un itinéraire de bus : pattern de vitesse (les voitures
  ont moins d'arrêts fréquents, vitesse moyenne plus haute) + si confidence
  score reste `< 0.6` plus de 5 min consécutives sur la ligne, on drop.
- Piéton à côté d'un bus en bouchon : filtre vitesse min 5 km/h soutenue.
- Moto-taxi : pattern très différent (vitesse moyenne plus haute, moins
  d'arrêts) → filtré naturellement par le score.

## 4. Stratégie d'échantillonnage

Battery-aware est **critique** sinon les gens désactivent le GPS de Misy.

| Contexte | Fréquence sampling | Stratégie |
|---|---|---|
| App foreground + confidence > 0.6 | 15 s | envoi Firestore immédiat |
| App foreground + confidence 0.3–0.6 | 30 s | local seulement, pas d'envoi |
| App backgrounded + in-vehicle détecté | 60 s | envoi Firestore batch |
| Véhicule arrêté (vitesse < 2 km/h) | 60 s | 1 envoi puis silence jusqu'à reprise |
| App backgrounded non-vehicle | 0 | stop GPS |

Budget cible : **< 3 %/h battery drain** côté utilisateur (à valider via tests
terrain longue durée).

## 5. Modèle de données Firestore

### Collection `transit_live_positions/{sessionId}` (éphémère)

TTL court (60–90s), un document par "tick" d'un contributeur. Session ID
tourné à chaque trip détecté (pas lié au user_id Firebase).

```
{
  session_id: "uuid-v4",        // rotatif, pas lié au compte user
  line_number: "017",
  direction: "aller",
  lat: -18.8912,
  lng: 47.5234,
  speed_ms: 6.2,
  heading: 87,                   // degrés boussole
  confidence: 0.82,
  app_version: "2.1.50+90",
  platform: "android",
  timestamp: serverTimestamp,
  // pas de user_uid, pas de device_id, pas d'IP
}
```

**Index requis** : `(line_number, direction, timestamp DESC)` pour le cron
d'agrégation.

**TTL** : politique Firestore TTL sur champ `expires_at = timestamp + 90s`.

### Collection `transit_live_estimates/{line_number}` (output lu par apps)

Recalculé toutes les 30s par un scheduled Cloud Function (ou un job côté
serveur OVH si on veut rester hors Cloud Functions — cf. section 10).

```
{
  line_number: "017",
  aller: {
    vehicles: [
      { lat, lng, speed_ms, confidence, contributor_count, last_seen_at },
      ...
    ],
    eta_by_stop: {
      "stop_id_1": { minutes: 3, confidence: 0.7 },
      "stop_id_2": { minutes: 8, confidence: 0.6 },
      ...
    },
    mean_speed_ms: 5.1,
    contributor_count_last_5min: 7,
    updated_at: serverTimestamp
  },
  retour: { ... },
  fallback_to_schedule: false   // true si aucun contributeur, apps utilisent frequencies
}
```

### Collection `transit_live_sessions_log/{YYYYMMDD}` (audit agrégé quotidien)

Jamais de data par user. Uniquement stats journalières pour observabilité.

```
{
  date: "2026-04-23",
  per_line: {
    "017": { aller: { peak_contributors: 5, total_contributions: 234 }, retour: {...} },
    ...
  },
  generated_at: timestamp
}
```

## 6. Anonymisation & vie privée

Point le plus sensible politiquement et légalement. Règles strictes :

1. **Aucun `user_uid` Firebase** dans `transit_live_positions`. La session ID
   est UUID v4 généré côté client, stockée localement dans SharedPreferences
   avec TTL 4h (puis rotation).
2. **Pas d'IP stockée**. Firestore ne logge pas les IP par défaut — OK.
3. **Opt-in explicite** au premier lancement post-feature : écran expliquant
   "On utilise ta position anonymement pour aider les autres users à savoir où
   sont les bus. Aucune info personnelle envoyée."
4. **Toggle désactivable** à tout moment dans Paramètres > Confidentialité.
5. **K-anonymity** : si `contributor_count < 2` sur un segment, on n'expose
   pas la position individuelle dans `transit_live_estimates` (sinon tu peux
   triangulé un user isolé). On attend un 2ᵉ contributeur ou on agrège au
   segment entier.
6. **Pas d'historique trajectoire par session** stocké côté serveur. Le TTL
   Firestore supprime les positions individuelles après 90s. Seul l'agrégat
   reste.
7. **Pas de logs bruts exportables** (pas de BigQuery export sur cette
   collection).
8. **Mention légale** : mettre à jour la CGU + politique de confidentialité
   de Misy avant rollout.

Risque si on néglige : un journaliste/concurrent reconstitue les trajets
individuels d'un user → image catastrophique pour Misy.

## 7. Matching ligne/direction côté client

L'app sait sur quelle ligne l'utilisateur se trouve via :

1. Snap position → polyline la plus proche dans `transport_lines_published`
   (calcul local, on a déjà les FC en cache après 1er load)
2. Filtre : polyline doit être à moins de 50m de la position
3. Disambiguation si plusieurs lignes candidates (fréquent en centre Tana) :
   - Utilise le heading de l'utilisateur vs direction de la polyline au point
     le plus proche
   - Utilise l'historique des 2-3 dernières positions pour confirmer la
     trajectoire
4. Si ambiguïté persiste > 2 min → demander à l'user (notification discrète
   "On pense que tu es sur 017 ou 142. Tu peux confirmer ?")

**Perf** : matching contre 95 polylines × ~50 vertices chacune = acceptable
en local JS/Dart (moins de 50ms par tick). Pas besoin de spatial index côté
client pour la V1.

Côté serveur, pas de re-matching : on fait confiance au `line_number` envoyé
par le client (le client a déjà fait le travail). Le serveur valide juste que
la position `(lat,lng)` est bien cohérente avec le buffer de la polyline
annoncée (anti-spoof basique).

## 8. Agrégation côté serveur

Deux options — le choix dépend de ta position "éviter les Cloud Functions".

### Option A : Cloud Function scheduled (30s)

- Lit les docs `transit_live_positions` des 60 dernières secondes, groupe
  par `(line, direction)`
- Clustering spatial des positions → détecte 1..N véhicules par direction
- Calcule mean_speed par cluster
- Projette ETA sur les stops en aval via `stop_times` du GTFS statique
- Écrit `transit_live_estimates/{line}`

Coût Firebase : 1 exec × 2 req/min × 43200 min/mois = 86400 execs/mois.
Budget Firestore : lectures ~100/exec × 86400 = 8.6M reads/mois (~ 3-5 €/mois).
**Pas énorme mais non nul.**

### Option B : Job Node.js sur OVH (book.misy.app)

Un petit daemon Node sur ton VPS qui :
- Utilise `firebase-admin` pour streamer `transit_live_positions` en temps
  réel
- Calcule en mémoire l'agrégat toutes les 30s
- Push `transit_live_estimates` dans Firestore

**Gratuit côté Firebase** (pas de CF). Utilise les ressources de ton VPS qui
sont déjà là. Cohérent avec ton choix "éviter les CF" pour GTFS statique.

Inconvénient : si ton VPS tombe, plus d'estimates. Mais fallback naturel
vers `frequencies.txt` côté app → dégradation gracieuse.

**Recommandation : Option B**, cohérente avec ta stratégie coût.

## 9. Sorties exploitées

### 9.1 In-app (Misy rider + book.misy.app onglet "Transport")

L'onglet "Transport" de bookingweb (`home_screen_web.dart:3057`) existe déjà et
affiche : recherche itinéraire A→B + carte des lignes. Il lit
`transport_lines_published` via `TransportLinesService`. On enrichit **ce même
onglet** avec :

- Sur la carte d'une ligne : markers bus live (1 par véhicule détecté), couleur
  dégradée selon `confidence`
- Sur les résultats d'itinéraire : ETA estimé au prochain arrêt de la ligne
  correspondante, avec indicateur de confiance ("basé sur 3 utilisateurs
  actuellement sur la ligne" vs "estimation horaire, pas d'observation live")
- Badge "Live" sur les lignes où `contributor_count_last_5min >= 2`

Côté rider app : mêmes enrichissements sur la vue équivalente (pas d'écran
transit dédié à construire, on augmente l'existant).

Côté data : nouveau stream Firestore `transit_live_estimates/{line}` lu en
parallèle du chargement des lignes. Pas d'impact sur `TransportLinesService`,
nouveau service séparé `transit_live_service.dart`.

### 9.2 GTFS-RT feed

Généré à la même fréquence que `transit_live_estimates` (30s), exposé en
Protobuf sur `book.misy.app/gtfs-rt/vehicle_positions.pb` et
`.../trip_updates.pb`. Consumable par :

- Google Maps Transit Partners (nécessite dossier séparé + validation Google)
- OpenTripPlanner
- Transitland
- Apps tierces

### 9.3 Heatmap debug (admin only)

Page admin (`/admin/transit-heatmap`) qui affiche les positions brutes des
dernières 5 min par ligne. Utile pour valider la qualité du signal avant
d'exposer aux users.

## 10. Estimation de faisabilité (math pénétration)

Hypothèses à valider :

- Base utilisateurs Misy active : ~ **X** users DAU (à chiffrer avec les data
  analytics)
- Part qui prend le bus en utilisant l'app au quotidien : **Y%** (~ 30% ? à
  chiffrer)
- Nombre de bus actifs simultanément Tana : ~ **1000** (95 lignes × ~10 bus
  actifs en moyenne par ligne aux heures de pointe)

### Scénario heure de pointe (7h-9h matin)

| Hypothèse DAU bus-users | Contributors par bus (moy) | Signal qualité |
|---|---|---|
| 1000 | 1.0 | marginal |
| 3000 | 3.0 | bon |
| 5000 | 5.0 | très bon |
| 10000 | 10.0 | excellent |

À chiffrer avec tes data analytics avant de lancer. **Si DAU bus-users < 1000,
la feature n'a pas assez de signal et il faut temporiser.**

### Scénario heure creuse (14h-15h)

Moitié moins de contributeurs → fallback gracieux vers `frequencies.txt`
schedule.

### Scénario nuit (21h-5h)

Zéro contributeur → afficher clairement "Pas de données live, dernier bus
estimé selon horaire".

## 11. Défis et risques

| Risque | Mitigation |
|---|---|
| Battery drain → uninstall | Sampling aggressive + tests 8h+ avant rollout |
| iOS background limitations | Utiliser `flutter_background_geolocation` (payant mais robuste) ou limiter à foreground-only pour V1 |
| False positives (voiture privée) | Score confidence strict, pattern stop-go obligatoire |
| Gaming / spam faux positions | Rate-limit par session_id (max 1 pos/10s), validation serveur cohérence polyline |
| Coût Firestore | Option B (Node sur VPS) + TTL agressif positions brutes |
| Dépendance GPS indoor | Accept dégradation, pas de dead-reckoning en V1 |
| Rejet politique coopératives | Ne jamais identifier un bus particulier, juste une position agrégée anonyme. Si questionné publiquement : "crowd-sourced community signal, no individual vehicle tracking". |
| Conformité données perso | Opt-in + CGU update + pas de user_id dans positions |
| Offline utilisateur | Buffer local (SharedPreferences ou sqflite), flush quand online. Cap buffer à 100 positions pour éviter abus. |

## 12. Phases de déploiement

### Phase 0 — Prérequis (avant tout code)

- [ ] Chiffrer la DAU "bus-users" actuelle via analytics → valider que la
      masse critique est atteignable (~ 1000+ DAU sur Tana bus-prone users)
- [ ] Update CGU + politique de confidentialité
- [ ] Décider Option A vs B (cf. section 8) → **recommandé B**
- [ ] Valider GTFS statique v1 fonctionnel (dépend du CLI `gtfs` à implémenter
      en premier — cf. `PLAN_GTFS.md` si créé séparément)

### Phase 1 — Instrumentation silencieuse (2-3 semaines dev)

Objectif : collecter des données sans exposer de feature users. Valider que le
signal est exploitable avant d'investir en UI.

- [ ] Service Flutter `transit_crowdsource_service.dart` : detection + sampling
      + envoi Firestore
- [ ] Toggle opt-in Paramètres (off par défaut) pour beta-testers manuels
- [ ] Collection `transit_live_positions` + TTL configurée
- [ ] Dashboard admin heatmap (`/admin/transit-heatmap`) pour visualiser le
      signal brut
- [ ] Déploiement rider app + recrutement 20–50 beta testeurs volontaires
- [ ] 2 semaines d'observation : signal exploitable ? Battery acceptable ?

### Phase 2 — Agrégation & ETA in-app (3-4 semaines dev)

- [ ] Daemon Node OVH (Option B) qui génère `transit_live_estimates`
- [ ] Widget "bus live" dans la carte des lignes
- [ ] Rollout progressif : 10% users → 50% → 100% avec feature flag
      `crowdsource_transit_enabled` via `feature_toggle_service.dart`
- [ ] Monitoring DAU bus-users + contributor_count p50/p95 par ligne

### Phase 3 — GTFS-RT public (1-2 semaines dev)

- [ ] Génération protobuf vehicle_positions + trip_updates
- [ ] Endpoint `book.misy.app/gtfs-rt/*.pb`
- [ ] Soumission Google Maps Transit Partners
- [ ] Soumission Transitland

### Phase 4 — Features avancées (long terme)

- [ ] Crowding level ("ce bus est bondé") via signal accelerometer /
      device density par bus
- [ ] Prédictions delays basées historique (ML simple, régression sur
      heure/jour/météo)
- [ ] Ajustement dynamique de `frequencies.txt` GTFS basé sur observations
      réelles des N dernières semaines
- [ ] Feedback loop : notifier le consultant terrain si une polyline ne
      matche jamais le signal crowdsourcé → la ligne a probablement changé

## 13. Stack technique suggéré

### Côté Flutter (rider app + bookingweb)

- `geolocator` (déjà présent) → GPS sampling
- `flutter_background_geolocation` (à ajouter) → sampling quand app
  backgrounded, gestion cross-plateforme des contraintes iOS/Android
- `activity_recognition_flutter` (à évaluer) → détection IN_VEHICLE
- Service : nouveau fichier `lib/services/transit_crowdsource_service.dart`
- Provider : nouveau `lib/provider/transit_crowdsource_provider.dart`
  (enabled, current_session_id, current_line_match, contributor_count_hint)
- Paramètres UI : étendre `lib/pages/view_module/settings/` avec toggle
  "Contribuer aux positions bus en temps réel"

### Côté serveur (option B — Node sur OVH)

- Nouveau dossier `server/transit-rt/` (pas dans `functions/` car pas CF)
- Node 20 + `firebase-admin` + `gtfs-realtime-bindings` (pour protobuf)
- Process manager : `pm2` ou `systemd`
- Expose endpoint HTTP pour GTFS-RT sur port interne, reverse-proxied par
  Nginx sur `book.misy.app/gtfs-rt/*`

### Côté data model

- Firestore collections : `transit_live_positions` (TTL), `transit_live_estimates`
- Firestore rules :
  ```
  match /transit_live_positions/{session} {
    allow create: if request.auth != null
                  && request.resource.data.keys().hasOnly([...])
                  && request.resource.data.session_id is string
                  && !('user_uid' in request.resource.data);
    allow read: if false;  // personne ne lit les positions brutes individuelles
    allow update, delete: if false;
  }
  match /transit_live_estimates/{line} {
    allow read: if true;  // public, agrégé
    allow write: if false;  // seul le daemon serveur écrit (via service account)
  }
  ```

## 14. Questions ouvertes à trancher

1. **Opt-in vs opt-out** à l'onboarding ? (recommandé opt-in pour conformité)
2. **Seuil confidence** de contribution (0.6 proposé, à ajuster après Phase 1)
3. **Background sampling iOS** : on paye `flutter_background_geolocation`
   (~$200/an licence) ou on limite la feature à foreground-only pour V1 ?
4. **Heatmap admin** : UI web dans bookingweb ou dashboard externe (Grafana,
   Metabase) ?
5. **K-anonymity threshold** : k=2 suffisant ou k=3 plus prudent ?
6. **Quand fallback sur frequencies.txt** : contributor_count < 1 sur les
   dernières 5 min ? 2 min ? À calibrer.
7. **Rotation session_id** : 4h (proposé) ou à la fin de chaque trip
   détecté (plus propre mais plus complexe) ?
8. **Crowding level** Phase 4 : stocker l'info si oui/non accelerometer densité
   dès Phase 1 (futur-proof) ou attendre ?
9. **Positionnement juridique** : on traite ça comme "données statistiques
   anonymisées" (pas de GDPR strict) ou "données personnelles pseudonymisées"
   (plus lourd, plus safe) ? Consulter un juriste avant rollout massif.

## 15. Métriques de succès

À définir en amont pour juger si la feature fonctionne :

- **Coverage** : % des lignes avec au moins 1 contributeur pendant l'heure de
  pointe (cible V1 : 70%+)
- **Précision ETA** : écart moyen entre ETA prédit et arrivée réelle observée
  (cible V1 : < 3 min d'erreur sur ETA < 15 min)
- **Adoption** : % users opt-in (cible V1 : 40%+)
- **Battery impact** : feedback qualitatif + retention des users opt-in vs
  opt-out (cible : pas de différence statistique)
- **Utilisation in-app** : % de sessions où l'user consulte le widget "bus
  live" quand il est disponible

## 16. Dépendances avec les autres chantiers

| Chantier | Dépendance |
|---|---|
| GTFS statique CLI | **Bloquant** — besoin de `stops.txt`, `routes.txt`, `shapes.txt` pour matcher les positions aux lignes et projeter ETA |
| Transport editor (consultant) | Indirecte — qualité des polylines influe sur la qualité du matching client |
| Analytics DAU | **Bloquant Phase 0** — besoin de chiffrer la base user bus-prone avant d'investir |
| Feature toggle service | Utile pour rollout progressif Phase 2 |
| Firebase rules | Update requise (nouvelles collections) |

---

## Annexe A — Exemple concret de flow utilisateur

Nirina sort du taxi-be ligne 017 à Analakely et prend son bus pour rentrer à
Ambohimanarina :

1. 07h12 — Nirina monte dans le bus. App Misy en background depuis ce matin.
2. 07h12 — `transit_crowdsource_service` détecte : activity = IN_VEHICLE,
   vitesse 18 km/h, position ∈ buffer ligne 017 aller. Confidence 0.45
   (pas assez).
3. 07h14 — Après 2 min, 3 positions consécutives cohérentes. Pattern stop-go
   détecté (bus s'est arrêté 2×). Confidence monte à 0.72. Session créée,
   contributions envoyées à Firestore.
4. 07h14–07h45 — Position envoyée toutes les 15s. L'app est backgroundée
   mais le service de sampling tourne (iOS/Android background mode).
5. 07h30 — Sur le téléphone de Tahiry (ligne 143, qui veut savoir quand son
   bus arrive à Ankadifotsy), l'app affiche "Prochain bus dans ~4 min,
   basé sur 4 utilisateurs actuellement sur la ligne".
6. 07h45 — Nirina descend à Ambohimanarina. Vitesse tombe à 0 (marche),
   activity = WALKING. Session fermée côté client.
7. 07h46 — Les 90 dernières positions de Nirina sont supprimées par TTL
   Firestore. Aucun historique de son trajet n'est conservé.

## Annexe B — À lire avant démarrage

- Spec GTFS-Realtime : https://gtfs.org/realtime/
- Transitland guidelines pour publishers : https://www.transit.land/documentation
- Google Maps Transit Partners requirements : (dossier dédié à récupérer
  auprès de Google — process lourd)
- Étude cas Citymapper sur crowdsourced transit : à rechercher, bon précédent
- Waze Transit Partners (pour inspiration modèle, pas techno) :
  https://www.waze.com/wazeforcities/
