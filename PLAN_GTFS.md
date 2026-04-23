# Plan — GTFS statique Misy Tana

> Document de planification, pas encore implémenté. Rédigé 2026-04-23.
> Voir aussi `PLAN_CROWDSOURCING_TRANSIT.md` pour le volet temps réel (GTFS-RT).

## 1. Objectif

Publier un **GTFS statique officiel** pour le transport bus/taxi-be de Tana,
généré depuis les données validées par les consultants via le transport editor.

Consumers visés V1 :
- **App Misy rider** (mobile Flutter) — lit `transport_lines_published` via `TransportLinesService`
- **book.misy.app onglet "Transport"** (web Flutter, déjà en place, public, pas de gating auth) — même source
- **Consumers externes** (Google Maps Transit Partners, Transitland, OTP) — via `feed.zip` statique

**Point clé** : la consommation côté Misy (rider + bookingweb) passe **déjà** par
`TransportLinesService` qui lit Firestore `transport_lines_published` en prio sur
les assets bundlés. L'onglet "Transport" de bookingweb est déjà opérationnel
(recherche itinéraire A→B + carte des lignes) — cf. `home_screen_web.dart:3057`.
Le GTFS statique est donc **uniquement un dérivé pour consumers externes**, pas
une migration du modèle de données interne. Ça tranche directement le dilemme
"bundle vs Firestore live" (cf. section 3) en faveur du scénario A.

## 2. Décisions acquises (validées en conversation 2026-04-23)

| Question | Décision |
|---|---|
| Horaires | `frequencies.txt` (pas de stop_times à heures précises V1) |
| Agency | Agence unique V1 (pas de modélisation coopératives) |
| Périmètre | Tana uniquement V1 |
| Consumers apps | Misy rider + bookingweb (les deux) |
| Hébergement feed | Fichier statique sur `book.misy.app/gtfs/feed.zip` (option C) |
| Génération | Via `node scripts/transport_editor_pull_cli.js gtfs` + rsync OVH |
| Pas de Cloud Function HTTP | Économiser sur les CF |

## 3. Le dilemme "coder en dur" vs "Firestore live" — à trancher

### Contexte

Aujourd'hui, `lib/services/transport_lines_service.dart` lit Firestore
`transport_lines_published` **en priorité** sur l'asset bundlé. C'est ce
mécanisme qui permet le **hot-update sans rebuild** après qu'un admin valide
une ligne : Firestore propage la nouvelle FC aux apps déployées en quelques
secondes.

Si on passe à un modèle "tout bundlé GTFS" dans les apps, **on perd ce bénéfice** :
chaque nouvelle ligne validée = rebuild + deploy des apps (iOS, Android, web).
Avec 95 lignes à valider terrain, ça ferait potentiellement 95 deploys.
Inacceptable en pratique.

### Trois scénarios possibles

#### Scénario A — GTFS statique = dérivé, Firestore reste la source live

Les apps continuent de lire `transport_lines_published` en priorité comme
aujourd'hui. Le GTFS statique est généré **uniquement pour les consumers
externes** (Google, Transitland, OTP) et éventuellement pour export/backup.

```
transport_lines_published (Firestore, live)
       │
       ├──▶ Apps Misy (lecture directe, hot-update préservé)
       │
       └──▶ CLI gtfs → feed.zip ──▶ Consumers externes
```

- ✅ Hot-update préservé
- ✅ Pas de rebuild à chaque validation
- ✅ Architecture actuelle inchangée côté apps
- 🟡 Les apps n'utilisent pas le standard GTFS en interne (modèle custom FC)
- 🔴 Coût Firestore reads côté apps (mais faible — document par ligne, lu
  1×/session)

#### Scénario B — GTFS statique = source de vérité unique, bundle intégral

Les apps n'utilisent plus `transport_lines_published`. Le GTFS est bundlé
dans les assets et rebuild/deploy à chaque maj.

```
transport_lines_published (Firestore)
       │
       ▼
CLI gtfs → feed.zip ──▶ bundlé dans assets/gtfs/ des apps
                  │
                  └──▶ rsync book.misy.app/gtfs/feed.zip (consumers externes)
```

