# Espace client SALFA sur book.misy.app — analyse & plan

> **Objectif** (Stéphane, 2026-06-04) : donner à SALFA un accès direct à leur compte sur
> **book.misy.app** pour qu'ils puissent (1) **réserver leurs courses** eux-mêmes et
> (2) **télécharger leurs factures** — au nom de SALFA / Hariniaina RABARY, **TVA 0 %** —
> sans passer par la re-facturation manuelle du dashboard.

---

## 1. Comment on facture SALFA aujourd'hui (manuel, dashboard)

Process actuel documenté dans la mémoire Claude (`tool_reinvoice_for_client.md`) :

- Les **opérateurs SALFA réservent avec leurs comptes riderapp persos** → la facture native
  (`rider_invoice`) sort au nom de l'opérateur, pas de SALFA.
- À chaque demande, on re-facture à la main depuis le dashboard :
  ```bash
  TVA_RATE=0 php scripts/FIX/reinvoice_for_client.php jxvd2gAsZuMHOgDMZrCgviiafKR2 <bookingId...>
  ```
  → force le client facturé = **Hariniaina RABARY** (`jxvd2gAsZuMHOgDMZrCgviiafKR2`,
  0328389639, hariniainarabary@yahoo.fr), **TVA 0 %** (libellé au taux réel), préserve le
  N° de facture original, détecte l'émetteur flotte MISY TECHNOLOGY, PDF sur le Bureau.
- **3 lots livrés** : 01/06 (5 courses), 02/06 (2 courses, passage à 0 %), 04/06 (3 courses).

**Comptes SALFA connus (Firebase Auth = mêmes comptes riderapp/booking-web) :**

| Rôle | Nom | UID | Tél |
|---|---|---|---|
| Client facturé | Hariniaina RABARY | `jxvd2gAsZuMHOgDMZrCgviiafKR2` | 0328389639 |
| Opérateur | Sarah Niaina Marcia | `e68jLndiqgQKxhsPg4IyuRlvCgn1` | — |
| Opérateur | Herinjaka Rasolofonirina | `MPeJAyquYSNYeMaX7JYATlz0Cp73` | — |
| Opérateur | Tsiory ANDRIANIVO | `1L8TQKJ3iyRHz14YviV2ziEiSg72` | 0323457205 |

---

## 2. Ce qui existe déjà dans misy_booking_web

