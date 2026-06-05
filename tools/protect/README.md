# Protection des tracés taxi-be contre le scraping

**Vérité de base** : tout ce que le navigateur affiche peut être copié. Les
tracés partent au client en JSON clair (`assets/.../transport_lines_public/`,
`transport_network/network_strands.json`). On ne rend pas le vol impossible —
on le rend **coûteux, détectable et juridiquement prouvable**. Trois couches,
toutes en place (06/06/2026).

## 1. Filigrane géométrique invisible — la PREUVE  (`watermark.py`)

À chaque déploiement, `deploy.sh` déforme les sommets des polylignes de
≤ 1,5 m selon un motif sinusoïdal **déterministe** seedé par
`(version = date+commit, numéro de ligne)`. Invisible (sous le trait, dans
le bruit GPS), sans effet sur l'app (snap/routing tolèrent ≫ 1,5 m). Le seed
de chaque déploiement est journalisé **hors dépôt** dans
`~/.misy/watermark-registry.jsonl` (= ce qui DATE une fuite).

Si nos lignes réapparaissent chez un concurrent :
```bash
# fichier suspect d'une ligne vs notre source (appariés par numéro) :
python3 tools/protect/watermark.py verify <suspect.geojson> \
    --version 20260606-ab12cd --key 133_aller
#   corr ≈ 1.0  → COPIE de notre filigrane (preuve, datée par la version)
#   corr ≈ 0    → données indépendantes
# ou un dossier entier de tracés suspects :
python3 tools/protect/watermark.py verify <dossier_suspect/> --version <V>
```
La version testée date la fuite : un même tracé corrèle à v=20260606 mais
pas à v=20260601 → on sait de quel déploiement la copie est issue.

Désactiver pour un deploy : `WATERMARK=0 ./deploy.sh`.

⚠️ Suppose les sommets préservés (cas du scrape direct du JSON, le plus
courant). Un concurrent qui resample/lisse fortement les tracés atténue la
corrélation — la couche légale prend alors le relais.

## 2. Légal — gratuit, dissuasif pour les entreprises

- Mention `©` + « droit sui generis des bases de données » injectée dans
  chaque JSON servi (`_wm`) et dans les **headers HTTP** (`X-Content-Source`,
  cf. couche 3). L'investissement de collecte terrain est précisément ce que
  ce droit protège (UE/inspirations malgaches ; opposable à un concurrent
  établi).
- À ajouter aux CGU de book.misy.app (hors scope de ce dossier) :
  > Les données de tracés, arrêts et horaires du réseau taxi-be affichées
  > dans l'application constituent une base de données dont Misy est le
  > producteur. Toute extraction ou réutilisation substantielle, répétée ou
  > systématique est interdite (droit sui generis des bases de données).

## 3. Friction serveur — filtre les paresseux  (vhost `book.misy.app`)

Sur `^/(assets/assets/transport_lines_public|transport_network)/` :
- `X-Robots-Tag: noindex, nofollow` (hors index des moteurs) ;
- `X-Content-Source` (© en clair dans la réponse) ;
- **journal dédié** `/var/log/nginx/book-data-access.log` AVEC le `Referer`
  → repérer les aspirations (un humain charge le bundle 1×/session via
  l'app ; un crawler le reprend en boucle, souvent sans Referer).

Détection (sur le serveur) :
```bash
# top IP sur les fichiers data, et part des accès SANS referer app :
awk '{print $1}' /var/log/nginx/book-data-access.log | sort | uniq -c | sort -rn | head
grep -c 'book.misy.app' /var/log/nginx/book-data-access.log   # legit
```

### Blocage par Referer — prêt, DÉSARMÉ
Dans le vhost, ce bloc est commenté (l'armer trop tôt = risque de casser
l'app si la Referrer-Policy change). À activer **après** avoir confirmé dans
les logs que l'app envoie bien `Referer: https://book.misy.app/…` :
```nginx
valid_referer none blocked book.misy.app *.misy.app;
if ($invalid_referer) { return 403; }
```
Rate-limit (`limit_req`) volontairement écarté : un chargement LÉGITIME fait
déjà ~186 requêtes (assets Flutter web servis un par un) — une limite assez
basse pour gêner un scraper casserait l'app. La valeur est ici dans le
filigrane + le légal, pas le débit.

## Tension stratégique (à trancher)

`PLAN_GTFS.md` prévoit de PUBLIER un feed GTFS public (Google Maps,
Transitland) → rendrait les tracés publics par construction. Si tu y vas, le
moat n'est plus la géométrie mais la **fraîcheur** (pipeline éditeur terrain)
+ la couverture + l'app : filigrane + légal suffisent, le GTFS devient la
vitrine. Ne pas faire les deux à moitié.