- ✅ Une seule source de vérité, standard GTFS partout
- ✅ Aucun appel Firestore en runtime pour les lignes
- ✅ App fonctionne offline dès le premier launch
- 🔴 **Perte du hot-update** : rebuild + deploy app à chaque maj
- 🔴 Incompatible avec le rythme consultant terrain (95 validations)

#### Scénario C — GTFS statique hybride : bundle de base + override Firestore

Les apps embarquent le GTFS au moment du build comme fallback offline. En
runtime, elles fetch `feed.zip` depuis `book.misy.app/gtfs/feed.zip` avec
check ETag 1×/jour (ou au resume après backgrounded > 6h) et remplacent le
cache local si nouvelle version.

```
transport_lines_published (Firestore)
       │
       ▼
CLI gtfs → feed.zip (rsync OVH) ◀── check ETag 1×/jour ── Apps Misy
       │
       └── bundle dans assets/gtfs/ (fallback offline pour 1er launch)
```

- ✅ Hot-update préservé (latence < 24h, acceptable pour GTFS statique)
- ✅ Standard GTFS partout, une seule source de vérité
- ✅ Offline first-launch OK
- ✅ Pas de dépendance Firestore runtime côté apps pour les lignes
- 🟡 Complexité : gestion du cache, version comparison, rollback si feed corrompu
- 🟡 Latence jusqu'à 24h entre validation admin et propagation apps (vs quasi-
  instantané avec Firestore live)

### Tableau de décision

| Critère | A (Firestore live) | B (bundle only) | C (bundle + fetch) |
|---|---|---|---|
| Hot-update post-validation | instantané | ❌ rebuild requis | < 24h |
| Complexité implémentation | faible (status quo) | moyenne | moyenne-haute |
| Coût Firestore runtime | bas mais non nul | zéro | zéro |
| Offline first-launch | dépend du bundle asset | oui | oui |
| Cohérence GTFS-RT (cf. autre doc) | mismatch format | cohérent | cohérent |
| Effort migration apps | nul | fort | moyen |

### Décision — Scénario A retenu (2026-04-23)

Tranché en conversation : l'onglet "Transport" de bookingweb + l'app rider
consomment **déjà** `transport_lines_published` via `TransportLinesService`.
Pas de raison de toucher à cette archi. Le CLI `gtfs` produit un feed **dérivé
pour consumers externes uniquement**.

Implications :
- Zero changement dans `home_screen_web.dart` onglet Transport
- Zero changement dans `TransportLinesService`
- Zero rebuild/deploy app à chaque validation admin — hot-update préservé
- Le feed `book.misy.app/gtfs/feed.zip` est une **sortie annexe** de la même
  source de vérité, pas un remplacement

**Scénario C** (migration apps vers GTFS bundlé) archivé comme piste long-terme,
à ressortir uniquement si :
- Coût Firestore devient visible (base user × 10)
- GTFS-RT crowdsourcé impose une cohérence format côté apps
- Besoin offline-first plus fort (app rider utilisée hors ligne prolongée)

**Scénario B** écarté définitivement.

## 4. Que fait la sous-commande `node scripts/transport_editor_pull_cli.js gtfs`

Quel que soit le scénario retenu côté apps, le CLI fait toujours la même chose.

### Entrées

- Firestore `transport_lines_published/*` (source de vérité)
- `assets/osm_bus_stops_tana.json` (canon pour dédup des stops — 1255 stops OSM)
- Optionnel : `scripts/gtfs_config.json` (tranches horaires, vitesses moyennes,
  agency info — à créer)

### Traitement

1. Fetch `transport_lines_published/*`
2. Pour chaque ligne × direction :
   - Extrait LineString → shape
   - Extrait Points type=stop → stops de ce trip
3. Dédup global des stops :
   - Match par `osm_id` si présent dans la FC → reuse stop_id canonique
   - Sinon match par proximité (< 30 m) + similarité nom (Levenshtein > 0.8)
   - Sinon nouveau stop_id alloué
4. Calcul `stop_times` via OSRM (durée projetée entre chaque paire de stops
   consécutifs, départ à 00:00 du service day)
5. Génère CSV en mémoire :
   - `agency.txt`
   - `stops.txt` (stops dédupliqués)
   - `routes.txt` (95 lignes)
   - `trips.txt` (190 trips = 95 × 2 directions × 1 service)
   - `stop_times.txt`
   - `shapes.txt`
   - `frequencies.txt`
   - `calendar.txt`
   - `feed_info.txt`