| Brique | État | Où |
|---|---|---|
| **Auth riderapp partagée** | ✅ Firebase Auth (mêmes comptes que l'app), login/OTP/Google/FB, mode invité | `lib/pages/auth_module/`, `lib/provider/auth_provider.dart` |
| **Espace client** | ✅ Mes courses (2 onglets actuelles/passées), détail course, profil, wallet, promos, fidélité | `lib/pages/view_module/my_booking_screen.dart`, `booking_detail_screen.dart` |
| **Téléchargement facture** | ✅ lien depuis le détail course → champ `rider_invoice` (URL Storage) | `booking_detail_screen.dart` |
| **Création de course** | ✅ écrit `bookingRequest` complet (immédiate + planifiée avec escalade Cloud Scheduler T-20/T-15) | `lib/provider/trip_provider.dart` (~`createBooking`) |
| **Génération PDF facture** | ✅ côté client Flutter, upload Storage | `lib/services/generate_invoice_pdf_service.dart` |
| **`companyId` sur user/booking** | 🟡 le champ existe et est propagé au booking si présent — **aucune logique derrière** | `user_modal.dart:37`, `trip_provider.dart:3040` |
| **`customBiller {name,nif,stat,address}`** | 🟡 override de l'**ÉMETTEUR** du PDF (« au nom et pour le compte de X ») — PAS du client facturé | `generate_invoice_pdf_service.dart:26-46` |
| **TVA** | ❌ **20 % codée en dur** (`0.20 * totalRidePrice`, libellé « Total TVA 20% ») | `generate_invoice_pdf_service.dart:61,395,449,732` |
| **Client facturé (« pour : »)** | ❌ = toujours le compte qui a réservé (`customerDetails`) | idem |

### ⚠️ Confusion de vocabulaire à retenir
- **Web `customBiller`** = l'émetteur (remplace le chauffeur en pied de page) — équivalent du
  `FLEET_BILLER` du dashboard.
- **Dashboard `billingTo`** = le client facturé (en-tête « pour : ») — c'est **ça** qu'il faut
  pour SALFA, et ça n'existe pas encore côté web.

---

## 3. Écarts à combler

### A. Accès aux comptes — rien à développer
Les 4 comptes existent déjà dans Firebase Auth. Donner l'accès = leur communiquer
book.misy.app + leurs identifiants riderapp (ou reset de mot de passe). Les courses
réservées sur le web et dans l'app atterrissent dans le même `bookingRequest`.

### B. Facture au nom de SALFA quel que soit l'opérateur ← le vrai chantier
Introduire une notion de **société rider** :

1. **Collection `rider_companies/{companyId}`** (nouvelle, ou réutiliser le modèle
   `fleets/` du dashboard) :
   ```
   { name: "SALFA", contactName: "Hariniaina RABARY", phone: "+261328389639",
     email: "hariniainarabary@yahoo.fr", nif: "", stat: "", address: "",
     tvaRate: 0, memberUids: [4 UIDs ci-dessus] }
   ```
2. **Poser `companyId` sur les 4 docs `users`** → le booking est déjà taggé
   automatiquement (`trip_provider.dart:3040` propage le champ).
3. **À la génération du PDF** (`generate_invoice_pdf_service.dart`) : si
   `bookingDetails.companyId` existe → charger la société et :
   - en-tête « Facture émise par Misy Technology pour : **{company.contactName ou name}** »
     (+ NIF/STAT société si renseignés) au lieu du rider ;
   - **TVA = `company.tvaRate`** (SALFA = 0) au lieu du 0.20 hardcodé, libellé
     « Total TVA {rate}% » (même logique que `TVA_RATE` du dashboard, commit `03750a1`).
4. Alternative plus robuste (phase 2) : déplacer la génération du PDF dans une **Cloud
   Function** (`onBookingCompleted`) pour ne pas dépendre du client web/app et unifier
   avec le moteur dashboard `regen_invoice.php`.

### C. Vue consolidée société (optionnel, phase 2)
`my_booking_screen` filtre par `requestBy == currentUser` : chaque opérateur ne voit que
SES courses. Pour que RABARY voie tout : requête `where('companyId','==',…)`.
⚠️ Prévoir l'**index composite** (`companyId`+`requestTime`) — vécu : `requestBy`+`requestTime`
n'a pas d'index aujourd'hui.

### D. Pièges connus (vécus sur les lots manuels)
- Adresse de départ = champ **`pickAddress`** (pas `pickupAddress`).
- Prix payé = **`ride_price_to_pay`** (un prix proposé/`customPrice` peut différer de
  `total_ride_price` — vu le 04/06 : 35 000 payé vs 25 000 calculé).
- Courses planifiées **annulées client** : `status=7` + `cancelledBy=rider` → ne pas facturer.
- Numérotation : le N° (`MISY/AAAA/MM/XXXXXXX`) doit rester unique et stable — le moteur
  dashboard sait le préserver (`INVOICE_NUMBER`), la génération web doit garder le sien.

---

## 4. Plan d'implémentation proposé

| # | Tâche | Effort | Fichiers |
|---|---|---|---|
| 1 | Créer `rider_companies/SALFA` + poser `companyId` sur les 4 users (script `scripts/FIX/` dashboard) | XS | script PHP one-shot |
| 2 | PDF web : client facturé = société si `companyId` (en-tête + NIF/STAT) | S | `generate_invoice_pdf_service.dart` |
| 3 | PDF web : TVA paramétrable `company.tvaRate` (défaut 20) | S | idem (4 occurrences hardcodées) |
| 4 | Rebuild + deploy Firebase Hosting (book.misy.app) | XS | — |
| 5 | (P2) Vue « courses de ma société » + index composite | M | `my_booking_screen.dart` |
| 6 | (P2) Génération facture côté Cloud Function, partagée app/web/dashboard | M/L | `functions/` riderapp |
| 7 | Communiquer les accès à SALFA (reset mots de passe si besoin) | XS | — |

**Remarque riderapp** : le même service PDF existe dans la riderapp
(`riderapp/lib/services/generate_invoice_pdf_service.dart`) — les opérateurs réservent
souvent via l'app mobile : appliquer les patchs 2-3 aussi côté riderapp (sinon une course
bookée mobile génèrera encore une facture au nom de l'opérateur à 20 %). C'est l'argument
principal pour la tâche 6 (génération serveur unique).

---

## 5. Références projet (audit 2026-06-04)

- **Stack** : Flutter Web 2.1.50+90 (path URL strategy), Firebase Hosting `book.misy.app`,
  projet `misy-95336`. Sous-projet React/Vite `transport-editor/` (claims `transport_editor`/`transport_admin`).
- **Cloud Functions** (`functions/index.js`, Node 22 — source de vérité pour 4 fonctions,
  deploy TOUJOURS `--only functions:NAME`) : `mainFunction` (escalade planifiées),
  `updateSchedulerJob`, `sendNotificationFunction`, `cleanupExpiredScheduledBookings`
  (+ 5 fonctions IAM transport).
- **Flux booking** : `TripProvider.createBooking` → `bookingRequest` (statuts 0-5, `isSchedule`,
  OTP, pricing complet, `companyId` si présent).
- **Multi-région** : `setting/cloud_functions_config` (us-central1/asia-east1, cache 60 s).
- i18n fr/mg/en (Maps statiques `MultiLangStrings`).
