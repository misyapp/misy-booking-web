---
name: sync-riderapp
description: Sync portable changes from the riderapp (mobile) repository into misy-booking-web. Reads new commits in /Users/stephane/StudioProjects/riderapp since the last synced hash (stored in .last_sync_riderapp), triages them (mobile-only vs portable to web), proposes each portable commit to the user, and applies after approval. Use when the user says "sync riderapp", "porte les nouveautés riderapp", "check riderapp", "qu'y a-t-il de neuf côté riderapp", or invokes /sync-riderapp.
---

# Sync riderapp → misy-booking-web

riderapp est la source de vérité maintenue par Stéphane. Ce repo (misy-booking-web) doit suivre les évolutions pertinentes pour le web. Pas toutes : iOS/Android-only à exclure systématiquement.

## Procédure

### 1. Lire le pointeur

```bash
LAST=$(cat .last_sync_riderapp 2>/dev/null || echo "")
```

Si le fichier n'existe pas ou est vide : demander à l'utilisateur quel hash riderapp utiliser comme point de départ. Ne JAMAIS prendre HEAD~50 par défaut (trop large).

### 2. Lister les commits non portés

```bash
cd /Users/stephane/StudioProjects/riderapp
git log --oneline "${LAST}..HEAD"
```

Si la sortie est vide : dire "Rien à porter, repo à jour avec riderapp@${LAST}" et terminer.

### 3. Triage par commit

Pour chaque commit, déterminer :

**EXCLU mobile-only** (skipper sans demander) :
- Live Activity iOS (`live-activity`, `ActivityKit`, `Dynamic Island`)
- CallKit / ConnectionService
- Firebase Phone Auth (SMS Android)
- Calendar (`add_2_calendar`, `EKEventEditView`, `Intent.ACTION_INSERT`)
- App Tracking Transparency iOS (`ATT`, `IDFA`)
- Sign in with Apple (iOS-specific)
- Crashlytics natif (web SDK limité)
- iOS/Android schemes, Podfile, `ios/Runner.xcodeproj`, `android/app/build.gradle`
- Push notifications natives (APNs, FCM Android-specific)
- WebRTC voice/call mobile
- Device fingerprint mobile (IDFV, Android ID)
- Modifs `ios/`, `android/` exclusivement

**PORTABLE web** (proposer) :
- Pricing / matching / cancellation logic
- Firestore services (`firestore_services.dart`, queries)
- Provider state (`trip_provider`, `pricing_provider`, etc.)
- Models (`models/`, `modal/`)
- UI bottom sheets, screens, widgets non-mobile-only
- i18n (`language_strings.dart`)
- Pricing config v2, scenarios
- Cloud Functions config / endpoints (`booking_service_scheduler`)
- Analytics (Firebase Analytics events, hors ATT iOS et SKAdNetwork)
- Promocodes, wallet logic, geo zones
- Routing OSRM, geocoding, places
- Loyalty system
- Invoice PDF logic

**À VÉRIFIER** (poser une question rapide à l'utilisateur) :
- Refactors larges qui touchent à des dizaines de fichiers (trip_provider split, etc.) — souvent à NE PAS porter
- Tout ce qui touche à `lib/services/transport_*`, `lib/pages/view_module/transport_*`, `lib/pages/view_module/transport_editor`, `lib/pages/view_module/transport_public` → ces fichiers SONT WEB-ONLY, riderapp ne les a pas → si un commit riderapp les modifie c'est forcément un rename/move accidentel, à ignorer
- Tout ce qui touche à `web/`, `index.html`, `manifest.json`, service worker → web-only spec

### 4. Pour chaque commit PORTABLE

Afficher à l'utilisateur :
```
<hash> <subject>
Files: <list>
Verdict: PORTABLE
Action proposée: [appliquer / sauter / voir le diff complet]
```

Puis :
1. Lire les fichiers touchés côté web pour voir s'ils existent (un service mobile peut ne pas avoir d'équivalent web — dans ce cas créer ou skipper selon le commit)
2. Appliquer le patch avec Edit/Write
3. Si web et riderapp ont divergé sur ces lignes, NE PAS forcer le patch — montrer le diff à l'utilisateur et demander

### 5. Mise à jour du pointeur

À la fin (même partielle) :
```bash
echo "<dernier-hash-traité>" > .last_sync_riderapp
```

Le hash écrit est celui du DERNIER commit traité (porté OU explicitement skippé), pas forcément HEAD. Si un commit a été VU mais REJETÉ par l'utilisateur (pas portable), on l'inclut quand même dans le hash écrit pour ne pas le re-proposer la prochaine fois.

### 6. Compte-rendu

Une ligne par commit traité :
- ✅ <hash> porté
- ⏭ <hash> skipped (mobile-only)
- ❌ <hash> conflit — à traiter manuellement
- ❓ <hash> à reposer plus tard

Et le nouveau pointeur : `📍 .last_sync_riderapp → <hash>`

## Garde-fous

- **Jamais de cherry-pick git** : le mapping de chemins entre riderapp et web n'est pas 1:1 (web a transport_*, riderapp a callkit_*). Toujours appliquer manuellement avec Edit.
- **Toujours montrer le diff riderapp avant d'appliquer** si le commit touche à >20 lignes ou à un fichier critique (trip_provider, firestore_services).
- **Ne pas inventer de fonctions** : si riderapp utilise `CurrencyService.convertToMGA` et que web ne l'a pas, soit on porte aussi le service, soit on skippe la partie multi-devises. Demander.
- **Tester mentalement après chaque apply** : est-ce que l'import existe ? est-ce que la fonction appelée existe côté web ? est-ce que ça compile ?

## Hash de référence riderapp au moment de l'écriture du skill

`61a7abc` — feat(email): SVG markers versionnés + assistance vers support@misy.app (2026-05-27)

Si `.last_sync_riderapp` est vide, démarrer depuis ce hash pour ne pas re-proposer les ports déjà faits dans le batch initial de 2026-05-27.