6. Zip → `build/gtfs/feed.zip`
7. Copie humaine JSON → `build/gtfs/feed.json` (debug/diff)

### Options

- `--validate` : lance MobilityData `gtfs-validator` local si présent dans PATH
- `--deploy` : rsync `feed.zip` vers `/var/www/book.misy.app/gtfs/feed.zip`
- `--dry-run` : génère sans écrire
- `--only=<ligne>` : utile pour debug une ligne unique

### Sorties déployées

- `https://book.misy.app/gtfs/feed.zip` (fichier statique Nginx)
- `https://book.misy.app/gtfs/feed.json` (version humaine, optionnelle, pour
  debug)

## 5. Valeurs de configuration à caler

### Tranches horaires `frequencies.txt` (valeurs par défaut V1)

Propositions à valider — mêmes valeurs pour toutes les lignes V1, override
par ligne plus tard quand on aura du signal crowdsourcé.

| Tranche | Headway |
|---|---|
| 05:00–08:00 (pointe matin) | 5 min |
| 08:00–16:00 (journée) | 10 min |
| 16:00–20:00 (pointe soir) | 6 min |
| 20:00–22:00 (soirée) | 15 min |

### `agency.txt`

```
agency_id: misy-tana
agency_name: Misy Transport Tana
agency_url: https://book.misy.app
agency_timezone: Indian/Antananarivo
agency_lang: fr
```

### `calendar.txt`

Service unique `weekday_weekend`, actif tous les jours de la semaine,
`start_date` = date de génération, `end_date` = +365 jours.

→ Question : on distingue dimanche (moins de bus) ou pas en V1 ? Proposition :
pas de distinction en V1, ajuster plus tard si le crowdsourcing révèle un
pattern clair.

### Vitesses pour `stop_times`

OSRM entre chaque paire de stops (déjà dans le codebase via
`transport_osrm_service.dart`). Avantage : précision inter-stops en fonction
de la géométrie réelle. Inconvénient : nécessite X appels OSRM par ligne
(X = nombre de stops), à exécuter lors de la génération CLI.

→ Coût OSRM public : 1× par stop × 2 directions × 95 lignes ≈ 2000 requêtes.
Respecter 1 req/s = ~35 min de génération. Acceptable. Avec fallback proxy
OVH si rate-limit public.

## 6. Intégration apps (selon scénario retenu)

### Si scénario A (recommandé)

Rien à changer côté apps. Le CLI génère juste le feed pour les consumers
externes. `transport_lines_service.dart` continue de lire Firestore.

### Si scénario C (cible moyen-terme)

- Nouveau service Flutter `lib/services/gtfs_feed_service.dart` :
  - Load bundle `assets/gtfs/feed.zip` si cache local vide
  - Fetch `book.misy.app/gtfs/feed.zip` avec ETag au launch si > 24h depuis
    dernier check
  - Parse CSV en mémoire (lib `csv` de pub.dev, pas besoin de dépendance
    GTFS dédiée — les fichiers sont simples)
  - Expose API équivalente à `transport_lines_service.dart` actuel
- `transport_lines_service.dart` devient un adapter au-dessus de
  `gtfs_feed_service` pour minimiser les changements dans les écrans consumer
- Deprecate `transport_lines_published` Firestore lecture côté apps (collection
  conservée comme source de vérité pour le CLI)

## 7. Questions ouvertes

1. **Scénario A vs C** : on vise A d'abord ou on saute directement à C ?
2. **Tranches horaires frequencies** : valeurs proposées OK ou à ajuster ?
3. **Dimanche distinct** dans calendar V1 ou non ?
4. **agency_name** exact : "Misy Transport Tana" ? "Misy Bus Tana" ?
5. **OSRM pour stop_times** : on accepte les 35 min de génération ou on
   simplifie avec une vitesse moyenne constante V1 ?
6. **Endpoint public GTFS** : tranché — fichier statique servi par Nginx sur
   `book.misy.app/gtfs/feed.zip`. Pas de sous-domaine dédié. L'UI publique de
   consultation reste l'onglet "Transport" de bookingweb (déjà en place). Le
   `feed.zip` est pour les consumers externes uniquement (Google, Transitland,
   OTP).
