# Fond de plan `misy2` (tiles.misy.app) — copie versionnée

**Source de vérité déployée** : `/opt/misy-tiles/ts-styles/misy2.json` sur l'OVH
(conteneur docker `misy-tiles`, config `/opt/misy-tiles/config.server.json`).
Ce dossier versionne le style pour traçabilité/rollback. Copie de travail
locale : `~/StudioProjects/_tools/tiles/ts-styles/misy2.json`.

## Historique
- v3 (05/06/2026, EN PROD) : match référence Uber — base plate froide #F2F3F5,
  routes blanches hiérarchisées par la largeur + casings froids, trunk lavande
  #A6B5DE (charte), quartiers sobres z≥13, police **Azo Sans** (glyphes
  générés serveur : conteneur node:20 + fontnik — fontnik ne compile pas sur
  Mac), bâtiments z≥14,5, POI texte z≥15,2.
- v2 → v2.5 : itérations chaud/froid/contraste (rejetées, cf. mémoire projet).
- `misy` (legacy, conservé sur le serveur) : 11 couches lavande — rollback =
  rebuilder l'app avec `RASTER_TILE_URL=https://tiles.misy.app/styles/misy/{z}/{x}/{y}.png`.

## Itérer (~2 min, AUCUN redeploy app)
1. Éditer `~/StudioProjects/_tools/tiles/ts-styles/misy2.json`
2. Préviz locale : `cd ~/StudioProjects/_tools/tiles && npx tileserver-gl --config config.json --port 8090`
   (style `misy2preview` = même fichier avec fonts Noto, les glyphes Azo
   n'existant que sur le serveur)
3. `scp -i ~/.ssh/id_rsa_misy ts-styles/misy2.json ubuntu@51.254.141.103:/tmp/`
4. `ssh … "sudo cp /tmp/misy2.json /opt/misy-tiles/ts-styles/ && sudo docker restart misy-tiles"`
5. Recopier ici + commit.

⚠️ Tuiles cachées 7 j navigateur : un changement de style se teste en fenêtre
privée ; une REFONTE visible par tous = nouvel id de style + flip de
`RASTER_TILE_URL` (cf. DEPLOYMENT_WEB.md).

## Notes serveur (05/06/2026)
- gzip activé sur le vhost nginx `book.misy.app` UNIQUEMENT (main.dart.js
  7,9 Mo → 2,3 Mo) — jamais en global : casserait les range-requests pmtiles.
- Jamais de `.bak` dans `/etc/nginx/sites-enabled/` (inclus → server_name en
  conflit, bloc ignoré en silence) → `/etc/nginx/backups/`.
- Le vhost book a le bloc :80 (redirect) AVANT le :443 — toute directive va
  dans le 2e bloc.