7. **Validation** : on s'engage à passer le MobilityData validator avec zéro
   erreur avant publication ?
8. **Version / ETag** : incrémenté à chaque génération (timestamp) ou sur
   hash du contenu (évite bumps inutiles si rien n'a changé) ?
9. **Soumission à Google Maps Transit Partners** : process lourd (dossier
   administratif, SLA 99.5%, contact Mada/Afrique). On lance le process
   quand V1 est stable ? Pas V1 ?
10. **feed_info.publisher** : "Misy" ou une entité légale spécifique ?

## 8. Roadmap

### V0 — Spec & décisions (1-2 jours, pas de code)

- [x] ~~Trancher scénario A vs C~~ — **Scénario A retenu** (2026-04-23)
- [x] ~~Valider endpoint public~~ — **`book.misy.app/gtfs/feed.zip`** (2026-04-23)
- [ ] Valider valeurs config (tranches horaires, agency, calendar)
- [ ] Trancher : OSRM par stop vs vitesse moyenne constante (cf. question 5)
- [ ] Trancher : dimanche distinct ou non (cf. question 3)

### V1 — CLI gtfs + feed statique (1-2 semaines dev)

- [ ] `scripts/gtfs_config.json` avec les valeurs par défaut
- [ ] Module `scripts/lib/gtfs_builder.js` (génération CSV)
- [ ] Module `scripts/lib/stop_dedup.js` (dédup par osm_id + proximité)
- [ ] Sous-commande `gtfs` dans `transport_editor_pull_cli.js`
- [ ] Option `--validate` si gtfs-validator installé
- [ ] Option `--deploy` rsync OVH
- [ ] Config Nginx sur OVH : servir `/gtfs/` avec headers corrects
      (`Content-Type: application/zip`, `Cache-Control`, ETag automatique)
- [ ] Test bout-en-bout : génération → upload → fetch → parse → validation

### V2 — Intégration apps

Non applicable en V1 (scénario A retenu — les apps continuent d'utiliser
`TransportLinesService` / Firestore sans changement). Archivé pour référence
long-terme dans la section 3 ci-dessus.

### V3 — Publication externe (1 semaine process + dossier)

- [ ] Soumission Transitland (simple, formulaire en ligne)
- [ ] Soumission OpenTripPlanner community registry
- [ ] Dossier Google Maps Transit Partners (long, plusieurs mois)

## 9. Dépendances et cohérence avec le reste

| Chantier | Relation |
|---|---|
| Transport editor (consultant) | Amont — qualité des FC publiées conditionne qualité GTFS |
| Crowdsourcing GTFS-RT (`PLAN_CROWDSOURCING_TRANSIT.md`) | Aval — GTFS-RT enrichit le GTFS statique. Cohérence des `route_id`, `stop_id`, `trip_id` impérative entre les deux flux |
| `transport_lines_published` Firestore | Source du CLI dans tous les scénarios |
| `assets/osm_bus_stops_tana.json` | Canon pour dédup des stops |
| OSRM (proxy OVH + public) | Dépendance génération stop_times |
| Nginx sur OVH | Sert le feed public, config à adapter |

---

## Annexe A — Format exact du feed attendu (rappel)

Un `feed.zip` contient (minimum V1) :

- `agency.txt` — 1 ligne
- `stops.txt` — N lignes (stops dédupliqués globalement)
- `routes.txt` — 95 lignes
- `trips.txt` — 190 lignes (95 × 2 directions)
- `stop_times.txt` — Σ stops par trip × 2 directions
- `shapes.txt` — Σ vertices × 2 directions
- `calendar.txt` — 1 ligne (service unique 7j/7)
- `frequencies.txt` — 190 × 4 lignes (4 tranches horaires)
- `feed_info.txt` — 1 ligne

Total estimé : ~5000-10000 lignes CSV, zippé ~200-500 KB.

## Annexe B — À lire avant démarrage

- Spec officielle GTFS : https://gtfs.org/schedule/reference/
- MobilityData gtfs-validator : https://github.com/MobilityData/gtfs-validator
- Transitland publishing guide : https://www.transit.land/documentation
- Google Transit Partners : (accès sur dossier, pas public)
